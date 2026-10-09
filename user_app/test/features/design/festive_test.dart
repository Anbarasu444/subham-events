import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/core/assets/app_illustrations.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/core/theme/app_style.dart';
import 'package:user_app/core/theme/app_theme.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/core/widgets/festive.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/budget/presentation/views/budget_view.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/checklist/presentation/views/checklist_view.dart';
import 'package:user_app/features/event_vendors/domain/event_vendor.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/explore/domain/listing.dart';
import 'package:user_app/features/home/data/event_charts_source.dart';
import 'package:user_app/features/invitations/domain/invitation.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_checklist_repository.dart';
import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_event_vendors.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/fake_invitations.dart';

final DateTime _today = dateOnly(DateTime.now());
Money _inr(String a) => Money.parse(a, 'INR');

void main() {
  tearDown(Get.reset);

  group('one style file (AC-1)', () {
    test('the theme takes its font and colours from app_style.dart', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyMedium!.fontFamily, AppFonts.body);
      expect(theme.textTheme.headlineSmall!.fontFamily, AppFonts.heading);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('every illustration path points at a real file', () {
      final missing = [
        for (final path in AppIllustrations.all)
          if (!File(path).existsSync()) path,
      ];
      expect(missing, isEmpty);
      expect(
        AppIllustrations.forEventType('Our Wedding'),
        AppIllustrations.eventWedding,
      );
      expect(
        AppIllustrations.forEventType('Pooja'),
        AppIllustrations.eventOther,
      );
    });

    test('no screen hard-codes colours or font families', () {
      final offenders = <String>[];
      final literal = RegExp(
        r'Color\(0x|fontFamily:\s*[\x27"]|[\x27"]assets/illustrations/',
      );
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.contains('core/theme/') ||
            f.path.endsWith('app_illustrations.dart')) {
          continue;
        }
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('festive components', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      ),
    );

    testWidgets('pill tabs report the tapped value', (tester) async {
      String? picked;
      await pump(
        tester,
        PillTabs<String>(
          items: const [('a', 'Alpha'), ('b', 'Beta')],
          selected: 'a',
          onSelected: (v) => picked = v,
        ),
      );
      await tester.tap(find.text('Beta'));
      expect(picked, 'b');
    });

    testWidgets('a donut chart speaks its numbers', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const DonutChart(
          slices: [DonutSlice('Paid', 3, AppChartColors.first)],
          centerText: '30%',
          semanticsLabel: '30% of the budget spent',
        ),
      );
      expect(find.bySemanticsLabel('30% of the budget spent'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a missing illustration falls back to an icon', (tester) async {
      await pump(
        tester,
        const Illustration(
          'assets/illustrations/does_not_exist.png',
          fallback: Icons.star,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('a gradient button calls back and shows busy', (tester) async {
      var taps = 0;
      await pump(
        tester,
        GradientButton(label: 'Sign up', onPressed: () => taps++),
      );
      await tester.tap(find.text('Sign up'));
      expect(taps, 1);
      await pump(
        tester,
        GradientButton(label: 'Sign up', isBusy: true, onPressed: () {}),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  test('Home charts count vendors by stage and invitation replies', () async {
    final events = FakeEventsRepository(
      events: [testEvent('e1', date: _today.add(const Duration(days: 9)))],
      today: _today,
    );
    final vendors = FakeEventVendorsRepository();
    vendors.seed('e1', sampleListing(1));
    final ev = vendors.seed('e1', sampleListing(2));
    vendors.sendQuote('e1', ev.id, '1000.00');
    final invitations = FakeInvitationsRepository()
      ..seed(
        'e1',
        status: InvitationStatus.published,
        rsvps: const RsvpList(
          totals: RsvpTotals(
            attending: 2,
            maybe: 1,
            notAttending: 0,
            guests: 6,
          ),
          rsvps: [],
        ),
      );
    final data =
        (await EventChartsSource(
                      events,
                      vendors,
                      invitations,
                    ).load(signedIn: true)
                    as Ok<Object?>)
                .value!
            as EventChartsData;
    expect(data.vendors.added, 1);
    expect(data.vendors.quoted, 1);
    expect(data.vendors.total, 2);
    expect(data.rsvps!.guests, 6);
  });

  group('screens', () {
    testWidgets('checklist month pills filter tasks', (tester) async {
      Get.testMode = true;
      final next = DateTime(_today.year, _today.month + 1, 10);
      Get.put<ChecklistRepository>(
        FakeChecklistRepository(
          items: {
            'e1': [
              testItem('a', title: 'Book hall', dueDate: _today),
              testItem('b', title: 'Buy flowers', dueDate: next),
              testItem('c', title: 'Call family'),
            ],
          },
        ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          home: const ChecklistView(eventId: 'e1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
      expect(find.text('No date'), findsOneWidget);
      await tester.tap(find.text(formatMonthYear(next)));
      await tester.pumpAndSettle();
      expect(find.text('Buy flowers'), findsOneWidget);
      expect(find.text('Book hall'), findsNothing);
      expect(find.text('Call family'), findsNothing);
      expect(find.byTooltip('Add task'), findsOneWidget);
      await tester.tap(find.text('No date'));
      await tester.pumpAndSettle();
      expect(find.text('Call family'), findsOneWidget);
    });

    testWidgets('a budget category opens its details', (tester) async {
      Get.testMode = true;
      final events = FakeEventsRepository(
        events: [testEvent('e1', date: _today.add(const Duration(days: 9)))],
        today: _today,
      );
      Get.put<EventsRepository>(events);
      final budgets = FakeBudgetRepository(totals: {'e1': _inr('100000.00')});
      (budgets.planned['e1'] = {})[FakeBudgetRepository.idOf('Photography')] =
          _inr('30000.00');
      budgets.seedExpense(
        'e1',
        'Album printing',
        _inr('5000.00'),
        _today,
        category: 'Photography',
      );
      Get.put<BudgetRepository>(budgets);
      final vendors =
          Get.put<EventVendorsRepository>(FakeEventVendorsRepository())
              as FakeEventVendorsRepository;
      vendors.seed(
        'e1',
        sampleListing(
          1,
          category: VendorCategory(
            id: FakeBudgetRepository.idOf('Photography'),
            name: 'Photography',
            slug: 'photography',
          ),
        ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          home: const BudgetView(eventId: 'e1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Photography'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Spent: ₹5,000'), findsOneWidget);
      await tester.tap(find.text('Photography'));
      await tester.pumpAndSettle();
      expect(find.text('DETAILS'), findsOneWidget);
      expect(find.text('BALANCE'), findsOneWidget);
      expect(find.text('Left in the plan: ₹25,000'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Album printing'), 100);
      expect(find.text('Album printing'), findsOneWidget);
      expect(find.text('Change plan'), findsOneWidget);
    });
  });
}
