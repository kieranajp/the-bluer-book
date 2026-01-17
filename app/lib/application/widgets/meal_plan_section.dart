import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import 'meal_plan_card.dart';

class MealPlanSection extends ConsumerWidget {
  const MealPlanSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favouriteRecipesAsync = ref.watch(favouriteRecipesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: Spacing.m),
        Padding(
          padding: Spacing.horizontal,
          child: Text(
            'Meal Plan',
            style: TextStyles.sectionHeading(context),
          ),
        ),
        SizedBox(height: Spacing.s),
        SizedBox(
          height: Spacing.mealPlanHeight,
          child: favouriteRecipesAsync.when(
            data: (recipes) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: Spacing.horizontal,
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < recipes.length - 1 ? Spacing.m : 0,
                  ),
                  child: MealPlanCard(recipe: recipes[index]),
                );
              },
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          ),
        ),
      ],
    );
  }
}
