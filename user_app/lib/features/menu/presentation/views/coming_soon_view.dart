import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state_view.dart';

/// Placeholder for menu entries whose feature arrives in a later milestone.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: EmptyStateView(
      icon: icon,
      title: 'Coming soon',
      message: '$title will be available in a future update.',
    ),
  );
}
