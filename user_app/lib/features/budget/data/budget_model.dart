import '../../../core/money/money.dart';
import '../../../core/utils/date_format.dart';
import '../domain/budget.dart';
import '../domain/expense.dart';

/// JSON mapping for `BudgetDto` and expenses (M11). Only `unplanned` and
/// `remaining` can be negative; they become [Budget.overPlannedBy] and
/// [Budget.overspentBy], so [Money] stays non-negative in the app.
abstract final class BudgetModel {
  static Budget fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    final (unplanned, overPlannedBy) = _split(map['unplanned']);
    final (remaining, overspentBy) = _split(map['remaining']);
    return Budget(
      eventId: map['eventId'] as String,
      isEditable: map['isEditable'] as bool,
      totalBudget: _maybe(map['totalBudget']),
      planned: _money(map['planned']),
      unplanned: unplanned,
      overPlannedBy: overPlannedBy,
      committed: _money(map['committed']),
      paid: _money(map['paid']),
      expenses: _money(map['expenses']),
      spent: _money(map['spent']),
      remaining: remaining,
      overspentBy: overspentBy,
      lines: (map['categories'] as List<dynamic>)
          .map((raw) {
            final line = raw as Map<String, dynamic>;
            return BudgetLine(
              categoryId: line['categoryId'] as String,
              name: line['name'] as String,
              isArchived: line['isArchived'] as bool? ?? false,
              planned: _maybe(line['planned']),
              committed: _money(line['committed']),
              paid: _money(line['paid']),
              expenses: _money(line['expenses']),
            );
          })
          .toList(growable: false),
    );
  }

  static ExpenseList expenseListFromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return ExpenseList(
      eventId: map['eventId'] as String,
      isEditable: map['isEditable'] as bool,
      total: _money(map['total']),
      expenses: (map['expenses'] as List<dynamic>)
          .map(expenseFromJson)
          .toList(growable: false),
    );
  }

  static Expense expenseFromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: _money(map['amount']),
      spentOn: parseApiDate(map['spentOn'] as String),
      categoryId: map['categoryId'] as String?,
      categoryName: map['categoryName'] as String?,
      note: map['note'] as String?,
      version: map['version'] as int,
    );
  }

  static Map<String, dynamic> expenseToJson(ExpenseInput input) => {
    'title': input.title,
    'amount': input.amount.toJson(),
    'spentOn': formatApiDate(input.spentOn),
    'categoryId': input.categoryId,
    'note': input.note,
  };

  /// A possibly negative amount → (value when ≥ 0, excess when negative).
  static (Money?, Money?) _split(Object? json) {
    if (json == null) return (null, null);
    final map = json as Map<String, dynamic>;
    final amount = map['amount'] as String;
    if (!amount.startsWith('-')) return (_money(map), null);
    return (null, Money.parse(amount.substring(1), map['currency'] as String));
  }

  static Money _money(Object? json) =>
      Money.fromJson(json as Map<String, dynamic>);

  static Money? _maybe(Object? json) => json == null ? null : _money(json);
}
