import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../styles/decorations.dart';
import '../../styles/text_styles.dart';

/// Shared styled text field used across the [EditRecipeScreen] sections.
class EditRecipeFormField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const EditRecipeFormField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: Decorations.input(context, label),
      style: TextStyles.body(context),
      maxLines: maxLines ?? 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }
}
