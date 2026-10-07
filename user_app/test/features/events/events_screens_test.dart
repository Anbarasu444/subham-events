import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/home/data/empty_section_source.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_events_repository.dart';
import '../../helpers/test_session.dart';

final DateTime _today = dateOnly(DateTime.now());
DateTime _inDays(int days) => _today.add(Duration(days: days));

void main() {
  tearDown(Get.reset);

  Future<FakeEventsRepository> pump(
    WidgetTester tester, {
    List<PlannerEvent> events = const [],
    ShellTab tab = ShellTab.events,
  }) async {
    Get.testMode = true;
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
    final repo = FakeEventsRepository(events: events, today: _today);
    Get.put<EventsRepository>(repo);
    Get.put(MyEventsController(repo, session));
    Get.put(HomeController(session, buildDashboardSources(repo)));
    Get.put(ShellController(initialTab: tab));
    await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
    await tester.pumpAndSettle();
    return repo;
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  /// The empty Upcoming list offers "Create event"; otherwise the FAB.
  Future<void> openNewEventForm(WidgetTester tester) async {
    final fab = find.widgetWithText(FloatingActionButton, 'New event');
    await tester.tap(
      fab.evaluate().isNotEmpty
          ? fab
          : find.widgetWithText(FilledButton, 'Create event'),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the top-most list until [finder] is built and visible, then taps.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('lists upcoming events and switches to past', (tester) async {
    await pump(
      tester,
      events: [
        testEvent('a', date: _inDays(12), title: 'Wedding day'),
        testEvent(
          'b',
          date: _inDays(5),
          title: 'Old party',
          status: EventStatus.cancelled,
        ),
      ],
    );
    expect(find.text('Wedding day'), findsOneWidget);
    expect(find.text('In 12 days'), findsOneWidget);
    expect(find.text('Old party'), findsNothing);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Old party'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('creates an event and opens it', (tester) async {
    final repo = await pump(tester);
    await openNewEventForm(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Birthday'));
    await tester.enterText(field('Title'), 'Meera turns 5');
    await tester.enterText(field('City'), 'Coimbatore');
    await tapVisible(tester, find.text('Choose a date'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Total budget (optional)'), '25,000');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create event'));

    expect(repo.events.single.title, 'Meera turns 5');
    expect(repo.events.single.eventType, 'Birthday');
    expect(repo.events.single.totalBudget!.amount, '25000.00');
    expect(find.text('Event'), findsOneWidget); // detail page app bar
    expect(find.text('₹25,000'), findsOneWidget);
    expect(find.text('Event created'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Meera turns 5'), findsOneWidget);
  });

  testWidgets('shows validation messages on the form', (tester) async {
    await pump(tester);
    await openNewEventForm(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create event'));
    expect(find.text('Enter the event type.'), findsOneWidget);
    expect(find.text('Choose the event date.'), findsOneWidget);
  });

  testWidgets('scrolls to the first invalid field after submit', (
    tester,
  ) async {
    await pump(tester);
    await openNewEventForm(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Wedding'));
    await tester.enterText(field('Title'), 'T');
    await tester.enterText(field('City'), 'Chennai');
    await tapVisible(tester, find.text('Choose a date'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapVisible(tester, field('Total budget (optional)'));
    await tester.enterText(field('Total budget (optional)'), '10.123');
    // Scroll back to the top, then submit from the bottom of the form.
    await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create event'));
    await tester.pumpAndSettle();
    final error = find.text('Enter an amount like 50000 or 50000.50.');
    expect(error, findsOneWidget);
    expect(tester.getRect(error).bottom, lessThan(600));
  });

  testWidgets('asks before discarding unsaved changes', (tester) async {
    await pump(tester);
    await openNewEventForm(tester);
    await tester.enterText(field('Title'), 'Draft');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('No upcoming events'), findsOneWidget);
  });

  testWidgets('cancels after confirmation, then deletes', (tester) async {
    final repo = await pump(
      tester,
      events: [testEvent('a', date: _inDays(3), title: 'Sangeet')],
    );
    await tester.tap(find.text('Sangeet'));
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Cancel event'),
    );
    expect(find.text('Cancel this event?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel event'));
    await tester.pumpAndSettle();
    expect(repo.events.single.status, EventStatus.cancelled);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reopen event'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete event'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.events, isEmpty);
    expect(find.text('Event deleted'), findsOneWidget);
    expect(find.text('No upcoming events'), findsOneWidget);
  });

  testWidgets('Home shows the next event and opens it in My Events', (
    tester,
  ) async {
    await pump(
      tester,
      tab: ShellTab.home,
      events: [
        testEvent('far', date: _inDays(40), title: 'Reception'),
        testEvent('near', date: _inDays(2), title: 'Mehendi'),
      ],
    );
    expect(find.text('Mehendi'), findsOneWidget);
    expect(find.text('Reception'), findsNothing);
    expect(find.text('Create event'), findsOneWidget);

    await tester.tap(find.text('Mehendi'));
    await tester.pumpAndSettle();
    expect(Get.find<ShellController>().current.value, ShellTab.events);
    expect(find.text('Event'), findsOneWidget);
  });

  testWidgets('Home keeps "Create event" when only past events exist', (
    tester,
  ) async {
    await pump(
      tester,
      tab: ShellTab.home,
      events: [testEvent('x', date: _inDays(4), status: EventStatus.completed)],
    );
    expect(
      find.text('No upcoming events. Your past events are in My Events.'),
      findsOneWidget,
    );
    expect(find.text('Create event'), findsOneWidget);
  });

  testWidgets('form and detail fit at 200 % text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pump(
      tester,
      events: [testEvent('a', date: _inDays(3), title: 'Sangeet night')],
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sangeet night'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openNewEventForm(tester);
    expect(tester.takeException(), isNull);
  });
}
