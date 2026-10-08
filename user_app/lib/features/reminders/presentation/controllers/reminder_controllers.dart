import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/request_id.dart';
import '../../domain/reminder.dart';

/// "6 PM the day before the due date" (M17 answer 6), or tomorrow 6 PM when
/// that time has already passed or there is no due date.
DateTime defaultReminderTime(DateTime? dueDate, DateTime now) {
  DateTime evening(DateTime day) => DateTime(day.year, day.month, day.day, 18);
  if (dueDate != null) {
    final before = evening(dueDate.subtract(const Duration(days: 1)));
    if (before.isAfter(now)) return before;
  }
  final tomorrow = dateOnly(now).add(const Duration(days: 1));
  return evening(tomorrow);
}

/// An event's reminders (Overview section, M17).
class EventRemindersController extends GetxController {
  EventRemindersController(this._repository, this.eventId);

  final RemindersRepository _repository;
  final String eventId;

  final Rx<ViewState<EventReminders>> state = Rx<ViewState<EventReminders>>(
    const Loading(),
  );
  final RxSet<String> busy = <String>{}.obs;
  int _generation = 0;
  StreamSubscription<void>? _changes;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    _changes = _repository.changes.listen((_) {
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
    final current = switch (state.value) {
      Content(:final data) => data,
      _ => null,
    };
    if (current == null) state.value = const Loading();
    final result = await _repository.list(eventId);
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
  Future<Failure?> cancel(Reminder reminder) async {
    if (busy.contains(reminder.id)) return null;
    busy.add(reminder.id);
    try {
      final result = await _repository.cancel(reminder);
      if (isClosed) return null;
      await load();
      return switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      };
    } finally {
      busy.remove(reminder.id);
    }
  }
}

/// Add or edit a reminder (title 1–120, a future time, optional task).
class ReminderFormController extends GetxController {
  ReminderFormController(
    this._repository,
    this.eventId, {
    this.existing,
    String? title,
    DateTime? at,
    String? taskId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _initialTitle = existing?.title ?? title,
       _initialAt =
           existing?.remindAt ??
           at ??
           defaultReminderTime(null, (clock ?? DateTime.now)()),
       _initialTask = existing?.checklistItemId ?? taskId;

  final RemindersRepository _repository;
  final String eventId;
  final Reminder? existing;
  final DateTime Function() _clock;
  final String? _initialTitle;
  final DateTime _initialAt;
  final String? _initialTask;

  late final title = TextEditingController(text: _initialTitle);
  late final Rx<DateTime> day = dateOnly(_initialAt).obs;
  late final Rx<TimeOfDay> time = TimeOfDay.fromDateTime(_initialAt).obs;
  late final Rx<String?> taskId = Rx<String?>(_initialTask);

  final Rx<String?> titleError = Rx<String?>(null);
  final Rx<String?> timeError = Rx<String?>(null);
  final Rx<String?> formError = Rx<String?>(null);
  final RxBool saving = false.obs;

  String _idempotencyKey = generateRequestId();
  ReminderInput? _lastAttempt;

  bool get isEdit => existing != null;

  DateTime get at => DateTime(
    day.value.year,
    day.value.month,
    day.value.day,
    time.value.hour,
    time.value.minute,
  );

  @override
  void onClose() {
    title.dispose();
    super.onClose();
  }

  Future<Reminder?> submit() async {
    if (saving.value) return null;
    formError.value = null;
    final text = title.text.trim();
    titleError.value = text.isEmpty
        ? 'Enter what to remind you about.'
        : text.length > 120
        ? 'Use at most 120 characters.'
        : null;
    timeError.value = at.isAfter(_clock())
        ? null
        : 'Choose a time in the future.';
    if (titleError.value != null || timeError.value != null) return null;
    final input = ReminderInput(
      title: text,
      remindAt: at,
      checklistItemId: taskId.value,
    );
    if (_lastAttempt != null && _lastAttempt != input) {
      _idempotencyKey = generateRequestId();
    }
    _lastAttempt = input;
    saving.value = true;
    final result = isEdit
        ? await _repository.update(existing!, input)
        : await _repository.create(
            eventId,
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
            'This event already has 200 scheduled reminders.',
          ConflictFailure(code: 'INVALID_STATE_TRANSITION') =>
            'This reminder can no longer be changed.',
          ConflictFailure() =>
            'This reminder was changed on another device. Close and try again.',
          NotFoundFailure() => 'This reminder no longer exists.',
          ValidationFailure() => 'Please check the time and title.',
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

/// Menu → Schedule (all upcoming reminders) and the Home banner (due ones).
class MyRemindersController extends GetxController {
  MyRemindersController(this._repository, {this.limit = 50});

  final RemindersRepository _repository;
  final int limit;

  final Rx<ViewState<List<Reminder>>> upcoming = Rx<ViewState<List<Reminder>>>(
    const Loading(),
  );
  final RxList<Reminder> due = <Reminder>[].obs;
  StreamSubscription<void>? _changes;
  int _generation = 0;

  Reminder? get next => switch (upcoming.value) {
    Content(:final data) => data.firstOrNull,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    _changes = _repository.changes.listen((_) => unawaited(load()));
  }

  @override
  void onClose() {
    unawaited(_changes?.cancel());
    super.onClose();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final results = await Future.wait([
      _repository.mine(due: false, limit: limit),
      _repository.mine(due: true, limit: 10),
    ]);
    if (isClosed || generation != _generation) return;
    upcoming.value = switch (results[0]) {
      Ok(:final value) => value.isEmpty ? const Empty() : Content(value),
      Err(:final failure) => Failed(failure),
    };
    if (results[1] case Ok(:final value)) due.assignAll(value);
  }

  /// Hides a due reminder's banner (server remembers it).
  Future<void> dismiss(Reminder reminder) async {
    due.removeWhere((r) => r.id == reminder.id);
    await _repository.markSeen(reminder);
  }
}
