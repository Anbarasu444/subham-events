import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/repositories/checklist_repository.dart';
import '../controllers/checklist_item_form_controller.dart';

/// Opens the add/edit sheet; returns the saved item, or null if closed.
Future<ChecklistItem?> showChecklistItemSheet(
  BuildContext context, {
  required String eventId,
  ChecklistItem? existing,
}) => showModalBottomSheet<ChecklistItem>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => ChecklistItemSheet(eventId: eventId, existing: existing),
);

class ChecklistItemSheet extends StatelessWidget {
  const ChecklistItemSheet({super.key, required this.eventId, this.existing});

  final String eventId;
  final ChecklistItem? existing;

  @override
  Widget build(BuildContext context) => GetBuilder<ChecklistItemFormController>(
    init: ChecklistItemFormController(
      Get.find<ChecklistRepository>(),
      eventId,
      existing: existing,
    ),
    global: false,
    builder: (c) => Padding(
      // Keep the fields above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                c.isEdit ? 'Edit task' : 'New task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => TextField(
                controller: c.title,
                autofocus: !c.isEdit,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => c.titleError.value = null,
                decoration: InputDecoration(
                  labelText: 'Task',
                  hintText: 'e.g. Book the photographer',
                  errorText: c.titleError.value,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(() {
              final due = c.dueDate.value;
              return Semantics(
                button: true,
                label: due == null
                    ? 'Due date, not set'
                    : 'Due date, ${formatLongDate(due)}',
                child: InkWell(
                  borderRadius: const BorderRadius.all(AppRadii.sm),
                  onTap: () => _pickDate(context, c),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due date (optional)',
                      prefixIcon: const Icon(Icons.event_outlined),
                      suffixIcon: due == null
                          ? null
                          : IconButton(
                              tooltip: 'Clear due date',
                              icon: const Icon(Icons.close),
                              onPressed: () => c.dueDate.value = null,
                            ),
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        due == null ? 'No due date' : formatLongDate(due),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => TextField(
                controller: c.notes,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => c.notesError.value = null,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  errorText: c.notesError.value,
                  alignLabelWithHint: true,
                ),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => AppButton(
                label: c.isEdit ? 'Save task' : 'Add task',
                icon: Icons.check,
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
    ),
  );

  Future<void> _pickDate(
    BuildContext context,
    ChecklistItemFormController c,
  ) async {
    final now = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: c.dueDate.value ?? now,
      // Past dates are allowed: the task then shows as overdue.
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Due date',
    );
    if (picked != null) c.dueDate.value = dateOnly(picked);
  }
}
