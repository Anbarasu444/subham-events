import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';
import '../controllers/event_form_controller.dart';
import '../events_navigation.dart';

/// Create or edit an event. Required: type, title, date, city (M8 answer 3).
class EventFormView extends StatelessWidget {
  const EventFormView({super.key, this.existing});

  final PlannerEvent? existing;

  @override
  Widget build(BuildContext context) => GetBuilder<EventFormController>(
    init: EventFormController(Get.find<EventsRepository>(), existing: existing),
    global: false,
    builder: (c) => PopScope<PlannerEvent>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c.saving.value) return; // stay while saving
        final navigator = Navigator.of(context);
        if (!c.isDirty || await _confirmDiscard(context)) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(c.isEdit ? 'Edit event' : 'New event')),
        body: SafeArea(
          child: ListView(
            controller: c.scroll,
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _field(
                c,
                'eventType',
                (error) => AppTextField(
                  label: 'Event type',
                  hintText: 'e.g. Wedding, Birthday, Pooja',
                  controller: c.eventType,
                  errorText: error,
                  maxLength: 60,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => c.clearError('eventType'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final type in EventFormController.typeSuggestions)
                    ActionChip(
                      label: Text(type),
                      onPressed: () => c.pickType(type),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                c,
                'title',
                (error) => AppTextField(
                  label: 'Title',
                  hintText: 'e.g. Asha & Ravi’s wedding',
                  controller: c.title,
                  errorText: error,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => c.clearError('title'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              KeyedSubtree(
                key: c.fieldKeys['eventDate'],
                child: Obx(
                  () => _PickerField(
                    label: 'Date',
                    value: c.eventDate.value == null
                        ? null
                        : formatLongDate(c.eventDate.value!),
                    placeholder: 'Choose a date',
                    icon: Icons.event_outlined,
                    errorText: c.fieldErrors['eventDate'],
                    onTap: () => _pickDate(context, c),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              KeyedSubtree(
                key: c.fieldKeys['startTime'],
                child: Obx(
                  () => _PickerField(
                    label: 'Start time (optional)',
                    value: c.startTime.value == null
                        ? null
                        : formatTimeOfDay(c.startTime.value!),
                    placeholder: 'Add a start time',
                    icon: Icons.schedule_outlined,
                    errorText: c.fieldErrors['startTime'],
                    onTap: () => _pickTime(context, c),
                    onClear: c.startTime.value == null
                        ? null
                        : () => c.startTime.value = null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                c,
                'city',
                (error) => AppTextField(
                  label: 'City',
                  controller: c.city,
                  errorText: error,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => c.clearError('city'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                c,
                'venueName',
                (error) => AppTextField(
                  label: 'Venue (optional)',
                  controller: c.venueName,
                  errorText: error,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => c.clearError('venueName'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                c,
                'venueAddress',
                (error) => AppTextField(
                  label: 'Venue address (optional)',
                  controller: c.venueAddress,
                  errorText: error,
                  maxLength: 300,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => c.clearError('venueAddress'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                c,
                'guestCountEstimate',
                (error) => AppTextField(
                  label: 'Expected guests (optional)',
                  controller: c.guests,
                  errorText: error,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => c.clearError('guestCountEstimate'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                c,
                'totalBudget',
                (error) => AppTextField(
                  label: 'Total budget (optional)',
                  hintText: 'e.g. 500000',
                  prefixText: '₹ ',
                  controller: c.budget,
                  errorText: error,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  maxLength: 16,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(context, c),
                  onChanged: (_) => c.clearError('totalBudget'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Obx(
                () => c.formError.value == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
              Obx(
                () => AppButton(
                  label: c.isEdit ? 'Save changes' : 'Create event',
                  icon: Icons.check,
                  isBusy: c.saving.value,
                  onPressed: () => _save(context, c),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _field(
    EventFormController c,
    String name,
    Widget Function(String? error) builder,
  ) => KeyedSubtree(
    key: c.fieldKeys[name],
    child: Obx(() => builder(c.fieldErrors[name])),
  );

  Future<void> _save(BuildContext context, EventFormController c) async {
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await c.submit();
    if (saved == null) {
      await _revealProblem(c);
      return;
    }
    if (c.isEdit) {
      navigator.pop(saved);
      messenger.showSnackBar(const SnackBar(content: Text('Changes saved')));
    } else {
      // Not awaited: the future completes only when the new page closes.
      unawaited(navigator.pushReplacement(EventsNavigation.detailRoute(saved)));
      messenger.showSnackBar(const SnackBar(content: Text('Event created')));
    }
  }

  /// Scrolls to the first invalid field, or to the form error above the
  /// button when only that is shown.
  Future<void> _revealProblem(EventFormController c) async {
    if (!c.scroll.hasClients) return;
    final field = c.firstErrorField;
    if (field == null) {
      if (c.formError.value != null) {
        await c.scroll.animateTo(
          c.scroll.position.maxScrollExtent,
          duration: AppDurations.medium,
          curve: Curves.easeOut,
        );
      }
      return;
    }
    // Fields far above the viewport may not be built yet (lazy list).
    if (c.fieldKeys[field]?.currentContext == null) {
      c.scroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
    }
    final target = c.fieldKeys[field]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        duration: AppDurations.medium,
        alignment: 0.1,
      );
    }
  }

  Future<void> _pickDate(BuildContext context, EventFormController c) async {
    final first = c.firstDate;
    final current = c.eventDate.value;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first)
          ? current
          : first,
      firstDate: first,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Event date',
    );
    if (picked != null) {
      c.eventDate.value = dateOnly(picked);
      c.clearError('eventDate');
    }
  }

  Future<void> _pickTime(BuildContext context, EventFormController c) async {
    final current = c.startTime.value;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay(
              hour: int.parse(current.substring(0, 2)),
              minute: int.parse(current.substring(3, 5)),
            ),
      helpText: 'Start time',
    );
    if (picked != null) {
      c.startTime.value =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      c.clearError('startTime');
    }
  }

  static Future<bool> _confirmDiscard(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your changes to this event will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Read-only field that opens a picker; looks like a text field.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    this.errorText,
    this.onClear,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Label and value are read from the decorator; the clear button stays
    // reachable for screen readers.
    return Semantics(
      button: true,
      label: '$label, ${value ?? placeholder}',
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadii.sm),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            prefixIcon: Icon(icon),
            suffixIcon: onClear == null
                ? null
                : IconButton(
                    tooltip: 'Clear $label',
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
          ),
          child: ExcludeSemantics(
            child: Text(
              value ?? placeholder,
              style: value == null
                  ? theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
