import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../controllers/profile_controller.dart';

/// Explains what deleting does and asks the user to type DELETE (M21).
class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({super.key, required this.controller});

  final ProfileController controller;

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _typed => _confirm.text.trim() == 'DELETE';

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final message = await widget.controller.deleteAccount();
    if (!mounted) return;
    if (message == null) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _busy = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            'When you delete your account:',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          point(
            Icons.event_busy_outlined,
            'Events you are still planning are cancelled, and their reminders '
            'stop.',
          ),
          point(
            Icons.handshake_outlined,
            'Confirmed bookings are cancelled with the reason “Account '
            'deleted”, and the vendors are told.',
          ),
          point(Icons.link_off, 'Invitation links stop working.'),
          point(
            Icons.logout,
            'You are signed out on all your devices and stop getting '
            'notifications.',
          ),
          point(
            Icons.restore,
            'Your details are kept. If you sign in again with the same '
            'account, it is restored — but cancelled events and bookings '
            'stay cancelled.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _confirm,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _typed && !_busy ? _delete : null,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_remove_outlined),
            label: const Text('Delete my account'),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Keep my account',
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
