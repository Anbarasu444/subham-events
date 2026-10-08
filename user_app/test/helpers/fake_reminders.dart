import 'dart:async';

import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/reminders/domain/reminder.dart';

/// In-memory reminders following the server rules (enough for widgets).
class FakeRemindersRepository implements RemindersRepository {
  FakeRemindersRepository({this.readOnlyEvents = const {}});

  final Set<String> readOnlyEvents;
  final List<Reminder> reminders = [];
  final List<String> calls = [];
  final List<String> idempotencyKeys = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Failure? failNext;
  int _seq = 0;

  @override
  Stream<void> get changes => _changes.stream;

  Result<T>? _failure<T>() {
    final f = failNext;
    failNext = null;
    return f == null ? null : Err(f);
  }

  Reminder _make(
    String id,
    String eventId,
    ReminderInput input, {
    ReminderStatus status = ReminderStatus.scheduled,
    int version = 1,
    String? reason,
  }) => Reminder(
    id: id,
    eventId: eventId,
    eventTitle: 'Asha & Ravi',
    title: input.title,
    remindAt: input.remindAt,
    status: status,
    checklistItemId: input.checklistItemId,
    checklistItemTitle: input.checklistItemId == null ? null : 'Linked task',
    cancelReason: reason,
    version: version,
  );

  /// Seeds a reminder directly (e.g. a sent one for the Home banner).
  Reminder seed(
    String eventId,
    String title,
    DateTime at, {
    ReminderStatus status = ReminderStatus.scheduled,
  }) {
    final r = _make(
      'r-${++_seq}',
      eventId,
      ReminderInput(title: title, remindAt: at),
      status: status,
    );
    reminders.add(r);
    return r;
  }

  @override
  Future<Result<EventReminders>> list(String eventId) async {
    calls.add('list:$eventId');
    final f = _failure<EventReminders>();
    if (f != null) return f;
    final mine = reminders.where((r) => r.eventId == eventId);
    return Ok(
      EventReminders(
        eventId: eventId,
        isEditable: !readOnlyEvents.contains(eventId),
        upcoming:
            mine.where((r) => r.status == ReminderStatus.scheduled).toList()
              ..sort((a, b) => a.remindAt.compareTo(b.remindAt)),
        past: mine.where((r) => r.status != ReminderStatus.scheduled).toList(),
      ),
    );
  }

  final Set<String> seen = {};

  @override
  Future<Result<List<Reminder>>> mine({
    required bool due,
    int limit = 20,
  }) async {
    final list =
        reminders
            .where(
              (r) => due
                  ? r.status == ReminderStatus.sent && !seen.contains(r.id)
                  : r.status == ReminderStatus.scheduled,
            )
            .toList()
          ..sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return Ok(list.take(limit).toList());
  }

  @override
  Future<Result<Reminder>> create(
    String eventId,
    ReminderInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('create:${input.title}');
    idempotencyKeys.add(idempotencyKey);
    final f = _failure<Reminder>();
    if (f != null) return f;
    final r = _make('r-${++_seq}', eventId, input);
    reminders.add(r);
    _changes.add(null);
    return Ok(r);
  }

  @override
  Future<Result<Reminder>> update(
    Reminder reminder,
    ReminderInput input,
  ) async {
    calls.add('update:${reminder.id}:${input.title}');
    final r = _make(
      reminder.id,
      reminder.eventId,
      input,
      version: reminder.version + 1,
    );
    reminders[reminders.indexWhere((e) => e.id == reminder.id)] = r;
    _changes.add(null);
    return Ok(r);
  }

  @override
  Future<Result<Reminder>> cancel(Reminder reminder) async {
    calls.add('cancel:${reminder.id}');
    final r = _make(
      reminder.id,
      reminder.eventId,
      ReminderInput(
        title: reminder.title,
        remindAt: reminder.remindAt,
        checklistItemId: reminder.checklistItemId,
      ),
      status: ReminderStatus.cancelled,
      version: reminder.version + 1,
      reason: 'USER',
    );
    reminders[reminders.indexWhere((e) => e.id == reminder.id)] = r;
    _changes.add(null);
    return Ok(r);
  }

  @override
  Future<Result<void>> markSeen(Reminder reminder) async {
    calls.add('seen:${reminder.id}');
    seen.add(reminder.id);
    _changes.add(null);
    return const Ok(null);
  }
}
