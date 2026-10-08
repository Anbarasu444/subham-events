import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/network/error_mapper.dart';
import 'media_remote_data_source.dart';

/// Sends a file straight to ImageKit with a backend-issued v2 upload token
/// (media-and-deep-links.md §3). Its own Dio: another host, no auth header,
/// longer timeouts for uploads (architecture/flutter.md §5).
class ImageKitUploader {
  ImageKitUploader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 120),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  final Dio _dio;

  /// Returns ImageKit's `fileId`.
  Future<Result<String>> upload(
    UploadIntent intent,
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: intent.fields['fileName'],
        ),
        'token': intent.token,
        // Exactly the signed fields (folder, name, privacy, checks).
        ...intent.fields,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        intent.uploadUrl,
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      final fileId = response.data?['fileId'];
      return fileId is String
          ? Ok(fileId)
          : const Err(UnknownFailure(code: 'INVALID_RESPONSE'));
    } on DioException catch (e) {
      return Err(mapDioException(e));
    }
  }
}
