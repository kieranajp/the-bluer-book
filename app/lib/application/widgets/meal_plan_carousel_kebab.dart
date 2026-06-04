import 'package:flutter/material.dart';

/// The overflow ("…") button overlaid on a [MealPlanCarouselCard]'s image.
class MealPlanCarouselKebab extends StatelessWidget {
  const MealPlanCarouselKebab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 18),
    );
  }
}
