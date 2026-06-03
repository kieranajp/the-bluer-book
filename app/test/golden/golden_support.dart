import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/application/providers/pantry_providers.dart';
import 'package:app/application/styles/app_theme.dart';
import 'package:app/application/styles/colours.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/label.dart';
import 'package:app/domain/recipe.dart';
import 'package:app/domain/step.dart' as domain;

/// A [GoldenTestScenario] that renders [child] under the app's real shipping
/// theme ([buildAppTheme]) for the given [brightness], on the matching
/// background colour. Use this so goldens reflect production theming — the
/// hand-built `ColorScheme` and the `Colours` extension that widgets read via
/// `context.colours` — rather than a bare `ThemeData.light`.
GoldenTestScenario themedScenario({
  required String name,
  required Brightness brightness,
  required Widget child,
}) {
  final colours = brightness == Brightness.light ? Colours.light : Colours.dark;
  return GoldenTestScenario(
    name: name,
    child: Theme(
      data: buildAppTheme(brightness, colours),
      child: ColoredBox(
        color: colours.background,
        // A Material ancestor keeps widgets that expect one (ink, tooltips,
        // default text styling) happy without changing the rendered surface.
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    ),
  );
}

/// A [PantryNotifier] pinned to a fixed set of ingredient names. Overriding
/// [pantryProvider] with this keeps pantry-aware widgets (cookability seals,
/// ingredient "have/missing" styling) deterministic and offline — no async
/// microtask load, no network.
class FixedPantry extends PantryNotifier {
  FixedPantry(this._items);

  final Set<String> _items;

  @override
  AsyncValue<Set<String>> build() => AsyncValue.data(_items);
}

/// Wraps [child] in a [ProviderScope] whose pantry is the fixed [pantry] set,
/// for goldens of widgets that read [pantryProvider]. Tests needing further
/// overrides (e.g. a fixed recipe list) build their own [ProviderScope].
Widget pantryScope({
  Set<String> pantry = const <String>{},
  required Widget child,
}) {
  return ProviderScope(
    overrides: [pantryProvider.overrideWith(() => FixedPantry(pantry))],
    child: child,
  );
}

/// A realistic recipe fixture for goldens. Deterministic and image-less (so the
/// striped placeholder renders instead of a network fetch). Tweak via the args.
Recipe sampleRecipe({
  String name = 'Roast Tomato & Basil Soup',
  String description =
      'A silky, slow-roasted tomato soup finished with torn basil and a swirl of cream.',
  bool isInMealPlan = false,
}) {
  return Recipe(
    uuid: 'sample-1',
    name: name,
    description: description,
    preparationTime: 15,
    cookingTime: 45,
    servings: 4,
    imageUrl: null,
    url: 'https://example.com/tomato-soup',
    isInMealPlan: isInMealPlan,
    ingredients: const [
      Ingredient(
        quantity: 1,
        detail: IngredientDetail(name: 'ripe tomatoes'),
        unit: IngredientUnit(name: 'kilogram', abbreviation: 'kg'),
      ),
      Ingredient(
        quantity: 1,
        detail: IngredientDetail(name: 'onion'),
      ),
      Ingredient(
        quantity: 2,
        detail: IngredientDetail(name: 'garlic'),
        unit: IngredientUnit(name: 'cloves'),
      ),
      Ingredient(
        quantity: 200,
        detail: IngredientDetail(name: 'fresh basil'),
        unit: IngredientUnit(name: 'grams', abbreviation: 'g'),
      ),
    ],
    steps: const [
      domain.Step(order: 1, description: 'Roast the tomatoes, onion and garlic.'),
      domain.Step(order: 2, description: 'Blend with stock until smooth.'),
      domain.Step(order: 3, description: 'Finish with cream and torn basil.'),
    ],
    labels: const [
      Label(type: 'course', name: 'soup'),
      Label(type: 'diet', name: 'vegetarian'),
    ],
  );
}
