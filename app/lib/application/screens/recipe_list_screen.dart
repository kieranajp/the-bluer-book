import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_list_item.dart';
import '../widgets/search_bar.dart';
import '../widgets/empty_state.dart';
import '../utils/error_snackbar.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    ref.read(recipeListProvider.notifier).searchDebounced(query);
  }

  @override
  Widget build(BuildContext context) {
    final allRecipesAsync = ref.watch(filteredRecipesProvider);
    final notifier = ref.read(recipeListProvider.notifier);

    listenForErrorSnackbar<List<Recipe>>(
      ref,
      context,
      provider: filteredRecipesProvider,
      fallbackMessage: 'Failed to load recipes',
      onRetry: () => notifier.loadRecipes(
        search: ref.read(searchQueryProvider),
      ),
    );

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
              ),

              // Search bar
              SliverToBoxAdapter(
                child: RecipeSearchBar(
                  onChanged: _onSearchChanged,
                ),
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
                        child: EmptyState(
                          icon: Icons.restaurant_menu,
                          title: ref.watch(searchQueryProvider).isNotEmpty
                              ? 'No recipes match your search'
                              : 'No recipes yet',
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
                  child: EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Couldn\'t load recipes',
                    action: OutlinedButton.icon(
                      onPressed: () => notifier.loadRecipes(
                        search: ref.read(searchQueryProvider),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
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

    );
  }
}
