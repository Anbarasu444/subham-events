/// Identity from Firebase on this device (never authoritative for roles).
class AuthUser {
  const AuthUser({required this.uid, this.phone, this.email, this.displayName});
  final String uid;
  final String? phone;
  final String? email;
  final String? displayName;
}

enum AuthErrorKind {
  cancelled,
  invalidPhone,
  invalidCode,
  codeExpired,
  tooManyRequests,
  network,
  unavailable,
  unknown,
}

/// Sign-in failure with a user-safe kind; provider details stay in logs.
class AuthException implements Exception {
  const AuthException(this.kind, [this.debugCode]);
  final AuthErrorKind kind;
  final String? debugCode;

  @override
  String toString() => 'AuthException($kind, $debugCode)';
}

sealed class PhoneVerificationStart {
  const PhoneVerificationStart();
}

/// SMS sent; the user must enter the code.
class CodeSent extends PhoneVerificationStart {
  const CodeSent(this.verificationId, this.resendToken);
  final String verificationId;
  final int? resendToken;
}

/// Android verified the number automatically; the user is signed in.
class AutoVerified extends PhoneVerificationStart {
  const AutoVerified();
}

/// Firebase identity operations (architecture/identity-access.md §4).
abstract class AuthService {
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();

  /// Current ID token; [forceRefresh] asks Firebase for a new one.
  Future<String?> idToken({bool forceRefresh = false});

  /// @throws AuthException
  Future<AuthUser> signInWithGoogle();

  /// [phoneE164] like `+919876543210`. @throws AuthException
  Future<PhoneVerificationStart> startPhoneVerification(
    String phoneE164, {
    int? resendToken,
  });

  /// @throws AuthException
  Future<AuthUser> confirmSmsCode(String verificationId, String smsCode);

  Future<void> signOut();
}
