import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/platform/external_actions.dart';
import 'package:user_app/core/utils/date_format.dart';
import 'package:user_app/features/budget/domain/budget.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/invitations/data/invitations_repository_impl.dart';
import 'package:user_app/features/invitations/domain/invitation.dart';
import 'package:user_app/features/invitations/presentation/controllers/invitation_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/fake_budget_repository.dart';
import '../../helpers/fake_checklist_repository.dart';
import '../../helpers/fake_discovery_repository.dart';
import '../../helpers/fake_event_vendors.dart';
import '../../helpers/fake_events_repository.dart';
import '../../helpers/fake_invitations.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/test_session.dart';
import '../../helpers/viewport.dart';

final DateTime _today = dateOnly(DateTime.now());

const _replies = RsvpList(
  totals: RsvpTotals(attending: 2, maybe: 1, notAttending: 1, guests: 5),
  rsvps: [],
);

void main() {
  tearDown(Get.reset);

  group('JSON', () {
    test('templates parse hex colours', () {
      final t = InvitationsRepositoryImpl.templateFromJson({
        'code': 'festive',
        'name': 'Festive',
        'background': '#7A1F2B',
        'surface': '#FFF4E0',
        'text': '#3B1418',
        'accent': '#E0A526',
        'headingFont': 'script',
        'ornament': 'diya',
      });
      expect(t.background, const Color(0xFF7A1F2B));
      expect(t.ornament, 'diya');
    });

    test('an invitation parses status, dates and totals', () {
      final inv = InvitationsRepositoryImpl.fromJson({
        'id': 'i1',
        'eventId': 'e1',
        'templateCode': 'classic',
        'title': 'Asha & Ravi',
        'message': null,
        'hostNames': 'The Kumars',
        'eventDate': '2026-12-12',
        'startTime': '18:30',
        'venueName': 'Lotus Hall',
        'venueAddress': null,
        'status': 'PUBLISHED',
        'rsvpOpen': true,
        'rsvpClosesOn': '2026-12-13',
        'totals': {'attending': 2, 'maybe': 1, 'notAttending': 0, 'guests': 6},
      });
      expect(inv.status, InvitationStatus.published);
      expect(inv.eventDate, DateTime(2026, 12, 12));
      expect(inv.totals.replies, 3);
      expect(inv.totals.guests, 6);
      expect(RsvpResponse.fromApi('NOT_ATTENDING'), RsvpResponse.notAttending);
    });
  });

  group('controller', () {
    test('publishing keeps the link; revoking forgets it', () async {
      final repo = FakeInvitationsRepository()..seed('e1');
      final c = InvitationController(repo, 'e1');
      await c.load();
      expect(c.current!.link, isNull);
      expect(await c.publish(), isNull);
      expect(c.current!.link, startsWith('http://localhost:3000/api/v1/i/'));
      expect(await c.revoke(), isNull);
      expect(c.current!.invitation!.status, InvitationStatus.revoked);
      expect(c.current!.link, isNull);
    });

    test('a conflict is returned and the invitation reloaded', () async {
      final repo = FakeInvitationsRepository()..seed('e1');
      final c = InvitationController(repo, 'e1');
      await c.load();
      repo.failNext = const ConflictFailure(message: 'Not planning');
      expect(await c.publish(), isA<ConflictFailure>());
      await pumpEventQueue();
      expect(repo.calls.where((x) => x.startsWith('get:')), hasLength(2));
    });

    test('a failed first load shows the failure', () async {
      final repo = FakeInvitationsRepository()
        ..failNext = const NetworkFailure();
      final c = InvitationController(repo, 'e1');
      await c.load();
      expect(c.current, isNull);
    });
  });

  group('screens', () {
    Future<(FakeInvitationsRepository, FakeExternalActions)> pump(
      WidgetTester tester, {
      EventStatus status = EventStatus.planning,
      void Function(FakeInvitationsRepository repo)? seed,
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
      Get.put<ChecklistRepository>(FakeChecklistRepository());
      Get.put<BudgetRepository>(FakeBudgetRepository());
      final invitations =
          Get.put<InvitationsRepository>(FakeInvitationsRepository())
              as FakeInvitationsRepository;
      seed?.call(invitations);
      final external =
          Get.put<ExternalActions>(FakeExternalActions())
              as FakeExternalActions;
      Get.put(MyEventsController(repo, session));
      registerExplore(FakeDiscoveryRepository());
      registerEngagement(onChanged: repo.notifyChanged);
      Get.put(HomeController(session, const []));
      Get.put(ShellController(initialTab: ShellTab.events));
      await tester.pumpWidget(const GetMaterialApp(home: ShellView()));
      await tester.pumpAndSettle();
      if (find.text('Asha & Ravi').evaluate().isEmpty) {
        await tester.tap(find.text('Past'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Asha & Ravi').first);
      await tester.pumpAndSettle();
      return (invitations, external);
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

    testWidgets('creates, publishes and shares the invitation link', (
      tester,
    ) async {
      final (invitations, external) = await pump(tester);
      await scrollTo(tester, find.byKey(const ValueKey('create-invitation')));
      await tester.tap(find.byKey(const ValueKey('create-invitation')));
      await tester.pumpAndSettle();
      expect(find.text('New invitation'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Festive'));
      await tester.enterText(
        find.widgetWithText(TextField, 'From (optional)'),
        'The Kumar family',
      );
      await tester.pumpAndSettle();
      // The live preview follows the form.
      expect(find.text('The Kumar family'), findsWidgets);
      await tester.dragUntilVisible(
        find.text('Save invitation'),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save invitation'));
      await tester.pumpAndSettle();
      expect(invitations.calls, contains('save:festive:Asha & Ravi'));

      await scrollTo(tester, find.text('Publish'));
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(invitations.calls, contains('publish'));
      await scrollTo(tester, find.text('Share link'));
      await tester.tap(find.text('Share link'));
      await tester.pumpAndSettle();
      expect(external.shared.single, contains('/api/v1/i/token-'));
    });

    testWidgets('shares the invitation as a picture with the link', (
      tester,
    ) async {
      final (_, external) = await pump(
        tester,
        seed: (r) => r.seed(
          'e1',
          status: InvitationStatus.published,
          link: 'http://x/api/v1/i/abc',
        ),
      );
      await scrollTo(tester, find.text('Share picture'));
      await tester.tap(find.text('Share picture'));
      await tester.pumpAndSettle();
      expect(find.text('Share as picture'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Share picture'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final (name, text, size) = external.images.single;
      expect(name, 'invitation.png');
      expect(text, contains('http://x/api/v1/i/abc'));
      expect(size, greaterThan(0));
    });

    testWidgets('shows reply totals and opens the replies list', (
      tester,
    ) async {
      final (invitations, _) = await pump(
        tester,
        seed: (r) => r.seed(
          'e1',
          status: InvitationStatus.published,
          link: 'http://x/i/abc',
          rsvps: RsvpList(
            totals: _replies.totals,
            rsvps: [
              Rsvp(
                id: 'r1',
                guestName: 'Meena',
                response: RsvpResponse.attending,
                guestCount: 3,
                message: 'See you!',
                updatedAt: DateTime(2026, 10, 1),
              ),
            ],
          ),
        ),
      );
      await scrollTo(tester, find.text('2 coming'));
      expect(find.text('5 people expected'), findsOneWidget);
      await tester.tap(find.text('2 coming'));
      await tester.pumpAndSettle();
      expect(find.text('Replies'), findsOneWidget);
      expect(find.text('Meena'), findsOneWidget);
      expect(find.textContaining('Coming · 3 people'), findsOneWidget);
      expect(find.textContaining('See you!'), findsOneWidget);
      expect(invitations.calls, contains('rsvps'));
    });

    testWidgets('closes replies and turns the link off after asking', (
      tester,
    ) async {
      final (invitations, _) = await pump(
        tester,
        seed: (r) => r.seed(
          'e1',
          status: InvitationStatus.published,
          link: 'http://x/i/abc',
        ),
      );
      await scrollTo(tester, find.byTooltip('More invitation actions'));
      await tester.tap(find.byTooltip('More invitation actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close replies'));
      await tester.pumpAndSettle();
      expect(invitations.calls, contains('rsvpOpen:false'));
      expect(find.text('Replies are closed.'), findsOneWidget);

      await tester.tap(find.byTooltip('More invitation actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(invitations.calls, isNot(contains('revoke')));

      await tester.tap(find.byTooltip('More invitation actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off link'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Turn off'));
      await tester.pumpAndSettle();
      expect(invitations.calls, contains('revoke'));
      expect(find.text('Link turned off'), findsOneWidget);
      expect(find.text('Publish with a new link'), findsOneWidget);
    });

    testWidgets('a phone without the link offers a new one', (tester) async {
      final (invitations, _) = await pump(
        tester,
        seed: (r) => r.seed('e1', status: InvitationStatus.published),
      );
      await scrollTo(tester, find.textContaining('doesn’t have the link'));
      expect(find.text('Share link'), findsNothing);
      await tester.tap(find.byTooltip('More invitation actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a new link'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Create new link'));
      await tester.pumpAndSettle();
      expect(invitations.calls, contains('newLink'));
      expect(find.text('Share link'), findsOneWidget);
    });

    testWidgets('a cancelled event cannot create an invitation', (
      tester,
    ) async {
      await pump(tester, status: EventStatus.cancelled);
      await scrollTo(
        tester,
        find.text('No invitation was made for this event.'),
      );
      expect(find.byKey(const ValueKey('create-invitation')), findsNothing);
    });

    testWidgets('the editor fits at 200 % text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester);
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('create-invitation')),
        find.byType(NestedScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('create-invitation')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Save invitation'),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
