import 'dart:async';

import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/reminder.dart';

/// Network-only (the server fires reminders).
class RemindersRepositoryImpl implements RemindersRepository {
  RemindersRepositoryImpl(this._api);

  final ApiClient _api;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  String _path(String eventId) => '/events/$eventId/reminders';

  @override
  Future<Result<EventReminders>> list(String eventId) async => _data(
    await _api.get(
      _path(eventId),
      decode: (json) {
        final map = json as Map<String, dynamic>;
        List<Reminder> all(Object? list) => (list as List<dynamic>)
            .map(reminderFromJson)
            .toList(growable: false);
        return EventReminders(
          eventId: map['eventId'] as String,
          isEditable: map['isEditable'] as bool,
          upcoming: all(map['upcoming']),
          past: all(map['past']),
        );
      },
    ),
    notify: false,
  );

  @override
  Future<Result<List<Reminder>>> mine({
    required bool due,
    int limit = 20,
  }) async => _data(
    await _api.get(
      '/me/reminders',
      query: {'scope': due ? 'due' : 'upcoming', 'limit': limit},
      decode: (json) =>
          (json as List<dynamic>).map(reminderFromJson).toList(growable: false),
    ),
    notify: false,
  );

  @override
  Future<Result<Reminder>> create(
    String eventId,
    ReminderInput input, {
    required String idempotencyKey,
  }) async => _data(
    await _api.post(
      _path(eventId),
      body: toJson(input),
      idempotencyKey: idempotencyKey,
      decode: reminderFromJson,
    ),
  );

  @override
  Future<Result<Reminder>> update(
    Reminder reminder,
    ReminderInput input,
  ) async => _data(
    await _api.patch(
      '${_path(reminder.eventId)}/${reminder.id}',
      body: {...toJson(input), 'version': reminder.version},
      decode: reminderFromJson,
    ),
  );

  @override
  Future<Result<Reminder>> cancel(Reminder reminder) async => _data(
    await _api.post(
      '${_path(reminder.eventId)}/${reminder.id}/cancel',
      decode: reminderFromJson,
    ),
  );

  @override
  Future<Result<void>> markSeen(Reminder reminder) async => _data(
    await _api.post(
      '${_path(reminder.eventId)}/${reminder.id}/seen',
      decode: (_) {},
    ),
  );

  Result<T> _data<T>(Result<ApiResponse<T>> result, {bool notify = true}) {
    switch (result) {
      case Ok(:final value):
        if (notify) _changes.add(null);
        return Ok(value.data);
      case Err(:final failure):
        return Err(failure);
    }
  }

  static Map<String, dynamic> toJson(ReminderInput input) => {
    'title': input.title,
    'remindAt': input.remindAt.toUtc().toIso8601String(),
    'checklistItemId': input.checklistItemId,
  };

  static Reminder reminderFromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return Reminder(
      id: map['id'] as String,
      eventId: map['eventId'] as String,
      eventTitle: map['eventTitle'] as String,
      title: map['title'] as String,
      remindAt: DateTime.parse(map['remindAt'] as String).toLocal(),
      status: ReminderStatus.fromApi(map['status'] as String),
      checklistItemId: map['checklistItemId'] as String?,
      checklistItemTitle: map['checklistItemTitle'] as String?,
      cancelReason: map['cancelReason'] as String?,
      version: map['version'] as int,
    );
  }
}
