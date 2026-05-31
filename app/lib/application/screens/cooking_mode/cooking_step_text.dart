import 'package:flutter/material.dart';

import '../../../domain/ingredient.dart';
import '../../styles/colours.dart';
import '../../utils/ingredient_highlighter.dart';

/// Large, distance-readable instruction text with ingredient names emphasised.
class CookingStepText extends StatelessWidget {
  final String description;
  final List<Ingredient> ingredients;

  const CookingStepText({
    super.key,
    required this.description,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final base = TextStyle(
      fontSize: 28,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: c.textPrimary,
    );

    final segments = highlightIngredients(description, ingredients);
    if (segments.every((s) => !s.isHighlighted)) {
      return Text(description, style: base);
    }

    final highlight = base.copyWith(
      color: c.primary,
      fontWeight: FontWeight.w800,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final s in segments)
            TextSpan(text: s.text, style: s.isHighlighted ? highlight : base),
        ],
      ),
    );
  }
}
