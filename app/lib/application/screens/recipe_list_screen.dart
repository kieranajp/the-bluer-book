import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../providers/pantry_providers.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../styles/label_colours.dart';
import '../styles/spacing.dart';
import '../utils/cookability.dart';
import '../widgets/brand_loader.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/home_header.dart';
import '../widgets/home_hero.dart';
import '../widgets/meal_plan_carousel.dart';
import '../widgets/pill_search.dart';
import '../widgets/recipe_row_swipeable.dart';
import '../widgets/section_label.dart';

/// Home — "My Kitchen", Garden Plot / M3 Expressive.
class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  Timer? _debounce;

  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).set(query);
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

  /// "Cook now" sorts the loaded recipes by fewest missing ingredients
  /// (ready first), breaking ties by name. Other sorts are handled server-side,
  /// so the list is shown as-is. Note: this only orders what's currently
  /// loaded — across pages it's approximate until more are fetched.
  List<Recipe> _sortForDisplay(
    List<Recipe> recipes,
    RecipeSort sort,
    Set<String> pantry,
  ) {
    if (sort != RecipeSort.cookable) return recipes;
    final missing = {
      for (final r in recipes) r.uuid: cookabilityOf(r, pantry).missing,
    };
    return [...recipes]..sort((a, b) {
        final cmp = missing[a.uuid]!.compareTo(missing[b.uuid]!);
        return cmp != 0
            ? cmp
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  List<FilterOption> _buildFilterOptions(List<LabelSummary> labels, int total) {
    final used = labels.where((l) => l.uses > 0).toList()
      ..sort((a, b) {
        final ti = kLabelTypes.indexOf(a.type);
        final tj = kLabelTypes.indexOf(b.type);
        if (ti != tj) return ti.compareTo(tj);
        return b.uses.compareTo(a.uses);
      });

    return [
      FilterOption(id: '__all__', label: 'All', count: total > 0 ? total : null),
      ...used.map((l) => FilterOption(
            id: l.key,
            label: labelDisplayName(l.name),
            count: l.uses,
            type: l.type,
          )),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(filteredRecipesProvider);
    final labelsAsync = ref.watch(labelsProvider);
    final notifier = ref.read(recipeListProvider.notifier);
    final activeLabels = ref.watch(recipeListProvider.notifier).activeLabels;
    // Watched so "Cook now" re-sorts live as the pantry changes.
    final pantry = ref.watch(pantryProvider).value ?? const <String>{};

    ref.listen<AsyncValue<List<Recipe>>>(filteredRecipesProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        final err = next.error;
        final message = err is Exception
            ? err.toString().replaceFirst('Exception: ', '')
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

    final total = notifier.total;
    final filters = _buildFilterOptions(
      labelsAsync.value ?? const [],
      total,
    );
    final chipActive = activeLabels.isEmpty ? {'__all__'} : activeLabels;

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(labelsProvider);
            ref.invalidate(mealPlanRecipesProvider);
            await notifier.refresh();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
                notifier.loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              const SliverToBoxAdapter(child: HomeHeader()),
              const SliverToBoxAdapter(child: HomeHero()),
              SliverToBoxAdapter(child: PillSearch(onChanged: _onSearchChanged)),
              SliverToBoxAdapter(
                child: FilterChipRow(
                  filters: filters,
                  active: chipActive,
                  onToggle: (id) {
                    if (id == '__all__') {
                      notifier.clearLabels();
                    } else {
                      notifier.toggleLabel(id);
                    }
                  },
                ),
              ),
              const SliverToBoxAdapter(child: MealPlanCarousel()),
              SliverToBoxAdapter(
                child: SectionLabel(
                  title: total > 0 ? 'All recipes · $total' : 'All recipes',
                  action: notifier.sort.label,
                  onAction: () => notifier.setSort(notifier.sort.next),
                ),
              ),
              recipesAsync.when(
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.restaurant_menu,
                        title: ref.watch(searchQueryProvider).isNotEmpty
                            ? 'No recipes match your search'
                            : 'No recipes yet',
                      ),
                    );
                  }
                  final displayed = _sortForDisplay(recipes, notifier.sort, pantry);
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => RecipeRowSwipeable(
                        recipe: displayed[i],
                        isLast: i == displayed.length - 1,
                      ),
                      childCount: displayed.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.xl),
                    child: Center(child: BrandLoader()),
                  ),
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.cloud_off,
                    title: "Couldn't load recipes",
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
              if (recipesAsync.hasValue && notifier.hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.m),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
