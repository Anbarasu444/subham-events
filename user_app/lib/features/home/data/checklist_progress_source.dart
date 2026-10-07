import '../../../core/error/result.dart';
import '../../checklist/domain/entities/checklist_item.dart';
import '../../checklist/domain/repositories/checklist_repository.dart';
import '../../events/domain/entities/planner_event.dart';
import '../../events/domain/repositories/events_repository.dart';
import '../domain/dashboard_section.dart';

/// Checklist progress of the next event plus its most urgent open tasks.
class ChecklistProgressData {
  const ChecklistProgressData({required this.event, required this.nextTasks});

  final PlannerEvent event;

  /// Up to three open tasks: overdue first, then by due date, then order.
  final List<ChecklistItem> nextTasks;
}

/// Home "Checklist progress" section (M9). `Ok(null)` (no upcoming event)
/// shows the section's empty state.
class ChecklistProgressSource implements DashboardSectionSource {
  ChecklistProgressSource(this._events, this._checklists);

  static const maxTasks = 3;

  final EventsRepository _events;
  final ChecklistRepository _checklists;

  @override
  DashboardSectionId get id => DashboardSectionId.checklist;

  @override
  bool get requiresSignIn => true;

  /// Checklist changes are announced through the events stream as well.
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
    if (event.checklist.pending == 0) {
      return Ok(ChecklistProgressData(event: event, nextTasks: const []));
    }
    final checklist = await _checklists.load(event.id);
    return switch (checklist) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => Ok(
        ChecklistProgressData(event: event, nextTasks: urgentFirst(value)),
      ),
    };
  }

  static List<ChecklistItem> urgentFirst(Checklist checklist) {
    final open = [...checklist.pending]
      ..sort((a, b) {
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        final ad = a.dueDate, bd = b.dueDate;
        if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
        if ((ad == null) != (bd == null)) return ad == null ? 1 : -1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return open.take(maxTasks).toList(growable: false);
  }
}
