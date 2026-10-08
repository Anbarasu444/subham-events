import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/app_notification.dart';
import '../controllers/notification_center_controller.dart';
import '../controllers/push_service.dart';

/// The Notification Center (M18).
class NotificationCenterView extends StatelessWidget {
  const NotificationCenterView({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterView());

  static IconData _icon(String category) => switch (category) {
    'BOOKING' => Icons.event_available_outlined,
    'PAYMENT' => Icons.receipt_long_outlined,
    'CHECKLIST' => Icons.checklist_outlined,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<NotificationCenterController>(
    init: NotificationCenterController(
      Get.find<NotificationsRepository>(),
      Get.isRegistered<PushService>() ? Get.find<PushService>() : null,
    ),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Obx(() {
            final state = c.state.value;
            final anyUnread =
                state is Content<List<AppNotification>> &&
                state.data.any((n) => !n.isRead);
            // An icon keeps the app bar readable at large text sizes.
            return IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(Icons.done_all),
              onPressed: anyUnread
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final failure = await c.markAllRead();
                      if (failure != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(failureMessage(failure))),
                        );
                      }
                    }
                  : null,
            );
          }),
        ],
      ),
      body: Obx(() {
        final state = c.state.value;
        if (state is Empty<List<AppNotification>>) {
          return const EmptyStateView(
            icon: Icons.notifications_none,
            title: 'No notifications yet',
            message: 'Quotes, bookings and reminders will show up here.',
          );
        }
        return AsyncStateView<List<AppNotification>>(
          state: state,
          onRetry: c.load,
          builder: (context, items) => NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 600) c.loadMore();
              return false;
            },
            child: RefreshIndicator(
              onRefresh: c.load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    return Obx(
                      () => Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: c.loadingMore.value
                              ? const CircularProgressIndicator(
                                  semanticsLabel: 'Loading more',
                                )
                              : c.loadMoreFailure.value != null
                              ? TextButton(
                                  onPressed: c.loadMore,
                                  child: const Text(
                                    'Could not load more. Try again',
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    );
                  }
                  final n = items[index];
                  final theme = Theme.of(context);
                  return ListTile(
                    leading: Icon(_icon(n.category)),
                    title: Text(
                      n.title,
                      style: n.isRead
                          ? null
                          : const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${n.body}\n${formatLongDate(n.createdAt)} · '
                      '${TimeOfDay.fromDateTime(n.createdAt).format(context)}',
                    ),
                    isThreeLine: true,
                    trailing: n.isRead
                        ? null
                        : Semantics(
                            label: 'Unread',
                            child: Container(
                              key: const ValueKey('unread-dot'),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                    onTap: () => c.open(n),
                  );
                },
              ),
            ),
          ),
        );
      }),
    ),
  );
}
