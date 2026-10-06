import 'package:flutter/material.dart';

/// Labelled text field that shows server-side validation messages.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      errorText: errorText,
    ),
  );
}
