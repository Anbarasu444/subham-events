import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/storage/secure_store.dart';
import 'package:user_app/features/notifications/data/notifications_repository_impl.dart';
import 'package:user_app/features/notifications/data/push_messaging.dart';
import 'package:user_app/features/notifications/domain/app_notification.dart';
import 'package:user_app/features/notifications/presentation/controllers/push_service.dart';
import 'package:user_app/features/notifications/presentation/views/notification_center_view.dart';
import 'package:user_app/features/notifications/presentation/views/notification_settings_view.dart';
import 'package:user_app/features/notifications/presentation/widgets/notification_bell.dart';

import '../../helpers/fake_notifications.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

class _MemoryStore implements SecureStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clear() async => values.clear();
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  tearDown(Get.reset);

  test('fromJson reads the event to open and the read state', () {
    final n = NotificationsRepositoryImpl.fromJson({
      'id': 'n1',
      'category': 'BOOKING',
      'type': 'BOOKING_CONFIRMED',
      'title': 'Booking confirmed',
      'body': 'Lotus is booked',
      'entityType': 'BOOKING',
      'entityId': 'b1',
      'deepLink': null,
      'data': {'eventId': 'e1'},
      'readAt': null,
      'createdAt': '2026-10-08T10:00:00.000Z',
    });
    expect(n.eventId, 'e1');
    expect(n.isRead, isFalse);
  });

  group('PushService', () {
    late FakeNotificationsRepository repo;
    late FakePushMessaging messaging;
    late SessionService session;
    late _MemoryStore store;

    PushService make({bool signedIn = true}) {
      session = testSession(
        signedIn ? const SignedInSession(testProfile) : const GuestSession(),
      );
      return PushService(
        repo,
        messaging,
        session,
        store,
        appVersion: '1.0.0',
        platform: TargetPlatform.android,
      )..onInit();
    }

    setUp(() {
      repo = FakeNotificationsRepository(
        items: [testNotification('n1'), testNotification('n2', read: true)],
      );
      messaging = FakePushMessaging();
      store = _MemoryStore();
    });

    test('registers the token only once permission is granted', () async {
      final s = make();
      await _settle();
      expect(s.unread.value, 1);
      expect(repo.calls.where((c) => c.startsWith('register')), isEmpty);

      messaging.status = PushPermission.granted;
      session.state.value = const GuestSession();
      session.state.value = const SignedInSession(testProfile);
      await _settle();
      expect(
        repo.calls,
        contains('register:device-token-123456789012345:ANDROID'),
      );
      s.onClose();
    });

    test('a refreshed token is registered; sign-out removes it', () async {
      messaging.status = PushPermission.granted;
      final s = make();
      await _settle();
      messaging.refreshes.add('new-token-12345678901234567890');
      await _settle();
      expect(repo.devices, contains('new-token-12345678901234567890'));
      await s.unregister();
      expect(repo.calls.last, 'remove:new-token-12345678901234567890');
      s.onClose();
    });

    test('guests never register or count', () async {
      messaging.status = PushPermission.granted;
      final s = make(signedIn: false);
      await _settle();
      expect(repo.calls, isEmpty);
      expect(s.unread.value, 0);
      s.onClose();
    });

    test('opening a push marks it read and refreshes the badge', () async {
      final s = make();
      await _settle();
      await s.open(const PushTap(notificationId: 'n1', type: 'REMINDER_DUE'));
      expect(repo.calls, contains('read:n1'));
      expect(s.unread.value, 0);
      s.onClose();
    });
  });

  testWidgets('asks in context once, then registers on Allow', (tester) async {
    final repo = FakeNotificationsRepository();
    final messaging = FakePushMessaging();
    final store = _MemoryStore();
    final session = testSession(const SignedInSession(testProfile));
    final push = PushService(repo, messaging, session, store)..onInit();
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                push.askInContext(context, why: 'Hear about quotes'),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Hear about quotes'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(messaging.requests, 1);
    expect(repo.devices, isNotEmpty);
    // Never asked twice.
    messaging.status = PushPermission.notDetermined;
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Hear about quotes'), findsNothing);
    push.onClose();
  });

  group('Notification Center', () {
    Future<FakeNotificationsRepository> pump(
      WidgetTester tester, {
      List<AppNotification>? items,
      Failure? fail,
    }) async {
      Get.testMode = true;
      usePhoneSize(tester);
      final repo =
          Get.put<NotificationsRepository>(
                FakeNotificationsRepository(
                  items:
                      items ??
                      [
                        testNotification(
                          'n1',
                          title: 'Booking confirmed',
                          category: 'BOOKING',
                          eventId: null,
                        ),
                        testNotification(
                          'n2',
                          body: 'Old one',
                          read: true,
                          eventId: null,
                        ),
                      ],
                )..failNext = fail,
              )
              as FakeNotificationsRepository;
      final session = Get.put<SessionService>(
        testSession(const SignedInSession(testProfile)),
      );
      Get.put(
        PushService(repo, FakePushMessaging(), session, _MemoryStore())
          ..onInit(),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [NotificationBell()]),
            body: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('the bell shows the unread count and opens the list', (
      tester,
    ) async {
      final repo = await pump(tester);
      expect(find.byTooltip('Notifications, 1 unread'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications, 1 unread'));
      await tester.pumpAndSettle();
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);

      await tester.tap(find.text('Booking confirmed'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('read:n1'));
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });

    testWidgets('mark all read', (tester) async {
      final repo = await pump(
        tester,
        items: [
          testNotification('a', eventId: null),
          testNotification('b', eventId: null),
        ],
      );
      await tester.tap(find.byTooltip('Notifications, 2 unread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark all read'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('readAll'));
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
    });

    testWidgets('empty and error states', (tester) async {
      await pump(tester, items: const [], fail: const NetworkFailure());
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('fits at 200 % text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester);
      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NotificationCenterView), findsOneWidget);
    });
  });

  testWidgets('settings switch groups and offer to allow notifications', (
    tester,
  ) async {
    Get.testMode = true;
    usePhoneSize(tester);
    final repo =
        Get.put<NotificationsRepository>(FakeNotificationsRepository())
            as FakeNotificationsRepository;
    final messaging = FakePushMessaging();
    final session = Get.put<SessionService>(
      testSession(const SignedInSession(testProfile)),
    );
    Get.put(PushService(repo, messaging, session, _MemoryStore())..onInit());
    await tester.pumpWidget(
      const GetMaterialApp(home: NotificationSettingsView()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bookings & quotes'), findsOneWidget);
    await tester.tap(find.text('Reminders & checklist'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('pref:REMINDERS:false'));
    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();
    expect(messaging.requests, 1);
    expect(find.text('Allow notifications'), findsNothing);
  });
}
