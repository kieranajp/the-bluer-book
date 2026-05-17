import 'package:flutter/material.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/label_colours.dart';
import '../styles/text_styles.dart';

class LabelEditChip extends StatelessWidget {
  final EditableLabel label;
  final VoidCallback onDelete;

  const LabelEditChip({
    super.key,
    required this.label,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tone = labelToneFor(context, label.type);

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Chip(
        label: Text(
          '${label.type}:${labelDisplayName(label.name)}',
          style: TextStyles.tag(context).copyWith(color: tone.foreground),
        ),
        backgroundColor: tone.background,
        deleteIcon: Icon(Icons.close, size: 16, color: tone.foreground),
        onDeleted: onDelete,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
