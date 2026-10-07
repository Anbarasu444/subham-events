import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// Firebase implementation. Google sign-in uses google_sign_in v7; the
/// Android server client id comes from the Firebase config (or the
/// `GOOGLE_SERVER_CLIENT_ID` define).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({fb.FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _googleInit;

  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      _googleInit ??= _google.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
      await _googleInit;
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(AuthErrorKind.unavailable, 'no-id-token');
      }
      final result = await _auth.signInWithCredential(
        fb.GoogleAuthProvider.credential(idToken: idToken),
      );
      return _map(result.user)!;
    } on GoogleSignInException catch (e) {
      if (kDebugMode) debugPrint('GoogleSignInException: ${e.code.name}');
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthErrorKind.cancelled
            : AuthErrorKind.unavailable,
        e.code.name,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _fromFirebase(e);
    }
  }

  @override
  Future<PhoneVerificationStart> startPhoneVerification(
    String phoneE164, {
    int? resendToken,
  }) {
    final completer = Completer<PhoneVerificationStart>();
    _auth
        .verifyPhoneNumber(
          phoneNumber: phoneE164,
          forceResendingToken: resendToken,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            // Android auto-retrieval / instant verification.
            try {
              await _auth.signInWithCredential(credential);
              if (!completer.isCompleted) {
                completer.complete(const AutoVerified());
              }
            } on fb.FirebaseAuthException catch (e) {
              if (!completer.isCompleted) {
                completer.completeError(_fromFirebase(e));
              }
            }
          },
          verificationFailed: (e) {
            if (!completer.isCompleted) {
              completer.completeError(_fromFirebase(e));
            }
          },
          codeSent: (verificationId, token) {
            if (!completer.isCompleted) {
              completer.complete(CodeSent(verificationId, token));
            }
          },
          codeAutoRetrievalTimeout: (_) {},
        )
        .catchError((Object e) {
          if (!completer.isCompleted) {
            completer.completeError(
              e is fb.FirebaseAuthException
                  ? _fromFirebase(e)
                  : const AuthException(AuthErrorKind.unknown),
            );
          }
        });
    return completer.future;
  }

  @override
  Future<AuthUser> confirmSmsCode(String verificationId, String smsCode) async {
    try {
      final result = await _auth.signInWithCredential(
        fb.PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        ),
      );
      return _map(result.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _fromFirebase(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _google.signOut();
    } catch (_) {
      // Google session may not exist (phone sign-in).
    }
  }

  static AuthUser? _map(fb.User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          phone: user.phoneNumber,
          email: user.email,
          displayName: user.displayName,
        );

  static AuthException _fromFirebase(fb.FirebaseAuthException e) {
    // Error codes only (no phone numbers or tokens) to diagnose setup issues.
    if (kDebugMode) debugPrint('FirebaseAuthException: ${e.code}');
    return AuthException(switch (e.code) {
      'invalid-phone-number' ||
      'missing-phone-number' => AuthErrorKind.invalidPhone,
      'invalid-verification-code' ||
      'missing-verification-code' => AuthErrorKind.invalidCode,
      'session-expired' || 'code-expired' => AuthErrorKind.codeExpired,
      'too-many-requests' || 'quota-exceeded' => AuthErrorKind.tooManyRequests,
      'network-request-failed' => AuthErrorKind.network,
      'user-disabled' ||
      'operation-not-allowed' ||
      'app-not-authorized' ||
      'invalid-app-credential' => AuthErrorKind.unavailable,
      _ => AuthErrorKind.unknown,
    }, e.code);
  }
}
