import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

enum PushPermission { granted, denied, notDetermined }

/// A push the user saw or tapped (data payload, matrix §3).
class PushTap {
  const PushTap({
    required this.notificationId,
    required this.type,
    this.eventId,
    this.title,
    this.body,
  });

  final String notificationId;
  final String type;
  final String? eventId;
  final String? title;
  final String? body;

  static PushTap? fromMessage(RemoteMessage message) {
    final id = message.data['notificationId'];
    if (id is! String) return null;
    return PushTap(
      notificationId: id,
      type: (message.data['type'] as String?) ?? '',
      eventId: message.data['eventId'] as String?,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}

/// The phone's push channel. Abstract so tests never touch Firebase.
abstract class PushMessaging {
  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();
  Future<String?> token();
  Stream<String> get tokenRefreshes;

  /// Pushes arriving while the app is open.
  Stream<PushTap> get foreground;

  /// Taps on pushes while the app was in the background.
  Stream<PushTap> get opened;

  /// The push that launched the app from closed, if any.
  Future<PushTap?> initial();
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging([FirebaseMessaging? messaging]) : _given = messaging;

  final FirebaseMessaging? _given;

  /// Resolved on first use (Firebase is initialised at app start).
  FirebaseMessaging get _messaging => _given ?? FirebaseMessaging.instance;

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<PushPermission> permission() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<String?> token() async {
    try {
      return await _messaging.getToken();
    } on Object {
      return null; // e.g. iOS without APNs set up yet (M18 answer 2)
    }
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<PushTap> get foreground => FirebaseMessaging.onMessage
      .map(PushTap.fromMessage)
      .where((tap) => tap != null)
      .cast<PushTap>();

  @override
  Stream<PushTap> get opened => FirebaseMessaging.onMessageOpenedApp
      .map(PushTap.fromMessage)
      .where((tap) => tap != null)
      .cast<PushTap>();

  @override
  Future<PushTap?> initial() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushTap.fromMessage(message);
  }
}
