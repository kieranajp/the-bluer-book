import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/label.dart';
import 'package:app/domain/recipe.dart';

void main() {
  test('Label parses real API JSON', () {
    final l = Label.fromJson({
      'type': 'course',
      'name': 'drink',
      'createdAt': '0001-01-01T00:00:00Z',
      'updatedAt': '0001-01-01T00:00:00Z',
    });
    expect(l.type, 'course');
    expect(l.name, 'drink');
  });

  test('LabelSummary parses real API JSON', () {
    final l = LabelSummary.fromJson({
      'type': 'course',
      'name': 'main',
      'uses': 10,
    });
    expect(l.key, 'course:main');
  });

  test('Recipe parses real API JSON', () {
    final json = {
      'uuid': '29600e44-d77e-4e4a-a7ee-534048ccfaff',
      'name': 'Apple, Lemon & Ginger Juice',
      'description': 'desc',
      'cookTime': 0,
      'prepTime': 3,
      'servings': 1,
      'mainPhoto': null,
      'isInMealPlan': false,
      'steps': [
        {'order': 1, 'description': 'wash', 'photos': null, 'createdAt': '0001-01-01T00:00:00Z'},
      ],
      'ingredients': [
        {
          'ingredient': {'name': 'fresh ginger', 'createdAt': '0001-01-01T00:00:00Z'},
          'unit': {'name': 'inch', 'abbreviation': ''},
          'quantity': 1,
          'preparation': '',
          'component': '',
        }
      ],
      'labels': [
        {'type': 'course', 'name': 'drink', 'createdAt': '0001-01-01T00:00:00Z'},
        {'type': 'diet', 'name': 'low_fodmap'},
      ],
    };
    final r = Recipe.fromJson(json);
    expect(r.labels.length, 2);
    expect(r.labels.first.type, 'course');
  });
}
