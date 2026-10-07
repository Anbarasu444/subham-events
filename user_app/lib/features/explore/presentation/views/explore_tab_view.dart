import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state_view.dart';

/// Explore tab: vendor discovery arrives in M12–M13.
class ExploreTabView extends StatelessWidget {
  const ExploreTabView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore')),
    body: const EmptyStateView(
      icon: Icons.storefront_outlined,
      title: 'Find vendors for your event',
      message:
          'Browse photographers, caterers, decorators and more — coming soon.',
    ),
  );
}
