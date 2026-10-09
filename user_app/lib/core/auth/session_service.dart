import 'dart:async';

import 'package:get/get.dart';

import '../../features/auth/data/auth_api.dart';
import '../crash/crash_reporter.dart';
import '../error/failure.dart';
import '../error/result.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../storage/app_cache_manager.dart';
import '../storage/secure_store.dart';
import 'auth_service.dart';
import 'session.dart';

/// App-wide session (architecture/flutter.md §6): combines the Firebase
/// identity with the backend user. Roles always come from the backend.
class SessionService extends GetxService {
  SessionService({
    required this.auth,
    required this.api,
    required this.store,
    required this.reporter,
    Future<void> Function()? clearPrivateMedia,
  }) : _clearPrivateMedia =
           clearPrivateMedia ?? AppCacheManager.instance.emptyCache;

  final AuthService auth;
  final AuthApi api;
  final SecureStore store;
  final CrashReporter reporter;
  final Future<void> Function() _clearPrivateMedia;

  /// Work that needs the still-valid session before a user-initiated
  /// sign-out (e.g. unregistering this phone's push token, M18).
  final List<Future<void> Function()> _beforeSignOut = [];

  void addBeforeSignOut(Future<void> Function() hook) =>
      _beforeSignOut.add(hook);

  final state = Rx<SessionState>(const RestoringSession());

  /// Keys written by earlier builds; removed on sign-out. No profile data is
  /// stored locally (GI-12: encrypted_shared_preferences is not hardware-backed).
  static const _legacyKeys = ['session.profile_label'];

  bool get isSignedIn => state.value is SignedInSession;

  /// Restores a previous Firebase session without blocking start-up.
  /// Temporary problems (offline, server errors) never sign the user out.
  Future<void> restore() async {
    if (auth.currentUser == null) {
      state.value = const GuestSession();
      return;
    }
    final me = await api.me();
    switch (me) {
      case Ok(:final value):
        state.value = SignedInSession(value);
      case Err(failure: UnauthorizedFailure(code: 'AUTH_REQUIRED')):
        // Firebase user exists but the backend user does not yet.
        await completeSignIn();
      case Err(:final failure):
        await _handleFailure(failure);
    }
  }

  /// Retries loading the profile after a temporary failure.
  Future<void> retry() => restore();

  /// Called after a successful Firebase sign-in: registers/maps the user.
  /// On a temporary failure the Firebase sign-in is kept so the user does not
  /// have to sign in (or enter an SMS code) again.
  Future<Result<MeProfile>> completeSignIn() async {
    final result = await api.createSession();
    switch (result) {
      case Ok(:final value):
        state.value = SignedInSession(value.profile);
        return Ok(value.profile);
      case Err(:final failure):
        await _handleFailure(failure);
        return Err(failure);
    }
  }

  /// Shows the edited profile (M21) without another request.
  void updateProfile(MeProfile profile) {
    if (state.value is SignedInSession) {
      state.value = SignedInSession(profile);
    }
  }

  /// The account was deleted (M21): the server already signed this user out
  /// everywhere and unregistered the devices, so only sign out here.
  Future<void> accountDeleted() => _signOutLocally(
    message:
        'Your account has been deleted. Sign in again any time to restore it.',
  );

  /// User-initiated sign-out: revoke on the server (best effort), then local.
  Future<void> signOut() async {
    for (final hook in _beforeSignOut) {
      try {
        await hook().timeout(const Duration(seconds: 5));
      } on Object catch (error) {
        reporter.log('Before sign-out step failed: $error'); // best effort
      }
    }
    if (auth.currentUser != null) await api.signOut();
    await _signOutLocally();
  }

  /// The server rejected the session (revoked, suspended, deleted…).
  void onSessionInvalid(SessionInvalidReason reason) {
    reporter.log('Session ended by server: ${reason.name}');
    unawaited(_signOutLocally(message: _messageFor(reason)));
  }

  Future<void> _handleFailure(Failure failure) async {
    final reason = switch (failure) {
      UnauthorizedFailure(code: 'AUTH_TOKEN_REVOKED') =>
        SessionInvalidReason.revoked,
      UnauthorizedFailure() => SessionInvalidReason.invalid,
      ForbiddenFailure(code: 'ACCOUNT_SUSPENDED') =>
        SessionInvalidReason.suspended,
      ForbiddenFailure(code: 'ACCOUNT_DELETED') => SessionInvalidReason.deleted,
      _ => null,
    };
    if (reason != null) {
      await _signOutLocally(message: _messageFor(reason));
    } else if (state.value is! SignedInSession) {
      state.value = const ProfilePendingSession();
    }
  }

  static String _messageFor(SessionInvalidReason reason) => switch (reason) {
    SessionInvalidReason.suspended =>
      'This account is suspended. Please contact support.',
    SessionInvalidReason.deleted => 'This account has been deleted.',
    SessionInvalidReason.revoked || SessionInvalidReason.invalid =>
      'You have been signed out. Please sign in again.',
  };

  Future<void>? _signingOut;
  String? _pendingMessage;

  /// Single-flight: concurrent sign-outs share one run; the first message wins.
  Future<void> _signOutLocally({String? message}) {
    _pendingMessage ??= message;
    return _signingOut ??= _doSignOut().whenComplete(() {
      _signingOut = null;
      _pendingMessage = null;
    });
  }

  Future<void> _doSignOut() async {
    await auth.signOut();
    for (final key in _legacyKeys) {
      await store.delete(key);
    }
    // Private media URLs must not outlive the session.
    await _clearPrivateMedia();
    state.value = GuestSession(message: _pendingMessage);
  }
}
