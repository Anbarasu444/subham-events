import 'auth_service.dart';

/// Used when Firebase could not be initialised: the app keeps working for
/// guests and sign-in reports "unavailable" instead of crashing.
class UnavailableAuthService implements AuthService {
  const UnavailableAuthService();

  static const _error = AuthException(
    AuthErrorKind.unavailable,
    'firebase-not-initialised',
  );

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => null;

  @override
  Future<AuthUser> signInWithGoogle() => Future.error(_error);

  @override
  Future<PhoneVerificationStart> startPhoneVerification(
    String phoneE164, {
    int? resendToken,
  }) => Future.error(_error);

  @override
  Future<AuthUser> confirmSmsCode(String verificationId, String smsCode) =>
      Future.error(_error);

  @override
  Future<void> signOut() async {}
}
