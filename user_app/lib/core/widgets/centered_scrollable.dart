import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Centres content vertically but scrolls when it does not fit
/// (large text scaling, small or landscape screens).
class CenteredScrollable extends StatelessWidget {
  const CenteredScrollable({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - padding.vertical).clamp(
            0,
            double.infinity,
          ),
        ),
        child: Center(child: child),
      ),
    ),
  );
}
