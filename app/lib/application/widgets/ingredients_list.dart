import 'package:flutter/material.dart';
import '../../domain/ingredient.dart';
import '../utils/ingredient_formatting.dart';
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
    final groups = groupByComponent(ingredients);

    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.entries.expand((entry) {
          return [
            if (entry.key.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.s, bottom: Spacing.xs),
                child: Text(
                  'For the ${entry.key}',
                  style: TextStyles.sectionHeading(context),
                ),
              ),
            ],
            ...entry.value.map((ingredient) => _buildIngredientRow(context, ingredient)),
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
          const Padding(
            padding: EdgeInsets.only(top: 8.0, right: 12.0),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Color(0xFF67737E),
            ),
          ),
          Expanded(
            child: Text(
              ingredient.formatted(),
              style: TextStyles.bodyText(context),
            ),
          ),
        ],
      ),
    );
  }
}
