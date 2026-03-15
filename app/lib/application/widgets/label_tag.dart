import 'package:flutter/material.dart';
import '../../domain/label.dart';
import '../styles/text_styles.dart';
import '../utils/label_colour.dart';

/// A compact label chip used in recipe list items.
class LabelTagCompact extends StatelessWidget {
  final Label label;

  const LabelTagCompact({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = parseLabelColour(label.colour);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.name.toUpperCase(),
        style: TextStyles.tag(context).copyWith(color: color),
      ),
    );
  }
}

/// A larger label chip with a border, used in the recipe detail header.
class LabelTagFull extends StatelessWidget {
  final Label label;

  const LabelTagFull({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = parseLabelColour(label.colour);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label.name.toUpperCase(),
        style: TextStyles.tag(context).copyWith(color: color),
      ),
    );
  }
}
