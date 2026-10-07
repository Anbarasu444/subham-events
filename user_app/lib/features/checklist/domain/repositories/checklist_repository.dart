import '../../../../core/error/result.dart';
import '../entities/checklist_item.dart';

/// An event's checklist (api-contracts.md Part B, M9).
abstract class ChecklistRepository {
  Future<Result<Checklist>> load(String eventId);

  /// [idempotencyKey] is created once per add intent and reused on retries.
  Future<Result<ChecklistItem>> add(
    String eventId,
    ChecklistItemInput input, {
    required String idempotencyKey,
  });

  Future<Result<ChecklistItem>> update(
    String eventId,
    ChecklistItem current,
    ChecklistItemInput input,
  );

  Future<Result<ChecklistItem>> complete(String eventId, String itemId);
  Future<Result<ChecklistItem>> reopen(String eventId, String itemId);

  /// [itemIds] = every item of the checklist in the new order.
  Future<Result<Checklist>> reorder(String eventId, List<String> itemIds);

  Future<Result<void>> delete(String eventId, String itemId);
}
