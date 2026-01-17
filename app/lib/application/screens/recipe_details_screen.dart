import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../widgets/recipe_hero_image.dart';
import '../widgets/recipe_header.dart';
import '../widgets/recipe_stats_card.dart';
import '../widgets/recipe_tab_bar.dart';
import '../widgets/ingredients_list.dart';
import '../widgets/instructions_list.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeDetailsScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailsScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends ConsumerState<RecipeDetailsScreen> {
  int _selectedTab = 0;

  void _onTabSelected(int index) {
    setState(() {
      _selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colours.background,
      body: CustomScrollView(
        slivers: [
          // Hero image with back button
          SliverAppBar(
            expandedHeight: 250,
            pinned: false,
            backgroundColor: context.colours.background,
            leading: Padding(
              padding: const EdgeInsets.all(Spacing.xs),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: RecipeHeroImage(imageUrl: widget.recipe.imageUrl),
            ),
          ),

          // Recipe header
          SliverToBoxAdapter(
            child: RecipeHeader(
              name: widget.recipe.name,
              description: widget.recipe.description,
              labels: widget.recipe.labels,
            ),
          ),

          // Stats card
          SliverToBoxAdapter(
            child: RecipeStatsCard(
              preparationTime: widget.recipe.preparationTime,
              cookingTime: widget.recipe.cookingTime,
              servings: widget.recipe.servings,
            ),
          ),

          // Add to Meal Plan button
          SliverToBoxAdapter(
            child: _AddToMealPlanButton(recipe: widget.recipe),
          ),

          // Sticky tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: RecipeTabBar(
              selectedTab: _selectedTab,
              onTabSelected: _onTabSelected,
            ),
          ),

          // Tab content (Ingredients or Instructions)
          SliverToBoxAdapter(
            child: _selectedTab == 0
                ? IngredientsList(ingredients: widget.recipe.ingredients)
                : InstructionsList(steps: widget.recipe.steps),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: Spacing.bottomSpacer),
          ),
        ],
      ),
    );
  }
}

class _AddToMealPlanButton extends ConsumerWidget {
  final Recipe recipe;

  const _AddToMealPlanButton({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the recipe list to get the latest state
    final recipeListAsync = ref.watch(recipeListProvider);

    // Find the current recipe in the list to get its updated state
    final currentRecipe = recipeListAsync.maybeWhen(
      data: (recipes) => recipes.firstWhere(
        (r) => r.uuid == recipe.uuid,
        orElse: () => recipe,
      ),
      orElse: () => recipe,
    );

    final isInMealPlan = currentRecipe.isFavourite;

    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () async {
            final notifier = ref.read(recipeListProvider.notifier);
            try {
              await notifier.toggleMealPlan(recipe.uuid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isInMealPlan
                          ? 'Removed from meal plan'
                          : 'Added to meal plan',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update meal plan'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isInMealPlan
                ? context.colours.textSecondary.withValues(alpha: 0.3)
                : context.colours.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isInMealPlan ? Icons.star : Icons.star_border,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isInMealPlan ? 'Remove from Meal Plan' : 'Add to Meal Plan',
                style: TextStyles.buttonText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
