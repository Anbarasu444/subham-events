import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'festive.dart';

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

  static final _onGradient = FilledButton.styleFrom(
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor: AppColors.onGradient,
    disabledForegroundColor: AppColors.onGradient,
    shadowColor: Colors.transparent,
  );

  @override
  Widget build(BuildContext context) {
    final onTap = isBusy ? null : onPressed;
    final child = isBusy
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary
                  ? AppColors.onGradient
                  : null,
            ),
          )
        : Text(label);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: isBusy ? '$label, loading' : label,
      excludeSemantics: true,
      child: switch (variant) {
        // Festive look (M22): the filled button sits on the brand gradient.
        AppButtonVariant.primary => Opacity(
          opacity: onTap == null && !isBusy ? 0.5 : 1,
          child: GradientBox(
            shadow: onTap != null,
            child: icon == null || isBusy
                ? FilledButton(
                    style: _onGradient,
                    onPressed: onTap,
                    child: child,
                  )
                : FilledButton.icon(
                    style: _onGradient,
                    onPressed: onTap,
                    icon: Icon(icon),
                    label: child,
                  ),
          ),
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
