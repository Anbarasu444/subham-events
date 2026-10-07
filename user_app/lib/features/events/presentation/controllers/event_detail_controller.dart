import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';

enum EventCommand { cancel, reopen, complete, delete }

/// One event's summary page and its actions (M8; rich details in M10).
class EventDetailController extends GetxController {
  EventDetailController(
    this._repository,
    this.eventId, {
    PlannerEvent? initial,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       state = Rx<ViewState<PlannerEvent>>(
         initial == null ? const Loading() : Content(initial),
       );

  final EventsRepository _repository;
  final String eventId;
  final DateTime Function() _clock;

  final Rx<ViewState<PlannerEvent>> state;
  final Rx<EventCommand?> running = Rx<EventCommand?>(null);

  DateTime get today => dateOnly(_clock());

  PlannerEvent? get event => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (event == null) state.value = const Loading();
    final result = await _repository.get(eventId);
    if (isClosed) return;
    state.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) =>
        event != null && failure is! NotFoundFailure
            ? Content(event!, isStale: true)
            : Failed(failure),
    };
  }

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
