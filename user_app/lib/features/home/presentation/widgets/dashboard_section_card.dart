import 'package:flutter/material.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/dashboard_section.dart';

/// Card for one dashboard section: title, then loading / empty / error /
/// content. Content builders are added by the milestones that own the data.
class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.state,
    required this.emptyMessage,
    required this.onRetry,
    this.emptyAction,
    this.contentBuilder,
  });

  final String title;
  final IconData icon;
  final ViewState<SectionData> state;
  final String emptyMessage;
  final Widget? emptyAction;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, Object data)? contentBuilder;

  @override
  Widget build(BuildContext context) {
    assert(
      state is! Content<SectionData> || contentBuilder != null,
      'A section that returns content needs a contentBuilder',
    );
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedSize(
              duration: AppDurations.fast,
              alignment: Alignment.topCenter,
              child: switch (state) {
                Loading() => const _SectionSkeleton(),
                Empty() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      emptyMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (emptyAction != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      emptyAction!,
                    ],
                  ],
                ),
                Failed(:final failure) => Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          failureTitle(failure),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
                Content(:final data) =>
                  data != null && contentBuilder != null
                      ? contentBuilder!(context, data)
                      : const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(AppRadii.sm),
      ),
    ),
  );
}
