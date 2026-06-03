import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../styles/colours.dart';
import '../styles/spacing.dart';
import 'recipe_image.dart';

/// The image + meal-plan star badge at the top of a [MealPlanCard].
class MealPlanCardImage extends StatelessWidget {
  final Recipe recipe;

  const MealPlanCardImage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: Spacing.mealPlanImageHeight,
          child: RecipeImage(
            imageUrl: recipe.imageUrl,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Positioned(
          top: Spacing.xs,
          right: Spacing.xs,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.colours.primary.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              recipe.isInMealPlan ? Icons.star : Icons.star_border,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
