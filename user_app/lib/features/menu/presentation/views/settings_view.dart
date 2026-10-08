import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/auth/session_service.dart';
import '../../../notifications/domain/app_notification.dart';
import '../../../notifications/presentation/views/notification_settings_view.dart';

/// Menu → Settings (M18: Notifications; more settings in later milestones).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = Get.find<SessionService>().isSignedIn;
    final canManage = signedIn && Get.isRegistered<NotificationsRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: Text(
              canManage
                  ? 'Choose what reaches this phone'
                  : 'Sign in to manage notifications',
            ),
            enabled: canManage,
            onTap: canManage
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsView(),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
