import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../../explore/presentation/views/listing_detail_view.dart';
import '../../../explore/presentation/widgets/category_icon.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../domain/event_vendor.dart';
import '../controllers/event_vendors_controller.dart';
import '../../../reminders/presentation/widgets/reminders_section.dart';
import '../views/payments_view.dart';
import 'enquiry_sheet.dart';

/// The event screen's Vendors tab content (M14).
List<Widget> eventVendorSlivers(
  BuildContext context,
  EventVendorList list,
  EventVendorsController controller,
  PlannerEvent event,
) {
  final theme = Theme.of(context);
  void explore() => Get.find<ShellController>().select(ShellTab.explore);
  if (list.vendors.isEmpty) {
    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.page),
        sliver: SliverList.list(
          children: [
            Text('No vendors yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              list.isEditable
                  ? 'Find vendors in Explore and tap “Add to event” on a '
                        'vendor’s page. You can then send them an enquiry.'
                  : 'No vendors were added to this event.',
            ),
            if (list.isEditable) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Explore vendors',
                icon: Icons.explore_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: explore,
              ),
            ],
          ],
        ),
      ),
    ];
  }
  return [
    if (!list.isEditable)
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            'This event is completed or cancelled, so its vendors are read '
            'only.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.page),
      sliver: SliverList.separated(
        itemCount: list.vendors.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _VendorCard(
          vendor: list.vendors[index],
          editable: list.isEditable,
          controller: controller,
          event: event,
        ),
      ),
    ),
    if (list.isEditable)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: AppButton(
            label: 'Find more vendors',
            icon: Icons.explore_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: explore,
          ),
        ),
      ),
  ];
}

Future<void> _report(BuildContext context, Future<Failure?> pending) async {
  final messenger = ScaffoldMessenger.of(context);
  final failure = await pending;
  if (failure == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (failure) {
        ConflictFailure(code: 'INVALID_STATE_TRANSITION') =>
          failure.message ?? 'This change is no longer possible.',
        ConflictFailure() =>
          'This vendor changed on another device. Showing the latest.',
        _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
      }),
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

enum _Action { note, remove }

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.editable,
    required this.controller,
    required this.event,
  });

  final EventVendor vendor;
  final bool editable;
  final EventVendorsController controller;
  final PlannerEvent event;

  bool get _removable =>
      editable &&
      (vendor.status == EventVendorStatus.added ||
          vendor.status == EventVendorStatus.enquired ||
          vendor.status == EventVendorStatus.quoted);

  Future<void> _editNote(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(initial: vendor.notes),
    );
    if (result == null || !context.mounted) return;
    final trimmed = result.trim();
    await _report(
      context,
      controller.updateNotes(vendor, trimmed.isEmpty ? null : trimmed),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final hasLive = vendor.liveEnquiry != null;
    if (!await _confirm(
          context,
          title: 'Remove ${vendor.listing.vendorName}?',
          body: hasLive
              ? 'Your open enquiry with this vendor will be closed.'
              : 'You can add this vendor again later.',
          action: 'Remove',
        ) ||
        !context.mounted) {
      return;
    }
    await _report(context, controller.remove(vendor));
  }

  Future<void> _enquire(BuildContext context) async {
    final sent = await showEnquirySheet(context, event: event, vendor: vendor);
    if (sent == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Enquiry sent. The vendor will reply in the app, or call or '
          'email them meanwhile.',
        ),
      ),
    );
    await controller.load();
    if (context.mounted) await askForPushes(context, reminder: false);
  }

  Future<void> _closeEnquiry(BuildContext context, Enquiry enquiry) async {
    if (!await _confirm(
          context,
          title: 'Close this enquiry?',
          body:
              'The vendor will no longer be able to reply to it. You can '
              'send a new enquiry later.',
          action: 'Close enquiry',
        ) ||
        !context.mounted) {
      return;
    }
    await _report(context, controller.closeEnquiry(vendor, enquiry));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = vendor.liveEnquiry;
    final last = vendor.enquiries.firstOrNull;
    return Obx(() {
      final busy = controller.busy.contains(vendor.id);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: const BorderRadius.all(AppRadii.sm),
                      ),
                      child: Icon(
                        categoryIcon(vendor.listing.category.slug),
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MergeSemantics(
                      child: InkWell(
                        onTap: vendor.isAvailable
                            ? () => ListingNavigation.open(
                                context,
                                vendor.listing,
                              )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendor.listing.vendorName,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '${vendor.listing.category.name} · '
                              '${vendor.listing.title}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
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
                          semanticsLabel: 'Saving',
                        ),
                      ),
                    )
                  else if (editable)
                    PopupMenuButton<_Action>(
                      tooltip: 'More for ${vendor.listing.vendorName}',
                      onSelected: (action) => switch (action) {
                        _Action.note => _editNote(context),
                        _Action.remove => _remove(context),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _Action.note,
                          child: Text(
                            vendor.notes == null ? 'Add note' : 'Edit note',
                          ),
                        ),
                        if (_removable)
                          const PopupMenuItem(
                            value: _Action.remove,
                            child: Text('Remove from event'),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    label: Text(vendor.status.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (!vendor.isAvailable)
                    Chip(
                      label: const Text('No longer listed'),
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(color: scheme.error),
                    ),
                ],
              ),
              if (vendor.booking != null)
                _BookingPanel(
                  vendor: vendor,
                  controller: controller,
                  busy: busy,
                )
              else if (vendor.openQuote != null)
                _QuotePanel(
                  vendor: vendor,
                  quote: vendor.openQuote!,
                  controller: controller,
                  editable: editable,
                  busy: busy,
                ),
              if (live != null && vendor.openQuote == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Enquiry sent ${formatLongDate(live.createdAt.toLocal())}'
                    '${live.preferredDate == null ? '' : ' · preferred ${formatLongDate(live.preferredDate!)}'}. '
                    'The vendor will reply in the app.',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else if (last != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Last enquiry: ${last.status.label.toLowerCase()}'
                    '${last.closedBy == 'SYSTEM' ? ' (event changed)' : ''}.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (vendor.notes != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Note: ${vendor.notes}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (editable && !busy && (vendor.canEnquire || live != null))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (vendor.canEnquire)
                        FilledButton.tonalIcon(
                          onPressed: () => _enquire(context),
                          icon: const Icon(Icons.send_outlined),
                          label: Text(
                            last == null ? 'Send enquiry' : 'Enquire again',
                          ),
                        ),
                      if (live != null)
                        TextButton(
                          onPressed: () => _closeEnquiry(context, live),
                          child: const Text('Close enquiry'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// Owns its text controller, so it is disposed only after the dialog is gone.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.initial});

  final String? initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Private note'),
    content: TextField(
      controller: _text,
      autofocus: true,
      minLines: 2,
      maxLines: 5,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        helperText: 'Only you can see this note.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_text.text),
        child: const Text('Save'),
      ),
    ],
  );
}

/// The latest quote: amount, validity, Accept / Decline (M15, R3).
class _QuotePanel extends StatelessWidget {
  const _QuotePanel({
    required this.vendor,
    required this.quote,
    required this.controller,
    required this.editable,
    required this.busy,
  });

  final EventVendor vendor;
  final Quotation quote;
  final EventVendorsController controller;
  final bool editable;
  final bool busy;

  Future<void> _accept(BuildContext context) async {
    if (!await _confirm(
          context,
          title:
              'Book ${vendor.listing.vendorName} for '
              '${quote.amount.format()}?',
          body:
              'This becomes the agreed amount in your budget. The vendor '
              'is told the booking is confirmed.',
          action: 'Book',
        ) ||
        !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final failure = await controller.acceptQuotation(vendor, quote);
    if (failure == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('${vendor.listing.vendorName} is booked.')),
      );
    } else if (context.mounted) {
      await _report(context, Future.value(failure));
    }
  }

  Future<void> _decline(BuildContext context) async {
    if (!await _confirm(
          context,
          title: 'Decline this quote?',
          body: 'The vendor can send you a new one.',
          action: 'Decline',
        ) ||
        !context.mounted) {
      return;
    }
    await _report(context, controller.rejectQuotation(vendor, quote));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = quote.status == QuotationStatus.expired;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              quote.revisionNo > 1 ? 'Revised quote' : 'Quote received',
              style: theme.textTheme.labelLarge,
            ),
          ),
          Text(quote.amount.format(), style: theme.textTheme.titleLarge),
          Text(
            expired
                ? 'Expired on ${formatLongDate(quote.validUntil)}. Ask the '
                      'vendor for a new quote.'
                : 'Valid until ${formatLongDate(quote.validUntil)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: expired ? theme.colorScheme.error : null,
            ),
          ),
          if (quote.description != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(quote.description!),
          ],
          if (editable && !expired && !busy) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.icon(
                  onPressed: () => _accept(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept & book'),
                ),
                OutlinedButton(
                  onPressed: () => _decline(context),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The booking: agreed amount, date, Cancel / Mark completed (M15, A7).
class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    required this.vendor,
    required this.controller,
    required this.busy,
  });

  final EventVendor vendor;
  final EventVendorsController controller;
  final bool busy;

  Future<void> _cancel(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) =>
          _CancelBookingDialog(vendorName: vendor.listing.vendorName),
    );
    if (reason == null || !context.mounted) return;
    await _report(context, controller.cancelBooking(vendor, reason));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booking = vendor.booking!;
    final cancelled = booking.status == BookingStatus.cancelled;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cancelled
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.secondaryContainer,
        borderRadius: const BorderRadius.all(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(switch (booking.status) {
              BookingStatus.confirmed => 'Booking confirmed',
              BookingStatus.completed => 'Booking completed',
              BookingStatus.cancelled => 'Booking cancelled',
            }, style: theme.textTheme.labelLarge),
          ),
          Text(
            'Agreed ${booking.agreedAmount.format()}',
            style: theme.textTheme.titleMedium,
          ),
          Text('Service on ${formatLongDate(booking.serviceDate)}'),
          if (booking.paid != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _paidLine(booking),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (cancelled && booking.cancelReason != null)
            Text(
              'Reason: ${booking.cancelReason}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              // Payments stay open after cancellation (A11) and the event.
              OutlinedButton.icon(
                onPressed: () => PaymentsView.open(
                  context,
                  eventId: controller.eventId,
                  bookingId: booking.id,
                  vendorName: vendor.listing.vendorName,
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Payments'),
              ),
              if (!busy) ...[
                if (booking.canComplete)
                  FilledButton.tonal(
                    onPressed: () =>
                        _report(context, controller.completeBooking(vendor)),
                    child: const Text('Mark completed'),
                  ),
                if (booking.canCancel)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _cancel(context),
                    child: const Text('Cancel booking'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// "Paid ₹X of ₹Y · Balance ₹Z" (or overpaid) for the booking panel.
String _paidLine(Booking booking) {
  final paid = booking.paid!;
  final agreed = booking.agreedAmount;
  final diff = agreed.minorUnits - paid.minorUnits;
  final tail = diff.isNegative
      ? 'overpaid ${Money.parse(_amount(-diff), agreed.currency).format()}'
      : 'balance ${Money.parse(_amount(diff), agreed.currency).format()}';
  return 'Paid ${paid.format()} of ${agreed.format()} · $tail';
}

String _amount(BigInt paise) {
  final digits = paise.toString().padLeft(3, '0');
  return '${digits.substring(0, digits.length - 2)}.'
      '${digits.substring(digits.length - 2)}';
}

/// Asks for the reason the vendor will see (3–500 characters, A7).
class _CancelBookingDialog extends StatefulWidget {
  const _CancelBookingDialog({required this.vendorName});

  final String vendorName;

  @override
  State<_CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<_CancelBookingDialog> {
  final TextEditingController _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _reason.text.trim();
    if (text.length < 3) {
      setState(() => _error = 'Tell the vendor why (at least 3 characters).');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Cancel the booking with ${widget.vendorName}?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'The vendor will be told. Any refund or cancellation fee is '
          'agreed with them directly.',
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _reason,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(labelText: 'Reason', errorText: _error),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Keep booking'),
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: _submit,
        child: const Text('Cancel booking'),
      ),
    ],
  );
}
