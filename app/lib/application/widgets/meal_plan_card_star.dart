import 'package:flutter/material.dart';

/// Translucent membership star floating over a [MealPlanCard]'s image.
class MealPlanCardStar extends StatelessWidget {
  final bool active;

  const MealPlanCardStar({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(
        active ? Icons.star : Icons.star_border,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}
