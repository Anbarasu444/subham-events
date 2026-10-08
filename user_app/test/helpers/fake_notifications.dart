import 'dart:async';

import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/notifications/data/push_messaging.dart';
import 'package:user_app/features/notifications/domain/app_notification.dart';

AppNotification testNotification(
  String id, {
  String title = 'Reminder',
  String body = 'Call the caterer',
  String category = 'CHECKLIST',
  String? eventId = 'e1',
  bool read = false,
  DateTime? at,
}) => AppNotification(
  id: id,
  category: category,
  type: 'REMINDER_DUE',
  title: title,
  body: body,
  entityType: 'REMINDER',
  entityId: 'r-$id',
  eventId: eventId,
  readAt: read ? DateTime(2026, 10, 8) : null,
  createdAt: at ?? DateTime(2026, 10, 8, 10),
);

/// In-memory notification center, devices and preferences.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({List<AppNotification>? items})
    : items = [...?items];

  final List<AppNotification> items;
  final List<String> calls = [];
  final Set<String> devices = {};
  final Map<PushGroup, bool> prefs = {
    for (final g in PushGroup.values) g: true,
  };
  Failure? failNext;

  @override
  Future<Result<NotificationPage>> list({
    String? cursor,
    int limit = 20,
  }) async {
    calls.add('list');
    final f = failNext;
    failNext = null;
    if (f != null) return Err(f);
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + limit).clamp(0, items.length);
    return Ok(
      NotificationPage(
        items: items.sublist(start, end),
        nextCursor: end < items.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Result<int>> unreadCount() async =>
      Ok(items.where((n) => !n.isRead).length);

  @override
  Future<Result<void>> markRead(String id) async {
    calls.add('read:$id');
    final i = items.indexWhere((n) => n.id == id);
    if (i >= 0) items[i] = items[i].markedRead(DateTime(2026, 10, 8, 12));
    return const Ok(null);
  }

  @override
  Future<Result<void>> markAllRead() async {
    calls.add('readAll');
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].markedRead(DateTime(2026, 10, 8, 12));
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> registerDevice(
    String token, {
    required String platform,
    String? appVersion,
  }) async {
    calls.add('register:$token:$platform');
    devices.add(token);
    return const Ok(null);
  }

  @override
  Future<Result<void>> removeDevice(String token) async {
    calls.add('remove:$token');
    devices.remove(token);
    return const Ok(null);
  }

  @override
  Future<Result<Map<PushGroup, bool>>> preferences() async => Ok({...prefs});

  @override
  Future<Result<Map<PushGroup, bool>>> setPreference(
    PushGroup group,
    bool enabled,
  ) async {
    calls.add('pref:${group.api}:$enabled');
    prefs[group] = enabled;
    return Ok({...prefs});
  }
}

/// Scriptable phone push channel.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.status = PushPermission.notDetermined,
    this.afterRequest = PushPermission.granted,
    this.deviceToken = 'device-token-123456789012345',
  });

  PushPermission status;
  PushPermission afterRequest;
  String? deviceToken;
  PushTap? launchedFrom;
  int requests = 0;
  final StreamController<String> refreshes = StreamController.broadcast();
  final StreamController<PushTap> arrivals = StreamController.broadcast();
  final StreamController<PushTap> taps = StreamController.broadcast();

  @override
  Future<PushPermission> permission() async => status;

  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    return status = afterRequest;
  }

  @override
  Future<String?> token() async => deviceToken;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<PushTap> get foreground => arrivals.stream;

  @override
  Stream<PushTap> get opened => taps.stream;

  @override
  Future<PushTap?> initial() async => launchedFrom;
}
