import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
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
              if (live != null)
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
