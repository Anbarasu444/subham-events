import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

/// Upload parameters from `POST /media/uploads` (ImageKit upload API v2).
/// [fields] are signed into [token]; they must be sent unchanged, or
/// ImageKit rejects the upload. The token works once.
class UploadIntent {
  const UploadIntent({
    required this.mediaId,
    required this.uploadUrl,
    required this.token,
    required this.fields,
  });

  factory UploadIntent.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return UploadIntent(
      mediaId: map['mediaId'] as String,
      uploadUrl: map['uploadUrl'] as String,
      token: map['token'] as String,
      fields: (map['fields'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
  }

  final String mediaId;
  final String uploadUrl;
  final String token;
  final Map<String, String> fields;
}

class MediaRemoteDataSource {
  const MediaRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<ApiResponse<UploadIntent>>> createUpload({
    required String ownerId,
    required String contentType,
    required int sizeBytes,
    String kind = 'EVENT_COVER',
  }) => _api.post(
    '/media/uploads',
    body: {
      'kind': kind,
      'ownerId': ownerId,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    },
    decode: UploadIntent.fromJson,
  );

  Future<Result<ApiResponse<void>>> complete(String mediaId, String fileId) =>
      _api.post(
        '/media/uploads/$mediaId/complete',
        body: {'fileId': fileId},
        decode: (_) {},
      );
}
