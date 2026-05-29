import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// M3 Expressive segmented control: rounded pill of tabs with the active one
/// sitting on a raised surface and showing a tonal count badge.
class RecipeTabBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabSelected;
  final int ingredientCount;
  final int stepCount;

  const RecipeTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    this.ingredientCount = 0,
    this.stepCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                label: 'Ingredients',
                count: ingredientCount,
                active: selectedTab == 0,
                onTap: () => onTabSelected(0),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Segment(
                label: 'Method',
                count: stepCount,
                active: selectedTab == 1,
                onTap: () => onTabSelected(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.background : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? c.textPrimary : c.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? c.secondaryContainer
                      : c.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? c.onSecondaryContainer
                        : c.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
