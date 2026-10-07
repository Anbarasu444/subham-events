import '../../../../core/error/result.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/repositories/checklist_repository.dart';
import '../datasources/checklist_remote_data_source.dart';
import '../models/checklist_model.dart';

/// Network-only (server-owned data, no offline cache in M9). Every successful
/// change calls [onChanged] so event progress elsewhere is refreshed.
class ChecklistRepositoryImpl implements ChecklistRepository {
  ChecklistRepositoryImpl(this._remote, this._onChanged);

  final ChecklistRemoteDataSource _remote;
  final void Function() _onChanged;

  @override
  Future<Result<Checklist>> load(String eventId) async =>
      _data(await _remote.load(eventId), notify: false);

  @override
  Future<Result<ChecklistItem>> add(
    String eventId,
    ChecklistItemInput input, {
    required String idempotencyKey,
  }) async => _data(
    await _remote.add(
      eventId,
      ChecklistModel.createJson(input),
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<Result<ChecklistItem>> update(
    String eventId,
    ChecklistItem current,
    ChecklistItemInput input,
  ) async {
    final body = ChecklistModel.updateJson(current, input);
    if (body.length == 1) return Ok(current); // only `version`: unchanged
    return _data(await _remote.update(eventId, current.id, body));
  }

  @override
  Future<Result<ChecklistItem>> complete(String eventId, String itemId) async =>
      _data(await _remote.action(eventId, itemId, 'complete'));

  @override
  Future<Result<ChecklistItem>> reopen(String eventId, String itemId) async =>
      _data(await _remote.action(eventId, itemId, 'reopen'));

  @override
  Future<Result<Checklist>> reorder(
    String eventId,
    List<String> itemIds,
  ) async => _data(await _remote.reorder(eventId, itemIds));

  @override
  Future<Result<void>> delete(String eventId, String itemId) async {
    final result = await _remote.delete(eventId, itemId);
    return switch (result) {
      Ok() => _notified(const Ok(null)),
      Err(:final failure) => Err(failure),
    };
  }

  Result<T> _data<T>(Result<ApiResponse<T>> result, {bool notify = true}) =>
      switch (result) {
        Ok(:final value) => notify ? _notified(Ok(value.data)) : Ok(value.data),
        Err(:final failure) => Err(failure),
      };

  Result<T> _notified<T>(Result<T> result) {
    _onChanged();
    return result;
  }
}
