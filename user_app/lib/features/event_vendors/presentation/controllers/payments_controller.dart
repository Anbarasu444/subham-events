import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/payment.dart';

/// One booking's payments page (M16).
class PaymentsController extends GetxController {
  PaymentsController(this._repository, this.eventId, this.bookingId);

  final PaymentsRepository _repository;
  final String eventId;
  final String bookingId;

  final Rx<ViewState<PaymentList>> state = Rx<ViewState<PaymentList>>(
    const Loading(),
  );
  final RxSet<String> busy = <String>{}.obs;
  int _generation = 0;

  PaymentList? get list => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_generation;
    final current = list;
    if (current == null) state.value = const Loading();
    final result = await _repository.list(eventId, bookingId);
    if (isClosed || generation != _generation) return;
    state.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) =>
        current != null && failure.isRetryable
            ? Content(current, isStale: true)
            : Failed(failure),
    };
  }

  /// Returns the failure to show, or null.
  Future<Failure?> delete(Payment payment) async {
    if (busy.contains(payment.id)) return null;
    busy.add(payment.id);
    try {
      final result = await _repository.delete(eventId, bookingId, payment.id);
      if (isClosed) return null;
      await load();
      return switch (result) {
        Ok() || Err(failure: NotFoundFailure()) => null,
        Err(:final failure) => failure,
      };
    } finally {
      busy.remove(payment.id);
    }
  }
}
