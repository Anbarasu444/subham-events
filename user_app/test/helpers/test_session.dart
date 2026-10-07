import 'package:mocktail/mocktail.dart';
import 'package:user_app/core/auth/auth_service.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/storage/secure_store.dart';
import 'package:user_app/features/auth/data/auth_api.dart';

import 'recording_reporter.dart';

class _Auth extends Mock implements AuthService {}

class _Api extends Mock implements AuthApi {}

class _Store extends Mock implements SecureStore {}

const testProfile = MeProfile(
  id: 'u1',
  roles: ['USER'],
  displayName: 'Priya Sharma',
);

/// SessionService in a fixed [state]; no Firebase or network involved.
SessionService testSession(SessionState state) => SessionService(
  auth: _Auth(),
  api: _Api(),
  store: _Store(),
  reporter: RecordingReporter(),
  clearPrivateMedia: () async {},
)..state.value = state;
