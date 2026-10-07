import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/network/api_client.dart';
import 'package:user_app/features/events/data/datasources/events_remote_data_source.dart';
import 'package:user_app/features/events/data/repositories/events_repository_impl.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';

import '../../helpers/fake_adapter.dart';

Map<String, Object?> _event(String id, {int version = 1}) => {
  'id': id,
  'eventType': 'Wedding',
  'title': 'T',
  'eventDate': '2026-12-14',
  'startTime': null,
  'timeZone': 'Asia/Kolkata',
  'city': 'Chennai',
  'venueName': null,
  'venueAddress': null,
  'guestCountEstimate': null,
  'totalBudget': null,
  'status': 'PLANNING',
  'version': version,
  'createdAt': '2026-10-07T10:00:00.000Z',
  'updatedAt': '2026-10-07T10:00:00.000Z',
};

EventsRepositoryImpl _repo(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
    ..httpClientAdapter = adapter;
  return EventsRepositoryImpl(EventsRemoteDataSource(ApiClient(dio)));
}

void main() {
  test('lists a page and exposes the next cursor', () async {
    final adapter = FakeAdapter([
      FakeAdapter.json(200, {
        'data': [_event('e1')],
        'meta': {
          'page': {
            'type': 'cursor',
            'limit': 1,
            'nextCursor': 'abc',
            'hasMore': true,
          },
        },
      }),
    ]);
    final result = await _repo(
      adapter,
    ).list(scope: EventScope.upcoming, limit: 1);
    final page = (result as Ok<EventsPage>).value;
    expect(page.items.single.id, 'e1');
    expect(page.nextCursor, 'abc');
    expect(adapter.requests.single.uri.query, 'scope=upcoming&limit=1');
  });

  test('create sends the idempotency key and announces the change', () async {
    final adapter = FakeAdapter([
      FakeAdapter.json(201, {'data': _event('e1'), 'meta': {}}),
    ]);
    final repo = _repo(adapter);
    final changes = <void>[];
    final sub = repo.changes.listen(changes.add);
    final result = await repo.create(
      EventInput(
        eventType: 'Wedding',
        title: 'T',
        eventDate: DateTime(2026, 12, 14),
        city: 'Chennai',
      ),
      idempotencyKey: 'key-12345678',
    );
    expect(result, isA<Ok<PlannerEvent>>());
    expect(adapter.requests.single.headers['Idempotency-Key'], 'key-12345678');
    await Future<void>.delayed(Duration.zero);
    expect(changes, hasLength(1));
    await sub.cancel();
  });

  test('update without changes makes no request', () async {
    final adapter = FakeAdapter([]);
    final repo = _repo(adapter);
    final current =
        (await _repoWith(_event('e1')).get('e1') as Ok).value as PlannerEvent;
    final result = await repo.update(
      current,
      EventInput(
        eventType: current.eventType,
        title: current.title,
        eventDate: current.eventDate,
        city: current.city,
      ),
    );
    expect(result, isA<Ok<PlannerEvent>>());
    expect(adapter.requests, isEmpty);
  });

  test('stale version maps to a conflict', () async {
    final adapter = FakeAdapter([
      FakeAdapter.json(412, {
        'error': {
          'code': 'PRECONDITION_FAILED',
          'message': 'changed',
          'details': [],
          'requestId': 'r',
        },
      }),
    ]);
    final current =
        (await _repoWith(_event('e1')).get('e1') as Ok).value as PlannerEvent;
    final result = await _repo(adapter).update(
      current,
      EventInput(
        eventType: 'Party',
        title: current.title,
        eventDate: current.eventDate,
        city: current.city,
      ),
    );
    expect((result as Err).failure, isA<ConflictFailure>());
    expect(adapter.requests.single.method, 'PATCH');
  });

  test('delete handles 204', () async {
    final adapter = FakeAdapter([ResponseBody.fromString('', 204)]);
    final result = await _repo(adapter).delete('e1');
    expect(result, isA<Ok<void>>());
    expect(adapter.requests.single.method, 'DELETE');
  });
}

EventsRepositoryImpl _repoWith(Map<String, Object?> event) => _repo(
  FakeAdapter([
    FakeAdapter.json(200, {'data': event, 'meta': {}}),
  ]),
);
