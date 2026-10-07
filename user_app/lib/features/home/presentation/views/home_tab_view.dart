import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state_view.dart';

/// Home tab. The dashboard content arrives in M7.
class HomeTabView extends StatelessWidget {
  const HomeTabView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Event Planner')),
    body: const EmptyStateView(
      icon: Icons.celebration_outlined,
      title: 'Welcome',
      message:
          'Your upcoming events, checklist and budget will appear here soon.',
    ),
  );
}
