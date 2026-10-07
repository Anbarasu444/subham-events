import 'package:flutter/material.dart';

import '../../domain/entities/planner_event.dart';

/// Status label; colours come from the theme so light/dark both work.
class EventStatusChip extends StatelessWidget {
  const EventStatusChip(this.status, {super.key});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      EventStatus.planning => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      EventStatus.completed => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      EventStatus.cancelled => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}
