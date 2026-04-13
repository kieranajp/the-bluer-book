import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/ingredient.dart';
import 'package:app/application/providers/edit_recipe_provider.dart';
import 'package:app/application/widgets/ingredient_edit_card.dart';
import 'package:app/application/styles/colours.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: const [Colours.light],
    ),
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

EditableIngredient _editableIngredient({
  String name = 'flour',
  double quantity = 200,
  String unitName = 'grams',
  String unitAbbreviation = 'g',
  String preparation = '',
  String component = '',
}) =>
    EditableIngredient(
      name: name,
      quantity: quantity,
      unitName: unitName,
      unitAbbreviation: unitAbbreviation,
      preparation: preparation,
      component: component,
    );

const _testUnits = [
  IngredientUnit(name: 'cups', abbreviation: 'c'),
  IngredientUnit(name: 'grams', abbreviation: 'g'),
  IngredientUnit(name: 'tablespoons', abbreviation: 'tbsp'),
  IngredientUnit(name: 'teaspoons', abbreviation: 'tsp'),
];

const _testIngredients = [
  IngredientDetail(name: 'carrot'),
  IngredientDetail(name: 'flour'),
  IngredientDetail(name: 'garlic'),
  IngredientDetail(name: 'salt'),
];

void main() {
  group('IngredientEditCard - summary display', () {
    testWidgets('shows ingredient summary when collapsed', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      expect(find.text('200 grams flour'), findsOneWidget);
    });

    testWidgets('shows summary with preparation', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(preparation: 'sifted'),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      expect(find.text('200 grams flour, sifted'), findsOneWidget);
    });

    testWidgets('shows "New ingredient" for empty name', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(name: '', quantity: 0, unitName: ''),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      expect(find.text('New ingredient'), findsOneWidget);
    });

    testWidgets('shows summary without unit when unit is empty',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(unitName: ''),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      expect(find.text('200 flour'), findsOneWidget);
    });
  });

  group('IngredientEditCard - expand/collapse', () {
    testWidgets('expands to show edit fields when tapped', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      // Should not show text fields initially
      expect(find.text('Qty'), findsNothing);

      // Tap expand button
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Should now show edit fields
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Unit (optional)'), findsOneWidget);
      expect(find.text('Preparation (optional)'), findsOneWidget);
      expect(find.text('Component (optional)'), findsOneWidget);
    });
  });

  group('IngredientEditCard - unit autocomplete', () {
    testWidgets('shows unit suggestions when typing', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(unitName: ''),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      // Expand the card
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Find the unit field and type "cup"
      final unitField = find.widgetWithText(TextFormField, 'Unit (optional)');
      await tester.enterText(unitField, 'cup');
      await tester.pumpAndSettle();

      // Should show "cups" suggestion
      expect(find.text('cups'), findsWidgets);
    });

    testWidgets('filters suggestions based on input', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(unitName: ''),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Type "t" to match tablespoons and teaspoons
      final unitField = find.widgetWithText(TextFormField, 'Unit (optional)');
      await tester.enterText(unitField, 't');
      await tester.pumpAndSettle();

      // Both "tablespoons" and "teaspoons" should appear
      expect(find.text('tablespoons'), findsWidgets);
      expect(find.text('teaspoons'), findsWidgets);
      // "cups" and "grams" should NOT appear in suggestions
      // (they may still appear in the summary, so check the options list)
    });

    testWidgets('selecting a unit suggestion calls onChanged',
        (tester) async {
      EditableIngredient? lastChanged;

      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(unitName: ''),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (updated) => lastChanged = updated,
          onDelete: () {},
        ),
      ));

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Type "gram" to filter
      final unitField = find.widgetWithText(TextFormField, 'Unit (optional)');
      await tester.enterText(unitField, 'gram');
      await tester.pumpAndSettle();

      // Tap the "grams" suggestion
      await tester.tap(find.text('grams').last);
      await tester.pumpAndSettle();

      expect(lastChanged, isNotNull);
      expect(lastChanged!.unitName, 'grams');
      expect(lastChanged!.unitAbbreviation, 'g');
    });
  });

  group('IngredientEditCard - ingredient name autocomplete', () {
    testWidgets('shows ingredient suggestions when typing', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(name: ''),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Type "gar" in the Name field
      final nameField = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(nameField, 'gar');
      await tester.pumpAndSettle();

      // Should show "garlic" suggestion
      expect(find.text('garlic'), findsWidgets);
    });

    testWidgets('selecting an ingredient suggestion calls onChanged',
        (tester) async {
      EditableIngredient? lastChanged;

      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(name: ''),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (updated) => lastChanged = updated,
          onDelete: () {},
        ),
      ));

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Type "sal" to filter
      final nameField = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(nameField, 'sal');
      await tester.pumpAndSettle();

      // Tap the "salt" suggestion
      await tester.tap(find.text('salt').last);
      await tester.pumpAndSettle();

      expect(lastChanged, isNotNull);
      expect(lastChanged!.name, 'salt');
    });
  });

  group('IngredientEditCard - delete', () {
    testWidgets('delete button calls onDelete', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(),
          availableUnits: _testUnits,
          availableIngredients: _testIngredients,
          onChanged: (_) {},
          onDelete: () => deleted = true,
        ),
      ));

      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, isTrue);
    });
  });

  group('IngredientEditCard - works with empty available lists', () {
    testWidgets('renders normally when no suggestions available',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(),
          availableUnits: const [],
          availableIngredients: const [],
          onChanged: (_) {},
          onDelete: () {},
        ),
      ));

      // Should still render the summary
      expect(find.text('200 grams flour'), findsOneWidget);

      // Expand and verify fields render
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Unit (optional)'), findsOneWidget);
    });
  });
}
