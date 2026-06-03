import 'package:flutter/material.dart';
import '../styles/colours.dart';
import 'recipe_tab_segment.dart';

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
              child: RecipeTabSegment(
                label: 'Ingredients',
                count: ingredientCount,
                active: selectedTab == 0,
                onTap: () => onTabSelected(0),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: RecipeTabSegment(
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
