import 'package:flutter/material.dart';

import 'app_style.dart';

/// Material 3 themes built only from `app_style.dart` (M22): font, brand
/// colours, warm background, rounded cards and pill tabs.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final scheme = light
        ? base.copyWith(
            primary: AppColors.primary,
            secondary: AppColors.orange,
            tertiary: AppColors.rose,
            surface: AppColors.surface,
            onSurface: AppColors.text,
            onSurfaceVariant: AppColors.textMuted,
            outlineVariant: AppColors.divider,
          )
        : base;
    final background = light ? AppColors.background : base.surface;
    // Sizes come from Material's type scale; colours from the scheme.
    final typography = Typography.material2021();
    final text = _textTheme(
      typography.englishLike.merge(light ? typography.black : typography.white),
      scheme.onSurface,
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(AppRadii.md),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      textTheme: text,
      scaffoldBackgroundColor: background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.headlineMedium?.copyWith(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
          shape: shape,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
          shape: shape,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.saffronDeep,
        foregroundColor: AppColors.onGradient,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? AppColors.surface : null,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadii.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: light ? 0 : 1,
        color: light ? AppColors.surface : null,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(AppRadii.lg),
          side: light
              ? const BorderSide(color: AppColors.divider)
              : BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.titleSmall,
        indicatorColor: AppColors.orange,
        labelColor: scheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: light ? AppColors.surface : null,
        indicatorColor: AppColors.gold.withValues(alpha: 0.35),
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Material's type scale in the app font, a touch larger for Kalam.
  static TextTheme _textTheme(TextTheme base, Color color) {
    TextStyle? scale(TextStyle? s, {bool heading = false}) => s?.copyWith(
      fontFamily: heading ? AppFonts.heading : AppFonts.body,
      fontSize: s.fontSize == null ? null : s.fontSize! * AppFonts.bodyScale,
      color: color,
    );
    return base.copyWith(
      displayLarge: scale(base.displayLarge, heading: true),
      displayMedium: scale(base.displayMedium, heading: true),
      displaySmall: scale(base.displaySmall, heading: true),
      headlineLarge: scale(base.headlineLarge, heading: true),
      headlineMedium: scale(base.headlineMedium, heading: true),
      headlineSmall: scale(base.headlineSmall, heading: true),
      titleLarge: scale(base.titleLarge, heading: true),
      titleMedium: scale(base.titleMedium, heading: true),
      titleSmall: scale(base.titleSmall, heading: true),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }
}
