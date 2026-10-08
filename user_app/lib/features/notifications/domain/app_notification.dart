import '../../../core/error/result.dart';

/// One entry of the Notification Center (M18).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.type,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.eventId,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String type;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;

  /// The event to open, when the notification belongs to one.
  final String? eventId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    category: category,
    type: type,
    title: title,
    body: body,
    entityType: entityType,
    entityId: entityId,
    eventId: eventId,
    readAt: readAt ?? at,
    createdAt: createdAt,
  );
}

class NotificationPage {
  const NotificationPage({required this.items, required this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;
}

enum PushGroup {
  bookings('BOOKINGS', 'Bookings & quotes'),
  reminders('REMINDERS', 'Reminders & checklist'),
  other('OTHER', 'Other');

  const PushGroup(this.api, this.label);
  final String api;
  final String label;

  static PushGroup fromApi(String value) =>
      PushGroup.values.firstWhere((g) => g.api == value);
}

/// The Notification Center, push devices and preferences (api-contracts.md
/// Part B, M18).
abstract class NotificationsRepository {
  Future<Result<NotificationPage>> list({String? cursor, int limit = 20});
  Future<Result<int>> unreadCount();
  Future<Result<void>> markRead(String id);
  Future<Result<void>> markAllRead();
  Future<Result<void>> registerDevice(
    String token, {
    required String platform,
    String? appVersion,
  });
  Future<Result<void>> removeDevice(String token);
  Future<Result<Map<PushGroup, bool>>> preferences();
  Future<Result<Map<PushGroup, bool>>> setPreference(
    PushGroup group,
    bool enabled,
  );
}
