import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/features/event_vendors/domain/payment.dart';

/// In-memory payments with server-like totals.
class FakePaymentsRepository implements PaymentsRepository {
  FakePaymentsRepository({required this.agreed});

  final Money agreed;
  final List<Payment> payments = [];
  final List<String> calls = [];
  final List<String> idempotencyKeys = [];
  Failure? failNext;
  int _seq = 0;

  Result<T>? _failure<T>() {
    final f = failNext;
    failNext = null;
    return f == null ? null : Err(f);
  }

  static Money _inr(BigInt paise) {
    final digits = paise.toString().padLeft(3, '0');
    return Money.parse(
      '${digits.substring(0, digits.length - 2)}.'
          '${digits.substring(digits.length - 2)}',
      'INR',
    );
  }

  @override
  Future<Result<PaymentList>> list(String eventId, String bookingId) async {
    calls.add('list');
    final f = _failure<PaymentList>();
    if (f != null) return f;
    final paid = payments.fold(BigInt.zero, (s, p) => s + p.amount.minorUnits);
    final diff = agreed.minorUnits - paid;
    final sorted = [...payments]..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    return Ok(
      PaymentList(
        bookingId: bookingId,
        agreedAmount: agreed,
        paid: _inr(paid),
        balance: diff.isNegative ? null : _inr(diff),
        overpaidBy: diff.isNegative ? _inr(-diff) : null,
        payments: sorted,
      ),
    );
  }

  Payment _from(String id, PaymentInput input, int version) => Payment(
    id: id,
    amount: input.amount,
    paidOn: input.paidOn,
    method: input.method,
    kind: input.kind,
    note: input.note,
    version: version,
  );

  @override
  Future<Result<Payment>> add(
    String eventId,
    String bookingId,
    PaymentInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('add:${input.amount.amount}');
    idempotencyKeys.add(idempotencyKey);
    final f = _failure<Payment>();
    if (f != null) return f;
    final p = _from('p-${++_seq}', input, 1);
    payments.add(p);
    return Ok(p);
  }

  @override
  Future<Result<Payment>> update(
    String eventId,
    String bookingId,
    Payment payment,
    PaymentInput input,
  ) async {
    calls.add('update:${payment.id}:${input.amount.amount}');
    final f = _failure<Payment>();
    if (f != null) return f;
    final p = _from(payment.id, input, payment.version + 1);
    payments[payments.indexWhere((e) => e.id == payment.id)] = p;
    return Ok(p);
  }

  @override
  Future<Result<void>> delete(
    String eventId,
    String bookingId,
    String paymentId,
  ) async {
    calls.add('delete:$paymentId');
    payments.removeWhere((p) => p.id == paymentId);
    return const Ok(null);
  }
}
