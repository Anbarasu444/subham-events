import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/request_id.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../domain/event_vendor.dart';

/// Send an enquiry (M14 answer 3): message 10–1000 characters, starting
/// from an editable text, plus an optional preferred date.
class EnquiryFormController extends GetxController {
  EnquiryFormController(
    this._repository,
    this.event,
    this.vendor, {
    DateTime? today,
  }) : today = today ?? dateOnly(DateTime.now());

  final EventVendorsRepository _repository;
  final PlannerEvent event;
  final EventVendor vendor;
  final DateTime today;

  late final message = TextEditingController(text: starterText(event, vendor));
  final Rx<DateTime?> preferredDate = Rx<DateTime?>(null);
  final Rx<String?> messageError = Rx<String?>(null);
  final Rx<String?> formError = Rx<String?>(null);
  final RxBool sending = false.obs;

  String _idempotencyKey = generateRequestId();
  EnquiryInput? _lastAttempt;

  /// A friendly start the user can change (only what a vendor may see, A9).
  static String starterText(PlannerEvent event, EventVendor vendor) {
    final guests = event.guestCountEstimate == null
        ? ''
        : ' for about ${event.guestCountEstimate} guests';
    return 'Hi, we are planning a ${event.eventType} on '
        '${formatLongDate(event.eventDate)} in ${event.city}$guests. '
        'Could you share your availability and a quote for '
        '"${vendor.listing.title}"?';
  }

  @override
  void onClose() {
    message.dispose();
    super.onClose();
  }

  Future<EventVendor?> submit() async {
    if (sending.value) return null;
    formError.value = null;
    final text = message.text.trim();
    messageError.value = text.length < 10
        ? 'Write at least 10 characters.'
        : text.length > 1000
        ? 'Use at most 1000 characters.'
        : null;
    if (messageError.value != null) return null;
    final input = EnquiryInput(
      message: text,
      preferredDate: preferredDate.value,
    );
    // Same input → same key: a retry never sends a second enquiry.
    if (_lastAttempt != null && _lastAttempt != input) {
      _idempotencyKey = generateRequestId();
    }
    _lastAttempt = input;
    sending.value = true;
    final result = await _repository.enquire(
      event.id,
      vendor.id,
      input,
      idempotencyKey: _idempotencyKey,
    );
    if (isClosed) return null;
    sending.value = false;
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        formError.value = switch (failure) {
          ConflictFailure(code: 'DUPLICATE') =>
            'You already have an open enquiry with this vendor.',
          ConflictFailure(code: 'INVALID_STATE_TRANSITION') =>
            'This event is no longer being planned, so enquiries are closed.',
          NotFoundFailure() => 'This vendor is no longer listed.',
          ForbiddenFailure() => 'You cannot enquire with your own listing.',
          ValidationFailure() => 'Please check the message and date.',
          NetworkFailure() =>
            'You are offline. Check your connection and try again.',
          TimeoutFailure() => 'The server did not respond in time. Try again.',
          RateLimitedFailure() => 'Too many enquiries. Please wait a moment.',
          _ => 'Something went wrong. Please try again.',
        };
        return null;
    }
  }
}
