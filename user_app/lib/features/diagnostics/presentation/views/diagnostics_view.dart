import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/entities/backend_health.dart';
import '../controllers/diagnostics_controller.dart';

class DiagnosticsView extends GetView<DiagnosticsController> {
  const DiagnosticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Check again',
            icon: const Icon(Icons.refresh),
            onPressed: controller.check,
          ),
        ],
      ),
      body: Obx(
        () => AsyncStateView<BackendHealth>(
          state: controller.state.value,
          onRetry: controller.check,
          loading: const Center(child: CircularProgressIndicator()),
          builder: (context, health) => _HealthDetails(
            health: health,
            apiBaseUrl: controller.config.apiBaseUrl,
            client: controller.config.clientHeader,
          ),
        ),
      ),
    );
  }
}

class _HealthDetails extends StatelessWidget {
  const _HealthDetails({
    required this.health,
    required this.apiBaseUrl,
    required this.client,
  });

  final BackendHealth health;
  final String apiBaseUrl;
  final String client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: AppSpacing.xs),
            Text('Backend ready', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Row('API', apiBaseUrl),
        _Row('Client', client),
        for (final check in health.checks.entries) _Row(check.key, check.value),
        _Row('Latency', '${health.latency.inMilliseconds} ms'),
        _Row('Request id', health.requestId ?? '—'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: SelectableText(value),
  );
}
