import '../../../../core/error/result.dart';
import '../entities/planner_event.dart';

enum EventScope { upcoming, past, all }

class EventsPage {
  const EventsPage({required this.items, required this.nextCursor});
  final List<PlannerEvent> items;

  /// Null when there are no more pages.
  final String? nextCursor;
  bool get hasMore => nextCursor != null;
}

/// The signed-in user's events (api-contracts.md Part B, M8).
abstract class EventsRepository {
  /// Emits after any successful change, so lists and the dashboard reload.
  Stream<void> get changes;

  /// Announces a change made through another feature that alters what an
  /// event shows (e.g. checklist progress, M9).
  void notifyChanged();

  Future<Result<EventsPage>> list({
    required EventScope scope,
    String? cursor,
    int limit = 20,
    EventStatus? status,
  });

  Future<Result<PlannerEvent>> get(String id);

  /// [idempotencyKey] is created once per form submission intent and reused
  /// on retries, so a retried create never duplicates the event.
  Future<Result<PlannerEvent>> create(
    EventInput input, {
    required String idempotencyKey,
  });

  Future<Result<PlannerEvent>> update(PlannerEvent current, EventInput input);

  Future<Result<PlannerEvent>> cancel(String id);
  Future<Result<PlannerEvent>> reopen(String id);
  Future<Result<PlannerEvent>> complete(String id);
  Future<Result<void>> delete(String id);
}
