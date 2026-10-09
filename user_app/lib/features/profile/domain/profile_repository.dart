import '../../../core/auth/session.dart';
import '../../../core/error/result.dart';

/// The signed-in user's profile and account (api-contracts.md, M21).
abstract class ProfileRepository {
  Future<Result<MeProfile>> me();
  Future<Result<MeProfile>> updateName(String displayName);
  Future<Result<MeProfile>> setPhoto(String mediaId);
  Future<Result<MeProfile>> removePhoto();

  /// Marks the account deleted (R11: data kept; signing in restores it).
  Future<Result<void>> deleteAccount();
}
