import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../screens/recipe_details_screen.dart';
import '../styles/colours.dart';
import '../styles/decorations.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';
import 'meal_plan_card_image.dart';

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
              MealPlanCardImage(recipe: recipe),
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
