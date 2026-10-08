import 'package:flutter/material.dart';

import '../error/failure.dart';
import '../state/view_state.dart';
import '../theme/tokens.dart';
import 'app_button.dart';
import 'skeleton.dart';

/// Renders a [ViewState] consistently: skeleton, empty, error with retry, or
/// content (CLAUDE.md §19). Stale content shows an "offline" banner.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.loading,
  });

  final ViewState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.fast,
      child: switch (state) {
        Loading<T>() => KeyedSubtree(
          key: const ValueKey('loading'),
          child: loading ?? const SkeletonList(),
        ),
        Empty<T>() => _Message(
          key: const ValueKey('empty'),
          icon: Icons.inbox_outlined,
          title: emptyTitle,
          message: emptyMessage,
        ),
        Failed<T>(:final failure) => _Message(
          key: const ValueKey('error'),
          icon: Icons.error_outline,
          title: failureTitle(failure),
          message: failureMessage(failure),
          onRetry: failure.isRetryable ? onRetry : null,
        ),
        Content<T>(:final data, :final isStale) => KeyedSubtree(
          key: const ValueKey('content'),
          child: Column(
            children: [
              if (isStale) const StaleBanner(),
              Expanded(child: builder(context, data)),
            ],
          ),
        ),
      },
    );
  }
}

/// User-facing title for a failure. Technical detail stays in logs.
String failureTitle(Failure failure) => switch (failure) {
  NetworkFailure() => 'You are offline',
  TimeoutFailure() => 'This is taking too long',
  UnauthorizedFailure() => 'Please sign in again',
  ForbiddenFailure() => 'You don’t have access to this',
  NotFoundFailure() => 'Not found',
  ConflictFailure() => 'This was changed elsewhere',
  ValidationFailure() => 'Please check your details',
  RateLimitedFailure() => 'Too many attempts',
  ServerFailure() => 'Something went wrong on our side',
  CancelledFailure() => 'Cancelled',
  UnknownFailure() => 'Something went wrong',
};

String failureMessage(Failure failure) => switch (failure) {
  NetworkFailure() => 'Check your internet connection and try again.',
  TimeoutFailure() => 'The server did not respond in time. Try again.',
  RateLimitedFailure(:final retryAfter) =>
    retryAfter == null
        ? 'Please wait a moment and try again.'
        : 'Please try again in ${retryAfter.inSeconds} seconds.',
  ServerFailure() || UnknownFailure() => 'Please try again in a moment.',
  _ => failure.message ?? '',
};

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 200,
                child: AppButton(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Showing saved data" strip for content kept after a failed refresh.
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: scheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Showing saved data — you may be offline',
          style: TextStyle(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
