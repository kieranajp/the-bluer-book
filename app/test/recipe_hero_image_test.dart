import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/widgets/recipe_hero_image.dart';
import 'package:app/application/styles/colours.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: const [Colours.light],
    ),
    home: Scaffold(
      body: SizedBox(width: 400, height: 300, child: child),
    ),
  );
}

void main() {
  group('RecipeHeroImage', () {
    testWidgets('shows placeholder icon when imageUrl is null', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const RecipeHeroImage(imageUrl: null),
      ));

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('attempts to load Image.network when imageUrl is provided',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        const RecipeHeroImage(imageUrl: 'https://example.com/photo.jpg'),
      ));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders gradient overlay', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const RecipeHeroImage(imageUrl: null),
      ));

      // Should have a gradient container in the Stack
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasGradient = containers.any((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.gradient != null;
      });
      expect(hasGradient, isTrue);
    });
  });
}
