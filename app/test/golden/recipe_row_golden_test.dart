import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import 'package:app/application/widgets/recipe_row.dart';

import 'golden_support.dart';

// RecipeRow is a full-width list item; constrain it to a phone-ish width.
Widget _sized(Widget child) => SizedBox(width: 390, child: child);

void main() {
  goldenTest(
    'RecipeRow renders in the all-recipes list',
    fileName: 'recipe_row',
    builder: () => GoldenTestGroup(
      columns: 1,
      // RecipeRow contains a horizontal ListView (the label chips), and a
      // scrolling viewport can't answer intrinsic-width queries. Pin the column
      // to a fixed width so alchemist's layout table doesn't ask for intrinsics.
      columnWidthBuilder: (_) => const FixedColumnWidth(390),
      children: [
        themedScenario(
          name: 'light',
          brightness: Brightness.light,
          child: pantryScope(
            child: _sized(RecipeRow(recipe: sampleRecipe())),
          ),
        ),
        themedScenario(
          name: 'dark',
          brightness: Brightness.dark,
          child: pantryScope(
            child: _sized(RecipeRow(recipe: sampleRecipe())),
          ),
        ),
        themedScenario(
          name: 'in meal plan + ready to cook',
          brightness: Brightness.light,
          // Pantry stocks every ingredient, so the cookability seal reads
          // "ready" (sage check) and the star is filled.
          child: pantryScope(
            pantry: const {'ripe tomatoes', 'onion', 'garlic', 'fresh basil'},
            child: _sized(
              RecipeRow(recipe: sampleRecipe(isInMealPlan: true)),
            ),
          ),
        ),
        themedScenario(
          name: 'partially cookable',
          brightness: Brightness.light,
          // Missing two ingredients → the seal shows the shortfall count.
          child: pantryScope(
            pantry: const {'ripe tomatoes', 'onion'},
            child: _sized(RecipeRow(recipe: sampleRecipe())),
          ),
        ),
      ],
    ),
  );
}
