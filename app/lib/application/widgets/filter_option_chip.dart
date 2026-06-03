import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/label_colours.dart';

/// A single selectable chip in the [FilterChipRow]. Tonal when selected
/// (coloured by taxonomy [type] when given), outlined when not.
class FilterOptionChip extends StatelessWidget {
  final String label;
  final int? count;
  final String? type;
  final bool selected;
  final VoidCallback onTap;

  const FilterOptionChip({
    super.key,
    required this.label,
    this.count,
    this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final tone = type == null ? null : labelToneFor(context, type!);

    final Color bg;
    final Color fg;
    final Color borderColor;
    if (selected) {
      bg = tone?.background ?? c.secondaryContainer;
      fg = tone?.foreground ?? c.onSecondaryContainer;
      borderColor = Colors.transparent;
    } else {
      bg = Colors.transparent;
      fg = c.textPrimary;
      borderColor = c.outlineVariant;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
              if (count != null)
                TextSpan(
                  text: ' · $count',
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
