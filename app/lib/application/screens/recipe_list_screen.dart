import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_list_item.dart';
import '../widgets/search_bar.dart';
import '../widgets/meal_plan_section.dart';
import '../styles/colours.dart';
import '../styles/typography.dart';
import '../styles/spacing.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRecipesAsync = ref.watch(allRecipesProvider);

    return Scaffold(
      backgroundColor: Colours.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              backgroundColor: Colours.background,
              elevation: 0,
              title: Text(
                'My Kitchen',
                style: Typography.appBarTitle,
              ),
            ),

            // Search bar
            const SliverToBoxAdapter(
              child: RecipeSearchBar(),
            ),

            // Meal plan section
            const SliverToBoxAdapter(
              child: MealPlanSection(),
            ),

            // All recipes section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.m,
                  Spacing.l,
                  Spacing.m,
                  Spacing.s,
                ),
                child: Text(
                  'All Recipes',
                  style: Typography.sectionHeading,
                ),
              ),
            ),

            // All recipes list
            allRecipesAsync.when(
              data: (recipes) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: Spacing.listItemPadding,
                      child: RecipeListItem(recipe: recipes[index]),
                    );
                  },
                  childCount: recipes.length,
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Text('Error: $error'),
                  ),
                ),
              ),
            ),

            // Bottom spacing for FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: Spacing.bottomSpacer),
            ),
          ],
        ),
      ),

      // Add recipe button
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colours.primary,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
