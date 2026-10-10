import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.inputFormatters,
    this.prefixText,
    this.autofillHints,
    this.maxLength,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onChanged: onChanged,
    inputFormatters: inputFormatters,
    autofillHints: autofillHints,
    maxLength: maxLength,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      errorText: errorText,
      prefixText: prefixText,
      counterText: '',
    ),
  );
}
