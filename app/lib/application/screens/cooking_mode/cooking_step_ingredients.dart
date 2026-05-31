import 'package:flutter/material.dart';

import '../../../domain/ingredient.dart';
import '../../styles/colours.dart';
import 'cooking_step_ingredient_row.dart';

/// "What you need now" — the ingredients mentioned in this step, big enough to
/// read from across the counter, each with its quantity.
class CookingStepIngredients extends StatelessWidget {
  final List<Ingredient> ingredients;

  const CookingStepIngredients({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT YOU NEED NOW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < ingredients.length; i++) ...[
            if (i > 0)
              Divider(
                height: 20,
                thickness: 1,
                color: c.outlineVariant.withValues(alpha: 0.4),
              ),
            CookingStepIngredientRow(ingredient: ingredients[i]),
          ],
        ],
      ),
    );
  }
}
