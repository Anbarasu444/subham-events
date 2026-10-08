import 'dart:async';

import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/events/domain/entities/planner_event.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';

/// In-memory events for widget/controller tests. Set [failNext] to make the
/// next call fail; [today] decides upcoming vs past.
class FakeEventsRepository implements EventsRepository {
  FakeEventsRepository({List<PlannerEvent>? events, DateTime? today})
    : events = [...?events],
      today = today ?? DateTime(2026, 10, 7);

  final List<PlannerEvent> events;
  final DateTime today;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Failure? failNext;
  final List<String> calls = [];
  int _seq = 0;
  String? lastIdempotencyKey;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void notifyChanged() => _changes.add(null);

  Result<T>? _failure<T>() {
    final failure = failNext;
    failNext = null;
    return failure == null ? null : Err(failure);
  }

  bool _isUpcoming(PlannerEvent e) =>
      e.status == EventStatus.planning && !e.eventDate.isBefore(today);

  @override
  Future<Result<EventsPage>> list({
    required EventScope scope,
    String? cursor,
    int limit = 20,
    EventStatus? status,
  }) async {
    calls.add('list:${scope.name}:${cursor ?? ''}');
    final failure = _failure<EventsPage>();
    if (failure != null) return failure;
    final filtered =
        events
            .where(
              (e) => switch (scope) {
                EventScope.upcoming => _isUpcoming(e),
                EventScope.past => !_isUpcoming(e),
                EventScope.all => true,
              },
            )
            .toList()
          ..sort(
            (a, b) => scope == EventScope.past
                ? b.eventDate.compareTo(a.eventDate)
                : a.eventDate.compareTo(b.eventDate),
          );
    final start = cursor == null ? 0 : int.parse(cursor);
    final page = filtered.skip(start).take(limit).toList();
    final next = start + limit < filtered.length ? '${start + limit}' : null;
    return Ok(EventsPage(items: page, nextCursor: next));
  }

  @override
  Future<Result<PlannerEvent>> get(String id) async {
    calls.add('get:$id');
    final failure = _failure<PlannerEvent>();
    if (failure != null) return failure;
    final found = events.where((e) => e.id == id).firstOrNull;
    return found == null ? const Err(NotFoundFailure()) : Ok(found);
  }

  @override
  Future<Result<PlannerEvent>> create(
    EventInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('create');
    lastIdempotencyKey = idempotencyKey;
    final failure = _failure<PlannerEvent>();
    if (failure != null) return failure;
    final event = fromInput('new-${++_seq}', input);
    events.add(event);
    _changes.add(null);
    return Ok(event);
  }

  @override
  Future<Result<PlannerEvent>> update(
    PlannerEvent current,
    EventInput input,
  ) async {
    calls.add('update:${current.id}');
    final failure = _failure<PlannerEvent>();
    if (failure != null) return failure;
    final updated = fromInput(
      current.id,
      input,
      status: current.status,
      version: current.version + 1,
    );
    _replace(updated);
    return Ok(updated);
  }

  @override
  Future<Result<PlannerEvent>> cancel(String id) =>
      _status(id, 'cancel', EventStatus.cancelled);
  @override
  Future<Result<PlannerEvent>> reopen(String id) =>
      _status(id, 'reopen', EventStatus.planning);
  @override
  Future<Result<PlannerEvent>> complete(String id) =>
      _status(id, 'complete', EventStatus.completed);

  @override
  Future<Result<void>> delete(String id) async {
    calls.add('delete:$id');
    final failure = _failure<void>();
    if (failure != null) return failure;
    events.removeWhere((e) => e.id == id);
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<PlannerEvent>> setCover(String id, String mediaId) async {
    calls.add('setCover:$id:$mediaId');
    final failure = _failure<PlannerEvent>();
    if (failure != null) return failure;
    final current = events.firstWhere((e) => e.id == id);
    final updated = withCover(
      current,
      EventCover(
        mediaId: mediaId,
        url: 'https://ik.test/$mediaId',
        thumbnailUrl: 'https://ik.test/$mediaId?thumb',
        expiresAt: DateTime.utc(2030),
      ),
    );
    _replace(updated);
    return Ok(updated);
  }

  @override
  Future<Result<PlannerEvent>> removeCover(String id) async {
    calls.add('removeCover:$id');
    final failure = _failure<PlannerEvent>();
    if (failure != null) return failure;
    final updated = withCover(events.firstWhere((e) => e.id == id), null);
    _replace(updated);
    return Ok(updated);
  }

  static PlannerEvent withCover(PlannerEvent e, EventCover? cover) =>
      PlannerEvent(
        id: e.id,
        eventType: e.eventType,
        title: e.title,
        eventDate: e.eventDate,
        startTime: e.startTime,
        timeZone: e.timeZone,
        city: e.city,
        venueName: e.venueName,
        venueAddress: e.venueAddress,
        guestCountEstimate: e.guestCountEstimate,
        totalBudget: e.totalBudget,
        status: e.status,
        version: e.version + 1,
        checklist: e.checklist,
        cover: cover,
      );

  Future<Result<PlannerEvent>> _status(
    String id,
    String name,
    EventStatus status,
  ) async {
    calls.add('$name:$id');
    final failure = _failure<PlannerEvent>();
    if (failure != null) return failure;
    final current = events.firstWhere((e) => e.id == id);
    final updated = copyWith(current, status: status);
    _replace(updated);
    return Ok(updated);
  }

  void _replace(PlannerEvent updated) {
    final index = events.indexWhere((e) => e.id == updated.id);
    events[index] = updated;
    _changes.add(null);
  }

  static PlannerEvent fromInput(
    String id,
    EventInput input, {
    EventStatus status = EventStatus.planning,
    int version = 1,
    ChecklistSummary checklist = ChecklistSummary.empty,
  }) => PlannerEvent(
    id: id,
    eventType: input.eventType,
    title: input.title,
    eventDate: input.eventDate,
    startTime: input.startTime,
    timeZone: 'Asia/Kolkata',
    city: input.city,
    venueName: input.venueName,
    venueAddress: input.venueAddress,
    guestCountEstimate: input.guestCountEstimate,
    totalBudget: input.totalBudget,
    status: status,
    version: version,
    checklist: checklist,
  );

  static PlannerEvent copyWith(
    PlannerEvent e, {
    EventStatus? status,
    DateTime? eventDate,
  }) => PlannerEvent(
    id: e.id,
    eventType: e.eventType,
    title: e.title,
    eventDate: eventDate ?? e.eventDate,
    startTime: e.startTime,
    timeZone: e.timeZone,
    city: e.city,
    venueName: e.venueName,
    venueAddress: e.venueAddress,
    guestCountEstimate: e.guestCountEstimate,
    totalBudget: e.totalBudget,
    status: status ?? e.status,
    version: e.version + 1,
    checklist: e.checklist,
    cover: e.cover,
  );
}

/// A planning event on [date] for tests.
PlannerEvent testEvent(
  String id, {
  required DateTime date,
  String title = 'Asha & Ravi Wedding',
  EventStatus status = EventStatus.planning,
  ChecklistSummary checklist = ChecklistSummary.empty,
}) => FakeEventsRepository.fromInput(
  id,
  EventInput(
    eventType: 'Wedding',
    title: title,
    eventDate: date,
    city: 'Chennai',
  ),
  status: status,
  checklist: checklist,
);
