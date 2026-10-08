import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/auth/session_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/listing.dart';

/// One listing's details page (M13). The card it was opened from is shown
/// straight away; details and related lists load independently.
class ListingDetailController extends GetxController {
  ListingDetailController(
    this._discovery,
    this._session,
    this.listingId, {
    this.preview,
  });

  final DiscoveryRepository _discovery;
  final SessionService _session;
  final String listingId;

  /// The card tapped to open the page, shown while details load.
  final ListingCard? preview;

  final Rx<ViewState<ListingDetail>> detail = Rx<ViewState<ListingDetail>>(
    const Loading(),
  );
  final Rx<ViewState<RelatedListings>> related = Rx<ViewState<RelatedListings>>(
    const Loading(),
  );

  int _generation = 0;
  Worker? _sessionWorker;

  bool get signedIn => _session.isSignedIn;

  /// True when the listing is no longer listed (404).
  bool get isGone => switch (detail.value) {
    Failed(:final failure) => failure is NotFoundFailure,
    _ => false,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    // Contact details appear (or go) when the user signs in or out.
    _sessionWorker = ever(_session.state, (_) => unawaited(loadDetail()));
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    super.onClose();
  }

  Future<void> load() => Future.wait([loadDetail(), loadRelated()]);

  Future<void> loadDetail() async {
    final generation = ++_generation;
    final current = switch (detail.value) {
      Content(:final data) => data,
      _ => null,
    };
    if (current == null) detail.value = const Loading();
    final result = await _discovery.detail(listingId);
    if (isClosed || generation != _generation) return;
    detail.value = switch (result) {
      Ok(:final value) => Content(value),
      Err(:final failure) =>
        current != null && failure.isRetryable
            ? Content(current, isStale: true)
            : Failed(failure),
    };
  }

  Future<void> loadRelated() async {
    if (related.value is! Content) related.value = const Loading();
    final result = await _discovery.related(listingId);
    if (isClosed) return;
    related.value = switch (result) {
      Ok(:final value) => value.isEmpty ? const Empty() : Content(value),
      Err(:final failure) => Failed(failure),
    };
  }

  /// Plain-text summary for the share sheet (M13 answer 3; no app link yet).
  static String shareText(ListingCard card) => [
    card.title,
    '${card.vendorName} · ${card.category.name}',
    card.serviceAreas.isEmpty
        ? card.city
        : '${card.city} (also ${card.serviceAreas.join(', ')})',
    'Starting from ${card.startingPrice.format()}',
  ].join('\n');
}
