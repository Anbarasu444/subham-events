import '../../../core/error/result.dart';
import '../../../core/money/money.dart';
import 'expense.dart';

/// One vendor category's line in an event budget (M11).
class BudgetLine {
  const BudgetLine({
    required this.categoryId,
    required this.name,
    this.isArchived = false,
    required this.planned,
    required this.committed,
    required this.paid,
    required this.expenses,
  });

  final String categoryId;
  final String name;

  /// No longer offered; listed only because it has a plan or expenses.
  final bool isArchived;

  /// Null when nothing is planned for this category.
  final Money? planned;

  /// Agreed amounts of confirmed bookings (M15); zero until then.
  final Money committed;

  /// The user's payment notes (M16); zero until then.
  final Money paid;

  /// The user's own expenses with this category.
  final Money expenses;
}

/// An event's budget, computed by the server with exact decimals
/// (domain-model.md §7). Without a total budget [unplanned], [overPlannedBy]
/// and [remaining] are null. When the plan exceeds the total, [unplanned]
/// is null and [overPlannedBy] holds the excess (money stays non-negative).
/// Likewise, when bookings and own expenses pass the total, [remaining] is
/// null and [overspentBy] holds the excess.
class Budget {
  const Budget({
    required this.eventId,
    required this.isEditable,
    required this.totalBudget,
    required this.planned,
    required this.unplanned,
    required this.overPlannedBy,
    required this.committed,
    required this.paid,
    required this.expenses,
    required this.spent,
    required this.remaining,
    required this.overspentBy,
    required this.lines,
  });

  final String eventId;
  final bool isEditable;
  final Money? totalBudget;
  final Money planned;
  final Money? unplanned;
  final Money? overPlannedBy;
  final Money committed;
  final Money paid;

  /// The user's own expenses (all of them, with or without a category).
  final Money expenses;

  /// Paid + own expenses.
  final Money spent;

  /// Total − committed − own expenses.
  final Money? remaining;
  final Money? overspentBy;
  final List<BudgetLine> lines;

  bool get isOverPlanned => overPlannedBy != null;

  /// Categories a new expense can use (offered ones only).
  List<BudgetLine> get offeredLines =>
      lines.where((l) => !l.isArchived).toList(growable: false);

  /// Share of the total that is planned (0–1, capped), or null.
  double? get plannedShare {
    final total = totalBudget;
    if (total == null || total.minorUnits == BigInt.zero) return null;
    final share = planned.minorUnits / total.minorUnits;
    return share > 1 ? 1 : share;
  }
}

/// An event's budget (api-contracts.md Part B, M11).
abstract class BudgetRepository {
  Future<Result<Budget>> load(String eventId);
  Future<Result<Budget>> setPlanned(
    String eventId,
    String categoryId,
    Money planned,
  );
  Future<Result<Budget>> clearPlanned(String eventId, String categoryId);

  Future<Result<ExpenseList>> loadExpenses(String eventId);
  Future<Result<Expense>> addExpense(
    String eventId,
    ExpenseInput input, {
    required String idempotencyKey,
  });
  Future<Result<Expense>> updateExpense(
    String eventId,
    Expense expense,
    ExpenseInput input,
  );
  Future<Result<void>> deleteExpense(String eventId, Expense expense);
}
