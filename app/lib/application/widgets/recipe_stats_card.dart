import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';
import '../utils/time_format.dart';
import 'recipe_stat_cell.dart';
import 'recipe_stat_divider.dart';

/// Three-stat tonal card: Prep / Cook / Serves. Each icon sits in a different
/// shape — squircle, blob, diamond — to demonstrate the Shape DNA rules.
class RecipeStatsCard extends StatelessWidget {
  final int preparationTime;
  final int cookingTime;
  final int servings;

  const RecipeStatsCard({
    super.key,
    required this.preparationTime,
    required this.cookingTime,
    required this.servings,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: RecipeStatCell(
                icon: Icons.schedule,
                value: formatMinutes(preparationTime),
                label: 'PREP',
                background: c.primaryContainer,
                foreground: c.onPrimaryContainer,
                shape: BorderRadius.circular(14), // squircle
              ),
            ),
            const RecipeStatDivider(),
            Expanded(
              child: RecipeStatCell(
                icon: Icons.local_fire_department_rounded,
                value: formatMinutes(cookingTime),
                label: 'COOK',
                background: c.tertiaryContainer,
                foreground: c.onTertiaryContainer,
                shape: Shapes.blob(44), // blob
              ),
            ),
            const RecipeStatDivider(),
            Expanded(
              child: RecipeStatCell(
                icon: Icons.people_alt_outlined,
                value: '$servings',
                label: 'SERVES',
                background: c.secondaryContainer,
                foreground: c.onSecondaryContainer,
                shape: Shapes.diamondish, // diamond-ish
              ),
            ),
          ],
        ),
      ),
    );
  }
}
