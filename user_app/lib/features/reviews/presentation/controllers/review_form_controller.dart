import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/request_id.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/review.dart';

/// Rate a completed booking once (M20; A4, A5).
class ReviewFormController extends GetxController {
  ReviewFormController(this._repository, this.eventId, this.bookingId);

  final ReviewsRepository _repository;
  final String eventId;
  final String bookingId;

  final comment = TextEditingController();
  final RxInt rating = 0.obs;
  final Rx<String?> ratingError = Rx<String?>(null);
  final Rx<String?> formError = Rx<String?>(null);
  final RxBool saving = false.obs;

  String _idempotencyKey = generateRequestId();
  ReviewInput? _lastAttempt;

  static const maxComment = 1000;

  @override
  void onClose() {
    comment.dispose();
    super.onClose();
  }

  void setRating(int value) {
    rating.value = value;
    ratingError.value = null;
  }

  Future<Review?> submit() async {
    if (saving.value) return null;
    formError.value = null;
    if (rating.value < 1) {
      ratingError.value = 'Choose 1 to 5 stars.';
      return null;
    }
    final text = comment.text.trim();
    final input = ReviewInput(
      rating: rating.value,
      comment: text.isEmpty ? null : text,
    );
    // Same input → same key: a retry never sends the review twice.
    if (_lastAttempt != null && _lastAttempt != input) {
      _idempotencyKey = generateRequestId();
    }
    _lastAttempt = input;
    saving.value = true;
    final result = await _repository.create(
      eventId,
      bookingId,
      input,
      idempotencyKey: _idempotencyKey,
    );
    if (isClosed) return null;
    saving.value = false;
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        formError.value = switch (failure) {
          ConflictFailure(:final message?) => message,
          ForbiddenFailure() => 'You can’t review your own listing.',
          ValidationFailure() => 'Please check the rating and comment.',
          _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
        };
        return null;
    }
  }
}
