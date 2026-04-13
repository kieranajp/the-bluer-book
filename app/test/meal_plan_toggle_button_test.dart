import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/widgets/meal_plan_toggle_button.dart';
import 'package:app/application/styles/colours.dart';

Widget wrapInApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const [Colours.light],
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('MealPlanStarIcon', () {
    testWidgets('renders star_border icon when not favourite', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MealPlanStarIcon(uuid: 'test-uuid', isFavourite: false),
      ));

      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('renders filled star icon when favourite', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MealPlanStarIcon(uuid: 'test-uuid', isFavourite: true),
      ));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('has minimum 48dp touch target', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MealPlanStarIcon(uuid: 'test-uuid', isFavourite: false),
      ));

      // Verify the rendered size is at least 48x48dp (Android minimum)
      final size = tester.getSize(find.byType(MealPlanStarIcon));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('MealPlanFullButton', () {
    testWidgets('shows "Add to Meal Plan" when not favourite', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MealPlanFullButton(uuid: 'test-uuid', isFavourite: false),
      ));

      expect(find.text('Add to Meal Plan'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('shows "Remove from Meal Plan" when favourite',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MealPlanFullButton(uuid: 'test-uuid', isFavourite: true),
      ));

      expect(find.text('Remove from Meal Plan'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('button has 48dp height', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MealPlanFullButton(uuid: 'test-uuid', isFavourite: false),
      ));

      final size = tester.getSize(find.byType(ElevatedButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
