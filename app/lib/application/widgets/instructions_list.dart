import 'package:flutter/material.dart';
import '../../domain/ingredient.dart';
import '../../domain/step.dart' as domain;
import '../styles/spacing.dart';
import 'instruction_step_row.dart';

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
          return InstructionStepRow(
            step: steps[index],
            isLast: index == steps.length - 1,
            ingredients: ingredients,
          );
        }),
      ),
    );
  }
}
