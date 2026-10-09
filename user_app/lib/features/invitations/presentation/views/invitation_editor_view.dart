import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../events/domain/entities/planner_event.dart';
import '../../domain/invitation.dart';
import '../controllers/invitation_controller.dart';
import '../widgets/invitation_card.dart';

/// Create or edit the invitation: design, wording, live preview (M19).
class InvitationEditorView extends StatefulWidget {
  const InvitationEditorView({
    super.key,
    required this.controller,
    required this.event,
  });

  final InvitationController controller;
  final PlannerEvent event;

  @override
  State<InvitationEditorView> createState() => _InvitationEditorViewState();
}

class _InvitationEditorViewState extends State<InvitationEditorView> {
  late final InvitationState _data = widget.controller.current!;
  late final Invitation? _existing = _data.invitation;
  late String _template = _existing?.templateCode ?? _data.templates.first.code;
  late final _title = TextEditingController(
    text: _existing?.title ?? widget.event.title,
  );
  late final _hosts = TextEditingController(text: _existing?.hostNames);
  late final _message = TextEditingController(
    text: _existing?.message ?? 'We would love you to join us.',
  );
  String? _titleError;
  String? _formError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _hosts, _message]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _hosts.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    setState(() {
      _titleError = title.isEmpty ? 'Enter a title.' : null;
      _formError = null;
    });
    if (_titleError != null) return;
    setState(() => _saving = true);
    final failure = await widget.controller.save(
      InvitationInput(
        templateCode: _template,
        title: title,
        message: _clean(_message),
        hostNames: _clean(_hosts),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(
        () => _formError = switch (failure) {
          ConflictFailure() =>
            'This event is no longer being planned, so its invitation can’t '
                'be changed.',
          ValidationFailure() => 'Please check the title and texts.',
          _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New invitation' : 'Edit invitation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text('Design', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _data.templates.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, i) {
                final t = _data.templates[i];
                return ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: t.accent, radius: 8),
                  label: Text(t.name),
                  selected: _template == t.code,
                  onSelected: (_) => setState(() => _template = t.code),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Title',
              errorText: _titleError,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _hosts,
            maxLength: 200,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'From (optional)',
              hintText: 'e.g. The Kumar family',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _message,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message (optional)',
              alignLabelWithHint: true,
            ),
          ),
          Text(
            'Date, time and venue come from the event. Edit the event to '
            'change them, then save the invitation again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Preview', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: const BorderRadius.all(AppRadii.md),
            child: InvitationCard(
              template: _data.templateFor(_template),
              title: _title.text.trim().isEmpty
                  ? event.title
                  : _title.text.trim(),
              eventDate: event.eventDate,
              startTime: event.startTime,
              hostNames: _clean(_hosts),
              message: _clean(_message),
              venueName: event.venueName,
              venueAddress: event.venueAddress,
            ),
          ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _formError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Save invitation',
            icon: Icons.check,
            isBusy: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
