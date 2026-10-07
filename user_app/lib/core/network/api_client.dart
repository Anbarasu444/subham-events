import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../error/failure.dart';
import '../error/result.dart';
import 'api_response.dart';
import 'error_mapper.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/request_id_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// The only HTTP entry point for the app (CLAUDE.md §14). Repositories call it;
/// widgets and controllers never touch Dio.
class ApiClient {
  ApiClient(this._dio);

  /// Production wiring: base URL, timeouts, headers and interceptors.
  factory ApiClient.create(
    AppConfig config, {
    HttpClientAdapter? adapter,
    AuthInterceptor? authInterceptor,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: '${config.apiBaseUrl}/api/v1',
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'X-Client': config.clientHeader,
        },
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.addAll([
      RequestIdInterceptor(),
      if (authInterceptor != null) authInterceptor..attach(dio),
      RetryInterceptor(dio),
      if (config.enableHttpLogging) LoggingInterceptor(),
    ]);
    return ApiClient(dio);
  }

  final Dio _dio;

  Future<Result<ApiResponse<T>>> get<T>(
    String path, {
    required T Function(Object? data) decode,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
    ),
    decode,
  );

  Future<Result<ApiResponse<T>>> post<T>(
    String path, {
    required T Function(Object? data) decode,
    Object? body,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      cancelToken: cancelToken,
      options: Options(headers: {'Idempotency-Key': ?idempotencyKey}),
    ),
    decode,
  );

  Future<Result<ApiResponse<T>>> patch<T>(
    String path, {
    required T Function(Object? data) decode,
    Object? body,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.patch<Object?>(path, data: body, cancelToken: cancelToken),
    decode,
  );

  /// DELETE; a 204 response decodes `null`.
  Future<Result<ApiResponse<T>>> delete<T>(
    String path, {
    required T Function(Object? data) decode,
    CancelToken? cancelToken,
  }) =>
      _send(() => _dio.delete<Object?>(path, cancelToken: cancelToken), decode);

  Future<Result<ApiResponse<T>>> _send<T>(
    Future<Response<Object?>> Function() request,
    T Function(Object? data) decode,
  ) async {
    try {
      final response = await request();
      if (response.statusCode == 204) {
        return Ok(ApiResponse<T>(data: decode(null)));
      }
      return Ok(ApiResponse.fromEnvelope(response.data, decode));
    } on DioException catch (e) {
      return Err(mapDioException(e));
    } on FormatException {
      return const Err(UnknownFailure(code: 'INVALID_RESPONSE'));
    } on TypeError {
      // A response that does not match the expected shape.
      return const Err(UnknownFailure(code: 'INVALID_RESPONSE'));
    }
  }
}
