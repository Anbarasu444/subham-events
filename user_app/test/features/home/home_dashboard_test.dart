import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/app/routes/app_routes.dart';
import 'package:user_app/core/auth/auth_service.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/state/view_state.dart';
import 'package:user_app/core/storage/secure_store.dart';
import 'package:user_app/features/auth/data/auth_api.dart';
import 'package:user_app/features/home/data/empty_section_source.dart';
import 'package:user_app/features/home/domain/dashboard_section.dart';
import 'package:user_app/features/home/presentation/controllers/home_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_controller.dart';
import 'package:user_app/features/shell/presentation/controllers/shell_tab.dart';
import 'package:user_app/features/shell/presentation/views/shell_view.dart';

import '../../helpers/recording_reporter.dart';

class _Auth extends Mock implements AuthService {}

class _Api extends Mock implements AuthApi {}

class _Store extends Mock implements SecureStore {}

/// Source that fails until [fail] is cleared.
class _FlakySource implements DashboardSectionSource {
  _FlakySource(this.id);
  @override
  final DashboardSectionId id;
  @override
  bool get requiresSignIn => false;
  bool fail = true;
  int loads = 0;
  @override
  Future<Result<SectionData>> load({required bool signedIn}) async {
    loads++;
    return fail ? const Err(ServerFailure(statusCode: 500)) : const Ok(null);
  }
}

/// Source whose loads finish only when the test completes them.
class _ManualSource implements DashboardSectionSource {
  _ManualSource(this.id, {this.requiresSignIn = false});
  @override
  final DashboardSectionId id;
  @override
  final bool requiresSignIn;
  final pending = <Completer<Result<SectionData>>>[];
  @override
  Future<Result<SectionData>> load({required bool signedIn}) {
    final c = Completer<Result<SectionData>>();
    pending.add(c);
    return c.future;
  }
}

class _ThrowingSource implements DashboardSectionSource {
  @override
  DashboardSectionId get id => DashboardSectionId.budget;
  @override
  bool get requiresSignIn => false;
  @override
  Future<Result<SectionData>> load({required bool signedIn}) =>
      Future.error(StateError('boom'));
}

SessionService _session(SessionState state) => SessionService(
  auth: _Auth(),
  api: _Api(),
  store: _Store(),
  reporter: RecordingReporter(),
  clearPrivateMedia: () async {},
)..state.value = state;

const _profile = MeProfile(
  id: 'u1',
  roles: ['USER'],
  displayName: 'Priya Sharma',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('HomeController', () {
    test('greets by time of day and first name', () {
      final morning = HomeController(
        _session(const SignedInSession(_profile)),
        defaultDashboardSources,
        clock: () => DateTime(2026, 10, 7, 9),
      );
      expect(morning.greeting, 'Good morning, Priya');

      final guestEvening = HomeController(
        _session(const GuestSession()),
        defaultDashboardSources,
        clock: () => DateTime(2026, 10, 7, 20),
      );
      expect(guestEvening.greeting, 'Good evening');
    });

    test(
      'sections load independently; one failure does not affect others',
      () async {
        final flaky = _FlakySource(DashboardSectionId.checklist);
        final controller = HomeController(_session(const GuestSession()), [
          const EmptySectionSource(DashboardSectionId.upcomingEvent),
          flaky,
          const EmptySectionSource(DashboardSectionId.explore),
        ]);
        await controller.refreshAll();
        expect(
          controller.sections[DashboardSectionId.upcomingEvent]!.value,
          isA<Empty<SectionData>>(),
        );
        expect(
          controller.sections[DashboardSectionId.checklist]!.value,
          isA<Failed<SectionData>>(),
        );
        expect(
          controller.sections[DashboardSectionId.explore]!.value,
          isA<Empty<SectionData>>(),
        );

        flaky.fail = false;
        await controller.loadSection(DashboardSectionId.checklist);
        expect(
          controller.sections[DashboardSectionId.checklist]!.value,
          isA<Empty<SectionData>>(),
        );
      },
    );

    test('reloads sections when the user signs in or out', () async {
      final flaky = _FlakySource(DashboardSectionId.budget)..fail = false;
      final session = _session(const GuestSession());
      final controller = HomeController(session, [flaky])..onInit();
      await Future<void>.delayed(Duration.zero);
      final before = flaky.loads;

      session.state.value = const SignedInSession(_profile);
      await Future<void>.delayed(Duration.zero);
      expect(flaky.loads, before + 1);

      // A profile update while signed in does not reload.
      session.state.value = const SignedInSession(_profile);
      await Future<void>.delayed(Duration.zero);
      expect(flaky.loads, before + 1);

      session.state.value = const GuestSession();
      await Future<void>.delayed(Duration.zero);
      expect(flaky.loads, before + 2);
      controller.onClose();
    });

    test(
      'sign-in-only sections are empty for guests without loading',
      () async {
        final source = _ManualSource(
          DashboardSectionId.upcomingEvent,
          requiresSignIn: true,
        );
        final controller = HomeController(_session(const GuestSession()), [
          source,
        ]);
        await controller.refreshAll();
        expect(source.pending, isEmpty);
        expect(
          controller.sections[DashboardSectionId.upcomingEvent]!.value,
          isA<Empty<SectionData>>(),
        );
      },
    );

    test(
      'an older load finishing last does not overwrite a newer one',
      () async {
        final source = _ManualSource(DashboardSectionId.explore);
        final controller = HomeController(_session(const GuestSession()), [
          source,
        ]);
        final first = controller.loadSection(DashboardSectionId.explore);
        final second = controller.loadSection(DashboardSectionId.explore);
        source.pending[1].complete(const Ok('new'));
        await second;
        source.pending[0].complete(const Err(ServerFailure(statusCode: 500)));
        await first;
        final state = controller.sections[DashboardSectionId.explore]!.value;
        expect(state, isA<Content<SectionData>>());
        expect((state as Content<SectionData>).data, 'new');
      },
    );

    test(
      'refresh keeps the shown state instead of flashing a skeleton',
      () async {
        final source = _ManualSource(DashboardSectionId.explore);
        final controller = HomeController(_session(const GuestSession()), [
          source,
        ]);
        final initial = controller.loadSection(DashboardSectionId.explore);
        source.pending.last.complete(const Ok('data'));
        await initial;

        final refresh = controller.loadSection(DashboardSectionId.explore);
        final during = controller.sections[DashboardSectionId.explore]!.value;
        expect(during, isA<Content<SectionData>>());
        expect((during as Content<SectionData>).isStale, isTrue);
        source.pending.last.complete(const Ok(null));
        await refresh;
        expect(
          controller.sections[DashboardSectionId.explore]!.value,
          isA<Empty<SectionData>>(),
        );
      },
    );

    test('a crashing section is reported and shown as failed', () async {
      final reporter = RecordingReporter();
      final controller = HomeController(_session(const GuestSession()), [
        _ThrowingSource(),
      ], reporter: reporter);
      await controller.refreshAll();
      expect(
        controller.sections[DashboardSectionId.budget]!.value,
        isA<Failed<SectionData>>(),
      );
      expect(reporter.errors, hasLength(1));
    });
  });

  group('Home dashboard screen', () {
    Future<void> pump(
      WidgetTester tester,
      SessionState state, {
      List<DashboardSectionSource>? sources,
      List<GetPage<dynamic>>? pages,
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
      final session = Get.put<SessionService>(_session(state));
      Get.put(HomeController(session, sources ?? defaultDashboardSources));
      Get.put(ShellController());
      await tester.pumpWidget(
        GetMaterialApp(home: const ShellView(), getPages: pages),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows greeting, call to action and the four sections', (
      tester,
    ) async {
      await pump(tester, const SignedInSession(_profile));
      expect(find.textContaining('Priya'), findsOneWidget);
      expect(find.text('Create your first event'), findsOneWidget);
      for (final title in [
        'Upcoming event',
        'Checklist progress',
        'Budget overview',
        'Explore vendors',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 100);
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('guest empty state asks to sign in for upcoming events', (
      tester,
    ) async {
      await pump(tester, const GuestSession());
      expect(find.text('Sign in to see your upcoming events.'), findsOneWidget);
    });

    testWidgets('section titles are headings; signed-in empty copy', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const SignedInSession(_profile));
      expect(
        tester.getSemantics(find.text('Upcoming event')),
        isSemantics(isHeader: true),
      );
      expect(find.text('You have no events yet.'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('signed-in call to action opens My Events', (tester) async {
      await pump(tester, const SignedInSession(_profile));
      await tester.tap(find.text('Create your first event'));
      await tester.pumpAndSettle();
      expect(Get.find<ShellController>().current.value, ShellTab.events);
      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('guest call to action opens sign-in returning to My Events', (
      tester,
    ) async {
      await pump(
        tester,
        const GuestSession(),
        pages: [
          GetPage<void>(
            name: AppRoutes.signIn,
            page: () => const Scaffold(body: Text('sign-in page')),
          ),
        ],
      );
      await tester.tap(find.text('Create your first event'));
      await tester.pumpAndSettle();
      expect(find.text('sign-in page'), findsOneWidget);
      expect(Get.parameters['returnTo'], AppRoutes.tab(ShellTab.events));
    });

    testWidgets('pull-to-refresh reloads the sections', (tester) async {
      final source = _FlakySource(DashboardSectionId.explore)..fail = false;
      await pump(tester, const GuestSession(), sources: [source]);
      final before = source.loads;
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(source.loads, greaterThan(before));
    });

    testWidgets(
      'Explore action in the section card switches to the Explore tab',
      (tester) async {
        await pump(tester, const GuestSession());
        // Scroll to the end of the dashboard with a real drag gesture.
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        final cardButton = find.descendant(
          of: find.byType(ListView),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        );
        await tester.tap(cardButton);
        await tester.pumpAndSettle();
        expect(Get.find<ShellController>().current.value, ShellTab.explore);
      },
    );

    testWidgets('a failing section shows retry while others render', (
      tester,
    ) async {
      final flaky = _FlakySource(DashboardSectionId.budget);
      await pump(
        tester,
        const GuestSession(),
        sources: [
          const EmptySectionSource(DashboardSectionId.upcomingEvent),
          flaky,
        ],
      );
      expect(find.text('Sign in to see your upcoming events.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      flaky.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('no overflow at 200 % text on a small screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, const SignedInSession(_profile));
      expect(tester.takeException(), isNull);
      // Lay out every card, not only the first screen.
      await tester.scrollUntilVisible(
        find.text('Explore'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
