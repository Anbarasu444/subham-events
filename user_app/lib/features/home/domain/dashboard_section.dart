import '../../../core/error/result.dart';

/// Home dashboard sections, in display order (M7, Option A).
enum DashboardSectionId { upcomingEvent, checklist, budget, explore }

/// Data for one section. `null` means "nothing to show yet" (empty state).
/// Later milestones return their own content types (event summary, checklist
/// progress, budget totals, vendor suggestions).
typedef SectionData = Object?;

/// Loads one section independently, so a failure never blanks the page.
abstract class DashboardSectionSource {
  DashboardSectionId get id;

  /// Whether the section has signed-in-only content. Guests get the empty
  /// state without [load] being called, so no protected API is requested.
  bool get requiresSignIn;

  /// Emits when the section's data changed elsewhere (e.g. an event was
  /// edited), so the dashboard reloads just this section. Null if static.
  Stream<void>? get changes;

  Future<Result<SectionData>> load({required bool signedIn});
}
