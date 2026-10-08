import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/payment.dart';
import '../controllers/payments_controller.dart';
import '../widgets/payment_sheet.dart';

/// A booking's payments (M16): totals, list, add / edit / delete.
class PaymentsView extends StatelessWidget {
  const PaymentsView({
    super.key,
    required this.eventId,
    required this.bookingId,
    required this.vendorName,
  });

  final String eventId;
  final String bookingId;
  final String vendorName;

  static Future<void> open(
    BuildContext context, {
    required String eventId,
    required String bookingId,
    required String vendorName,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PaymentsView(
        eventId: eventId,
        bookingId: bookingId,
        vendorName: vendorName,
      ),
    ),
  );

  Future<void> _edit(
    BuildContext context,
    PaymentsController c, [
    Payment? payment,
  ]) async {
    final saved = await showPaymentSheet(
      context,
      eventId: eventId,
      bookingId: bookingId,
      existing: payment,
    );
    if (saved != null) await c.load();
  }

  Future<void> _delete(
    BuildContext context,
    PaymentsController c,
    Payment payment,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete the ${payment.amount.format()} payment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final failure = await c.delete(payment);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? 'Payment deleted.'
              : '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GetBuilder<PaymentsController>(
    init: PaymentsController(
      Get.find<PaymentsRepository>(),
      eventId,
      bookingId,
    ),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(title: Text('Payments · $vendorName')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, c),
        icon: const Icon(Icons.add),
        label: const Text('Add payment'),
      ),
      body: Obx(
        () => AsyncStateView<PaymentList>(
          state: c.state.value,
          onRetry: c.load,
          builder: (context, list) => RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                96,
              ),
              children: [
                _Totals(list: list),
                const SizedBox(height: AppSpacing.md),
                if (list.payments.isEmpty)
                  const Text(
                    'No payments yet. Tap “Add payment” to note an advance or '
                    'instalment you paid.',
                  ),
                for (final payment in list.payments)
                  Obx(
                    () => _PaymentTile(
                      payment: payment,
                      busy: c.busy.contains(payment.id),
                      onTap: () => _edit(context, c, payment),
                      onDelete: () => _delete(context, c, payment),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Totals extends StatelessWidget {
  const _Totals({required this.list});

  final PaymentList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paid ${list.paid.format()} of ${list.agreedAmount.format()}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            if (list.overpaidBy != null)
              Text(
                'Overpaid by ${list.overpaidBy!.format()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text('Balance due ${list.balance!.format()}'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'For your records — no money is sent through the app, and the '
              'vendor does not see these.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.busy,
    required this.onTap,
    required this.onDelete,
  });

  final Payment payment;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.amount.format(),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${payment.kind.label} · ${payment.method.label} · '
                      '${formatLongDate(payment.paidOn)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (payment.note != null)
                      Text(
                        payment.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Deleting',
                  ),
                ),
              )
            else
              IconButton(
                tooltip: 'Delete ${payment.amount.format()} payment',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
