import '../../../core/error/result.dart';
import '../../budget/domain/budget.dart';
import '../../explore/domain/listing.dart';
import '../../checklist/domain/repositories/checklist_repository.dart';
import 'budget_overview_source.dart';
import '../../events/domain/repositories/events_repository.dart';
import 'checklist_progress_source.dart';
import 'explore_section_source.dart';
import '../domain/dashboard_section.dart';
import 'upcoming_event_source.dart';
import 'event_charts_source.dart';
import '../../event_vendors/domain/event_vendor.dart';
import '../../invitations/domain/invitation.dart';

/// Placeholder source until the feature that owns the section exists
/// (Upcoming event since M8, Checklist M9, Budget M11, Explore M12).
class EmptySectionSource implements DashboardSectionSource {
  const EmptySectionSource(this.id, {this.requiresSignIn = false});

  @override
  final DashboardSectionId id;

  @override
  final bool requiresSignIn;

  @override
  Stream<void>? get changes => null;

  @override
  Future<Result<SectionData>> load({required bool signedIn}) async =>
      const Ok(null);
}

/// Placeholder-only sources (tests and guests-only previews).
const defaultDashboardSources = <DashboardSectionSource>[
  EmptySectionSource(DashboardSectionId.upcomingEvent, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.checklist, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.charts, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.budget, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.explore),
];

/// Sources used by the app: real data where the feature exists.
List<DashboardSectionSource> buildDashboardSources(
  EventsRepository events,
  ChecklistRepository checklists,
  BudgetRepository budgets,
  DiscoveryRepository discovery, {
  EventVendorsRepository? vendors,
  InvitationsRepository? invitations,
}) => [
  UpcomingEventSource(events),
  ChecklistProgressSource(events, checklists),
  if (vendors != null)
    EventChartsSource(events, vendors, invitations)
  else
    const EmptySectionSource(DashboardSectionId.charts, requiresSignIn: true),
  BudgetOverviewSource(events, budgets),
  ExploreSectionSource(discovery, events),
];
