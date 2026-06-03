import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/ingredient.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../../infrastructure/analytics/analytics.dart';
import '../../infrastructure/network/api_client.dart';
import '../../infrastructure/recipe_repository.dart';
import 'analytics_providers.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(apiClientProvider));
});

final ingredientsProvider = FutureProvider<List<IngredientDetail>>((ref) async {
  return ref.watch(recipeRepositoryProvider).getIngredients();
});

final unitsProvider = FutureProvider<List<IngredientUnit>>((ref) async {
  return ref.watch(recipeRepositoryProvider).getUnits();
});

final allRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return ref.watch(recipeRepositoryProvider).getAllRecipes();
});

final mealPlanRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return ref.watch(recipeRepositoryProvider).getMealPlanRecipes();
});

final labelsProvider = FutureProvider<List<LabelSummary>>((ref) async {
  return ref.watch(recipeRepositoryProvider).getLabels();
});

enum RecipeSort { newest, name, time, cookable }

extension RecipeSortApi on RecipeSort {
  /// Server-side sort key. `cookable` has none — the server returns its default
  /// order and the list is re-sorted client-side from the pantry (the client
  /// already has each recipe's ingredients and the pantry set).
  String get apiValue => switch (this) {
        RecipeSort.newest => '',
        RecipeSort.name => 'name',
        RecipeSort.time => 'time',
        RecipeSort.cookable => '',
      };

  String get label => switch (this) {
        RecipeSort.newest => 'Newest',
        RecipeSort.name => 'A–Z',
        RecipeSort.time => 'Quickest',
        RecipeSort.cookable => 'Cook now',
      };

  RecipeSort get next => switch (this) {
        RecipeSort.newest => RecipeSort.name,
        RecipeSort.name => RecipeSort.time,
        RecipeSort.time => RecipeSort.cookable,
        RecipeSort.cookable => RecipeSort.newest,
      };
}

// Notifier for managing paginated recipe list with meal plan toggles
class RecipeListNotifier extends Notifier<AsyncValue<List<Recipe>>> {
  RecipeRepository get _repository => ref.read(recipeRepositoryProvider);

  static const int _pageSize = 20;
  int _total = 0;
  bool _isLoadingMore = false;
  String _currentSearch = '';
  RecipeSort _currentSort = RecipeSort.newest;
  Set<String> _currentLabels = const {};

  @override
  AsyncValue<List<Recipe>> build() {
    Future.microtask(() => loadRecipes());
    return const AsyncValue.loading();
  }

  int get total => _total;
  bool get hasMore => (state.value?.length ?? 0) < _total;
  bool get isLoadingMore => _isLoadingMore;
  RecipeSort get sort => _currentSort;
  Set<String> get activeLabels => _currentLabels;

  Future<void> loadRecipes({
    String search = '',
    RecipeSort? sort,
    Set<String>? labels,
  }) async {
    _currentSearch = search;
    if (sort != null) _currentSort = sort;
    if (labels != null) _currentLabels = labels;
    state = const AsyncValue.loading();
    try {
      final result = await _repository.getRecipes(
        limit: _pageSize,
        offset: 0,
        search: search,
        sort: _currentSort.apiValue,
        labels: _currentLabels.toList(),
      );
      _total = result.total;
      dev.log('Loaded ${result.recipes.length}/$_total recipes (search="$search", sort=${_currentSort.name}, labels=$_currentLabels)', name: 'RecipeListNotifier');
      state = AsyncValue.data(result.recipes);
    } catch (e, stack) {
      dev.log('Failed to load recipes', name: 'RecipeListNotifier', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  /// Reload the current page from scratch, preserving the active
  /// search, sort and label filters. Used for pull-to-refresh.
  Future<void> refresh() => loadRecipes(
        search: _currentSearch,
        sort: _currentSort,
        labels: _currentLabels,
      );

  /// Replace a single recipe in the loaded list (matched by uuid) with a
  /// freshly fetched copy, without disturbing pagination or scroll position.
  void updateRecipe(Recipe updated) {
    final currentState = state;
    if (!currentState.hasValue) return;
    final recipes = currentState.value!;
    final index = recipes.indexWhere((r) => r.uuid == updated.uuid);
    if (index == -1) return;
    final next = [...recipes];
    next[index] = updated;
    state = AsyncValue.data(next);
  }

  Future<void> setSort(RecipeSort sort) =>
      loadRecipes(search: _currentSearch, sort: sort, labels: _currentLabels);

  Future<void> toggleLabel(String key) {
    final next = {..._currentLabels};
    if (!next.remove(key)) next.add(key);
    return loadRecipes(
      search: _currentSearch,
      sort: _currentSort,
      labels: next,
    );
  }

  Future<void> clearLabels() => loadRecipes(
        search: _currentSearch,
        sort: _currentSort,
        labels: const {},
      );

  Future<void> loadMore() async {
    final currentState = state;
    if (_isLoadingMore || !hasMore || !currentState.hasValue) return;
    _isLoadingMore = true;
    try {
      final currentRecipes = currentState.value!;
      final result = await _repository.getRecipes(
        limit: _pageSize,
        offset: currentRecipes.length,
        search: _currentSearch,
        sort: _currentSort.apiValue,
        labels: _currentLabels.toList(),
      );
      _total = result.total;
      dev.log('Loaded ${result.recipes.length} more recipes (${currentRecipes.length + result.recipes.length}/$_total)',
          name: 'RecipeListNotifier');
      state = AsyncValue.data([...currentRecipes, ...result.recipes]);
    } catch (e, stack) {
      dev.log('Failed to load more recipes', name: 'RecipeListNotifier', error: e, stackTrace: stack);
      // Don't replace state with error — keep existing recipes visible
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Delete (archive) a recipe. Optimistically removes it from the loaded
  /// list — and shrinks the total count — then reverts if the API call fails.
  Future<void> deleteRecipe(String uuid) async {
    final currentState = state;
    if (!currentState.hasValue) return;

    final recipes = currentState.value!;
    final recipeIndex = recipes.indexWhere((r) => r.uuid == uuid);
    if (recipeIndex == -1) return;

    // Optimistic removal
    final updatedRecipes = [...recipes]..removeAt(recipeIndex);
    final previousTotal = _total;
    if (_total > 0) _total -= 1;
    state = AsyncValue.data(updatedRecipes);

    try {
      await _repository.deleteRecipe(uuid);
      // The recipe may have been on the meal plan — refresh that section too.
      ref.invalidate(mealPlanRecipesProvider);
      ref.read(analyticsProvider).capture(
        AnalyticsEvent.recipeArchived,
        properties: {'recipe_uuid': uuid},
      );
    } catch (e, stack) {
      dev.log('Failed to delete $uuid', name: 'RecipeListNotifier', error: e, stackTrace: stack);
      // Revert optimistic update on error
      _total = previousTotal;
      state = AsyncValue.data(recipes);
      rethrow;
    }
  }

  Future<void> toggleMealPlan(String uuid) async {
    final currentState = state;
    if (!currentState.hasValue) {
      return;
    }

    final recipes = currentState.value!;

    // Find the recipe
    final recipeIndex = recipes.indexWhere((r) => r.uuid == uuid);
    if (recipeIndex == -1) {
      return;
    }

    final recipe = recipes[recipeIndex];
    final wasInMealPlan = recipe.isInMealPlan;

    // Optimistic update
    final updatedRecipe = recipe.copyWith(isInMealPlan: !wasInMealPlan);
    final updatedRecipes = [...recipes];
    updatedRecipes[recipeIndex] = updatedRecipe;
    state = AsyncValue.data(updatedRecipes);

    try {
      // Make API call
      if (wasInMealPlan) {
        await _repository.removeFromMealPlan(uuid);
      } else {
        await _repository.addToMealPlan(uuid);
      }

      // Invalidate the meal plan list to refresh the meal plan section
      ref.invalidate(mealPlanRecipesProvider);
      ref.read(analyticsProvider).capture(
        AnalyticsEvent.mealPlanToggled,
        properties: {'added': !wasInMealPlan, 'recipe_uuid': uuid},
      );
    } catch (e, stack) {
      dev.log('Failed to toggle meal plan for $uuid', name: 'RecipeListNotifier', error: e, stackTrace: stack);
      // Revert optimistic update on error
      state = AsyncValue.data(recipes);
      rethrow;
    }
  }
}

final recipeListProvider =
    NotifierProvider<RecipeListNotifier, AsyncValue<List<Recipe>>>(
        RecipeListNotifier.new);

// Search query state
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// Recipes provider — search is handled server-side via loadRecipes()
final filteredRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  return ref.watch(recipeListProvider);
});
