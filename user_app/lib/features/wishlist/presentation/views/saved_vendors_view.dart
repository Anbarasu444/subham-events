import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/state/view_state.dart';
import '../../../explore/presentation/widgets/listing_card_tile.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../domain/wishlist.dart';
import '../controllers/saved_vendors_controller.dart';
import '../controllers/wishlist_controller.dart';

/// Menu → Saved vendors (M14). Signed-in users only (Menu shows it then).
class SavedVendorsView extends StatelessWidget {
  const SavedVendorsView({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SavedVendorsView());

  @override
  Widget build(BuildContext context) => GetBuilder<SavedVendorsController>(
    init: SavedVendorsController(
      Get.find<WishlistRepository>(),
      Get.find<WishlistController>(),
    ),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(title: const Text('Saved vendors')),
      body: Obx(() {
        final state = c.state.value;
        if (state is Empty<List<WishlistItem>>) {
          return EmptyStateView(
            icon: Icons.favorite_border,
            title: 'No saved vendors yet',
            message: 'Tap the heart on a vendor to keep it here for later.',
            action: AppButton(
              label: 'Explore vendors',
              icon: Icons.explore_outlined,
              onPressed: () {
                Navigator.of(context).pop();
                Get.find<ShellController>().select(ShellTab.explore);
              },
            ),
          );
        }
        return AsyncStateView<List<WishlistItem>>(
          state: state,
          onRetry: c.load,
          builder: (context, items) => NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 600) c.loadMore();
              return false;
            },
            child: RefreshIndicator(
              onRefresh: c.load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  if (index == items.length) return _Footer(controller: c);
                  final item = items[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Opacity(
                        opacity: item.isAvailable ? 1 : 0.6,
                        child: ListingCardTile(
                          listing: item.listing,
                          // A hidden listing has no details page any more.
                          onTap: item.isAvailable ? null : () {},
                        ),
                      ),
                      if (!item.isAvailable)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                            top: AppSpacing.xxs,
                          ),
                          child: Text(
                            'No longer listed',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final SavedVendorsController controller;

  @override
  Widget build(BuildContext context) => Obx(
    () => Center(
      child: controller.loadingMore.value
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(semanticsLabel: 'Loading more'),
            )
          : controller.loadMoreFailure.value != null
          ? TextButton.icon(
              onPressed: controller.loadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Could not load more. Try again'),
            )
          : const SizedBox(height: AppSpacing.lg),
    ),
  );
}
