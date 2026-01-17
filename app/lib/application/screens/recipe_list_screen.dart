import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_list_item.dart';
import '../widgets/search_bar.dart';
import '../widgets/meal_plan_section.dart';
import '../widgets/theme_selector_dialog.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRecipesAsync = ref.watch(allRecipesProvider);

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              backgroundColor: context.colours.background,
              elevation: 0,
              title: Text(
                'My Kitchen',
                style: TextStyles.appBarTitle(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.brightness_6),
                  tooltip: 'Theme',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ThemeSelectorDialog(),
                    );
                  },
                ),
              ],
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
                  style: TextStyles.sectionHeading(context),
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
        backgroundColor: context.colours.primary,
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }
}
