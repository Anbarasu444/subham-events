import '../../../core/error/result.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/date_format.dart';
import '../domain/payment.dart';

/// Network-only. Changes call [_onChanged] so budgets and event screens
/// refresh.
class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl(this._api, this._onChanged);

  final ApiClient _api;
  final void Function() _onChanged;

  String _path(String eventId, String bookingId) =>
      '/events/$eventId/bookings/$bookingId/payments';

  @override
  Future<Result<PaymentList>> list(String eventId, String bookingId) async =>
      _data(
        await _api.get(_path(eventId, bookingId), decode: listFromJson),
        notify: false,
      );

  @override
  Future<Result<Payment>> add(
    String eventId,
    String bookingId,
    PaymentInput input, {
    required String idempotencyKey,
  }) async => _data(
    await _api.post(
      _path(eventId, bookingId),
      body: toJson(input),
      idempotencyKey: idempotencyKey,
      decode: paymentFromJson,
    ),
  );

  @override
  Future<Result<Payment>> update(
    String eventId,
    String bookingId,
    Payment payment,
    PaymentInput input,
  ) async => _data(
    await _api.patch(
      '${_path(eventId, bookingId)}/${payment.id}',
      body: {...toJson(input), 'version': payment.version},
      decode: paymentFromJson,
    ),
  );

  @override
  Future<Result<void>> delete(
    String eventId,
    String bookingId,
    String paymentId,
  ) async => _data(
    await _api.delete(
      '${_path(eventId, bookingId)}/$paymentId',
      decode: (_) {},
    ),
  );

  Result<T> _data<T>(Result<ApiResponse<T>> result, {bool notify = true}) {
    switch (result) {
      case Ok(:final value):
        if (notify) _onChanged();
        return Ok(value.data);
      case Err(:final failure):
        return Err(failure);
    }
  }

  static Map<String, dynamic> toJson(PaymentInput input) => {
    'amount': input.amount.toJson(),
    'paidOn': formatApiDate(input.paidOn),
    'method': input.method.api,
    'kind': input.kind.api,
    'note': input.note,
  };

  static Payment paymentFromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return Payment(
      id: map['id'] as String,
      amount: Money.fromJson(map['amount'] as Map<String, dynamic>),
      paidOn: parseApiDate(map['paidOn'] as String),
      method: PaymentMethod.fromApi(map['method'] as String),
      kind: PaymentKind.fromApi(map['kind'] as String),
      note: map['note'] as String?,
      version: map['version'] as int,
    );
  }

  static PaymentList listFromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    Money? maybe(Object? v) =>
        v == null ? null : Money.fromJson(v as Map<String, dynamic>);
    return PaymentList(
      bookingId: map['bookingId'] as String,
      agreedAmount: Money.fromJson(map['agreedAmount'] as Map<String, dynamic>),
      paid: Money.fromJson(map['paid'] as Map<String, dynamic>),
      balance: maybe(map['balance']),
      overpaidBy: maybe(map['overpaidBy']),
      payments: (map['payments'] as List<dynamic>)
          .map(paymentFromJson)
          .toList(growable: false),
    );
  }
}
