import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/payment.dart';
import '../controllers/payment_form_controller.dart';

/// Add or edit a payment; returns the saved payment, or null if closed.
Future<Payment?> showPaymentSheet(
  BuildContext context, {
  required String eventId,
  required String bookingId,
  Payment? existing,
}) => showModalBottomSheet<Payment>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) =>
      _PaymentSheet(eventId: eventId, bookingId: bookingId, existing: existing),
);

class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({
    required this.eventId,
    required this.bookingId,
    this.existing,
  });

  final String eventId;
  final String bookingId;
  final Payment? existing;

  @override
  Widget build(BuildContext context) => GetBuilder<PaymentFormController>(
    init: PaymentFormController(
      Get.find<PaymentsRepository>(),
      eventId,
      bookingId,
      existing: existing,
    ),
    global: false,
    builder: (c) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  c.isEdit ? 'Edit payment' : 'Add payment',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Text(
                'For your records — no money is sent through the app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => TextField(
                  controller: c.amount,
                  autofocus: !c.isEdit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  maxLength: 16,
                  onChanged: (_) => c.amountError.value = null,
                  decoration: InputDecoration(
                    labelText: 'Amount paid',
                    prefixText: '₹ ',
                    errorText: c.amountError.value,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(() {
                final date = c.paidOn.value;
                return Semantics(
                  button: true,
                  label: 'Paid on, ${formatLongDate(date)}',
                  child: InkWell(
                    borderRadius: const BorderRadius.all(AppRadii.sm),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: c.today,
                        helpText: 'Paid on',
                      );
                      if (picked != null) {
                        c.paidOn.value = dateOnly(picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Paid on',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: ExcludeSemantics(
                        child: Text(formatLongDate(date)),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => DropdownButtonFormField<PaymentMethod>(
                  initialValue: c.method.value,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: [
                    for (final m in PaymentMethod.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (m) => c.method.value = m ?? c.method.value,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => DropdownButtonFormField<PaymentKind>(
                  initialValue: c.kind.value,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final k in PaymentKind.values)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                  ],
                  onChanged: (k) => c.kind.value = k ?? c.kind.value,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: c.note,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Receipt with uncle',
                ),
              ),
              Obx(
                () => c.formError.value == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            c.formError.value!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => AppButton(
                  label: c.isEdit ? 'Save payment' : 'Add payment',
                  icon: Icons.check,
                  isBusy: c.saving.value,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final saved = await c.submit();
                    if (saved != null) navigator.pop(saved);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
