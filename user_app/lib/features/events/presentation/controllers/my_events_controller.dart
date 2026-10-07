import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';

/// One paginated list (Upcoming or Past).
class EventListState {
  final Rx<ViewState<List<PlannerEvent>>> state =
      Rx<ViewState<List<PlannerEvent>>>(const Loading());
  final RxBool loadingMore = false.obs;
  final Rx<Failure?> moreError = Rx<Failure?>(null);
  String? nextCursor;
  bool loaded = false;
  int generation = 0;

  List<PlannerEvent> get items => switch (state.value) {
    Content(:final data) => data,
    _ => const [],
  };

  bool get hasMore => nextCursor != null;
}

/// My Events tab: upcoming and past events of the signed-in user.
class MyEventsController extends GetxController {
  MyEventsController(this._repository, this._session);

  static const pageSize = 20;

  final EventsRepository _repository;
  final SessionService _session;

  final Rx<EventScope> scope = EventScope.upcoming.obs;
  final Map<EventScope, EventListState> lists = {
    EventScope.upcoming: EventListState(),
    EventScope.past: EventListState(),
  };

  Worker? _sessionWorker;
  StreamSubscription<void>? _changes;

  bool get signedIn => _session.state.value is SignedInSession;

  EventListState get current => lists[scope.value]!;

  @override
  void onInit() {
    super.onInit();
    if (signedIn) unawaited(load(EventScope.upcoming));
    var wasSignedIn = signedIn;
    _sessionWorker = ever<SessionState>(_session.state, (_) {
      if (signedIn == wasSignedIn) return;
      wasSignedIn = signedIn;
      _reset();
      if (signedIn) unawaited(load(scope.value));
    });
    // Any create/edit/status change reloads what was already shown.
    _changes = _repository.changes.listen((_) {
      for (final entry in lists.entries) {
        if (entry.value.loaded) unawaited(load(entry.key));
      }
    });
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    unawaited(_changes?.cancel());
    super.onClose();
  }

  void selectScope(EventScope value) {
    scope.value = value;
    if (!lists[value]!.loaded && signedIn) unawaited(load(value));
  }

  /// First page (also used by pull-to-refresh and retry). Keeps shown items
  /// while refreshing.
  Future<void> load(EventScope which) async {
    final list = lists[which]!;
    final generation = ++list.generation;
    list.loaded = true;
    if (list.state.value is! Content) list.state.value = const Loading();
    list.moreError.value = null;
    final result = await _repository.list(scope: which, limit: pageSize);
    if (isClosed || generation != list.generation) return;
    switch (result) {
      case Ok(:final value):
        list.nextCursor = value.nextCursor;
        list.state.value = value.items.isEmpty
            ? const Empty()
            : Content(value.items);
      case Err(:final failure):
        // A failed refresh keeps the events on screen, marked as stale.
        final shown = list.items;
        list.state.value = shown.isEmpty
            ? Failed(failure)
            : Content(shown, isStale: true);
    }
  }

  /// Next page; failures show an inline retry under the list.
  Future<void> loadMore(EventScope which) async {
    final list = lists[which]!;
    final cursor = list.nextCursor;
    if (cursor == null || list.loadingMore.value) return;
    final generation = list.generation;
    list.loadingMore.value = true;
    list.moreError.value = null;
    final result = await _repository.list(
      scope: which,
      cursor: cursor,
      limit: pageSize,
    );
    list.loadingMore.value = false;
    if (isClosed || generation != list.generation) return;
    switch (result) {
      case Ok(:final value):
        list.nextCursor = value.nextCursor;
        list.state.value = Content([...list.items, ...value.items]);
      case Err(:final failure):
        list.moreError.value = failure;
    }
  }

  void _reset() {
    for (final list in lists.values) {
      list.generation++;
      list.loaded = false;
      list.nextCursor = null;
      list.loadingMore.value = false;
      list.moreError.value = null;
      list.state.value = const Loading();
    }
    scope.value = EventScope.upcoming;
  }
}
