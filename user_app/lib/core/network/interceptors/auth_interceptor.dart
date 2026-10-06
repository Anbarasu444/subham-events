import 'package:dio/dio.dart';

/// Attaches the Firebase ID token once authentication exists (M5).
/// Until then every request is a guest request (identity-access.md §3).
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }
}
