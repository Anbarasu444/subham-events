import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/app/config/app_config.dart';
import 'package:vendor_app/core/error/failure.dart';
import 'package:vendor_app/core/error/result.dart';
import 'package:vendor_app/core/network/api_client.dart';
import 'package:vendor_app/core/network/api_response.dart';
import 'package:vendor_app/core/network/interceptors/logging_interceptor.dart';
import 'package:vendor_app/core/network/interceptors/request_id_interceptor.dart';
import 'package:vendor_app/core/network/interceptors/retry_interceptor.dart';

import '../../helpers/fake_adapter.dart';

const _config = AppConfig(
  flavor: Flavor.staging,
  apiBaseUrl: 'http://localhost:3000',
  appVersion: '1.0.0',
  buildNumber: '1',
);

/// Client with instant retries so tests do not sleep.
ApiClient _client(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
    ..httpClientAdapter = adapter;
  dio.interceptors.addAll([
    RequestIdInterceptor(generate: () => 'req-test-0001'),
    RetryInterceptor(dio, sleep: (_) async {}),
  ]);
  return ApiClient(dio);
}

Map<String, Object?> _error(String code, {List<Object> details = const []}) => {
  'error': {
    'code': code,
    'message': 'msg',
    'details': details,
    'requestId': 'r1',
  },
};

void main() {
  group('ApiClient', () {
    test('production client targets /api/v1 and sends X-Client', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(200, {'data': 1, 'meta': {}}),
      ]);
      await ApiClient.create(
        _config,
        adapter: adapter,
      ).get('/x', decode: (d) => d);
      final request = adapter.requests.single;
      expect(request.uri.toString(), 'http://localhost:3000/api/v1/x');
      expect(request.headers['X-Client'], 'vendor_app/1.0.0+1');
      expect(request.headers[requestIdHeader], isNotEmpty);
    });

    test(
      'decodes the success envelope with request id and cursor page',
      () async {
        final adapter = FakeAdapter([
          FakeAdapter.json(200, {
            'data': [1, 2],
            'meta': {
              'requestId': 'abc',
              'page': {
                'type': 'cursor',
                'limit': 20,
                'nextCursor': 'n1',
                'hasMore': true,
              },
            },
          }),
        ]);
        final result = await _client(
          adapter,
        ).get('/items', decode: (d) => (d! as List).cast<int>());
        final response = (result as Ok<ApiResponse<List<int>>>).value;
        expect(response.data, [1, 2]);
        expect(response.requestId, 'abc');
        expect((response.page! as CursorPageMeta).nextCursor, 'n1');
      },
    );

    test('maps 422 field details to ValidationFailure', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(
          422,
          _error(
            'VALIDATION_FAILED',
            details: [
              {'field': 'title', 'code': 'ISNOTEMPTY', 'message': 'required'},
            ],
          ),
        ),
      ]);
      final result = await _client(
        adapter,
      ).post('/events', decode: (d) => d, body: {});
      final failure = (result as Err).failure as ValidationFailure;
      expect(failure.code, 'VALIDATION_FAILED');
      expect(failure.fieldErrors.single.field, 'title');
      expect(failure.requestId, 'r1');
    });

    test('maps status codes to failure types', () async {
      Future<Failure> failureFor(int status) async {
        final adapter = FakeAdapter([FakeAdapter.json(status, _error('X'))]);
        final result = await _client(adapter).post('/p', decode: (d) => d);
        return (result as Err).failure;
      }

      expect(await failureFor(401), isA<UnauthorizedFailure>());
      expect(await failureFor(403), isA<ForbiddenFailure>());
      expect(await failureFor(404), isA<NotFoundFailure>());
      expect(await failureFor(409), isA<ConflictFailure>());
      expect(await failureFor(500), isA<ServerFailure>());
      expect(await failureFor(400), isA<UnknownFailure>());
    });

    test('maps connection errors and timeouts', () async {
      final offline = await _client(
        FakeAdapter([
          DioExceptionType.connectionError,
          DioExceptionType.connectionError,
          DioExceptionType.connectionError,
        ]),
      ).get('/x', decode: (d) => d);
      expect((offline as Err).failure, isA<NetworkFailure>());

      final timeout = await _client(
        FakeAdapter([
          DioExceptionType.receiveTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.receiveTimeout,
        ]),
      ).get('/x', decode: (d) => d);
      expect((timeout as Err).failure, isA<TimeoutFailure>());
    });

    test('a non-conforming error body still yields a Failure', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(500, {
          'error': {
            'code': 123,
            'details': [
              {'field': 7},
            ],
          },
        }),
      ]);
      final result = await _client(adapter).post('/x', decode: (d) => d);
      final failure = (result as Err).failure as ServerFailure;
      expect(failure.code, isNull);
    });

    test('decodes offset page meta', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(200, {
          'data': <Object>[],
          'meta': {
            'page': {
              'type': 'offset',
              'page': 2,
              'pageSize': 50,
              'totalItems': 312,
              'totalPages': 7,
            },
          },
        }),
      ]);
      final result = await _client(adapter).get('/admin/x', decode: (d) => d);
      final page =
          (result as Ok<ApiResponse<Object?>>).value.page! as OffsetPageMeta;
      expect(page.totalPages, 7);
      expect(page.page, 2);
    });

    test('a body that is not an envelope becomes INVALID_RESPONSE', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(200, {'unexpected': true}),
      ]);
      final result = await _client(adapter).get('/x', decode: (d) => d);
      expect((result as Err).failure.code, 'INVALID_RESPONSE');
    });
  });

  group('RetryInterceptor', () {
    test('retries idempotent GET on 503 and keeps the request id', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(503, _error('SERVICE_UNAVAILABLE')),
        FakeAdapter.json(200, {'data': 'ok', 'meta': {}}),
      ]);
      final result = await _client(adapter).get('/x', decode: (d) => d);
      expect(result, isA<Ok>());
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.map((r) => r.headers[requestIdHeader]).toSet(), {
        'req-test-0001',
      });
    });

    test('gives up after two retries', () async {
      final adapter = FakeAdapter([
        DioExceptionType.connectionError,
        DioExceptionType.connectionError,
        DioExceptionType.connectionError,
      ]);
      await _client(adapter).get('/x', decode: (d) => d);
      expect(adapter.requests, hasLength(3));
    });

    test('never retries a POST without an Idempotency-Key', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(503, _error('SERVICE_UNAVAILABLE')),
      ]);
      final result = await _client(adapter).post('/x', decode: (d) => d);
      expect((result as Err).failure, isA<ServerFailure>());
      expect(adapter.requests, hasLength(1));
    });

    test('retries a POST that carries an Idempotency-Key', () async {
      final adapter = FakeAdapter([
        DioExceptionType.connectionError,
        FakeAdapter.json(201, {'data': 'created', 'meta': {}}),
      ]);
      final result = await _client(
        adapter,
      ).post('/x', decode: (d) => d, idempotencyKey: 'key-1');
      expect(result, isA<Ok>());
      expect(adapter.requests.last.headers['Idempotency-Key'], 'key-1');
    });

    test('does not retry 4xx client errors', () async {
      final adapter = FakeAdapter([FakeAdapter.json(404, _error('NOT_FOUND'))]);
      await _client(adapter).get('/x', decode: (d) => d);
      expect(adapter.requests, hasLength(1));
    });

    test(
      'honours a short Retry-After on 429 and gives up on a long one',
      () async {
        final short = FakeAdapter([
          FakeAdapter.json(
            429,
            _error('RATE_LIMITED'),
            headers: {
              'retry-after': ['2'],
            },
          ),
          FakeAdapter.json(200, {'data': 1, 'meta': {}}),
        ]);
        expect(await _client(short).get('/x', decode: (d) => d), isA<Ok>());

        final long = FakeAdapter([
          FakeAdapter.json(
            429,
            _error('RATE_LIMITED'),
            headers: {
              'retry-after': ['120'],
            },
          ),
        ]);
        final result = await _client(long).get('/x', decode: (d) => d);
        final failure = (result as Err).failure as RateLimitedFailure;
        expect(failure.retryAfter, const Duration(seconds: 120));
        expect(long.requests, hasLength(1));
      },
    );
    test('retries idempotent PUT and DELETE', () async {
      for (final method in ['PUT', 'DELETE']) {
        final adapter = FakeAdapter([
          DioExceptionType.connectionError,
          FakeAdapter.json(200, {'data': 1, 'meta': {}}),
        ]);
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(RetryInterceptor(dio, sleep: (_) async {}));
        final response = await dio.request<Object?>(
          '/x',
          options: Options(method: method),
        );
        expect(response.statusCode, 200, reason: method);
        expect(adapter.requests, hasLength(2), reason: method);
      }
    });

    test(
      'stops retrying when the request was cancelled during backoff',
      () async {
        final token = CancelToken();
        final adapter = FakeAdapter([DioExceptionType.connectionError]);
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(
          RetryInterceptor(dio, sleep: (_) async => token.cancel()),
        );
        await expectLater(
          dio.get<Object?>('/x', cancelToken: token),
          throwsA(isA<DioException>()),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  });

  group('RequestIdInterceptor', () {
    test('adds a UUID v4 request id and keeps an explicit one', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(200, {'data': 1, 'meta': {}}),
        FakeAdapter.json(200, {'data': 1, 'meta': {}}),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(RequestIdInterceptor());
      await dio.get<Object?>('http://h/x');
      await dio.get<Object?>(
        'http://h/x',
        options: Options(headers: {requestIdHeader: 'mine-0001'}),
      );
      expect(
        adapter.requests.first.headers[requestIdHeader],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(adapter.requests.last.headers[requestIdHeader], 'mine-0001');
    });
  });

  group('LoggingInterceptor', () {
    test(
      'logs method, path and status but never headers, query or body',
      () async {
        final lines = <String>[];
        final adapter = FakeAdapter([
          FakeAdapter.json(200, {'data': 'secret-body', 'meta': {}}),
        ]);
        final dio = Dio()..httpClientAdapter = adapter;
        dio.interceptors.add(LoggingInterceptor(log: lines.add));
        await dio.get<Object?>(
          'http://h/api/v1/invitations',
          queryParameters: {'token': 'tok-secret'},
          options: Options(headers: {'Authorization': 'Bearer abc.def'}),
        );
        expect(lines.single, startsWith('GET /api/v1/invitations -> 200'));
        final logged = lines.join();
        expect(logged, isNot(contains('tok-secret')));
        expect(logged, isNot(contains('abc.def')));
        expect(logged, isNot(contains('secret-body')));
      },
    );
  });
}
