import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/core/state/view_state.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/explore/data/discovery_repository_impl.dart';
import 'package:user_app/features/explore/domain/listing.dart';
import 'package:user_app/features/explore/presentation/controllers/explore_controller.dart';
import 'package:user_app/features/home/data/explore_section_source.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

final DateTime _today = dateOnly(DateTime.now());
Money _inr(String amount) => Money.parse(amount, 'INR');
Future<void> _settle() => Future<void>.delayed(Duration.zero);

List<ListingCard> _catalogue() => [
  sampleListing(1, title: 'Candid wedding photography', areas: ['Tambaram']),
  sampleListing(
    2,
    title: 'Grand wedding hall',
    category: sampleCategories[0],
    price: '150000.00',
  ),
  sampleListing(
    3,
    title: 'Kongu catering',
    city: 'Coimbatore',
    category: sampleCategories[1],
    price: '380.00',
  ),
];

void main() {
  tearDown(Get.reset);

  group('DiscoveryRepositoryImpl.listingFromJson', () {
    test('reads exact money and rating', () {
      final card = DiscoveryRepositoryImpl.listingFromJson({
        'id': 'l1',
        'title': 'Candid',
        'category': {'id': 'c1', 'name': 'Photography', 'slug': 'photography'},
        'vendor': {'id': 'v1', 'businessName': 'Candid Frames'},
        'city': 'Chennai',
        'serviceAreas': ['Vellore'],
        'startingPrice': {'amount': '25000.10', 'currency': 'INR'},
        'rating': {'average': '4.5', 'count': 2},
        'coverImageUrl': null,
        'publishedAt': '2026-10-01T10:00:00.000Z',
      });
      expect(card.startingPrice, _inr('25000.10'));
      expect(card.vendorName, 'Candid Frames');
      expect(card.ratingAverage, '4.5');
      expect(card.serviceAreas, ['Vellore']);
    });
  });

  group('ExploreController', () {
    late FakeDiscoveryRepository discovery;
    late FakeEventsRepository events;

    ExploreController make({bool signedIn = true}) => ExploreController(
      discovery,
      events,
      testSession(
        signedIn ? const SignedInSession(testProfile) : const GuestSession(),
      ),
      searchDelay: const Duration(milliseconds: 10),
      pageSize: 2,
    );

    setUp(() {
      discovery = FakeDiscoveryRepository(listings: _catalogue());
      events = FakeEventsRepository(
        events: [testEvent('e1', date: _today.add(const Duration(days: 9)))],
        today: _today,
      );
    });

    test('starts in the next event’s city when signed in', () async {
      final c = make()..onInit();
      await c.start();
      expect(c.query.value.city, 'Chennai');
      expect(discovery.queries.last.city, 'Chennai');
      c.onClose();
    });

    test('guests start with every city', () async {
      final c = make(signedIn: false)..onInit();
      await c.start();
      expect(c.query.value.city, isNull);
      c.onClose();
    });

    test('pages to the end without repeats', () async {
      final c = make(signedIn: false)..onInit();
      await c.start();
      expect(
        (c.results.value as Content<List<ListingCard>>).data,
        hasLength(2),
      );
      expect(c.hasMore, isTrue);
      await c.loadMore();
      final ids = (c.results.value as Content<List<ListingCard>>).data
          .map((l) => l.id)
          .toList();
      expect(ids, ['l1', 'l2', 'l3']);
      expect(c.hasMore, isFalse);
      await c.loadMore(); // nothing more to load
      expect(discovery.queries, hasLength(2));
      c.onClose();
    });

    test('debounces typing into one search', () async {
      final c = make(signedIn: false)..onInit();
      await c.start();
      final before = discovery.queries.length;
      c
        ..setText('c')
        ..setText('ca')
        ..setText(' candid ');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(discovery.queries.length, before + 1);
      expect(discovery.queries.last.text, 'candid');
      expect(
        (c.results.value as Content<List<ListingCard>>).data.single.id,
        'l1',
      );
      c.onClose();
    });

    test('a failed refresh keeps the results, marked stale', () async {
      final c = make(signedIn: false)..onInit();
      await c.start();
      discovery.failNext = const NetworkFailure();
      await c.search();
      final state = c.results.value as Content<List<ListingCard>>;
      expect(state.isStale, isTrue);
      expect(state.data, isNotEmpty);
      c.onClose();
    });

    test('a failed page offers a retry and keeps what was loaded', () async {
      final c = make(signedIn: false)..onInit();
      await c.start();
      discovery.failNext = const NetworkFailure();
      await c.loadMore();
      expect(c.loadMoreFailure.value, isA<NetworkFailure>());
      expect(
        (c.results.value as Content<List<ListingCard>>).data,
        hasLength(2),
      );
      await c.loadMore();
      expect(c.loadMoreFailure.value, isNull);
      expect(
        (c.results.value as Content<List<ListingCard>>).data,
        hasLength(3),
      );
      c.onClose();
    });

    test('Home can open it with a preset before it started', () async {
      final c = make(signedIn: false)..onInit();
      c.openWith(categoryId: 'cat-catering', city: 'Coimbatore');
      await _settle();
      await _settle();
      expect(c.query.value.categoryId, 'cat-catering');
      expect(
        (c.results.value as Content<List<ListingCard>>).data.single.id,
        'l3',
      );
      c.onClose();
    });
  });

  group('ExploreSectionSource', () {
    test(
      'falls back to everywhere when the event city has no vendors',
      () async {
        final discovery = FakeDiscoveryRepository(
          listings: [_catalogue()[2]], // Coimbatore only
        );
        final events = FakeEventsRepository(
          events: [testEvent('e1', date: _today.add(const Duration(days: 9)))],
          today: _today,
        );
        final result = await ExploreSectionSource(
          discovery,
          events,
        ).load(signedIn: true);
        final data = (result as dynamic).value as ExploreSectionData;
        expect(data.city, isNull);
        expect(data.listings.single.id, 'l3');
        expect(discovery.queries.map((q) => q.city), ['Chennai', null]);
      },
    );
  });

  group('Explore screen', () {
    Future<FakeDiscoveryRepository> pump(
      WidgetTester tester, {
      List<ListingCard>? listings,
      bool signedIn = false,
      ShellTab tab = ShellTab.explore,
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
        testSession(
          signedIn ? const SignedInSession(testProfile) : const GuestSession(),
        ),
      );
      final events = Get.put<EventsRepository>(
        FakeEventsRepository(
          events: signedIn
              ? [testEvent('e1', date: _today.add(const Duration(days: 9)))]
              : const [],
          today: _today,
        ),
      );
      Get.put(MyEventsController(events, session));
      final discovery = registerExplore(
        FakeDiscoveryRepository(listings: listings ?? _catalogue()),
      );
      Get.put(
        HomeController(session, [ExploreSectionSource(discovery, events)]),
      );
      Get.put(ShellController(initialTab: tab));
      await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
      await tester.pumpAndSettle();
      return discovery;
    }

    testWidgets('guests browse listings with starting prices', (tester) async {
      await pump(tester);
      expect(find.text('Candid wedding photography'), findsOneWidget);
      expect(find.text('Starting from ₹25,000'), findsOneWidget);
      expect(find.text('Chennai · also Tambaram'), findsOneWidget);
      await tester.tap(find.text('Candid wedding photography'));
      await tester.pumpAndSettle();
      expect(find.text('About this service'), findsOneWidget);
    });

    testWidgets('filters by category and search text', (tester) async {
      final discovery = await pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Catering'));
      await tester.pumpAndSettle();
      expect(discovery.queries.last.categoryId, 'cat-catering');
      expect(find.text('Kongu catering'), findsOneWidget);
      expect(find.text('Grand wedding hall'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hall');
      await tester.pumpAndSettle();
      expect(find.text('Grand wedding hall'), findsOneWidget);
      expect(find.text('Kongu catering'), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Kongu catering'), findsOneWidget);
    });

    testWidgets('the filter sheet sets city, exact prices and sort', (
      tester,
    ) async {
      final discovery = await pump(tester);
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Minimum'),
        '50000',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Maximum'), '100');
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(
        find.text('The maximum must not be less than the minimum.'),
        findsOneWidget,
      );
      await tester.enterText(find.widgetWithText(TextField, 'Minimum'), '');
      await tester.enterText(
        find.widgetWithText(TextField, 'Maximum'),
        '30,000.50',
      );
      await tester.tap(find.text('Any city'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chennai').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price: high to low'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      final q = discovery.queries.last;
      expect(q.city, 'Chennai');
      expect(q.minPrice, isNull);
      expect(q.maxPrice, _inr('30000.50'));
      expect(q.sort, ListingSort.priceHighToLow);
      expect(find.text('Up to ₹30,000.50'), findsOneWidget);
      expect(find.text('Candid wedding photography'), findsOneWidget);
      expect(find.text('Grand wedding hall'), findsNothing);
      await tester.tap(find.byTooltip('Remove price range'));
      await tester.pumpAndSettle();
      expect(find.text('Grand wedding hall'), findsOneWidget);
    });

    testWidgets('no matches offers to clear filters', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'fireworks');
      await tester.pumpAndSettle();
      expect(find.text('No vendors match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Grand wedding hall'), findsOneWidget);
    });

    testWidgets('an error offers a retry', (tester) async {
      // Home loads its own section first; then Explore's first search fails.
      final discovery = await pump(tester, tab: ShellTab.home);
      discovery.failNext = const NetworkFailure();
      Get.find<ShellController>().select(ShellTab.explore);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Grand wedding hall'), findsOneWidget);
    });

    testWidgets('scrolling loads the next page', (tester) async {
      final discovery = await pump(
        tester,
        listings: [for (var i = 1; i <= 45; i++) sampleListing(i)],
      );
      expect(find.text('Listing 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Listing 45'),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey<String>('explore')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Listing 45'), findsOneWidget);
      expect(discovery.cursors.whereType<String>(), isNotEmpty);
    });

    testWidgets('Home shows vendors near the next event and opens Explore', (
      tester,
    ) async {
      final discovery = await pump(tester, signedIn: true, tab: ShellTab.home);
      expect(find.text('In Chennai'), findsOneWidget);
      expect(find.text('Candid wedding photography'), findsOneWidget);
      expect(find.text('Kongu catering'), findsNothing); // Coimbatore
      await tester.ensureVisible(find.text('See all vendors'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all vendors'));
      await tester.pumpAndSettle();
      expect(Get.find<ShellController>().current.value, ShellTab.explore);
      expect(discovery.queries.last.city, 'Chennai');
      expect(find.widgetWithText(InputChip, 'Chennai'), findsOneWidget);
    });

    testWidgets('Explore fits at 200 % text on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        listings: [
          sampleListing(
            1,
            title: 'A very long listing title for a wedding photographer',
            areas: ['Tambaram', 'Velachery', 'Kanchipuram'],
            price: '9999999999.99',
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
