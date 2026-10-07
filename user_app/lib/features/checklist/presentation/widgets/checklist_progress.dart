import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../events/domain/entities/planner_event.dart';

/// "3 of 10 done", a progress bar and the overdue count.
class ChecklistProgress extends StatelessWidget {
  const ChecklistProgress({super.key, required this.summary});

  final ChecklistSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = summary.total == 0
        ? 'No tasks yet'
        : '${summary.done} of ${summary.total} done';
    return Semantics(
      label: [
        label,
        if (summary.overdue > 0) '${summary.overdue} overdue',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              if (summary.overdue > 0)
                Text(
                  '${summary.overdue} overdue',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: const BorderRadius.all(AppRadii.sm),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
