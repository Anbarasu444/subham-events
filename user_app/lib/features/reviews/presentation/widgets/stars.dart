import 'package:flutter/material.dart';

/// Read-only stars, e.g. ★★★★☆, with a spoken label.
class StarsDisplay extends StatelessWidget {
  const StarsDisplay({super.key, required this.rating, this.size = 18});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$rating out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: color,
            ),
        ],
      ),
    );
  }
}

/// Five tappable stars (48 dp targets).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i ${i == 1 ? 'star' : 'stars'} – ${_labels[i - 1]}',
                isSelected: i <= value,
                iconSize: 36,
                color: theme.colorScheme.primary,
                icon: const Icon(Icons.star_outline_rounded),
                selectedIcon: const Icon(Icons.star_rounded),
                onPressed: () => onChanged(i),
              ),
          ],
        ),
        if (value > 0)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(_labels[value - 1], style: theme.textTheme.labelLarge),
          ),
      ],
    );
  }
}
