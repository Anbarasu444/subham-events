import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shell/presentation/controllers/shell_controller.dart';
import '../../shell/presentation/controllers/shell_tab.dart';
import '../domain/entities/planner_event.dart';
import 'views/event_detail_view.dart';
import 'views/event_form_view.dart';

/// Event pages live in the My Events tab's navigator (bottom bar stays).
abstract final class EventsNavigation {
  /// New-event form; after saving it is replaced by the event's page.
  static Route<void> createRoute() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'event-create'),
    builder: (_) => const EventFormView(),
  );

  static Route<void> detailRoute(PlannerEvent event) => MaterialPageRoute<void>(
    settings: RouteSettings(name: 'event-${event.id}'),
    builder: (_) => EventDetailView(eventId: event.id, initial: event),
  );

  static Route<PlannerEvent> editRoute(PlannerEvent event) =>
      MaterialPageRoute<PlannerEvent>(
        settings: RouteSettings(name: 'event-edit-${event.id}'),
        builder: (_) => EventFormView(existing: event),
      );

  /// From anywhere (e.g. Home): open My Events and start a new event.
  static void startCreate() =>
      Get.find<ShellController>().pushInTab(ShellTab.events, createRoute());

  static void openEvent(PlannerEvent event) => Get.find<ShellController>()
      .pushInTab(ShellTab.events, detailRoute(event));
}
