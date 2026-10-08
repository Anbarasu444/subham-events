import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/reminder.dart';
import '../controllers/reminder_controllers.dart';
import '../widgets/reminder_sheet.dart';

/// Menu → Schedule (M17 answer 4): all upcoming reminders, soonest first.
class ScheduleView extends StatelessWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) => GetBuilder<MyRemindersController>(
    init: MyRemindersController(Get.find<RemindersRepository>()),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: Obx(() {
        final state = c.upcoming.value;
        if (state is Empty<List<Reminder>>) {
          return const EmptyStateView(
            icon: Icons.notifications_none,
            title: 'No upcoming reminders',
            message:
                'Open an event and add reminders in its Overview, or use '
                '“Remind me” on a checklist task.',
          );
        }
        return AsyncStateView<List<Reminder>>(
          state: state,
          onRetry: c.load,
          builder: (context, reminders) => RefreshIndicator(
            onRefresh: c.load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: reminders.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = reminders[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_none),
                  title: Text(r.title),
                  subtitle: Text(
                    '${formatReminderTime(context, r.remindAt)}\n${r.eventTitle}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
          ),
        );
      }),
    ),
  );
}
