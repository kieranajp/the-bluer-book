import 'package:flutter/material.dart';
import '../../domain/ingredient.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class IngredientsList extends StatelessWidget {
  final List<Ingredient> ingredients;

  const IngredientsList({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final hasComponents = ingredients.any(
      (i) => i.component != null && i.component!.isNotEmpty,
    );

    if (!hasComponents) {
      return _buildFlatList(context);
    }
    return _buildGroupedList(context);
  }

  Widget _buildFlatList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ingredients.map((ingredient) {
          return _buildIngredientRow(context, ingredient);
        }).toList(),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    // Group ingredients by component, preserving order from the API
    final Map<String, List<Ingredient>> groups = {};
    for (final ingredient in ingredients) {
      final key = (ingredient.component != null && ingredient.component!.isNotEmpty)
          ? ingredient.component!
          : '';
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(ingredient);
    }

    // Uncategorised first, then named components in the order they appear
    final orderedKeys = <String>[];
    if (groups.containsKey('')) {
      orderedKeys.add('');
    }
    for (final key in groups.keys) {
      if (key.isNotEmpty && !orderedKeys.contains(key)) {
        orderedKeys.add(key);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: orderedKeys.expand((component) {
          final items = groups[component]!;
          return [
            if (component.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.s, bottom: Spacing.xs),
                child: Text(
                  'For the $component',
                  style: TextStyles.sectionHeading(context),
                ),
              ),
            ],
            ...items.map((ingredient) => _buildIngredientRow(context, ingredient)),
          ];
        }).toList(),
      ),
    );
  }

  Widget _buildIngredientRow(BuildContext context, Ingredient ingredient) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 12.0),
            child: Icon(
              Icons.circle,
              size: 6,
              color: context.colours.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              _formatIngredient(ingredient),
              style: TextStyles.bodyText(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatIngredient(Ingredient ingredient) {
    final buffer = StringBuffer();

    // Quantity
    if (ingredient.quantity > 0) {
      // Format quantity to remove unnecessary decimals
      if (ingredient.quantity == ingredient.quantity.toInt()) {
        buffer.write(ingredient.quantity.toInt());
      } else {
        buffer.write(ingredient.quantity);
      }
    }

    // Unit
    if (ingredient.unit != null) {
      final unitText = ingredient.unit!.abbreviation?.isNotEmpty == true
          ? ingredient.unit!.abbreviation!
          : ingredient.unit!.name.isNotEmpty
              ? ingredient.unit!.name
              : null;
      if (unitText != null) {
        buffer.write(' $unitText');
      }
    }

    // Ingredient name
    buffer.write(' ${ingredient.detail.name}');

    // Preparation note
    if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty) {
      buffer.write(', ${ingredient.preparation}');
    }

    return buffer.toString().trim();
  }
}
