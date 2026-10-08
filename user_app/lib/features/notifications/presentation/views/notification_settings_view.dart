import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../data/push_messaging.dart';
import '../../domain/app_notification.dart';
import '../controllers/push_service.dart';

/// Menu → Settings → Notifications (M18 answer 5).
class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  final _repository = Get.find<NotificationsRepository>();
  final PushService? _push = Get.isRegistered<PushService>()
      ? Get.find<PushService>()
      : null;
  Map<PushGroup, bool>? _prefs;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final result = await _repository.preferences();
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Ok(:final value):
          _prefs = value;
          _error = null;
        case Err(:final failure):
          _error = failureMessage(failure);
      }
    });
  }

  Future<void> _toggle(PushGroup group, bool on) async {
    final before = _prefs!;
    setState(() => _prefs = {...before, group: on});
    final result = await _repository.setPreference(group, on);
    if (!mounted) return;
    if (result case Err(:final failure)) {
      setState(() => _prefs = before);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage(failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (_push != null)
            Obx(
              () => _push.permission.value == PushPermission.granted
                  ? const SizedBox.shrink()
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _push.permission.value == PushPermission.denied
                                  ? 'Notifications are turned off for this '
                                        'app in your phone’s settings.'
                                  : 'Allow notifications to get reminders and '
                                        'booking updates on this phone.',
                            ),
                            if (_push.permission.value !=
                                PushPermission.denied) ...[
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                label: 'Allow notifications',
                                icon: Icons.notifications_active_outlined,
                                onPressed: _push.requestPermission,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text('Send to this phone', style: theme.textTheme.titleMedium),
          if (_error != null)
            Row(
              children: [
                Expanded(child: Text(_error!)),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            )
          else if (prefs == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final group in PushGroup.values)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(group.label),
                value: prefs[group] ?? true,
                onChanged: (on) => _toggle(group, on),
              ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Booking and payment updates always appear in your notification '
            'list, even when their phone alerts are off.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
