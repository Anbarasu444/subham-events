import 'package:flutter/material.dart';
import '../../../../core/assets/app_illustrations.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../event_vendors/domain/event_vendor.dart';
import '../../../event_vendors/presentation/views/payments_view.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/budget.dart';
import '../../domain/expense.dart';
import '../../../../core/widgets/festive.dart';
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
                ? 'Tap a category to see its details and plan an amount.'
                : 'Planned amounts per category.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    SliverToBoxAdapter(
      child: Obx(
        () => PillTabs<String>(
          items: const [
            ('all', 'All'),
            ('planned', 'Planned'),
            ('spending', 'With spending'),
            ('over', 'Over plan'),
          ],
          selected: controller.lineFilter.value,
          onSelected: (v) => controller.lineFilter.value = v,
        ),
      ),
    ),
    Obx(() {
      final lines = budget.lines
          .where((l) => _matches(l, controller.lineFilter.value))
          .toList(growable: false);
      if (lines.isEmpty) {
        return const SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: Text('No categories match this filter.'),
          ),
        );
      }
      return SliverList.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) => _LineTile(
          line: lines[index],
          editable: budget.isEditable,
          controller: controller,
        ),
      );
    }),
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

/// Spent on a category: bookings plus the user's own expenses.
BigInt _spentOn(BudgetLine l) => l.committed.minorUnits + l.expenses.minorUnits;

bool _matches(BudgetLine l, String filter) => switch (filter) {
  'planned' => l.planned != null,
  'spending' => _spentOn(l) > BigInt.zero || l.paid.minorUnits > BigInt.zero,
  'over' => l.planned != null && _spentOn(l) > l.planned!.minorUnits,
  _ => true,
};

String _money(BigInt paise) {
  final digits = paise.abs().toString().padLeft(3, '0');
  return Money.parse(
    '${digits.substring(0, digits.length - 2)}.'
        '${digits.substring(digits.length - 2)}',
    'INR',
  ).format();
}

Set<String> _bookedCategories(Budget budget) => {
  for (final line in budget.lines)
    if (line.committed.minorUnits > BigInt.zero) line.categoryId,
};

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
    bookedCategoryIds: _bookedCategories(budget),
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
          child: Column(
            children: [
              const Illustration(
                AppIllustrations.emptyBudget,
                fallback: Icons.receipt_long_outlined,
                size: 120,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                budget.isEditable
                    ? 'No expenses yet. Tap Add to note one.'
                    : 'No expenses were noted for this event.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
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
      bookedCategoryIds: _bookedCategories(budget),
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
    final spent = budget.spent.minorUnits.toDouble();
    final totalValue = total?.minorUnits.toDouble() ?? 0;
    final share = totalValue <= 0 ? null : spent / totalValue;
    return SectionCard(
      title: 'Balance',
      icon: Icons.calculate_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // At very large text the figures need the width.
              if (MediaQuery.textScalerOf(context).scale(1) <= 1.4) ...[
                DonutChart(
                  size: 88,
                  centerText: share == null ? '–' : '${(share * 100).round()}%',
                  semanticsLabel: share == null
                      ? 'No total budget set'
                      : '${(share * 100).round()}% of the total spent',
                  slices: share == null
                      ? const []
                      : [
                          DonutSlice('Spent', spent, AppChartColors.first),
                          DonutSlice(
                            'Left',
                            (totalValue - spent).clamp(0, double.infinity),
                            AppChartColors.empty,
                          ),
                        ],
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total budget', style: theme.textTheme.labelMedium),
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
                            child: Text(total == null ? 'Set total' : 'Change'),
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
            GradientProgressBar(
              value: budget.plannedShare!,
              color: budget.isOverPlanned ? scheme.error : null,
              semanticsLabel: 'Share of the total budget planned',
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
          if ((budget.paidToCancelled?.minorUnits ?? BigInt.zero) > BigInt.zero)
            _Figure(
              label: '  of which to cancelled vendors',
              value: budget.paidToCancelled!,
            ),
          if ((budget.outstanding?.minorUnits ?? BigInt.zero) > BigInt.zero)
            _Figure(label: 'Still to pay vendors', value: budget.outstanding!),
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
            'Booked amounts come from accepted quotes; Paid is what you '
            'noted under each booking’s Payments.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
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
    final spent = _spentOn(line);
    final planned = line.planned?.minorUnits;
    final over = planned != null && spent > planned;
    return Obx(() {
      final busy = controller.busy.contains(line.categoryId);
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xxs,
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BudgetCategoryView(
                  controller: controller,
                  categoryId: line.categoryId,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (busy)
                        const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Saving',
                          ),
                        )
                      else
                        Text(
                          line.planned?.format() ?? (editable ? 'Add' : '—'),
                          semanticsLabel: line.planned == null
                              ? (editable
                                    ? 'Not planned, add amount'
                                    : 'Not planned')
                              : null,
                          style: line.planned == null
                              ? theme.textTheme.labelLarge?.copyWith(
                                  color: editable
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                )
                              : theme.textTheme.titleSmall,
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  if (planned != null && planned > BigInt.zero) ...[
                    const SizedBox(height: AppSpacing.xs),
                    GradientProgressBar(
                      value: spent.toDouble() / planned.toDouble(),
                      color: over ? theme.colorScheme.error : null,
                      semanticsLabel: 'Spent of the plan for ${line.name}',
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Spent: ${_money(spent)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: over ? theme.colorScheme.error : null,
                            ),
                          ),
                        ),
                        Text(
                          'Plan: ${line.planned!.format()}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                  if (_subtitle(hasBookings) case final sub?)
                    DefaultTextStyle.merge(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      child: sub,
                    ),
                ],
              ),
            ),
          ),
        ),
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

/// Budget details for one category (M22): plan, balance, expenses and the
/// booked vendors with their payments.
class BudgetCategoryView extends StatefulWidget {
  const BudgetCategoryView({
    super.key,
    required this.controller,
    required this.categoryId,
  });

  final BudgetController controller;
  final String categoryId;

  @override
  State<BudgetCategoryView> createState() => _BudgetCategoryViewState();
}

class _BudgetCategoryViewState extends State<BudgetCategoryView> {
  Future<Result<EventVendorList>>? _vendors;

  BudgetController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<EventVendorsRepository>()) {
      _vendors = Get.find<EventVendorsRepository>().list(c.eventId);
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final budget = c.budget;
    final line = budget?.lines
        .where((l) => l.categoryId == widget.categoryId)
        .firstOrNull;
    final expenses = switch (c.expenses.value) {
      Content(:final data) =>
        data.expenses
            .where((e) => e.categoryId == widget.categoryId)
            .toList(growable: false),
      _ => const <Expense>[],
    };
    return Scaffold(
      appBar: AppBar(title: Text(line?.name ?? 'Budget')),
      floatingActionButton: budget != null && budget.isEditable
          ? GradientFab(
              tooltip: 'Add expense',
              onPressed: () => _addExpense(context, budget, c),
            )
          : null,
      body: budget == null || line == null
          ? const Center(
              child: Text('This category is no longer in the budget.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                96,
              ),
              children: [
                _details(context, budget, line),
                const SizedBox(height: AppSpacing.md),
                _balance(context, line),
                const SizedBox(height: AppSpacing.md),
                _bookings(context, line),
                SectionCard(
                  title: 'Expenses',
                  icon: Icons.receipt_long_outlined,
                  child: expenses.isEmpty
                      ? const Text('No expenses in this category yet.')
                      : Column(
                          children: [
                            for (final e in expenses)
                              _ExpenseTile(
                                expense: e,
                                budget: budget,
                                controller: c,
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  });

  Widget _row(BuildContext context, String label, String value, [Color? dot]) =>
      MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (dot != null)
                Flexible(
                  child: LegendDot(color: dot, label: value),
                )
              else
                Flexible(child: Text(value, textAlign: TextAlign.end)),
            ],
          ),
        ),
      );

  Widget _details(BuildContext context, Budget budget, BudgetLine line) =>
      SectionCard(
        title: 'Details',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(context, 'Category', line.name),
            if (line.isArchived) _row(context, 'Status', 'No longer offered'),
            _row(context, 'Plan', line.planned?.format() ?? 'Not planned'),
            if (budget.isEditable &&
                (!line.isArchived || line.planned != null)) ...[
              const SizedBox(height: AppSpacing.sm),
              GradientButton(
                label: line.isArchived
                    ? 'Remove plan'
                    : line.planned == null
                    ? 'Plan an amount'
                    : 'Change plan',
                icon: Icons.edit_outlined,
                onPressed: () => _LineTile(
                  line: line,
                  editable: true,
                  controller: c,
                )._edit(context),
              ),
            ],
          ],
        ),
      );

  Widget _balance(BuildContext context, BudgetLine line) {
    final theme = Theme.of(context);
    final spent = _spentOn(line);
    final planned = line.planned?.minorUnits;
    final left = planned == null ? null : planned - spent;
    return SectionCard(
      title: 'Balance',
      icon: Icons.calculate_outlined,
      actionLabel: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(
            context,
            'Plan',
            line.planned?.format() ?? '—',
            AppChartColors.empty,
          ),
          _row(
            context,
            'Booked',
            line.committed.format(),
            AppChartColors.third,
          ),
          _row(context, 'Paid', line.paid.format(), AppChartColors.first),
          _row(
            context,
            'My expenses',
            line.expenses.format(),
            AppChartColors.second,
          ),
          if (left != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              left.isNegative
                  ? 'Over the plan by ${_money(-left)}'
                  : 'Left in the plan: ${_money(left)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: left.isNegative
                    ? theme.colorScheme.error
                    : AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            GradientProgressBar(
              value: planned! == BigInt.zero
                  ? 1
                  : spent.toDouble() / planned.toDouble(),
              color: left.isNegative ? theme.colorScheme.error : null,
              semanticsLabel: 'Spent of the plan',
            ),
          ],
        ],
      ),
    );
  }

  Widget _bookings(BuildContext context, BudgetLine line) {
    final vendors = _vendors;
    if (vendors == null) return const SizedBox.shrink();
    return FutureBuilder<Result<EventVendorList>>(
      future: vendors,
      builder: (context, snap) {
        final booked = switch (snap.data) {
          Ok(:final value) =>
            value.vendors
                .where(
                  (v) =>
                      v.listing.category.id == line.categoryId &&
                      v.booking != null,
                )
                .toList(growable: false),
          _ => const <EventVendor>[],
        };
        if (booked.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: SectionCard(
            title: 'Bookings',
            icon: Icons.handshake_outlined,
            child: Column(
              children: [
                for (final v in booked)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.listing.vendorName),
                    subtitle: Text(
                      'Agreed ${v.booking!.agreedAmount.format()}'
                      '${v.booking!.paid == null ? '' : ' · Paid ${v.booking!.paid!.format()}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => PaymentsView.open(
                      context,
                      eventId: c.eventId,
                      bookingId: v.booking!.id,
                      vendorName: v.listing.vendorName,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
