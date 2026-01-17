import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../widgets/recipe_hero_image.dart';
import '../widgets/recipe_header.dart';
import '../widgets/recipe_stats_card.dart';
import '../widgets/recipe_tab_bar.dart';
import '../widgets/ingredients_list.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeDetailsScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailsScreen({super.key, required this.recipe});

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
              background: RecipeHeroImage(imageUrl: recipe.imageUrl),
            ),
          ),

          // Recipe header
          SliverToBoxAdapter(
            child: RecipeHeader(
              name: recipe.name,
              description: recipe.description,
              labels: recipe.labels,
            ),
          ),

          // Stats card
          SliverToBoxAdapter(
            child: RecipeStatsCard(
              preparationTime: recipe.preparationTime,
              cookingTime: recipe.cookingTime,
              servings: recipe.servings,
            ),
          ),

          // Add to Meal Plan button
          SliverToBoxAdapter(
            child: _AddToMealPlanButton(),
          ),

          // Sticky tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: RecipeTabBar(),
          ),

          // Ingredients list
          SliverToBoxAdapter(
            child: IngredientsList(ingredients: recipe.ingredients),
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

class _AddToMealPlanButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () {
            // TODO: Implement add to meal plan functionality
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colours.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Add to Meal Plan',
            style: TextStyles.buttonText(context),
          ),
        ),
      ),
    );
  }
}
