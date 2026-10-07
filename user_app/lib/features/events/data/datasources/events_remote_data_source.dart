import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/planner_event.dart';
import '../models/event_model.dart';

class EventsRemoteDataSource {
  const EventsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<ApiResponse<List<PlannerEvent>>>> list({
    required String scope,
    String? cursor,
    required int limit,
    String? status,
  }) => _api.get(
    '/events',
    query: {
      'scope': scope,
      'limit': limit,
      'cursor': ?cursor,
      'status': ?status,
    },
    decode: EventModel.listFromJson,
  );

  Future<Result<ApiResponse<PlannerEvent>>> get(String id) =>
      _api.get('/events/$id', decode: EventModel.fromJson);

  Future<Result<ApiResponse<PlannerEvent>>> create(
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _api.post(
    '/events',
    body: body,
    idempotencyKey: idempotencyKey,
    decode: EventModel.fromJson,
  );

  Future<Result<ApiResponse<PlannerEvent>>> update(
    String id,
    Map<String, dynamic> body,
  ) => _api.patch('/events/$id', body: body, decode: EventModel.fromJson);

  Future<Result<ApiResponse<PlannerEvent>>> action(String id, String action) =>
      _api.post('/events/$id/$action', decode: EventModel.fromJson);

  Future<Result<ApiResponse<void>>> delete(String id) =>
      _api.delete('/events/$id', decode: (_) {});
}
