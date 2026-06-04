import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/utils/cookability.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/recipe.dart';

Recipe _recipe(List<String> ingredientNames) => Recipe(
      uuid: 'r',
      name: 'R',
      description: '',
      preparationTime: 0,
      cookingTime: 0,
      servings: 1,
      isInMealPlan: false,
      ingredients: [
        for (final n in ingredientNames)
          Ingredient(quantity: 1, detail: IngredientDetail(name: n)),
      ],
      steps: const [],
      labels: const [],
    );

void main() {
  group('cookabilityOf', () {
    test('ready when every ingredient is in the pantry', () {
      final c = cookabilityOf(_recipe(['flour', 'eggs']), {'flour', 'eggs', 'salt'});
      expect(c.total, 2);
      expect(c.have, 2);
      expect(c.missing, 0);
      expect(c.ready, isTrue);
    });

    test('counts missing ingredients and is not ready', () {
      final c = cookabilityOf(_recipe(['flour', 'eggs', 'milk']), {'flour'});
      expect(c.have, 1);
      expect(c.missing, 2);
      expect(c.ready, isFalse);
    });

    test('a recipe with no ingredients is never ready', () {
      final c = cookabilityOf(_recipe([]), {'flour'});
      expect(c.total, 0);
      expect(c.ready, isFalse);
    });

    test('empty pantry means everything is missing', () {
      final c = cookabilityOf(_recipe(['flour', 'eggs']), const {});
      expect(c.have, 0);
      expect(c.missing, 2);
    });
  });
}
