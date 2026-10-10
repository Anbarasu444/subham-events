import 'dart:math';

import 'package:dio/dio.dart';

import '../error_mapper.dart';

typedef Sleep = Future<void> Function(Duration duration);

/// Retries only requests that are safe to repeat (architecture/flutter.md §5):
/// idempotent methods, or requests carrying an `Idempotency-Key`; on network
/// errors, timeouts, 502/503/504, and 429 with a short `Retry-After`.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    this.delays = const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1500),
    ],
    Sleep? sleep,
    Random? random,
  }) : _sleep = sleep ?? Future<void>.delayed,
       _random = random ?? Random();

  static const _attemptKey = 'retry_attempt';
  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};
  static const _retryableStatuses = {502, 503, 504};
  static const _maxRetryAfter = Duration(seconds: 10);

  final Dio _dio;
  final int maxRetries;
  final List<Duration> delays;
  final Sleep _sleep;
  final Random _random;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    final delay = _retryDelay(err, attempt);
    if (attempt >= maxRetries || delay == null || !_isSafeToRepeat(options)) {
      return handler.next(err);
    }
    await _sleep(delay);
    if (options.cancelToken?.isCancelled ?? false) {
      return handler.next(err);
    }
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isSafeToRepeat(RequestOptions options) =>
      _idempotentMethods.contains(options.method.toUpperCase()) ||
      options.headers.keys.any((k) => k.toLowerCase() == 'idempotency-key');

  /// Returns the delay before the next attempt, or null if not retryable.
  Duration? _retryDelay(DioException err, int attempt) {
    final base = delays[min(attempt, delays.length - 1)];
    final jitter = Duration(milliseconds: _random.nextInt(250));
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return base + jitter;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (status == 429) {
          final retryAfter = parseRetryAfter(
            err.response?.headers.value('retry-after'),
          );
          return retryAfter != null && retryAfter <= _maxRetryAfter
              ? retryAfter
              : null;
        }
        return _retryableStatuses.contains(status) ? base + jitter : null;
      case DioExceptionType.transformTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return null;
    }
  }
}
