import 'package:flutter/material.dart';
import '../../domain/ingredient.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class IngredientsList extends StatelessWidget {
  final List<Ingredient> ingredients;

  const IngredientsList({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ingredients.map((ingredient) {
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
                    _formatIngredient(ingredient),
                    style: TextStyles.bodyText(context),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
      final unitText = ingredient.unit!.abbreviation ?? ingredient.unit!.name;
      buffer.write(' $unitText');
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
