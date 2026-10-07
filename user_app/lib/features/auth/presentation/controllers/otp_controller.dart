import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/async_state_view.dart';
import 'sign_in_controller.dart';

class OtpController extends GetxController {
  OtpController(
    this._auth,
    this._session,
    this.args, {
    this.resendAfter = 30,
    void Function(String route)? navigateTo,
  }) : _navigateTo = navigateTo ?? ((route) => Get.offAllNamed<void>(route));

  final AuthService _auth;
  final SessionService _session;
  final OtpArgs args;
  final int resendAfter;
  final void Function(String route) _navigateTo;

  late String _verificationId = args.verificationId;
  late int? _resendToken = args.resendToken;

  /// Owned here so the field can be cleared on resend or a wrong code.
  final codeField = TextEditingController();
  final code = ''.obs;
  final busy = false.obs;
  final error = RxnString();
  final secondsLeft = 0.obs;
  Timer? _timer;
  StreamSubscription<AuthUser?>? _authChanges;

  /// Firebase sign-in succeeded; only the backend step is left to retry.
  bool _firebaseSignedIn = false;
  bool _finishing = false;

  bool get canSubmit =>
      !busy.value &&
      (_firebaseSignedIn || RegExp(r'^\d{6}$').hasMatch(code.value));

  @override
  void onInit() {
    super.onInit();
    _startCountdown();
    // Android may verify the SMS automatically after the code was sent.
    _authChanges = _auth.authStateChanges().listen((user) {
      if (user != null && !busy.value && !_firebaseSignedIn) {
        _firebaseSignedIn = true;
        unawaited(_finish());
      }
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    unawaited(_authChanges?.cancel());
    codeField.dispose();
    super.onClose();
  }

  void onCodeChanged(String value) {
    code.value = value;
    if (value.length == 6) unawaited(submit());
  }

  Future<void> submit() async {
    if (!canSubmit) return;
    busy.value = true;
    error.value = null;
    try {
      if (!_firebaseSignedIn) {
        await _auth.confirmSmsCode(_verificationId, code.value);
        _firebaseSignedIn = true;
      }
      await _finish();
    } on AuthException catch (e) {
      error.value = authErrorMessage(e.kind);
      if (e.kind == AuthErrorKind.invalidCode ||
          e.kind == AuthErrorKind.codeExpired) {
        _clearCode();
      }
    } finally {
      busy.value = false;
    }
  }

  Future<void> resend() async {
    if (secondsLeft.value > 0 || busy.value) return;
    busy.value = true;
    error.value = null;
    try {
      final start = await _auth.startPhoneVerification(
        args.phoneE164,
        resendToken: _resendToken,
      );
      switch (start) {
        case CodeSent(:final verificationId, :final resendToken):
          _verificationId = verificationId;
          _resendToken = resendToken;
          _clearCode();
          _startCountdown();
        case AutoVerified():
          _firebaseSignedIn = true;
          await _finish();
      }
    } on AuthException catch (e) {
      error.value = authErrorMessage(e.kind);
    } finally {
      busy.value = false;
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      final result = await _session.completeSignIn();
      switch (result) {
        case Ok():
          _navigateTo(args.returnTo ?? '/');
        case Err(:final failure):
          error.value = '${failureTitle(failure)}. ${failureMessage(failure)}'
              .trim();
      }
    } finally {
      _finishing = false;
    }
  }

  void _clearCode() {
    codeField.clear();
    code.value = '';
  }

  void _startCountdown() {
    _timer?.cancel();
    secondsLeft.value = resendAfter;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft.value <= 1) {
        secondsLeft.value = 0;
        t.cancel();
      } else {
        secondsLeft.value--;
      }
    });
  }
}
