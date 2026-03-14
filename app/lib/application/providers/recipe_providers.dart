import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/network/api_client.dart';
import '../../infrastructure/recipe_repository.dart';
import '../../domain/recipe.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(apiClientProvider));
});

final allRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return ref.watch(recipeRepositoryProvider).getAllRecipes();
});

final favouriteRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return ref.watch(recipeRepositoryProvider).getFavouriteRecipes();
});

// State notifier for managing paginated recipe list with meal plan toggles
class RecipeListNotifier extends StateNotifier<AsyncValue<List<Recipe>>> {
  final RecipeRepository _repository;
  final Ref _ref;

  static const int _pageSize = 20;
  int _total = 0;
  bool _isLoadingMore = false;
  String _currentSearch = '';

  RecipeListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadRecipes();
  }

  int get total => _total;
  bool get hasMore => (state.valueOrNull?.length ?? 0) < _total;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadRecipes({String search = ''}) async {
    _currentSearch = search;
    state = const AsyncValue.loading();
    try {
      final result = await _repository.getRecipes(limit: _pageSize, offset: 0, search: search);
      _total = result.total;
      dev.log('Loaded ${result.recipes.length}/$_total recipes (search="$search")', name: 'RecipeListNotifier');
      state = AsyncValue.data(result.recipes);
    } catch (e, stack) {
      dev.log('Failed to load recipes', name: 'RecipeListNotifier', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore || !state.hasValue) return;
    _isLoadingMore = true;
    try {
      final currentRecipes = state.value!;
      final result = await _repository.getRecipes(
        limit: _pageSize,
        offset: currentRecipes.length,
        search: _currentSearch,
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
    final wasInMealPlan = recipe.isFavourite;

    // Optimistic update
    final updatedRecipe = recipe.copyWith(isFavourite: !wasInMealPlan);
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

      // Invalidate favourite recipes to refresh meal plan section
      _ref.invalidate(favouriteRecipesProvider);
    } catch (e, stack) {
      dev.log('Failed to toggle meal plan for $uuid', name: 'RecipeListNotifier', error: e, stackTrace: stack);
      // Revert optimistic update on error
      state = AsyncValue.data(recipes);
      rethrow;
    }
  }
}

final recipeListProvider = StateNotifierProvider<RecipeListNotifier, AsyncValue<List<Recipe>>>((ref) {
  return RecipeListNotifier(ref.watch(recipeRepositoryProvider), ref);
});

// Provider for individual recipe detail with meal plan toggle support
class RecipeDetailNotifier extends StateNotifier<AsyncValue<Recipe?>> {
  final RecipeRepository _repository;
  final Ref _ref;

  RecipeDetailNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> loadRecipe(int id) async {
    state = const AsyncValue.loading();
    try {
      final recipe = await _repository.getRecipe(id);
      state = AsyncValue.data(recipe);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleMealPlan() async {
    final currentState = state;
    if (!currentState.hasValue) return;

    final recipe = currentState.value;
    if (recipe == null) return;

    final wasInMealPlan = recipe.isFavourite;

    // Optimistic update
    final updatedRecipe = recipe.copyWith(isFavourite: !wasInMealPlan);
    state = AsyncValue.data(updatedRecipe);

    try {
      // Make API call
      if (wasInMealPlan) {
        await _repository.removeFromMealPlan(recipe.uuid);
      } else {
        await _repository.addToMealPlan(recipe.uuid);
      }

      // Invalidate providers to refresh lists
      _ref.invalidate(favouriteRecipesProvider);
      _ref.invalidate(recipeListProvider);
    } catch (e) {
      // Revert optimistic update on error
      state = AsyncValue.data(recipe);
      rethrow;
    }
  }
}

final recipeDetailProvider = StateNotifierProvider.family<RecipeDetailNotifier, AsyncValue<Recipe?>, int>((ref, id) {
  final notifier = RecipeDetailNotifier(ref.watch(recipeRepositoryProvider), ref);
  notifier.loadRecipe(id);
  return notifier;
});

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

// Recipes provider — search is handled server-side via loadRecipes()
final filteredRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  return ref.watch(recipeListProvider);
});
