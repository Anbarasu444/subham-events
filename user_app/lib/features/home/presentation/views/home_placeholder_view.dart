import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/centered_scrollable.dart';

/// Temporary start screen until the main navigation shell exists (M6).
class HomePlaceholderView extends StatelessWidget {
  const HomePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Get.find<AppConfig>();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: CenteredScrollable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.celebration_outlined,
                size: AppSizes.heroIcon,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Event Planner',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Foundation build ${config.appVersion} (${config.flavor.name})',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (config.enableDiagnostics) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Open diagnostics',
                  icon: Icons.monitor_heart_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Get.toNamed(AppRoutes.diagnostics),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
