import 'dart:async';

import '../../../core/error/result.dart';

enum ReminderStatus {
  scheduled('Scheduled'),
  sent('Sent'),
  cancelled('Cancelled');

  const ReminderStatus(this.label);
  final String label;

  static ReminderStatus fromApi(String value) =>
      ReminderStatus.values.byName(value.toLowerCase());
}

/// A reminder for an event (M17). [remindAt] is local time.
class Reminder {
  const Reminder({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.title,
    required this.remindAt,
    required this.status,
    required this.checklistItemId,
    required this.checklistItemTitle,
    required this.cancelReason,
    required this.version,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String title;
  final DateTime remindAt;
  final ReminderStatus status;
  final String? checklistItemId;
  final String? checklistItemTitle;

  /// USER, TASK_DONE, TASK_DELETED, EVENT_CANCELLED or EVENT_DELETED.
  final String? cancelReason;
  final int version;
}

class EventReminders {
  const EventReminders({
    required this.eventId,
    required this.isEditable,
    required this.upcoming,
    required this.past,
  });

  final String eventId;
  final bool isEditable;

  /// Scheduled, soonest first.
  final List<Reminder> upcoming;

  /// Sent or cancelled, newest first.
  final List<Reminder> past;
}

class ReminderInput {
  const ReminderInput({
    required this.title,
    required this.remindAt,
    this.checklistItemId,
  });

  final String title;

  /// Local time; sent as UTC.
  final DateTime remindAt;
  final String? checklistItemId;

  @override
  bool operator ==(Object other) =>
      other is ReminderInput &&
      other.title == title &&
      other.remindAt == remindAt &&
      other.checklistItemId == checklistItemId;

  @override
  int get hashCode => Object.hash(title, remindAt, checklistItemId);
}

/// Reminders (api-contracts.md Part B, M17).
abstract class RemindersRepository {
  /// Emits after every change, so Home and Schedule refresh.
  Stream<void> get changes;

  Future<Result<EventReminders>> list(String eventId);

  /// Across the user's events: `upcoming` (scheduled) or `due` (sent, not
  /// dismissed).
  Future<Result<List<Reminder>>> mine({required bool due, int limit = 20});
  Future<Result<Reminder>> create(
    String eventId,
    ReminderInput input, {
    required String idempotencyKey,
  });
  Future<Result<Reminder>> update(Reminder reminder, ReminderInput input);
  Future<Result<Reminder>> cancel(Reminder reminder);
  Future<Result<void>> markSeen(Reminder reminder);
}
