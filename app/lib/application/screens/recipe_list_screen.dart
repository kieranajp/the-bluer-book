import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../styles/label_colours.dart';
import '../styles/spacing.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/home_header.dart';
import '../widgets/home_hero.dart';
import '../widgets/meal_plan_carousel.dart';
import '../widgets/pill_search.dart';
import '../widgets/recipe_row.dart';
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

  static const _typeOrder = ['course', 'cuisine', 'diet', 'method'];

  List<FilterOption> _buildFilterOptions(List<LabelSummary> labels, int total) {
    final used = labels.where((l) => l.uses > 0).toList()
      ..sort((a, b) {
        final ti = _typeOrder.indexOf(a.type);
        final tj = _typeOrder.indexOf(b.type);
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
      labelsAsync.valueOrNull ?? const [],
      total,
    );
    final chipActive = activeLabels.isEmpty ? {'__all__'} : activeLabels;

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
              notifier.loadMore();
            }
            return false;
          },
          child: CustomScrollView(
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
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(child: MealPlanCarousel()),
              SliverToBoxAdapter(
                child: SectionLabel(
                  title: total > 0 ? 'All recipes · $total' : 'All recipes',
                  action: notifier.sort.label,
                  onAction: () => notifier.setSort(notifier.sort.next),
                ),
              ),
              recipesAsync.when(
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
                          (context, i) => RecipeRow(
                            recipe: recipes[i],
                            isLast: i == recipes.length - 1,
                          ),
                          childCount: recipes.length,
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.xl),
                    child: Center(child: CircularProgressIndicator()),
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
    );
  }
}
