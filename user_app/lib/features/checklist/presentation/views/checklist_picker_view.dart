import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../../events/presentation/events_navigation.dart';
import '../checklist_navigation.dart';
import '../controllers/checklist_picker_controller.dart';
import '../widgets/checklist_progress.dart';

/// Menu → Checklist: pick an event being planned; with exactly one event its
/// checklist opens straight away (M9 answer 4).
class ChecklistPickerView extends StatelessWidget {
  const ChecklistPickerView({super.key});

  @override
  Widget build(BuildContext context) => GetBuilder<ChecklistPickerController>(
    init: ChecklistPickerController(Get.find<EventsRepository>()),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(title: const Text('Checklist')),
      body: Obx(() {
        final state = c.state.value;
        if (state is Content<List<PlannerEvent>> && state.data.length == 1) {
          // Only once, even if this rebuilds before the next frame.
          if (!c.openedOnlyEvent) {
            c.openedOnlyEvent = true;
            _openOnly(context, state.data.single);
          }
          return const Center(child: CircularProgressIndicator());
        }
        if (state is Empty<List<PlannerEvent>>) {
          return EmptyStateView(
            icon: Icons.checklist_outlined,
            title: 'No events being planned',
            message: 'Create an event to start its checklist.',
            action: AppButton(
              label: 'Create event',
              icon: Icons.add,
              onPressed: EventsNavigation.startCreate,
            ),
          );
        }
        return AsyncStateView<List<PlannerEvent>>(
          state: state,
          onRetry: c.load,
          builder: (context, events) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.page),
            itemCount: events.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Choose an event',
                  style: Theme.of(context).textTheme.titleMedium,
                );
              }
              final event = events[index - 1];
              return Card(
                clipBehavior: Clip.antiAlias,
                // One screen-reader stop per event.
                child: MergeSemantics(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      ChecklistNavigation.route(
                        eventId: event.id,
                        eventTitle: event.title,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(formatLongDate(event.eventDate)),
                          const SizedBox(height: AppSpacing.xs),
                          ChecklistProgress(summary: event.checklist),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
    ),
  );

  /// Replaces the picker with the only event's checklist after this frame.
  static void _openOnly(BuildContext context, PlannerEvent event) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        ChecklistNavigation.route(eventId: event.id, eventTitle: event.title),
      );
    });
  }
}
