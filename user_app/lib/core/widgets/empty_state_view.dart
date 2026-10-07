import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'centered_scrollable.dart';
import 'session_message.dart';

/// Purposeful empty / placeholder state: icon, title, one line of text and an
/// optional action. Scrolls at large text sizes.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.notice,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Optional message shown above the content (e.g. why the user was signed out).
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) ...[
            SessionMessage(notice!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Icon(icon, size: AppSizes.heroIcon, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
