import 'package:flutter/material.dart';
import 'filter_option_chip.dart';

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
          return FilterOptionChip(
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
