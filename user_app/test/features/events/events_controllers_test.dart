import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/auth/session.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/state/view_state.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/events/presentation/controllers/event_detail_controller.dart';
import 'package:user_app/features/events/presentation/controllers/event_form_controller.dart';
import 'package:user_app/features/events/presentation/controllers/my_events_controller.dart';

import '../../helpers/fake_events_repository.dart';
import '../../helpers/test_session.dart';

final _today = DateTime(2026, 10, 7);
DateTime _clock() => DateTime(2026, 10, 7, 9);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('MyEventsController', () {
    test('loads upcoming events for signed-in users only', () async {
      final repo = FakeEventsRepository(
        events: [testEvent('a', date: DateTime(2026, 12, 1))],
      );
      final guest = MyEventsController(repo, testSession(const GuestSession()))
        ..onInit();
      await _settle();
      expect(repo.calls, isEmpty);
      guest.onClose();

      final c = MyEventsController(
        repo,
        testSession(const SignedInSession(testProfile)),
      )..onInit();
      await _settle();
      expect(c.lists[EventScope.upcoming]!.items.single.id, 'a');
      expect(c.lists[EventScope.past]!.loaded, isFalse);

      c.selectScope(EventScope.past);
      await _settle();
      expect(
        c.lists[EventScope.past]!.state.value,
        isA<Empty<List<PlannerEvent>>>(),
      );
      c.onClose();
    });

    test('paginates and shows load-more errors inline', () async {
      final repo = FakeEventsRepository(
        events: [
          for (var i = 0; i < 25; i++)
            testEvent(
              'e$i',
              date: DateTime(2026, 11, 1).add(Duration(days: i)),
            ),
        ],
      );
      final c = MyEventsController(
        repo,
        testSession(const SignedInSession(testProfile)),
      )..onInit();
      await _settle();
      final list = c.lists[EventScope.upcoming]!;
      expect(list.items, hasLength(20));
      expect(list.hasMore, isTrue);

      repo.failNext = const NetworkFailure();
      await c.loadMore(EventScope.upcoming);
      expect(list.moreError.value, isA<NetworkFailure>());
      expect(list.items, hasLength(20));

      await c.loadMore(EventScope.upcoming);
      expect(list.items, hasLength(25));
      expect(list.hasMore, isFalse);
      c.onClose();
    });

    test('reloads after a change and resets on sign-out', () async {
      final repo = FakeEventsRepository();
      final session = testSession(const SignedInSession(testProfile));
      final c = MyEventsController(repo, session)..onInit();
      await _settle();
      expect(
        c.lists[EventScope.upcoming]!.state.value,
        isA<Empty<List<PlannerEvent>>>(),
      );

      await repo.create(
        EventInput(
          eventType: 'Birthday',
          title: 'Party',
          eventDate: DateTime(2026, 11, 1),
          city: 'Chennai',
        ),
        idempotencyKey: 'k-12345678',
      );
      await _settle();
      await _settle();
      expect(c.lists[EventScope.upcoming]!.items.single.title, 'Party');

      session.state.value = const GuestSession();
      await _settle();
      expect(
        c.lists[EventScope.upcoming]!.state.value,
        isA<Loading<List<PlannerEvent>>>(),
      );
      expect(c.lists[EventScope.upcoming]!.loaded, isFalse);
      c.onClose();
    });

    test('a failed refresh keeps the events as stale content', () async {
      final repo = FakeEventsRepository(
        events: [testEvent('a', date: DateTime(2026, 12, 1))],
      );
      final c = MyEventsController(
        repo,
        testSession(const SignedInSession(testProfile)),
      )..onInit();
      await _settle();
      repo.failNext = const NetworkFailure();
      await c.load(EventScope.upcoming);
      final state = c.lists[EventScope.upcoming]!.state.value;
      expect(state, isA<Content<List<PlannerEvent>>>());
      expect((state as Content<List<PlannerEvent>>).isStale, isTrue);
      c.onClose();
    });

    test('a failed first load shows an error state', () async {
      final repo = FakeEventsRepository()..failNext = const ServerFailure();
      final c = MyEventsController(
        repo,
        testSession(const SignedInSession(testProfile)),
      )..onInit();
      await _settle();
      expect(
        c.lists[EventScope.upcoming]!.state.value,
        isA<Failed<List<PlannerEvent>>>(),
      );
      c.onClose();
    });
  });

  group('EventFormController', () {
    EventFormController form(
      FakeEventsRepository repo, {
      PlannerEvent? existing,
    }) => EventFormController(repo, existing: existing, clock: _clock);

    test('requires type, title, date and city', () async {
      final repo = FakeEventsRepository();
      final c = form(repo);
      expect(await c.submit(), isNull);
      expect(
        c.fieldErrors.keys,
        containsAll(['eventType', 'title', 'eventDate', 'city']),
      );
      expect(repo.calls, isEmpty);
    });

    test('rejects past dates for new events and bad numbers', () async {
      final c = form(FakeEventsRepository())
        ..eventType.text = 'Wedding'
        ..title.text = 'T'
        ..city.text = 'Chennai'
        ..guests.text = '200001'
        ..budget.text = '10.123';
      c.eventDate.value = DateTime(2026, 10, 6);
      expect(await c.submit(), isNull);
      expect(c.fieldErrors['eventDate'], 'Choose today or a later date.');
      expect(c.fieldErrors['guestCountEstimate'], isNotNull);
      expect(c.fieldErrors['totalBudget'], isNotNull);
    });

    test('creates with exact money and reuses the idempotency key', () async {
      final repo = FakeEventsRepository()..failNext = const NetworkFailure();
      final c = form(repo)
        ..eventType.text = ' Wedding '
        ..title.text = 'Asha & Ravi'
        ..city.text = 'Chennai'
        ..budget.text = '1,25,000.5';
      c.eventDate.value = _today;
      expect(await c.submit(), isNull);
      expect(c.formError.value, contains('offline'));
      final firstKey = repo.lastIdempotencyKey;

      final saved = await c.submit();
      expect(saved, isNotNull);
      expect(saved!.eventType, 'Wedding');
      expect(saved.totalBudget!.amount, '125000.50');
      expect(repo.lastIdempotencyKey, firstKey);
    });

    test('changed input after a failed create uses a new key', () async {
      final repo = FakeEventsRepository()..failNext = const TimeoutFailure();
      final c = form(repo)
        ..eventType.text = 'Wedding'
        ..title.text = 'T'
        ..city.text = 'Chennai';
      c.eventDate.value = _today;
      await c.submit();
      final firstKey = repo.lastIdempotencyKey;
      c.city.text = 'Madurai';
      await c.submit();
      expect(repo.lastIdempotencyKey, isNot(firstKey));
    });

    test('shows server field errors next to the fields', () async {
      final repo = FakeEventsRepository()
        ..failNext = const ValidationFailure(
          fieldErrors: [
            FieldError(
              field: 'eventDate',
              code: 'MUST_NOT_BE_PAST',
              message: 'x',
            ),
            FieldError(
              field: 'totalBudget.amount',
              code: 'MATCHES',
              message: 'x',
            ),
          ],
        );
      final c = form(repo)
        ..eventType.text = 'Wedding'
        ..title.text = 'T'
        ..city.text = 'Chennai';
      c.eventDate.value = _today;
      await c.submit();
      expect(c.fieldErrors['eventDate'], 'Choose today or a later date.');
      expect(c.fieldErrors['totalBudget'], isNotNull);
      expect(c.formError.value, isNull);
    });

    test(
      'edit allows past dates, tracks changes and reports conflicts',
      () async {
        final existing = testEvent('a', date: DateTime(2026, 12, 1));
        final repo = FakeEventsRepository(events: [existing]);
        final c = form(repo, existing: existing);
        expect(c.isDirty, isFalse);
        c.eventDate.value = DateTime(2026, 9, 1);
        expect(c.isDirty, isTrue);
        expect(c.firstDate, DateTime(2026, 9, 1));

        repo.failNext = const ConflictFailure(code: 'PRECONDITION_FAILED');
        expect(await c.submit(), isNull);
        expect(c.formError.value, contains('changed on another device'));

        final saved = await c.submit();
        expect(saved!.eventDate, DateTime(2026, 9, 1));
        expect(saved.version, 2);
      },
    );
  });

  group('EventDetailController', () {
    test('runs actions and refreshes on conflict', () async {
      final event = testEvent('a', date: DateTime(2026, 12, 1));
      final repo = FakeEventsRepository(events: [event]);
      final c = EventDetailController(repo, 'a', initial: event, clock: _clock)
        ..onInit();
      await _settle();

      expect(await c.run(EventCommand.cancel), isNull);
      expect(c.event!.status, EventStatus.cancelled);
      expect(c.event!.canReopen(c.today), isTrue);

      repo.failNext = const ConflictFailure(code: 'INVALID_STATE_TRANSITION');
      final failure = await c.run(EventCommand.complete);
      expect(failure, isA<ConflictFailure>());
      expect(repo.calls.last, 'get:a');

      expect(await c.run(EventCommand.delete), isNull);
      expect(repo.events, isEmpty);
    });

    test('a missing event shows not found', () async {
      final c = EventDetailController(
        FakeEventsRepository(),
        'zzz',
        clock: _clock,
      )..onInit();
      await _settle();
      expect(
        (c.state.value as Failed<PlannerEvent>).failure,
        isA<NotFoundFailure>(),
      );
    });
  });
}
