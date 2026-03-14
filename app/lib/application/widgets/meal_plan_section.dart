import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import 'meal_plan_card.dart';

class MealPlanSection extends ConsumerWidget {
  const MealPlanSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favouriteRecipesAsync = ref.watch(favouriteRecipesProvider);

    ref.listen<AsyncValue<List<Recipe>>>(favouriteRecipesProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        final error = next.error;
        final message = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Failed to load meal plan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => ref.invalidate(favouriteRecipesProvider),
            ),
          ),
        );
      }
    });

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
            data: (recipes) => recipes.isEmpty
                ? Center(
                    child: Text(
                      'Star some recipes to build your meal plan',
                      style: TextStyle(color: context.colours.textSecondary),
                    ),
                  )
                : ListView.builder(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 32,
                      color: context.colours.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: Spacing.s),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(favouriteRecipesProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
