import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../domain/invitation.dart';

/// The invitation as guests see it (same look as the guest web page).
/// Drawn from catalogue data, so new templates need no code changes.
class InvitationCard extends StatelessWidget {
  const InvitationCard({
    super.key,
    required this.template,
    required this.title,
    required this.eventDate,
    this.startTime,
    this.hostNames,
    this.message,
    this.venueName,
    this.venueAddress,
  });

  final InvitationTemplate template;
  final String title;
  final DateTime eventDate;
  final String? startTime;
  final String? hostNames;
  final String? message;
  final String? venueName;
  final String? venueAddress;

  static const _ornaments = {
    'lines': '— ✦ —',
    'floral': '❀ ✿ ❀',
    'diya': '🪔 ✦ 🪔',
    'stars': '✧ ✦ ✧',
  };

  static String? _font(String heading) => switch (heading) {
    'serif' => 'serif',
    'script' => 'cursive',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = template;
    final theme = Theme.of(context);
    final ornament = _ornaments[t.ornament];
    final when = [
      formatLongDate(eventDate),
      if (startTime != null) formatTimeOfDay(startTime!),
    ].join(' · ');
    final where = [?venueName, ?venueAddress].join(', ');
    final body = theme.textTheme.bodyMedium?.copyWith(color: t.text);
    return Semantics(
      label: 'Invitation preview',
      container: true,
      child: Container(
        color: t.background,
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: t.accent.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ornament != null)
                ExcludeSemantics(
                  child: Text(ornament, style: TextStyle(color: t.accent)),
                ),
              if (hostNames != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$hostNames invite you to',
                  textAlign: TextAlign.center,
                  style: body,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: t.accent,
                  fontFamily: _font(t.headingFont),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                when,
                textAlign: TextAlign.center,
                style: body?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (where.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(where, textAlign: TextAlign.center, style: body),
              ],
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(message!, textAlign: TextAlign.center, style: body),
              ],
              if (ornament != null) ...[
                const SizedBox(height: 12),
                ExcludeSemantics(
                  child: Text(ornament, style: TextStyle(color: t.accent)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
