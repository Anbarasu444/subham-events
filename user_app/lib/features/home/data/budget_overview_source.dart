import '../../../core/error/result.dart';
import '../../budget/domain/budget.dart';
import '../../events/domain/entities/planner_event.dart';
import '../../events/domain/repositories/events_repository.dart';
import '../domain/dashboard_section.dart';

class BudgetOverviewData {
  const BudgetOverviewData({required this.event, required this.budget});
  final PlannerEvent event;
  final Budget budget;
}

/// Home "Budget overview" (M11): the next event's total, planned and
/// unplanned amounts. `Ok(null)` (no upcoming event) shows the empty state.
class BudgetOverviewSource implements DashboardSectionSource {
  BudgetOverviewSource(this._events, this._budgets);

  final EventsRepository _events;
  final BudgetRepository _budgets;

  @override
  DashboardSectionId get id => DashboardSectionId.budget;

  @override
  bool get requiresSignIn => true;

  /// Budget changes are announced through the events stream as well.
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
    final budget = await _budgets.load(event.id);
    return switch (budget) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => Ok(BudgetOverviewData(event: event, budget: value)),
    };
  }
}
