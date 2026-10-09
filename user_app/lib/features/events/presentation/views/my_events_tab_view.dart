import 'package:flutter/material.dart';
import '../../../../core/assets/app_illustrations.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';
import '../controllers/my_events_controller.dart';
import '../events_navigation.dart';
import '../widgets/event_card.dart';

/// My Events tab: guests see a sign-in prompt (M6 decision); signed-in users
/// see their upcoming and past events (M8).
class MyEventsTabView extends StatelessWidget {
  const MyEventsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    return Obx(
      () => switch (session.state.value) {
        SignedInSession() => const _SignedInEvents(),
        final state => Scaffold(
          appBar: AppBar(title: const Text('My Events')),
          body: switch (state) {
            GuestSession(message: final reason) => EmptyStateView(
              icon: Icons.event_note_outlined,
              illustration: AppIllustrations.signInSecure,
              title: 'Plan your events',
              message:
                  'Sign in to create events and keep everything in one place.',
              notice: reason,
              action: AppButton(
                label: 'Sign in',
                icon: Icons.login,
                onPressed: () => Get.toNamed<void>(
                  AppRoutes.signIn,
                  parameters: {'returnTo': AppRoutes.tab(ShellTab.events)},
                ),
              ),
            ),
            ProfilePendingSession() => EmptyStateView(
              icon: Icons.cloud_off_outlined,
              title: 'Couldn’t reach the server',
              message: 'You are still signed in. Try again in a moment.',
              action: AppButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: session.retry,
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      },
    );
  }
}

class _SignedInEvents extends GetView<MyEventsController> {
  const _SignedInEvents();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Events')),
    // Hidden while the Upcoming empty state shows its own create button.
    floatingActionButton: Obx(
      () =>
          controller.scope.value == EventScope.upcoming &&
              controller.lists[EventScope.upcoming]!.state.value
                  is Empty<List<PlannerEvent>>
          ? const SizedBox.shrink()
          : FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).push(EventsNavigation.createRoute()),
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xs,
          ),
          child: Obx(
            () => SizedBox(
              width: double.infinity,
              child: SegmentedButton<EventScope>(
                segments: const [
                  ButtonSegment(
                    value: EventScope.upcoming,
                    label: Text('Upcoming'),
                  ),
                  ButtonSegment(value: EventScope.past, label: Text('Past')),
                ],
                selected: {controller.scope.value},
                showSelectedIcon: false,
                onSelectionChanged: (s) => controller.selectScope(s.first),
              ),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            final scope = controller.scope.value;
            // Each scope keeps its own list widget and scroll position.
            return IndexedStack(
              index: scope == EventScope.upcoming ? 0 : 1,
              children: const [
                _EventList(scope: EventScope.upcoming),
                _EventList(scope: EventScope.past),
              ],
            );
          }),
        ),
      ],
    ),
  );
}

class _EventList extends GetView<MyEventsController> {
  const _EventList({required this.scope});

  final EventScope scope;

  @override
  Widget build(BuildContext context) {
    final list = controller.lists[scope]!;
    return Obx(() {
      final state = list.state.value;
      if (state is Empty<List<PlannerEvent>>) {
        return RefreshIndicator(
          onRefresh: () => controller.load(scope),
          child: scope == EventScope.upcoming
              ? EmptyStateView(
                  icon: Icons.event_available_outlined,
                  illustration: AppIllustrations.emptyEvents,
                  title: 'No upcoming events',
                  message: 'Create an event to start planning.',
                  action: AppButton(
                    label: 'Create event',
                    icon: Icons.add,
                    onPressed: () => Navigator.of(
                      context,
                    ).push(EventsNavigation.createRoute()),
                  ),
                )
              : const EmptyStateView(
                  icon: Icons.history,
                  illustration: AppIllustrations.emptyEvents,
                  title: 'No past events',
                  message: 'Completed and cancelled events appear here.',
                ),
        );
      }
      return AsyncStateView<List<PlannerEvent>>(
        state: state,
        onRetry: () => controller.load(scope),
        builder: (context, events) => RefreshIndicator(
          onRefresh: () => controller.load(scope),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // After a failed page the footer's "Try again" retries; the
              // scroll position alone must not keep re-sending the request.
              if (n.metrics.extentAfter < 400 && list.moreError.value == null) {
                controller.loadMore(scope);
              }
              return false;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              // Room for the floating button over the last card.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                96,
              ),
              itemCount: events.length + 1,
              itemBuilder: (context, index) {
                if (index == events.length) {
                  return _ListFooter(list: list, scope: scope);
                }
                final event = events[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: EventCard(
                    event: event,
                    today: dateOnly(DateTime.now()),
                    onTap: () => Navigator.of(
                      context,
                    ).push(EventsNavigation.detailRoute(event)),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }
}

class _ListFooter extends GetView<MyEventsController> {
  const _ListFooter({required this.list, required this.scope});

  final EventListState list;
  final EventScope scope;

  @override
  Widget build(BuildContext context) => Obx(() {
    if (list.loadingMore.value) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = list.moreError.value;
    if (error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: () => controller.loadMore(scope),
          icon: const Icon(Icons.refresh),
          label: Text('${failureTitle(error)} · Try again'),
        ),
      );
    }
    return const SizedBox.shrink();
  });
}
