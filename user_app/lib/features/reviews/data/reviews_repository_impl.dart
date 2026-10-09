import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/review.dart';

/// Network-only.
class ReviewsRepositoryImpl implements ReviewsRepository {
  ReviewsRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<Review>> create(
    String eventId,
    String bookingId,
    ReviewInput input, {
    required String idempotencyKey,
  }) async => switch (await _api.post(
    '/events/$eventId/bookings/$bookingId/review',
    body: {'rating': input.rating, 'comment': ?input.comment},
    idempotencyKey: idempotencyKey,
    decode: reviewFromJson,
  )) {
    Ok(:final value) => Ok(value.data),
    Err(:final failure) => Err(failure),
  };

  @override
  Future<Result<RatingSummary>> summary(String listingId) async =>
      switch (await _api.get(
        '/listings/$listingId/rating',
        decode: summaryFromJson,
      )) {
        Ok(:final value) => Ok(value.data),
        Err(:final failure) => Err(failure),
      };

  @override
  Future<Result<MyReviewPage>> mine({String? cursor}) async {
    final result = await _api.get(
      '/me/reviews',
      query: {'limit': 20, 'cursor': ?cursor},
      decode: (json) =>
          (json as List<dynamic>).map(reviewFromJson).toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok(
        MyReviewPage(
          items: value.data,
          nextCursor: switch (value.page) {
            CursorPageMeta(:final nextCursor, :final hasMore) =>
              hasMore ? nextCursor : null,
            _ => null,
          },
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<PublicReviewPage>> listingReviews(
    String listingId, {
    String? cursor,
  }) async {
    final result = await _api.get(
      '/listings/$listingId/reviews',
      query: {'limit': 10, 'cursor': ?cursor},
      decode: (json) => (json as List<dynamic>)
          .map(publicReviewFromJson)
          .toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok(
        PublicReviewPage(
          items: value.data,
          nextCursor: switch (value.page) {
            CursorPageMeta(:final nextCursor, :final hasMore) =>
              hasMore ? nextCursor : null,
            _ => null,
          },
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  static Review reviewFromJson(Object? json) {
    final m = json as Map<String, dynamic>;
    final listing = m['listing'] as Map<String, dynamic>;
    return Review(
      id: m['id'] as String,
      bookingId: m['bookingId'] as String,
      listingId: listing['id'] as String,
      listingTitle: listing['title'] as String,
      rating: m['rating'] as int,
      comment: m['comment'] as String?,
      commentStatus: CommentStatus.fromApi(m['commentStatus'] as String),
      createdAt: DateTime.parse(m['createdAt'] as String).toLocal(),
    );
  }

  static PublicReview publicReviewFromJson(Object? json) {
    final m = json as Map<String, dynamic>;
    return PublicReview(
      id: m['id'] as String,
      rating: m['rating'] as int,
      comment: m['comment'] as String,
      reviewerName: m['reviewerName'] as String,
      createdAt: DateTime.parse(m['createdAt'] as String).toLocal(),
    );
  }

  static RatingSummary summaryFromJson(Object? json) {
    final m = json as Map<String, dynamic>;
    return RatingSummary(
      average: m['average'] as String?,
      count: m['count'] as int,
      stars: [
        for (final s in m['stars'] as List<dynamic>)
          (
            stars: (s as Map<String, dynamic>)['stars'] as int,
            count: s['count'] as int,
          ),
      ],
    );
  }
}
