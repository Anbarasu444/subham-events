import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/auth_service.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/crash/crash_reporter.dart';
import 'package:user_app/core/storage/secure_store.dart';
import 'package:user_app/features/auth/data/auth_api.dart';
import 'package:user_app/app/routes/app_routes.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/home/data/empty_section_source.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/bindings/shell_binding.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_checklist_repository.dart';
import 'package:user_app/features/explore/domain/listing.dart';

import 'package:user_app/features/reminders/domain/reminder.dart';

import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_reminders.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/recording_reporter.dart';

class _Auth extends Mock implements AuthService {}

class _Api extends Mock implements AuthApi {}

class _Store extends Mock implements SecureStore {}

AppConfig _config(Flavor flavor) => AppConfig(
  flavor: flavor,
  apiBaseUrl: flavor == Flavor.prod
      ? 'https://api.example.com'
      : 'http://localhost:3000',
  appVersion: '1.0.0',
  buildNumber: '1',
);

const _profile = MeProfile(id: 'u1', roles: ['USER'], phone: '+919800000001');

SessionService _session(SessionState state) {
  final service = SessionService(
    auth: _Auth(),
    api: _Api(),
    store: _Store(),
    reporter: RecordingReporter(),
    clearPrivateMedia: () async {},
  );
  service.state.value = state;
  return service;
}

Future<ShellController> _pumpShell(
  WidgetTester tester, {
  SessionState state = const GuestSession(),
  Flavor flavor = Flavor.staging,
  ShellTab initial = ShellTab.home,
}) async {
  Get.testMode = true;
  Get.put<AppConfig>(_config(flavor));
  Get.put<SessionService>(_session(state));
  Get.put(HomeController(Get.find<SessionService>(), defaultDashboardSources));
  final events = Get.put<EventsRepository>(FakeEventsRepository());
  Get.put(MyEventsController(events, Get.find<SessionService>()));
  registerExplore();
  final controller = Get.put(ShellController(initialTab: initial));
  await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  tearDown(Get.reset);

  testWidgets('shows the four tabs in order and opens Home', (tester) async {
    await _pumpShell(tester);
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['Home', 'Explore', 'My Events', 'Menu']);
    expect(find.text('Create your first event'), findsOneWidget);
  });

  testWidgets('tabs are built lazily and keep their state', (tester) async {
    final controller = await _pumpShell(tester);
    expect(controller.isBuilt(ShellTab.explore), isFalse);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    // Open a page inside the Menu tab, switch away and back.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'bar stays visible',
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget, reason: 'state kept');
    expect(controller.isBuilt(ShellTab.explore), isFalse);
  });

  testWidgets('re-selecting the active tab returns to its root', (
    tester,
  ) async {
    await _pumpShell(tester, initial: ShellTab.menu);
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);

    await tester.tap(
      find.byType(NavigationDestination).at(ShellTab.menu.index),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsNothing);
    expect(find.text('Help'), findsOneWidget);
  });

  testWidgets('back pops inside the tab, then returns to Home', (tester) async {
    final controller = await _pumpShell(tester, initial: ShellTab.menu);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(await controller.handleBack(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsNothing);
    expect(controller.current.value, ShellTab.menu);

    expect(await controller.handleBack(), isTrue);
    await tester.pumpAndSettle();
    expect(controller.current.value, ShellTab.home);

    expect(await controller.handleBack(), isFalse, reason: 'app may close');
  });

  testWidgets('guests see a sign-in prompt on My Events', (tester) async {
    await _pumpShell(tester, initial: ShellTab.events);
    expect(find.text('Plan your events'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signed-in users without events see the empty My Events', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      initial: ShellTab.events,
      state: const SignedInSession(_profile),
    );
    expect(find.text('No upcoming events'), findsOneWidget);
    // The empty state has its own button, so the floating one is hidden.
    expect(find.text('Create event'), findsOneWidget);
    expect(find.text('New event'), findsNothing);
  });

  testWidgets('guest Menu shows only Settings and Help with a Sign in header', (
    tester,
  ) async {
    await _pumpShell(tester, initial: ShellTab.menu);
    expect(find.text('Sign in to plan your events'), findsOneWidget);
    for (final title in ['Settings', 'Help']) {
      expect(find.text(title), findsOneWidget);
    }
    for (final title in [
      'My profile',
      'Budget',
      'Checklist',
      'Messages',
      'Schedule',
    ]) {
      expect(find.text(title), findsNothing);
    }
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('signed-in Menu shows identity, all entries and sign out', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      initial: ShellTab.menu,
      state: const SignedInSession(_profile),
    );
    expect(
      find.text('+919800000001'),
      findsOneWidget,
      reason: 'phone shown once',
    );
    for (final title in [
      'Schedule',
      'Checklist',
      'Budget',
      'Messages',
      'My profile',
      'Settings',
      'Help',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 100);
      expect(find.text(title), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Sign out'), 100);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Diagnostics appears in staging builds', (tester) async {
    await _pumpShell(tester, initial: ShellTab.menu);
    expect(find.text('Diagnostics'), findsOneWidget);
  });

  testWidgets('Diagnostics is hidden in prod builds', (tester) async {
    await _pumpShell(tester, initial: ShellTab.menu, flavor: Flavor.prod);
    expect(find.text('Diagnostics'), findsNothing);
  });

  testWidgets('no overflow at 200 % text on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpShell(tester, initial: ShellTab.events);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('unknown tab names fall back to Home', () {
    expect(ShellTab.fromName('events'), ShellTab.events);
    expect(ShellTab.fromName('nope'), ShellTab.home);
    expect(ShellTab.fromName(null), ShellTab.home);
  });

  testWidgets(
    'pending profile keeps the signed-in menu with retry and sign out',
    (tester) async {
      await _pumpShell(
        tester,
        initial: ShellTab.menu,
        state: const ProfilePendingSession(),
      );
      expect(find.textContaining('Couldn’t reach the server'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sign out'), 100);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Sign in to plan your events'), findsNothing);
    },
  );

  testWidgets('the reason for a forced sign-out is shown', (tester) async {
    const reason = 'This account is suspended. Please contact support.';
    await _pumpShell(
      tester,
      initial: ShellTab.events,
      state: const GuestSession(message: reason),
    );
    expect(find.text(reason), findsOneWidget);
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text(reason), findsOneWidget);
  });

  testWidgets('menu sections and signed-in entries open Coming soon', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      initial: ShellTab.menu,
      state: const SignedInSession(_profile),
    );
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    expect(
      find.text('Messages will be available in a future update.'),
      findsOneWidget,
    );
  });

  testWidgets('signing out returns every tab to its first page', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      initial: ShellTab.menu,
      state: const SignedInSession(_profile),
    );
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);

    Get.find<SessionService>().state.value = const GuestSession();
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsNothing);
    expect(find.text('Sign in to plan your events'), findsOneWidget);
  });

  testWidgets('system back pops inside the tab before leaving it', (
    tester,
  ) async {
    final controller = await _pumpShell(tester, initial: ShellTab.menu);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsNothing);
    expect(controller.current.value, ShellTab.menu);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.current.value, ShellTab.home);
  });

  testWidgets('after sign-in the shell reopens on the tab from returnTo', (
    tester,
  ) async {
    Get.testMode = true;
    Get.put<AppConfig>(_config(Flavor.staging));
    Get.put<SessionService>(_session(const SignedInSession(_profile)));
    Get.put<CrashReporter>(RecordingReporter());
    final events = Get.put<EventsRepository>(FakeEventsRepository());
    Get.put<ChecklistRepository>(
      FakeChecklistRepository(onChanged: events.notifyChanged),
    );
    Get.put<BudgetRepository>(FakeBudgetRepository());
    Get.put<DiscoveryRepository>(FakeDiscoveryRepository());
    Get.put<RemindersRepository>(FakeRemindersRepository());
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.home,
        getPages: [
          GetPage(
            name: AppRoutes.home,
            page: ShellView.new,
            binding: ShellBinding(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(Get.find<ShellController>().current.value, ShellTab.home);

    Get.offAllNamed<void>(AppRoutes.tab(ShellTab.events));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Get.find<ShellController>().current.value, ShellTab.events);
    expect(find.text('No upcoming events'), findsOneWidget);
  });
}
