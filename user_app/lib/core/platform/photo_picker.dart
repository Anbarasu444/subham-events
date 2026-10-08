import 'dart:io';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { gallery, camera }

/// Picks a photo, downscaled on the device so uploads stay small.
abstract class PhotoPicker {
  /// Null when the user cancels.
  Future<PickedPhoto?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
    );
    if (file == null) return null;
    final type = photoTypeOf(file.path) ?? 'image/jpeg';
    return PickedPhoto(
      path: file.path,
      sizeBytes: await File(file.path).length(),
      contentType: type,
    );
  }
}

/// A photo chosen on the device, ready to upload.
class PickedPhoto {
  const PickedPhoto({
    required this.path,
    required this.sizeBytes,
    required this.contentType,
  });

  final String path;
  final int sizeBytes;

  /// `image/jpeg`, `image/png`, `image/webp`, `image/heic` or `image/heif`.
  final String contentType;
}

const allowedPhotoTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
};

/// Content type from the file name, or null if not an allowed photo.
String? photoTypeOf(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return null;
  return allowedPhotoTypes[path.substring(dot + 1).toLowerCase()];
}
