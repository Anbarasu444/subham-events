import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/profile/domain/profile_repository.dart';

/// In-memory profile following the server rules (enough for widgets).
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([MeProfile? profile])
    : profile =
          profile ??
          MeProfile(
            id: 'u1',
            roles: const ['USER'],
            displayName: 'Priya Sharma',
            phone: '+919800000001',
            createdAt: DateTime(2026, 1, 15),
          );

  MeProfile profile;
  final List<String> calls = [];
  Failure? failNext;
  bool deleted = false;

  Result<T>? _failure<T>() {
    final f = failNext;
    failNext = null;
    return f == null ? null : Err(f);
  }

  MeProfile _copy({String? name, String? photo, bool clearPhoto = false}) =>
      MeProfile(
        id: profile.id,
        roles: profile.roles,
        displayName: name ?? profile.displayName,
        phone: profile.phone,
        email: profile.email,
        createdAt: profile.createdAt,
        photoMediaId: clearPhoto ? null : (photo ?? profile.photoMediaId),
        photoUrl: clearPhoto
            ? null
            : (photo == null ? profile.photoUrl : 'https://img.test/$photo'),
        photoThumbnailUrl: clearPhoto
            ? null
            : (photo == null
                  ? profile.photoThumbnailUrl
                  : 'https://img.test/$photo?t'),
      );

  @override
  Future<Result<MeProfile>> me() async {
    calls.add('me');
    return _failure() ?? Ok(profile);
  }

  @override
  Future<Result<MeProfile>> updateName(String displayName) async {
    calls.add('name:$displayName');
    return _failure() ?? Ok(profile = _copy(name: displayName));
  }

  @override
  Future<Result<MeProfile>> setPhoto(String mediaId) async {
    calls.add('photo:$mediaId');
    return _failure() ?? Ok(profile = _copy(photo: mediaId));
  }

  @override
  Future<Result<MeProfile>> removePhoto() async {
    calls.add('removePhoto');
    return _failure() ?? Ok(profile = _copy(clearPhoto: true));
  }

  @override
  Future<Result<void>> deleteAccount() async {
    calls.add('delete');
    final f = _failure<void>();
    if (f != null) return f;
    deleted = true;
    return const Ok(null);
  }
}
