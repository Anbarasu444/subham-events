import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/centered_scrollable.dart';

/// Shown instead of a blank screen when a critical start-up step fails.
class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } catch (_) {
      // Start-up reports its own errors; keep this screen so the user can retry.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: SafeArea(
              child: CenteredScrollable(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: AppSizes.heroIcon,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Couldn’t start the app',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Please try again. If this keeps happening, reinstall '
                      'the app or contact support.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Try again',
                      icon: Icons.refresh,
                      isBusy: _retrying,
                      onPressed: _retry,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
