import '../../../core/error/result.dart';
import '../../events/domain/entities/planner_event.dart';
import '../../events/domain/repositories/events_repository.dart';
import '../domain/dashboard_section.dart';

/// Upcoming-event section data. [next] is null when the user only has past
/// or cancelled events.
class UpcomingEventSummary {
  const UpcomingEventSummary({required this.next});
  final PlannerEvent? next;
}

/// Next planning event of the signed-in user (M8). `Ok(null)` = no events at
/// all, which shows the section's empty state.
class UpcomingEventSource implements DashboardSectionSource {
  UpcomingEventSource(this._events);

  final EventsRepository _events;

  @override
  DashboardSectionId get id => DashboardSectionId.upcomingEvent;

  @override
  bool get requiresSignIn => true;

  @override
  Stream<void>? get changes => _events.changes;

  @override
  Future<Result<SectionData>> load({required bool signedIn}) async {
    final upcoming = await _events.list(scope: EventScope.upcoming, limit: 1);
    switch (upcoming) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when value.items.isNotEmpty:
        return Ok(UpcomingEventSummary(next: value.items.first));
      case Ok():
    }
    // No upcoming event: does the user have any events at all?
    final any = await _events.list(scope: EventScope.all, limit: 1);
    return switch (any) {
      Err(:final failure) => Err(failure),
      Ok(:final value) =>
        value.items.isEmpty
            ? const Ok(null)
            : const Ok(UpcomingEventSummary(next: null)),
    };
  }
}
