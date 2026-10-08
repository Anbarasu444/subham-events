import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/app/routes/app_routes.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/platform/external_actions.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/event_vendors/data/event_vendors_repository_impl.dart';
import 'package:user_app/features/event_vendors/domain/event_vendor.dart';
import 'package:user_app/features/event_vendors/presentation/controllers/enquiry_form_controller.dart';
import 'package:user_app/features/event_vendors/presentation/controllers/event_vendors_controller.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/explore/domain/listing.dart';
import 'package:user_app/features/explore/presentation/controllers/explore_controller.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';
import 'package:user_app/features/wishlist/presentation/controllers/wishlist_controller.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_checklist_repository.dart';
import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_event_vendors.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

final DateTime _today = dateOnly(DateTime.now());

List<ListingCard> _catalogue() => [
  sampleListing(1, title: 'Candid wedding photography'),
  sampleListing(2, title: 'Grand wedding hall', category: sampleCategories[0]),
];

PlannerEvent _event({EventStatus status = EventStatus.planning}) => testEvent(
  'e1',
  date: _today.add(const Duration(days: 30)),
  title: 'Asha & Ravi',
  status: status,
);

void main() {
  tearDown(Get.reset);

  group('WishlistController', () {
    test('guests are asked to sign in; nothing is sent', () async {
      final repo = FakeWishlistRepository();
      final c = WishlistController(repo, testSession(const GuestSession()))
        ..onInit();
      expect(await c.toggle('l1'), isA<NeedsSignIn>());
      expect(repo.calls, isEmpty);
      c.onClose();
    });

    test('saves optimistically and rolls back on failure', () async {
      final repo = FakeWishlistRepository();
      final c = WishlistController(
        repo,
        testSession(const SignedInSession(testProfile)),
      )..onInit();
      expect(await c.toggle('l1'), isA<Saved>());
      expect(c.isSaved('l1'), isTrue);
      repo.failNext = const NetworkFailure();
      expect(await c.toggle('l2'), isA<SaveFailed>());
      expect(c.isSaved('l2'), isFalse);
      expect(await c.toggle('l1'), isA<Unsaved>());
      expect(c.isSaved('l1'), isFalse);
      c.onClose();
    });
  });

  group('EnquiryFormController', () {
    final vendor = EventVendor(
      id: 'ev1',
      status: EventVendorStatus.added,
      notes: null,
      listing: _catalogue().first,
      isAvailable: true,
      enquiries: const [],
      canEnquire: true,
      version: 1,
    );

    test('starts from a friendly text with only A9 details', () {
      final text = EnquiryFormController.starterText(_event(), vendor);
      expect(text, contains('Wedding'));
      expect(text, contains('Chennai'));
      expect(text, contains('Candid wedding photography'));
      expect(text, isNot(contains('₹'))); // never the budget
    });

    test('validates and reuses the key when retrying', () async {
      final repo = FakeEventVendorsRepository(listings: _catalogue());
      repo.seed('e1', _catalogue().first);
      final c = EnquiryFormController(
        repo,
        _event(),
        repo.byEvent['e1']!.single,
      )..onInit();
      c.message.text = 'too short';
      expect(await c.submit(), isNull);
      expect(c.messageError.value, 'Write at least 10 characters.');
      c.message.text = 'Please share your availability.';
      repo.failNext = const NetworkFailure();
      expect(await c.submit(), isNull);
      expect(c.formError.value, contains('offline'));
      final sent = await c.submit();
      expect(sent?.status, EventVendorStatus.enquired);
      expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);
      c.onClose();
    });
  });

  test('vendorFromJson reads status, enquiries and availability', () {
    final v = EventVendorsRepositoryImpl.vendorFromJson({
      'id': 'ev1',
      'status': 'ENQUIRED',
      'notes': 'Parking?',
      'isAvailable': true,
      'canEnquire': false,
      'version': 3,
      'createdAt': '2026-10-08T10:00:00.000Z',
      'listing': {
        'id': 'l1',
        'title': 'Candid',
        'category': {'id': 'c1', 'name': 'Photography', 'slug': 'photography'},
        'vendor': {'id': 'v1', 'businessName': 'Candid Frames'},
        'city': 'Chennai',
        'serviceAreas': <String>[],
        'startingPrice': {'amount': '25000.00', 'currency': 'INR'},
        'rating': {'average': null, 'count': 0},
        'coverImageUrl': null,
        'publishedAt': '2026-10-01T10:00:00.000Z',
      },
      'enquiries': [
        {
          'id': 'q1',
          'status': 'OPEN',
          'message': 'Hello there vendor',
          'preferredDate': '2026-11-01',
          'closedBy': null,
          'closedAt': null,
          'createdAt': '2026-10-08T10:00:00.000Z',
        },
      ],
    });
    expect(v.status, EventVendorStatus.enquired);
    expect(v.liveEnquiry?.preferredDate, DateTime(2026, 11, 1));
    expect(v.notes, 'Parking?');
  });

  group('screens', () {
    Future<
      ({
        FakeWishlistRepository wishlist,
        FakeEventVendorsRepository vendors,
        FakeEventsRepository events,
      })
    >
    pump(
      WidgetTester tester, {
      bool signedIn = true,
      ShellTab tab = ShellTab.explore,
      List<PlannerEvent>? events,
      Set<String> readOnly = const {},
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
      final repo = FakeEventsRepository(
        events: events ?? (signedIn ? [_event()] : const []),
        today: _today,
      );
      Get.put<EventsRepository>(repo);
      Get.put<ChecklistRepository>(
        FakeChecklistRepository(onChanged: repo.notifyChanged),
      );
      Get.put<BudgetRepository>(
        FakeBudgetRepository(onChanged: repo.notifyChanged),
      );
      Get.put<ExternalActions>(FakeExternalActions());
      Get.put(MyEventsController(repo, session));
      registerExplore(FakeDiscoveryRepository(listings: _catalogue()));
      final engagement = registerEngagement(
        listings: _catalogue(),
        readOnlyEvents: readOnly,
        onChanged: repo.notifyChanged,
      );
      Get.put(HomeController(session, const []));
      Get.put(ShellController(initialTab: tab));
      await tester.pumpWidget(
        GetMaterialApp(
          home: const ShellView(),
          getPages: [
            GetPage(
              name: AppRoutes.signIn,
              page: () => const Scaffold(body: Text('Sign-in page')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return (
        wishlist: engagement.wishlist,
        vendors: engagement.vendors,
        events: repo,
      );
    }

    Future<void> openEventVendors(WidgetTester tester) async {
      Get.find<ShellController>().select(ShellTab.events);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha & Ravi'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
    }

    testWidgets('the heart saves a vendor; guests are asked to sign in', (
      tester,
    ) async {
      final r = await pump(tester);
      await tester.tap(find.byTooltip('Save Candid wedding photography'));
      await tester.pumpAndSettle();
      expect(r.wishlist.saved, ['l1']);
      expect(
        find.byTooltip('Remove Candid wedding photography from saved'),
        findsOneWidget,
      );
    });

    testWidgets('guests tapping the heart see a sign-in prompt', (
      tester,
    ) async {
      final r = await pump(tester, signedIn: false);
      await tester.tap(find.byTooltip('Save Candid wedding photography'));
      await tester.pump();
      expect(find.text('Sign in to save vendors.'), findsOneWidget);
      expect(r.wishlist.calls, isEmpty);
      // The Saved filter asks guests to sign in too.
      await tester.tap(find.widgetWithText(FilterChip, 'Saved'));
      await tester.pump();
      expect(find.text('Sign in to see your saved vendors.'), findsOneWidget);
    });

    testWidgets('the Saved filter shows only saved vendors', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Saved'));
      await tester.pumpAndSettle();
      expect(Get.find<ExploreController>().query.value.saved, isTrue);
    });

    testWidgets('Add to event adds the vendor to the only planning event', (
      tester,
    ) async {
      final r = await pump(tester);
      await tester.tap(find.text('Candid wedding photography'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to event'));
      await tester.pumpAndSettle();
      expect(r.vendors.calls, contains('add:e1:l1'));
      expect(find.text('Added to Asha & Ravi.'), findsOneWidget);
    });

    testWidgets('guests tapping Add to event are asked to sign in', (
      tester,
    ) async {
      final r = await pump(tester, signedIn: false);
      await tester.tap(find.text('Candid wedding photography'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to event'));
      await tester.pump();
      expect(
        find.text('Sign in to add vendors to your events.'),
        findsOneWidget,
      );
      expect(r.vendors.calls, isEmpty);
    });

    testWidgets('Vendors tab: send, close, note and remove', (tester) async {
      final r = await pump(tester, tab: ShellTab.home);
      r.vendors.seed('e1', _catalogue().first);
      await openEventVendors(tester);
      expect(find.text('Vendor 1'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);

      await tester.tap(find.text('Send enquiry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('we are planning a Wedding'), findsOneWidget);
      expect(
        find.textContaining('not your phone, email, budget or notes'),
        findsOneWidget,
      );
      await tester.tap(find.text('Send enquiry').last);
      await tester.pumpAndSettle();
      expect(r.vendors.calls, contains('enquire:ev-1'));
      expect(find.text('Enquiry sent'), findsOneWidget); // status chip
      expect(
        find.textContaining('The vendor will reply in the app.'),
        findsWidgets,
      );

      await tester.tap(find.text('Close enquiry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Close enquiry').last);
      await tester.pumpAndSettle();
      expect(
        r.vendors.calls.where((c) => c.startsWith('close:')),
        hasLength(1),
      );
      expect(find.text('Enquire again'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('More for Vendor 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More for Vendor 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Ask about drone');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Note: Ask about drone'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('More for Vendor 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More for Vendor 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from event'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('No vendors yet'), findsOneWidget);
    });

    testWidgets('a cancelled event’s vendors are read only', (tester) async {
      final r = await pump(
        tester,
        tab: ShellTab.home,
        events: [_event(status: EventStatus.cancelled)],
        readOnly: {'e1'},
      );
      r.vendors.seed('e1', _catalogue().first);
      Get.find<ShellController>().select(ShellTab.events);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha & Ravi'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      expect(find.textContaining('vendors are read only'), findsOneWidget);
      expect(find.text('Send enquiry'), findsNothing);
      expect(find.byTooltip('More for Vendor 1'), findsNothing);
    });

    testWidgets('Menu → Saved vendors lists saved ones', (tester) async {
      final r = await pump(tester, tab: ShellTab.menu);
      r.wishlist.saved.add('l2');
      await Get.find<WishlistController>().refreshIds();
      await tester.tap(find.text('Saved vendors'));
      await tester.pumpAndSettle();
      expect(find.text('Grand wedding hall'), findsOneWidget);
      // Unsaving here removes it from the list.
      await tester.tap(find.byTooltip('Remove Grand wedding hall from saved'));
      await tester.pumpAndSettle();
      expect(find.text('No saved vendors yet'), findsOneWidget);
    });

    testWidgets('Vendors tab fits at 200 % text on a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final r = await pump(tester, tab: ShellTab.home);
      r.vendors.seed('e1', _catalogue().first);
      Get.find<ShellController>().select(ShellTab.events);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha & Ravi'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  test('vendorFromJson reads quotes and the booking (M15)', () {
    final v = EventVendorsRepositoryImpl.vendorFromJson({
      'id': 'ev1',
      'status': 'BOOKED',
      'notes': null,
      'isAvailable': true,
      'canEnquire': false,
      'version': 4,
      'createdAt': '2026-10-08T10:00:00.000Z',
      'listing': {
        'id': 'l1',
        'title': 'Candid',
        'category': {'id': 'c1', 'name': 'Photography', 'slug': 'photography'},
        'vendor': {'id': 'v1', 'businessName': 'Candid Frames'},
        'city': 'Chennai',
        'serviceAreas': <String>[],
        'startingPrice': {'amount': '25000.00', 'currency': 'INR'},
        'rating': {'average': null, 'count': 0},
        'coverImageUrl': null,
        'publishedAt': '2026-10-01T10:00:00.000Z',
      },
      'enquiries': <Object>[],
      'quotations': [
        {
          'id': 'q2',
          'enquiryId': 'e1',
          'status': 'ACCEPTED',
          'amount': {'amount': '30000.10', 'currency': 'INR'},
          'description': null,
          'validUntil': '2026-11-01',
          'revisionNo': 2,
          'createdAt': '2026-10-08T10:00:00.000Z',
          'respondedAt': '2026-10-08T11:00:00.000Z',
        },
        {
          'id': 'q1',
          'enquiryId': 'e1',
          'status': 'SUPERSEDED',
          'amount': {'amount': '32000.00', 'currency': 'INR'},
          'description': null,
          'validUntil': '2026-11-01',
          'revisionNo': 1,
          'createdAt': '2026-10-08T09:00:00.000Z',
          'respondedAt': null,
        },
      ],
      'booking': {
        'id': 'b1',
        'status': 'CONFIRMED',
        'agreedAmount': {'amount': '30000.10', 'currency': 'INR'},
        'serviceDate': '2026-11-07',
        'cancelledBy': null,
        'cancelReason': null,
        'completedAt': null,
        'createdAt': '2026-10-08T11:00:00.000Z',
        'canCancel': true,
        'canComplete': false,
      },
    });
    expect(v.quotations.first.status, QuotationStatus.accepted);
    expect(v.openQuote, isNull);
    expect(v.booking?.agreedAmount, Money.parse('30000.10', 'INR'));
    expect(v.booking?.serviceDate, DateTime(2026, 11, 7));
  });

  test('a retried accept reuses the idempotency key', () async {
    final events = FakeEventsRepository(events: [_event()], today: _today);
    final repo = FakeEventVendorsRepository(listings: _catalogue());
    final ev = repo.seed('e1', _catalogue().first);
    final quote = repo.sendQuote('e1', ev.id, '180000.00');
    final c = EventVendorsController(repo, events, 'e1')..onInit();
    await Future<void>.delayed(Duration.zero);
    final vendor = repo.byEvent['e1']!.single;
    repo.failNext = const NetworkFailure();
    expect(await c.acceptQuotation(vendor, quote), isA<NetworkFailure>());
    expect(await c.acceptQuotation(vendor, quote), isNull);
    expect(repo.idempotencyKeys, hasLength(2));
    expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);
    c.onClose();
  });

  group('quotes and bookings (M15)', () {
    Future<FakeEventVendorsRepository> pumpQuoted(
      WidgetTester tester, {
      bool expired = false,
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
      final repo = FakeEventsRepository(events: [_event()], today: _today);
      Get.put<EventsRepository>(repo);
      Get.put<ChecklistRepository>(
        FakeChecklistRepository(onChanged: repo.notifyChanged),
      );
      Get.put<BudgetRepository>(
        FakeBudgetRepository(onChanged: repo.notifyChanged),
      );
      Get.put(MyEventsController(repo, session));
      registerExplore(FakeDiscoveryRepository(listings: _catalogue()));
      final vendors = registerEngagement(
        listings: _catalogue(),
        onChanged: repo.notifyChanged,
      ).vendors;
      final ev = vendors.seed('e1', _catalogue().first);
      vendors.sendQuote(
        'e1',
        ev.id,
        '180000.00',
        expired: expired,
        validUntil: DateTime(2026, 11, 20),
      );
      Get.put(HomeController(session, const []));
      Get.put(ShellController(initialTab: ShellTab.events));
      await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha & Ravi'));
      await tester.pumpAndSettle();
      // At large text the header is tall: scroll it away to reach the tabs.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Vendors'));
      await tester.pumpAndSettle();
      return vendors;
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('accepting a quote books the vendor at that amount', (
      tester,
    ) async {
      final vendors = await pumpQuoted(tester);
      expect(find.text('Quote received'), findsOneWidget);
      expect(find.text('₹1,80,000'), findsOneWidget);
      expect(find.text('Valid until Fri, 20 Nov 2026'), findsOneWidget);
      await scrollTo(tester, find.text('Accept & book'));
      await tester.tap(find.text('Accept & book'));
      await tester.pumpAndSettle();
      expect(find.text('Book Vendor 1 for ₹1,80,000?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Book'));
      await tester.pumpAndSettle();
      expect(vendors.calls.where((c) => c.startsWith('accept:')), hasLength(1));
      expect(find.text('Vendor 1 is booked.'), findsOneWidget);
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Agreed ₹1,80,000'), findsOneWidget);
      expect(
        find.text('Paid ₹0 of ₹1,80,000 · balance ₹1,80,000'),
        findsOneWidget,
      );
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Accept & book'), findsNothing);
    });

    testWidgets('declining asks first and waits for a new quote', (
      tester,
    ) async {
      final vendors = await pumpQuoted(tester);
      await scrollTo(tester, find.text('Decline'));
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Decline'));
      await tester.pumpAndSettle();
      expect(vendors.calls.where((c) => c.startsWith('reject:')), hasLength(1));
      expect(find.text('Quote received'), findsNothing);
      expect(find.text('Enquiry sent'), findsOneWidget); // status chip
    });

    testWidgets('an expired quote cannot be accepted', (tester) async {
      await pumpQuoted(tester, expired: true);
      expect(find.textContaining('Expired on'), findsOneWidget);
      expect(find.text('Accept & book'), findsNothing);
    });

    testWidgets('cancelling a booking needs a reason', (tester) async {
      final vendors = await pumpQuoted(tester);
      final ev = vendors.byEvent['e1']!.single;
      await vendors.acceptQuotation(
        'e1',
        ev.id,
        ev.quotations.first.id,
        idempotencyKey: 'k',
      );
      await Get.find<EventsRepository>().get('e1');
      (Get.find<EventsRepository>() as FakeEventsRepository).notifyChanged();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Cancel booking'));
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel booking').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Tell the vendor why (at least 3 characters).'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).last, 'Date moved');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel booking').last);
      await tester.pumpAndSettle();
      expect(vendors.calls, contains('cancelBooking:${ev.id}:Date moved'));
      expect(find.text('Booking cancelled'), findsOneWidget);
      expect(find.text('Reason: Date moved'), findsOneWidget);
    });

    testWidgets('a booking can be marked completed from its date', (
      tester,
    ) async {
      final vendors = await pumpQuoted(tester);
      final ev = vendors.byEvent['e1']!.single;
      await vendors.acceptQuotation(
        'e1',
        ev.id,
        ev.quotations.first.id,
        idempotencyKey: 'k',
      );
      vendors.serviceDateReached('e1', ev.id);
      (Get.find<EventsRepository>() as FakeEventsRepository).notifyChanged();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Mark completed'));
      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();
      expect(find.text('Booking completed'), findsOneWidget);
    });

    testWidgets('quote and booking fit at 200 % text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpQuoted(tester);
      expect(tester.takeException(), isNull);
      await scrollTo(tester, find.text('Accept & book'));
      expect(tester.takeException(), isNull);
    });
  });
}
