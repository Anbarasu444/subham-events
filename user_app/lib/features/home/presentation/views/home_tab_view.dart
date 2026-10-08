import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../domain/dashboard_section.dart';
import '../../../events/presentation/events_navigation.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../../../../core/utils/date_format.dart';
import '../../../checklist/presentation/checklist_navigation.dart';
import '../../../checklist/presentation/widgets/checklist_progress.dart';
import '../../../budget/presentation/views/budget_view.dart';
import '../../../explore/presentation/controllers/explore_controller.dart';
import '../../../explore/presentation/widgets/category_icon.dart';
import '../../../explore/presentation/widgets/listing_card_tile.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../reminders/presentation/widgets/due_reminders_banner.dart';
import '../../data/explore_section_source.dart';
import '../../data/budget_overview_source.dart';
import '../../data/checklist_progress_source.dart';
import '../../data/upcoming_event_source.dart';
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

  /// Guests are asked to sign in first; signed-in users get the new-event
  /// form in the My Events tab.
  void _startPlanning() => controller.signedIn
      ? EventsNavigation.startCreate()
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
            Obx(
              () => AppButton(
                label: controller.signedIn && controller.hasEvents
                    ? 'Create event'
                    : 'Create your first event',
                icon: Icons.add,
                onPressed: _startPlanning,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Due and next reminders (M17); signed-in users only.
            Obx(
              () =>
                  controller.signedIn && Get.isRegistered<RemindersRepository>()
                  ? const DueRemindersBanner()
                  : const SizedBox.shrink(),
            ),
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
        contentBuilder: (context, data) =>
            _UpcomingEvent(summary: data as UpcomingEventSummary),
      ),
      DashboardSectionId.checklist => DashboardSectionCard(
        title: 'Checklist progress',
        icon: Icons.checklist_outlined,
        state: state,
        onRetry: retry,
        emptyMessage: signedIn
            ? 'Plan an upcoming event to see its checklist here.'
            : 'Your checklist will appear once you create an event.',
        contentBuilder: (context, data) =>
            _ChecklistProgressCard(data: data as ChecklistProgressData),
      ),
      DashboardSectionId.budget => DashboardSectionCard(
        title: 'Budget overview',
        icon: Icons.account_balance_wallet_outlined,
        state: state,
        onRetry: retry,
        emptyMessage: signedIn
            ? 'Plan an upcoming event to see its budget here.'
            : 'Track planned and paid amounts once you create an event.',
        contentBuilder: (context, data) =>
            _BudgetOverviewCard(data: data as BudgetOverviewData),
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
        contentBuilder: (context, data) =>
            _ExploreCard(data: data as ExploreSectionData),
      ),
    };
  }
}

class _UpcomingEvent extends StatelessWidget {
  const _UpcomingEvent({required this.summary});

  final UpcomingEventSummary summary;

  @override
  Widget build(BuildContext context) {
    final next = summary.next;
    if (next == null) {
      final theme = Theme.of(context);
      return Text(
        'No upcoming events. Your past events are in My Events.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return EventCard(
      event: next,
      today: dateOnly(DateTime.now()),
      onTap: () => EventsNavigation.openEvent(next),
    );
  }
}

class _ChecklistProgressCard extends StatelessWidget {
  const _ChecklistProgressCard({required this.data});

  final ChecklistProgressData data;

  void _open() => Get.find<ShellController>().pushInTab(
    ShellTab.events,
    ChecklistNavigation.route(
      eventId: data.event.id,
      eventTitle: data.event.title,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = data.event.checklist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data.event.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (summary.total == 0)
          Text('No tasks yet.', style: theme.textTheme.bodyMedium)
        else ...[
          ChecklistProgress(summary: summary),
          if (summary.pending == 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('All tasks done!', style: theme.textTheme.bodyMedium),
            ),
          for (final task in data.nextTasks)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                [
                  task.title,
                  if (task.isOverdue)
                    'overdue'
                  else if (task.dueDate != null)
                    'due ${formatLongDate(task.dueDate!)}',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: task.isOverdue ? theme.colorScheme.error : null,
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: summary.total == 0 ? 'Add tasks' : 'Open checklist',
          icon: Icons.checklist_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: _open,
        ),
      ],
    );
  }
}

class _BudgetOverviewCard extends StatelessWidget {
  const _BudgetOverviewCard({required this.data});

  final BudgetOverviewData data;

  void _open() => Get.find<ShellController>().pushInTab(
    ShellTab.events,
    BudgetNavigation.route(
      eventId: data.event.id,
      eventTitle: data.event.title,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = data.budget;
    final total = budget.totalBudget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data.event.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          total == null
              ? budget.planned.minorUnits == BigInt.zero
                    ? 'No budget planned yet.'
                    : 'Planned ${budget.planned.format()} · no total set'
              : 'Planned ${budget.planned.format()} of ${total.format()}',
          style: theme.textTheme.bodyMedium,
        ),
        if (budget.plannedShare != null) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: const BorderRadius.all(AppRadii.sm),
            child: LinearProgressIndicator(
              value: budget.plannedShare,
              minHeight: 8,
              color: budget.isOverPlanned ? theme.colorScheme.error : null,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              semanticsLabel: 'Share of the total budget planned',
            ),
          ),
        ],
        if (budget.overPlannedBy != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Over budget by ${budget.overPlannedBy!.format()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (budget.unplanned != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text('Not yet planned: ${budget.unplanned!.format()}'),
          ),
        if (budget.spent.minorUnits > BigInt.zero)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text('Spent so far: ${budget.spent.format()}'),
          ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: total == null && budget.planned.minorUnits == BigInt.zero
              ? 'Plan budget'
              : 'Open budget',
          icon: Icons.account_balance_wallet_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: _open,
        ),
      ],
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.data});

  final ExploreSectionData data;

  void _open({String? categoryId}) {
    Get.find<ExploreController>().openWith(
      categoryId: categoryId,
      city: data.city,
    );
    Get.find<ShellController>().select(ShellTab.explore);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.categories.isNotEmpty)
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final category in data.categories.take(6))
                ActionChip(
                  avatar: Icon(categoryIcon(category.slug), size: 18),
                  label: Text(category.name),
                  onPressed: () => _open(categoryId: category.id),
                ),
            ],
          ),
        if (data.listings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.city == null ? 'New on the app' : 'In ${data.city}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final listing in data.listings) ...[
            ListingCardTile(listing: listing),
            const SizedBox(height: AppSpacing.xs),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Vendors will appear here once they join.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'See all vendors',
          icon: Icons.explore_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: _open,
        ),
      ],
    );
  }
}
