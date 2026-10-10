import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE APP'S LOOK — ONE FILE (Subam Vendor, M24; same pattern as the User App)
///
///  Change the font, the brand colours, gradients, corner radii, spacing
///  and chart colours here and the whole Vendor App follows. Widgets never
///  hard-code colours or font families; they read these values (directly or
///  through the Material theme built in `app_theme.dart`).
/// ─────────────────────────────────────────────────────────────────────────

/// Fonts. Kalam (Google Fonts, SIL OFL 1.1 — free for commercial apps) is
/// bundled in `assets/fonts/kalam/`. To change the font: add the new files
/// to `pubspec.yaml` under `fonts:` and change the family names below.
abstract final class AppFonts {
  /// Body text, buttons, numbers.
  static const body = 'Kalam';

  /// Titles and headings (can be a more decorative font).
  static const heading = 'Kalam';

  /// Text a little larger than Material's default suits a handwritten font.
  static const bodyScale = 1.05;
}

/// Brand colours — Subam Vendor (user, 2026-10-10: same festive style as the
/// User App with a teal → green accent).
abstract final class AppColors {
  /// The user's vendor gradient: teal → green.
  static const teal = Color(0xFF11998E);
  static const green = Color(0xFF38EF7D);

  /// Deeper teal and green for fills that carry white text: white on them
  /// passes WCAG AA (≥ 4.5:1). The bright gradient fails with white text
  /// (teal 3.5:1, green 1.5:1), so it is used for decoration only.
  static const tealDeep = Color(0xFF0B6E66);
  static const greenDeep = Color(0xFF1B7F4B);

  /// A warm festive accent kept from the User App family (charts, badges).
  static const marigold = Color(0xFFF5B83D);

  /// Seeds the Material colour scheme.
  static const seed = teal;

  /// Primary for text and icons on light backgrounds (AA on white and on
  /// [background]).
  static const primary = tealDeep;

  /// Text drawn on the AA-safe gradient fills.
  static const onGradient = Colors.white;

  /// Soft shadow behind white text on gradients.
  static const onGradientShadow = Color(0x55000000);

  /// Light mint page background and white cards.
  static const background = Color(0xFFF3FBF7);
  static const surface = Colors.white;
  static const text = Color(0xFF1F332E);
  static const textMuted = Color(0xFF55706A);
  static const divider = Color(0xFFDDEFE7);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFB26A00);

  /// The Material seed under its shared name.
  static const brand = teal;
}

/// Gradients built from [AppColors].
abstract final class AppGradients {
  /// Buttons, selected tabs, floating "+" (white text: AA-safe shades).
  static const brand = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.tealDeep, AppColors.greenDeep],
  );

  /// Big hero cards with white text.
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.tealDeep, AppColors.greenDeep],
  );

  /// The user's exact teal → green, for decoration without text
  /// (banners, glows).
  static const festive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.teal, AppColors.green],
  );

  /// Progress bars.
  static const progress = LinearGradient(
    colors: [AppColors.teal, AppColors.green],
  );
}

/// Chart and legend colours, in order.
abstract final class AppChartColors {
  static const first = AppColors.teal;
  static const second = AppColors.green;
  static const third = AppColors.marigold;
  static const fourth = Color(0xFF9B7BE0);
  static const fifth = Color(0xFF4DB6E0);
  static const empty = Color(0xFFE3EFEA);

  static const series = [first, second, third, fourth, fifth];
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

/// Corner radii (cards are soft and rounded in the festive look).
abstract final class AppRadii {
  static const sm = Radius.circular(10);
  static const md = Radius.circular(14);
  static const lg = Radius.circular(22);
  static const pill = Radius.circular(100);
}

/// Card shadow: a soft glow instead of Material elevation.
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x140B6E66), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x330B6E66), blurRadius: 14, offset: Offset(0, 6)),
  ];
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

  /// Illustration sizes (quick-action grid, empty screens).
  static const gridIllustration = 56.0;
  static const emptyIllustration = 140.0;
}
