@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/core/theme/app_theme.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/budget/presentation/views/budget_view.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/checklist/presentation/views/checklist_view.dart';
import 'package:user_app/features/event_vendors/domain/event_vendor.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/home/data/empty_section_source.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/home/presentation/views/home_tab_view.dart';
import 'package:user_app/features/invitations/domain/invitation.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../helpers/fake_budget_repository.dart';
import '../helpers/fake_checklist_repository.dart';
import '../helpers/fake_discovery_repository.dart';
import '../helpers/fake_event_vendors.dart';
import '../helpers/fake_events_repository.dart';
import '../helpers/fake_invitations.dart';
import '../helpers/test_session.dart';

/// Screenshots of the festive redesign (M22) with the real Kalam font.
/// Update with: flutter test --update-goldens --tags golden
final DateTime _today = dateOnly(DateTime.now());
Money _inr(String a) => Money.parse(a, 'INR');

Future<void> _loadFonts() async {
  final kalam = FontLoader('Kalam');
  for (final w in ['Light', 'Regular', 'Bold']) {
    kalam.addFont(rootBundle.load('assets/fonts/kalam/Kalam-$w.ttf'));
  }
  await kalam.load();
  final sdk = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '${sdk ?? '/Users/macbookpro/Documents/flutter'}'
    '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);
  tearDown(Get.reset);

  Future<void> setUp(WidgetTester tester) async {
    countdownClock = () => _today.add(const Duration(hours: 14, minutes: 18));
    addTearDown(() => countdownClock = DateTime.now);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.77;
    addTearDown(tester.view.reset);
    Get.testMode = true;
    Get.put<AppConfig>(
      const AppConfig(
        flavor: Flavor.prod,
        apiBaseUrl: 'https://x',
        appVersion: '1.0.0',
        buildNumber: '1',
      ),
    );
    final session = Get.put<SessionService>(
      testSession(const SignedInSession(testProfile)),
    );
    final event = testEvent(
      'e1',
      date: _today.add(const Duration(days: 12)),
      title: 'Asha & Ravi Wedding',
      checklist: const ChecklistSummary(total: 6, done: 2, overdue: 1),
    );
    final events = Get.put<EventsRepository>(
      FakeEventsRepository(events: [event], today: _today),
    );
    Get.put<ChecklistRepository>(
      FakeChecklistRepository(
        items: {
          'e1': [
            testItem(
              'a',
              title: 'Pay the hall advance',
              dueDate: _today.subtract(const Duration(days: 1)),
              overdue: true,
            ),
            testItem(
              'b',
              title: 'Book the photographer',
              dueDate: _today.add(const Duration(days: 3)),
            ),
            testItem(
              'c',
              title: 'Order wedding cards',
              dueDate: _today.add(const Duration(days: 35)),
            ),
            testItem('d', title: 'Shortlist caterers'),
            testItem('e', title: 'Fix the date', done: true),
            testItem('f', title: 'Make a guest list', done: true),
          ],
        },
      ),
    );
    final budgets = FakeBudgetRepository(
      categories: const ['Venue', 'Catering', 'Photography', 'Decoration'],
      totals: {'e1': _inr('500000.00')},
    );
    budgets.planned['e1'] = {
      FakeBudgetRepository.idOf('Venue'): _inr('150000.00'),
      FakeBudgetRepository.idOf('Catering'): _inr('200000.00'),
      FakeBudgetRepository.idOf('Photography'): _inr('40000.00'),
    };
    budgets.seedExpense(
      'e1',
      'Hall advance',
      _inr('50000.00'),
      _today,
      category: 'Venue',
    );
    budgets.seedExpense(
      'e1',
      'Album printing',
      _inr('9000.00'),
      _today,
      category: 'Photography',
    );
    Get.put<BudgetRepository>(budgets);
    Get.put(MyEventsController(events, session));
    final discovery = registerExplore();
    final engagement = registerEngagement();
    final v = engagement.vendors;
    v.seed('e1', sampleListing(1, title: 'Lotus Grand Mahal'));
    final quoted = v.seed('e1', sampleListing(2, title: 'Candid Clicks'));
    v.sendQuote('e1', quoted.id, '40000.00');
    v.seed('e1', sampleListing(3, title: 'Saffron Caterers'));
    final invitations =
        Get.find<InvitationsRepository>() as FakeInvitationsRepository;
    invitations.seed(
      'e1',
      status: InvitationStatus.published,
      rsvps: const RsvpList(
        totals: RsvpTotals(
          attending: 24,
          maybe: 6,
          notAttending: 3,
          guests: 61,
        ),
        rsvps: [],
      ),
    );
    Get.put(
      HomeController(
        session,
        buildDashboardSources(
          events,
          Get.find<ChecklistRepository>(),
          budgets,
          discovery,
          vendors: Get.find<EventVendorsRepository>(),
          invitations: invitations,
        ),
      ),
    );
  }

  Widget app(Widget home) => GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: home,
  );

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    // Decode the user's illustrations before capturing.
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('home', (tester) async {
    await setUp(tester);
    Get.put(ShellController(initialTab: ShellTab.home));
    await tester.pumpWidget(app(const ShellView()));
    await shot(tester, 'home_top');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await shot(tester, 'home_charts');
  });

  testWidgets('checklist', (tester) async {
    await setUp(tester);
    await tester.pumpWidget(
      app(const ChecklistView(eventId: 'e1', eventTitle: 'Asha & Ravi')),
    );
    await shot(tester, 'checklist');
  });

  testWidgets('budget and details', (tester) async {
    await setUp(tester);
    await tester.pumpWidget(app(const BudgetView(eventId: 'e1')));
    await shot(tester, 'budget');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await shot(tester, 'budget_categories');
    await tester.tap(find.text('Venue'));
    await shot(tester, 'budget_details');
  });

  testWidgets('menu', (tester) async {
    await setUp(tester);
    Get.put(ShellController(initialTab: ShellTab.menu));
    await tester.pumpWidget(app(const ShellView()));
    await shot(tester, 'menu');
  });
}
