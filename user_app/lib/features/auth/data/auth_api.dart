import '../../../core/auth/session.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';

class SessionResponse {
  const SessionResponse(this.profile, {required this.isNewUser});
  final MeProfile profile;
  final bool isNewUser;
}

/// Backend auth endpoints (api-contracts.md Part B).
class AuthApi {
  const AuthApi(this._api);
  final ApiClient _api;

  Future<Result<SessionResponse>> createSession() async {
    final result = await _api.post(
      '/auth/session',
      decode: (data) {
        final map = data! as Map<String, dynamic>;
        return SessionResponse(
          MeProfile.fromJson(map['user']),
          isNewUser: map['isNewUser'] as bool,
        );
      },
    );
    return switch (result) {
      Ok(:final value) => Ok(value.data),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<MeProfile>> me() async {
    final result = await _api.get('/me', decode: MeProfile.fromJson);
    return switch (result) {
      Ok(:final value) => Ok(value.data),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void>> signOut() async {
    final result = await _api.post<void>('/auth/sign-out', decode: (_) {});
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}
