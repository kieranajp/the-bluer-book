import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

import 'package:app/domain/ingredient.dart';
import 'package:app/domain/pantry_item.dart';
import 'package:app/domain/shopping_list_item.dart';
import 'package:app/application/providers/pantry_providers.dart';
import 'package:app/application/widgets/ingredients_list.dart';
import 'package:app/application/styles/colours.dart';
import 'package:app/infrastructure/pantry_repository.dart';

/// IngredientsList now reads the shared pantry (a ConsumerWidget). Stub it with
/// an empty pantry so these rendering tests don't touch the network.
class _EmptyPantryRepository implements PantryRepository {
  @override
  Future<List<PantryItem>> getPantry() async => const [];

  @override
  Future<void> addToPantry(String ingredient) async {}

  @override
  Future<void> removeFromPantry(String ingredient) async {}

  @override
  Future<List<ShoppingListItem>> getShoppingList() async => const [];

  @override
  Future<void> addCustomShoppingItem(String name) async {}

  @override
  Future<void> removeCustomShoppingItem(String name) async {}

  @override
  Future<List<String>> scanShoppingList(Uint8List bytes, String filename) async =>
      const [];
}

/// The redesigned IngredientsList renders each row as two separate Text
/// widgets: the qty (in a monospace pill on the right) and the name (with
/// optional preparation note appended). These tests assert on both parts.
Widget wrapInApp(Widget child) {
  return ProviderScope(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(_EmptyPantryRepository()),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const [Colours.light],
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('IngredientsList - flat list (no components)', () {
    testWidgets('renders all ingredients as a flat list', (tester) async {
      final ingredients = [
        const Ingredient(
          quantity: 2,
          detail: IngredientDetail(name: 'eggs'),
          unit: IngredientUnit(name: 'large'),
        ),
        const Ingredient(
          quantity: 100,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        IngredientsList(ingredients: ingredients),
      ));

      expect(find.text('2 large'), findsOneWidget);
      expect(find.text('eggs'), findsOneWidget);
      expect(find.text('100 g'), findsOneWidget);
      expect(find.text('flour'), findsOneWidget);
    });

    testWidgets('does not show component headers when no components set', (tester) async {
      final ingredients = [
        const Ingredient(
          quantity: 1,
          detail: IngredientDetail(name: 'salt'),
          unit: IngredientUnit(name: 'teaspoon', abbreviation: 'tsp'),
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        IngredientsList(ingredients: ingredients),
      ));

      // No "For the" headers should appear
      expect(find.textContaining('For the'), findsNothing);
    });
  });

  group('IngredientsList - grouped by component', () {
    testWidgets('renders component headers when ingredients have components', (tester) async {
      final ingredients = [
        const Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
          component: 'batter',
        ),
        const Ingredient(
          quantity: 3,
          detail: IngredientDetail(name: 'soy sauce'),
          unit: IngredientUnit(name: 'tablespoons', abbreviation: 'tbsp'),
          component: 'sauce',
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        IngredientsList(ingredients: ingredients),
      ));

      expect(find.text('For the batter'), findsOneWidget);
      expect(find.text('For the sauce'), findsOneWidget);
      expect(find.text('200 g'), findsOneWidget);
      expect(find.text('flour'), findsOneWidget);
      expect(find.text('3 tbsp'), findsOneWidget);
      expect(find.text('soy sauce'), findsOneWidget);
    });

    testWidgets('uncategorised ingredients appear without header', (tester) async {
      final ingredients = [
        const Ingredient(
          quantity: 1,
          detail: IngredientDetail(name: 'sesame seeds'),
          unit: IngredientUnit(name: 'tablespoon', abbreviation: 'tbsp'),
        ),
        const Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
          component: 'batter',
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        IngredientsList(ingredients: ingredients),
      ));

      // Uncategorised ingredient renders without a header
      expect(find.text('1 tbsp'), findsOneWidget);
      expect(find.text('sesame seeds'), findsOneWidget);
      // Component header only for the batter group
      expect(find.text('For the batter'), findsOneWidget);
      expect(find.text('200 g'), findsOneWidget);
      expect(find.text('flour'), findsOneWidget);
    });

    testWidgets('multiple ingredients group under same component header', (tester) async {
      final ingredients = [
        const Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
          component: 'batter',
        ),
        const Ingredient(
          quantity: 2,
          detail: IngredientDetail(name: 'eggs'),
          unit: IngredientUnit(name: 'large'),
          component: 'batter',
        ),
        const Ingredient(
          quantity: 100,
          detail: IngredientDetail(name: 'water'),
          unit: IngredientUnit(name: 'millilitres', abbreviation: 'ml'),
          component: 'batter',
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        IngredientsList(ingredients: ingredients),
      ));

      // Only one header for the batter component
      expect(find.text('For the batter'), findsOneWidget);
      // All three ingredients render (qty + name pairs)
      expect(find.text('200 g'), findsOneWidget);
      expect(find.text('flour'), findsOneWidget);
      expect(find.text('2 large'), findsOneWidget);
      expect(find.text('eggs'), findsOneWidget);
      expect(find.text('100 ml'), findsOneWidget);
      expect(find.text('water'), findsOneWidget);
    });
  });

  group('IngredientsList - formatting edge cases', () {
    testWidgets('shows preparation note after ingredient name', (tester) async {
      final ingredients = [
        const Ingredient(
          quantity: 1,
          detail: IngredientDetail(name: 'onion'),
          unit: IngredientUnit(name: 'medium'),
          preparation: 'finely diced',
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        IngredientsList(ingredients: ingredients),
      ));

      expect(find.text('1 medium'), findsOneWidget);
      expect(find.text('onion, finely diced'), findsOneWidget);
    });

    testWidgets('handles ingredient with component and preparation', (tester) async {
      final ingredients = [
        const Ingredient(
          quantity: 3,
          detail: IngredientDetail(name: 'garlic cloves'),
          unit: IngredientUnit(name: 'pieces'),
          preparation: 'minced',
          component: 'sauce',
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        IngredientsList(ingredients: ingredients),
      ));

      expect(find.text('For the sauce'), findsOneWidget);
      expect(find.text('3 pieces'), findsOneWidget);
      expect(find.text('garlic cloves, minced'), findsOneWidget);
    });
  });
}
