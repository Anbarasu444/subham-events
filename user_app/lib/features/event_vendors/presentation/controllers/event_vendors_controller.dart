import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/request_id.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../domain/event_vendor.dart';

/// An event's Vendors tab (M14): list, notes, remove and enquiry actions.
/// The server owns every state change; the list reloads after each.
class EventVendorsController extends GetxController {
  EventVendorsController(this._vendors, this._events, this.eventId);

  final EventVendorsRepository _vendors;
  final EventsRepository _events;
  final String eventId;

  final Rx<ViewState<EventVendorList>> state = Rx<ViewState<EventVendorList>>(
    const Loading(),
  );

  /// Event vendor ids with a request in flight.
  final RxSet<String> busy = <String>{}.obs;

  int _generation = 0;

  /// One key per quote: retrying an accept never books twice.
  final Map<String, String> _acceptKeys = {};
  StreamSubscription<void>? _changes;

  EventVendorList? get list => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    // Added elsewhere (details page), or the event changed status.
    _changes = _events.changes.listen((_) {
      if (busy.isEmpty) unawaited(load());
    });
  }

  @override
  void onClose() {
    unawaited(_changes?.cancel());
    super.onClose();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final current = list;
    if (current == null) state.value = const Loading();
    final result = await _vendors.list(eventId);
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
  Future<Failure?> updateNotes(EventVendor vendor, String? notes) =>
      _run(vendor.id, () => _vendors.updateNotes(eventId, vendor, notes));

  Future<Failure?> remove(EventVendor vendor) =>
      _run(vendor.id, () => _vendors.remove(eventId, vendor.id));

  Future<Failure?> closeEnquiry(EventVendor vendor, Enquiry enquiry) => _run(
    vendor.id,
    () => _vendors.closeEnquiry(eventId, vendor.id, enquiry.id),
  );

  Future<Failure?> acceptQuotation(EventVendor vendor, Quotation quote) => _run(
    vendor.id,
    () => _vendors.acceptQuotation(
      eventId,
      vendor.id,
      quote.id,
      idempotencyKey: _acceptKeys.putIfAbsent(quote.id, generateRequestId),
    ),
  );

  Future<Failure?> rejectQuotation(EventVendor vendor, Quotation quote) => _run(
    vendor.id,
    () => _vendors.rejectQuotation(eventId, vendor.id, quote.id),
  );

  Future<Failure?> cancelBooking(EventVendor vendor, String reason) =>
      _run(vendor.id, () => _vendors.cancelBooking(eventId, vendor.id, reason));

  Future<Failure?> completeBooking(EventVendor vendor) =>
      _run(vendor.id, () => _vendors.completeBooking(eventId, vendor.id));

  Future<Failure?> _run<T>(
    String key,
    Future<Result<T>> Function() request,
  ) async {
    if (busy.contains(key)) return null;
    busy.add(key);
    try {
      final result = await request();
      if (isClosed) return null;
      // Success or a rejected change: either way show the server's state.
      await load();
      return switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      };
    } finally {
      busy.remove(key);
    }
  }
}
