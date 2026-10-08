import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../domain/event_vendor.dart';
import '../controllers/enquiry_form_controller.dart';

/// Returns the updated vendor after sending, or null if closed.
Future<EventVendor?> showEnquirySheet(
  BuildContext context, {
  required PlannerEvent event,
  required EventVendor vendor,
}) => showModalBottomSheet<EventVendor>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _EnquirySheet(event: event, vendor: vendor),
);

class _EnquirySheet extends StatelessWidget {
  const _EnquirySheet({required this.event, required this.vendor});

  final PlannerEvent event;
  final EventVendor vendor;

  @override
  Widget build(BuildContext context) => GetBuilder<EnquiryFormController>(
    init: EnquiryFormController(
      Get.find<EventVendorsRepository>(),
      event,
      vendor,
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
                  'Enquire with ${vendor.listing.vendorName}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The vendor sees your name, event type, date, city and guest '
                'estimate — not your phone, email, budget or notes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => TextField(
                  controller: c.message,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => c.messageError.value = null,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    errorText: c.messageError.value,
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Obx(() {
                final date = c.preferredDate.value;
                return Semantics(
                  button: true,
                  label: date == null
                      ? 'Preferred date, not set'
                      : 'Preferred date, ${formatLongDate(date)}',
                  child: InkWell(
                    borderRadius: const BorderRadius.all(AppRadii.sm),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date ?? event.eventDate,
                        firstDate: c.today,
                        lastDate: DateTime(2100, 12, 31),
                        helpText: 'Preferred date',
                      );
                      if (picked != null) {
                        c.preferredDate.value = dateOnly(picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Preferred date (optional)',
                        prefixIcon: const Icon(Icons.event_outlined),
                        suffixIcon: date == null
                            ? null
                            : IconButton(
                                tooltip: 'Clear preferred date',
                                icon: const Icon(Icons.close),
                                onPressed: () => c.preferredDate.value = null,
                              ),
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          date == null ? 'No date' : formatLongDate(date),
                        ),
                      ),
                    ),
                  ),
                );
              }),
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
                  label: 'Send enquiry',
                  icon: Icons.send_outlined,
                  isBusy: c.sending.value,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final sent = await c.submit();
                    if (sent != null) navigator.pop(sent);
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
