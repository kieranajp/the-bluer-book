import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_list_item.dart';
import '../widgets/search_bar.dart';
import '../widgets/meal_plan_section.dart';
import '../widgets/theme_selector_dialog.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  Timer? _debounce;

  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(recipeListProvider.notifier).loadRecipes(search: query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRecipesAsync = ref.watch(filteredRecipesProvider);
    final notifier = ref.read(recipeListProvider.notifier);

    ref.listen<AsyncValue<List<Recipe>>>(filteredRecipesProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        final error = next.error;
        final message = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Failed to load recipes';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => notifier.loadRecipes(
                search: ref.read(searchQueryProvider),
              ),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.extentAfter < 200) {
              notifier.loadMore();
            }
            return false;
          },
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
              SliverToBoxAdapter(
                child: RecipeSearchBar(
                  onChanged: _onSearchChanged,
                ),
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
                data: (recipes) => recipes.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.xl),
                            child: Column(
                              children: [
                                Icon(Icons.restaurant_menu, size: 48,
                                    color: context.colours.textSecondary.withValues(alpha: 0.4)),
                                const SizedBox(height: Spacing.m),
                                Text(
                                  ref.watch(searchQueryProvider).isNotEmpty
                                      ? 'No recipes match your search'
                                      : 'No recipes yet',
                                  style: TextStyle(color: context.colours.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
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
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off, size: 48,
                              color: context.colours.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: Spacing.m),
                          Text(
                            'Couldn\'t load recipes',
                            style: TextStyle(color: context.colours.textSecondary),
                          ),
                          const SizedBox(height: Spacing.m),
                          OutlinedButton.icon(
                            onPressed: () => notifier.loadRecipes(
                              search: ref.read(searchQueryProvider),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Loading more indicator
              if (allRecipesAsync.hasValue && notifier.hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.m),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),

              // Bottom spacing for FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: Spacing.bottomSpacer),
              ),
            ],
          ),
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
