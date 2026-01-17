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

// State notifier for managing meal plan toggles
class RecipeListNotifier extends StateNotifier<AsyncValue<List<Recipe>>> {
  final RecipeRepository _repository;
  final Ref _ref;

  RecipeListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadRecipes();
  }

  Future<void> loadRecipes() async {
    state = const AsyncValue.loading();
    try {
      final recipes = await _repository.getAllRecipes();
      state = AsyncValue.data(recipes);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
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
    } catch (e) {
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
