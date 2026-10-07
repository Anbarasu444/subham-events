import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/planner_event.dart';
import 'event_status_chip.dart';

/// One event in a list or on the Home dashboard.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.today,
    this.onTap,
  });

  final PlannerEvent event;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = daysBetween(today, event.eventDate);
    final when = [
      formatLongDate(event.eventDate),
      if (event.startTime != null) formatTimeOfDay(event.startTime!),
    ].join(' · ');
    // One screen-reader item per event.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (event.status != EventStatus.planning) ...[
                      const SizedBox(width: AppSpacing.xs),
                      EventStatusChip(event.status),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  event.eventType,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _Line(icon: Icons.event_outlined, text: when),
                _Line(icon: Icons.place_outlined, text: event.city),
                if (event.status == EventStatus.planning) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    relativeDays(days),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
