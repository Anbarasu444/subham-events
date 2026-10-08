import '../../../core/error/result.dart';
import '../../../core/platform/photo_picker.dart';

export '../../../core/platform/photo_picker.dart' show PickedPhoto;

/// Media uploads (M10): ask the backend for an upload, send the file to
/// ImageKit, then let the backend verify it.
abstract class MediaRepository {
  /// Returns the verified media id. [onProgress] gets 0.0–1.0.
  Future<Result<String>> uploadEventCover(
    String eventId,
    PickedPhoto photo, {
    void Function(double progress)? onProgress,
  });
}

/// Cover photos are limited to 5 MB (M10 answer).
const coverMaxBytes = 5 * 1024 * 1024;
