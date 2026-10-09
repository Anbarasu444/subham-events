import 'dart:ui' show Rect;

import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/platform/external_actions.dart';
import 'package:user_app/core/platform/photo_picker.dart';
import 'package:user_app/features/media/domain/media_repository.dart';

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([this.next]);

  /// Returned by the next pick (null = user cancelled).
  PickedPhoto? next;
  final List<PhotoSource> picks = [];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    picks.add(source);
    return next;
  }
}

class FakeMediaRepository implements MediaRepository {
  Failure? failNext;
  final List<String> uploads = [];
  int _seq = 0;

  @override
  Future<Result<String>> uploadEventCover(
    String eventId,
    PickedPhoto photo, {
    void Function(double progress)? onProgress,
  }) async {
    uploads.add('$eventId:${photo.path}');
    onProgress?.call(0.5);
    final failure = failNext;
    failNext = null;
    if (failure != null) return Err(failure);
    onProgress?.call(1);
    return Ok('media-${++_seq}');
  }
}

class FakeExternalActions implements ExternalActions {
  final List<String> maps = [];
  final List<String> shared = [];
  bool mapsAvailable = true;

  @override
  Future<bool> openMaps(String query) async {
    maps.add(query);
    return mapsAvailable;
  }

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    shared.add(text);
  }

  final List<String> calls = [];
  final List<String> emails = [];

  @override
  Future<bool> call(String phone) async {
    calls.add(phone);
    return true;
  }

  @override
  Future<bool> email(String address, {String? subject}) async {
    emails.add(address);
    return true;
  }

  /// (fileName, text, byte count) of each shared picture.
  final List<(String, String?, int)> images = [];

  @override
  Future<void> shareImage(
    List<int> pngBytes, {
    required String fileName,
    String? text,
    Rect? origin,
  }) async {
    images.add((fileName, text, pngBytes.length));
  }
}

const photo = PickedPhoto(
  path: '/tmp/cover.jpg',
  sizeBytes: 1024 * 1024,
  contentType: 'image/jpeg',
);
