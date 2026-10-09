import '../../../reminders/presentation/controllers/reminder_controllers.dart';
import '../../../reminders/presentation/widgets/reminder_sheet.dart';
import '../../../reminders/presentation/widgets/reminders_section.dart';
import 'package:flutter/material.dart';
import '../../../../core/assets/app_illustrations.dart';
import 'package:flutter/semantics.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/festive.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/repositories/checklist_repository.dart';
import '../controllers/checklist_controller.dart';
import '../widgets/checklist_item_sheet.dart';
import '../widgets/checklist_progress.dart';

/// An event's checklist (M9): to-do items in the user's order (drag or the
/// item menu to reorder), done items below, newest first.
class ChecklistView extends StatelessWidget {
  const ChecklistView({super.key, required this.eventId, this.eventTitle});

  final String eventId;
  final String? eventTitle;

  @override
  Widget build(BuildContext context) => GetBuilder<ChecklistController>(
    init: ChecklistController(Get.find<ChecklistRepository>(), eventId),
    global: false,
    builder: (c) => Scaffold(
      // One line only: a two-line title overflows the toolbar at 200 % text.
      appBar: AppBar(
        title: const ScreenTitle(
          icon: Icons.checklist_rounded,
          title: 'Checklist',
        ),
      ),
      floatingActionButton: Obx(() {
        final list = c.checklist;
        if (list == null || !list.isEditable || list.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return GradientFab(
          tooltip: 'Add task',
          onPressed: () => _add(context, c),
        );
      }),
      body: Obx(
        () => AsyncStateView<Checklist>(
          state: c.state.value,
          onRetry: c.load,
          builder: (context, list) => RefreshIndicator(
            onRefresh: c.load,
            child: list.items.isEmpty
                ? EmptyStateView(
                    icon: Icons.checklist_outlined,
                    illustration: AppIllustrations.emptyChecklist,
                    title: 'No tasks yet',
                    message: list.isEditable
                        ? 'Write down everything you need to do for '
                              '${eventTitle ?? 'this event'}.'
                        : '${eventTitle ?? 'This event'} is no longer being '
                              'planned.',
                    action: list.isEditable
                        ? AppButton(
                            label: 'Add task',
                            icon: Icons.add,
                            onPressed: () => _add(context, c),
                          )
                        : null,
                  )
                : _ChecklistBody(
                    list: list,
                    controller: c,
                    eventTitle: eventTitle,
                  ),
          ),
        ),
      ),
    ),
  );

  static Future<void> _add(BuildContext context, ChecklistController c) async {
    final saved = await showChecklistItemSheet(context, eventId: c.eventId);
    if (saved != null) c.applySaved(saved);
  }
}

class _ChecklistBody extends StatelessWidget {
  const _ChecklistBody({
    required this.list,
    required this.controller,
    this.eventTitle,
  });

  final Checklist list;
  final ChecklistController controller;
  final String? eventTitle;

  @override
  // Obx: the month pill filter rebuilds the list.
  Widget build(BuildContext context) => Obx(
    () => CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: checklistContentSlivers(
        context,
        list,
        controller,
        eventTitle: eventTitle,
      ),
    ),
  );
}

/// The checklist's slivers (progress, To do, Done), shared by the checklist
/// page and the event screen's Checklist tab (M10). [onAdd] adds an inline
/// "Add task" button (the tab has no floating button).
List<Widget> checklistContentSlivers(
  BuildContext context,
  Checklist list,
  ChecklistController controller, {
  String? eventTitle,
  VoidCallback? onAdd,
}) {
  final key = controller.month.value;
  bool inMonth(ChecklistItem i) => switch (key) {
    'all' => true,
    'none' => i.dueDate == null,
    _ => i.dueDate != null && ChecklistController.monthKey(i.dueDate!) == key,
  };
  final pending = list.pending.where(inMonth).toList(growable: false);
  final done = list.done.where(inMonth).toList(growable: false);
  final editable = list.isEditable;
  // Reordering works on the whole list only.
  final reorderable = editable && key == 'all';
  final months = {
    for (final i in list.items)
      if (i.dueDate != null) DateTime(i.dueDate!.year, i.dueDate!.month),
  }.toList()..sort();
  final hasUndated = list.items.any((i) => i.dueDate == null);
  return [
    if (months.isNotEmpty)
      SliverToBoxAdapter(
        child: PillTabs<String>(
          items: [
            ('all', 'All'),
            for (final m in months)
              (ChecklistController.monthKey(m), formatMonthYear(m)),
            if (hasUndated) ('none', 'No date'),
          ],
          selected: key,
          onSelected: (v) => controller.month.value = v,
        ),
      ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      sliver: SliverList.list(
        children: [
          if (eventTitle != null) ...[
            Text(eventTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
          ],
          ChecklistProgress(summary: list.summary),
          if (editable && onAdd != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Add task',
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              onPressed: onAdd,
            ),
          ],
          if (!editable) ...[
            const SizedBox(height: AppSpacing.sm),
            const _ReadOnlyBanner(),
          ],
        ],
      ),
    ),
    _SectionHeader(
      'To do',
      count: pending.length,
      hint: reorderable && pending.length > 1
          ? 'Drag the handle or use the menu to reorder'
          : null,
    ),
    if (pending.isEmpty)
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.sm,
          ),
          child: Text('All done — nice work!'),
        ),
      )
    else if (reorderable)
      SliverReorderableList(
        itemCount: pending.length,
        // The dragged row gets its own surface so rows below don't show
        // through it.
        proxyDecorator: (child, _, _) => Material(
          elevation: 4,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.all(AppRadii.sm),
          child: child,
        ),
        onReorderItem: (from, to) =>
            _report(context, controller.movePending(from, to)),
        itemBuilder: (context, index) => _ItemTile(
          key: ValueKey(pending[index].id),
          item: pending[index],
          index: index,
          pendingCount: pending.length,
          controller: controller,
          editable: true,
        ),
      )
    else
      SliverList.builder(
        itemCount: pending.length,
        itemBuilder: (context, index) => _ItemTile(
          item: pending[index],
          index: index,
          pendingCount: pending.length,
          controller: controller,
          editable: editable,
          reorderable: false,
        ),
      ),
    if (done.isNotEmpty) ...[
      _SectionHeader('Done', count: done.length),
      SliverList.builder(
        itemCount: done.length,
        itemBuilder: (context, index) => _ItemTile(
          item: done[index],
          index: index,
          pendingCount: pending.length,
          controller: controller,
          editable: editable,
        ),
      ),
    ],
    // Room for the floating button.
    const SliverToBoxAdapter(child: SizedBox(height: 96)),
  ];
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(AppRadii.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          const Expanded(
            child: Text(
              'This event is completed or cancelled, so its checklist is read only. You can reopen it (while its date has not passed) to make changes.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.count, this.hint});

  final String title;
  final int count;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xxs,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('$title ($count)', style: theme.textTheme.titleSmall),
            ),
            if (hint != null)
              Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ItemAction { edit, remind, up, down, delete }

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.pendingCount,
    required this.controller,
    required this.editable,
    this.reorderable = true,
  });

  final ChecklistItem item;
  final int index;
  final int pendingCount;
  final ChecklistController controller;
  final bool editable;

  /// False while a month filter is on (positions are list-wide).
  final bool reorderable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = <Widget>[
      if (item.isDone && item.completedAt != null)
        Text(
          'Done ${formatLongDate(dateOnly(item.completedAt!.toLocal()))}',
          style: theme.textTheme.bodySmall,
        )
      else if (item.dueDate != null)
        Text(
          item.isOverdue
              ? 'Overdue · due ${formatLongDate(item.dueDate!)}'
              : 'Due ${formatLongDate(item.dueDate!)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: item.isOverdue ? scheme.error : scheme.onSurfaceVariant,
            fontWeight: item.isOverdue ? FontWeight.w600 : null,
          ),
        ),
      if (item.notes != null)
        Text(
          item.notes!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
    ];

    final canMove = editable && reorderable && !item.isDone;
    return Semantics(
      customSemanticsActions: {
        if (canMove && index > 0)
          const CustomSemanticsAction(label: 'Move up'): () =>
              _report(context, controller.movePending(index, index - 1)),
        if (canMove && index < pendingCount - 1)
          const CustomSemanticsAction(label: 'Move down'): () =>
              _report(context, controller.movePending(index, index + 1)),
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xxs,
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: Obx(() {
            final busy = controller.busy.contains(item.id);
            return ListTile(
              contentPadding: const EdgeInsets.only(
                left: AppSpacing.xs,
                right: AppSpacing.xs,
              ),
              leading: Checkbox(
                value: item.isDone,
                semanticLabel: item.isDone
                    ? 'Mark "${item.title}" as not done'
                    : 'Mark "${item.title}" as done',
                onChanged: !editable || busy ? null : (_) => _toggle(context),
              ),
              title: Text(
                item.title,
                style: item.isDone
                    ? theme.textTheme.bodyLarge?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: scheme.onSurfaceVariant,
                      )
                    : theme.textTheme.bodyLarge,
              ),
              subtitle: details.isEmpty
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details,
                    ),
              onTap: editable ? () => _edit(context) : null,
              trailing: editable
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<_ItemAction>(
                          tooltip: 'More actions for "${item.title}"',
                          onSelected: (action) => _onAction(context, action),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: _ItemAction.edit,
                              child: Text('Edit'),
                            ),
                            if (!item.isDone)
                              const PopupMenuItem(
                                value: _ItemAction.remind,
                                child: Text('Remind me'),
                              ),
                            if (canMove && index > 0)
                              const PopupMenuItem(
                                value: _ItemAction.up,
                                child: Text('Move up'),
                              ),
                            if (canMove && index < pendingCount - 1)
                              const PopupMenuItem(
                                value: _ItemAction.down,
                                child: Text('Move down'),
                              ),
                            const PopupMenuItem(
                              value: _ItemAction.delete,
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        if (canMove)
                          // Screen readers use the Move up/down actions instead.
                          ExcludeSemantics(
                            child: ReorderableDragStartListener(
                              index: index,
                              child: const SizedBox.square(
                                dimension: AppSizes.minTouchTarget,
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                      ],
                    )
                  : null,
            );
          }),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final wasDone = item.isDone;
    final failure = await controller.toggle(item);
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(_failureText(failure))));
      return;
    }
    if (!wasDone) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('“${item.title}” done'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                final current = controller.checklist?.items
                    .where((i) => i.id == item.id)
                    .firstOrNull;
                if (current == null || !current.isDone) return;
                final failure = await controller.toggle(current);
                if (failure != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(_failureText(failure))),
                  );
                }
              },
            ),
          ),
        );
    }
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await showChecklistItemSheet(
      context,
      eventId: controller.eventId,
      existing: item,
    );
    if (saved != null) controller.applySaved(saved);
  }

  /// "Remind me" (M17 answer 6): 6 PM the day before the due date.
  Future<void> _remind(BuildContext context) async {
    final saved = await showReminderSheet(
      context,
      eventId: controller.eventId,
      tasks: [
        for (final i in controller.checklist?.items ?? const <ChecklistItem>[])
          if (!i.isDone) (id: i.id, title: i.title),
      ],
      title: item.title,
      at: defaultReminderTime(item.dueDate, DateTime.now()),
      taskId: item.id,
    );
    if (saved == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder set for ${formatReminderTime(context, saved.remindAt)}.',
        ),
      ),
    );
    await askForPushes(context, reminder: true);
  }

  Future<void> _onAction(BuildContext context, _ItemAction action) async {
    switch (action) {
      case _ItemAction.edit:
        await _edit(context);
      case _ItemAction.remind:
        await _remind(context);
      case _ItemAction.up:
        await _report(context, controller.movePending(index, index - 1));
      case _ItemAction.down:
        await _report(context, controller.movePending(index, index + 1));
      case _ItemAction.delete:
        final messenger = ScaffoldMessenger.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this task?'),
            content: Text(
              '“${item.title}” will be removed from the checklist.',
            ),
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
        );
        if (ok != true) return;
        final failure = await controller.delete(item);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              failure == null ? 'Task deleted' : _failureText(failure),
            ),
          ),
        );
    }
  }
}

Future<void> _report(BuildContext context, Future<Failure?> pending) async {
  final messenger = ScaffoldMessenger.of(context);
  final failure = await pending;
  if (failure != null) {
    messenger.showSnackBar(SnackBar(content: Text(_failureText(failure))));
  }
}

String _failureText(Failure failure) => switch (failure) {
  ConflictFailure(code: 'INVALID_STATE_TRANSITION') =>
    'The checklist changed or is now read only. Showing the latest version.',
  ConflictFailure() =>
    'This changed on another device. Showing the latest version.',
  NotFoundFailure() => 'This task no longer exists.',
  _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
};
