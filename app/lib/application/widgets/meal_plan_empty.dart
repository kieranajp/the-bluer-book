import 'package:flutter/material.dart';

import '../styles/colours.dart';
import '../styles/shapes.dart';
import 'section_label.dart';

/// Placeholder shown in the meal-plan carousel slot when nothing is planned.
class MealPlanEmpty extends StatelessWidget {
  const MealPlanEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(title: 'On the meal plan'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: Shapes.tornCorner,
            ),
            child: Text(
              'Star recipes to build your week.',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
