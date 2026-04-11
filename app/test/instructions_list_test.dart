import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/ingredient.dart';
import 'package:app/domain/step.dart' as domain;
import 'package:app/application/widgets/instructions_list.dart';
import 'package:app/application/styles/colours.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: const [Colours.light],
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('InstructionsList - basic rendering', () {
    testWidgets('renders step numbers and descriptions', (tester) async {
      final steps = [
        const domain.Step(order: 1, description: 'Preheat the oven.'),
        const domain.Step(order: 2, description: 'Mix the batter.'),
      ];

      await tester.pumpWidget(wrapInApp(
        InstructionsList(steps: steps),
      ));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Preheat the oven.'), findsOneWidget);
      expect(find.text('Mix the batter.'), findsOneWidget);
    });

    testWidgets('renders without ingredients (no crash)', (tester) async {
      final steps = [
        const domain.Step(order: 1, description: 'Do something.'),
      ];

      await tester.pumpWidget(wrapInApp(
        InstructionsList(steps: steps),
      ));

      expect(find.text('Do something.'), findsOneWidget);
    });
  });

  group('InstructionsList - ingredient highlighting', () {
    testWidgets('highlights ingredient name in step text', (tester) async {
      final steps = [
        const domain.Step(order: 1, description: 'Add the flour to the bowl.'),
      ];
      final ingredients = [
        const Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        InstructionsList(steps: steps, ingredients: ingredients),
      ));

      // The highlighted "flour" should appear as a separate Text widget
      // inside a Tooltip, plus surrounding plain text spans.
      expect(find.text('flour'), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('shows tooltip with quantity on tap', (tester) async {
      final steps = [
        const domain.Step(order: 1, description: 'Add the flour.'),
      ];
      final ingredients = [
        const Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        InstructionsList(steps: steps, ingredients: ingredients),
      ));

      // Tap the highlighted ingredient to trigger tooltip
      await tester.tap(find.text('flour'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tooltip should show the formatted ingredient
      expect(find.text('200 g flour'), findsOneWidget);
    });

    testWidgets('highlights multiple ingredients in one step', (tester) async {
      final steps = [
        const domain.Step(order: 1, description: 'Mix the flour and sugar.'),
      ];
      final ingredients = [
        const Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
        ),
        const Ingredient(
          quantity: 100,
          detail: IngredientDetail(name: 'sugar'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        InstructionsList(steps: steps, ingredients: ingredients),
      ));

      expect(find.byType(Tooltip), findsNWidgets(2));
    });

    testWidgets('no tooltips when ingredients do not match step text', (tester) async {
      final steps = [
        const domain.Step(order: 1, description: 'Preheat the oven.'),
      ];
      final ingredients = [
        const Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        InstructionsList(steps: steps, ingredients: ingredients),
      ));

      expect(find.byType(Tooltip), findsNothing);
      expect(find.text('Preheat the oven.'), findsOneWidget);
    });

    testWidgets('handles plural matching', (tester) async {
      final steps = [
        const domain.Step(order: 1, description: 'Crack the eggs into the bowl.'),
      ];
      final ingredients = [
        const Ingredient(
          quantity: 3,
          detail: IngredientDetail(name: 'egg'),
          unit: IngredientUnit(name: 'large'),
        ),
      ];

      await tester.pumpWidget(wrapInApp(
        InstructionsList(steps: steps, ingredients: ingredients),
      ));

      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.text('eggs'), findsOneWidget);
    });
  });
}
