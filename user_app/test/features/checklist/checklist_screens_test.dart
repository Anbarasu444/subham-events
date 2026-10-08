import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/checklist/domain/entities/checklist_item.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/home/data/empty_section_source.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_checklist_repository.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

final DateTime _today = dateOnly(DateTime.now());
DateTime _inDays(int days) => _today.add(Duration(days: days));

void main() {
  tearDown(Get.reset);

  Future<FakeChecklistRepository> pump(
    WidgetTester tester, {
    List<PlannerEvent> events = const [],
    Map<String, List<ChecklistItem>> items = const {},
    Set<String> readOnly = const {},
    ShellTab tab = ShellTab.events,
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
    final repo = FakeEventsRepository(events: events, today: _today);
    Get.put<EventsRepository>(repo);
    final checklists = FakeChecklistRepository(
      items: items,
      readOnlyEvents: readOnly,
      onChanged: repo.notifyChanged,
    );
    Get.put<ChecklistRepository>(checklists);
    Get.put(MyEventsController(repo, session));
    Get.put(HomeController(session, buildDashboardSources(repo, checklists)));
    Get.put(ShellController(initialTab: tab));
    await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
    await tester.pumpAndSettle();
    return checklists;
  }

  /// Opens the event screen, then its Checklist tab (M10).
  Future<void> openChecklist(WidgetTester tester, String eventTitle) async {
    await tester.tap(find.text(eventTitle));
    await tester.pumpAndSettle();
    final tab = find.widgetWithText(Tab, 'Checklist');
    if (tab.evaluate().isEmpty) {
      // Small screen / large text: scroll the header away; the tabs pin.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('adds a task from the event page and ticks it with undo', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      events: [testEvent('e1', date: _inDays(5), title: 'Sangeet')],
    );
    await openChecklist(tester, 'Sangeet');
    expect(find.text('No tasks yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Task'), 'Book DJ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task').last);
    await tester.pumpAndSettle();
    expect(find.text('Book DJ'), findsOneWidget);
    expect(repo.items['e1']!.single.title, 'Book DJ');

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(repo.items['e1']!.single.isDone, isTrue);
    expect(find.text('1 of 1 done'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.items['e1']!.single.isDone, isFalse);
    expect(find.text('0 of 1 done'), findsOneWidget);
  });

  testWidgets('shows overdue tasks and moves, then deletes via the menu', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      events: [testEvent('e1', date: _inDays(5), title: 'Sangeet')],
      items: {
        'e1': [
          testItem(
            'a',
            title: 'Venue deposit',
            dueDate: _inDays(-2),
            overdue: true,
          ),
          testItem('b', title: 'Flowers', sortOrder: 1),
        ],
      },
    );
    await openChecklist(tester, 'Sangeet');
    expect(find.textContaining('Overdue · due'), findsOneWidget);
    expect(find.text('1 overdue'), findsOneWidget);

    await tester.tap(find.byTooltip('More actions for "Venue deposit"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'reorder:b,a');

    await tester.tap(find.byTooltip('More actions for "Flowers"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this task?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);
    expect(repo.items['e1']!.map((i) => i.id), ['a']);
  });

  testWidgets('a cancelled event’s checklist is read only', (tester) async {
    await pump(
      tester,
      events: [
        testEvent(
          'e1',
          date: _inDays(5),
          title: 'Sangeet',
          status: EventStatus.cancelled,
        ),
      ],
      items: {
        'e1': [testItem('a', title: 'Venue deposit')],
      },
      readOnly: {'e1'},
    );
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    await openChecklist(tester, 'Sangeet');
    expect(find.textContaining('read only'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(find.text('Add task'), findsNothing);
    expect(find.byTooltip('More actions for "Venue deposit"'), findsNothing);
  });

  group('Menu → Checklist', () {
    Future<void> openFromMenu(WidgetTester tester) async {
      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
    }

    testWidgets('one planning event opens its checklist directly', (
      tester,
    ) async {
      await pump(
        tester,
        tab: ShellTab.menu,
        events: [testEvent('e1', date: _inDays(5), title: 'Sangeet')],
      );
      await openFromMenu(tester);
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.textContaining('Sangeet'), findsOneWidget); // names the event
    });

    testWidgets('several events: pick one', (tester) async {
      await pump(
        tester,
        tab: ShellTab.menu,
        events: [
          testEvent('e1', date: _inDays(5), title: 'Sangeet'),
          testEvent('e2', date: _inDays(9), title: 'Reception'),
        ],
      );
      await openFromMenu(tester);
      expect(find.text('Choose an event'), findsOneWidget);
      await tester.tap(find.text('Reception'));
      await tester.pumpAndSettle();
      expect(find.text('No tasks yet'), findsOneWidget);
    });

    testWidgets('no events: offers to create one', (tester) async {
      await pump(tester, tab: ShellTab.menu);
      await openFromMenu(tester);
      expect(find.text('No events being planned'), findsOneWidget);
      expect(find.text('Create event'), findsOneWidget);
    });
  });

  testWidgets('Home shows checklist progress and urgent tasks', (tester) async {
    await pump(
      tester,
      tab: ShellTab.home,
      events: [
        testEvent(
          'e1',
          date: _inDays(5),
          title: 'Sangeet',
          checklist: const ChecklistSummary(total: 3, done: 1, overdue: 1),
        ),
      ],
      items: {
        'e1': [
          testItem('a', title: 'Flowers', dueDate: _inDays(3)),
          testItem('b', title: 'Deposit', dueDate: _inDays(-1), overdue: true),
          testItem('c', title: 'Cake', done: true),
        ],
      },
    );
    // Scroll the dashboard with a real drag gesture (see M7 tests).
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 done'), findsOneWidget);
    expect(find.text('Deposit · overdue'), findsOneWidget);
    expect(find.textContaining('Flowers · due'), findsOneWidget);

    await tester.tap(find.text('Open checklist'));
    await tester.pumpAndSettle();
    expect(Get.find<ShellController>().current.value, ShellTab.events);
    expect(find.text('To do (2)'), findsOneWidget);
  });

  testWidgets('checklist fits at 200 % text on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      events: [testEvent('e1', date: _inDays(5), title: 'Sangeet')],
      items: {
        'e1': [
          testItem(
            'a',
            title: 'Pay the venue deposit and confirm the hall',
            dueDate: _inDays(-1),
            overdue: true,
            notes: 'Ask about parking',
          ),
          testItem('b', title: 'Cake', done: true),
        ],
      },
    );
    await openChecklist(tester, 'Sangeet');
    expect(tester.takeException(), isNull);
  });
}
