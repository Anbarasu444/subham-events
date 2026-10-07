import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/core/auth/auth_service.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/features/auth/presentation/controllers/sign_in_controller.dart';

class _Auth extends Mock implements AuthService {}

class _Session extends Mock implements SessionService {}

void main() {
  test('normalises Indian mobile numbers to E.164', () {
    expect(toE164('98765 43210'), '+919876543210');
    expect(toE164('098765-43210'), '+919876543210');
    expect(toE164('+91 98765 43210'), '+919876543210');
    expect(toE164('+14155552671'), '+14155552671');
  });

  test('rejects invalid numbers', () {
    for (final bad in ['12345', '5876543210', '+0123', '98765432101', '']) {
      expect(toE164(bad), isNull, reason: bad);
    }
  });

  test('cancelling Google sign-in shows no error', () async {
    final auth = _Auth();
    when(
      () => auth.signInWithGoogle(),
    ).thenThrow(const AuthException(AuthErrorKind.cancelled));
    final controller = SignInController(auth, _Session());
    await controller.signInWithGoogle();
    expect(controller.error.value, isNull);
    expect(controller.busy.value, isNull);
  });

  test('an invalid number never starts verification', () async {
    final auth = _Auth();
    final controller = SignInController(auth, _Session())
      ..phone.value = '12345';
    await controller.continueWithPhone();
    expect(controller.error.value, contains('valid mobile'));
    verifyNever(() => auth.startPhoneVerification(any()));
  });

  test('shows a hint once ten digits are typed but invalid', () {
    final controller = SignInController(_Auth(), _Session());
    controller.phone.value = '12345';
    expect(controller.phoneError, isNull);
    controller.phone.value = '1234567890';
    expect(controller.phoneError, isNotNull);
    controller.phone.value = '9876543210';
    expect(controller.phoneError, isNull);
  });
}
