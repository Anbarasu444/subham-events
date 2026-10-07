import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Explains why the user was signed out (suspended, deleted, revoked).
class SessionMessage extends StatelessWidget {
  const SessionMessage(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: const BorderRadius.all(AppRadii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
