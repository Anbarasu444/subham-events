import '../../../core/error/result.dart';

/// Where a review's comment is in moderation (R7; screens for admins M51).
enum CommentStatus {
  none,
  pendingModeration,
  approved,
  rejected,
  hidden;

  static CommentStatus fromApi(String value) => switch (value) {
    'PENDING_MODERATION' => pendingModeration,
    'APPROVED' => approved,
    'REJECTED' => rejected,
    'HIDDEN' => hidden,
    _ => none,
  };

  /// What the author is told about their comment.
  String? get authorNote => switch (this) {
    CommentStatus.none => null,
    CommentStatus.pendingModeration => 'Your comment is waiting for approval.',
    CommentStatus.approved => 'Your comment is public.',
    CommentStatus.rejected || CommentStatus.hidden =>
      'Your comment isn’t shown. Your rating still counts.',
  };
}

class ReviewInput {
  const ReviewInput({required this.rating, this.comment});

  final int rating;
  final String? comment;

  @override
  bool operator ==(Object other) =>
      other is ReviewInput &&
      other.rating == rating &&
      other.comment == comment;

  @override
  int get hashCode => Object.hash(rating, comment);
}

/// The author's own review.
class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.listingId,
    required this.listingTitle,
    required this.rating,
    required this.comment,
    required this.commentStatus,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String listingId;
  final String listingTitle;
  final int rating;
  final String? comment;
  final CommentStatus commentStatus;
  final DateTime createdAt;
}

/// A public review: an approved comment with the reviewer as "Asha K.".
class PublicReview {
  const PublicReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String reviewerName;
  final DateTime createdAt;
}

class PublicReviewPage {
  const PublicReviewPage({required this.items, required this.nextCursor});

  final List<PublicReview> items;
  final String? nextCursor;
}

class MyReviewPage {
  const MyReviewPage({required this.items, required this.nextCursor});

  final List<Review> items;
  final String? nextCursor;
}

class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.stars,
  });

  /// "4.5", or null without ratings.
  final String? average;
  final int count;

  /// Count per star value, 5 first.
  final List<({int stars, int count})> stars;
}

/// Reviews (api-contracts.md Part B, M20).
abstract class ReviewsRepository {
  Future<Result<Review>> create(
    String eventId,
    String bookingId,
    ReviewInput input, {
    required String idempotencyKey,
  });
  Future<Result<RatingSummary>> summary(String listingId);

  /// The caller's reviews, newest first (M21 "My reviews").
  Future<Result<MyReviewPage>> mine({String? cursor});
  Future<Result<PublicReviewPage>> listingReviews(
    String listingId, {
    String? cursor,
  });
}
