import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/budget.dart';
import '../../domain/expense.dart';
import '../controllers/budget_controller.dart';
import 'expense_sheet.dart';
import 'money_sheet.dart';

/// Budget content as slivers, shared by the event screen's Budget tab and
/// the standalone budget page (M11).
List<Widget> budgetSlivers(
  BuildContext context,
  Budget budget,
  BudgetController controller,
) {
  final theme = Theme.of(context);
  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      sliver: SliverList.list(
        children: [
          _Summary(budget: budget, controller: controller),
          if (!budget.isEditable) ...[
            const SizedBox(height: AppSpacing.sm),
            const _ReadOnlyNote(),
          ],
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text('By category', style: theme.textTheme.titleMedium),
          ),
          Text(
            budget.isEditable
                ? 'Tap a category to plan an amount for it.'
                : 'Planned amounts per category.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    SliverList.builder(
      itemCount: budget.lines.length,
      itemBuilder: (context, index) => _LineTile(
        line: budget.lines[index],
        editable: budget.isEditable,
        controller: controller,
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.xs,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('My expenses', style: theme.textTheme.titleMedium),
              ),
            ),
            if (budget.isEditable)
              TextButton.icon(
                key: const ValueKey('add-expense'),
                onPressed: () => _addExpense(context, budget, controller),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
          ],
        ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      sliver: SliverToBoxAdapter(
        child: Text(
          'Note money you spend outside bookings, like small purchases '
          'or help from family. It counts towards what you have spent.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
    _ExpenseSlivers(budget: budget, controller: controller),
  ];
}

List<ExpenseCategory> _categoriesFor(Budget budget, Expense? existing) => [
  for (final line in budget.offeredLines)
    (id: line.categoryId, name: line.name),
  // A retired category stays selectable for the expense that already has it.
  if (existing?.categoryId case final id?
      when !budget.offeredLines.any((l) => l.categoryId == id))
    (id: id, name: existing!.categoryName ?? 'Other'),
];

Future<void> _addExpense(
  BuildContext context,
  Budget budget,
  BudgetController controller,
) async {
  final saved = await showExpenseSheet(
    context,
    eventId: budget.eventId,
    categories: _categoriesFor(budget, null),
  );
  if (saved == null || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Added “${saved.title}”.')));
  await controller.expenseSaved();
}

/// The expense list (its own loading/empty/error states).
class _ExpenseSlivers extends StatelessWidget {
  const _ExpenseSlivers({required this.budget, required this.controller});

  final Budget budget;
  final BudgetController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final theme = Theme.of(context);
    return switch (controller.expenses.value) {
      Content(:final data, :final isStale) => SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xs,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${data.expenses.length == 1 ? '1 expense' : '${data.expenses.length} expenses'}'
                ' · ${data.total.format()}'
                '${isStale ? ' · may be out of date' : ''}',
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
          SliverList.builder(
            itemCount: data.expenses.length,
            itemBuilder: (context, index) => _ExpenseTile(
              expense: data.expenses[index],
              budget: budget,
              controller: controller,
            ),
          ),
        ],
      ),
      Failed(:final failure) => SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.page),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load your expenses. ${failureMessage(failure)}'
                      .trim(),
                ),
              ),
              if (failure.isRetryable)
                TextButton(
                  onPressed: controller.loadExpenses,
                  child: const Text('Try again'),
                ),
            ],
          ),
        ),
      ),
      Empty() => SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.page),
        sliver: SliverToBoxAdapter(
          child: Text(
            budget.isEditable
                ? 'No expenses yet. Tap Add to note one.'
                : 'No expenses were noted for this event.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
      Loading() => const SliverPadding(
        padding: EdgeInsets.all(AppSpacing.page),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading expenses',
            ),
          ),
        ),
      ),
    };
  });
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.budget,
    required this.controller,
  });

  final Expense expense;
  final Budget budget;
  final BudgetController controller;

  Future<void> _edit(BuildContext context) async {
    final saved = await showExpenseSheet(
      context,
      eventId: budget.eventId,
      categories: _categoriesFor(budget, expense),
      existing: expense,
    );
    if (saved == null || !context.mounted) return;
    await controller.expenseSaved();
  }

  Future<void> _delete(BuildContext context) async {
    if (!await _confirmClear(context, 'Delete “${expense.title}”?') ||
        !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final failure = await controller.deleteExpense(expense);
    if (!context.mounted) return;
    if (failure != null) {
      await _report(context, Future.value(failure));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Expense deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      formatLongDate(expense.spentOn),
      ?expense.categoryName,
    ].join(' · ');
    return Obx(() {
      final busy = controller.busy.contains(expense.id);
      return InkWell(
        onTap: budget.isEditable && !busy ? () => _edit(context) : null,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.page,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                // One screen-reader stop: title, amount, date, note.
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              expense.title,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              expense.amount.format(),
                              textAlign: TextAlign.end,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        details,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (expense.note != null)
                        Text(
                          expense.note!,
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
              else if (budget.isEditable)
                IconButton(
                  tooltip: 'Delete ${expense.title}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context),
                )
              else
                const SizedBox(width: AppSpacing.page),
            ],
          ),
        ),
      );
    });
  }
}

Future<bool> _confirmClear(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> _report(BuildContext context, Future<Failure?> pending) async {
  final messenger = ScaffoldMessenger.of(context);
  final failure = await pending;
  if (failure == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (failure) {
        ConflictFailure(code: 'INVALID_STATE_TRANSITION') =>
          'This event is no longer being planned, so its budget is read only.',
        ConflictFailure() =>
          'This event changed on another device. Showing the latest budget.',
        ValidationFailure() => 'Please check the amount.',
        _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
      }),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.budget, required this.controller});

  final Budget budget;
  final BudgetController controller;

  Future<void> _editTotal(BuildContext context) async {
    final result = await showMoneySheet(
      context,
      title: 'Total budget',
      initial: budget.totalBudget,
      clearLabel: 'Remove total budget',
    );
    if (result == null || !context.mounted) return;
    if (result is MoneyCleared &&
        !await _confirmClear(context, 'Remove the total budget?')) {
      return;
    }
    if (!context.mounted) return;
    await _report(
      context,
      controller.setTotal(switch (result) {
        MoneyEntered(:final amount) => amount,
        MoneyCleared() => null,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = budget.totalBudget;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total budget',
                          style: theme.textTheme.labelMedium,
                        ),
                        Text(
                          total?.format() ?? 'Not set',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (budget.isEditable)
                  Obx(
                    () => controller.busy.contains('total')
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.sm),
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Saving total budget',
                              ),
                            ),
                          )
                        : Semantics(
                            label: total == null
                                ? 'Set total budget'
                                : 'Change total budget',
                            excludeSemantics: true,
                            button: true,
                            child: TextButton(
                              onPressed: () => _editTotal(context),
                              child: Text(
                                total == null ? 'Set total' : 'Change',
                              ),
                            ),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              total == null
                  ? 'Planned so far: ${budget.planned.format()}'
                  : 'Planned ${budget.planned.format()} of ${total.format()}',
              style: theme.textTheme.bodyMedium,
            ),
            if (budget.plannedShare != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: const BorderRadius.all(AppRadii.sm),
                child: LinearProgressIndicator(
                  value: budget.plannedShare,
                  minHeight: 8,
                  color: budget.isOverPlanned ? scheme.error : null,
                  backgroundColor: scheme.surfaceContainerHighest,
                  semanticsLabel: 'Share of the total budget planned',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            if (budget.overPlannedBy != null)
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Over budget by ${budget.overPlannedBy!.format()}: '
                        'planned more than your total.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (budget.unplanned != null)
              Text(
                'Not yet planned: ${budget.unplanned!.format()}',
                style: theme.textTheme.bodyMedium,
              ),
            const Divider(height: AppSpacing.lg),
            _Figure(label: 'Booked (committed)', value: budget.committed),
            _Figure(label: 'Paid', value: budget.paid),
            _Figure(label: 'My expenses', value: budget.expenses),
            if (budget.overspentBy != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Text(
                    'Bookings and expenses are '
                    '${budget.overspentBy!.format()} over your total.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else if (budget.remaining != null)
              _Figure(label: 'Left to spend', value: budget.remaining!),
            Text(
              'Booked and paid amounts appear once you book vendors and '
              'record payments.',
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

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final Money value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpacing.xs),
          // Large amounts at large text sizes wrap instead of overflowing.
          Flexible(
            child: Text(
              value.format(),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

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
              'This event is completed or cancelled, so its budget is read '
              'only. You can reopen it (while its date has not passed) to '
              'make changes.',
            ),
          ),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.editable,
    required this.controller,
  });

  final BudgetLine line;
  final bool editable;
  final BudgetController controller;

  Future<void> _edit(BuildContext context) async {
    if (line.isArchived) {
      // No new plans for a category that is no longer offered.
      if (await _confirmClear(context, 'Remove the plan for ${line.name}?') &&
          context.mounted) {
        await _report(context, controller.clearPlanned(line.categoryId));
      }
      return;
    }
    final result = await showMoneySheet(
      context,
      title: 'Plan for ${line.name}',
      initial: line.planned,
      clearLabel: 'Clear planned amount',
    );
    if (result == null || !context.mounted) return;
    if (result is MoneyCleared &&
        !await _confirmClear(context, 'Clear the plan for ${line.name}?')) {
      return;
    }
    if (!context.mounted) return;
    await _report(context, switch (result) {
      MoneyEntered(:final amount) => controller.setPlanned(
        line.categoryId,
        amount,
      ),
      MoneyCleared() => controller.clearPlanned(line.categoryId),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBookings =
        line.committed.minorUnits > BigInt.zero ||
        line.paid.minorUnits > BigInt.zero;
    // A retired category with only expenses has nothing to change here.
    final tappable = editable && (!line.isArchived || line.planned != null);
    return Obx(() {
      final busy = controller.busy.contains(line.categoryId);
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        title: Text(line.name),
        subtitle: _subtitle(hasBookings),
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Saving',
                ),
              )
            : Text(
                line.planned?.format() ?? (editable ? 'Add' : '—'),
                semanticsLabel: line.planned == null
                    ? (editable ? 'Not planned, add amount' : 'Not planned')
                    : null,
                style: line.planned == null
                    ? theme.textTheme.labelLarge?.copyWith(
                        color: editable
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      )
                    : theme.textTheme.titleSmall,
              ),
        onTap: tappable && !busy ? () => _edit(context) : null,
      );
    });
  }

  Widget? _subtitle(bool hasBookings) {
    final parts = [
      if (line.isArchived) 'No longer offered',
      if (hasBookings)
        'Booked ${line.committed.format()} · Paid ${line.paid.format()}',
      if (line.expenses.minorUnits > BigInt.zero)
        'My expenses ${line.expenses.format()}',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }
}
