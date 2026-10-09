import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/platform/external_actions.dart';
import '../../../../core/theme/tokens.dart';

const _faqs = [
  (
    'How do I plan an event?',
    'Open Events, tap “New event” and add the date, city and budget. Each '
        'event has its own checklist, budget, vendors, reminders and '
        'invitation.',
  ),
  (
    'How do I find and book a vendor?',
    'Browse Explore, add a vendor to your event and send an enquiry. When '
        'the vendor sends a quote, accept it to book them at that amount.',
  ),
  (
    'Are payments made in the app?',
    'No. “Payments” is your private record of what you paid a vendor, so '
        'you can track balances. Money is never sent through the app.',
  ),
  (
    'How do invitations work?',
    'Design an invitation on the event’s Overview, publish it and share the '
        'link or picture. Guests reply in their browser without the app.',
  ),
  (
    'How do I manage notifications?',
    'Go to Menu → Settings → Notifications to choose which phone '
        'notifications you get. Everything still appears in the bell.',
  ),
  (
    'Can I restore a deleted account?',
    'Yes. Sign in again with the same Google account or phone number. '
        'Cancelled events and bookings stay cancelled.',
  ),
];

/// Menu → Help (M21): FAQs, contact, version, legal.
class HelpView extends StatelessWidget {
  const HelpView({super.key});

  ExternalActions get _external => Get.isRegistered<ExternalActions>()
      ? Get.find<ExternalActions>()
      : const PlatformExternalActions();

  AppConfig? get _config =>
      Get.isRegistered<AppConfig>() ? Get.find<AppConfig>() : null;

  Future<void> _open(BuildContext context, Future<bool> action) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await action) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No app on this phone can open this.')),
      );
    }
  }

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _config;
    final email = config?.supportEmail ?? AppConfig.defaultSupportEmail;
    final phone = config?.supportPhone ?? AppConfig.defaultSupportPhone;
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Semantics(
              header: true,
              child: Text(
                'Frequently asked questions',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          for (final (q, a) in _faqs)
            ExpansionTile(
              title: Text(q),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              expandedAlignment: Alignment.centerLeft,
              children: [Text(a)],
            ),
          const Divider(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Semantics(
              header: true,
              child: Text('Contact us', style: theme.textTheme.titleMedium),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email support'),
            subtitle: Text(email),
            onTap: () => _open(
              context,
              _external.email(email, subject: 'Event Planner help'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Call support'),
            subtitle: Text(phone),
            onTap: () => _open(context, _external.call(phone)),
          ),
          const Divider(height: AppSpacing.lg),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of use'),
            subtitle: const Text('Coming soon'),
            onTap: () => _comingSoon(context, 'Terms of use'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            subtitle: const Text('Coming soon'),
            onTap: () => _comingSoon(context, 'The privacy policy'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text(
              config == null
                  ? '–'
                  : '${config.appVersion} (${config.buildNumber})',
            ),
          ),
        ],
      ),
    );
  }
}
