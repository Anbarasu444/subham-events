import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';

/// Menu → Checklist / Budget (M9, M11): the user's events being planned.
/// The view opens the page directly when there is exactly one.
class PlanningEventPickerController extends GetxController {
  PlanningEventPickerController(this._events);

  /// Plenty for a picker; more planning events than this is unusual.
  static const limit = 100;

  final EventsRepository _events;

  /// Set once the only event's checklist was opened, so rebuilds don't
  /// navigate twice.
  bool openedOnlyEvent = false;

  final Rx<ViewState<List<PlannerEvent>>> state =
      Rx<ViewState<List<PlannerEvent>>>(const Loading());

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    state.value = const Loading();
    final result = await _events.list(
      scope: EventScope.all,
      status: EventStatus.planning,
      limit: limit,
    );
    if (isClosed) return;
    state.value = switch (result) {
      Ok(:final value) when value.items.isEmpty => const Empty(),
      Ok(:final value) => Content(value.items),
      Err(:final failure) => Failed(failure),
    };
  }
}
