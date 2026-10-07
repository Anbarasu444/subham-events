import 'package:flutter/material.dart';

import 'views/checklist_view.dart';

/// Checklist pages are pushed on the current tab's navigator (bottom bar
/// stays): from the event page (My Events tab) or from Menu → Checklist.
abstract final class ChecklistNavigation {
  static Route<void> route({required String eventId, String? eventTitle}) =>
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'checklist-$eventId'),
        builder: (_) => ChecklistView(eventId: eventId, eventTitle: eventTitle),
      );
}
