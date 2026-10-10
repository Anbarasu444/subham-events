import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_style.dart';

/// Festive building blocks (M22). Colours, gradients and radii come from
/// `app_style.dart` only.

/// A rounded box filled with a gradient.
class GradientBox extends StatelessWidget {
  const GradientBox({
    super.key,
    required this.child,
    this.gradient = AppGradients.brand,
    this.radius = AppRadii.md,
    this.padding,
    this.shadow = true,
  });

  final Widget child;
  final Gradient gradient;
  final Radius radius;
  final EdgeInsetsGeometry? padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.all(radius),
      boxShadow: shadow ? AppShadows.raised : null,
    ),
    child: padding == null ? child : Padding(padding: padding!, child: child),
  );
}

/// Text style for white text on the gradient (soft shadow for contrast).
TextStyle? onGradientStyle(TextStyle? base) => base?.copyWith(
  color: AppColors.onGradient,
  shadows: const [Shadow(color: AppColors.onGradientShadow, blurRadius: 3)],
);

/// Full-width gradient button with a busy state.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    final style = onGradientStyle(
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isBusy)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onGradient,
            ),
          )
        else if (icon != null)
          Icon(icon, color: AppColors.onGradient, size: 20),
        if (isBusy || icon != null) const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label, style: style, softWrap: true)),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || isBusy ? 1 : 0.5,
        child: GradientBox(
          shadow: enabled,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: const BorderRadius.all(AppRadii.md),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round gradient "+" button.
class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.icon = Icons.add,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: GradientBox(
        radius: AppRadii.pill,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 60,
              child: Icon(icon, color: AppColors.onGradient, size: 32),
            ),
          ),
        ),
      ),
    ),
  );
}

/// White rounded card with an icon + uppercase title and an optional
/// "More ›" link, like the reference's sections.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.all(AppRadii.lg),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    Flexible(
                      child: TextButton(
                        onPressed: onAction,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                actionLabel!,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Divider(
                height: AppSpacing.md,
                color: theme.colorScheme.outlineVariant,
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling pill tabs; the selected one is a gradient pill.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (final (value, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Semantics(
                selected: value == selected,
                button: true,
                child: value == selected
                    ? GradientBox(
                        radius: AppRadii.sm,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          label,
                          style: onGradientStyle(theme.textTheme.titleMedium),
                        ),
                      )
                    : InkWell(
                        borderRadius: const BorderRadius.all(AppRadii.sm),
                        onTap: () => onSelected(value),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSizes.minTouchTarget - 8,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded progress bar with the festive gradient.
class GradientProgressBar extends StatelessWidget {
  const GradientProgressBar({
    super.key,
    required this.value,
    required this.semanticsLabel,
    this.height = 10,
    this.color,
  });

  /// 0–1 (clamped).
  final double value;
  final String semanticsLabel;
  final double height;

  /// Solid colour instead of the gradient (e.g. error when over budget).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: '${(v * 100).round()}%',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(AppRadii.pill),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppChartColors.empty),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    gradient: color == null ? AppGradients.progress : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DonutSlice {
  const DonutSlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

/// Donut chart (fl_chart) with a centre label; an all-zero chart draws a
/// grey ring. Screen readers get the numbers as text.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerText,
    required this.semanticsLabel,
    this.size = 120,
  });

  final List<DonutSlice> slices;
  final String centerText;
  final String semanticsLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, x) => s + x.value);
    final sections = total <= 0
        ? [
            PieChartSectionData(
              value: 1,
              color: AppChartColors.empty,
              radius: size * 0.14,
              showTitle: false,
            ),
          ]
        : [
            for (final s in slices)
              if (s.value > 0)
                PieChartSectionData(
                  value: s.value,
                  color: s.color,
                  radius: size * 0.14,
                  showTitle: false,
                ),
          ];
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: size * 0.34,
                sectionsSpace: total <= 0 ? 0 : 2,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(enabled: false),
              ),
              duration: AppDurations.medium,
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.2),
              child: FittedBox(
                child: Text(
                  centerText,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "● 3 accepted" legend row.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label)),
      ],
    ),
  );
}

/// A picture from `AppIllustrations` (user-supplied, M22). While a file is
/// missing a coloured circle with [fallback] shows, so pictures can be
/// replaced without code changes. Decoded at display size to save memory.
class Illustration extends StatelessWidget {
  const Illustration(
    this.asset, {
    super.key,
    required this.fallback,
    this.size = AppSizes.gridIllustration,
    this.height,
    this.color = AppColors.teal,
    this.fit = BoxFit.contain,
    this.radius,
  });

  /// An `AppIllustrations` path.
  final String asset;
  final IconData fallback;

  /// Width (and height unless [height] is given).
  final double size;
  final double? height;
  final Color color;
  final BoxFit fit;

  /// Rounded corners (e.g. for photo-like scenes shown with [BoxFit.cover]).
  final Radius? radius;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final h = height ?? size;
    Widget image = Image.asset(
      asset,
      width: size,
      height: h,
      fit: fit,
      cacheWidth: (size * dpr).round(),
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.32),
            ],
          ),
        ),
        child: Icon(fallback, color: color, size: size * 0.5),
      ),
    );
    if (radius != null) {
      image = ClipRRect(borderRadius: BorderRadius.all(radius!), child: image);
    }
    return ExcludeSemantics(
      child: SizedBox(width: size, height: h, child: image),
    );
  }
}

/// App-bar title with a leading icon, like "🏠 Home".
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 28),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
    ],
  );
}
