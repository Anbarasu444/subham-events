import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/features/reviews/domain/review.dart';

/// In-memory reviews (enough for widgets).
class FakeReviewsRepository implements ReviewsRepository {
  FakeReviewsRepository({this.onCreated});

  /// Lets the event-vendor fake show the review on its booking.
  void Function(String bookingId, Review review)? onCreated;
  final List<String> calls = [];
  final List<String> idempotencyKeys = [];
  final Map<String, List<PublicReview>> published = {};
  final Map<String, List<int>> ratings = {};
  Failure? failNext;
  int pageSize = 10;
  int _seq = 0;

  Result<T>? _failure<T>() {
    final f = failNext;
    failNext = null;
    return f == null ? null : Err(f);
  }

  @override
  Future<Result<Review>> create(
    String eventId,
    String bookingId,
    ReviewInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('create:$bookingId:${input.rating}:${input.comment}');
    idempotencyKeys.add(idempotencyKey);
    final f = _failure<Review>();
    if (f != null) return f;
    final review = Review(
      id: 'rv-${++_seq}',
      bookingId: bookingId,
      listingId: 'l1',
      listingTitle: 'Lens & Light',
      rating: input.rating,
      comment: input.comment,
      commentStatus: input.comment == null
          ? CommentStatus.none
          : CommentStatus.pendingModeration,
      createdAt: DateTime(2026, 11, 8),
    );
    onCreated?.call(bookingId, review);
    return Ok(review);
  }

  @override
  Future<Result<RatingSummary>> summary(String listingId) async {
    calls.add('summary:$listingId');
    final f = _failure<RatingSummary>();
    if (f != null) return f;
    final list = ratings[listingId] ?? const [];
    final sum = list.fold(0, (s, r) => s + r);
    return Ok(
      RatingSummary(
        average: list.isEmpty
            ? null
            : ((sum * 10 / list.length).round() / 10).toStringAsFixed(1),
        count: list.length,
        stars: [
          for (final s in [5, 4, 3, 2, 1])
            (stars: s, count: list.where((r) => r == s).length),
        ],
      ),
    );
  }

  @override
  Future<Result<PublicReviewPage>> listingReviews(
    String listingId, {
    String? cursor,
  }) async {
    calls.add('reviews:$listingId:${cursor ?? '-'}');
    final f = _failure<PublicReviewPage>();
    if (f != null) return f;
    final all = published[listingId] ?? const [];
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, all.length);
    return Ok(
      PublicReviewPage(
        items: all.sublist(start, end),
        nextCursor: end < all.length ? '$end' : null,
      ),
    );
  }
}

PublicReview testPublicReview(int n, {int rating = 5}) => PublicReview(
  id: 'pr-$n',
  rating: rating,
  comment: 'Comment number $n',
  reviewerName: 'Guest $n.',
  createdAt: DateTime(2026, 10, 1),
);
