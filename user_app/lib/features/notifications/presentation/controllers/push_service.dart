import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/error/result.dart';
import '../../../../core/storage/secure_store.dart';
import '../../../events/presentation/events_navigation.dart';
import '../../data/push_messaging.dart';
import '../../domain/app_notification.dart';

/// Phone pushes and the unread badge (M18). Registers this phone's token for
/// the signed-in user (only once permission is granted), unregisters it
/// before sign-out, shows pushes that arrive while the app is open, and opens
/// the right screen when one is tapped. Permission is asked in context
/// (M18 answer 4), never at launch.
class PushService extends GetxService {
  PushService(
    this._repository,
    this._messaging,
    this._session,
    this._store, {
    this.appVersion,
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform;

  final NotificationsRepository _repository;
  final PushMessaging _messaging;
  final SessionService _session;
  final SecureStore _store;
  final String? appVersion;
  final TargetPlatform _platform;

  static const _promptedKey = 'push_permission_asked';

  final RxInt unread = 0.obs;
  final Rx<PushPermission> permission = PushPermission.notDetermined.obs;

  String? _registeredToken;
  final Set<String> _seen = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Worker? _sessionWorker;

  String get _platformName =>
      _platform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  @override
  void onInit() {
    super.onInit();
    _session.addBeforeSignOut(unregister);
    _sessionWorker = ever<SessionState>(_session.state, (_) {
      unawaited(_onSession());
    });
    _subscriptions
      ..add(_messaging.tokenRefreshes.listen((t) => unawaited(_register(t))))
      ..add(_messaging.foreground.listen(_onForeground))
      ..add(_messaging.opened.listen((tap) => unawaited(open(tap))));
    unawaited(_start());
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.onClose();
  }

  Future<void> _start() async {
    await _onSession();
    final initial = await _messaging.initial();
    if (initial != null) await open(initial);
  }

  Future<void> _onSession() async {
    if (!_session.isSignedIn) {
      unread.value = 0;
      _registeredToken = null;
      return;
    }
    await refreshUnread();
    permission.value = await _messaging.permission();
    if (permission.value == PushPermission.granted) {
      final token = await _messaging.token();
      if (token != null) await _register(token);
    }
  }

  Future<void> refreshUnread() async {
    if (!_session.isSignedIn) return;
    final result = await _repository.unreadCount();
    if (result case Ok(:final value)) unread.value = value;
  }

  Future<void> _register(String token) async {
    if (!_session.isSignedIn || token == _registeredToken) return;
    final result = await _repository.registerDevice(
      token,
      platform: _platformName,
      appVersion: appVersion,
    );
    if (result is Ok) _registeredToken = token;
  }

  /// Before sign-out: this phone stops receiving this user's pushes.
  Future<void> unregister() async {
    final token = _registeredToken;
    if (token == null) return;
    await _repository.removeDevice(token);
    _registeredToken = null;
  }

  /// Asks for permission the first time it matters (a reminder, an
  /// enquiry). Explains first; asks the system only once per install.
  Future<void> askInContext(BuildContext context, {required String why}) async {
    if (!_session.isSignedIn) return;
    permission.value = await _messaging.permission();
    if (permission.value != PushPermission.notDetermined) return;
    if (await _store.read(_promptedKey) != null) return;
    await _store.write(_promptedKey, '1');
    if (!context.mounted) return;
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Get notified?'),
            content: Text(why),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Allow'),
              ),
            ],
          ),
        ) ??
        false;
    if (yes) await requestPermission();
  }

  /// From Settings (or after the in-context explanation).
  Future<PushPermission> requestPermission() async {
    permission.value = await _messaging.requestPermission();
    if (permission.value == PushPermission.granted) {
      final token = await _messaging.token();
      if (token != null) await _register(token);
    }
    return permission.value;
  }

  void _onForeground(PushTap tap) {
    if (!_seen.add(tap.notificationId)) return; // at-least-once delivery
    unawaited(refreshUnread());
    Get.rawSnackbar(
      title: tap.title,
      message: tap.body ?? '',
      duration: const Duration(seconds: 4),
      onTap: (_) => unawaited(open(tap)),
    );
  }

  /// A tapped push or Notification Center entry: mark read, open the event.
  Future<void> open(PushTap tap) async {
    _seen.add(tap.notificationId);
    await _repository.markRead(tap.notificationId);
    await refreshUnread();
    final eventId = tap.eventId;
    if (eventId != null) EventsNavigation.openEventById(eventId);
  }
}
