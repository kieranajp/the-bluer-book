import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import 'package:app/application/widgets/meal_plan_card.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/label.dart';
import 'package:app/domain/recipe.dart';
import 'package:app/domain/step.dart' as domain;

import 'golden_support.dart';

Recipe _recipe() => const Recipe(
      uuid: 'abc-123',
      name: 'Buttermilk Pancakes',
      description: 'Fluffy pancakes',
      preparationTime: 10,
      cookingTime: 15,
      servings: 4,
      // No imageUrl so the card shows its deterministic striped placeholder
      // instead of reaching for the network during the test.
      imageUrl: null,
      isInMealPlan: true,
      ingredients: [
        Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
        ),
      ],
      steps: [
        domain.Step(order: 1, description: 'Mix dry ingredients'),
      ],
      labels: [
        Label(type: 'course', name: 'breakfast'),
      ],
    );

// MealPlanCard fills its grid cell (the image region is Expanded), so give it
// the same bounded box the SliverGrid hands it on screen.
Widget _sized(Widget child) =>
    SizedBox(width: 180, height: 250, child: child);

void main() {
  goldenTest(
    'MealPlanCard renders in light and dark themes',
    fileName: 'meal_plan_card',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        themedScenario(
          name: 'light',
          brightness: Brightness.light,
          child: _sized(MealPlanCard(recipe: _recipe())),
        ),
        themedScenario(
          name: 'dark',
          brightness: Brightness.dark,
          child: _sized(MealPlanCard(recipe: _recipe())),
        ),
        themedScenario(
          name: 'mirrored',
          brightness: Brightness.light,
          child: _sized(MealPlanCard(recipe: _recipe(), mirror: true)),
        ),
      ],
    ),
  );
}
