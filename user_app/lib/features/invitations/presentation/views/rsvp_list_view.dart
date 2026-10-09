import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/invitation.dart';

/// Guests' replies with totals (M19).
class RsvpListView extends StatefulWidget {
  const RsvpListView({super.key, required this.eventId});

  final String eventId;

  @override
  State<RsvpListView> createState() => _RsvpListViewState();
}

class _RsvpListViewState extends State<RsvpListView> {
  ViewState<RsvpList> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await Get.find<InvitationsRepository>().rsvps(
      widget.eventId,
    );
    if (!mounted) return;
    setState(() {
      _state = switch (result) {
        Ok(:final value) =>
          value.rsvps.isEmpty ? const Empty() : Content(value),
        Err(:final failure) => Failed(failure),
      };
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Replies')),
    body: _state is Empty<RsvpList>
        ? const EmptyStateView(
            icon: Icons.mark_email_unread_outlined,
            title: 'No replies yet',
            message: 'Share your invitation. Replies from guests appear here.',
          )
        : AsyncStateView<RsvpList>(
            state: _state,
            onRetry: _load,
            builder: (context, list) => RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  TotalsRow(totals: list.totals),
                  const SizedBox(height: AppSpacing.md),
                  for (final r in list.rsvps)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(switch (r.response) {
                        RsvpResponse.attending => Icons.check_circle_outline,
                        RsvpResponse.maybe => Icons.help_outline,
                        RsvpResponse.notAttending => Icons.cancel_outlined,
                      }),
                      title: Text(r.guestName),
                      subtitle: Text(
                        [
                          '${r.response.label}'
                              '${r.response == RsvpResponse.attending ? ' · ${r.guestCount} ${r.guestCount == 1 ? 'person' : 'people'}' : ''}',
                          formatLongDate(r.updatedAt),
                          ?r.message,
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
            ),
          ),
  );
}

/// "12 coming (30 people) · 3 maybe · 2 not coming".
class TotalsRow extends StatelessWidget {
  const TotalsRow({super.key, required this.totals});

  final RsvpTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(String label, int value) => Chip(
      label: Text('$value $label'),
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('coming', totals.attending),
        chip('maybe', totals.maybe),
        chip('not coming', totals.notAttending),
        Text(
          '${totals.guests} ${totals.guests == 1 ? 'person' : 'people'} expected',
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}
