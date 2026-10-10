import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE APP'S LOOK — ONE FILE (M22, user request 2026-10-09)
///
///  Change the font, the brand colours, gradients, corner radii, spacing
///  and chart colours here and the whole User App follows. Widgets never
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

/// Brand colours (user, 2026-10-09: "festive", may change later).
abstract final class AppColors {
  /// The festive gradient: golden yellow → orange → deep burnt orange.
  static const gold = Color(0xFFF5C842);
  static const orange = Color(0xFFE8873A);
  static const deepOrange = Color(0xFFC0461E);

  /// Accent used next to the gradient (pink, like a marigold garland).
  static const rose = Color(0xFFE5677E);

  /// Deeper saffron and rose for fills that carry white text: white on
  /// them passes WCAG AA (≥ 4.5:1). The bright colours above fail with white
  /// text (gold 1.6:1, orange 2.6:1), so they are used for decoration only
  /// (M23 accessibility pass).
  static const saffronDeep = Color(0xFFBF5418);
  static const roseDeep = Color(0xFFB83E5C);

  /// Seeds the Material colour scheme.
  static const seed = orange;

  /// Primary for text and icons on light backgrounds (WCAG AA on white and
  /// on [background]; the bright gradient colours are for fills only).
  static const primary = Color(0xFFB0441C);

  /// Text drawn on the gradient (white passes AA on the darker half only;
  /// gradient widgets add a soft shadow behind white text).
  static const onGradient = Colors.white;

  /// Soft shadow behind white text on the gradient.
  static const onGradientShadow = Color(0x55000000);

  /// Light warm page background and white cards.
  static const background = Color(0xFFFFF7EE);
  static const surface = Colors.white;
  static const text = Color(0xFF3A2A22);
  static const textMuted = Color(0xFF7A6458);
  static const divider = Color(0xFFF0E2D6);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFB26A00);

  /// Kept for older code: the original seed name.
  static const brand = orange;
}

/// Gradients built from [AppColors].
abstract final class AppGradients {
  /// Buttons, selected tabs, floating "+" (white text: AA-safe shades).
  static const brand = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.saffronDeep, AppColors.roseDeep],
  );

  /// Big hero cards with white text (event countdown).
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.saffronDeep, AppColors.deepOrange, AppColors.roseDeep],
  );

  /// The user's festive gold → orange → deep orange, for decoration
  /// without text (banners, glows).
  static const festive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.orange, AppColors.deepOrange],
  );

  /// Progress bars.
  static const progress = LinearGradient(
    colors: [AppColors.gold, AppColors.orange],
  );
}

/// Chart and legend colours, in order (paid, pending, remaining…).
abstract final class AppChartColors {
  static const first = AppColors.rose;
  static const second = AppColors.gold;
  static const third = Color(0xFF9B7BE0);
  static const fourth = AppColors.orange;
  static const fifth = Color(0xFF4DB6AC);
  static const empty = Color(0xFFEDE3DA);

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

/// Card shadow: a soft warm glow instead of Material elevation.
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x14B0441C), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x33C0461E), blurRadius: 14, offset: Offset(0, 6)),
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
