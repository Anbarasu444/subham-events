import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../domain/dashboard_section.dart';
import '../controllers/home_controller.dart';
import '../widgets/dashboard_section_card.dart';

/// Home tab dashboard (M7, Option A): greeting, primary call to action and
/// sections that later milestones fill with real data.
class HomeTabView extends GetView<HomeController> {
  const HomeTabView({super.key});

  void _openTab(ShellTab tab) => Get.find<ShellController>().select(tab);

  void _signIn(ShellTab returnTab) => Get.toNamed<void>(
    AppRoutes.signIn,
    parameters: {'returnTo': AppRoutes.tab(returnTab)},
  );

  /// Guests are asked to sign in first; signed-in users go to My Events.
  void _startPlanning() => controller.signedIn
      ? _openTab(ShellTab.events)
      : _signIn(ShellTab.events);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Event Planner')),
      body: RefreshIndicator(
        onRefresh: controller.refreshAll,
        // Small fixed list; each part rebuilds only for its own state.
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Obx(
              () => Semantics(
                header: true,
                child: Text(
                  controller.greeting,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Let’s plan something wonderful.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Create your first event',
              icon: Icons.add,
              onPressed: _startPlanning,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final source in controller.sources) ...[
              Obx(() => _section(source.id, signedIn: controller.signedIn)),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(DashboardSectionId id, {required bool signedIn}) {
    final state = controller.sections[id]!.value;
    void retry() => controller.loadSection(id);
    return switch (id) {
      DashboardSectionId.upcomingEvent => DashboardSectionCard(
        title: 'Upcoming event',
        icon: Icons.event_outlined,
        state: state,
        onRetry: retry,
        emptyMessage: signedIn
            ? 'You have no events yet.'
            : 'Sign in to see your upcoming events.',
      ),
      DashboardSectionId.checklist => DashboardSectionCard(
        title: 'Checklist progress',
        icon: Icons.checklist_outlined,
        state: state,
        onRetry: retry,
        emptyMessage: 'Your checklist will appear once you create an event.',
      ),
      DashboardSectionId.budget => DashboardSectionCard(
        title: 'Budget overview',
        icon: Icons.account_balance_wallet_outlined,
        state: state,
        onRetry: retry,
        emptyMessage:
            'Track planned and paid amounts once you create an event.',
      ),
      DashboardSectionId.explore => DashboardSectionCard(
        title: 'Explore vendors',
        icon: Icons.storefront_outlined,
        state: state,
        onRetry: retry,
        emptyMessage: 'Find photographers, caterers, decorators and more.',
        emptyAction: AppButton(
          label: 'Explore',
          icon: Icons.explore_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => _openTab(ShellTab.explore),
        ),
      ),
    };
  }
}
