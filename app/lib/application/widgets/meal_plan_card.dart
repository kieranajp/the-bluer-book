import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../screens/recipe_details_screen.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';
import '../styles/text_styles.dart';
import '../utils/time_format.dart';
import 'striped_placeholder.dart';

/// A torn-corner meal-plan card for the two-column grid on the Meal Plan
/// screen. Shares the cookbook-page shape DNA, full-bleed image and serif
/// title with the home carousel, scaled down for the grid. Set [mirror] to
/// flip the torn corners so adjacent columns read as a symmetric spread.
class MealPlanCard extends StatelessWidget {
  final Recipe recipe;
  final bool mirror;

  const MealPlanCard({super.key, required this.recipe, this.mirror = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final totalTime = recipe.preparationTime + recipe.cookingTime;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailsScreen(recipe: recipe),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: mirror ? Shapes.tornCornerMirror : Shapes.tornCorner,
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecipeImage(
                    imageUrl: recipe.imageUrl,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _PlanStar(active: recipe.isInMealPlan),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.name,
                    style: TextStyles.serifCardTitleSmall(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: c.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        formatMinutes(totalTime),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Translucent membership star floating over the card image.
class _PlanStar extends StatelessWidget {
  final bool active;

  const _PlanStar({required this.active});

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
