import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';

/// Minimal signed-in area (protected route). Full profile arrives in M21.
class AccountView extends StatefulWidget {
  const AccountView({super.key});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  final SessionService _session = Get.find<SessionService>();
  bool _signingOut = false;

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign in again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _signingOut = true);
    try {
      await _session.signOut();
      Get.offAllNamed<void>('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t sign out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My account')),
      body: SafeArea(
        child: Obx(() {
          final state = _session.state.value;
          final profile = state is SignedInSession ? state.profile : null;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Signed in as', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(profile?.label ?? '—', style: theme.textTheme.titleLarge),
              // Second line only when the label is a name/email, not the phone itself.
              if (profile?.phone != null &&
                  profile!.label != profile.phone) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(profile.phone!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Sign out',
                icon: Icons.logout,
                variant: AppButtonVariant.secondary,
                isBusy: _signingOut,
                onPressed: _confirmSignOut,
              ),
            ],
          );
        }),
      ),
    );
  }
}
