import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/wishlist.dart';
import 'wishlist_controller.dart';

/// Menu → Saved vendors (M14): the user's saved listings, newest first.
class SavedVendorsController extends GetxController {
  SavedVendorsController(
    this._repository,
    this._wishlist, {
    this.pageSize = 20,
  });

  final WishlistRepository _repository;
  final WishlistController _wishlist;
  final int pageSize;

  final Rx<ViewState<List<WishlistItem>>> state =
      Rx<ViewState<List<WishlistItem>>>(const Loading());
  final RxBool loadingMore = false.obs;
  final Rx<Failure?> loadMoreFailure = Rx<Failure?>(null);
  String? _cursor;
  int _generation = 0;
  Worker? _changes;

  bool get hasMore => _cursor != null;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    // Unsaving here (or elsewhere) refreshes the list.
    _changes = ever<int>(_wishlist.changes, (_) => unawaited(load()));
  }

  @override
  void onClose() {
    _changes?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final current = switch (state.value) {
      Content(:final data) => data,
      _ => null,
    };
    if (current == null) state.value = const Loading();
    final result = await _repository.list(limit: pageSize);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _cursor = value.nextCursor;
        state.value = value.items.isEmpty
            ? const Empty()
            : Content(value.items);
      case Err(:final failure):
        state.value = current != null && failure.isRetryable
            ? Content(current, isStale: true)
            : Failed(failure);
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    final current = state.value;
    if (cursor == null || loadingMore.value || current is! Content) return;
    final items = (current as Content<List<WishlistItem>>).data;
    final generation = _generation;
    loadingMore.value = true;
    loadMoreFailure.value = null;
    final result = await _repository.list(cursor: cursor, limit: pageSize);
    loadingMore.value = false;
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _cursor = value.nextCursor;
        state.value = Content([...items, ...value.items]);
      case Err(:final failure):
        loadMoreFailure.value = failure;
    }
  }
}
