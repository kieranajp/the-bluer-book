import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/application/providers/pantry_providers.dart';
import 'package:app/application/providers/recipe_providers.dart';
import 'package:app/application/screens/recipe_details_screen.dart';
import 'package:app/domain/recipe.dart';

import 'golden_support.dart';

/// A recipe-list notifier pinned to a fixed list, so RecipeDetailsScreen — which
/// watches [recipeListProvider] — renders immediately without the real notifier
/// firing a network request on build.
class _FixedRecipeList extends RecipeListNotifier {
  _FixedRecipeList(this._recipes);

  final List<Recipe> _recipes;

  @override
  AsyncValue<List<Recipe>> build() => AsyncValue.data(_recipes);
}

// Render the screen at a phone size so the scrolling layout (hero, header,
// stats, tabs, ingredients) lays out as it would on device.
Widget _phone(Widget child) => SizedBox(width: 390, height: 844, child: child);

void main() {
  final recipe = sampleRecipe(isInMealPlan: true);

  goldenTest(
    'RecipeDetailsScreen renders the recipe view',
    fileName: 'recipe_details',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        for (final brightness in Brightness.values)
          themedScenario(
            name: brightness == Brightness.light ? 'light' : 'dark',
            brightness: brightness,
            child: ProviderScope(
              overrides: [
                pantryProvider.overrideWith(() => FixedPantry(const {'ripe tomatoes', 'onion'})),
                recipeListProvider.overrideWith(() => _FixedRecipeList([recipe])),
              ],
              child: _phone(RecipeDetailsScreen(recipe: recipe)),
            ),
          ),
      ],
    ),
  );
}
