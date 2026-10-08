import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../data/push_messaging.dart';
import '../../domain/app_notification.dart';
import 'push_service.dart';

/// The Notification Center list (M18): newest first, paged, read state.
class NotificationCenterController extends GetxController {
  NotificationCenterController(
    this._repository,
    this._push, {
    this.pageSize = 20,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final NotificationsRepository _repository;
  final PushService? _push;
  final int pageSize;
  final DateTime Function() _clock;

  final Rx<ViewState<List<AppNotification>>> state =
      Rx<ViewState<List<AppNotification>>>(const Loading());
  final RxBool loadingMore = false.obs;
  final Rx<Failure?> loadMoreFailure = Rx<Failure?>(null);
  String? _cursor;
  int _generation = 0;

  bool get hasMore => _cursor != null;

  List<AppNotification> get _items => switch (state.value) {
    Content(:final data) => data,
    _ => const [],
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_generation;
    final current = _items;
    if (current.isEmpty) state.value = const Loading();
    final result = await _repository.list(limit: pageSize);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _cursor = value.nextCursor;
        state.value = value.items.isEmpty
            ? const Empty()
            : Content(value.items);
      case Err(:final failure):
        state.value = current.isNotEmpty && failure.isRetryable
            ? Content(current, isStale: true)
            : Failed(failure);
    }
    unawaited(_push?.refreshUnread());
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || loadingMore.value || state.value is! Content) return;
    final items = _items;
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

  /// Opens a notification: marked read at once (optimistic), then routed.
  Future<void> open(AppNotification n) async {
    _replace(n.markedRead(_clock()));
    final push = _push;
    if (push != null) {
      await push.open(
        PushTap(notificationId: n.id, type: n.type, eventId: n.eventId),
      );
    } else {
      await _repository.markRead(n.id);
    }
  }

  Future<Failure?> markAllRead() async {
    final now = _clock();
    final before = _items;
    state.value = Content([for (final n in before) n.markedRead(now)]);
    final result = await _repository.markAllRead();
    unawaited(_push?.refreshUnread());
    if (result case Err(:final failure)) {
      state.value = Content(before);
      return failure;
    }
    return null;
  }

  void _replace(AppNotification updated) {
    state.value = Content([
      for (final n in _items) n.id == updated.id ? updated : n,
    ]);
  }
}
