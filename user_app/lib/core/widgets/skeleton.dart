import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Static placeholder blocks shown while content loads. No shimmer animation
/// (keeps low-end devices idle — rule 16).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Loading',
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.page),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, _) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(AppRadii.md),
          ),
        ),
      ),
    );
  }
}
