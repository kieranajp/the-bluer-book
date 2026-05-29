import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../screens/recipe_details_screen.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';
import '../styles/text_styles.dart';
import '../utils/time_format.dart';
import 'striped_placeholder.dart';

/// A single torn-corner meal-plan card used in the home screen carousel.
class MealPlanCarouselCard extends StatelessWidget {
  final Recipe recipe;

  const MealPlanCarouselCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final totalTime = recipe.preparationTime + recipe.cookingTime;
    final firstLabel = recipe.labels.isNotEmpty ? recipe.labels.first : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailsScreen(recipe: recipe),
        ),
      ),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Shapes.tornCorner,
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecipeImage(
                    imageUrl: recipe.imageUrl,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(top: 14, left: 14, child: _PlanBadge(label: firstLabel?.name)),
                  const Positioned(top: 12, right: 12, child: _Kebab()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.serifCardTitle(context),
                  ),
                  const SizedBox(height: 10),
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
                      if (firstLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: c.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            firstLabel.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: c.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
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

class _PlanBadge extends StatelessWidget {
  final String? label;

  const _PlanBadge({this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PLAN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: c.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: c.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Kebab extends StatelessWidget {
  const _Kebab();

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
