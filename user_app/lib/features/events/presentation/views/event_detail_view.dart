import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';
import '../controllers/event_detail_controller.dart';
import '../events_navigation.dart';
import '../widgets/event_status_chip.dart';

/// Event summary and actions (M8). Checklist, budget and vendors join in
/// M9–M11 (event details: M10).
class EventDetailView extends StatelessWidget {
  const EventDetailView({super.key, required this.eventId, this.initial});

  final String eventId;
  final PlannerEvent? initial;

  @override
  Widget build(BuildContext context) => GetBuilder<EventDetailController>(
    init: EventDetailController(
      Get.find<EventsRepository>(),
      eventId,
      initial: initial,
    ),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          Obx(
            () => c.event == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Edit event',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: c.running.value != null
                        ? null
                        : () => _edit(context, c),
                  ),
          ),
        ],
      ),
      body: Obx(
        () => AsyncStateView<PlannerEvent>(
          state: c.state.value,
          onRetry: c.load,
          builder: (context, event) => RefreshIndicator(
            onRefresh: c.load,
            child: _Body(event: event, controller: c),
          ),
        ),
      ),
    ),
  );

  Future<void> _edit(BuildContext context, EventDetailController c) async {
    final updated = await Navigator.of(
      context,
    ).push(EventsNavigation.editRoute(c.event!));
    if (updated != null) c.replace(updated);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.event, required this.controller});

  final PlannerEvent event;
  final EventDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final today = c.today;
    final days = daysBetween(today, event.eventDate);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Semantics(
          header: true,
          child: Text(event.title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EventStatusChip(event.status),
            Text(
              event.eventType,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Row(
          icon: Icons.event_outlined,
          label: 'Date',
          value: [
            formatLongDate(event.eventDate),
            if (event.status == EventStatus.planning) relativeDays(days),
          ].join(' · '),
        ),
        if (event.startTime != null)
          _Row(
            icon: Icons.schedule_outlined,
            label: 'Start time',
            value: formatTimeOfDay(event.startTime!),
          ),
        _Row(
          icon: Icons.location_city_outlined,
          label: 'City',
          value: event.city,
        ),
        if (event.venueName != null)
          _Row(
            icon: Icons.place_outlined,
            label: 'Venue',
            value: event.venueName!,
          ),
        if (event.venueAddress != null)
          _Row(
            icon: Icons.map_outlined,
            label: 'Address',
            value: event.venueAddress!,
          ),
        if (event.guestCountEstimate != null)
          _Row(
            icon: Icons.groups_outlined,
            label: 'Expected guests',
            value: '${event.guestCountEstimate}',
          ),
        _Row(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Total budget',
          value: event.totalBudget?.format() ?? 'Not set',
        ),
        const SizedBox(height: AppSpacing.lg),
        Obx(() {
          final running = c.running.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (event.canComplete)
                _action(
                  context,
                  label: 'Mark as completed',
                  icon: Icons.task_alt,
                  command: EventCommand.complete,
                  running: running,
                  confirm: (
                    'Mark this event as completed?',
                    'You can reopen it later while its date is today or later.',
                    'Mark completed',
                  ),
                  keepLabel: 'Not now',
                ),
              if (event.canReopen(today))
                _action(
                  context,
                  label: 'Reopen event',
                  icon: Icons.replay,
                  command: EventCommand.reopen,
                  running: running,
                ),
              if (event.canCancel)
                _action(
                  context,
                  label: 'Cancel event',
                  icon: Icons.event_busy_outlined,
                  command: EventCommand.cancel,
                  running: running,
                  confirm: (
                    'Cancel this event?',
                    'It moves to Past. You can reopen it while its date is today or later.',
                    'Cancel event',
                  ),
                ),
              if (!event.canReopen(today) &&
                  event.status != EventStatus.planning)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'To reopen this event, edit it and choose today or a later date first.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              _action(
                context,
                label: 'Delete event',
                icon: Icons.delete_outline,
                command: EventCommand.delete,
                running: running,
                destructive: true,
                confirm: (
                  'Delete this event?',
                  'It will be removed from your events. This cannot be undone in the app.',
                  'Delete',
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required String label,
    required IconData icon,
    required EventCommand command,
    required EventCommand? running,
    (String, String, String)? confirm,
    String keepLabel = 'Keep',
    bool destructive = false,
  }) {
    final button = AppButton(
      label: label,
      icon: icon,
      variant: AppButtonVariant.secondary,
      isBusy: running == command,
      onPressed: running != null
          ? null
          : () => _run(
              context,
              command,
              confirm,
              keepLabel: keepLabel,
              destructive: destructive,
            ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: destructive
          ? Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.error,
                ),
              ),
              child: button,
            )
          : button,
    );
  }

  Future<void> _run(
    BuildContext context,
    EventCommand command,
    (String, String, String)? confirm, {
    required String keepLabel,
    required bool destructive,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (confirm != null) {
      final (title, message, action) = confirm;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(keepLabel),
            ),
            TextButton(
              style: destructive
                  ? TextButton.styleFrom(
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                    )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final failure = await controller.run(command);
    if (failure == null) {
      if (command == EventCommand.delete) {
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(_failureText(failure))));
  }

  static String _failureText(Failure failure) => switch (failure) {
    ConflictFailure() =>
      'This event changed in the meantime. Showing the latest version.',
    NotFoundFailure() => 'This event no longer exists.',
    _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  Text(value, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
