import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/assets/app_illustrations.dart';
import '../../../../core/money/money.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/festive.dart';
import '../../../budget/presentation/views/budget_view.dart';
import '../../../checklist/presentation/checklist_navigation.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../../events/presentation/events_navigation.dart';
import '../../../explore/presentation/controllers/explore_controller.dart';
import '../../../explore/presentation/widgets/category_icon.dart';
import '../../../explore/presentation/widgets/listing_card_tile.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../profile/presentation/views/my_reviews_view.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../reminders/presentation/views/schedule_view.dart';
import '../../../reminders/presentation/widgets/due_reminders_banner.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../data/budget_overview_source.dart';
import '../../data/checklist_progress_source.dart';
import '../../data/event_charts_source.dart';
import '../../data/explore_section_source.dart';
import '../../data/upcoming_event_source.dart';
import '../../domain/dashboard_section.dart';
import '../controllers/home_controller.dart';

/// Home tab (M7; festive redesign M22): event countdown, quick actions,
/// checklist progress, charts for vendors, replies and budget, and vendor
/// suggestions. Each part loads on its own and never blanks the page.
class HomeTabView extends GetView<HomeController> {
  const HomeTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(icon: Icons.home_outlined, title: 'Home'),
        actions: [
          Obx(
            () => controller.signedIn
                ? const NotificationBell()
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Obx(
              () => Semantics(
                header: true,
                child: Text(
                  controller.greeting,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _watch([
              DashboardSectionId.upcomingEvent,
            ], () => _EventHero(controller: controller)),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () =>
                  controller.signedIn && Get.isRegistered<RemindersRepository>()
                  ? const DueRemindersBanner()
                  : const SizedBox.shrink(),
            ),
            _watch([
              DashboardSectionId.upcomingEvent,
            ], () => _QuickActions(event: _nextEvent(controller))),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => controller.signedIn
                  ? const SizedBox.shrink()
                  : const _SignInAdvice(),
            ),
            _watch([
              DashboardSectionId.checklist,
            ], () => _ChecklistCard(controller: controller)),
            _watch([
              DashboardSectionId.charts,
            ], () => _ChartsRow(controller: controller)),
            _watch([
              DashboardSectionId.budget,
            ], () => _BudgetCard(controller: controller)),
            _watch([
              DashboardSectionId.explore,
            ], () => _ExploreCard(controller: controller)),
          ],
        ),
      ),
    );
  }

  /// Rebuilds [build] when the given sections or the session change (the
  /// observables must be read inside the Obx closure itself).
  Widget _watch(List<DashboardSectionId> ids, Widget Function() build) =>
      Obx(() {
        for (final id in ids) {
          controller.sections[id]?.value;
        }
        controller.signedIn;
        return build();
      });
}

PlannerEvent? _nextEvent(HomeController c) =>
    switch (c.sections[DashboardSectionId.upcomingEvent]?.value) {
      Content(:final UpcomingEventSummary data) => data.next,
      _ => null,
    };

/// Wraps a section with spacing; hides sections with nothing to show.
class _Gap extends StatelessWidget {
  const _Gap(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: child,
  );
}

/// A small failure row with "Try again" inside a section.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.state, required this.onRetry});
  final Failed<Object?> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(failureMessage(state.failure))),
      if (state.failure.isRetryable)
        TextButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.controller});
  final HomeController controller;

  void _start() => controller.signedIn
      ? EventsNavigation.startCreate()
      : Get.toNamed<void>(
          AppRoutes.signIn,
          parameters: {'returnTo': AppRoutes.tab(ShellTab.events)},
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state =
        controller.sections[DashboardSectionId.upcomingEvent]?.value ??
        const Empty<Object?>();
    final next = _nextEvent(controller);
    if (state is Loading<Object?>) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (next != null) return _Countdown(event: next);
    final hasEvents = controller.hasEvents;
    return GradientBox(
      gradient: AppGradients.hero,
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasEvents ? 'No upcoming events' : 'Let’s plan something wonderful',
            style: onGradientStyle(theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            state is Failed<Object?>
                ? 'Couldn’t load your events. Pull down to try again.'
                : 'Weddings, birthdays, poojas and more — all in one place.',
            style: onGradientStyle(theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: AppColors.surface,
            borderRadius: const BorderRadius.all(AppRadii.md),
            child: InkWell(
              borderRadius: const BorderRadius.all(AppRadii.md),
              onTap: _start,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            controller.signedIn && hasEvents
                                ? 'Create event'
                                : 'Create your first event',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The countdown's clock (fixed in screenshot tests).
@visibleForTesting
DateTime Function() countdownClock = DateTime.now;

/// "Days . Hours . Mins . Secs" to the event, then the event row.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.event});
  final PlannerEvent event;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  late DateTime _now = countdownClock();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = countdownClock());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime get _start {
    final e = widget.event;
    final parts = e.startTime?.split(':');
    return DateTime(
      e.eventDate.year,
      e.eventDate.month,
      e.eventDate.day,
      parts == null ? 0 : int.parse(parts[0]),
      parts == null ? 0 : int.parse(parts[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = _start.difference(_now);
    final started = left.isNegative;
    String two(int v) => v.toString().padLeft(2, '0');
    final values = [
      ('Days', two(left.inDays)),
      ('Hours', two(left.inHours % 24)),
      ('Mins', two(left.inMinutes % 60)),
      ('Secs', two(left.inSeconds % 60)),
    ];
    final event = widget.event;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(AppRadii.lg),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientBox(
              gradient: AppGradients.hero,
              radius: AppRadii.lg,
              shadow: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Semantics(
                label: started
                    ? '${event.title} is today'
                    : '${left.inDays} days, ${left.inHours % 24} hours and '
                          '${left.inMinutes % 60} minutes to ${event.title}',
                excludeSemantics: true,
                child: started
                    ? Text(
                        'It’s celebration time! 🎉',
                        textAlign: TextAlign.center,
                        style: onGradientStyle(theme.textTheme.headlineSmall),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            for (final (i, (label, value))
                                in values.indexed) ...[
                              if (i > 0)
                                Text(
                                  ' . ',
                                  style: onGradientStyle(
                                    theme.textTheme.displaySmall,
                                  ),
                                ),
                              Column(
                                children: [
                                  Text(
                                    label,
                                    style: onGradientStyle(
                                      theme.textTheme.labelLarge,
                                    ),
                                  ),
                                  Text(
                                    value,
                                    style: onGradientStyle(
                                      theme.textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: AppRadii.lg),
              onTap: () => EventsNavigation.openEvent(event),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Illustration(
                      AppIllustrations.forEventType(event.eventType),
                      fallback: Icons.celebration_outlined,
                      size: 72,
                      height: 56,
                      fit: BoxFit.cover,
                      radius: AppRadii.md,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: theme.textTheme.titleLarge),
                          Text(
                            '${formatLongDate(event.eventDate)} · ${event.city}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.asset, this.icon, this.color, this.onTap);
  final String label;
  final String asset;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context) onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.event});
  final PlannerEvent? event;

  ShellController get _shell => Get.find<ShellController>();

  void _needEvent(BuildContext context, void Function(PlannerEvent e) go) {
    final e = event;
    if (e != null) return go(e);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Create an event first to use this.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        'Checklist',
        AppIllustrations.menuChecklist,
        Icons.checklist_rounded,
        AppChartColors.third,
        (c) => _needEvent(
          c,
          (e) => _shell.pushInTab(
            ShellTab.events,
            ChecklistNavigation.route(eventId: e.id, eventTitle: e.title),
          ),
        ),
      ),
      _QuickAction(
        'Budget',
        AppIllustrations.menuBudget,
        Icons.account_balance_wallet_outlined,
        AppColors.orange,
        (c) => _needEvent(
          c,
          (e) => _shell.pushInTab(
            ShellTab.events,
            BudgetNavigation.route(eventId: e.id, eventTitle: e.title),
          ),
        ),
      ),
      _QuickAction(
        'Vendors',
        AppIllustrations.menuVendors,
        Icons.storefront_outlined,
        AppColors.rose,
        (c) => _needEvent(c, EventsNavigation.openEvent),
      ),
      _QuickAction(
        'Schedule',
        AppIllustrations.menuSchedule,
        Icons.schedule_outlined,
        AppChartColors.fifth,
        (c) => Navigator.of(
          c,
        ).push(MaterialPageRoute<void>(builder: (_) => const ScheduleView())),
      ),
      _QuickAction(
        'Events',
        AppIllustrations.menuEvents,
        Icons.celebration_outlined,
        AppColors.deepOrange,
        (_) => _shell.select(ShellTab.events),
      ),
      _QuickAction(
        'Invitation',
        AppIllustrations.menuInvitation,
        Icons.mail_outline,
        AppColors.rose,
        (c) => _needEvent(c, EventsNavigation.openEvent),
      ),
      _QuickAction(
        'Explore',
        AppIllustrations.menuExplore,
        Icons.explore_outlined,
        AppChartColors.third,
        (_) => _shell.select(ShellTab.explore),
      ),
      _QuickAction(
        'Reviews',
        AppIllustrations.menuReviews,
        Icons.star_outline_rounded,
        AppColors.warning,
        (c) => Navigator.of(
          c,
        ).push(MaterialPageRoute<void>(builder: (_) => const MyReviewsView())),
      ),
    ];
    final signedIn = Get.find<HomeController>().signedIn;
    final visible = signedIn
        ? actions
        : actions.where((a) => a.label == 'Explore').toList();
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Menu',
      icon: Icons.grid_view_rounded,
      actionLabel: 'More',
      onAction: () => _shell.select(ShellTab.menu),
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth < 300 ? 3 : 4;
          final width = (box.maxWidth / columns).floorToDouble();
          return Wrap(
            children: [
              for (final a in visible)
                SizedBox(
                  width: width,
                  child: InkWell(
                    borderRadius: const BorderRadius.all(AppRadii.md),
                    onTap: () => a.onTap(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        children: [
                          Illustration(
                            a.asset,
                            fallback: a.icon,
                            color: a.color,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            a.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SignInAdvice extends StatelessWidget {
  const _SignInAdvice();

  @override
  Widget build(BuildContext context) => _Gap(
    SectionCard(
      title: 'Save your plans',
      icon: Icons.lock_outline,
      child: Row(
        children: [
          const Illustration(
            AppIllustrations.signInSecure,
            fallback: Icons.verified_user_outlined,
            size: 64,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sign in to create events, track your budget and book '
                  'vendors.',
                ),
                const SizedBox(height: AppSpacing.xs),
                GradientButton(
                  label: 'Sign in',
                  onPressed: () => Get.toNamed<void>(
                    AppRoutes.signIn,
                    parameters: {'returnTo': AppRoutes.tab(ShellTab.home)},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.controller});
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.sections[DashboardSectionId.checklist]?.value;
    if (state == null) return const SizedBox.shrink();
    if (state is! Content<Object?> && state is! Failed<Object?>) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final data = state is Content<Object?>
        ? state.data as ChecklistProgressData
        : null;
    void open() => Get.find<ShellController>().pushInTab(
      ShellTab.events,
      ChecklistNavigation.route(
        eventId: data!.event.id,
        eventTitle: data.event.title,
      ),
    );
    final summary = data?.event.checklist;
    return _Gap(
      SectionCard(
        title: 'Checklist',
        icon: Icons.checklist_rounded,
        actionLabel: data == null ? null : 'Summary',
        onAction: data == null ? null : open,
        child: switch (state) {
          Failed() => _SectionError(
            state: state,
            onRetry: () => controller.loadSection(DashboardSectionId.checklist),
          ),
          _ when summary!.total == 0 => Row(
            children: [
              const Expanded(child: Text('No tasks yet.')),
              TextButton(onPressed: open, child: const Text('Add tasks')),
            ],
          ),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final task in data!.nextTasks.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      if (task.dueDate != null)
                        Text(
                          task.isOverdue
                              ? 'overdue'
                              : formatShortDate(task.dueDate!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: task.isOverdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              if (summary.pending == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    'All tasks done! 🎉',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              GradientProgressBar(
                value: summary.progress,
                semanticsLabel: 'Checklist progress',
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(summary.progress * 100).round()}% completed',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${summary.done} out of ${summary.total}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.controller});
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.sections[DashboardSectionId.charts]?.value;
    if (state == null) return const SizedBox.shrink();
    if (state is! Content<Object?>) return const SizedBox.shrink();
    final data = state.data as EventChartsData;
    final v = data.vendors;
    final r = data.rsvps;
    final vendors = _DonutCard(
      title: 'Vendors',
      icon: Icons.storefront_outlined,
      center: '${v.total}',
      semantics:
          '${v.total} vendors: ${v.booked} booked, ${v.quoted} with a quote, '
          '${v.enquired} enquired, ${v.added} added',
      slices: [
        DonutSlice(
          '${v.booked} booked',
          v.booked.toDouble(),
          AppChartColors.first,
        ),
        DonutSlice(
          '${v.quoted} quoted',
          v.quoted.toDouble(),
          AppChartColors.second,
        ),
        DonutSlice(
          '${v.enquired} enquired',
          v.enquired.toDouble(),
          AppChartColors.third,
        ),
        DonutSlice(
          '${v.added} added',
          v.added.toDouble(),
          AppChartColors.fifth,
        ),
      ],
      onTap: () => EventsNavigation.openEvent(data.event),
    );
    final replies = _DonutCard(
      title: 'Replies',
      icon: Icons.mail_outline,
      center: r == null ? '–' : '${r.guests}',
      semantics: r == null
          ? 'No invitation yet'
          : '${r.guests} guests expected: ${r.attending} coming, '
                '${r.maybe} maybe, ${r.notAttending} not coming',
      slices: r == null
          ? const []
          : [
              DonutSlice(
                '${r.attending} coming',
                r.attending.toDouble(),
                AppChartColors.first,
              ),
              DonutSlice(
                '${r.maybe} maybe',
                r.maybe.toDouble(),
                AppChartColors.second,
              ),
              DonutSlice(
                '${r.notAttending} not coming',
                r.notAttending.toDouble(),
                AppChartColors.third,
              ),
            ],
      emptyNote: r == null ? 'No invitation yet' : null,
      onTap: () => EventsNavigation.openEvent(data.event),
    );
    return _Gap(
      LayoutBuilder(
        builder: (context, box) {
          final narrow =
              box.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          if (narrow) {
            return Column(
              children: [
                vendors,
                const SizedBox(height: AppSpacing.md),
                replies,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: vendors),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: replies),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.title,
    required this.icon,
    required this.center,
    required this.semantics,
    required this.slices,
    required this.onTap,
    this.emptyNote,
  });

  final String title;
  final IconData icon;
  final String center;
  final String semantics;
  final List<DonutSlice> slices;
  final VoidCallback onTap;
  final String? emptyNote;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SectionCard(
      title: title,
      icon: icon,
      child: Column(
        children: [
          DonutChart(
            slices: slices,
            centerText: center,
            semanticsLabel: semantics,
            size: 110,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (emptyNote != null)
            Text(emptyNote!)
          else
            for (final s in slices) LegendDot(color: s.color, label: s.label),
        ],
      ),
    ),
  );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.controller});
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.sections[DashboardSectionId.budget]?.value;
    if (state == null) return const SizedBox.shrink();
    if (state is! Content<Object?> && state is! Failed<Object?>) {
      return const SizedBox.shrink();
    }
    final data = state is Content<Object?>
        ? state.data as BudgetOverviewData
        : null;
    void open() => Get.find<ShellController>().pushInTab(
      ShellTab.events,
      BudgetNavigation.route(
        eventId: data!.event.id,
        eventTitle: data.event.title,
      ),
    );
    final theme = Theme.of(context);
    Widget body() {
      final b = data!.budget;
      final total = b.totalBudget;
      double n(Money? m) => m == null ? 0 : m.minorUnits.toDouble();
      final share = total == null || total.minorUnits == BigInt.zero
          ? null
          : (n(b.spent) / n(total));
      final rows = [
        ('Budget', total?.format() ?? 'Not set', AppChartColors.empty),
        ('Spent', b.spent.format(), AppChartColors.first),
        ('To pay', b.outstanding?.format() ?? '₹0', AppChartColors.second),
      ];
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                for (final (label, value, color) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label, style: theme.textTheme.bodyLarge),
                        ),
                        LegendDot(color: color, label: value),
                      ],
                    ),
                  ),
                if (b.overspentBy != null)
                  Text(
                    'Over budget by ${b.overspentBy!.format()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          DonutChart(
            size: 96,
            centerText: share == null ? '–' : '${(share * 100).round()}%',
            semanticsLabel: share == null
                ? 'No total budget set'
                : '${(share * 100).round()}% of the budget spent',
            slices: share == null
                ? const []
                : [
                    DonutSlice('Spent', n(b.spent), AppChartColors.first),
                    DonutSlice(
                      'To pay',
                      n(b.outstanding),
                      AppChartColors.second,
                    ),
                    DonutSlice('Left', n(b.remaining), AppChartColors.empty),
                  ],
          ),
        ],
      );
    }

    return _Gap(
      SectionCard(
        title: 'Budget',
        icon: Icons.account_balance_wallet_outlined,
        actionLabel: data == null ? null : 'Details',
        onAction: data == null ? null : open,
        child: state is Failed<Object?>
            ? _SectionError(
                state: state,
                onRetry: () =>
                    controller.loadSection(DashboardSectionId.budget),
              )
            : body(),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.controller});
  final HomeController controller;

  void _open({String? categoryId, String? city}) {
    Get.find<ExploreController>().openWith(categoryId: categoryId, city: city);
    Get.find<ShellController>().select(ShellTab.explore);
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.sections[DashboardSectionId.explore]?.value;
    if (state == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final data = state is Content<Object?>
        ? state.data as ExploreSectionData
        : null;
    return _Gap(
      SectionCard(
        title: 'Explore vendors',
        icon: Icons.explore_outlined,
        actionLabel: 'See all',
        onAction: () => _open(city: data?.city),
        child: switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          Failed() => _SectionError(
            state: state,
            onRetry: () => controller.loadSection(DashboardSectionId.explore),
          ),
          _ when data == null => const Text(
            'Find photographers, caterers, decorators and more.',
          ),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.categories.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final category in data.categories.take(6))
                      ActionChip(
                        avatar: Icon(
                          categoryIcon(category.slug),
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(category.name),
                        onPressed: () =>
                            _open(categoryId: category.id, city: data.city),
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
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Text('Vendors will appear here once they join.'),
                ),
            ],
          ),
        },
      ),
    );
  }
}
