import 'package:dio/dio.dart';

import '../../utils/request_id.dart';

const requestIdHeader = 'X-Request-Id';

/// Adds a fresh `X-Request-Id` per request (kept across retries).
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({String Function()? generate})
    : _generate = generate ?? generateRequestId;

  final String Function() _generate;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(requestIdHeader, _generate);
    handler.next(options);
  }
}
