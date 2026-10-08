import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/reminder.dart';
import '../controllers/reminder_controllers.dart';
import 'reminder_sheet.dart';

/// Home (M17): reminders that are due now (until phone alerts in M18), and
/// the next upcoming one. Hidden when there is nothing to show.
class DueRemindersBanner extends StatelessWidget {
  const DueRemindersBanner({super.key});

  @override
  Widget build(BuildContext context) => GetBuilder<MyRemindersController>(
    init: MyRemindersController(Get.find<RemindersRepository>(), limit: 1),
    global: false,
    builder: (c) => Obx(() {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final next = c.next;
      if (c.due.isEmpty && next == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in c.due)
              Card(
                color: scheme.tertiaryContainer,
                child: Semantics(
                  liveRegion: true,
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: scheme.onTertiaryContainer,
                    ),
                    title: Text(
                      r.title,
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                    subtitle: Text(
                      'Reminder · ${r.eventTitle}',
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                    trailing: IconButton(
                      tooltip: 'Dismiss reminder ${r.title}',
                      icon: const Icon(Icons.close),
                      onPressed: () => c.dismiss(r),
                    ),
                  ),
                ),
              ),
            if (next != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Next reminder: ${next.title} · '
                        '${formatReminderTime(context, next.remindAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }),
  );
}
