import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/reminder.dart';
import '../controllers/reminder_controllers.dart';

/// A task a reminder can be linked to.
typedef ReminderTask = ({String id, String title});

/// "Sat, 7 Nov 2026 · 6:00 PM".
String formatReminderTime(BuildContext context, DateTime at) =>
    '${formatLongDate(at)} · ${TimeOfDay.fromDateTime(at).format(context)}';

/// Add or edit a reminder; returns the saved one, or null if closed.
Future<Reminder?> showReminderSheet(
  BuildContext context, {
  required String eventId,
  List<ReminderTask> tasks = const [],
  Reminder? existing,
  String? title,
  DateTime? at,
  String? taskId,
}) => showModalBottomSheet<Reminder>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _ReminderSheet(
    eventId: eventId,
    tasks: tasks,
    existing: existing,
    title: title,
    at: at,
    taskId: taskId,
  ),
);

class _ReminderSheet extends StatelessWidget {
  const _ReminderSheet({
    required this.eventId,
    required this.tasks,
    this.existing,
    this.title,
    this.at,
    this.taskId,
  });

  final String eventId;
  final List<ReminderTask> tasks;
  final Reminder? existing;
  final String? title;
  final DateTime? at;
  final String? taskId;

  @override
  Widget build(BuildContext context) => GetBuilder<ReminderFormController>(
    init: ReminderFormController(
      Get.find<RemindersRepository>(),
      eventId,
      existing: existing,
      title: title,
      at: at,
      taskId: taskId,
    ),
    global: false,
    builder: (c) {
      final theme = Theme.of(context);
      // A linked task that is no longer listed stays selectable.
      final options = [
        ...tasks,
        if (c.taskId.value != null && !tasks.any((t) => t.id == c.taskId.value))
          (id: c.taskId.value!, title: existing?.checklistItemTitle ?? 'Task'),
      ];
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  c.isEdit ? 'Edit reminder' : 'New reminder',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => TextField(
                  controller: c.title,
                  autofocus: !c.isEdit && (title ?? '').isEmpty,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => c.titleError.value = null,
                  decoration: InputDecoration(
                    labelText: 'Remind me to…',
                    hintText: 'e.g. Call the caterer',
                    errorText: c.titleError.value,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: c.day.value.isBefore(dateOnly(now))
                              ? dateOnly(now)
                              : c.day.value,
                          firstDate: dateOnly(now),
                          lastDate: DateTime(2100, 12, 31),
                          helpText: 'Reminder date',
                        );
                        if (picked != null) {
                          c.day.value = dateOnly(picked);
                          c.timeError.value = null;
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(formatLongDate(c.day.value)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: c.time.value,
                          helpText: 'Reminder time',
                        );
                        if (picked != null) {
                          c.time.value = picked;
                          c.timeError.value = null;
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(c.time.value.format(context)),
                    ),
                  ],
                ),
              ),
              Obx(
                () => c.timeError.value == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          c.timeError.value!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
              ),
              if (options.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => DropdownButtonFormField<String?>(
                    initialValue: c.taskId.value,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'For task (optional)',
                      prefixIcon: Icon(Icons.checklist_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('No task')),
                      for (final task in options)
                        DropdownMenuItem<String?>(
                          value: task.id,
                          child: Text(
                            task.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => c.taskId.value = value,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You’ll see it in the app at that time. Phone alerts arrive '
                'with a later update.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Obx(
                () => c.formError.value == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            c.formError.value!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => AppButton(
                  label: c.isEdit ? 'Save reminder' : 'Add reminder',
                  icon: Icons.notifications_active_outlined,
                  isBusy: c.saving.value,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final saved = await c.submit();
                    if (saved != null) navigator.pop(saved);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
