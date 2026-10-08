import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/budget.dart';
import '../../domain/expense.dart';
import '../controllers/expense_form_controller.dart';

/// A category the user can pick for an expense.
typedef ExpenseCategory = ({String id, String name});

/// Opens the add/edit sheet; returns the saved expense, or null if closed.
Future<Expense?> showExpenseSheet(
  BuildContext context, {
  required String eventId,
  required List<ExpenseCategory> categories,
  Set<String> bookedCategoryIds = const {},
  Expense? existing,
}) => showModalBottomSheet<Expense>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => ExpenseSheet(
    eventId: eventId,
    categories: categories,
    bookedCategoryIds: bookedCategoryIds,
    existing: existing,
  ),
);

class ExpenseSheet extends StatelessWidget {
  const ExpenseSheet({
    super.key,
    required this.eventId,
    required this.categories,
    this.bookedCategoryIds = const {},
    this.existing,
  });

  final String eventId;
  final List<ExpenseCategory> categories;

  /// Categories with a booked vendor: payments to them belong under the
  /// booking's Payments instead (GI-32).
  final Set<String> bookedCategoryIds;
  final Expense? existing;

  @override
  Widget build(BuildContext context) => GetBuilder<ExpenseFormController>(
    init: ExpenseFormController(
      Get.find<BudgetRepository>(),
      eventId,
      existing: existing,
    ),
    global: false,
    builder: (c) => Padding(
      // Keep the fields above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                c.isEdit ? 'Edit expense' : 'New expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => TextField(
                controller: c.title,
                autofocus: !c.isEdit,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => c.titleError.value = null,
                decoration: InputDecoration(
                  labelText: 'What was it for?',
                  hintText: 'e.g. Flowers for the stage',
                  errorText: c.titleError.value,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => TextField(
                controller: c.amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                maxLength: 16,
                onChanged: (_) => c.amountError.value = null,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  hintText: 'e.g. 1500',
                  errorText: c.amountError.value,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(() {
              final date = c.spentOn.value;
              return Semantics(
                button: true,
                label: 'Date, ${formatLongDate(date)}',
                child: InkWell(
                  borderRadius: const BorderRadius.all(AppRadii.sm),
                  onTap: () => _pickDate(context, c),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: ExcludeSemantics(child: Text(formatLongDate(date))),
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => DropdownButtonFormField<String?>(
                initialValue: c.categoryId.value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('No category')),
                  for (final category in categories)
                    DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => c.categoryId.value = value,
              ),
            ),
            Obx(
              () => bookedCategoryIds.contains(c.categoryId.value)
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          'Paying a booked vendor? Add it under that '
                          'booking’s Payments instead, so it isn’t counted '
                          'twice.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => TextField(
                controller: c.note,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => c.noteError.value = null,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Paid by uncle, to settle later',
                  errorText: c.noteError.value,
                  alignLabelWithHint: true,
                ),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => AppButton(
                label: c.isEdit ? 'Save expense' : 'Add expense',
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
    ),
  );

  Future<void> _pickDate(BuildContext context, ExpenseFormController c) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: c.spentOn.value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Date of the expense',
    );
    if (picked != null) c.spentOn.value = dateOnly(picked);
  }
}
