import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/core/auth/auth_service.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/network/interceptors/auth_interceptor.dart';
import 'package:user_app/core/storage/secure_store.dart';
import 'package:user_app/features/auth/data/auth_api.dart';

import '../../helpers/recording_reporter.dart';

class _Auth extends Mock implements AuthService {}

class _Api extends Mock implements AuthApi {}

class _Store implements SecureStore {
  final values = <String, String>{};
  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

const _profile = MeProfile(id: 'u1', roles: ['USER'], phone: '+919800000001');

void main() {
  late _Auth auth;
  late _Api api;
  late _Store store;
  late int cacheClears;
  late SessionService session;

  setUp(() {
    auth = _Auth();
    api = _Api();
    store = _Store();
    cacheClears = 0;
    when(() => auth.signOut()).thenAnswer((_) async {});
    session = SessionService(
      auth: auth,
      api: api,
      store: store,
      reporter: RecordingReporter(),
      clearPrivateMedia: () async => cacheClears++,
    );
  });

  test('restore without a Firebase user is a guest session', () async {
    when(() => auth.currentUser).thenReturn(null);
    await session.restore();
    expect(session.state.value, isA<GuestSession>());
  });

  test('restore with a registered user loads /me', () async {
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'x'));
    when(() => api.me()).thenAnswer((_) async => const Ok(_profile));
    await session.restore();
    expect((session.state.value as SignedInSession).profile.id, 'u1');
  });

  test(
    'restore registers the user when the backend does not know them yet',
    () async {
      when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'x'));
      when(() => api.me()).thenAnswer(
        (_) async => const Err(UnauthorizedFailure(code: 'AUTH_REQUIRED')),
      );
      when(() => api.createSession()).thenAnswer(
        (_) async => const Ok(SessionResponse(_profile, isNewUser: true)),
      );
      await session.restore();
      expect(session.isSignedIn, isTrue);
    },
  );

  test('completeSignIn failure signs out locally', () async {
    when(() => api.createSession()).thenAnswer(
      (_) async => const Err(ForbiddenFailure(code: 'ACCOUNT_SUSPENDED')),
    );
    final result = await session.completeSignIn();
    expect(result, isA<Err<MeProfile>>());
    expect(session.state.value, isA<GuestSession>());
    verify(() => auth.signOut()).called(1);
  });

  test('sign-out revokes on the server and clears local data', () async {
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'x'));
    when(() => api.signOut()).thenAnswer((_) async => const Ok(null));
    when(() => api.createSession()).thenAnswer(
      (_) async => const Ok(SessionResponse(_profile, isNewUser: false)),
    );
    await session.completeSignIn();
    store.values['session.profile_label'] = 'left by an older build';

    await session.signOut();
    verify(() => api.signOut()).called(1);
    expect(store.values, isEmpty);
    expect(cacheClears, 1);
    expect(session.state.value, isA<GuestSession>());
  });

  test('server-ended sessions sign out with a message', () async {
    session.onSessionInvalid(SessionInvalidReason.suspended);
    await Future<void>.delayed(Duration.zero);
    final state = session.state.value as GuestSession;
    expect(state.message, contains('suspended'));
  });

  test('a server error at start-up keeps the Firebase session', () async {
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'x'));
    when(
      () => api.me(),
    ).thenAnswer((_) async => const Err(ServerFailure(statusCode: 503)));
    await session.restore();
    expect(session.state.value, isA<ProfilePendingSession>());
    verifyNever(() => auth.signOut());

    when(() => api.me()).thenAnswer((_) async => const Ok(_profile));
    await session.retry();
    expect(session.isSignedIn, isTrue);
  });

  test(
    'a temporary failure after sign-in keeps the Firebase identity',
    () async {
      when(
        () => api.createSession(),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      await session.completeSignIn();
      verifyNever(() => auth.signOut());
      expect(session.state.value, isA<ProfilePendingSession>());
    },
  );

  test('revoked at start-up signs out with a message', () async {
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'x'));
    when(() => api.me()).thenAnswer(
      (_) async => const Err(UnauthorizedFailure(code: 'AUTH_TOKEN_REVOKED')),
    );
    await session.restore();
    expect(
      (session.state.value as GuestSession).message,
      contains('signed out'),
    );
  });

  test('concurrent sign-outs keep the first message', () async {
    session.onSessionInvalid(SessionInvalidReason.deleted);
    await session.signOut();
    expect((session.state.value as GuestSession).message, contains('deleted'));
    verify(() => auth.signOut()).called(1);
  });
}
