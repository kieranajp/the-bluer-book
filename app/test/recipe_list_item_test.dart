import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/recipe.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/step.dart' as domain;
import 'package:app/domain/label.dart';
import 'package:app/application/widgets/recipe_list_item.dart';
import 'package:app/application/styles/colours.dart';

Widget wrapInApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const [Colours.light],
      ),
      home: Scaffold(body: child),
    ),
  );
}

Recipe _testRecipe({String? imageUrl, bool isFavourite = false}) => Recipe(
      uuid: 'abc-123',
      name: 'Test Pancakes',
      description: 'Fluffy pancakes for the whole family',
      preparationTime: 10,
      cookingTime: 15,
      servings: 4,
      imageUrl: imageUrl,
      isFavourite: isFavourite,
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
        Label(name: 'Breakfast', colour: '#FF9800'),
      ],
    );

void main() {
  group('RecipeListItem', () {
    testWidgets('displays recipe name', (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe()),
      ));

      expect(find.text('Test Pancakes'), findsOneWidget);
    });

    testWidgets('displays recipe description', (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe()),
      ));

      expect(
          find.text('Fluffy pancakes for the whole family'), findsOneWidget);
    });

    testWidgets('displays total time', (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe()),
      ));

      expect(find.text('25m'), findsOneWidget);
    });

    testWidgets('shows placeholder icon when no image URL', (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe(imageUrl: null)),
      ));

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('uses ClipRRect for thumbnail', (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe(imageUrl: null)),
      ));

      expect(
        find.descendant(
          of: find.byType(RecipeListItem),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays label tags', (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe()),
      ));

      expect(find.text('BREAKFAST'), findsOneWidget);
    });

    testWidgets('shows filled star when recipe is favourite', (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe(isFavourite: true)),
      ));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('shows star border when recipe is not favourite',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        RecipeListItem(recipe: _testRecipe(isFavourite: false)),
      ));

      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });
  });
}
