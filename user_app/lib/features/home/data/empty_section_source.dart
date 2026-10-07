import '../../../core/error/result.dart';
import '../../checklist/domain/repositories/checklist_repository.dart';
import '../../events/domain/repositories/events_repository.dart';
import 'checklist_progress_source.dart';
import '../domain/dashboard_section.dart';
import 'upcoming_event_source.dart';

/// Placeholder source until the feature that owns the section exists
/// (Budget → M11, Explore → M12; Upcoming event since M8, Checklist M9).
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
  EmptySectionSource(DashboardSectionId.budget, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.explore),
];

/// Sources used by the app: real data where the feature exists.
List<DashboardSectionSource> buildDashboardSources(
  EventsRepository events,
  ChecklistRepository checklists,
) => [
  UpcomingEventSource(events),
  ChecklistProgressSource(events, checklists),
  const EmptySectionSource(DashboardSectionId.budget, requiresSignIn: true),
  const EmptySectionSource(DashboardSectionId.explore),
];
