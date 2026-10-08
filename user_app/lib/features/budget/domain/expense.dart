import '../../../core/money/money.dart';

/// One of the user's own expenses for an event (M11, answer 5): money spent
/// outside platform bookings. A note only — no money moves through the app.
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.spentOn,
    required this.categoryId,
    required this.categoryName,
    required this.note,
    required this.version,
  });

  final String id;
  final String title;

  /// Always more than zero.
  final Money amount;

  /// Calendar date (local midnight).
  final DateTime spentOn;
  final String? categoryId;
  final String? categoryName;
  final String? note;
  final int version;
}

/// What the user typed in the expense sheet (already validated).
class ExpenseInput {
  const ExpenseInput({
    required this.title,
    required this.amount,
    required this.spentOn,
    this.categoryId,
    this.note,
  });

  final String title;
  final Money amount;
  final DateTime spentOn;
  final String? categoryId;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is ExpenseInput &&
      other.title == title &&
      other.amount == amount &&
      other.spentOn == spentOn &&
      other.categoryId == categoryId &&
      other.note == note;

  @override
  int get hashCode => Object.hash(title, amount, spentOn, categoryId, note);
}

/// An event's own expenses, newest first, with their exact total.
class ExpenseList {
  const ExpenseList({
    required this.eventId,
    required this.isEditable,
    required this.total,
    required this.expenses,
  });

  final String eventId;
  final bool isEditable;
  final Money total;
  final List<Expense> expenses;
}
