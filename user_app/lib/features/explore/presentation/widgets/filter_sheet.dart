import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/listing.dart';

/// City, price range and sort. Returns the new query, or null if closed.
Future<ListingQuery?> showFilterSheet(
  BuildContext context, {
  required ListingQuery current,
  required List<String> cities,
}) => showModalBottomSheet<ListingQuery>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _FilterSheet(current: current, cities: cities),
);

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current, required this.cities});

  final ListingQuery current;
  final List<String> cities;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _city = widget.current.city;
  late ListingSort _sort = widget.current.sort;
  late final _min = TextEditingController(
    text: widget.current.minPrice?.toInputText(),
  );
  late final _max = TextEditingController(
    text: widget.current.maxPrice?.toInputText(),
  );
  String? _priceError;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// Blank = no bound; otherwise an exact amount (no doubles, ADR-0014).
  (bool, Money?) _read(TextEditingController field) {
    final text = field.text.trim();
    if (text.isEmpty) return (true, null);
    final money = Money.tryParseInput(text);
    return (money != null, money);
  }

  void _apply() {
    final (minOk, min) = _read(_min);
    final (maxOk, max) = _read(_max);
    String? error;
    if (!minOk || !maxOk) {
      error = 'Enter amounts like 25000 or 25000.50.';
    } else if (min != null && max != null && max.minorUnits < min.minorUnits) {
      error = 'The maximum must not be less than the minimum.';
    }
    if (error != null) {
      setState(() => _priceError = error);
      return;
    }
    Navigator.of(context).pop(
      widget.current.copyWith(
        city: () => _city,
        minPrice: () => min,
        maxPrice: () => max,
        sort: _sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A preset city (e.g. the event's) stays selectable even if no listing
    // uses it yet.
    final cities = {...widget.cities, ?widget.current.city}.toList();
    Widget amount(TextEditingController controller, String label) => TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      maxLength: 16,
      onChanged: (_) => setState(() => _priceError = null),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        counterText: '',
      ),
    );
    return Padding(
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
              child: Text('Filters', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(child: Text('Any city')),
                for (final city in cities)
                  DropdownMenuItem<String?>(value: city, child: Text(city)),
              ],
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Starting price', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                SizedBox(width: 150, child: amount(_min, 'Minimum')),
                SizedBox(width: 150, child: amount(_max, 'Maximum')),
              ],
            ),
            if (_priceError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _priceError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text('Sort by', style: theme.textTheme.titleSmall),
            RadioGroup<ListingSort>(
              groupValue: _sort,
              onChanged: (value) => setState(() => _sort = value ?? _sort),
              child: Column(
                children: [
                  for (final sort in ListingSort.values)
                    RadioListTile<ListingSort>(
                      value: sort,
                      contentPadding: EdgeInsets.zero,
                      title: Text(sort.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Show results',
              icon: Icons.check,
              onPressed: _apply,
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                ListingQuery(
                  categoryId: widget.current.categoryId,
                  text: widget.current.text,
                ),
              ),
              child: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }
}
