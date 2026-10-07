import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/repositories/checklist_repository.dart';

/// One event's checklist. Ticking, reordering and deleting update the
/// screen at once and roll back if the server rejects the change.
class ChecklistController extends GetxController {
  ChecklistController(
    this._repository,
    this.eventId, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ChecklistRepository _repository;
  final String eventId;
  final DateTime Function() _clock;

  final Rx<ViewState<Checklist>> state = Rx<ViewState<Checklist>>(
    const Loading(),
  );

  /// Items with a request in flight (prevents double taps).
  final RxSet<String> busy = <String>{}.obs;

  /// A reorder request is in flight.
  bool _reordering = false;

  int _generation = 0;

  Checklist? get checklist => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_generation;
    if (checklist == null) state.value = const Loading();
    final result = await _repository.load(eventId);
    if (isClosed || generation != _generation) return;
    state.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) =>
        checklist != null && failure is! NotFoundFailure
            ? Content(checklist!, isStale: true)
            : Failed(failure),
    };
  }

  /// Ticks or unticks [item]; returns the failure to show, or null.
  Future<Failure?> toggle(ChecklistItem item) async {
    final current = checklist;
    if (current == null || busy.contains(item.id) || _reordering) return null;
    final toDone = !item.isDone;
    final optimistic = toDone
        ? item.copyWith(
            status: ChecklistStatus.done,
            isOverdue: false,
            completedAt: _clock().toUtc(),
          )
        : item.copyWith(
            status: ChecklistStatus.pending,
            clearCompletedAt: true,
            isOverdue:
                item.dueDate != null &&
                item.dueDate!.isBefore(dateOnly(_clock())),
          );
    return _mutate(
      item.id,
      apply: (items) => _replace(items, optimistic),
      request: () => toDone
          ? _repository.complete(eventId, item.id)
          : _repository.reopen(eventId, item.id),
      onSaved: (items, saved) => _replace(items, saved as ChecklistItem),
      // Only this task is restored; other changes made meanwhile stay.
      rollback: (items) => _replace(items, item),
    );
  }

  /// Moves a pending item from [oldIndex] to its final position [newIndex]
  /// (indexes in the pending list).
  Future<Failure?> movePending(int oldIndex, int newIndex) async {
    final current = checklist;
    // A reorder never overlaps other changes (and vice versa), so restoring
    // the previous order can't undo another change.
    if (current == null || busy.isNotEmpty || _reordering) return null;
    final pending = [...current.pending];
    if (oldIndex < 0 || oldIndex >= pending.length) return null;
    if (newIndex == oldIndex || newIndex < 0 || newIndex >= pending.length) {
      return null;
    }
    pending.insert(newIndex, pending.removeAt(oldIndex));
    final doneInOrder = current.items.where((i) => i.isDone);
    final ordered = [
      for (final (index, item) in [...pending, ...doneInOrder].indexed)
        item.copyWith(sortOrder: index),
    ];
    _reordering = true;
    try {
      return await _mutate(
        null,
        apply: (_) => ordered,
        request: () =>
            _repository.reorder(eventId, [for (final i in ordered) i.id]),
        onSaved: (_, saved) => (saved as Checklist).items,
        rollback: (_) => current.items,
      );
    } finally {
      _reordering = false;
    }
  }

  Future<Failure?> delete(ChecklistItem item) async {
    final current = checklist;
    if (current == null || busy.contains(item.id) || _reordering) return null;
    final position = current.items.indexWhere((i) => i.id == item.id);
    return _mutate(
      item.id,
      apply: (items) => [
        for (final i in items)
          if (i.id != item.id) i,
      ],
      request: () => _repository.delete(eventId, item.id),
      onSaved: (items, _) => items,
      // Put just this task back where it was.
      rollback: (items) => items.any((i) => i.id == item.id)
          ? items
          : ([...items]..insert(position.clamp(0, items.length), item)),
    );
  }

  /// Shows an item saved by the add/edit sheet.
  void applySaved(ChecklistItem saved) {
    final current = checklist;
    if (current == null) return;
    final exists = current.items.any((i) => i.id == saved.id);
    state.value = Content(
      current.withItems(
        exists ? _replace(current.items, saved) : [...current.items, saved],
      ),
    );
  }

  /// Applies a change on screen, sends it, then keeps the server result or
  /// undoes it with [rollback] (applied to the *current* items).
  Future<Failure?> _mutate(
    String? itemId, {
    required List<ChecklistItem> Function(List<ChecklistItem> items) apply,
    required Future<Result<Object?>> Function() request,
    required List<ChecklistItem> Function(
      List<ChecklistItem> items,
      Object? saved,
    )
    onSaved,
    required List<ChecklistItem> Function(List<ChecklistItem> items) rollback,
  }) async {
    final before = checklist;
    if (before == null) return null;
    _generation++; // a load in flight must not overwrite this change
    if (itemId != null) busy.add(itemId);
    state.value = Content(before.withItems(apply(before.items)));
    final result = await request();
    if (itemId != null) busy.remove(itemId);
    if (isClosed) return null;
    final now = checklist!;
    switch (result) {
      case Ok(:final value):
        state.value = Content(now.withItems(onSaved(now.items, value)));
        return null;
      case Err(:final failure):
        state.value = Content(now.withItems(rollback(now.items)));
        // Changed elsewhere, read only now, or the item set differs
        // (reorder 422): show the server's current checklist.
        if (failure is ConflictFailure ||
            failure is NotFoundFailure ||
            failure is ValidationFailure) {
          unawaited(load());
        }
        return failure;
    }
  }

  static List<ChecklistItem> _replace(
    List<ChecklistItem> items,
    ChecklistItem updated,
  ) => [for (final i in items) i.id == updated.id ? updated : i];
}
