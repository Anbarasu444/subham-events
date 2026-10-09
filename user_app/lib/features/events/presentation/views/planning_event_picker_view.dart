import 'package:flutter/material.dart';
import '../../../../core/assets/app_illustrations.dart';
import 'package:get/get.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';
import '../events_navigation.dart';
import '../controllers/planning_event_picker_controller.dart';

/// Menu → Checklist / Budget: pick an event being planned; with exactly one
/// event its page opens straight away (M9 answer 4, M11).
class PlanningEventPickerView extends StatelessWidget {
  const PlanningEventPickerView({
    super.key,
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.routeFor,
    this.detailBuilder,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;

  /// The page to open for an event (pushed on the Menu tab's navigator).
  final Route<void> Function(PlannerEvent event) routeFor;

  /// Extra line(s) under each event, e.g. checklist progress.
  final Widget Function(PlannerEvent event)? detailBuilder;

  @override
  Widget build(BuildContext context) =>
      GetBuilder<PlanningEventPickerController>(
        init: PlanningEventPickerController(Get.find<EventsRepository>()),
        global: false,
        builder: (c) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Obx(() {
            final state = c.state.value;
            if (state is Content<List<PlannerEvent>> &&
                state.data.length == 1) {
              // Only once, even if this rebuilds before the next frame.
              if (!c.openedOnlyEvent) {
                c.openedOnlyEvent = true;
                _openOnly(context, state.data.single);
              }
              return const Center(child: CircularProgressIndicator());
            }
            if (state is Empty<List<PlannerEvent>>) {
              return EmptyStateView(
                icon: icon,
                illustration: AppIllustrations.emptyEvents,
                title: 'No events being planned',
                message: emptyMessage,
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
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Semantics(
                      header: true,
                      child: Text(
                        'Choose an event',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }
                  final event = events[index - 1];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    // One screen-reader stop per event.
                    child: MergeSemantics(
                      child: InkWell(
                        onTap: () =>
                            Navigator.of(context).push(routeFor(event)),
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
                              ?detailBuilder?.call(event),
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

  /// Replaces the picker with the only event's page after this frame.
  void _openOnly(BuildContext context, PlannerEvent event) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(routeFor(event));
    });
  }
}
