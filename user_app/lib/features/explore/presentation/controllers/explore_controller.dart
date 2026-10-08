import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/auth/session_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../domain/listing.dart';

/// Explore tab (M12): categories, filters and paged results. Kept for the
/// whole session so Home can open it with a category or city preset.
class ExploreController extends GetxController {
  ExploreController(
    this._discovery,
    this._events,
    this._session, {
    this.searchDelay = const Duration(milliseconds: 400),
    this.pageSize = 20,
  });

  final DiscoveryRepository _discovery;
  final EventsRepository _events;
  final SessionService _session;
  final Duration searchDelay;
  final int pageSize;

  final Rx<ViewState<List<VendorCategory>>> categories =
      Rx<ViewState<List<VendorCategory>>>(const Loading());
  final Rx<ListingQuery> query = const ListingQuery().obs;
  final Rx<ViewState<List<ListingCard>>> results =
      Rx<ViewState<List<ListingCard>>>(const Loading());
  final RxBool loadingMore = false.obs;
  final Rx<Failure?> loadMoreFailure = Rx<Failure?>(null);

  String? _cursor;
  int _generation = 0;
  Timer? _debounce;
  bool _started = false;

  bool get hasMore => _cursor != null;

  /// Starts on first use: the next planning event's city is the default
  /// filter (M12 answer 3); the user can change or clear it.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    unawaited(loadCategories());
    if (query.value.city == null && _session.isSignedIn) {
      final upcoming = await _events.list(scope: EventScope.upcoming, limit: 1);
      if (upcoming case Ok(:final value) when value.items.isNotEmpty) {
        final city = value.items.first.city.trim();
        if (city.isNotEmpty && query.value.city == null) {
          query.value = query.value.copyWith(city: () => city);
        }
      }
    }
    await search();
  }

  Future<void> loadCategories() async {
    if (categories.value is! Content) categories.value = const Loading();
    final result = await _discovery.categories();
    if (isClosed) return;
    categories.value = switch (result) {
      Ok(:final value) => value.isEmpty ? const Empty() : Content(value),
      Err(:final failure) => Failed(failure),
    };
  }

  /// Loads the first page for the current query (newest request wins).
  Future<void> search() async {
    _debounce?.cancel();
    final generation = ++_generation;
    final current = switch (results.value) {
      Content(:final data) => data,
      _ => null,
    };
    if (current == null) results.value = const Loading();
    loadMoreFailure.value = null;
    final result = await _discovery.search(query.value, limit: pageSize);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _cursor = value.nextCursor;
        results.value = value.items.isEmpty
            ? const Empty()
            : Content(value.items);
      case Err(:final failure):
        results.value = current != null && failure.isRetryable
            ? Content(current, isStale: true)
            : Failed(failure);
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    final current = results.value;
    if (cursor == null || loadingMore.value || current is! Content) return;
    final items = (current as Content<List<ListingCard>>).data;
    loadingMore.value = true;
    loadMoreFailure.value = null;
    final generation = _generation;
    final result = await _discovery.search(
      query.value,
      cursor: cursor,
      limit: pageSize,
    );
    loadingMore.value = false;
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _cursor = value.nextCursor;
        results.value = Content([...items, ...value.items]);
      case Err(:final failure):
        loadMoreFailure.value = failure;
    }
  }

  /// Search text: waits for typing to pause before searching.
  void setText(String text) {
    final trimmed = text.trim();
    final next = trimmed.isEmpty ? null : trimmed;
    if (next == query.value.text) return;
    query.value = query.value.copyWith(text: () => next);
    _debounce?.cancel();
    _debounce = Timer(searchDelay, search);
  }

  /// "Saved" chip; guests are asked to sign in (returns false).
  bool setSaved(bool saved) {
    if (saved && !_session.isSignedIn) return false;
    _apply(query.value.copyWith(saved: saved));
    return true;
  }

  void setCategory(String? categoryId) =>
      _apply(query.value.copyWith(categoryId: () => categoryId));

  /// Filters from the filter sheet (city, prices, sort).
  void applyFilters(ListingQuery filters) => _apply(filters);

  void clearFilters() => _apply(const ListingQuery());

  /// From Home: open Explore with a category and/or city.
  void openWith({String? categoryId, String? city}) {
    final next = ListingQuery(categoryId: categoryId, city: city);
    if (!_started) {
      query.value = next;
      unawaited(start());
      return;
    }
    _apply(next);
  }

  void _apply(ListingQuery next) {
    if (next == query.value && results.value is! Failed) return;
    query.value = next;
    unawaited(search());
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
