import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/ingredient.dart';
import '../../styles/colours.dart';
import '../../utils/ingredient_highlighter.dart';

/// A single ingredient line in the "what you need now" panel.
class CookingStepIngredientRow extends StatelessWidget {
  final Ingredient ingredient;

  const CookingStepIngredientRow({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final qty = formatIngredientQuantity(ingredient);
    final name = ingredient.preparation != null &&
            ingredient.preparation!.isNotEmpty
        ? '${ingredient.detail.name}, ${ingredient.preparation}'
        : ingredient.detail.name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: c.textPrimary,
            ),
          ),
        ),
        if (qty.isNotEmpty) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              qty,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: c.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
