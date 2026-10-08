import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/home/data/empty_section_source.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_checklist_repository.dart';
import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_event_vendors.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

final DateTime _today = dateOnly(DateTime.now());
DateTime _inDays(int days) => _today.add(Duration(days: days));
Money _inr(String amount) => Money.parse(amount, 'INR');

void main() {
  tearDown(Get.reset);

  Future<FakeBudgetRepository> pump(
    WidgetTester tester, {
    List<PlannerEvent> events = const [],
    Map<String, Money?> totals = const {},
    Set<String> readOnly = const {},
    List<String> archived = const [],
    Map<String, Money> plans = const {},
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
    final checklists = FakeChecklistRepository(onChanged: repo.notifyChanged);
    Get.put<ChecklistRepository>(checklists);
    final budgets = FakeBudgetRepository(
      totals: totals,
      readOnlyEvents: readOnly,
      archived: archived,
      onChanged: repo.notifyChanged,
    );
    for (final MapEntry(:key, :value) in plans.entries) {
      (budgets.planned['e1'] ??= {})[FakeBudgetRepository.idOf(key)] = value;
    }
    Get.put<BudgetRepository>(budgets);
    Get.put(MyEventsController(repo, session));
    final discovery = registerExplore();
    registerEngagement(onChanged: repo.notifyChanged);
    Get.put(
      HomeController(
        session,
        buildDashboardSources(repo, checklists, budgets, discovery),
      ),
    );
    Get.put(ShellController(initialTab: tab));
    await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
    await tester.pumpAndSettle();
    return budgets;
  }

  Future<void> openBudgetTab(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Budget'));
    await tester.pumpAndSettle();
  }

  /// Scrolls the Budget tab (or page) until [text] is visible, then taps it.
  Future<void> tapLine(WidgetTester tester, String text) async {
    final tab = find.byKey(const PageStorageKey<String>('budget'));
    final scrollable = find
        .descendant(
          of: tab.evaluate().isNotEmpty
              ? tab
              : find.byType(CustomScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(text),
      120,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> enterAmount(WidgetTester tester, String amount) async {
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('plans a category and shows what is left', (tester) async {
    final budgets = await pump(
      tester,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      totals: {'e1': _inr('50000.00')},
    );
    await openBudgetTab(tester, 'Asha & Ravi');
    expect(find.text('₹50,000'), findsWidgets);
    await tapLine(tester, 'Venue');
    expect(find.text('Plan for Venue'), findsOneWidget);
    await enterAmount(tester, '20,000.50');
    expect(
      budgets.calls,
      contains('set:${FakeBudgetRepository.idOf('Venue')}:20000.50'),
    );
    expect(find.text('₹20,000.50'), findsWidgets);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Not yet planned: ₹29,999.50'),
      -120,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey<String>('budget')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Not yet planned: ₹29,999.50'), findsOneWidget);
  });

  testWidgets('warns when the plan exceeds the total', (tester) async {
    await pump(
      tester,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      totals: {'e1': _inr('10000.00')},
    );
    await openBudgetTab(tester, 'Asha & Ravi');
    await tapLine(tester, 'Catering');
    await enterAmount(tester, '12000');
    await tester.scrollUntilVisible(
      find.text('Over budget by ₹2,000: planned more than your total.'),
      -120,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey<String>('budget')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.text('Over budget by ₹2,000: planned more than your total.'),
      findsOneWidget,
    );
  });

  testWidgets('rejects an invalid amount in the sheet', (tester) async {
    await pump(
      tester,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
    );
    await openBudgetTab(tester, 'Asha & Ravi');
    await tapLine(tester, 'Venue');
    await enterAmount(tester, '10.123');
    expect(
      find.textContaining('Enter an amount like 50000 or 50000.50'),
      findsOneWidget,
    );
  });

  testWidgets('clearing a plan asks first', (tester) async {
    final budgets = await pump(
      tester,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      plans: {'Venue': _inr('5000.00')},
    );
    await openBudgetTab(tester, 'Asha & Ravi');
    await tapLine(tester, 'Venue');
    await tester.tap(find.text('Clear planned amount'));
    await tester.pumpAndSettle();
    expect(find.text('Clear the plan for Venue?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(budgets.calls.where((c) => c.startsWith('clear:')), isEmpty);
    await tapLine(tester, 'Venue');
    await tester.tap(find.text('Clear planned amount'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(
      budgets.calls,
      contains('clear:${FakeBudgetRepository.idOf('Venue')}'),
    );
  });

  testWidgets('a plan for a retired category can only be removed', (
    tester,
  ) async {
    final budgets = await pump(
      tester,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      archived: ['Fireworks'],
      plans: {'Fireworks': _inr('3000.00')},
    );
    await openBudgetTab(tester, 'Asha & Ravi');
    await tapLine(tester, 'Fireworks');
    expect(find.text('No longer offered'), findsOneWidget);
    expect(find.text('Plan for Fireworks'), findsNothing);
    expect(find.text('Remove the plan for Fireworks?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(
      budgets.calls,
      contains('clear:${FakeBudgetRepository.idOf('Fireworks')}'),
    );
    expect(find.text('Fireworks'), findsNothing);
  });

  testWidgets('keeps the budget with a notice when a refresh fails', (
    tester,
  ) async {
    final budgets = await pump(
      tester,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      totals: {'e1': _inr('50000.00')},
    );
    await openBudgetTab(tester, 'Asha & Ravi');
    budgets.failNext = const NetworkFailure();
    (Get.find<EventsRepository>() as FakeEventsRepository).notifyChanged();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Showing saved data — you may be offline'), findsWidgets);
    expect(find.text('₹50,000'), findsWidgets);
  });

  group('my expenses', () {
    Future<void> openBudgetPage(WidgetTester tester) async {
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('adds an expense and counts it as spent', (tester) async {
      final budgets = await pump(
        tester,
        tab: ShellTab.menu,
        events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
        totals: {'e1': _inr('10000.00')},
      );
      await openBudgetPage(tester);
      expect(find.text('Left to spend'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('add-expense')));
      expect(
        find.text('No expenses yet. Tap Add to note one.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('add-expense')));
      await tester.pumpAndSettle();
      expect(find.text('New expense'), findsOneWidget);

      // Validation first.
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();
      expect(find.text('Enter what the money was for.'), findsOneWidget);
      expect(
        find.text('Enter an amount like 1500 or 1500.50.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'What was it for?'),
        'Flowers',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '0');
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();
      expect(find.text('The amount must be more than ₹0.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '1,250.50',
      );
      await tester.tap(find.text('No category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catering').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();

      expect(budgets.calls, contains('addExpense:Flowers:1250.50'));
      expect(budgets.expenses['e1']!.single.categoryId, 'cat-catering');
      await scrollTo(tester, find.text('Flowers'));
      expect(find.text('1 expense · ₹1,250.50'), findsOneWidget);
      expect(find.text('My expenses ₹1,250.50'), findsOneWidget); // line
    });

    testWidgets('edits and deletes an expense after confirming', (
      tester,
    ) async {
      final budgets = await pump(
        tester,
        tab: ShellTab.menu,
        events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      );
      budgets.seedExpense('e1', 'Auto fare', _inr('99.75'), _today);
      await openBudgetPage(tester);
      await scrollTo(tester, find.text('Auto fare'));
      await tester.tap(find.text('Auto fare'));
      await tester.pumpAndSettle();
      expect(find.text('Edit expense'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '120');
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      expect(budgets.calls, contains('updateExpense:exp-1:120.00'));

      await scrollTo(tester, find.byTooltip('Delete Auto fare'));
      await tester.tap(find.byTooltip('Delete Auto fare'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(budgets.calls, isNot(contains('deleteExpense:exp-1')));
      await tester.tap(find.byTooltip('Delete Auto fare'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(budgets.calls, contains('deleteExpense:exp-1'));
      expect(find.text('Auto fare'), findsNothing);
      expect(find.text('Expense deleted.'), findsOneWidget);
    });

    testWidgets('warns when bookings and expenses pass the total', (
      tester,
    ) async {
      final budgets = await pump(
        tester,
        tab: ShellTab.menu,
        events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
        totals: {'e1': _inr('1000.00')},
      );
      budgets.seedExpense('e1', 'Hall advance', _inr('1500.00'), _today);
      await openBudgetPage(tester);
      expect(
        find.text('Bookings and expenses are ₹500 over your total.'),
        findsOneWidget,
      );
      expect(find.text('Left to spend'), findsNothing);
    });

    testWidgets('a failed expense load offers a retry', (tester) async {
      final budgets = await pump(
        tester,
        tab: ShellTab.menu,
        events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      );
      budgets.failExpensesNext = const NetworkFailure();
      budgets.seedExpense('e1', 'Auto fare', _inr('99.75'), _today);
      await openBudgetPage(tester);
      await scrollTo(
        tester,
        find.textContaining('Could not load your expenses'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Try again'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Auto fare'));
      expect(find.text('Auto fare'), findsOneWidget);
    });

    testWidgets('read-only events list expenses without changes', (
      tester,
    ) async {
      final budgets = await pump(
        tester,
        events: [
          testEvent(
            'e1',
            date: _inDays(20),
            title: 'Asha & Ravi',
            status: EventStatus.cancelled,
          ),
        ],
        readOnly: {'e1'},
      );
      budgets.seedExpense('e1', 'Auto fare', _inr('99.75'), _today);
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      await openBudgetTab(tester, 'Asha & Ravi');
      await tapLine(tester, 'Auto fare');
      expect(find.text('Edit expense'), findsNothing);
      expect(find.byKey(const ValueKey('add-expense')), findsNothing);
      expect(find.byTooltip('Delete Auto fare'), findsNothing);
    });
  });

  testWidgets('a cancelled event’s budget is read only', (tester) async {
    await pump(
      tester,
      events: [
        testEvent(
          'e1',
          date: _inDays(20),
          title: 'Asha & Ravi',
          status: EventStatus.cancelled,
        ),
      ],
      readOnly: {'e1'},
    );
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    await openBudgetTab(tester, 'Asha & Ravi');
    await tester.scrollUntilVisible(
      find.textContaining('budget is read only'),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey<String>('budget')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('budget is read only'), findsOneWidget);
    expect(find.text('Set total'), findsNothing);
    await tapLine(tester, 'Venue');
    expect(find.text('Plan for Venue'), findsNothing);
  });

  testWidgets('Menu → Budget opens the only planning event', (tester) async {
    await pump(
      tester,
      tab: ShellTab.menu,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
    );
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('Asha & Ravi'), findsOneWidget);
  });

  testWidgets('Home budget overview opens the budget', (tester) async {
    final budgets = await pump(
      tester,
      tab: ShellTab.home,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      totals: {'e1': _inr('100000.00')},
    );
    (budgets.planned['e1'] = {})[FakeBudgetRepository.idOf('Venue')] = _inr(
      '40000.00',
    );
    budgets.seedExpense('e1', 'Hall advance', _inr('2500.00'), _today);
    await Get.find<HomeController>().refreshAll();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Planned ₹40,000 of ₹1,00,000'), findsOneWidget);
    expect(find.text('Not yet planned: ₹60,000'), findsOneWidget);
    expect(find.text('Spent so far: ₹2,500'), findsOneWidget);
    await tester.tap(find.text('Open budget'));
    await tester.pumpAndSettle();
    expect(Get.find<ShellController>().current.value, ShellTab.events);
    expect(find.text('By category'), findsOneWidget);
  });

  testWidgets('budget fits at 200 % text on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final budgets = await pump(
      tester,
      tab: ShellTab.menu,
      events: [testEvent('e1', date: _inDays(20), title: 'Asha & Ravi')],
      totals: {'e1': _inr('10000.00')},
    );
    budgets.seedExpense(
      'e1',
      'Flowers and garlands for the stage',
      _inr('12345678.90'),
      _today,
      category: 'Photography',
      note: 'Paid by uncle, to settle after the wedding',
    );
    await tester.scrollUntilVisible(
      find.text('Budget'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Flowers and garlands for the stage'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
