import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/application/utils/ingredient_highlighter.dart';

Ingredient _ingredient(String name, {double qty = 1, String? unit, String? prep}) {
  return Ingredient(
    quantity: qty,
    detail: IngredientDetail(name: name),
    unit: unit != null ? IngredientUnit(name: unit) : null,
    preparation: prep,
  );
}

void main() {
  group('highlightIngredients', () {
    test('returns single plain segment when no ingredients match', () {
      final segments = highlightIngredients(
        'Preheat the oven to 180C.',
        [_ingredient('flour')],
      );
      expect(segments.length, 1);
      expect(segments[0].text, 'Preheat the oven to 180C.');
      expect(segments[0].isHighlighted, false);
    });

    test('returns single plain segment for empty ingredients list', () {
      final segments = highlightIngredients('Add the flour.', []);
      expect(segments.length, 1);
      expect(segments[0].text, 'Add the flour.');
      expect(segments[0].isHighlighted, false);
    });

    test('returns single plain segment for empty text', () {
      final segments = highlightIngredients('', [_ingredient('flour')]);
      expect(segments.length, 1);
      expect(segments[0].text, '');
    });

    test('highlights a basic exact match', () {
      final segments = highlightIngredients(
        'Add the flour to the bowl.',
        [_ingredient('flour', qty: 200, unit: 'grams')],
      );
      expect(segments.length, 3);
      expect(segments[0].text, 'Add the ');
      expect(segments[0].isHighlighted, false);
      expect(segments[1].text, 'flour');
      expect(segments[1].isHighlighted, true);
      expect(segments[1].ingredient!.detail.name, 'flour');
      expect(segments[2].text, ' to the bowl.');
      expect(segments[2].isHighlighted, false);
    });

    test('matches case-insensitively', () {
      final segments = highlightIngredients(
        'Add the Flour and SUGAR.',
        [_ingredient('flour'), _ingredient('sugar')],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 2);
      expect(highlighted[0].text, 'Flour');
      expect(highlighted[1].text, 'SUGAR');
    });

    test('respects word boundaries — does not match partial words', () {
      final segments = highlightIngredients(
        'Spread the butter evenly.',
        [_ingredient('butt')],
      );
      // "butt" should NOT match inside "butter"
      expect(segments.length, 1);
      expect(segments[0].isHighlighted, false);
    });

    test('handles plural: ingredient "egg" matches "eggs" in text', () {
      final segments = highlightIngredients(
        'Crack the eggs into the bowl.',
        [_ingredient('egg', qty: 3)],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 1);
      expect(highlighted[0].text, 'eggs');
      expect(highlighted[0].ingredient!.detail.name, 'egg');
    });

    test('handles reverse plural: ingredient "eggs" matches "egg" in text', () {
      final segments = highlightIngredients(
        'Add one egg at a time.',
        [_ingredient('eggs', qty: 3)],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 1);
      expect(highlighted[0].text, 'egg');
    });

    test('handles -es plural: "tomato" matches "tomatoes"', () {
      final segments = highlightIngredients(
        'Dice the tomatoes.',
        [_ingredient('tomato', qty: 2)],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 1);
      expect(highlighted[0].text, 'tomatoes');
    });

    test('handles -ies/-y plural: "cherry" matches "cherries"', () {
      final segments = highlightIngredients(
        'Pit the cherries.',
        [_ingredient('cherry', qty: 10)],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 1);
      expect(highlighted[0].text, 'cherries');
    });

    test('handles -ies/-y reverse: "cherries" matches "cherry"', () {
      final segments = highlightIngredients(
        'Add a cherry on top.',
        [_ingredient('cherries', qty: 10)],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 1);
      expect(highlighted[0].text, 'cherry');
    });

    test('longest name wins: "soy sauce" matches before "soy"', () {
      final segments = highlightIngredients(
        'Add the soy sauce and soy milk.',
        [_ingredient('soy'), _ingredient('soy sauce')],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 2);
      expect(highlighted[0].text, 'soy sauce');
      expect(highlighted[0].ingredient!.detail.name, 'soy sauce');
      expect(highlighted[1].text, 'soy');
      expect(highlighted[1].ingredient!.detail.name, 'soy');
    });

    test('multiple ingredients in one step', () {
      final segments = highlightIngredients(
        'Mix the flour, sugar, and salt together.',
        [_ingredient('flour'), _ingredient('sugar'), _ingredient('salt')],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 3);
      expect(highlighted.map((s) => s.text).toSet(), {'flour', 'sugar', 'salt'});
    });

    test('same ingredient appearing multiple times', () {
      final segments = highlightIngredients(
        'Add flour, then add more flour.',
        [_ingredient('flour')],
      );
      final highlighted = segments.where((s) => s.isHighlighted).toList();
      expect(highlighted.length, 2);
      expect(highlighted[0].text, 'flour');
      expect(highlighted[1].text, 'flour');
    });

    test('ingredient at start of text', () {
      final segments = highlightIngredients(
        'Flour goes in first.',
        [_ingredient('flour')],
      );
      expect(segments[0].text, 'Flour');
      expect(segments[0].isHighlighted, true);
    });

    test('ingredient at end of text', () {
      final segments = highlightIngredients(
        'Finally add the flour',
        [_ingredient('flour')],
      );
      expect(segments.last.text, 'flour');
      expect(segments.last.isHighlighted, true);
    });
  });

  group('ingredientsInStep', () {
    test('returns only the ingredients mentioned in the step', () {
      final result = ingredientsInStep(
        'Whisk the eggs into the flour.',
        [_ingredient('flour'), _ingredient('sugar'), _ingredient('egg')],
      );
      expect(result.map((i) => i.detail.name), ['egg', 'flour']);
    });

    test('preserves order of first appearance', () {
      final result = ingredientsInStep(
        'Add the sugar, then the flour.',
        [_ingredient('flour'), _ingredient('sugar')],
      );
      expect(result.map((i) => i.detail.name), ['sugar', 'flour']);
    });

    test('dedupes an ingredient mentioned multiple times', () {
      final result = ingredientsInStep(
        'Add flour, then add more flour.',
        [_ingredient('flour')],
      );
      expect(result.length, 1);
      expect(result.first.detail.name, 'flour');
    });

    test('returns empty when nothing matches', () {
      final result = ingredientsInStep(
        'Preheat the oven to 180C.',
        [_ingredient('flour')],
      );
      expect(result, isEmpty);
    });
  });

  group('formatIngredientQuantity', () {
    test('formats quantity with unit abbreviation', () {
      final result = formatIngredientQuantity(Ingredient(
        quantity: 200,
        detail: const IngredientDetail(name: 'flour'),
        unit: const IngredientUnit(name: 'grams', abbreviation: 'g'),
      ));
      expect(result, '200 g');
    });

    test('falls back to unit name without abbreviation', () {
      final result = formatIngredientQuantity(Ingredient(
        quantity: 2,
        detail: const IngredientDetail(name: 'eggs'),
        unit: const IngredientUnit(name: 'large'),
      ));
      expect(result, '2 large');
    });

    test('omits unit when none and drops trailing decimals', () {
      final result = formatIngredientQuantity(const Ingredient(
        quantity: 3,
        detail: IngredientDetail(name: 'eggs'),
      ));
      expect(result, '3');
    });

    test('returns empty string when there is nothing to show', () {
      final result = formatIngredientQuantity(const Ingredient(
        quantity: 0,
        detail: IngredientDetail(name: 'salt'),
      ));
      expect(result, '');
    });
  });

  group('formatIngredientTooltip', () {
    test('formats quantity and unit abbreviation', () {
      final result = formatIngredientTooltip(Ingredient(
        quantity: 200,
        detail: const IngredientDetail(name: 'flour'),
        unit: const IngredientUnit(name: 'grams', abbreviation: 'g'),
      ));
      expect(result, '200 g flour');
    });

    test('formats with unit name when no abbreviation', () {
      final result = formatIngredientTooltip(Ingredient(
        quantity: 2,
        detail: const IngredientDetail(name: 'eggs'),
        unit: const IngredientUnit(name: 'large'),
      ));
      expect(result, '2 large eggs');
    });

    test('includes preparation note', () {
      final result = formatIngredientTooltip(Ingredient(
        quantity: 1,
        detail: const IngredientDetail(name: 'onion'),
        unit: const IngredientUnit(name: 'medium'),
        preparation: 'finely diced',
      ));
      expect(result, '1 medium onion, finely diced');
    });

    test('handles zero quantity', () {
      final result = formatIngredientTooltip(const Ingredient(
        quantity: 0,
        detail: IngredientDetail(name: 'salt'),
      ));
      expect(result, 'salt');
    });

    test('formats integer quantities without decimals', () {
      final result = formatIngredientTooltip(Ingredient(
        quantity: 3.0,
        detail: const IngredientDetail(name: 'eggs'),
      ));
      expect(result, '3 eggs');
    });

    test('preserves decimal quantities', () {
      final result = formatIngredientTooltip(Ingredient(
        quantity: 1.5,
        detail: const IngredientDetail(name: 'lemons'),
        unit: const IngredientUnit(name: 'whole'),
      ));
      expect(result, '1.5 whole lemons');
    });
  });
}
