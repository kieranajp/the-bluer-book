import '../../domain/ingredient.dart';

/// Formatting and grouping utilities for ingredients.
extension IngredientFormatting on Ingredient {
  /// Formats the ingredient as a human-readable string.
  /// E.g. "200 g flour, sifted"
  String formatted() {
    final buffer = StringBuffer();

    if (quantity > 0) {
      if (quantity == quantity.toInt()) {
        buffer.write(quantity.toInt());
      } else {
        buffer.write(quantity);
      }
    }

    if (unit != null) {
      final unitText = unit!.abbreviation?.isNotEmpty == true
          ? unit!.abbreviation!
          : unit!.name.isNotEmpty
              ? unit!.name
              : null;
      if (unitText != null) {
        buffer.write(' $unitText');
      }
    }

    buffer.write(' ${detail.name}');

    if (preparation != null && preparation!.isNotEmpty) {
      buffer.write(', $preparation');
    }

    return buffer.toString().trim();
  }
}

/// Groups ingredients by component, preserving API order.
/// Uncategorised items (empty/null component) come first, then named
/// components in the order they first appear.
Map<String, List<Ingredient>> groupByComponent(List<Ingredient> ingredients) {
  final Map<String, List<Ingredient>> groups = {};
  for (final ingredient in ingredients) {
    final key = (ingredient.component != null && ingredient.component!.isNotEmpty)
        ? ingredient.component!
        : '';
    groups.putIfAbsent(key, () => []);
    groups[key]!.add(ingredient);
  }

  final ordered = <String, List<Ingredient>>{};
  if (groups.containsKey('')) {
    ordered[''] = groups['']!;
  }
  for (final key in groups.keys) {
    if (key.isNotEmpty) {
      ordered[key] = groups[key]!;
    }
  }
  return ordered;
}
