import 'dart:async';

import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/checklist/domain/entities/checklist_item.dart';
import 'package:user_app/features/checklist/domain/repositories/checklist_repository.dart';

/// In-memory checklists keyed by event id. [failNext] fails the next call;
/// [onChanged] mirrors the real repository's change notification.
class FakeChecklistRepository implements ChecklistRepository {
  FakeChecklistRepository({
    Map<String, List<ChecklistItem>>? items,
    this.readOnlyEvents = const {},
    this.onChanged,
  }) : items = {
         for (final e in (items ?? {}).entries) e.key: [...e.value],
       };

  final Map<String, List<ChecklistItem>> items;
  final Set<String> readOnlyEvents;
  final void Function()? onChanged;
  final List<String> calls = [];
  Failure? failNext;

  /// When set, the next complete/reopen waits for it (to interleave calls).
  Completer<void>? hold;
  String? lastIdempotencyKey;
  int _seq = 0;

  Result<T>? _failure<T>() {
    final failure = failNext;
    failNext = null;
    return failure == null ? null : Err(failure);
  }

  List<ChecklistItem> _of(String eventId) =>
      items.putIfAbsent(eventId, () => []);

  void _changed() => onChanged?.call();

  @override
  Future<Result<Checklist>> load(String eventId) async {
    calls.add('load:$eventId');
    return _failure<Checklist>() ??
        Ok(
          Checklist(
            eventId: eventId,
            isEditable: !readOnlyEvents.contains(eventId),
            items: [..._of(eventId)],
          ),
        );
  }

  @override
  Future<Result<ChecklistItem>> add(
    String eventId,
    ChecklistItemInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('add:$eventId');
    lastIdempotencyKey = idempotencyKey;
    final failure = _failure<ChecklistItem>();
    if (failure != null) return failure;
    final item = testItem(
      'new-${++_seq}',
      title: input.title,
      notes: input.notes,
      dueDate: input.dueDate,
      sortOrder: _of(eventId).length,
    );
    _of(eventId).add(item);
    _changed();
    return Ok(item);
  }

  @override
  Future<Result<ChecklistItem>> update(
    String eventId,
    ChecklistItem current,
    ChecklistItemInput input,
  ) async {
    calls.add('update:${current.id}');
    final failure = _failure<ChecklistItem>();
    if (failure != null) return failure;
    final updated = ChecklistItem(
      id: current.id,
      title: input.title,
      notes: input.notes,
      dueDate: input.dueDate,
      status: current.status,
      isOverdue: current.isOverdue,
      completedAt: current.completedAt,
      sortOrder: current.sortOrder,
      version: current.version + 1,
    );
    _replace(eventId, updated);
    return Ok(updated);
  }

  @override
  Future<Result<ChecklistItem>> complete(String eventId, String itemId) =>
      _set(eventId, itemId, 'complete', ChecklistStatus.done);

  @override
  Future<Result<ChecklistItem>> reopen(String eventId, String itemId) =>
      _set(eventId, itemId, 'reopen', ChecklistStatus.pending);

  @override
  Future<Result<Checklist>> reorder(
    String eventId,
    List<String> itemIds,
  ) async {
    calls.add('reorder:${itemIds.join(',')}');
    final failure = _failure<Checklist>();
    if (failure != null) return failure;
    final byId = {for (final i in _of(eventId)) i.id: i};
    items[eventId] = [
      for (final (index, id) in itemIds.indexed)
        byId[id]!.copyWith(sortOrder: index),
    ];
    _changed();
    return Ok(
      Checklist(eventId: eventId, isEditable: true, items: [..._of(eventId)]),
    );
  }

  @override
  Future<Result<void>> delete(String eventId, String itemId) async {
    calls.add('delete:$itemId');
    final failure = _failure<void>();
    if (failure != null) return failure;
    _of(eventId).removeWhere((i) => i.id == itemId);
    _changed();
    return const Ok(null);
  }

  Future<Result<ChecklistItem>> _set(
    String eventId,
    String itemId,
    String name,
    ChecklistStatus status,
  ) async {
    calls.add('$name:$itemId');
    final gate = hold;
    hold = null;
    final failure = _failure<ChecklistItem>();
    if (gate != null) await gate.future;
    if (failure != null) return failure;
    final current = _of(eventId).firstWhere((i) => i.id == itemId);
    final updated = status == ChecklistStatus.done
        ? current.copyWith(
            status: status,
            isOverdue: false,
            completedAt: DateTime.utc(2026, 10, 7, 10),
          )
        : current.copyWith(status: status, clearCompletedAt: true);
    _replace(eventId, updated);
    return Ok(updated);
  }

  void _replace(String eventId, ChecklistItem updated) {
    final list = _of(eventId);
    list[list.indexWhere((i) => i.id == updated.id)] = updated;
    _changed();
  }
}

ChecklistItem testItem(
  String id, {
  String title = 'Task',
  String? notes,
  DateTime? dueDate,
  bool done = false,
  bool overdue = false,
  int sortOrder = 0,
}) => ChecklistItem(
  id: id,
  title: title,
  notes: notes,
  dueDate: dueDate,
  status: done ? ChecklistStatus.done : ChecklistStatus.pending,
  isOverdue: overdue,
  completedAt: done ? DateTime.utc(2026, 10, 6, 10) : null,
  sortOrder: sortOrder,
  version: 1,
);
