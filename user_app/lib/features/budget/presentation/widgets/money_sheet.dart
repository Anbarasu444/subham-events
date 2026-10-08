import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';

/// What the money sheet returns: a new amount, or a request to clear it.
sealed class MoneySheetResult {
  const MoneySheetResult();
}

class MoneyEntered extends MoneySheetResult {
  const MoneyEntered(this.amount);
  final Money amount;
}

class MoneyCleared extends MoneySheetResult {
  const MoneyCleared();
}

/// Bottom sheet for one rupee amount (exact paise, no doubles — ADR-0014).
Future<MoneySheetResult?> showMoneySheet(
  BuildContext context, {
  required String title,
  Money? initial,
  String? clearLabel,
}) => showModalBottomSheet<MoneySheetResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) =>
      _MoneySheet(title: title, initial: initial, clearLabel: clearLabel),
);

class _MoneySheet extends StatefulWidget {
  const _MoneySheet({required this.title, this.initial, this.clearLabel});

  final String title;
  final Money? initial;
  final String? clearLabel;

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  // The current amount is selected, so typing replaces it.
  late final TextEditingController _text =
      TextEditingController(text: widget.initial?.toInputText())
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial?.toInputText().length ?? 0,
        );
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final amount = Money.tryParseInput(_text.text);
    if (amount == null) {
      setState(
        () => _error =
            'Enter an amount like 50000 or 50000.50 '
            '(up to ₹99,99,99,99,999.99).',
      );
      return;
    }
    Navigator.of(context).pop(MoneyEntered(amount));
  }

  @override
  Widget build(BuildContext context) => Padding(
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
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _text,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textInputAction: TextInputAction.done,
            maxLength: 16,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              hintText: 'e.g. 50000',
              errorText: _error,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Save', icon: Icons.check, onPressed: _save),
          if (widget.clearLabel != null && widget.initial != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(const MoneyCleared()),
              child: Text(widget.clearLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}
