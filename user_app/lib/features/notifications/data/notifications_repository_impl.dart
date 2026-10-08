import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/app_notification.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<NotificationPage>> list({
    String? cursor,
    int limit = 20,
  }) async {
    final result = await _api.get(
      '/me/notifications',
      query: {'limit': limit, 'cursor': ?cursor},
      decode: (json) =>
          (json as List<dynamic>).map(fromJson).toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok(
        NotificationPage(
          items: value.data,
          nextCursor: switch (value.page) {
            CursorPageMeta(:final nextCursor, :final hasMore) =>
              hasMore ? nextCursor : null,
            _ => null,
          },
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<int>> unreadCount() async => _data(
    await _api.get(
      '/me/notifications/unread-count',
      decode: (json) => (json as Map<String, dynamic>)['count'] as int,
    ),
  );

  @override
  Future<Result<void>> markRead(String id) async =>
      _data(await _api.post('/me/notifications/$id/read', decode: (_) {}));

  @override
  Future<Result<void>> markAllRead() async =>
      _data(await _api.post('/me/notifications/read-all', decode: (_) {}));

  @override
  Future<Result<void>> registerDevice(
    String token, {
    required String platform,
    String? appVersion,
  }) async => _data(
    await _api.put(
      '/me/devices',
      body: {'token': token, 'platform': platform, 'appVersion': ?appVersion},
      decode: (_) {},
    ),
  );

  @override
  Future<Result<void>> removeDevice(String token) async => _data(
    await _api.delete(
      '/me/devices/${Uri.encodeComponent(token)}',
      decode: (_) {},
    ),
  );

  @override
  Future<Result<Map<PushGroup, bool>>> preferences() async =>
      _data(await _api.get('/me/notification-preferences', decode: _prefs));

  @override
  Future<Result<Map<PushGroup, bool>>> setPreference(
    PushGroup group,
    bool enabled,
  ) async => _data(
    await _api.put(
      '/me/notification-preferences',
      body: {
        'preferences': [
          {'group': group.api, 'pushEnabled': enabled},
        ],
      },
      decode: _prefs,
    ),
  );

  static Map<PushGroup, bool> _prefs(Object? json) => {
    for (final raw in json as List<dynamic>)
      PushGroup.fromApi((raw as Map<String, dynamic>)['group'] as String):
          raw['pushEnabled'] as bool,
  };

  Result<T> _data<T>(Result<ApiResponse<T>> result) => switch (result) {
    Ok(:final value) => Ok(value.data),
    Err(:final failure) => Err(failure),
  };

  static AppNotification fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    final data = (map['data'] as Map<String, dynamic>?) ?? const {};
    final read = map['readAt'] as String?;
    return AppNotification(
      id: map['id'] as String,
      category: map['category'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      entityType: map['entityType'] as String?,
      entityId: map['entityId'] as String?,
      eventId: data['eventId'] as String?,
      readAt: read == null ? null : DateTime.parse(read).toLocal(),
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
    );
  }
}
