import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/request_id.dart';
import '../../domain/budget.dart';
import '../../domain/expense.dart';

/// Add or edit one own expense (title 1–120, amount > 0, note ≤ 1000).
class ExpenseFormController extends GetxController {
  ExpenseFormController(
    this._repository,
    this.eventId, {
    this.existing,
    DateTime? today,
  }) : _today = today ?? dateOnly(DateTime.now());

  final BudgetRepository _repository;
  final String eventId;
  final Expense? existing;
  final DateTime _today;

  late final title = TextEditingController(text: existing?.title);
  late final amount = TextEditingController(
    text: existing?.amount.toInputText(),
  );
  late final note = TextEditingController(text: existing?.note);
  late final Rx<DateTime> spentOn = (existing?.spentOn ?? _today).obs;
  late final Rx<String?> categoryId = Rx<String?>(existing?.categoryId);

  final Rx<String?> titleError = Rx<String?>(null);
  final Rx<String?> amountError = Rx<String?>(null);
  final Rx<String?> noteError = Rx<String?>(null);
  final Rx<String?> formError = Rx<String?>(null);
  final RxBool saving = false.obs;

  String _idempotencyKey = generateRequestId();
  ExpenseInput? _lastAttempt;

  bool get isEdit => existing != null;

  @override
  void onClose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    super.onClose();
  }

  Future<Expense?> submit() async {
    if (saving.value) return null;
    formError.value = null;
    final input = _read();
    if (input == null) return null;
    saving.value = true;
    final result = isEdit
        ? await _repository.updateExpense(eventId, existing!, input)
        : await _repository.addExpense(
            eventId,
            input,
            idempotencyKey: _keyFor(input),
          );
    if (isClosed) return null;
    saving.value = false;
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        formError.value = _message(failure);
        return null;
    }
  }

  ExpenseInput? _read() {
    final titleText = title.text.trim();
    final noteText = note.text.trim();
    final money = Money.tryParseInput(amount.text);
    titleError.value = titleText.isEmpty
        ? 'Enter what the money was for.'
        : titleText.length > 120
        ? 'Use at most 120 characters.'
        : null;
    amountError.value = money == null
        ? 'Enter an amount like 1500 or 1500.50.'
        : money.minorUnits == BigInt.zero
        ? 'The amount must be more than ₹0.'
        : null;
    noteError.value = noteText.length > 1000
        ? 'Use at most 1000 characters.'
        : null;
    if (titleError.value != null ||
        amountError.value != null ||
        noteError.value != null) {
      return null;
    }
    return ExpenseInput(
      title: titleText,
      amount: money!,
      spentOn: spentOn.value,
      categoryId: categoryId.value,
      note: noteText.isEmpty ? null : noteText,
    );
  }

  /// Same input → same key (a retry never duplicates); changed input → new key.
  String _keyFor(ExpenseInput input) {
    final last = _lastAttempt;
    if (last != null && last != input) _idempotencyKey = generateRequestId();
    _lastAttempt = input;
    return _idempotencyKey;
  }

  static String _message(Failure failure) => switch (failure) {
    ConflictFailure(code: 'LIMIT_REACHED') =>
      'This event already has 500 expenses. Remove some to add more.',
    ConflictFailure(code: 'INVALID_STATE_TRANSITION') =>
      'This event is no longer being planned, so its budget is read only.',
    ConflictFailure() =>
      'This expense was changed on another device. Close and open it again.',
    NotFoundFailure() => 'This expense no longer exists.',
    ValidationFailure() => 'Please check the details.',
    NetworkFailure() => 'You are offline. Check your connection and try again.',
    TimeoutFailure() => 'The server did not respond in time. Try again.',
    RateLimitedFailure() => 'Too many attempts. Please wait a moment.',
    _ => 'Something went wrong. Please try again.',
  };
}
