import 'package:flutter/material.dart';
import '../../domain/label.dart';
import '../styles/label_colours.dart';
import '../styles/text_styles.dart';

/// A larger label chip with a border, used in the recipe detail header.
class LabelTagFull extends StatelessWidget {
  final Label label;

  const LabelTagFull({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final tone = labelToneFor(context, label.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tone.foreground.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        labelDisplayName(label.name).toUpperCase(),
        style: TextStyles.tag(context).copyWith(color: tone.foreground),
      ),
    );
  }
}
