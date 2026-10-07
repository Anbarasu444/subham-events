import 'package:dio/dio.dart';

import '../api_exception.dart';

typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// Why the server rejected the session; the app must sign out locally.
enum SessionInvalidReason { revoked, invalid, suspended, deleted }

/// Attaches the Firebase ID token and handles expiry (identity-access.md §5):
/// on `401 AUTH_TOKEN_EXPIRED` it forces **one** refresh — shared by all
/// concurrent requests — and replays the request once. Revoked/invalid
/// tokens and suspended/deleted accounts end the session.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenProvider,
    required this.onSessionInvalid,
  });

  final TokenProvider tokenProvider;
  final void Function(SessionInvalidReason reason) onSessionInvalid;

  static const _replayedKey = 'auth_replayed';
  static const skipAuthKey = 'auth_skip';

  Dio? _dio;
  Future<String?>? _refreshing;

  /// Gives the interceptor the client used to replay requests.
  void attach(Dio dio) => _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true &&
        !options.headers.containsKey('Authorization')) {
      String? token;
      try {
        token = await (_refreshing ?? tokenProvider());
      } catch (_) {
        token = null; // Offline token fetch: send as guest; server decides.
      }
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final code = ApiError.fromBody(err.response?.data).code;
    final options = err.requestOptions;
    final sentToken = options.headers.containsKey('Authorization');

    if (status == 401 && code == 'AUTH_TOKEN_EXPIRED' && sentToken) {
      if (options.extra[_replayedKey] == true || _dio == null) {
        onSessionInvalid(SessionInvalidReason.invalid);
        return handler.next(err);
      }
      final String? fresh;
      try {
        fresh = await _refreshOnce();
      } catch (_) {
        // Could not refresh (e.g. offline): keep the session, fail the call.
        return handler.next(err);
      }
      if (fresh == null) {
        onSessionInvalid(SessionInvalidReason.invalid);
        return handler.next(err);
      }
      options
        ..extra[_replayedKey] = true
        ..headers['Authorization'] = 'Bearer $fresh';
      try {
        return handler.resolve(await _dio!.fetch<dynamic>(options));
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }

    final reason = switch ((status, code)) {
      (401, 'AUTH_TOKEN_REVOKED') => SessionInvalidReason.revoked,
      (401, 'AUTH_TOKEN_INVALID') => SessionInvalidReason.invalid,
      (403, 'ACCOUNT_SUSPENDED') => SessionInvalidReason.suspended,
      (403, 'ACCOUNT_DELETED') => SessionInvalidReason.deleted,
      _ => null,
    };
    if (reason != null && sentToken) onSessionInvalid(reason);
    handler.next(err);
  }

  Future<String?> _refreshOnce() {
    return _refreshing ??= tokenProvider(
      forceRefresh: true,
    ).catchError((Object _) => null).whenComplete(() => _refreshing = null);
  }
}
