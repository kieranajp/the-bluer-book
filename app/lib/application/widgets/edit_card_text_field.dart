import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../styles/decorations.dart';
import '../styles/text_styles.dart';

/// A plain text field styled for the edit-recipe cards. Uncontrolled — seeds
/// from [value] and reports edits via [onChanged].
class EditCardTextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const EditCardTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: Decorations.input(context, label),
      style: TextStyles.body(context),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }
}
