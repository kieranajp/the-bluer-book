import 'package:flutter/material.dart';

import '../../domain/ingredient.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../utils/ingredient_highlighter.dart';

/// A recipe step's instruction text, with any ingredient names it mentions
/// highlighted and tappable for a quantity tooltip.
class StepDescription extends StatelessWidget {
  final String description;
  final List<Ingredient> ingredients;

  const StepDescription({
    super.key,
    required this.description,
    this.ingredients = const [],
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyles.bodyText(context).copyWith(
      height: 1.5,
      fontWeight: FontWeight.w500,
    );

    if (ingredients.isEmpty) {
      return Text(description, style: baseStyle);
    }

    final segments = highlightIngredients(description, ingredients);

    // If nothing was highlighted, use a plain Text for simplicity.
    if (segments.every((s) => !s.isHighlighted)) {
      return Text(description, style: baseStyle);
    }

    final highlightedStyle = baseStyle.copyWith(
      color: context.colours.primary,
      fontWeight: FontWeight.w600,
    );

    return Text.rich(
      TextSpan(
        children: segments.map((segment) {
          if (!segment.isHighlighted) {
            return TextSpan(text: segment.text, style: baseStyle);
          }
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message: formatIngredientTooltip(segment.ingredient!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: context.colours.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(segment.text, style: highlightedStyle),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
