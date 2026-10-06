import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary }

/// Full-width button with a built-in busy state.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isBusy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isBusy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final onTap = isBusy ? null : onPressed;
    final child = isBusy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: isBusy ? '$label, loading' : label,
      excludeSemantics: true,
      child: switch (variant) {
        AppButtonVariant.primary =>
          icon == null || isBusy
              ? FilledButton(onPressed: onTap, child: child)
              : FilledButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon),
                  label: child,
                ),
        AppButtonVariant.secondary =>
          icon == null || isBusy
              ? OutlinedButton(onPressed: onTap, child: child)
              : OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon),
                  label: child,
                ),
      },
    );
  }
}
