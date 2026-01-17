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
