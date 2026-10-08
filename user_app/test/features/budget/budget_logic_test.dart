import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/core/state/view_state.dart';
import 'package:user_app/features/budget/data/budget_model.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/budget/domain/expense.dart';
import 'package:user_app/features/budget/presentation/controllers/budget_controller.dart';
import 'package:user_app/features/budget/presentation/controllers/expense_form_controller.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_events_repository.dart';

Money _inr(String amount) => Money.parse(amount, 'INR');
Map<String, String> _json(String amount) => {
  'amount': amount,
  'currency': 'INR',
};
Future<void> _settle() => Future<void>.delayed(Duration.zero);

Map<String, Object?> _budgetJson({
  required Object? unplanned,
  Object? remaining = const {'amount': '498499.50', 'currency': 'INR'},
}) => {
  'eventId': 'e1',
  'isEditable': true,
  'totalBudget': _json('500000.00'),
  'planned': _json('600000.00'),
  'unplanned': unplanned,
  'isOverPlanned': true,
  'committed': _json('0.00'),
  'paid': _json('0.00'),
  'expenses': _json('1500.50'),
  'spent': _json('1500.50'),
  'remaining': remaining,
  'categories': [
    {
      'categoryId': 'c1',
      'name': 'Venue',
      'planned': _json('600000.00'),
      'committed': _json('0.00'),
      'paid': _json('0.00'),
      'expenses': _json('1500.50'),
    },
    {
      'categoryId': 'c2',
      'name': 'Catering',
      'planned': null,
      'committed': _json('0.00'),
      'paid': _json('0.00'),
      'expenses': _json('0.00'),
    },
  ],
};

void main() {
  group('BudgetModel', () {
    test('turns a negative unplanned amount into "over by"', () {
      final budget = BudgetModel.fromJson(
        _budgetJson(unplanned: _json('-100000.00')),
      );
      expect(budget.unplanned, isNull);
      expect(budget.overPlannedBy, _inr('100000.00'));
      expect(budget.isOverPlanned, isTrue);
      expect(budget.plannedShare, 1); // capped
      expect(budget.lines.last.planned, isNull);
    });

    test('keeps a positive unplanned amount', () {
      final budget = BudgetModel.fromJson(
        _budgetJson(unplanned: _json('100.50')),
      );
      expect(budget.unplanned, _inr('100.50'));
      expect(budget.overPlannedBy, isNull);
      expect(budget.expenses, _inr('1500.50'));
      expect(budget.remaining, _inr('498499.50'));
      expect(budget.overspentBy, isNull);
      expect(budget.lines.first.expenses, _inr('1500.50'));
    });

    test('turns a negative remaining amount into "overspent by"', () {
      final budget = BudgetModel.fromJson(
        _budgetJson(unplanned: null, remaining: _json('-0.01')),
      );
      expect(budget.remaining, isNull);
      expect(budget.overspentBy, _inr('0.01'));
    });

    test('reads and writes expenses exactly', () {
      final list = BudgetModel.expenseListFromJson({
        'eventId': 'e1',
        'isEditable': true,
        'total': _json('10.10'),
        'expenses': [
          {
            'id': 'x1',
            'title': 'Flowers',
            'amount': _json('10.10'),
            'spentOn': '2026-09-01',
            'categoryId': null,
            'categoryName': null,
            'note': null,
            'version': 3,
          },
        ],
      });
      final expense = list.expenses.single;
      expect(expense.amount, _inr('10.10'));
      expect(expense.spentOn, DateTime(2026, 9, 1));
      expect(expense.version, 3);
      expect(
        BudgetModel.expenseToJson(
          ExpenseInput(
            title: 'Flowers',
            amount: _inr('10.10'),
            spentOn: DateTime(2026, 9, 1),
          ),
        ),
        {
          'title': 'Flowers',
          'amount': _json('10.10'),
          'spentOn': '2026-09-01',
          'categoryId': null,
          'note': null,
        },
      );
    });
  });

  group('BudgetController', () {
    late FakeEventsRepository events;
    late FakeBudgetRepository budgets;

    setUp(() {
      events = FakeEventsRepository(
        events: [testEvent('e1', date: DateTime(2026, 12, 1))],
      );
      budgets = FakeBudgetRepository(totals: {'e1': _inr('1000.00')});
    });

    test('plans and clears a category with exact amounts', () async {
      final c = BudgetController(budgets, events, 'e1')..onInit();
      await _settle();
      final venue = FakeBudgetRepository.idOf('Venue');
      expect(await c.setPlanned(venue, _inr('400.25')), isNull);
      expect(c.budget!.unplanned, _inr('599.75'));
      expect(await c.setPlanned(venue, _inr('1200.00')), isNull);
      expect(c.budget!.overPlannedBy, _inr('200.00'));
      expect(await c.clearPlanned(venue), isNull);
      expect(c.budget!.planned, _inr('0.00'));
      c.onClose();
    });

    test('a read-only rejection reloads and is reported', () async {
      final c = BudgetController(budgets, events, 'e1')..onInit();
      await _settle();
      budgets.failNext = const ConflictFailure(
        code: 'INVALID_STATE_TRANSITION',
      );
      final failure = await c.setPlanned('x', _inr('1.00'));
      expect(failure, isA<ConflictFailure>());
      await _settle();
      expect(budgets.calls.where((x) => x.startsWith('load:')), hasLength(2));
      c.onClose();
    });

    test('sets the total through the event', () async {
      final c = BudgetController(budgets, events, 'e1')..onInit();
      await _settle();
      expect(await c.setTotal(_inr('25000.00')), isNull);
      expect(events.events.single.totalBudget, _inr('25000.00'));
      expect(events.calls, contains('update:e1'));
      c.onClose();
    });

    test('a failed first load shows an error', () async {
      budgets.failNext = const NetworkFailure();
      final c = BudgetController(budgets, events, 'e1')..onInit();
      await _settle();
      expect(c.state.value, isA<Failed<Budget>>());
      c.onClose();
    });
  });

  group('ExpenseFormController', () {
    test(
      'a retry reuses the idempotency key; changed input gets a new one',
      () async {
        final budgets = FakeBudgetRepository();
        final c = ExpenseFormController(
          budgets,
          'e1',
          today: DateTime(2026, 10, 8),
        )..onInit();
        c.title.text = '  Flowers ';
        c.amount.text = '10.5';
        budgets.failNext = const NetworkFailure();
        expect(await c.submit(), isNull);
        expect(c.formError.value, contains('offline'));
        final saved = await c.submit();
        expect(saved?.title, 'Flowers');
        expect(saved?.amount, _inr('10.50'));
        expect(saved?.spentOn, DateTime(2026, 10, 8));
        expect(budgets.idempotencyKeys[0], budgets.idempotencyKeys[1]);
        c.amount.text = '11';
        await c.submit();
        expect(budgets.idempotencyKeys[2], isNot(budgets.idempotencyKeys[1]));
        c.onClose();
      },
    );
  });
}
