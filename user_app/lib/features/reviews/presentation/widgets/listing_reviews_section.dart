import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/review.dart';
import '../controllers/listing_reviews_controller.dart';
import 'stars.dart';

/// "Ratings & reviews" on a listing's details page (M20).
class ListingReviewsSection extends StatelessWidget {
  const ListingReviewsSection({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) => GetBuilder<ListingReviewsController>(
    init: ListingReviewsController(Get.find<ReviewsRepository>(), listingId),
    global: false,
    builder: (c) => Obx(() {
      final theme = Theme.of(context);
      final state = c.state.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Ratings & reviews',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          switch (state) {
            Loading() => const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading reviews',
                ),
              ),
            ),
            Failed(:final failure) => Row(
              children: [
                Expanded(child: Text(failureMessage(failure))),
                if (failure.isRetryable)
                  TextButton(onPressed: c.load, child: const Text('Try again')),
              ],
            ),
            Content(:final data) => _Body(controller: c, data: data),
            _ => const SizedBox.shrink(),
          },
        ],
      );
    }),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.data});

  final ListingReviewsController controller;
  final ListingReviews data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = data.summary;
    if (summary.count == 0) {
      return Text(
        'No ratings yet. Customers can rate a vendor after a completed '
        'booking.',
        style: theme.textTheme.bodyMedium,
      );
    }
    final most = summary.stars.fold(0, (m, s) => s.count > m ? s.count : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.average ?? '–',
                  style: theme.textTheme.displaySmall,
                  semanticsLabel: 'Average ${summary.average} out of 5',
                ),
                StarsDisplay(
                  rating: double.parse(summary.average ?? '0').round(),
                ),
                Text(
                  '${summary.count} ${summary.count == 1 ? 'rating' : 'ratings'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                children: [
                  for (final s in summary.stars)
                    Semantics(
                      label: '${s.stars} stars: ${s.count}',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          SizedBox(width: 16, child: Text('${s.stars}')),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: most == 0 ? 0 : s.count / most,
                              minHeight: 6,
                              borderRadius: const BorderRadius.all(AppRadii.sm),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          SizedBox(
                            width: 32,
                            child: Text('${s.count}', textAlign: TextAlign.end),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.reviews.isEmpty)
          Text('No written reviews yet.', style: theme.textTheme.bodySmall)
        else
          for (final r in data.reviews) _ReviewTile(review: r),
        if (data.nextCursor != null)
          Obx(() {
            final error = controller.moreError.value;
            return Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: controller.loadingMore.value
                    ? null
                    : controller.loadMore,
                child: Text(
                  error != null ? 'Couldn’t load more. Try again' : 'Show more',
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PublicReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StarsDisplay(rating: review.rating, size: 16),
              Text(review.reviewerName, style: theme.textTheme.labelLarge),
              Text(
                formatLongDate(review.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(review.comment),
        ],
      ),
    );
  }
}
