import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../../events/presentation/controllers/planning_event_picker_controller.dart';
import '../../../events/presentation/events_navigation.dart';
import '../../../explore/domain/listing.dart';
import '../../domain/event_vendor.dart';

/// "Add to event" from a listing (M14): picks a planning event (one event →
/// added directly) and reports the result with Undo.
Future<void> addListingToEvent(
  BuildContext context,
  ListingCard listing,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final picker = PlanningEventPickerController(Get.find<EventsRepository>());
  await picker.load();
  if (!context.mounted) return;
  final state = picker.state.value;
  final PlannerEvent? event;
  if (state case Content(:final data) when data.length == 1) {
    event = data.single;
  } else if (state case Content(:final data)) {
    event = await showModalBottomSheet<PlannerEvent>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _EventChoice(events: data),
    );
  } else if (state is Empty<List<PlannerEvent>>) {
    event = await _noEvents(context);
  } else if (state case Failed(:final failure)) {
    event = _fail(messenger, failure);
  } else {
    event = null;
  }
  if (event == null) return;
  final chosen = event;
  final repo = Get.find<EventVendorsRepository>();
  final result = await repo.add(chosen.id, listing.id);
  switch (result) {
    case Ok(:final value):
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Added to ${chosen.title}.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => repo.remove(chosen.id, value.id),
            ),
          ),
        );
    case Err(:final failure):
      _fail(messenger, failure);
  }
}

PlannerEvent? _fail(ScaffoldMessengerState messenger, Failure failure) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(switch (failure) {
          ConflictFailure(code: 'LIMIT_REACHED') =>
            'This event already has 100 vendors.',
          ForbiddenFailure() => 'You cannot add your own listing.',
          NotFoundFailure() => 'This vendor is no longer listed.',
          _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
        }),
      ),
    );
  return null;
}

Future<PlannerEvent?> _noEvents(BuildContext context) async {
  final create = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('No events being planned'),
      content: const Text('Create an event first, then add vendors to it.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Create event'),
        ),
      ],
    ),
  );
  if (create ?? false) EventsNavigation.startCreate();
  return null;
}

class _EventChoice extends StatelessWidget {
  const _EventChoice({required this.events});

  final List<PlannerEvent> events;

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Semantics(
          header: true,
          child: Text(
            'Add to which event?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      for (final event in events)
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: Text(event.title),
          subtitle: Text('${formatLongDate(event.eventDate)} · ${event.city}'),
          onTap: () => Navigator.of(context).pop(event),
        ),
    ],
  );
}
