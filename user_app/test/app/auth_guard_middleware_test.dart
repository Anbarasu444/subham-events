import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/app/middlewares/auth_guard_middleware.dart';

void main() {
  test('guests are sent to sign-in with returnTo', () {
    final guard = AuthGuardMiddleware(isSignedIn: () => false);
    final redirect = guard.redirect('/account');
    expect(Uri.parse(redirect!.name!).path, '/sign-in');
    expect(Uri.parse(redirect.name!).queryParameters['returnTo'], '/account');
  });

  test('signed-in users pass', () {
    expect(
      AuthGuardMiddleware(isSignedIn: () => true).redirect('/account'),
      isNull,
    );
  });
}
