import 'package:flutter/material.dart';
import '../../domain/label.dart';
import '../styles/label_colours.dart';

/// A single rounded label chip used in the recipe details header.
class RecipeLabelChip extends StatelessWidget {
  final Label label;

  const RecipeLabelChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final tone = labelToneFor(context, label.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelDisplayName(label.name).toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: tone.foreground,
        ),
      ),
    );
  }
}
