import '../../../core/error/result.dart';
import '../domain/media_repository.dart';
import 'imagekit_uploader.dart';
import 'media_remote_data_source.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._remote, this._uploader);

  final MediaRemoteDataSource _remote;
  final ImageKitUploader _uploader;

  @override
  Future<Result<String>> uploadEventCover(
    String eventId,
    PickedPhoto photo, {
    void Function(double progress)? onProgress,
  }) async {
    final intent = await _remote.createUpload(
      eventId: eventId,
      contentType: photo.contentType,
      sizeBytes: photo.sizeBytes,
    );
    final UploadIntent upload;
    switch (intent) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        upload = value.data;
    }
    final uploaded = await _uploader.upload(
      upload,
      photo.path,
      onProgress: onProgress,
    );
    final String fileId;
    switch (uploaded) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        fileId = value;
    }
    final completed = await _remote.complete(upload.mediaId, fileId);
    return switch (completed) {
      Ok() => Ok(upload.mediaId),
      Err(:final failure) => Err(failure),
    };
  }
}
