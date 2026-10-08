import '../../../core/error/result.dart';
import '../../../core/money/money.dart';

enum PaymentMethod {
  cash('Cash'),
  upi('UPI'),
  bankTransfer('Bank transfer'),
  card('Card'),
  cheque('Cheque'),
  other('Other');

  const PaymentMethod(this.label);
  final String label;

  String get api => switch (this) {
    PaymentMethod.bankTransfer => 'BANK_TRANSFER',
    _ => name.toUpperCase(),
  };

  static PaymentMethod fromApi(String value) => value == 'BANK_TRANSFER'
      ? PaymentMethod.bankTransfer
      : PaymentMethod.values.byName(value.toLowerCase());
}

enum PaymentKind {
  advance('Advance'),
  instalment('Instalment'),
  finalPayment('Final payment'),
  other('Other');

  const PaymentKind(this.label);
  final String label;

  String get api => switch (this) {
    PaymentKind.finalPayment => 'FINAL',
    _ => name.toUpperCase(),
  };

  static PaymentKind fromApi(String value) => value == 'FINAL'
      ? PaymentKind.finalPayment
      : PaymentKind.values.byName(value.toLowerCase());
}

/// The user's private record of a payment to a booked vendor (M16, R5).
/// No money moves through the app.
class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.paidOn,
    required this.method,
    required this.kind,
    required this.note,
    required this.version,
  });

  final String id;
  final Money amount;
  final DateTime paidOn;
  final PaymentMethod method;
  final PaymentKind kind;
  final String? note;
  final int version;
}

class PaymentInput {
  const PaymentInput({
    required this.amount,
    required this.paidOn,
    required this.method,
    required this.kind,
    this.note,
  });

  final Money amount;
  final DateTime paidOn;
  final PaymentMethod method;
  final PaymentKind kind;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is PaymentInput &&
      other.amount == amount &&
      other.paidOn == paidOn &&
      other.method == method &&
      other.kind == kind &&
      other.note == note;

  @override
  int get hashCode => Object.hash(amount, paidOn, method, kind, note);
}

/// A booking's payments with server-computed totals.
class PaymentList {
  const PaymentList({
    required this.bookingId,
    required this.agreedAmount,
    required this.paid,
    required this.balance,
    required this.overpaidBy,
    required this.payments,
  });

  final String bookingId;
  final Money agreedAmount;
  final Money paid;

  /// Null when overpaid.
  final Money? balance;
  final Money? overpaidBy;

  /// Newest first.
  final List<Payment> payments;
}

/// Payments on a booking (api-contracts.md Part B, M16).
abstract class PaymentsRepository {
  Future<Result<PaymentList>> list(String eventId, String bookingId);
  Future<Result<Payment>> add(
    String eventId,
    String bookingId,
    PaymentInput input, {
    required String idempotencyKey,
  });
  Future<Result<Payment>> update(
    String eventId,
    String bookingId,
    Payment payment,
    PaymentInput input,
  );
  Future<Result<void>> delete(
    String eventId,
    String bookingId,
    String paymentId,
  );
}
