import 'package:flutter/material.dart';

/// Bottom-navigation sections, in display order (M6 user decision).
enum ShellTab {
  home('Home', Icons.home_outlined, Icons.home),
  explore('Explore', Icons.explore_outlined, Icons.explore),
  events('My Events', Icons.event_note_outlined, Icons.event_note),
  menu('Menu', Icons.menu, Icons.menu);

  const ShellTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static ShellTab fromName(String? name) =>
      ShellTab.values.firstWhere((t) => t.name == name, orElse: () => home);
}
