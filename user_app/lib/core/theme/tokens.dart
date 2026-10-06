import 'package:flutter/material.dart';

/// Design tokens (architecture/flutter.md §11). Widgets read these through
/// the theme; never hard-code colours, spacing or durations.
abstract final class AppColors {
  /// Brand colour (user, 2026-10-06 — may change when branding exists).
  /// Seeds the Material 3 scheme; the generated `primary` tones keep text
  /// contrast, so use `colorScheme.primary` for text/buttons, not [brand].
  /// Fails WCAG contrast for text on white (≈2.3:1): splash and theme seed only.
  static const brand = Color(0xFFFF7E7E);
  static const seed = brand;
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFB26A00);
}

/// 4-pt spacing scale.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// Horizontal page gutter.
  static const page = md;
}

abstract final class AppRadii {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(20);
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
}

abstract final class AppSizes {
  /// Minimum touch target (accessibility).
  static const minTouchTarget = 48.0;

  /// Large decorative icon on full-screen messages.
  static const heroIcon = 64.0;
}
