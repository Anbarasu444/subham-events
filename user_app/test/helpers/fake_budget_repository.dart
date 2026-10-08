import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/budget/domain/expense.dart';

/// In-memory budgets: categories are fixed; totals come from [totals].
class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository({
    this.categories = const ['Venue', 'Catering', 'Photography'],
    Map<String, Money?>? totals,
    this.readOnlyEvents = const {},
    this.archived = const [],
    this.onChanged,
  }) : totals = {...?totals};

  final List<String> categories;
  final Map<String, Money?> totals;
  final Set<String> readOnlyEvents;

  /// No longer offered: listed only while an event has a plan for them.
  final List<String> archived;
  final void Function()? onChanged;
  final Map<String, Map<String, Money>> planned = {};
  final Map<String, List<Expense>> expenses = {};
  final List<String> calls = [];
  final List<String> idempotencyKeys = [];
  Failure? failNext;
  Failure? failExpensesNext;
  int _nextId = 0;

  static String idOf(String name) => 'cat-${name.toLowerCase()}';

  Result<T>? _failure<T>() {
    final failure = failNext;
    failNext = null;
    return failure == null ? null : Err(failure);
  }

  static Money _inr(BigInt paise) => Money.parse(_amount(paise), 'INR');

  Budget budgetOf(String eventId) {
    final plans = planned[eventId] ?? const {};
    final spent = expenses[eventId] ?? const <Expense>[];
    final zero = Money.parse('0.00', 'INR');
    BigInt sumOf(Iterable<Money> values) =>
        values.fold(BigInt.zero, (s, m) => s + m.minorUnits);
    final sum = sumOf(plans.values);
    final expenseSum = sumOf(spent.map((e) => e.amount));
    Money byCategory(String id) => _inr(
      sumOf(spent.where((e) => e.categoryId == id).map((e) => e.amount)),
    );
    final total = totals[eventId];
    final diff = total == null ? null : total.minorUnits - sum;
    final left = total == null ? null : total.minorUnits - expenseSum;
    BudgetLine line(String name, {bool isArchived = false}) => BudgetLine(
      categoryId: idOf(name),
      name: name,
      isArchived: isArchived,
      planned: plans[idOf(name)],
      committed: zero,
      paid: zero,
      expenses: byCategory(idOf(name)),
    );
    return Budget(
      eventId: eventId,
      isEditable: !readOnlyEvents.contains(eventId),
      totalBudget: total,
      planned: _inr(sum),
      unplanned: diff == null || diff.isNegative ? null : _inr(diff),
      overPlannedBy: diff != null && diff.isNegative ? _inr(-diff) : null,
      committed: zero,
      paid: zero,
      expenses: _inr(expenseSum),
      spent: _inr(expenseSum),
      remaining: left == null || left.isNegative ? null : _inr(left),
      overspentBy: left != null && left.isNegative ? _inr(-left) : null,
      lines: [
        for (final name in categories) line(name),
        for (final name in archived)
          if (plans[idOf(name)] != null ||
              spent.any((e) => e.categoryId == idOf(name)))
            line(name, isArchived: true),
      ],
    );
  }

  static String _amount(BigInt paise) {
    final digits = paise.toString().padLeft(3, '0');
    return '${digits.substring(0, digits.length - 2)}.'
        '${digits.substring(digits.length - 2)}';
  }

  String? _nameOf(String? categoryId) => categoryId == null
      ? null
      : [
          ...categories,
          ...archived,
        ].firstWhere((n) => idOf(n) == categoryId, orElse: () => 'Other');

  @override
  Future<Result<Budget>> load(String eventId) async {
    calls.add('load:$eventId');
    return _failure() ?? Ok(budgetOf(eventId));
  }

  @override
  Future<Result<Budget>> setPlanned(
    String eventId,
    String categoryId,
    Money amount,
  ) async {
    calls.add('set:$categoryId:${amount.amount}');
    final failure = _failure<Budget>();
    if (failure != null) return failure;
    (planned[eventId] ??= {})[categoryId] = amount;
    onChanged?.call();
    return Ok(budgetOf(eventId));
  }

  @override
  Future<Result<Budget>> clearPlanned(String eventId, String categoryId) async {
    calls.add('clear:$categoryId');
    final failure = _failure<Budget>();
    if (failure != null) return failure;
    planned[eventId]?.remove(categoryId);
    onChanged?.call();
    return Ok(budgetOf(eventId));
  }

  @override
  Future<Result<ExpenseList>> loadExpenses(String eventId) async {
    calls.add('loadExpenses:$eventId');
    final failure = failExpensesNext;
    failExpensesNext = null;
    if (failure != null) return Err(failure);
    final list = [...?expenses[eventId]]
      ..sort((a, b) => b.spentOn.compareTo(a.spentOn));
    return Ok(
      ExpenseList(
        eventId: eventId,
        isEditable: !readOnlyEvents.contains(eventId),
        total: budgetOf(eventId).expenses,
        expenses: list,
      ),
    );
  }

  /// Seeds an expense directly (no call recorded).
  Expense seedExpense(
    String eventId,
    String title,
    Money amount,
    DateTime spentOn, {
    String? category,
    String? note,
  }) {
    final expense = Expense(
      id: 'exp-${++_nextId}',
      title: title,
      amount: amount,
      spentOn: spentOn,
      categoryId: category == null ? null : idOf(category),
      categoryName: category,
      note: note,
      version: 1,
    );
    (expenses[eventId] ??= []).add(expense);
    return expense;
  }

  @override
  Future<Result<Expense>> addExpense(
    String eventId,
    ExpenseInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('addExpense:${input.title}:${input.amount.amount}');
    idempotencyKeys.add(idempotencyKey);
    final failure = _failure<Expense>();
    if (failure != null) return failure;
    final expense = Expense(
      id: 'exp-${++_nextId}',
      title: input.title,
      amount: input.amount,
      spentOn: input.spentOn,
      categoryId: input.categoryId,
      categoryName: _nameOf(input.categoryId),
      note: input.note,
      version: 1,
    );
    (expenses[eventId] ??= []).add(expense);
    onChanged?.call();
    return Ok(expense);
  }

  @override
  Future<Result<Expense>> updateExpense(
    String eventId,
    Expense expense,
    ExpenseInput input,
  ) async {
    calls.add('updateExpense:${expense.id}:${input.amount.amount}');
    final failure = _failure<Expense>();
    if (failure != null) return failure;
    final list = expenses[eventId]!;
    final updated = Expense(
      id: expense.id,
      title: input.title,
      amount: input.amount,
      spentOn: input.spentOn,
      categoryId: input.categoryId,
      categoryName: _nameOf(input.categoryId),
      note: input.note,
      version: expense.version + 1,
    );
    list[list.indexWhere((e) => e.id == expense.id)] = updated;
    onChanged?.call();
    return Ok(updated);
  }

  @override
  Future<Result<void>> deleteExpense(String eventId, Expense expense) async {
    calls.add('deleteExpense:${expense.id}');
    final failure = _failure<void>();
    if (failure != null) return failure;
    expenses[eventId]?.removeWhere((e) => e.id == expense.id);
    onChanged?.call();
    return const Ok(null);
  }
}
