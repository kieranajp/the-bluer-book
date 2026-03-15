import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../screens/recipe_details_screen.dart';
import '../styles/colours.dart';
import '../styles/decorations.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';

class MealPlanCard extends StatelessWidget {
  final Recipe recipe;

  const MealPlanCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
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
        width: 200,
        decoration: Decorations.card(context),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealPlanImage(recipe: recipe),
              const SizedBox(height: Spacing.s),
              Text(
                recipe.name,
                style: TextStyles.cardSubtitle(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14,
                      color: context.colours.textSecondary),
                  const SizedBox(width: 4),
                  Text('${totalTime}m', style: TextStyles.caption(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealPlanImage extends StatelessWidget {
  final Recipe recipe;

  const _MealPlanImage({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: Spacing.mealPlanImageHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: context.colours.border,
            image: recipe.imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(recipe.imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: recipe.imageUrl == null
              ? Icon(Icons.restaurant, size: 48,
                  color: context.colours.textSecondary.withValues(alpha: 0.4))
              : null,
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
              recipe.isFavourite ? Icons.star : Icons.star_border,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
