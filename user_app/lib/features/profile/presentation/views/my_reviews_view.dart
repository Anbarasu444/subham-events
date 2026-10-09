import 'package:flutter/material.dart';
import '../../../../core/assets/app_illustrations.dart';
import 'package:get/get.dart';

import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../reviews/domain/review.dart';
import '../../../reviews/presentation/widgets/stars.dart';

/// The user's own reviews and their comment status (M21).
class MyReviewsView extends StatefulWidget {
  const MyReviewsView({super.key});

  @override
  State<MyReviewsView> createState() => _MyReviewsViewState();
}

class _MyReviewsViewState extends State<MyReviewsView> {
  ViewState<List<Review>> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await Get.find<ReviewsRepository>().mine();
    if (!mounted) return;
    setState(() {
      _state = switch (result) {
        Ok(:final value) =>
          value.items.isEmpty ? const Empty() : Content(value.items),
        Err(:final failure) => Failed(failure),
      };
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My reviews')),
    body: _state is Empty<List<Review>>
        ? const EmptyStateView(
            icon: Icons.star_outline_rounded,
            illustration: AppIllustrations.emptyReviews,
            title: 'No reviews yet',
            message:
                'After a booking is completed, you can rate the vendor from '
                'the event’s Vendors tab.',
          )
        : AsyncStateView<List<Review>>(
            state: _state,
            onRetry: _load,
            builder: (context, reviews) => RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) {
                  final r = reviews[i];
                  final theme = Theme.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.listingTitle, style: theme.textTheme.titleSmall),
                      Wrap(
                        spacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StarsDisplay(rating: r.rating),
                          Text(
                            formatLongDate(r.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (r.comment != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(r.comment!),
                      ],
                      if (r.commentStatus.authorNote case final note?)
                        Text(note, style: theme.textTheme.bodySmall),
                    ],
                  );
                },
              ),
            ),
          ),
  );
}
