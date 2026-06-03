import 'package:flutter/material.dart';
import '../../domain/label.dart';
import '../styles/label_colours.dart';
import '../styles/text_styles.dart';

/// A compact label chip used in recipe list items.
class LabelTagCompact extends StatelessWidget {
  final Label label;

  const LabelTagCompact({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final tone = labelToneFor(context, label.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        labelDisplayName(label.name).toUpperCase(),
        style: TextStyles.tag(context).copyWith(color: tone.foreground),
      ),
    );
  }
}
