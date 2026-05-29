import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('IngredientEditCard - summary display', () {
    testWidgets('shows ingredient summary when collapsed', (tester) async {
      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(),
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

  group('IngredientEditCard - editing', () {
    testWidgets('typing in unit field calls onChanged', (tester) async {
      EditableIngredient? lastChanged;

      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(unitName: ''),
          onChanged: (updated) => lastChanged = updated,
          onDelete: () {},
        ),
      ));

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Type in unit field
      final unitField = find.widgetWithText(TextFormField, 'Unit (optional)');
      await tester.enterText(unitField, 'cups');
      await tester.pumpAndSettle();

      expect(lastChanged, isNotNull);
      expect(lastChanged!.unitName, 'cups');
    });

    testWidgets('typing in name field calls onChanged', (tester) async {
      EditableIngredient? lastChanged;

      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(name: ''),
          onChanged: (updated) => lastChanged = updated,
          onDelete: () {},
        ),
      ));

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Type in name field
      final nameField = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(nameField, 'salt');
      await tester.pumpAndSettle();

      expect(lastChanged, isNotNull);
      expect(lastChanged!.name, 'salt');
    });

    testWidgets('typing in quantity field calls onChanged with parsed number',
        (tester) async {
      EditableIngredient? lastChanged;

      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(),
          onChanged: (updated) => lastChanged = updated,
          onDelete: () {},
        ),
      ));

      // Expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Type in qty field
      final qtyField = find.widgetWithText(TextFormField, 'Qty');
      await tester.enterText(qtyField, '3.5');
      await tester.pumpAndSettle();

      expect(lastChanged, isNotNull);
      expect(lastChanged!.quantity, 3.5);
    });
  });

  group('IngredientEditCard - delete', () {
    testWidgets('delete button calls onDelete', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(wrapInApp(
        IngredientEditCard(
          index: 0,
          ingredient: _editableIngredient(),
          onChanged: (_) {},
          onDelete: () => deleted = true,
        ),
      ));

      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, isTrue);
    });
  });
}
