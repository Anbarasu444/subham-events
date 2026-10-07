import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/network/interceptors/auth_interceptor.dart';

import '../../helpers/fake_adapter.dart';

Map<String, Object> _err(String code) => {
  'error': {'code': code, 'message': 'm', 'details': <Object>[]},
};

class _Tokens {
  int refreshes = 0;
  String current = 'token-1';
  Future<String?> call({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      current = 'token-${refreshes + 1}';
    }
    return current;
  }
}

({
  Dio dio,
  FakeAdapter adapter,
  List<SessionInvalidReason> invalid,
  _Tokens tokens,
})
_setup(List<Object> script, {String? Function()? token}) {
  final adapter = FakeAdapter(script);
  final dio = Dio(BaseOptions(baseUrl: 'http://h/api/v1'))
    ..httpClientAdapter = adapter;
  final invalid = <SessionInvalidReason>[];
  final tokens = _Tokens();
  dio.interceptors.add(
    AuthInterceptor(
      tokenProvider: ({bool forceRefresh = false}) => token != null
          ? Future.value(token())
          : tokens(forceRefresh: forceRefresh),
      onSessionInvalid: invalid.add,
    )..attach(dio),
  );
  return (dio: dio, adapter: adapter, invalid: invalid, tokens: tokens);
}

void main() {
  test('attaches the bearer token; none for guests', () async {
    final signedIn = _setup([
      FakeAdapter.json(200, {'data': 1, 'meta': {}}),
    ]);
    await signedIn.dio.get<Object?>('/me');
    expect(
      signedIn.adapter.requests.single.headers['Authorization'],
      'Bearer token-1',
    );

    final guest = _setup([
      FakeAdapter.json(200, {'data': 1, 'meta': {}}),
    ], token: () => null);
    await guest.dio.get<Object?>('/vendors');
    expect(
      guest.adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test(
    'expired token: one forced refresh, then the request is replayed',
    () async {
      final s = _setup([
        FakeAdapter.json(401, _err('AUTH_TOKEN_EXPIRED')),
        FakeAdapter.json(200, {'data': 'ok', 'meta': {}}),
      ]);
      final res = await s.dio.get<Object?>('/me');
      expect(res.statusCode, 200);
      expect(s.tokens.refreshes, 1);
      expect(
        s.adapter.requests.last.headers['Authorization'],
        'Bearer token-2',
      );
      expect(s.invalid, isEmpty);
    },
  );

  test('concurrent expired requests share a single refresh', () async {
    final s = _setup([
      FakeAdapter.json(401, _err('AUTH_TOKEN_EXPIRED')),
      FakeAdapter.json(401, _err('AUTH_TOKEN_EXPIRED')),
      FakeAdapter.json(200, {'data': 1, 'meta': {}}),
      FakeAdapter.json(200, {'data': 2, 'meta': {}}),
    ]);
    await Future.wait([s.dio.get<Object?>('/a'), s.dio.get<Object?>('/b')]);
    expect(s.tokens.refreshes, 1);
  });

  test('still expired after the replay ends the session', () async {
    final s = _setup([
      FakeAdapter.json(401, _err('AUTH_TOKEN_EXPIRED')),
      FakeAdapter.json(401, _err('AUTH_TOKEN_EXPIRED')),
    ]);
    await expectLater(s.dio.get<Object?>('/me'), throwsA(isA<DioException>()));
    expect(s.invalid, [SessionInvalidReason.invalid]);
  });

  test('revoked, invalid, suspended and deleted end the session', () async {
    for (final (status, code, reason) in [
      (401, 'AUTH_TOKEN_REVOKED', SessionInvalidReason.revoked),
      (401, 'AUTH_TOKEN_INVALID', SessionInvalidReason.invalid),
      (403, 'ACCOUNT_SUSPENDED', SessionInvalidReason.suspended),
      (403, 'ACCOUNT_DELETED', SessionInvalidReason.deleted),
    ]) {
      final s = _setup([FakeAdapter.json(status, _err(code))]);
      await expectLater(
        s.dio.get<Object?>('/me'),
        throwsA(isA<DioException>()),
      );
      expect(s.invalid, [reason], reason: code);
    }
  });

  test('other errors do not touch the session', () async {
    final s = _setup([FakeAdapter.json(403, _err('FORBIDDEN_ROLE'))]);
    await expectLater(s.dio.get<Object?>('/x'), throwsA(isA<DioException>()));
    expect(s.invalid, isEmpty);
  });

  test('a refresh that fails offline keeps the session', () async {
    final adapter = FakeAdapter([
      FakeAdapter.json(401, _err('AUTH_TOKEN_EXPIRED')),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'http://h/api/v1'))
      ..httpClientAdapter = adapter;
    final invalid = <SessionInvalidReason>[];
    dio.interceptors.add(
      AuthInterceptor(
        tokenProvider: ({bool forceRefresh = false}) async {
          if (forceRefresh) throw Exception('network');
          return 'token-1';
        },
        onSessionInvalid: invalid.add,
      )..attach(dio),
    );
    await expectLater(dio.get<Object?>('/me'), throwsA(isA<DioException>()));
    expect(invalid, isEmpty);
  });
}
