import 'package:flutter/material.dart';
import '../../../../core/widgets/festive.dart';
import '../../../../core/assets/app_illustrations.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/listing.dart';
import '../controllers/explore_controller.dart';
import '../widgets/category_icon.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/listing_card_tile.dart';

/// Explore tab (M12): search, categories, filters and paged vendor listings.
/// Guests can browse; listing details arrive in M13.
class ExploreTabView extends StatefulWidget {
  const ExploreTabView({super.key});

  @override
  State<ExploreTabView> createState() => _ExploreTabViewState();
}

class _ExploreTabViewState extends State<ExploreTabView> {
  final ExploreController _c = Get.find<ExploreController>();
  late final TextEditingController _search = TextEditingController(
    text: _c.query.value.text,
  );
  Worker? _queryWorker;

  @override
  void initState() {
    super.initState();
    _c.start();
    // A preset from Home replaces the query: keep the field in step.
    _queryWorker = ever<ListingQuery>(_c.query, (q) {
      final text = q.text ?? '';
      if (_search.text.trim() != text) _search.text = text;
    });
  }

  @override
  void dispose() {
    _queryWorker?.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final citiesResult = await Get.find<DiscoveryRepository>().cities();
    if (!mounted) return;
    final cities = switch (citiesResult) {
      Ok(:final value) => value,
      Err() => const <String>[],
    };
    final next = await showFilterSheet(
      context,
      current: _c.query.value,
      cities: cities,
    );
    if (next != null) _c.applyFilters(next);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 600) _c.loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore')),
    body: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_c.loadCategories(), _c.search()]);
        },
        child: CustomScrollView(
          key: const PageStorageKey<String>('explore'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _search,
                  onChanged: _c.setText,
                  onSubmitted: (_) => _c.search(),
                  textInputAction: TextInputAction.search,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: 'Search vendors, e.g. photography',
                    prefixIcon: const Icon(Icons.search),
                    counterText: '',
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _search,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _c.setText('');
                                _c.search();
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _CategoryChips(controller: _c)),
            SliverToBoxAdapter(
              child: _ActiveFilters(controller: _c, onOpen: _openFilters),
            ),
            _Results(controller: _c),
          ],
        ),
      ),
    ),
  );
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final selected = controller.query.value.categoryId;
    final state = controller.categories.value;
    final List<Widget> chips = switch (state) {
      Content(:final data) => [
        ChoiceChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => controller.setCategory(null),
        ),
        for (final category in data)
          ChoiceChip(
            avatar: Icon(categoryIcon(category.slug), size: 18),
            label: Text(category.name),
            selected: selected == category.id,
            onSelected: (on) => controller.setCategory(on ? category.id : null),
          ),
      ],
      Failed() => [
        ActionChip(
          avatar: const Icon(Icons.refresh, size: 18),
          label: const Text('Categories did not load. Retry'),
          onPressed: controller.loadCategories,
        ),
      ],
      _ => const [],
    };
    if (chips.isEmpty) return const SizedBox(height: AppSpacing.sm);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xs,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  });
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller, required this.onOpen});

  final ExploreController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Obx(() {
    final q = controller.query.value;
    final price = switch ((q.minPrice, q.maxPrice)) {
      (null, null) => null,
      (final min?, null) => 'From ${min.format()}',
      (null, final max?) => 'Up to ${max.format()}',
      (final min?, final max?) => '${min.format()} – ${max.format()}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            avatar: const Icon(Icons.tune, size: 18),
            label: const Text('Filters'),
            onPressed: onOpen,
          ),
          FilterChip(
            avatar: q.saved
                ? null
                : const Icon(Icons.favorite_border, size: 18),
            label: const Text('Saved'),
            selected: q.saved,
            onSelected: (on) {
              if (!controller.setSaved(on)) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Sign in to see your saved vendors.'),
                    ),
                  );
              }
            },
          ),
          if (q.city != null)
            InputChip(
              avatar: const Icon(Icons.place_outlined, size: 18),
              label: Text(q.city!),
              deleteButtonTooltipMessage: 'Remove city ${q.city}',
              onDeleted: () =>
                  controller.applyFilters(q.copyWith(city: () => null)),
            ),
          if (price != null)
            InputChip(
              label: Text(price),
              deleteButtonTooltipMessage: 'Remove price range',
              onDeleted: () => controller.applyFilters(
                q.copyWith(minPrice: () => null, maxPrice: () => null),
              ),
            ),
          if (q.sort != ListingSort.relevance)
            InputChip(
              label: Text(q.sort.label),
              deleteButtonTooltipMessage: 'Remove sort',
              onDeleted: () => controller.applyFilters(
                q.copyWith(sort: ListingSort.relevance),
              ),
            ),
        ],
      ),
    );
  });
}

class _Results extends StatelessWidget {
  const _Results({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final theme = Theme.of(context);
    final state = controller.results.value;
    Widget message({
      required IconData icon,
      required String title,
      String? body,
      Widget? action,
      String? illustration,
    }) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (illustration != null)
              Illustration(
                illustration,
                fallback: icon,
                size: AppSizes.emptyIllustration,
              )
            else
              Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(body, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action,
            ],
          ],
        ),
      ),
    );
    return switch (state) {
      Loading() => SliverList.list(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                0,
              ),
              child: Semantics(
                label: i == 0 ? 'Loading vendors' : null,
                child: Container(
                  height: 88,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.all(AppRadii.md),
                  ),
                ),
              ),
            ),
        ],
      ),
      Empty() => message(
        icon: Icons.search_off,
        illustration: AppIllustrations.emptySearch,
        title: 'No vendors match',
        body: controller.query.value.hasFilters
            ? 'Try another city, category or price range.'
            : 'Vendors will appear here once they join.',
        action: controller.query.value.hasFilters
            ? AppButton(
                label: 'Clear filters',
                icon: Icons.filter_alt_off_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: controller.clearFilters,
              )
            : null,
      ),
      Failed(:final failure) => message(
        icon: Icons.error_outline,
        title: failureTitle(failure),
        body: failureMessage(failure),
        action: failure.isRetryable
            ? AppButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: controller.search,
              )
            : null,
      ),
      Content(:final data, :final isStale) => SliverMainAxisGroup(
        slivers: [
          if (isStale) const SliverToBoxAdapter(child: StaleBanner()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              0,
            ),
            sliver: SliverList.separated(
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (_, index) => ListingCardTile(listing: data[index]),
            ),
          ),
          SliverToBoxAdapter(child: _Footer(controller: controller)),
        ],
      ),
    };
  });
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final Failure? failure = controller.loadMoreFailure.value;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: controller.loadingMore.value
            ? const CircularProgressIndicator(
                semanticsLabel: 'Loading more vendors',
              )
            : failure != null
            ? TextButton.icon(
                onPressed: controller.loadMore,
                icon: const Icon(Icons.refresh),
                label: const Text('Could not load more. Try again'),
              )
            : controller.hasMore
            ? const SizedBox(height: 40)
            : const SizedBox.shrink(),
      ),
    );
  });
}
