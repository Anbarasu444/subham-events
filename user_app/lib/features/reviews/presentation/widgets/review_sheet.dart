import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/review.dart';
import '../controllers/review_form_controller.dart';
import 'stars.dart';

/// Rate a vendor after a completed booking; returns the review, or null.
Future<Review?> showReviewSheet(
  BuildContext context, {
  required String eventId,
  required String bookingId,
  required String vendorName,
}) => showModalBottomSheet<Review>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _ReviewSheet(
    eventId: eventId,
    bookingId: bookingId,
    vendorName: vendorName,
  ),
);

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({
    required this.eventId,
    required this.bookingId,
    required this.vendorName,
  });

  final String eventId;
  final String bookingId;
  final String vendorName;

  @override
  Widget build(BuildContext context) => GetBuilder<ReviewFormController>(
    init: ReviewFormController(
      Get.find<ReviewsRepository>(),
      eventId,
      bookingId,
    ),
    global: false,
    builder: (c) {
      final theme = Theme.of(context);
      final muted = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Rate $vendorName',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  'You can send one review per booking. It can’t be changed '
                  'later.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.sm),
                StarRatingInput(value: c.rating.value, onChanged: c.setRating),
                if (c.ratingError.value != null)
                  Text(
                    c.ratingError.value!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: c.comment,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: ReviewFormController.maxComment,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    hintText: 'What went well? What could be better?',
                    alignLabelWithHint: true,
                  ),
                ),
                Text(
                  'Your stars show straight away. A comment is checked by our '
                  'team before it appears, with your name shown like '
                  '“Asha K.”.',
                  style: muted,
                ),
                if (c.formError.value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      c.formError.value!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Send review',
                  icon: Icons.send_outlined,
                  isBusy: c.saving.value,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final review = await c.submit();
                    if (review != null) navigator.pop(review);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
