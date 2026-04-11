import 'package:flutter/material.dart';
import '../../domain/ingredient.dart';
import '../../domain/step.dart' as domain;
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import '../styles/colours.dart';
import '../utils/ingredient_highlighter.dart';

class InstructionsList extends StatelessWidget {
  final List<domain.Step> steps;
  final List<Ingredient> ingredients;

  const InstructionsList({
    super.key,
    required this.steps,
    this.ingredients = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number and vertical line
                Column(
                  children: [
                    // Numbered circle badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.colours.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          step.order.toString(),
                          style: TextStyle(
                            color: context.colours.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Vertical connecting line (hidden for last item)
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
                          decoration: BoxDecoration(
                            color: context.colours.border,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: Spacing.m),
                // Step description with ingredient highlighting
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: isLast ? 0 : Spacing.m,
                    ),
                    child: _buildStepDescription(context, step.description),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepDescription(BuildContext context, String description) {
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