import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/recipe.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/step.dart' as domain;
import 'package:app/domain/label.dart';
import 'package:app/application/widgets/meal_plan_card.dart';
import 'package:app/application/styles/colours.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: const [Colours.light],
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Recipe _testRecipe({String? imageUrl}) => Recipe(
      uuid: 'abc-123',
      name: 'Test Pancakes',
      description: 'Fluffy pancakes',
      preparationTime: 10,
      cookingTime: 15,
      servings: 4,
      imageUrl: imageUrl,
      isInMealPlan: true,
      ingredients: const [
        Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
        ),
      ],
      steps: const [
        domain.Step(order: 1, description: 'Mix dry ingredients'),
      ],
      labels: const [
        Label(type: 'course', name: 'breakfast'),
      ],
    );

void main() {
  group('MealPlanCard', () {
    testWidgets('shows placeholder icon when recipe has no image',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        MealPlanCard(recipe: _testRecipe(imageUrl: null)),
      ));

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('displays recipe name', (tester) async {
      await tester.pumpWidget(wrapInApp(
        MealPlanCard(recipe: _testRecipe()),
      ));

      expect(find.text('Test Pancakes'), findsOneWidget);
    });

    testWidgets('displays total cooking time', (tester) async {
      await tester.pumpWidget(wrapInApp(
        MealPlanCard(recipe: _testRecipe()),
      ));

      // 10 + 15 = 25 minutes
      expect(find.text('25m'), findsOneWidget);
    });

    testWidgets('shows star icon for favourite recipe', (tester) async {
      await tester.pumpWidget(wrapInApp(
        MealPlanCard(recipe: _testRecipe()),
      ));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('uses ClipRRect for image container', (tester) async {
      await tester.pumpWidget(wrapInApp(
        MealPlanCard(recipe: _testRecipe()),
      ));

      // Verify ClipRRect is used for rounded corners within the card
      expect(
        find.descendant(
          of: find.byType(MealPlanCard),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

  });
}
