import '../../../core/error/result.dart';
import '../../event_vendors/domain/event_vendor.dart';
import '../../events/domain/entities/planner_event.dart';
import '../../events/domain/repositories/events_repository.dart';
import '../../invitations/domain/invitation.dart';
import '../domain/dashboard_section.dart';

/// Vendor counts for the Home vendors donut (M22).
class VendorCounts {
  const VendorCounts({
    required this.booked,
    required this.quoted,
    required this.enquired,
    required this.added,
  });

  final int booked;
  final int quoted;
  final int enquired;
  final int added;

  int get total => booked + quoted + enquired + added;
}

class EventChartsData {
  const EventChartsData({
    required this.event,
    required this.vendors,
    required this.rsvps,
  });

  final PlannerEvent event;
  final VendorCounts vendors;

  /// Null when the event has no invitation yet.
  final RsvpTotals? rsvps;
}

/// Home charts (M22): vendors by stage and invitation replies for the next
/// planning event. Each part fails independently into "no data".
class EventChartsSource implements DashboardSectionSource {
  EventChartsSource(this._events, this._vendors, this._invitations);

  final EventsRepository _events;
  final EventVendorsRepository _vendors;
  final InvitationsRepository? _invitations;

  @override
  DashboardSectionId get id => DashboardSectionId.charts;

  @override
  bool get requiresSignIn => true;

  @override
  Stream<void>? get changes => _events.changes;

  @override
  Future<Result<SectionData>> load({required bool signedIn}) async {
    final upcoming = await _events.list(scope: EventScope.upcoming, limit: 1);
    final PlannerEvent event;
    switch (upcoming) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when value.items.isEmpty:
        return const Ok(null);
      case Ok(:final value):
        event = value.items.first;
    }
    final vendors = await _vendors.list(event.id);
    final VendorCounts counts;
    switch (vendors) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        int count(Set<EventVendorStatus> s) =>
            value.vendors.where((v) => s.contains(v.status)).length;
        counts = VendorCounts(
          booked: count({
            EventVendorStatus.booked,
            EventVendorStatus.completed,
          }),
          quoted: count({EventVendorStatus.quoted}),
          enquired: count({EventVendorStatus.enquired}),
          added: count({EventVendorStatus.added}),
        );
    }
    RsvpTotals? rsvps;
    final invitations = _invitations;
    if (invitations != null) {
      final inv = await invitations.get(event.id);
      if (inv case Ok(:final value?)) rsvps = value.totals;
    }
    return Ok(EventChartsData(event: event, vendors: counts, rsvps: rsvps));
  }
}
