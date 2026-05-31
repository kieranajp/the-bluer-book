import 'package:flutter/material.dart';

import '../../../domain/ingredient.dart';
import '../../../domain/step.dart' as domain;
import '../../styles/colours.dart';
import '../../styles/shapes.dart';
import 'cooking_step_ingredients.dart';
import 'cooking_step_text.dart';

/// A single step page: big number, big instruction text (with ingredient
/// highlighting), and the ingredients used in this step.
class CookingStepPage extends StatelessWidget {
  final domain.Step step;
  final int stepNumber;
  final List<Ingredient> ingredients;

  const CookingStepPage({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: Shapes.squircle(18),
            ),
            child: Text(
              '$stepNumber',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          CookingStepText(description: step.description, ingredients: ingredients),
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 32),
            CookingStepIngredients(ingredients: ingredients),
          ],
        ],
      ),
    );
  }
}
