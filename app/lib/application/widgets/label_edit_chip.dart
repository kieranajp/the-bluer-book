import 'package:flutter/material.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/colours.dart';
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
    final bgColor = _parseColor(label.colour) ??
        context.colours.primary.withValues(alpha: 0.1);
    final textColor = _parseColor(label.colour) != null
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

  Color? _parseColor(String hex) {
    if (hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
