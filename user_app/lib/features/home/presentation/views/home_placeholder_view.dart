import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/centered_scrollable.dart';

/// Temporary start screen until the main navigation shell exists (M6).
/// Shows sign-in / account entry points for M5.
class HomePlaceholderView extends StatelessWidget {
  const HomePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Get.find<AppConfig>();
    final session = Get.find<SessionService>();
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
              const SizedBox(height: AppSpacing.xl),
              Obx(() {
                final state = session.state.value;
                return switch (state) {
                  RestoringSession() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  // Label only: no phone/email on the home screen.
                  SignedInSession() => AppButton(
                    label: 'My account',
                    icon: Icons.person_outline,
                    onPressed: () => Get.toNamed<void>(AppRoutes.account),
                  ),
                  ProfilePendingSession() => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Couldn’t reach the server. You are still signed in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Try again',
                        icon: Icons.refresh,
                        onPressed: session.retry,
                      ),
                    ],
                  ),
                  GuestSession(:final message) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (message != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppButton(
                        label: 'Sign in',
                        icon: Icons.login,
                        onPressed: () => Get.toNamed<void>(AppRoutes.signIn),
                      ),
                    ],
                  ),
                };
              }),
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
