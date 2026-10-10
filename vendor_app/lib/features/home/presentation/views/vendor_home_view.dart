import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/assets/app_illustrations.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/festive.dart';
import '../controllers/vendor_home_controller.dart';

/// Placeholder vendor home (M24). Shows the brand, the server connection and
/// what is coming next; real vendor screens arrive from M25.
class VendorHomeView extends GetView<VendorHomeController> {
  const VendorHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.checkConnection,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const ScreenTitle(
                icon: Icons.storefront_outlined,
                title: 'Subam Vendor',
              ),
              const SizedBox(height: AppSpacing.md),
              const _WelcomeCard(),
              const SizedBox(height: AppSpacing.md),
              _ConnectionCard(controller: controller),
              const SizedBox(height: AppSpacing.md),
              const _ComingSoonCard(),
              if (controller.config.enableDiagnostics) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.diagnostics),
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Diagnostics'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientBox(
      gradient: AppGradients.hero,
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Grow your business',
                    style: onGradientStyle(theme.textTheme.headlineSmall),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'List your services, answer enquiries and manage bookings '
                  '— all in one place. Sign-in is coming next.',
                  style: onGradientStyle(theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Illustration(
            AppIllustrations.onboardingWelcome,
            fallback: Icons.storefront_outlined,
            size: 88,
            color: AppColors.onGradient,
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.controller});

  final VendorHomeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.cloud_outlined,
      title: 'Server connection',
      actionLabel: 'Check again',
      onAction: controller.checkConnection,
      child: Obx(() {
        final (
          icon,
          color,
          title,
          detail,
        ) = switch (controller.connection.value) {
          Loading() => (
            Icons.sync,
            theme.colorScheme.onSurfaceVariant,
            'Checking…',
            'Contacting the server.',
          ),
          Content(:final data) => (
            Icons.check_circle,
            AppColors.success,
            'Connected',
            'Server ${data.status} · ${data.latency.inMilliseconds} ms',
          ),
          Failed(:final failure) => (
            Icons.cloud_off_outlined,
            theme.colorScheme.error,
            failureTitle(failure),
            failureMessage(failure),
          ),
          Empty() => (
            Icons.help_outline,
            theme.colorScheme.onSurfaceVariant,
            'Unknown',
            'Try again.',
          ),
        };
        return Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(detail, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  static const _items = [
    (AppIllustrations.menuListings, Icons.list_alt_outlined, 'Listings'),
    (AppIllustrations.menuEnquiries, Icons.forum_outlined, 'Enquiries'),
    (AppIllustrations.menuQuotations, Icons.request_quote_outlined, 'Quotes'),
    (AppIllustrations.menuBookings, Icons.event_available_outlined, 'Bookings'),
    (AppIllustrations.menuPayments, Icons.payments_outlined, 'Payments'),
    (AppIllustrations.menuReviews, Icons.star_outline_rounded, 'Reviews'),
    (AppIllustrations.menuCalendar, Icons.calendar_month_outlined, 'Calendar'),
    (AppIllustrations.menuProfile, Icons.badge_outlined, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.grid_view_rounded,
      title: 'Coming soon',
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.md,
        children: [
          for (final (asset, icon, label) in _items)
            SizedBox(
              width: 72,
              child: Column(
                children: [
                  Illustration(asset, fallback: icon),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
