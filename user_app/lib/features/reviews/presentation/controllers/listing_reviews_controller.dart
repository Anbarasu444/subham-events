import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/review.dart';

class ListingReviews {
  const ListingReviews({
    required this.summary,
    required this.reviews,
    required this.nextCursor,
  });

  final RatingSummary summary;
  final List<PublicReview> reviews;
  final String? nextCursor;
}

/// A listing's rating summary and approved comments (M20).
class ListingReviewsController extends GetxController {
  ListingReviewsController(this._repository, this.listingId);

  final ReviewsRepository _repository;
  final String listingId;

  final Rx<ViewState<ListingReviews>> state = Rx<ViewState<ListingReviews>>(
    const Loading(),
  );
  final RxBool loadingMore = false.obs;
  final Rx<Failure?> moreError = Rx<Failure?>(null);

  ListingReviews? get current => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    if (current == null) state.value = const Loading();
    final summary = await _repository.summary(listingId);
    final page = await _repository.listingReviews(listingId);
    if (isClosed) return;
    switch ((summary, page)) {
      case (Ok(value: final s), Ok(value: final p)):
        state.value = Content(
          ListingReviews(
            summary: s,
            reviews: p.items,
            nextCursor: p.nextCursor,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        state.value = current != null && failure.isRetryable
            ? Content(current!, isStale: true)
            : Failed(failure);
    }
  }

  Future<void> loadMore() async {
    final now = current;
    if (now == null || now.nextCursor == null || loadingMore.value) return;
    loadingMore.value = true;
    moreError.value = null;
    final result = await _repository.listingReviews(
      listingId,
      cursor: now.nextCursor,
    );
    if (isClosed) return;
    loadingMore.value = false;
    switch (result) {
      case Ok(:final value):
        state.value = Content(
          ListingReviews(
            summary: now.summary,
            reviews: [...now.reviews, ...value.items],
            nextCursor: value.nextCursor,
          ),
        );
      case Err(:final failure):
        moreError.value = failure;
    }
  }
}
