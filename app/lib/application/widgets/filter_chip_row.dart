import 'package:flutter/material.dart';
import '../styles/colours.dart';

class FilterOption {
  final String id;
  final String label;
  final int? count;

  const FilterOption({required this.id, required this.label, this.count});
}

/// Horizontal scrolling row of selectable filter chips.
class FilterChipRow extends StatelessWidget {
  final List<FilterOption> filters;
  final String active;
  final ValueChanged<String> onChanged;

  const FilterChipRow({
    super.key,
    required this.filters,
    required this.active,
    required this.onChanged,
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
            selected: f.id == active,
            onTap: () => onChanged(f.id),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final bg = selected ? c.secondaryContainer : Colors.transparent;
    final fg = selected ? c.onSecondaryContainer : c.textPrimary;
    final border = selected ? Colors.transparent : c.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
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
