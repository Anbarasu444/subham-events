import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/reminders/data/reminders_repository_impl.dart';
import 'package:user_app/features/reminders/domain/reminder.dart';
import 'package:user_app/features/reminders/presentation/controllers/reminder_controllers.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_checklist_repository.dart';
import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_event_vendors.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/fake_reminders.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

final DateTime _today = dateOnly(DateTime.now());

void main() {
  tearDown(Get.reset);

  group('defaultReminderTime (answer 6)', () {
    final now = DateTime(2026, 10, 8, 10, 30);
    test('6 PM the day before the due date', () {
      expect(
        defaultReminderTime(DateTime(2026, 10, 20), now),
        DateTime(2026, 10, 19, 18),
      );
    });
    test('tomorrow 6 PM when that has passed or there is no due date', () {
      expect(
        defaultReminderTime(DateTime(2026, 10, 8), now),
        DateTime(2026, 10, 9, 18),
      );
      expect(defaultReminderTime(null, now), DateTime(2026, 10, 9, 18));
    });
  });

  test('reminder JSON round-trips the instant in UTC', () {
    final at = DateTime(2026, 11, 6, 18, 30);
    final json = RemindersRepositoryImpl.toJson(
      ReminderInput(title: 'Call', remindAt: at, checklistItemId: 't1'),
    );
    expect(json['remindAt'], at.toUtc().toIso8601String());
    final r = RemindersRepositoryImpl.reminderFromJson({
      'id': 'r1',
      'eventId': 'e1',
      'eventTitle': 'Asha & Ravi',
      'title': 'Call',
      'remindAt': json['remindAt'],
      'status': 'SCHEDULED',
      'checklistItemId': 't1',
      'checklistItemTitle': 'Book photographer',
      'sentAt': null,
      'seenAt': null,
      'cancelReason': null,
      'version': 1,
    });
    expect(r.remindAt, at);
    expect(r.status, ReminderStatus.scheduled);
  });

  test('the form refuses a past time and reuses the key on retry', () async {
    final repo = FakeRemindersRepository();
    final now = DateTime(2026, 10, 8, 10);
    final c = ReminderFormController(
      repo,
      'e1',
      title: 'Call the caterer',
      at: DateTime(2026, 10, 8, 9),
      clock: () => now,
    )..onInit();
    expect(await c.submit(), isNull);
    expect(c.timeError.value, 'Choose a time in the future.');
    c.day.value = DateTime(2026, 10, 9);
    repo.failNext = const NetworkFailure();
    expect(await c.submit(), isNull);
    expect(await c.submit(), isNotNull);
    expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);
    c.onClose();
  });

  group('screens', () {
    Future<FakeRemindersRepository> pump(
      WidgetTester tester, {
      ShellTab tab = ShellTab.events,
      EventStatus status = EventStatus.planning,
    }) async {
      Get.testMode = true;
      usePhoneSize(tester);
      Get.put<AppConfig>(
        const AppConfig(
          flavor: Flavor.staging,
          apiBaseUrl: 'http://localhost:3000',
          appVersion: '1.0.0',
          buildNumber: '1',
        ),
      );
      final session = Get.put<SessionService>(
        testSession(const SignedInSession(testProfile)),
      );
      final readOnly = status != EventStatus.planning;
      final repo = FakeEventsRepository(
        events: [
          testEvent(
            'e1',
            date: _today.add(const Duration(days: 30)),
            title: 'Asha & Ravi',
            status: status,
          ),
        ],
        today: _today,
      );
      Get.put<EventsRepository>(repo);
      Get.put<ChecklistRepository>(
        FakeChecklistRepository(
          items: {
            'e1': [
              testItem(
                't1',
                title: 'Book photographer',
                dueDate: _today.add(const Duration(days: 10)),
              ),
            ],
          },
          onChanged: repo.notifyChanged,
        ),
      );
      Get.put<BudgetRepository>(
        FakeBudgetRepository(onChanged: repo.notifyChanged),
      );
      final reminders =
          Get.put<RemindersRepository>(
                FakeRemindersRepository(readOnlyEvents: readOnly ? {'e1'} : {}),
              )
              as FakeRemindersRepository;
      Get.put(MyEventsController(repo, session));
      registerExplore(FakeDiscoveryRepository());
      registerEngagement(onChanged: repo.notifyChanged);
      Get.put(HomeController(session, const []));
      Get.put(ShellController(initialTab: tab));
      await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
      await tester.pumpAndSettle();
      return reminders;
    }

    Future<void> openEvent(WidgetTester tester) async {
      if (find.text('Asha & Ravi').evaluate().isEmpty) {
        await tester.tap(find.text('Past'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Asha & Ravi'));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey<String>('overview')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('adds a reminder in Overview and cancels it after asking', (
      tester,
    ) async {
      final reminders = await pump(tester);
      await openEvent(tester);
      await scrollTo(tester, find.byKey(const ValueKey('add-reminder')));
      expect(find.textContaining('No reminders yet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-reminder')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Remind me to…'),
        'Call the caterer',
      );
      await tester.tap(find.text('Add reminder'));
      await tester.pumpAndSettle();
      expect(reminders.calls, contains('create:Call the caterer'));
      expect(find.textContaining('Reminder set for'), findsOneWidget);
      await scrollTo(tester, find.text('Call the caterer'));
      expect(find.text('Call the caterer'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel reminder Call the caterer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel reminder'));
      await tester.pumpAndSettle();
      expect(
        reminders.calls.where((c) => c.startsWith('cancel:')),
        hasLength(1),
      );
      expect(find.text('Call the caterer'), findsNothing);
    });

    testWidgets('“Remind me” on a task prefills its title and link', (
      tester,
    ) async {
      final reminders = await pump(tester);
      await openEvent(tester);
      await tester.ensureVisible(find.widgetWithText(Tab, 'Checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More actions for "Book photographer"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Book photographer'),
        findsOneWidget,
      );
      // 6 PM the day before the due date.
      final due = _today.add(const Duration(days: 9));
      expect(find.text(formatLongDate(due)), findsOneWidget);
      await tester.tap(find.text('Add reminder'));
      await tester.pumpAndSettle();
      expect(reminders.reminders.single.checklistItemId, 't1');
      expect(
        reminders.reminders.single.remindAt,
        DateTime(due.year, due.month, due.day, 18),
      );
    });

    testWidgets('a cancelled event’s reminders are read only', (tester) async {
      final reminders = await pump(tester, status: EventStatus.cancelled);
      reminders.seed('e1', 'Old', DateTime.now().add(const Duration(days: 1)));
      await openEvent(tester);
      await scrollTo(tester, find.text('Old'));
      expect(find.byKey(const ValueKey('add-reminder')), findsNothing);
      expect(find.byTooltip('Cancel reminder Old'), findsNothing);
    });

    testWidgets('Menu → Schedule lists upcoming reminders across events', (
      tester,
    ) async {
      final reminders = await pump(tester, tab: ShellTab.menu);
      reminders
        ..seed('e1', 'Later', DateTime.now().add(const Duration(days: 3)))
        ..seed('e1', 'Sooner', DateTime.now().add(const Duration(hours: 3)));
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      final sooner = tester.getTopLeft(find.text('Sooner'));
      final later = tester.getTopLeft(find.text('Later'));
      expect(sooner.dy, lessThan(later.dy));
    });

    testWidgets('Home shows due reminders until dismissed', (tester) async {
      Get.testMode = true;
      final reminders = FakeRemindersRepository()
        ..seed(
          'e1',
          'Pay the decorator',
          DateTime.now().subtract(const Duration(minutes: 5)),
          status: ReminderStatus.sent,
        )
        ..seed('e1', 'Next one', DateTime.now().add(const Duration(days: 1)));
      Get.put<RemindersRepository>(reminders);
      await pump(tester, tab: ShellTab.home);
      expect(find.text('Pay the decorator'), findsOneWidget);
      expect(find.textContaining('Next reminder: Next one'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss reminder Pay the decorator'));
      await tester.pumpAndSettle();
      expect(reminders.calls, contains('seen:r-1'));
      expect(find.text('Pay the decorator'), findsNothing);
    });

    testWidgets('the reminder sheet fits at 200 % text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester);
      await openEvent(tester);
      // At large text the header is tall: drag the whole screen instead.
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('add-reminder')),
        find.byType(NestedScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-reminder')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
