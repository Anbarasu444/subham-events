import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Dev/staging-only request log. Logs method, path, status and duration —
/// never headers, bodies or query strings (tokens, phone numbers).
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({void Function(String message)? log})
    : _log = log ?? ((m) => developer.log(m, name: 'http'));

  final void Function(String message) _log;
  static const _startKey = 'log_started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(_line(response.requestOptions, response.statusCode));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      '${_line(err.requestOptions, err.response?.statusCode)} ${err.type.name}',
    );
    handler.next(err);
  }

  String _line(RequestOptions options, int? status) {
    final started = options.extra[_startKey] as DateTime?;
    final ms = started == null
        ? '?'
        : DateTime.now().difference(started).inMilliseconds.toString();
    return '${options.method} ${options.uri.path} -> ${status ?? '-'} '
        '(${ms}ms) [${options.headers['X-Request-Id']}]';
  }
}
