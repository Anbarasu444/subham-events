import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/platform/external_actions.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../event_vendors/presentation/widgets/add_to_event_sheet.dart';
import '../../../wishlist/presentation/controllers/wishlist_controller.dart';
import '../../../wishlist/presentation/widgets/save_button.dart';
import '../../domain/listing.dart';
import '../controllers/listing_detail_controller.dart';
import '../../../reviews/presentation/widgets/listing_reviews_section.dart';
import '../widgets/category_icon.dart';
import '../widgets/listing_card_tile.dart';

/// Opens listing details inside the current tab (Explore, Home, …).
abstract final class ListingNavigation {
  static Route<void> route(ListingCard card) => MaterialPageRoute<void>(
    builder: (_) => ListingDetailView(listingId: card.id, preview: card),
  );

  static Future<void> open(BuildContext context, ListingCard card) =>
      Navigator.of(context).push(route(card));
}

/// Listing details (M13): listing, vendor, contact (signed-in users only,
/// A10), more from the vendor and similar vendors. Guests can view it.
class ListingDetailView extends StatelessWidget {
  const ListingDetailView({super.key, required this.listingId, this.preview});

  final String listingId;
  final ListingCard? preview;

  ExternalActions get _external => Get.isRegistered<ExternalActions>()
      ? Get.find<ExternalActions>()
      : const PlatformExternalActions();

  @override
  Widget build(BuildContext context) => GetBuilder<ListingDetailController>(
    init: ListingDetailController(
      Get.find<DiscoveryRepository>(),
      Get.find<SessionService>(),
      listingId,
      preview: preview,
    ),
    global: false,
    builder: (c) => Obx(() {
      final state = c.detail.value;
      final ListingDetail? data = switch (state) {
        Content(:final data) => data,
        _ => null,
      };
      final card = data?.card ?? (c.isGone ? null : c.preview);
      return Scaffold(
        appBar: AppBar(
          title: Text(card?.category.name ?? 'Vendor'),
          actions: [
            if (card != null && Get.isRegistered<WishlistController>())
              SaveButton(listingId: card.id, name: card.title),
            if (card != null)
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    final box = buttonContext.findRenderObject() as RenderBox?;
                    _external.shareText(
                      ListingDetailController.shareText(card),
                      subject: card.title,
                      origin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    );
                  },
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: c.load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (c.isGone)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    icon: Icons.storefront_outlined,
                    title: 'This vendor is no longer listed',
                    body:
                        'It may have been withdrawn or paused. Explore other '
                        'vendors instead.',
                  ),
                )
              else ...[
                if (state case Content(isStale: true))
                  const SliverToBoxAdapter(child: StaleBanner()),
                if (card != null) ...[
                  SliverToBoxAdapter(child: _Header(card: card)),
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    sliver: SliverList.list(
                      children: [
                        _Summary(card: card),
                        if (data != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            label: 'Add to event',
                            icon: Icons.playlist_add,
                            onPressed: () => c.signedIn
                                ? addListingToEvent(context, card)
                                : _askToSignIn(context),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        ..._details(context, c, state, data),
                        const SizedBox(height: AppSpacing.lg),
                        ListingReviewsSection(listingId: card.id),
                      ],
                    ),
                  ),
                ] else
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: switch (state) {
                      Failed(:final failure) => _Message(
                        icon: Icons.error_outline,
                        title: failureTitle(failure),
                        body: failureMessage(failure),
                        action: failure.isRetryable
                            ? AppButton(
                                label: 'Try again',
                                icon: Icons.refresh,
                                onPressed: c.loadDetail,
                              )
                            : null,
                      ),
                      _ => const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Loading vendor',
                        ),
                      ),
                    },
                  ),
                if (card != null) _RelatedSlivers(controller: c),
              ],
            ],
          ),
        ),
      );
    }),
  );

  void _askToSignIn(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Sign in to add vendors to your events.'),
          action: SnackBarAction(
            label: 'Sign in',
            onPressed: () {
              final tab = Get.isRegistered<ShellController>()
                  ? Get.find<ShellController>().current.value
                  : null;
              Get.toNamed<void>(
                AppRoutes.signIn,
                parameters: {if (tab != null) 'returnTo': AppRoutes.tab(tab)},
              );
            },
          ),
        ),
      );
  }

  List<Widget> _details(
    BuildContext context,
    ListingDetailController c,
    ViewState<ListingDetail> state,
    ListingDetail? data,
  ) {
    if (data == null) {
      return switch (state) {
        Failed(:final failure) => [
          Text(failureMessage(failure)),
          if (failure.isRetryable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: c.loadDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
        ],
        _ => const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading details',
              ),
            ),
          ),
        ],
      };
    }
    final theme = Theme.of(context);
    return [
      if (data.description != null) ...[
        Semantics(
          header: true,
          child: Text('About this service', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(data.description!),
        const SizedBox(height: AppSpacing.lg),
      ],
      _VendorCard(
        vendor: data.vendor,
        signedIn: c.signedIn,
        external: _external,
        listingTitle: data.card.title,
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card});

  final ListingCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Listing photos arrive in M28; until then a category icon (answer 5).
    return ExcludeSemantics(
      child: Container(
        height: 160,
        color: scheme.primaryContainer,
        alignment: Alignment.center,
        child: Icon(
          categoryIcon(card.category.slug),
          size: 72,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.card});

  final ListingCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(card.title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${card.vendorName} · ${card.category.name}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Starting from ${card.startingPrice.format()}',
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
        ),
        Text(
          'Final price depends on your event; agree it with the vendor.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.place_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                card.serviceAreas.isEmpty
                    ? card.city
                    : '${card.city} · also serves '
                          '${card.serviceAreas.join(', ')}',
              ),
            ),
          ],
        ),
        if (card.ratingAverage != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '★ ${card.ratingAverage} (${card.ratingCount} reviews)',
            semanticsLabel:
                'Rated ${card.ratingAverage} from ${card.ratingCount} reviews',
          ),
        ],
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.signedIn,
    required this.external,
    required this.listingTitle,
  });

  final VendorProfile vendor;
  final bool signedIn;
  final ExternalActions external;
  final String listingTitle;

  Future<void> _report(BuildContext context, Future<bool> opened) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No app on this phone can open that.')),
      );
    }
  }

  void _signIn() {
    final tab = Get.isRegistered<ShellController>()
        ? Get.find<ShellController>().current.value
        : null;
    Get.toNamed<void>(
      AppRoutes.signIn,
      parameters: {if (tab != null) 'returnTo': AppRoutes.tab(tab)},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contact = vendor.contact;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'About the vendor',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(vendor.businessName, style: theme.textTheme.titleSmall),
            Text(
              vendor.serviceAreas.isEmpty
                  ? vendor.city
                  : '${vendor.city} · ${vendor.serviceAreas.join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
            if (vendor.description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(vendor.description!),
            ],
            const Divider(height: AppSpacing.lg),
            if (!signedIn || contact == null) ...[
              Text(
                'Sign in to see contact details.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Sign in',
                icon: Icons.login,
                variant: AppButtonVariant.secondary,
                onPressed: _signIn,
              ),
            ] else if (contact.isEmpty)
              Text(
                'This vendor has not added contact details yet.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (contact.phone != null)
                    FilledButton.icon(
                      onPressed: () =>
                          _report(context, external.call(contact.phone!)),
                      icon: const Icon(Icons.call_outlined),
                      label: Text('Call ${contact.phone}'),
                    ),
                  if (contact.email != null)
                    OutlinedButton.icon(
                      onPressed: () => _report(
                        context,
                        external.email(
                          contact.email!,
                          subject: 'Enquiry: $listingTitle',
                        ),
                      ),
                      icon: const Icon(Icons.mail_outline),
                      label: Text('Email ${contact.email}'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RelatedSlivers extends StatelessWidget {
  const _RelatedSlivers({required this.controller});

  final ListingDetailController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final theme = Theme.of(context);
    Widget section(String title, List<ListingCard> cards) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
        ),
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.xs,
            ),
            child: ListingCardTile(listing: card),
          ),
      ],
    );
    return switch (controller.related.value) {
      Content(:final data) => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.sameVendor.isNotEmpty)
              section('More from this vendor', data.sameVendor),
            if (data.similar.isNotEmpty)
              section('Similar vendors', data.similar),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
      Failed(:final failure) when failure.isRetryable => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: TextButton.icon(
            onPressed: controller.loadRelated,
            icon: const Icon(Icons.refresh),
            label: const Text('Could not load similar vendors. Try again'),
          ),
        ),
      ),
      _ => const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
    };
  });
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(body!, textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
