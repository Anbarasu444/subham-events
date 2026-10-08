import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shell/presentation/controllers/shell_controller.dart';
import '../controllers/push_service.dart';
import '../views/notification_center_view.dart';

/// App-bar bell with the unread count (M18).
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PushService>()) return const SizedBox.shrink();
    final push = Get.find<PushService>();
    return Obx(() {
      final count = push.unread.value;
      return IconButton(
        tooltip: count == 0 ? 'Notifications' : 'Notifications, $count unread',
        onPressed: () {
          final shell = Get.isRegistered<ShellController>()
              ? Get.find<ShellController>()
              : null;
          if (shell != null) {
            shell.pushInTab(
              shell.current.value,
              NotificationCenterView.route(),
            );
          } else {
            Navigator.of(context).push(NotificationCenterView.route());
          }
        },
        icon: Badge.count(
          count: count,
          isLabelVisible: count > 0,
          child: const Icon(Icons.notifications_none),
        ),
      );
    });
  }
}
