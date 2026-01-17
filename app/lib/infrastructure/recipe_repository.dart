import 'package:dio/dio.dart';
import '../domain/recipe.dart';
import 'network/api_client.dart';

class RecipeRepository {
  final ApiClient _apiClient;

  RecipeRepository(this._apiClient);

  Future<List<Recipe>> getAllRecipes() async {
    try {
      final response = await _apiClient.dio.get('/recipes');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> recipes = data['recipes'];
      return recipes.map((json) => Recipe.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load recipes: ${e.message}');
    }
  }

  Future<List<Recipe>> getFavouriteRecipes() async {
    try {
      final response = await _apiClient.dio.get('/recipes/meal-plan');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> recipes = data['recipes'];
      return recipes.map((json) => Recipe.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load favourite recipes: ${e.message}');
    }
  }

  Future<Recipe> getRecipe(int id) async {
    try {
      final response = await _apiClient.dio.get('/recipes/$id');
      return Recipe.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to load recipe: ${e.message}');
    }
  }

  Future<void> toggleFavourite(int id) async {
    try {
      await _apiClient.dio.post('/recipes/$id/favourite');
    } on DioException catch (e) {
      throw Exception('Failed to toggle favourite: ${e.message}');
    }
  }

  Future<void> addToMealPlan(String uuid) async {
    try {
      await _apiClient.dio.post('/recipes/$uuid/meal-plan');
    } on DioException catch (e) {
      throw Exception('Failed to add to meal plan: ${e.message}');
    }
  }

  Future<void> removeFromMealPlan(String uuid) async {
    try {
      await _apiClient.dio.delete('/recipes/$uuid/meal-plan');
    } on DioException catch (e) {
      throw Exception('Failed to remove from meal plan: ${e.message}');
    }
  }
}
