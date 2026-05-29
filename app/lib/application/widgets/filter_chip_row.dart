import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/label_colours.dart';

class FilterOption {
  /// Stable identifier — for label chips, this is `type:name`.
  final String id;
  final String label;
  final int? count;

  /// Optional taxonomy type used to colour the chip (course/cuisine/diet/method).
  /// null = neutral.
  final String? type;

  const FilterOption({
    required this.id,
    required this.label,
    this.count,
    this.type,
  });
}

/// Horizontal scrolling row of selectable filter chips. Multi-select.
/// A null `id` in `active` is never matched; pass an empty set for "none selected".
class FilterChipRow extends StatelessWidget {
  final List<FilterOption> filters;
  final Set<String> active;
  final ValueChanged<String> onToggle;

  const FilterChipRow({
    super.key,
    required this.filters,
    required this.active,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          return _Chip(
            label: f.label,
            count: f.count,
            type: f.type,
            selected: active.contains(f.id),
            onTap: () => onToggle(f.id),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final String? type;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
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
