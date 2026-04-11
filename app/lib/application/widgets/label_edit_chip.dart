import 'package:flutter/material.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../utils/label_colour.dart';

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
    final parsedColor = tryParseLabelColour(label.colour);
    final bgColor = parsedColor ?? context.colours.primary.withValues(alpha: 0.1);
    final textColor = parsedColor != null
        ? _contrastColor(bgColor)
        : context.colours.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Chip(
        label: Text(
          label.name,
          style: TextStyles.tag(context).copyWith(color: textColor),
        ),
        backgroundColor: bgColor,
        deleteIcon: Icon(Icons.close, size: 16, color: textColor),
        onDeleted: onDelete,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
