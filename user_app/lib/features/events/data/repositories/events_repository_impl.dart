import 'dart:async';

import '../../../../core/error/result.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';
import '../datasources/events_remote_data_source.dart';
import '../models/event_model.dart';

/// Network-only for now: events are server-owned and always fetched fresh
/// (no offline cache in M8).
class EventsRepositoryImpl implements EventsRepository {
  EventsRepositoryImpl(this._remote);

  final EventsRemoteDataSource _remote;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<EventsPage>> list({
    required EventScope scope,
    String? cursor,
    int limit = 20,
  }) async {
    final result = await _remote.list(
      scope: scope.name,
      cursor: cursor,
      limit: limit,
    );
    return switch (result) {
      Ok(:final value) => Ok(
        EventsPage(
          items: value.data,
          nextCursor: switch (value.page) {
            CursorPageMeta(:final nextCursor, :final hasMore) =>
              hasMore ? nextCursor : null,
            _ => null,
          },
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<PlannerEvent>> get(String id) async =>
      _data(await _remote.get(id), notify: false);

  @override
  Future<Result<PlannerEvent>> create(
    EventInput input, {
    required String idempotencyKey,
  }) async => _data(
    await _remote.create(
      EventModel.createJson(input),
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<Result<PlannerEvent>> update(
    PlannerEvent current,
    EventInput input,
  ) async {
    final body = EventModel.updateJson(current, input);
    if (body.length == 1) return Ok(current); // only `version`: nothing changed
    return _data(await _remote.update(current.id, body));
  }

  @override
  Future<Result<PlannerEvent>> cancel(String id) async =>
      _data(await _remote.action(id, 'cancel'));

  @override
  Future<Result<PlannerEvent>> reopen(String id) async =>
      _data(await _remote.action(id, 'reopen'));

  @override
  Future<Result<PlannerEvent>> complete(String id) async =>
      _data(await _remote.action(id, 'complete'));

  @override
  Future<Result<void>> delete(String id) async {
    final result = await _remote.delete(id);
    return switch (result) {
      Ok() => _notified(const Ok(null)),
      Err(:final failure) => Err(failure),
    };
  }

  Result<PlannerEvent> _data(
    Result<ApiResponse<PlannerEvent>> result, {
    bool notify = true,
  }) => switch (result) {
    Ok(:final value) => notify ? _notified(Ok(value.data)) : Ok(value.data),
    Err(:final failure) => Err(failure),
  };

  Result<T> _notified<T>(Result<T> result) {
    _changes.add(null);
    return result;
  }
}
