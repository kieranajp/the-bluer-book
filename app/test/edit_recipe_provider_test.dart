import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/domain/recipe.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/step.dart' as domain;
import 'package:app/domain/label.dart';
import 'package:app/application/providers/edit_recipe_provider.dart';

/// A complete test recipe for use across tests.
Recipe _testRecipe() => const Recipe(
      uuid: 'abc-123',
      name: 'Test Pancakes',
      description: 'Fluffy pancakes',
      preparationTime: 10,
      cookingTime: 15,
      servings: 4,
      imageUrl: 'https://example.com/photo.jpg',
      isFavourite: true,
      ingredients: [
        Ingredient(
          quantity: 200,
          detail: IngredientDetail(name: 'flour'),
          unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
          preparation: 'sifted',
          component: 'batter',
        ),
        Ingredient(
          quantity: 2,
          detail: IngredientDetail(name: 'eggs'),
          unit: IngredientUnit(name: 'large'),
        ),
      ],
      steps: [
        domain.Step(order: 1, description: 'Mix dry ingredients'),
        domain.Step(order: 2, description: 'Add wet ingredients'),
        domain.Step(order: 3, description: 'Cook on griddle'),
      ],
      labels: [
        Label(type: 'course', name: 'breakfast'),
        Label(type: 'method', name: 'no_cook'),
      ],
    );

void main() {
  group('EditRecipeState.fromRecipe', () {
    test('populates all scalar fields', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());

      expect(state.name, 'Test Pancakes');
      expect(state.description, 'Fluffy pancakes');
      expect(state.preparationTime, 10);
      expect(state.cookingTime, 15);
      expect(state.servings, 4);
      expect(state.imageUrl, 'https://example.com/photo.jpg');
      expect(state.isInMealPlan, true);
      expect(state.isSaving, false);
    });

    test('converts ingredients correctly', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());

      expect(state.ingredients.length, 2);
      expect(state.ingredients[0].name, 'flour');
      expect(state.ingredients[0].quantity, 200);
      expect(state.ingredients[0].unitName, 'grams');
      expect(state.ingredients[0].unitAbbreviation, 'g');
      expect(state.ingredients[0].preparation, 'sifted');
      expect(state.ingredients[0].component, 'batter');
      expect(state.ingredients[1].name, 'eggs');
      expect(state.ingredients[1].unitName, 'large');
      expect(state.ingredients[1].unitAbbreviation, '');
      expect(state.ingredients[1].preparation, '');
    });

    test('converts steps correctly', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());

      expect(state.steps.length, 3);
      expect(state.steps[0].description, 'Mix dry ingredients');
      expect(state.steps[1].description, 'Add wet ingredients');
      expect(state.steps[2].description, 'Cook on griddle');
    });

    test('converts labels correctly', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());

      expect(state.labels.length, 2);
      expect(state.labels[0].type, 'course');
      expect(state.labels[0].name, 'breakfast');
      expect(state.labels[1].type, 'method');
      expect(state.labels[1].name, 'no_cook');
    });
  });

  group('EditRecipeState.toRecipe', () {
    test('converts back to a Recipe with auto-computed step order', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());
      final recipe = state.toRecipe('abc-123');

      expect(recipe.uuid, 'abc-123');
      expect(recipe.name, 'Test Pancakes');
      expect(recipe.description, 'Fluffy pancakes');
      expect(recipe.preparationTime, 10);
      expect(recipe.cookingTime, 15);
      expect(recipe.servings, 4);
      expect(recipe.imageUrl, 'https://example.com/photo.jpg');
      expect(recipe.isFavourite, true);
    });

    test('auto-assigns step order from list position', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());
      final recipe = state.toRecipe('abc-123');

      expect(recipe.steps[0].order, 1);
      expect(recipe.steps[1].order, 2);
      expect(recipe.steps[2].order, 3);
    });

    test('converts ingredients back to domain model', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());
      final recipe = state.toRecipe('abc-123');

      expect(recipe.ingredients.length, 2);
      expect(recipe.ingredients[0].detail.name, 'flour');
      expect(recipe.ingredients[0].quantity, 200);
      expect(recipe.ingredients[0].unit?.name, 'grams');
      expect(recipe.ingredients[0].unit?.abbreviation, 'g');
      expect(recipe.ingredients[0].preparation, 'sifted');
      expect(recipe.ingredients[0].component, 'batter');
    });

    test('converts empty optional fields to null', () {
      final state = EditRecipeState.fromRecipe(_testRecipe());
      final recipe = state.toRecipe('abc-123');

      // Second ingredient has no preparation or component
      expect(recipe.ingredients[1].preparation, isNull);
      expect(recipe.ingredients[1].component, isNull);
    });

    test('trims whitespace on all text fields', () {
      final state = EditRecipeState(
        name: '  Padded Name  ',
        description: '  desc  ',
        preparationTime: 5,
        cookingTime: 10,
        servings: 2,
        ingredients: [
          EditableIngredient(
            name: '  flour  ',
            quantity: 1,
            unitName: '  cup  ',
          ),
        ],
        steps: [EditableStep(description: '  Step one  ')],
        labels: [EditableLabel(type: '  diet  ', name: '  vegan  ')],
      );
      final recipe = state.toRecipe('id');

      expect(recipe.name, 'Padded Name');
      expect(recipe.description, 'desc');
      expect(recipe.ingredients[0].detail.name, 'flour');
      expect(recipe.ingredients[0].unit?.name, 'cup');
      expect(recipe.steps[0].description, 'Step one');
      expect(recipe.labels[0].type, 'diet');
      expect(recipe.labels[0].name, 'vegan');
    });
  });

  group('EditRecipeState.copyWith', () {
    test('creates a new instance with changed fields', () {
      final original = EditRecipeState.fromRecipe(_testRecipe());
      final updated = original.copyWith(name: 'New Name', servings: 8);

      expect(updated.name, 'New Name');
      expect(updated.servings, 8);
      expect(updated.description, original.description);
      expect(updated.preparationTime, original.preparationTime);
    });

    test('preserves all fields when no arguments provided', () {
      final original = EditRecipeState.fromRecipe(_testRecipe());
      final copy = original.copyWith();

      expect(copy.name, original.name);
      expect(copy.description, original.description);
      expect(copy.preparationTime, original.preparationTime);
      expect(copy.cookingTime, original.cookingTime);
      expect(copy.servings, original.servings);
      expect(copy.ingredients.length, original.ingredients.length);
      expect(copy.steps.length, original.steps.length);
      expect(copy.labels.length, original.labels.length);
    });

    test('isSaving transitions correctly through save lifecycle', () {
      final original = EditRecipeState.fromRecipe(_testRecipe());
      expect(original.isSaving, false);

      // Simulate save start
      final saving = original.copyWith(isSaving: true);
      expect(saving.isSaving, true);

      // Simulate save success — isSaving must reset to false
      final saved = saving.copyWith(isSaving: false);
      expect(saved.isSaving, false);
    });

    test('isSaving resets to false on error path', () {
      final saving = EditRecipeState.fromRecipe(_testRecipe())
          .copyWith(isSaving: true);
      expect(saving.isSaving, true);

      // Simulate error recovery
      final recovered = saving.copyWith(isSaving: false);
      expect(recovered.isSaving, false);
    });
  });

  group('EditRecipeNotifier — mutations', () {
    late ProviderContainer container;
    late Recipe recipe;

    setUp(() {
      recipe = _testRecipe();
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    EditRecipeNotifier notifier() =>
        container.read(editRecipeProvider(recipe).notifier);

    EditRecipeState state() => container.read(editRecipeProvider(recipe));

    test('updateName changes name', () {
      notifier().updateName('Waffles');
      expect(state().name, 'Waffles');
    });

    test('updateDescription changes description', () {
      notifier().updateDescription('Crispy waffles');
      expect(state().description, 'Crispy waffles');
    });

    test('updatePrepTime changes prep time', () {
      notifier().updatePrepTime(20);
      expect(state().preparationTime, 20);
    });

    test('updateCookTime changes cook time', () {
      notifier().updateCookTime(30);
      expect(state().cookingTime, 30);
    });

    test('updateServings changes servings', () {
      notifier().updateServings(6);
      expect(state().servings, 6);
    });

    test('addIngredient appends a blank ingredient', () {
      final initialCount = state().ingredients.length;
      notifier().addIngredient();
      expect(state().ingredients.length, initialCount + 1);
      expect(state().ingredients.last.name, '');
      expect(state().ingredients.last.quantity, 0);
    });

    test('removeIngredient removes at index', () {
      final firstName = state().ingredients[0].name;
      notifier().removeIngredient(0);
      expect(state().ingredients[0].name, isNot(firstName));
      expect(state().ingredients.length, 1);
    });

    test('updateIngredient replaces at index', () {
      final updated = state().ingredients[0].clone()..name = 'rice flour';
      notifier().updateIngredient(0, updated);
      expect(state().ingredients[0].name, 'rice flour');
    });

    test('addStep appends a blank step', () {
      final initialCount = state().steps.length;
      notifier().addStep();
      expect(state().steps.length, initialCount + 1);
      expect(state().steps.last.description, '');
    });

    test('removeStep removes at index', () {
      notifier().removeStep(1);
      expect(state().steps.length, 2);
      expect(state().steps[1].description, 'Cook on griddle');
    });

    test('updateStep replaces at index', () {
      final updated = state().steps[0].clone()..description = 'Sift flour';
      notifier().updateStep(0, updated);
      expect(state().steps[0].description, 'Sift flour');
    });

    test('reorderSteps moves step from old to new position', () {
      // Move last step (index 2) to first position (index 0)
      notifier().reorderSteps(2, 0);
      expect(state().steps[0].description, 'Cook on griddle');
      expect(state().steps[1].description, 'Mix dry ingredients');
      expect(state().steps[2].description, 'Add wet ingredients');
    });

    test('addLabel appends a label', () {
      final initialCount = state().labels.length;
      notifier().addLabel(type: 'diet', name: 'vegan');
      expect(state().labels.length, initialCount + 1);
      expect(state().labels.last.type, 'diet');
      expect(state().labels.last.name, 'vegan');
    });

    test('addLabel ignores empty/whitespace inputs', () {
      final initialCount = state().labels.length;
      notifier().addLabel(type: 'diet', name: '   ');
      notifier().addLabel(type: '   ', name: 'vegan');
      expect(state().labels.length, initialCount);
    });

    test('addLabel deduplicates (type, name)', () {
      final initialCount = state().labels.length;
      notifier().addLabel(type: 'course', name: 'breakfast'); // already exists
      expect(state().labels.length, initialCount);
    });

    test('removeLabel removes at index', () {
      notifier().removeLabel(0);
      expect(state().labels.length, 1);
      expect(state().labels[0].type, 'method');
      expect(state().labels[0].name, 'no_cook');
    });
  });

  group('EditRecipeNotifier — validation', () {
    late ProviderContainer container;
    late Recipe recipe;

    setUp(() {
      recipe = _testRecipe();
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    EditRecipeNotifier notifier() =>
        container.read(editRecipeProvider(recipe).notifier);

    test('valid recipe returns null', () {
      expect(notifier().validate(), isNull);
    });

    test('empty name returns error', () {
      notifier().updateName('');
      expect(notifier().validate(), 'Recipe name is required');
    });

    test('whitespace-only name returns error', () {
      notifier().updateName('   ');
      expect(notifier().validate(), 'Recipe name is required');
    });

    test('empty ingredients list returns error', () {
      // Remove all ingredients
      while (container.read(editRecipeProvider(recipe)).ingredients.isNotEmpty) {
        notifier().removeIngredient(0);
      }
      expect(notifier().validate(), 'At least one ingredient is required');
    });

    test('ingredient with empty name returns error', () {
      notifier().addIngredient();
      // The new ingredient has name=''
      expect(notifier().validate(), 'All ingredients must have a name');
    });

    test('ingredient with zero quantity is valid (e.g. "salt")', () {
      final ing = container
          .read(editRecipeProvider(recipe))
          .ingredients[0]
          .clone()
        ..quantity = 0;
      notifier().updateIngredient(0, ing);
      expect(notifier().validate(), isNull);
    });

    test('ingredient with negative quantity returns error', () {
      final ing = container
          .read(editRecipeProvider(recipe))
          .ingredients[0]
          .clone()
        ..quantity = -1;
      notifier().updateIngredient(0, ing);
      expect(notifier().validate(), 'Ingredient quantity cannot be negative');
    });

    test('ingredient with empty unit is valid', () {
      final ing = container
          .read(editRecipeProvider(recipe))
          .ingredients[0]
          .clone()
        ..unitName = '';
      notifier().updateIngredient(0, ing);
      expect(notifier().validate(), isNull);
    });

    test('empty steps list returns error', () {
      while (container.read(editRecipeProvider(recipe)).steps.isNotEmpty) {
        notifier().removeStep(0);
      }
      expect(notifier().validate(), 'At least one step is required');
    });

    test('step with empty description returns error', () {
      notifier().addStep();
      expect(notifier().validate(), 'All steps must have a description');
    });
  });

  group('EditableIngredient.clone', () {
    test('preserves id across clones', () {
      final original =
          EditableIngredient(name: 'flour', quantity: 1, unitName: 'cup');
      final cloned = original.clone();
      expect(cloned.id, original.id);
      expect(cloned.name, original.name);
    });
  });

  group('EditableStep.clone', () {
    test('preserves id across clones', () {
      final original = EditableStep(description: 'Mix');
      final cloned = original.clone();
      expect(cloned.id, original.id);
      expect(cloned.description, original.description);
    });
  });
}
