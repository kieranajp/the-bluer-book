import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../widgets/add_to_plan_button.dart';
import '../widgets/ingredients_list.dart';
import '../widgets/instructions_list.dart';
import '../widgets/recipe_header.dart';
import '../widgets/recipe_hero_image.dart';
import '../widgets/recipe_stats_card.dart';
import '../widgets/recipe_tab_bar.dart';
import 'edit_recipe_screen.dart';

class RecipeDetailsScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailsScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends ConsumerState<RecipeDetailsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final recipeListAsync = ref.watch(recipeListProvider);
    final recipe = recipeListAsync.maybeWhen(
      data: (recipes) => recipes.firstWhere(
        (r) => r.uuid == widget.recipe.uuid,
        orElse: () => widget.recipe,
      ),
      orElse: () => widget.recipe,
    );

    return Scaffold(
      backgroundColor: context.colours.background,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: RecipeHeroImage(
              imageUrl: recipe.imageUrl,
              onBack: () => Navigator.pop(context),
              onShare: () {},
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditRecipeScreen(recipe: recipe),
                ),
              ),
              onBookmark: () => ref
                  .read(recipeListProvider.notifier)
                  .toggleMealPlan(recipe.uuid),
              bookmarkActive: recipe.isFavourite,
            ),
          ),
          SliverToBoxAdapter(
            child: RecipeHeader(
              name: recipe.name,
              description: recipe.description,
              labels: recipe.labels,
            ),
          ),
          SliverToBoxAdapter(
            child: RecipeStatsCard(
              preparationTime: recipe.preparationTime,
              cookingTime: recipe.cookingTime,
              servings: recipe.servings,
            ),
          ),
          SliverToBoxAdapter(
            child: AddToPlanButton(
              uuid: recipe.uuid,
              isInMealPlan: recipe.isFavourite,
            ),
          ),
          SliverToBoxAdapter(
            child: RecipeTabBar(
              selectedTab: _selectedTab,
              onTabSelected: (i) => setState(() => _selectedTab = i),
              ingredientCount: recipe.ingredients.length,
              stepCount: recipe.steps.length,
            ),
          ),
          SliverToBoxAdapter(
            child: _selectedTab == 0
                ? IngredientsList(ingredients: recipe.ingredients)
                : InstructionsList(
                    steps: recipe.steps,
                    ingredients: recipe.ingredients,
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
