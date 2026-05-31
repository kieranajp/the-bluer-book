import 'package:flutter/material.dart';

import '../../domain/ingredient.dart';
import '../../domain/step.dart' as domain;
import '../styles/colours.dart';
import '../styles/spacing.dart';
import 'step_description.dart';

/// One row in the numbered, vertically-connected instructions timeline.
class InstructionStepRow extends StatelessWidget {
  final domain.Step step;
  final bool isLast;
  final List<Ingredient> ingredients;

  const InstructionStepRow({
    super.key,
    required this.step,
    required this.isLast,
    this.ingredients = const [],
  });

  @override
  Widget build(BuildContext context) {
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
              child: StepDescription(
                description: step.description,
                ingredients: ingredients,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
