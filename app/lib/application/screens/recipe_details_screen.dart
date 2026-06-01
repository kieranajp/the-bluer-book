import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_share.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../widgets/add_to_plan_button.dart';
import '../widgets/cooking_mode_button.dart';
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

  /// Freshly fetched copy from a pull-to-refresh. Used as the fallback when
  /// the recipe isn't part of the currently loaded list page.
  Recipe? _refreshed;

  Future<void> _refresh() async {
    try {
      final fresh =
          await ref.read(recipeRepositoryProvider).getRecipe(widget.recipe.uuid);
      if (!mounted) return;
      setState(() => _refreshed = fresh);
      // Keep the list and meal plan in sync with the latest data.
      ref.read(recipeListProvider.notifier).updateRecipe(fresh);
      ref.invalidate(mealPlanRecipesProvider);
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Failed to refresh recipe';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeListAsync = ref.watch(recipeListProvider);
    final fallback = _refreshed ?? widget.recipe;
    final recipe = recipeListAsync.maybeWhen(
      data: (recipes) => recipes.firstWhere(
        (r) => r.uuid == widget.recipe.uuid,
        orElse: () => fallback,
      ),
      orElse: () => fallback,
    );

    return Scaffold(
      backgroundColor: context.colours.background,
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverToBoxAdapter(
            child: RecipeHeroImage(
              imageUrl: recipe.imageUrl,
              onBack: () => Navigator.pop(context),
              onShare: () => _shareRecipe(context, recipe),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditRecipeScreen(recipe: recipe),
                ),
              ),
              onBookmark: () => ref
                  .read(recipeListProvider.notifier)
                  .toggleMealPlan(recipe.uuid),
              bookmarkActive: recipe.isInMealPlan,
            ),
          ),
          SliverToBoxAdapter(
            child: RecipeHeader(
              name: recipe.name,
              description: recipe.description,
              labels: recipe.labels,
              url: recipe.url,
            ),
          ),
          SliverToBoxAdapter(
            child: RecipeStatsCard(
              preparationTime: recipe.preparationTime,
              cookingTime: recipe.cookingTime,
              servings: recipe.servings,
            ),
          ),
          if (recipe.steps.isNotEmpty)
            SliverToBoxAdapter(
              child: CookingModeButton(recipe: recipe),
            ),
          SliverToBoxAdapter(
            child: AddToPlanButton(
              uuid: recipe.uuid,
              isInMealPlan: recipe.isInMealPlan,
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
      ),
    );
  }

  void _shareRecipe(BuildContext context, Recipe recipe) {
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(
      ShareParams(
        text: recipe.toShareableText(),
        subject: recipe.name,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}
