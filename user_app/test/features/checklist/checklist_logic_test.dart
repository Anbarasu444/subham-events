import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/state/view_state.dart';
import 'package:user_app/features/checklist/data/models/checklist_model.dart';
import 'package:user_app/features/checklist/domain/entities/checklist_item.dart';
import 'package:user_app/features/checklist/presentation/controllers/checklist_controller.dart';
import 'package:user_app/features/checklist/presentation/controllers/checklist_item_form_controller.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/home/data/checklist_progress_source.dart';
import 'package:user_app/features/home/domain/dashboard_section.dart';

import '../../helpers/fake_checklist_repository.dart';
import '../../helpers/fake_events_repository.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);
DateTime _clock() => DateTime(2026, 10, 7, 9);

void main() {
  group('ChecklistModel', () {
    test('decodes a checklist', () {
      final checklist = ChecklistModel.fromJson({
        'eventId': 'e1',
        'isEditable': false,
        'summary': {'total': 1, 'done': 0, 'overdue': 1},
        'items': [
          {
            'id': 'i1',
            'title': 'Book photographer',
            'notes': null,
            'dueDate': '2026-10-01',
            'status': 'PENDING',
            'isOverdue': true,
            'completedAt': null,
            'sortOrder': 0,
            'version': 2,
            'createdAt': '2026-10-01T00:00:00.000Z',
            'updatedAt': '2026-10-01T00:00:00.000Z',
          },
        ],
      });
      expect(checklist.isEditable, isFalse);
      final item = checklist.items.single;
      expect(item.dueDate, DateTime(2026, 10, 1));
      expect(item.isOverdue, isTrue);
      expect(
        checklist.summary,
        const ChecklistSummary(total: 1, done: 0, overdue: 1),
      );
    });

    test('builds create and update bodies', () {
      expect(
        ChecklistModel.createJson(
          ChecklistItemInput(title: 'Cake', dueDate: DateTime(2026, 12, 1)),
        ),
        {'title': 'Cake', 'dueDate': '2026-12-01'},
      );
      final current = testItem('i1', title: 'Cake', notes: 'Chocolate');
      expect(
        ChecklistModel.updateJson(
          current,
          const ChecklistItemInput(title: 'Cake', notes: null),
        ),
        {'notes': null, 'version': 1},
      );
    });
  });

  group('ChecklistController', () {
    ChecklistController controller(FakeChecklistRepository repo) =>
        ChecklistController(repo, 'e1', clock: _clock)..onInit();

    test('ticks optimistically and keeps the server result', () async {
      final repo = FakeChecklistRepository(
        items: {
          'e1': [testItem('a', overdue: true)],
        },
      );
      final c = controller(repo);
      await _settle();
      final future = c.toggle(c.checklist!.items.single);
      expect(c.checklist!.items.single.isDone, isTrue); // immediately
      expect(c.checklist!.summary.overdue, 0);
      expect(await future, isNull);
      expect(repo.items['e1']!.single.isDone, isTrue);
    });

    test('rolls back a rejected tick and reloads on conflict', () async {
      final repo = FakeChecklistRepository(
        items: {
          'e1': [testItem('a')],
        },
      );
      final c = controller(repo);
      await _settle();
      repo.failNext = const ConflictFailure(code: 'INVALID_STATE_TRANSITION');
      final failure = await c.toggle(c.checklist!.items.single);
      expect(failure, isA<ConflictFailure>());
      expect(c.checklist!.items.single.isDone, isFalse);
      await _settle();
      expect(repo.calls.where((x) => x.startsWith('load')), hasLength(2));
    });

    test('a failed tick rolls back only its own task', () async {
      final repo = FakeChecklistRepository(
        items: {
          'e1': [testItem('a'), testItem('b', sortOrder: 1)],
        },
      );
      final c = controller(repo);
      await _settle();
      // A is slow and will fail; B succeeds meanwhile.
      final gate = Completer<void>();
      repo
        ..failNext = const NetworkFailure()
        ..hold = gate;
      final tickA = c.toggle(c.checklist!.items.first);
      final tickB = c.toggle(c.checklist!.items.last);
      expect(await tickB, isNull);
      gate.complete();
      expect(await tickA, isA<NetworkFailure>());
      final items = {for (final i in c.checklist!.items) i.id: i.isDone};
      expect(items, {'a': false, 'b': true});
    });

    test('no reorder while another change is in flight', () async {
      final repo = FakeChecklistRepository(
        items: {
          'e1': [testItem('a'), testItem('b', sortOrder: 1)],
        },
      );
      final c = controller(repo);
      await _settle();
      final gate = Completer<void>();
      repo.hold = gate;
      final tick = c.toggle(c.checklist!.items.first);
      expect(await c.movePending(0, 1), isNull);
      expect(repo.calls.where((x) => x.startsWith('reorder')), isEmpty);
      gate.complete();
      await tick;
    });

    test('reorders pending items and sends every id', () async {
      final repo = FakeChecklistRepository(
        items: {
          'e1': [
            testItem('a', sortOrder: 0),
            testItem('b', sortOrder: 1),
            testItem('c', sortOrder: 2),
            testItem('d', sortOrder: 3, done: true),
          ],
        },
      );
      final c = controller(repo);
      await _settle();
      expect(await c.movePending(0, 2), isNull);
      expect(c.checklist!.pending.map((i) => i.id), ['b', 'c', 'a']);
      expect(repo.calls.last, 'reorder:b,c,a,d');
      expect(await c.movePending(0, 0), isNull); // no-op
      expect(repo.calls.last, 'reorder:b,c,a,d');
    });

    test('deletes with rollback on failure', () async {
      final repo = FakeChecklistRepository(
        items: {
          'e1': [testItem('a')],
        },
      );
      final c = controller(repo);
      await _settle();
      repo.failNext = const NetworkFailure();
      expect(await c.delete(c.checklist!.items.single), isA<NetworkFailure>());
      expect(c.checklist!.items, hasLength(1));
      expect(await c.delete(c.checklist!.items.single), isNull);
      expect(c.checklist!.items, isEmpty);
    });

    test('a failed first load shows an error', () async {
      final repo = FakeChecklistRepository()..failNext = const ServerFailure();
      final c = controller(repo);
      await _settle();
      expect(c.state.value, isA<Failed<Checklist>>());
    });
  });

  group('ChecklistItemFormController', () {
    test('validates title and notes', () async {
      final c = ChecklistItemFormController(FakeChecklistRepository(), 'e1');
      expect(await c.submit(), isNull);
      expect(c.titleError.value, isNotNull);
      c.title.text = 'x' * 121;
      c.notes.text = 'n' * 1001;
      expect(await c.submit(), isNull);
      expect(c.titleError.value, 'Use at most 120 characters.');
      expect(c.notesError.value, isNotNull);
    });

    test(
      'explains the item limit and reuses the key for the same input',
      () async {
        final repo = FakeChecklistRepository()
          ..failNext = const ConflictFailure(code: 'LIMIT_REACHED');
        final c = ChecklistItemFormController(repo, 'e1')..title.text = 'Cake';
        expect(await c.submit(), isNull);
        expect(c.formError.value, contains('200 items'));
        final key = repo.lastIdempotencyKey;
        final saved = await c.submit();
        expect(saved!.title, 'Cake');
        expect(repo.lastIdempotencyKey, key);
      },
    );

    test('read-only event is explained', () async {
      final repo = FakeChecklistRepository()
        ..failNext = const ConflictFailure(code: 'INVALID_STATE_TRANSITION');
      final c = ChecklistItemFormController(repo, 'e1')..title.text = 'Cake';
      await c.submit();
      expect(c.formError.value, contains('read only'));
    });
  });

  group('ChecklistProgressSource', () {
    test(
      'no upcoming event → empty; no tasks → no checklist request',
      () async {
        final events = FakeEventsRepository(today: DateTime(2026, 10, 7));
        final checklists = FakeChecklistRepository();
        final source = ChecklistProgressSource(events, checklists);
        final empty = await source.load(signedIn: true);
        expect((empty as Ok<SectionData>).value, isNull);
        expect(checklists.calls, isEmpty);

        events.events.add(testEvent('e1', date: DateTime(2026, 11, 1)));
        await source.load(signedIn: true);
        expect(checklists.calls, isEmpty); // checklist summary is empty
      },
    );

    test('lists overdue first, then by due date, then order', () {
      final list = Checklist(
        eventId: 'e1',
        isEditable: true,
        items: [
          testItem('later', dueDate: DateTime(2026, 12, 1), sortOrder: 0),
          testItem('none', sortOrder: 1),
          testItem(
            'overdue',
            dueDate: DateTime(2026, 10, 1),
            overdue: true,
            sortOrder: 2,
          ),
          testItem('soon', dueDate: DateTime(2026, 10, 20), sortOrder: 3),
          testItem('done', done: true, sortOrder: 4),
        ],
      );
      expect(ChecklistProgressSource.urgentFirst(list).map((i) => i.id), [
        'overdue',
        'soon',
        'later',
      ]);
    });
  });
}
