import '../../../core/error/result.dart';
import '../domain/dashboard_section.dart';

/// Placeholder source until the feature that owns the section exists
/// (Upcoming event → M8, Checklist → M9, Budget → M11, Explore → M12).
class EmptySectionSource implements DashboardSectionSource {
  const EmptySectionSource(this.id, {this.requiresSignIn = false});

  @override
  final DashboardSectionId id;

  @override
  final bool requiresSignIn;

  @override
  Future<Result<SectionData>> load({required bool signedIn}) async =>
      const Ok(null);
}

const defaultDashboardSources = <DashboardSectionSource>[
  EmptySectionSource(DashboardSectionId.upcomingEvent, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.checklist, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.budget, requiresSignIn: true),
  EmptySectionSource(DashboardSectionId.explore),
];
