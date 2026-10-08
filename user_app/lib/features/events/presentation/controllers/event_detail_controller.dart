import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';
import '../../../media/domain/media_repository.dart';
import '../../../../core/platform/photo_picker.dart';

enum EventCommand { cancel, reopen, complete, delete }

/// One event's home screen (M8, tabs and cover photo in M10) and its actions.
class EventDetailController extends GetxController {
  EventDetailController(
    this._repository,
    this.eventId, {
    PlannerEvent? initial,
    this.media,
    this.picker,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       state = Rx<ViewState<PlannerEvent>>(
         initial == null ? const Loading() : Content(initial),
       );

  final EventsRepository _repository;

  /// Cover uploads; null where photos are not available (e.g. some tests).
  final MediaRepository? media;
  final PhotoPicker? picker;
  final String eventId;
  final DateTime Function() _clock;

  /// Cover upload progress 0.0–1.0; null when no upload is running.
  final Rx<double?> coverProgress = Rx<double?>(null);

  /// The cover is being removed.
  final RxBool removingCover = false.obs;

  bool get coverBusy => coverProgress.value != null || removingCover.value;

  bool get canChangeCover => media != null && picker != null;

  final Rx<ViewState<PlannerEvent>> state;
  final Rx<EventCommand?> running = Rx<EventCommand?>(null);

  DateTime get today => dateOnly(_clock());

  PlannerEvent? get event => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  StreamSubscription<void>? _changes;

  @override
  void onInit() {
    super.onInit();
    load();
    // Checklist progress (or an edit elsewhere) changes what this page shows.
    _changes = _repository.changes.listen((_) {
      if (running.value == null) load();
    });
  }

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    if (event == null) state.value = const Loading();
    final result = await _repository.get(eventId);
    // An older response arriving last must not replace a newer one.
    if (isClosed || generation != _generation) return;
    state.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) =>
        event != null && failure is! NotFoundFailure
            ? Content(event!, isStale: true)
            : Failed(failure),
    };
  }

  /// Picks, checks and uploads a cover photo, then makes it the cover.
  /// Returns a message to show, or null on success or cancel.
  Future<String?> changeCover(PhotoSource source) async {
    final media = this.media, picker = this.picker;
    if (media == null || picker == null || coverBusy) return null;
    final PickedPhoto? photo;
    try {
      photo = await picker.pick(source);
    } on Exception {
      return source == PhotoSource.camera
          ? 'The camera is not available. Check camera access in Settings.'
          : 'Your photos are not available. Check photo access in Settings.';
    }
    if (photo == null || isClosed) return null; // cancelled
    if (photoTypeOf(photo.path) == null) {
      return 'Choose a JPEG, PNG, WebP or HEIC photo.';
    }
    if (photo.sizeBytes > coverMaxBytes) {
      return 'This photo is larger than 5 MB. Choose a smaller one.';
    }
    coverProgress.value = 0;
    final uploaded = await media.uploadEventCover(
      eventId,
      photo,
      onProgress: (p) {
        if (!isClosed) coverProgress.value = p;
      },
    );
    final String mediaId;
    switch (uploaded) {
      case Err(:final failure):
        coverProgress.value = null;
        return _coverMessage(failure);
      case Ok(:final value):
        mediaId = value;
    }
    final result = await _repository.setCover(eventId, mediaId);
    if (isClosed) return null;
    coverProgress.value = null;
    switch (result) {
      case Ok(:final value):
        state.value = Content(value);
        return null;
      case Err(:final failure):
        return _coverMessage(failure);
    }
  }

  /// Returns a message to show, or null on success.
  Future<String?> removeCover() async {
    if (coverBusy) return null;
    removingCover.value = true;
    final result = await _repository.removeCover(eventId);
    if (isClosed) return null;
    removingCover.value = false;
    switch (result) {
      case Ok(:final value):
        state.value = Content(value);
        return null;
      case Err(:final failure):
        return _coverMessage(failure);
    }
  }

  static String _coverMessage(Failure failure) => switch (failure) {
    ValidationFailure(code: 'MEDIA_INVALID', :final message) =>
      message ?? 'This photo could not be used. Try another one.',
    ServerFailure(statusCode: 503) =>
      'Photos are not available right now. Please try again later.',
    NetworkFailure() => 'You are offline. Check your connection and try again.',
    TimeoutFailure() => 'The upload took too long. Please try again.',
    NotFoundFailure() => 'This event no longer exists.',
    RateLimitedFailure() => 'Too many uploads. Please wait a moment.',
    _ => 'The photo could not be uploaded. Please try again.',
  };

  /// Shows the edited event without another request.
  void replace(PlannerEvent updated) => state.value = Content(updated);

  /// Runs an action; returns null on success or the failure to show.
  Future<Failure?> run(EventCommand command) async {
    if (running.value != null) return null;
    running.value = command;
    final Result<Object?> result = switch (command) {
      EventCommand.cancel => await _repository.cancel(eventId),
      EventCommand.reopen => await _repository.reopen(eventId),
      EventCommand.complete => await _repository.complete(eventId),
      EventCommand.delete => await _repository.delete(eventId),
    };
    if (isClosed) return null;
    running.value = null;
    switch (result) {
      case Ok(:final value):
        if (value is PlannerEvent) state.value = Content(value);
        return null;
      case Err(:final failure):
        // The event changed elsewhere: show the current server state.
        if (failure is ConflictFailure) await load();
        return failure;
    }
  }
}
