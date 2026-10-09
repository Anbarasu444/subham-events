import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/state/view_state.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../domain/budget.dart';
import '../../domain/expense.dart';

/// One event's budget (M11). The server computes every figure; this
/// controller only loads, sends changes and shows the returned budget.
class BudgetController extends GetxController {
  BudgetController(this._budgets, this._events, this.eventId);

  final BudgetRepository _budgets;
  final EventsRepository _events;
  final String eventId;

  final Rx<ViewState<Budget>> state = Rx<ViewState<Budget>>(const Loading());

  /// The user's own expenses (answer 5), loaded next to the budget.
  final Rx<ViewState<ExpenseList>> expenses = Rx<ViewState<ExpenseList>>(
    const Loading(),
  );

  /// Category ids, `total` or expense ids with a request in flight.
  final RxSet<String> busy = <String>{}.obs;

  /// Category filter pills (M22): all, planned, spending or over.
  final RxString lineFilter = 'all'.obs;

  int _generation = 0;
  int _expenseGeneration = 0;
  StreamSubscription<void>? _changes;

  Budget? get budget => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    // The total lives on the event: an edit elsewhere changes the budget.
    _changes = _events.changes.listen((_) {
      if (busy.isEmpty) unawaited(load());
    });
  }

  @override
  void onClose() {
    unawaited(_changes?.cancel());
    super.onClose();
  }

  /// Loads the budget and the expenses together.
  Future<void> load() async {
    await Future.wait([_loadBudget(), loadExpenses()]);
  }

  Future<void> loadExpenses() async {
    final generation = ++_expenseGeneration;
    final current = switch (expenses.value) {
      Content(:final data) => data,
      _ => null,
    };
    if (current == null) expenses.value = const Loading();
    final result = await _budgets.loadExpenses(eventId);
    if (isClosed || generation != _expenseGeneration) return;
    expenses.value = switch (result) {
      Ok(:final value) =>
        value.expenses.isEmpty ? const Empty() : Content(value),
      Err(:final failure) =>
        current != null && failure is! NotFoundFailure
            ? Content(current, isStale: true)
            : Failed(failure),
    };
  }

  /// After an expense was added or edited in its sheet.
  Future<void> expenseSaved() => load();

  /// Returns the failure to show, or null.
  Future<Failure?> deleteExpense(Expense expense) async {
    if (busy.contains(expense.id)) return null;
    busy.add(expense.id);
    try {
      final result = await _budgets.deleteExpense(eventId, expense);
      if (isClosed) return null;
      // Deleted, or read only / gone: either way show the server's state.
      await load();
      return switch (result) {
        Ok() || Err(failure: NotFoundFailure()) => null,
        Err(:final failure) => failure,
      };
    } finally {
      busy.remove(expense.id);
    }
  }

  Future<void> _loadBudget() async {
    final generation = ++_generation;
    if (budget == null) state.value = const Loading();
    final result = await _budgets.load(eventId);
    if (isClosed || generation != _generation) return;
    state.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) =>
        budget != null && failure is! NotFoundFailure
            ? Content(budget!, isStale: true)
            : Failed(failure),
    };
  }

  /// Returns the failure to show, or null.
  Future<Failure?> setPlanned(String categoryId, Money planned) =>
      _run(categoryId, () => _budgets.setPlanned(eventId, categoryId, planned));

  Future<Failure?> clearPlanned(String categoryId) =>
      _run(categoryId, () => _budgets.clearPlanned(eventId, categoryId));

  /// Changes the event's total budget (null clears it) through the event.
  Future<Failure?> setTotal(Money? total) async {
    if (busy.contains('total')) return null;
    busy.add('total');
    try {
      final current = await _events.get(eventId);
      final PlannerEvent event;
      switch (current) {
        case Err(:final failure):
          return failure;
        case Ok(:final value):
          event = value;
      }
      final result = await _events.update(
        event,
        EventInput(
          eventType: event.eventType,
          title: event.title,
          eventDate: event.eventDate,
          city: event.city,
          startTime: event.startTime,
          venueName: event.venueName,
          venueAddress: event.venueAddress,
          guestCountEstimate: event.guestCountEstimate,
          totalBudget: total,
        ),
      );
      if (result case Err(:final failure)) {
        // Changed elsewhere or gone: show the current budget.
        if (failure is ConflictFailure || failure is NotFoundFailure) {
          unawaited(load());
        }
        return failure;
      }
      await load();
      return null;
    } finally {
      busy.remove('total');
    }
  }

  Future<Failure?> _run(
    String key,
    Future<Result<Budget>> Function() request,
  ) async {
    if (busy.contains(key)) return null;
    busy.add(key);
    // Newest request wins: an older load or change finishing later must
    // not overwrite this result.
    final generation = ++_generation;
    final result = await request();
    busy.remove(key);
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        if (generation == _generation) {
          state.value = Content(value);
        } else {
          unawaited(load());
        }
        return null;
      case Err(:final failure):
        // Read only now, or gone: show the server's current budget.
        if (failure is ConflictFailure || failure is NotFoundFailure) {
          unawaited(load());
        }
        return failure;
    }
  }
}
