import 'package:flutter/material.dart';

/// Nested navigator for one tab; its root page is [root].
class TabNavigator extends StatelessWidget {
  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.root,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder root;

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    onGenerateRoute: (settings) =>
        MaterialPageRoute<void>(settings: settings, builder: root),
  );
}
