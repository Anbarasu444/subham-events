import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/photo_picker.dart';
import '../../../../core/state/view_state.dart';
import '../../../media/domain/media_repository.dart';
import '../../domain/profile_repository.dart';

/// My profile (M21): name, photo and account deletion.
class ProfileController extends GetxController {
  ProfileController(this._repository, this._session, {this.media, this.picker});

  final ProfileRepository _repository;
  final SessionService _session;
  final MediaRepository? media;
  final PhotoPicker? picker;

  final Rx<ViewState<MeProfile>> state = Rx<ViewState<MeProfile>>(
    const Loading(),
  );
  final name = TextEditingController();
  final Rx<String?> nameError = Rx<String?>(null);
  final RxBool savingName = false.obs;
  final Rx<double?> photoProgress = Rx<double?>(null);
  final RxBool removingPhoto = false.obs;
  final RxBool deleting = false.obs;

  static const maxName = 60;

  MeProfile? get profile => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  bool get photoBusy => photoProgress.value != null || removingPhoto.value;

  @override
  void onInit() {
    super.onInit();
    final current = _session.state.value;
    if (current is SignedInSession) _show(current.profile);
    load();
  }

  @override
  void onClose() {
    name.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (profile == null) state.value = const Loading();
    final result = await _repository.me();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _apply(value);
      case Err(:final failure):
        state.value = profile != null && failure.isRetryable
            ? Content(profile!, isStale: true)
            : Failed(failure);
    }
  }

  void _show(MeProfile p) {
    state.value = Content(p);
    name.text = p.displayName ?? '';
  }

  void _apply(MeProfile p) {
    _show(p);
    _session.updateProfile(p);
  }

  /// Returns a message to show, or null on success / no change.
  Future<String?> saveName() async {
    final value = name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    nameError.value = value.isEmpty
        ? 'Enter your name.'
        : value.length > maxName
        ? 'Use at most $maxName characters.'
        : null;
    if (nameError.value != null || savingName.value) return null;
    if (value == profile?.displayName) return null;
    savingName.value = true;
    final result = await _repository.updateName(value);
    if (isClosed) return null;
    savingName.value = false;
    switch (result) {
      case Ok(:final value):
        _apply(value);
        return 'Name saved.';
      case Err(:final failure):
        return _message(failure);
    }
  }

  /// Returns a message to show, or null on success.
  Future<String?> changePhoto(PhotoSource source) async {
    final media = this.media, picker = this.picker, me = profile;
    if (media == null || picker == null || me == null || photoBusy) {
      return null;
    }
    final PickedPhoto? photo;
    try {
      photo = await picker.pick(source);
    } on Exception {
      return source == PhotoSource.camera
          ? 'The camera is not available. Check camera access in Settings.'
          : 'Your photos are not available. Check photo access in Settings.';
    }
    if (photo == null || isClosed) return null;
    if (photoTypeOf(photo.path) == null) {
      return 'Choose a JPEG, PNG, WebP or HEIC photo.';
    }
    if (photo.sizeBytes > coverMaxBytes) {
      return 'This photo is larger than 5 MB. Choose a smaller one.';
    }
    photoProgress.value = 0;
    final uploaded = await media.uploadProfilePhoto(
      me.id,
      photo,
      onProgress: (p) {
        if (!isClosed) photoProgress.value = p;
      },
    );
    final String mediaId;
    switch (uploaded) {
      case Err(:final failure):
        photoProgress.value = null;
        return _photoMessage(failure);
      case Ok(:final value):
        mediaId = value;
    }
    final result = await _repository.setPhoto(mediaId);
    if (isClosed) return null;
    photoProgress.value = null;
    switch (result) {
      case Ok(:final value):
        _apply(value);
        return null;
      case Err(:final failure):
        return _photoMessage(failure);
    }
  }

  Future<String?> removePhoto() async {
    if (photoBusy) return null;
    removingPhoto.value = true;
    final result = await _repository.removePhoto();
    if (isClosed) return null;
    removingPhoto.value = false;
    switch (result) {
      case Ok(:final value):
        _apply(value);
        return null;
      case Err(:final failure):
        return _message(failure);
    }
  }

  /// Deletes the account and signs out; returns a message on failure.
  Future<String?> deleteAccount() async {
    if (deleting.value) return null;
    deleting.value = true;
    final result = await _repository.deleteAccount();
    if (isClosed) return null;
    deleting.value = false;
    switch (result) {
      case Ok():
        await _session.accountDeleted();
        return null;
      case Err(:final failure):
        return _message(failure);
    }
  }

  static String _message(Failure failure) => switch (failure) {
    NetworkFailure() => 'You are offline. Check your connection and try again.',
    TimeoutFailure() => 'This took too long. Please try again.',
    ValidationFailure() => 'Please check your name.',
    RateLimitedFailure() => 'Too many changes. Please wait a moment.',
    _ => 'Something went wrong. Please try again.',
  };

  static String _photoMessage(Failure failure) => switch (failure) {
    ValidationFailure(code: 'MEDIA_INVALID', :final message) =>
      message ?? 'This photo could not be used. Try another one.',
    ServerFailure(statusCode: 503) =>
      'Photos are not available right now. Please try again later.',
    _ => _message(failure),
  };
}
