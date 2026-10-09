import '../../../core/auth/session.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<MeProfile>> me() async =>
      _data(await _api.get('/me', decode: MeProfile.fromJson));

  @override
  Future<Result<MeProfile>> updateName(String displayName) async => _data(
    await _api.patch(
      '/me',
      body: {'displayName': displayName},
      decode: MeProfile.fromJson,
    ),
  );

  @override
  Future<Result<MeProfile>> setPhoto(String mediaId) async => _data(
    await _api.put(
      '/me/photo',
      body: {'mediaId': mediaId},
      decode: MeProfile.fromJson,
    ),
  );

  @override
  Future<Result<MeProfile>> removePhoto() async =>
      _data(await _api.delete('/me/photo', decode: MeProfile.fromJson));

  @override
  Future<Result<void>> deleteAccount() async => _data(
    await _api.post<void>(
      '/me/delete',
      body: {'confirm': 'DELETE'},
      decode: (_) {},
    ),
  );

  Result<T> _data<T>(Result<ApiResponse<T>> result) => switch (result) {
    Ok(:final value) => Ok(value.data),
    Err(:final failure) => Err(failure),
  };
}
