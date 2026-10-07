import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/request_id.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';

/// Create or edit an event. Client checks mirror the backend (M8 spec items
/// 2 and 6); the server remains authoritative and its field errors are shown.
class EventFormController extends GetxController {
  EventFormController(
    this._repository, {
    this.existing,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Quick-fill suggestions; any text is accepted (O1: free-text type).
  static const typeSuggestions = [
    'Wedding',
    'Engagement',
    'Birthday',
    'Anniversary',
    'Baby shower',
    'Housewarming',
    'Corporate',
  ];

  final EventsRepository _repository;
  final PlannerEvent? existing;
  final DateTime Function() _clock;

  late final eventType = TextEditingController(text: existing?.eventType);
  late final title = TextEditingController(text: existing?.title);
  late final city = TextEditingController(text: existing?.city);
  late final venueName = TextEditingController(text: existing?.venueName);
  late final venueAddress = TextEditingController(text: existing?.venueAddress);
  late final guests = TextEditingController(
    text: existing?.guestCountEstimate?.toString(),
  );
  late final budget = TextEditingController(
    text: existing?.totalBudget?.toInputText(),
  );
  late final Rx<DateTime?> eventDate = Rx<DateTime?>(existing?.eventDate);
  late final Rx<String?> startTime = Rx<String?>(existing?.startTime);

  /// Form scroll position, so the view can reveal errors after submit.
  late final ScrollController scroll = ScrollController();

  /// One [GlobalKey] per field, so the view can scroll to the first error.
  late final Map<String, GlobalKey> fieldKeys = {
    for (final field in fieldOrder) field: GlobalKey(debugLabel: field),
  };

  /// Fields in on-screen order.
  static const fieldOrder = [
    'eventType',
    'title',
    'eventDate',
    'startTime',
    'city',
    'venueName',
    'venueAddress',
    'guestCountEstimate',
    'totalBudget',
  ];

  /// First field (on screen) that has an error, if any.
  String? get firstErrorField =>
      fieldOrder.where(fieldErrors.containsKey).firstOrNull;

  final RxMap<String, String> fieldErrors = <String, String>{}.obs;
  final Rx<String?> formError = Rx<String?>(null);
  final RxBool saving = false.obs;

  /// One key per create intent, reused when the user retries after an error.
  /// The key belongs to one create intent: a retry of the *same* input
  /// reuses it (no duplicate event); changed input gets a new key, so the
  /// server never reports the key as reused for a different request.
  String _idempotencyKey = generateRequestId();
  EventInput? _lastAttempt;

  late final EventInput? _initial = existing == null
      ? null
      : _inputOf(existing!);

  bool get isEdit => existing != null;
  DateTime get today => dateOnly(_clock());

  /// First selectable date in the picker: new events cannot be in the past.
  DateTime get firstDate {
    final current = eventDate.value;
    if (!isEdit) return today;
    return current != null && current.isBefore(today) ? current : today;
  }

  bool get isDirty {
    final initial = _initial;
    if (initial == null) {
      return [
            eventType,
            title,
            city,
            venueName,
            venueAddress,
            guests,
            budget,
          ].any((c) => c.text.trim().isNotEmpty) ||
          eventDate.value != null ||
          startTime.value != null;
    }
    final now = _readInput(validate: false);
    return now == null || !_sameInput(now, initial);
  }

  @override
  void onClose() {
    for (final c in [
      eventType,
      title,
      city,
      venueName,
      venueAddress,
      guests,
      budget,
    ]) {
      c.dispose();
    }
    scroll.dispose();
    super.onClose();
  }

  void clearError(String field) => fieldErrors.remove(field);

  void pickType(String value) {
    eventType.text = value;
    clearError('eventType');
  }

  /// Saves; returns the saved event, or null when validation or the request
  /// failed (errors are shown on the form).
  Future<PlannerEvent?> submit() async {
    if (saving.value) return null;
    formError.value = null;
    final input = _readInput(validate: true);
    if (input == null) return null;
    saving.value = true;
    final result = isEdit
        ? await _repository.update(existing!, input)
        : await _repository.create(input, idempotencyKey: _keyFor(input));
    if (isClosed) return null;
    saving.value = false;
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        _showFailure(failure);
        return null;
    }
  }

  String _keyFor(EventInput input) {
    final last = _lastAttempt;
    if (last != null && !_sameInput(last, input)) {
      _idempotencyKey = generateRequestId();
    }
    _lastAttempt = input;
    return _idempotencyKey;
  }

  void _showFailure(Failure failure) {
    switch (failure) {
      case ValidationFailure(:final fieldErrors):
        final mapped = <String, String>{};
        for (final error in fieldErrors) {
          final field = (error.field ?? '').split('.').first;
          if (_fields.contains(field)) {
            mapped[field] = _serverMessage(field, error);
          }
        }
        this.fieldErrors.addAll(mapped);
        formError.value = mapped.isEmpty ? 'Please check your details.' : null;
      case ConflictFailure():
        formError.value =
            'This event was changed on another device. Go back and open it again to see the latest details.';
      case NotFoundFailure():
        formError.value = 'This event no longer exists.';
      case NetworkFailure():
        formError.value =
            'You are offline. Check your connection and try again.';
      case TimeoutFailure():
        formError.value = 'The server did not respond in time. Try again.';
      case RateLimitedFailure():
        formError.value = 'Too many attempts. Please wait a moment.';
      default:
        formError.value = 'Something went wrong. Please try again.';
    }
  }

  static const _fields = {
    'eventType',
    'title',
    'eventDate',
    'city',
    'startTime',
    'venueName',
    'venueAddress',
    'guestCountEstimate',
    'totalBudget',
  };

  static String _serverMessage(String field, FieldError error) =>
      switch (error.code) {
        'MUST_NOT_BE_PAST' => 'Choose today or a later date.',
        _ => switch (field) {
          'totalBudget' => 'Enter an amount like 50000 or 50000.50.',
          _ => 'Please check this field.',
        },
      };

  EventInput? _readInput({required bool validate}) {
    final errors = <String, String>{};
    String? optional(TextEditingController c) {
      final text = c.text.trim();
      return text.isEmpty ? null : text;
    }

    String required(
      TextEditingController c,
      String field,
      String label,
      int max,
    ) {
      final text = c.text.trim();
      if (text.isEmpty) {
        errors[field] = 'Enter $label.';
      } else if (text.length > max) {
        errors[field] = 'Use at most $max characters.';
      }
      return text;
    }

    final type = required(eventType, 'eventType', 'the event type', 60);
    final name = required(title, 'title', 'a title', 100);
    final place = required(city, 'city', 'the city', 80);
    final venue = optional(venueName);
    if (venue != null && venue.length > 120) {
      errors['venueName'] = 'Use at most 120 characters.';
    }
    final address = optional(venueAddress);
    if (address != null && address.length > 300) {
      errors['venueAddress'] = 'Use at most 300 characters.';
    }

    final date = eventDate.value;
    if (date == null) {
      errors['eventDate'] = 'Choose the event date.';
    } else if (!isEdit && date.isBefore(today)) {
      errors['eventDate'] = 'Choose today or a later date.';
    }

    int? guestCount;
    final guestText = optional(guests);
    if (guestText != null) {
      guestCount = int.tryParse(guestText);
      if (guestCount == null || guestCount < 0 || guestCount > 100000) {
        errors['guestCountEstimate'] = 'Enter a number from 0 to 100000.';
      }
    }

    Money? amount;
    final budgetText = optional(budget);
    if (budgetText != null) {
      amount = Money.tryParseInput(budgetText);
      if (amount == null) {
        errors['totalBudget'] = 'Enter an amount like 50000 or 50000.50.';
      }
    }

    if (errors.isNotEmpty) {
      if (validate) fieldErrors.assignAll(errors);
      return null;
    }
    if (validate) fieldErrors.clear();
    return EventInput(
      eventType: type,
      title: name,
      eventDate: date!,
      city: place,
      startTime: startTime.value,
      venueName: venue,
      venueAddress: address,
      guestCountEstimate: guestCount,
      totalBudget: amount,
    );
  }

  static EventInput _inputOf(PlannerEvent e) => EventInput(
    eventType: e.eventType,
    title: e.title,
    eventDate: e.eventDate,
    city: e.city,
    startTime: e.startTime,
    venueName: e.venueName,
    venueAddress: e.venueAddress,
    guestCountEstimate: e.guestCountEstimate,
    totalBudget: e.totalBudget,
  );

  static bool _sameInput(EventInput a, EventInput b) =>
      a.eventType == b.eventType &&
      a.title == b.title &&
      a.eventDate == b.eventDate &&
      a.city == b.city &&
      a.startTime == b.startTime &&
      a.venueName == b.venueName &&
      a.venueAddress == b.venueAddress &&
      a.guestCountEstimate == b.guestCountEstimate &&
      a.totalBudget == b.totalBudget;
}
