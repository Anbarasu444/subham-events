import 'package:get/get.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/async_state_view.dart';

/// Normalises an Indian mobile number to E.164 (`+91XXXXXXXXXX`).
/// Accepts other countries when the user types a leading `+`.
String? toE164(String input, {String defaultCountryCode = '+91'}) {
  final compact = input.replaceAll(RegExp(r'[\s()-]'), '');
  if (compact.startsWith('+')) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact) ? compact : null;
  }
  final local = compact.startsWith('0') ? compact.substring(1) : compact;
  return RegExp(r'^[6-9]\d{9}$').hasMatch(local)
      ? '$defaultCountryCode$local'
      : null;
}

String authErrorMessage(AuthErrorKind kind) => switch (kind) {
  AuthErrorKind.cancelled => '',
  AuthErrorKind.invalidPhone => 'Enter a valid mobile number.',
  AuthErrorKind.invalidCode =>
    'That code is not correct. Check the SMS and try again.',
  AuthErrorKind.codeExpired => 'This code has expired. Request a new one.',
  AuthErrorKind.tooManyRequests =>
    'Too many attempts. Please wait and try again later.',
  AuthErrorKind.network =>
    'Couldn’t connect. Check your connection and try again.',
  AuthErrorKind.unavailable =>
    'Sign-in is not available right now. Please try again later.',
  AuthErrorKind.unknown => 'Something went wrong. Please try again.',
};

class SignInController extends GetxController {
  SignInController(this._auth, this._session, {this.returnTo});

  final AuthService _auth;
  final SessionService _session;

  /// Route to resume after sign-in (protected route that redirected here).
  final String? returnTo;

  final busy = Rxn<String>(); // 'google' | 'phone'
  final error = RxnString();
  final phone = ''.obs;

  bool get phoneValid => toE164(phone.value) != null;

  /// Shown once enough digits are typed and the number is still invalid.
  String? get phoneError {
    final digits = phone.value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && !phoneValid
        ? 'Enter a 10-digit Indian mobile number, or start with + and the country code.'
        : null;
  }

  Future<void> signInWithGoogle() async {
    busy.value = 'google';
    error.value = null;
    try {
      await _auth.signInWithGoogle();
      await _finish();
    } on AuthException catch (e) {
      final message = authErrorMessage(e.kind);
      error.value = message.isEmpty ? null : message;
    } finally {
      busy.value = null;
    }
  }

  /// Starts phone verification; returns the OTP route arguments, or null.
  Future<void> continueWithPhone() async {
    final e164 = toE164(phone.value);
    if (e164 == null) {
      error.value = authErrorMessage(AuthErrorKind.invalidPhone);
      return;
    }
    busy.value = 'phone';
    error.value = null;
    try {
      final start = await _auth.startPhoneVerification(e164);
      switch (start) {
        case CodeSent(:final verificationId, :final resendToken):
          await Get.toNamed<void>(
            '/sign-in/otp',
            arguments: OtpArgs(
              phoneE164: e164,
              verificationId: verificationId,
              resendToken: resendToken,
              returnTo: returnTo,
            ),
          );
        case AutoVerified():
          await _finish();
      }
    } on AuthException catch (e) {
      error.value = authErrorMessage(e.kind);
    } finally {
      busy.value = null;
    }
  }

  Future<void> _finish() async {
    final result = await _session.completeSignIn();
    switch (result) {
      case Ok():
        Get.offAllNamed<void>(returnTo ?? '/');
      case Err(:final failure):
        error.value = '${failureTitle(failure)}. ${failureMessage(failure)}'
            .trim();
    }
  }
}

class OtpArgs {
  const OtpArgs({
    required this.phoneE164,
    required this.verificationId,
    this.resendToken,
    this.returnTo,
  });
  final String phoneE164;
  final String verificationId;
  final int? resendToken;
  final String? returnTo;
}
