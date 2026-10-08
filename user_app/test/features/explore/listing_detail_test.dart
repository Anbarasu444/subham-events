import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/app/routes/app_routes.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/platform/external_actions.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/explore/data/discovery_repository_impl.dart';
import 'package:user_app/features/explore/domain/listing.dart';
import 'package:user_app/features/explore/presentation/controllers/listing_detail_controller.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

List<ListingCard> _catalogue() => [
  sampleListing(1, title: 'Candid wedding photography', areas: ['Tambaram']),
  // Same vendor (Vendor 1 by name) — "More from this vendor".
  ListingCard(
    id: 'l9',
    title: 'Candid films',
    category: sampleCategories[0],
    vendorName: 'Vendor 1',
    city: 'Chennai',
    serviceAreas: const [],
    startingPrice: sampleListing(9).startingPrice,
    ratingAverage: null,
    ratingCount: 0,
    coverImageUrl: null,
  ),
  sampleListing(2, title: 'Other photographer'), // similar
  sampleListing(3, title: 'Coimbatore photographer', city: 'Coimbatore'),
];

void main() {
  tearDown(Get.reset);

  test('detailFromJson reads the vendor and optional contact', () {
    Map<String, dynamic> json({Map<String, dynamic>? contact}) => {
      'id': 'l1',
      'title': 'Candid',
      'category': {'id': 'c1', 'name': 'Photography', 'slug': 'photography'},
      'vendor': {
        'id': 'v1',
        'businessName': 'Candid Frames',
        'description': 'We shoot weddings',
        'city': 'Chennai',
        'serviceAreas': ['Vellore'],
        'contact': contact,
      },
      'city': 'Chennai',
      'serviceAreas': ['Vellore'],
      'startingPrice': {'amount': '25000.00', 'currency': 'INR'},
      'rating': {'average': null, 'count': 0},
      'coverImageUrl': null,
      'publishedAt': '2026-10-01T10:00:00.000Z',
      'description': 'Full day coverage',
      'photos': <Object>[],
    };
    final guest = DiscoveryRepositoryImpl.detailFromJson(json());
    expect(guest.vendor.contact, isNull);
    expect(guest.description, 'Full day coverage');
    final member = DiscoveryRepositoryImpl.detailFromJson(
      json(contact: {'phone': '+919800000001', 'email': null}),
    );
    expect(member.vendor.contact?.phone, '+919800000001');
    expect(member.vendor.contact?.email, isNull);
  });

  test('share text has the name, vendor, place and starting price', () {
    expect(
      ListingDetailController.shareText(_catalogue().first),
      'Candid wedding photography\n'
      'Vendor 1 · Photography\n'
      'Chennai (also Tambaram)\n'
      'Starting from ₹25,000',
    );
  });

  group('Listing details screen', () {
    Future<(FakeDiscoveryRepository, FakeExternalActions)> pump(
      WidgetTester tester, {
      bool signedIn = true,
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
      final events = Get.put<EventsRepository>(FakeEventsRepository());
      Get.put(MyEventsController(events, session));
      final external = Get.put<ExternalActions>(FakeExternalActions());
      final discovery = registerExplore(
        FakeDiscoveryRepository(listings: _catalogue())
          ..contact = signedIn
              ? const VendorContact(
                  phone: '+919800000001',
                  email: 'vendor@example.invalid',
                )
              : null,
      );
      Get.put(HomeController(session, const []));
      Get.put(ShellController(initialTab: ShellTab.explore));
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
      return (discovery, external as FakeExternalActions);
    }

    Future<void> open(WidgetTester tester, String title) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('signed-in users see contact actions that hand off', (
      tester,
    ) async {
      final (_, external) = await pump(tester);
      await open(tester, 'Candid wedding photography');
      expect(find.text('Starting from ₹25,000'), findsOneWidget);
      expect(find.text('Chennai · also serves Tambaram'), findsOneWidget);
      expect(find.text('About this service'), findsOneWidget);
      await scrollTo(tester, find.text('Call +919800000001'));
      await tester.tap(find.text('Call +919800000001'));
      await tester.pump();
      expect(external.calls, ['+919800000001']);
      await tester.tap(find.text('Email vendor@example.invalid'));
      await tester.pump();
      expect(external.emails, ['vendor@example.invalid']);
    });

    testWidgets('guests are asked to sign in for contact details', (
      tester,
    ) async {
      final (_, external) = await pump(tester, signedIn: false);
      await open(tester, 'Candid wedding photography');
      await scrollTo(tester, find.text('Sign in to see contact details.'));
      expect(find.textContaining('Call'), findsNothing);
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(find.text('Sign-in page'), findsOneWidget);
      expect(external.calls, isEmpty);
    });

    testWidgets('shows related listings and opens them', (tester) async {
      await pump(tester);
      await open(tester, 'Candid wedding photography');
      await scrollTo(tester, find.text('Similar vendors'));
      expect(find.text('More from this vendor'), findsOneWidget);
      expect(find.text('Candid films'), findsOneWidget);
      expect(find.text('Other photographer'), findsOneWidget);
      expect(find.text('Coimbatore photographer'), findsNothing);
      await tester.tap(find.text('Other photographer'));
      await tester.pumpAndSettle();
      expect(find.text('About Other photographer'), findsOneWidget);
    });

    testWidgets('shares the listing as text', (tester) async {
      final (_, external) = await pump(tester);
      await open(tester, 'Candid wedding photography');
      await tester.tap(find.byTooltip('Share'));
      await tester.pump();
      expect(external.shared.single, startsWith('Candid wedding photography'));
    });

    testWidgets('a listing withdrawn since the list loaded says so', (
      tester,
    ) async {
      final (discovery, _) = await pump(tester);
      discovery.failDetailNext = const NotFoundFailure();
      await open(tester, 'Candid wedding photography');
      expect(find.text('This vendor is no longer listed'), findsOneWidget);
      expect(find.text('Starting from ₹25,000'), findsNothing);
    });

    testWidgets('a failed load keeps the card and offers a retry', (
      tester,
    ) async {
      final (discovery, _) = await pump(tester);
      discovery.failDetailNext = const NetworkFailure();
      await open(tester, 'Candid wedding photography');
      expect(find.text('Starting from ₹25,000'), findsWidgets); // preview
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('About this service'), findsOneWidget);
    });

    testWidgets('fits at 200 % text on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester);
      await open(tester, 'Candid wedding photography');
      expect(tester.takeException(), isNull);
      await scrollTo(tester, find.text('Similar vendors'));
      expect(tester.takeException(), isNull);
    });
  });
}
