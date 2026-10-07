import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/core/auth/auth_service.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/auth/presentation/bindings/auth_bindings.dart';
import 'package:user_app/features/auth/presentation/controllers/otp_controller.dart';
import 'package:user_app/features/auth/presentation/controllers/sign_in_controller.dart';

class _Auth extends Mock implements AuthService {}

class _Session extends Mock implements SessionService {}

const _profile = MeProfile(id: 'u1', roles: ['USER']);
const _args = OtpArgs(
  phoneE164: '+919800000001',
  verificationId: 'v1',
  returnTo: '/?tab=events',
);

void main() {
  late _Auth auth;
  late _Session session;
  late StreamController<AuthUser?> authState;
  late List<String> routes;
  late OtpController controller;

  setUp(() {
    auth = _Auth();
    session = _Session();
    authState = StreamController<AuthUser?>.broadcast();
    routes = [];
    when(() => auth.authStateChanges()).thenAnswer((_) => authState.stream);
    controller = OtpController(auth, session, _args, navigateTo: routes.add)
      ..onInit();
  });

  tearDown(() {
    controller.onClose();
    authState.close();
  });

  test('a correct code signs in and returns to the requested route', () async {
    when(
      () => auth.confirmSmsCode('v1', '123456'),
    ).thenAnswer((_) async => const AuthUser(uid: 'x'));
    when(
      () => session.completeSignIn(),
    ).thenAnswer((_) async => const Ok(_profile));
    controller.onCodeChanged('123456');
    await Future<void>.delayed(Duration.zero);
    expect(routes, ['/?tab=events']);
  });

  test('a wrong code shows a message and clears the field', () async {
    when(
      () => auth.confirmSmsCode(any(), any()),
    ).thenThrow(const AuthException(AuthErrorKind.invalidCode));
    controller.codeField.text = '000000';
    controller.onCodeChanged('000000');
    await Future<void>.delayed(Duration.zero);
    expect(controller.error.value, contains('not correct'));
    expect(controller.codeField.text, isEmpty);
    expect(routes, isEmpty);
  });

  test(
    'if the backend step fails, retry does not ask for the code again',
    () async {
      when(
        () => auth.confirmSmsCode('v1', '123456'),
      ).thenAnswer((_) async => const AuthUser(uid: 'x'));
      when(
        () => session.completeSignIn(),
      ).thenAnswer((_) async => const Err(ServerFailure(statusCode: 503)));
      controller.onCodeChanged('123456');
      await Future<void>.delayed(Duration.zero);
      expect(controller.error.value, isNotNull);

      when(
        () => session.completeSignIn(),
      ).thenAnswer((_) async => const Ok(_profile));
      await controller.submit();
      verify(() => auth.confirmSmsCode(any(), any())).called(1);
      expect(routes, ['/?tab=events']);
    },
  );

  test(
    'Android auto-verification after the code was sent finishes sign-in',
    () async {
      when(
        () => session.completeSignIn(),
      ).thenAnswer((_) async => const Ok(_profile));
      authState.add(const AuthUser(uid: 'x'));
      await Future<void>.delayed(Duration.zero);
      expect(routes, ['/?tab=events']);
    },
  );

  test('resend is blocked during the countdown', () async {
    expect(controller.secondsLeft.value, 30);
    await controller.resend();
    verifyNever(
      () => auth.startPhoneVerification(
        any(),
        resendToken: any(named: 'resendToken'),
      ),
    );
  });

  test('only known shell routes are accepted as returnTo', () {
    expect(safeReturnTo('/?tab=events'), '/?tab=events');
    expect(safeReturnTo('/?tab=menu'), '/?tab=menu');
    expect(safeReturnTo('/?tab=../x'), isNull);
    expect(safeReturnTo('/diagnostics'), isNull);
    expect(safeReturnTo('https://evil.example'), isNull);
    expect(safeReturnTo(null), isNull);
  });
}
