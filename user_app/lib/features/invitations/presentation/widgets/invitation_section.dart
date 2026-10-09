import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/widgets/festive.dart';
import '../../../../core/assets/app_illustrations.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/platform/external_actions.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../domain/invitation.dart';
import '../controllers/invitation_controller.dart';
import '../views/invitation_editor_view.dart';
import '../views/rsvp_list_view.dart';
import '../views/share_picture_view.dart';
import 'invitation_card.dart';

enum _Action { edit, closeReplies, openReplies, newLink, revoke }

/// The event Overview's Invitation card (M19).
class InvitationSection extends StatelessWidget {
  const InvitationSection({super.key, required this.event});

  final PlannerEvent event;

  ExternalActions get _external => Get.isRegistered<ExternalActions>()
      ? Get.find<ExternalActions>()
      : const PlatformExternalActions();

  bool get _editable => event.status == EventStatus.planning;

  InvitationCard _card(InvitationState data, Invitation inv) => InvitationCard(
    template: data.templateFor(inv.templateCode),
    title: inv.title,
    eventDate: inv.eventDate,
    startTime: inv.startTime,
    hostNames: inv.hostNames,
    message: inv.message,
    venueName: inv.venueName,
    venueAddress: inv.venueAddress,
  );

  Future<void> _report(BuildContext context, Future<Failure?> pending) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await pending;
    if (failure == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (failure) {
          ConflictFailure(:final message?) => message,
          _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
        }),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _edit(BuildContext context, InvitationController c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => InvitationEditorView(controller: c, event: event),
      ),
    );
  }

  Future<void> _shareLink(BuildContext context, String link, Rect? origin) =>
      _external.shareText(
        'You’re invited to ${event.title}! See the invitation and reply '
        'here: $link',
        subject: event.title,
        origin: origin,
      );

  Future<void> _onAction(
    BuildContext context,
    InvitationController c,
    _Action action,
  ) async {
    switch (action) {
      case _Action.edit:
        await _edit(context, c);
      case _Action.closeReplies:
        await _report(context, c.setRsvpOpen(false));
      case _Action.openReplies:
        await _report(context, c.setRsvpOpen(true));
      case _Action.newLink:
        if (await _confirm(
              context,
              'Create a new link?',
              'The old link stops working. Share the new one with your guests.',
              'Create new link',
            ) &&
            context.mounted) {
          await _report(context, c.newLink());
        }
      case _Action.revoke:
        if (await _confirm(
              context,
              'Turn off the invitation link?',
              'Guests can no longer open it or reply. Replies so far are kept.',
              'Turn off',
            ) &&
            context.mounted) {
          await _report(context, c.revoke());
        }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<InvitationController>(
    init: InvitationController(Get.find<InvitationsRepository>(), event.id),
    global: false,
    builder: (c) => Obx(() {
      final theme = Theme.of(context);
      final state = c.state.value;
      final data = switch (state) {
        Content(:final data) => data,
        _ => null,
      };
      final inv = data?.invitation;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Invitation',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (inv != null)
                    Chip(
                      label: Text(inv.status.label),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (inv != null)
                    PopupMenuButton<_Action>(
                      tooltip: 'More invitation actions',
                      onSelected: (a) => _onAction(context, c, a),
                      itemBuilder: (_) => [
                        if (_editable)
                          const PopupMenuItem(
                            value: _Action.edit,
                            child: Text('Edit'),
                          ),
                        if (inv.status == InvitationStatus.published &&
                            inv.rsvpOpen)
                          const PopupMenuItem(
                            value: _Action.closeReplies,
                            child: Text('Close replies'),
                          ),
                        if (inv.status == InvitationStatus.published &&
                            !inv.rsvpOpen)
                          const PopupMenuItem(
                            value: _Action.openReplies,
                            child: Text('Reopen replies'),
                          ),
                        if (_editable &&
                            inv.status == InvitationStatus.published)
                          const PopupMenuItem(
                            value: _Action.newLink,
                            child: Text('Create a new link'),
                          ),
                        if (inv.status == InvitationStatus.published)
                          const PopupMenuItem(
                            value: _Action.revoke,
                            child: Text('Turn off link'),
                          ),
                      ],
                    ),
                ],
              ),
              switch (state) {
                Loading() => const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Center(child: CircularProgressIndicator()),
                ),
                Failed(:final failure) => Row(
                  children: [
                    Expanded(child: Text(failureMessage(failure))),
                    if (failure.isRetryable)
                      TextButton(
                        onPressed: c.load,
                        child: const Text('Try again'),
                      ),
                  ],
                ),
                _ when inv == null => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    LayoutBuilder(
                      builder: (context, box) => Illustration(
                        AppIllustrations.invitationBanner,
                        fallback: Icons.mail_outline,
                        size: box.maxWidth,
                        height: box.maxWidth * 0.4,
                        fit: BoxFit.cover,
                        radius: AppRadii.md,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _editable
                          ? 'Design an e-invitation and share it as a link or '
                                'a picture. Guests can reply without the app.'
                          : 'No invitation was made for this event.',
                    ),
                    if (_editable) ...[
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        key: const ValueKey('create-invitation'),
                        onPressed: () => _edit(context, c),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Create invitation'),
                      ),
                    ],
                  ],
                ),
                _ => _Body(
                  section: this,
                  controller: c,
                  data: data!,
                  invitation: inv,
                ),
              },
            ],
          ),
        ),
      );
    }),
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.section,
    required this.controller,
    required this.data,
    required this.invitation,
  });

  final InvitationSection section;
  final InvitationController controller;
  final InvitationState data;
  final Invitation invitation;

  @override
  Widget build(BuildContext context) {
    final inv = invitation;
    final link = data.link;
    final published = inv.status == InvitationStatus.published;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: const BorderRadius.all(AppRadii.md),
          child: SizedBox(
            height: 180,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(width: 360, child: section._card(data, inv)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (inv.totals.replies > 0 || published)
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RsvpListView(eventId: inv.eventId),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: TotalsRow(totals: inv.totals)),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        if (published && !inv.rsvpOpen)
          const Text('Replies are closed.')
        else if (published)
          Text(
            'Replies close on the day after the event.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.sm),
        Obx(() {
          final busy = controller.busy.value;
          return Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (!published && section._editable)
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => section._report(context, controller.publish()),
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(
                    inv.status == InvitationStatus.revoked
                        ? 'Publish with a new link'
                        : 'Publish',
                  ),
                ),
              if (published && link != null)
                Builder(
                  builder: (b) => FilledButton.icon(
                    onPressed: () {
                      final box = b.findRenderObject() as RenderBox?;
                      unawaited(
                        section._shareLink(
                          context,
                          link,
                          box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Share link'),
                  ),
                ),
              if (published)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SharePictureView(
                        card: section._card(data, inv),
                        link: link,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Share picture'),
                ),
            ],
          );
        }),
        if (published && link == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'This phone doesn’t have the link. Use “Create a new link” in '
              'the menu (the old link stops working).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
