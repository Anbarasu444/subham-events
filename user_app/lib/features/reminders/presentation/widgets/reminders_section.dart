import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/reminder.dart';
import '../controllers/reminder_controllers.dart';
import 'reminder_sheet.dart';

/// The event Overview's Reminders card (M17 answer 3).
class RemindersSection extends StatelessWidget {
  const RemindersSection({
    super.key,
    required this.eventId,
    required this.tasks,
  });

  final String eventId;

  /// Pending tasks a reminder can be linked to.
  final List<ReminderTask> tasks;

  Future<void> _add(BuildContext context, EventRemindersController c) async {
    final saved = await showReminderSheet(
      context,
      eventId: eventId,
      tasks: tasks,
    );
    if (saved == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder set for ${formatReminderTime(context, saved.remindAt)}.',
        ),
      ),
    );
    await c.load();
  }

  Future<void> _cancel(
    BuildContext context,
    EventRemindersController c,
    Reminder reminder,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cancel this reminder?'),
            content: Text(reminder.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cancel reminder'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final failure = await c.cancel(reminder);
    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<EventRemindersController>(
    init: EventRemindersController(Get.find<RemindersRepository>(), eventId),
    global: false,
    builder: (c) => Obx(() {
      final theme = Theme.of(context);
      final state = c.state.value;
      final data = switch (state) {
        Content(:final data) => data,
        _ => null,
      };
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Reminders',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (data?.isEditable ?? false)
                    TextButton.icon(
                      key: const ValueKey('add-reminder'),
                      onPressed: () => _add(context, c),
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('Add'),
                    ),
                ],
              ),
              switch (state) {
                Loading() => const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading reminders',
                    ),
                  ),
                ),
                Failed(:final failure) => Row(
                  children: [
                    Expanded(child: Text(failureMessage(failure))),
                    if (failure.isRetryable)
                      TextButton(
                        onPressed: c.load,
                        child: const Text('Try again'),
                      ),
                  ],
                ),
                _ when data!.upcoming.isEmpty => Text(
                  data.isEditable
                      ? 'No reminders yet. Add one so you don’t forget a call '
                            'or a payment.'
                      : 'No upcoming reminders.',
                  style: theme.textTheme.bodyMedium,
                ),
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in data.upcoming)
                      _ReminderTile(
                        reminder: r,
                        editable: data.isEditable,
                        busy: c.busy.contains(r.id),
                        onEdit: () async {
                          final saved = await showReminderSheet(
                            context,
                            eventId: eventId,
                            tasks: tasks,
                            existing: r,
                          );
                          if (saved != null) await c.load();
                        },
                        onCancel: () => _cancel(context, c, r),
                      ),
                  ],
                ),
              },
            ],
          ),
        ),
      );
    }),
  );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.editable,
    required this.busy,
    required this.onEdit,
    required this.onCancel,
  });

  final Reminder reminder;
  final bool editable;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: editable && !busy ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            const Icon(Icons.notifications_none),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reminder.title, style: theme.textTheme.bodyLarge),
                    Text(
                      [
                        formatReminderTime(context, reminder.remindAt),
                        if (reminder.checklistItemTitle != null)
                          'for “${reminder.checklistItemTitle}”',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (editable)
              IconButton(
                tooltip: 'Cancel reminder ${reminder.title}',
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
          ],
        ),
      ),
    );
  }
}
