import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/request_id.dart';
import '../../domain/payment.dart';

/// Add or edit one payment (amount > 0, date not in the future, M16).
class PaymentFormController extends GetxController {
  PaymentFormController(
    this._repository,
    this.eventId,
    this.bookingId, {
    this.existing,
    DateTime? today,
  }) : today = today ?? dateOnly(DateTime.now());

  final PaymentsRepository _repository;
  final String eventId;
  final String bookingId;
  final Payment? existing;
  final DateTime today;

  late final amount = TextEditingController(
    text: existing?.amount.toInputText(),
  );
  late final note = TextEditingController(text: existing?.note);
  late final Rx<DateTime> paidOn = (existing?.paidOn ?? today).obs;
  late final Rx<PaymentMethod> method =
      (existing?.method ?? PaymentMethod.upi).obs;
  late final Rx<PaymentKind> kind = (existing?.kind ?? PaymentKind.advance).obs;

  final Rx<String?> amountError = Rx<String?>(null);
  final Rx<String?> formError = Rx<String?>(null);
  final RxBool saving = false.obs;

  String _idempotencyKey = generateRequestId();
  PaymentInput? _lastAttempt;

  bool get isEdit => existing != null;

  @override
  void onClose() {
    amount.dispose();
    note.dispose();
    super.onClose();
  }

  Future<Payment?> submit() async {
    if (saving.value) return null;
    formError.value = null;
    final money = Money.tryParseInput(amount.text);
    amountError.value = money == null
        ? 'Enter an amount like 50000 or 50000.50.'
        : money.minorUnits == BigInt.zero
        ? 'The amount must be more than ₹0.'
        : null;
    if (amountError.value != null) return null;
    final noteText = note.text.trim();
    final input = PaymentInput(
      amount: money!,
      paidOn: paidOn.value,
      method: method.value,
      kind: kind.value,
      note: noteText.isEmpty ? null : noteText,
    );
    // Same input → same key: a retry never records the payment twice.
    if (_lastAttempt != null && _lastAttempt != input) {
      _idempotencyKey = generateRequestId();
    }
    _lastAttempt = input;
    saving.value = true;
    final result = isEdit
        ? await _repository.update(eventId, bookingId, existing!, input)
        : await _repository.add(
            eventId,
            bookingId,
            input,
            idempotencyKey: _idempotencyKey,
          );
    if (isClosed) return null;
    saving.value = false;
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        formError.value = switch (failure) {
          ConflictFailure(code: 'LIMIT_REACHED') =>
            'This booking already has 100 payments.',
          ConflictFailure() =>
            'This payment was changed on another device. Close and try again.',
          NotFoundFailure() => 'This booking or payment no longer exists.',
          ValidationFailure() => 'Please check the amount and date.',
          NetworkFailure() =>
            'You are offline. Check your connection and try again.',
          TimeoutFailure() => 'The server did not respond in time. Try again.',
          RateLimitedFailure() => 'Too many attempts. Please wait a moment.',
          _ => 'Something went wrong. Please try again.',
        };
        return null;
    }
  }
}
