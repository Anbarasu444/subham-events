import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Fades the first screen in once so the change from the coloured native
/// splash to the app background is not a hard flash.
class FadeInOnStart extends StatefulWidget {
  const FadeInOnStart({super.key, required this.child});

  final Widget child;

  @override
  State<FadeInOnStart> createState() => _FadeInOnStartState();
}

class _FadeInOnStartState extends State<FadeInOnStart> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _visible ? 1 : 0,
    duration: AppDurations.medium,
    curve: Curves.easeOut,
    child: widget.child,
  );
}
