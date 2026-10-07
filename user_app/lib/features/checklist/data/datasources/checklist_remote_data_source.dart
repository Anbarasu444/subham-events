import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/checklist_item.dart';
import '../models/checklist_model.dart';

class ChecklistRemoteDataSource {
  const ChecklistRemoteDataSource(this._api);

  final ApiClient _api;

  String _path(String eventId) => '/events/$eventId/checklist';

  Future<Result<ApiResponse<Checklist>>> load(String eventId) =>
      _api.get(_path(eventId), decode: ChecklistModel.fromJson);

  Future<Result<ApiResponse<ChecklistItem>>> add(
    String eventId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _api.post(
    _path(eventId),
    body: body,
    idempotencyKey: idempotencyKey,
    decode: ChecklistModel.itemFromJson,
  );

  Future<Result<ApiResponse<ChecklistItem>>> update(
    String eventId,
    String itemId,
    Map<String, dynamic> body,
  ) => _api.patch(
    '${_path(eventId)}/$itemId',
    body: body,
    decode: ChecklistModel.itemFromJson,
  );

  Future<Result<ApiResponse<ChecklistItem>>> action(
    String eventId,
    String itemId,
    String action,
  ) => _api.post(
    '${_path(eventId)}/$itemId/$action',
    decode: ChecklistModel.itemFromJson,
  );

  Future<Result<ApiResponse<Checklist>>> reorder(
    String eventId,
    List<String> itemIds,
  ) => _api.put(
    '${_path(eventId)}/order',
    body: {'itemIds': itemIds},
    decode: ChecklistModel.fromJson,
  );

  Future<Result<ApiResponse<void>>> delete(String eventId, String itemId) =>
      _api.delete('${_path(eventId)}/$itemId', decode: (_) {});
}
