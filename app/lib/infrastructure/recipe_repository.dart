import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import '../domain/recipe.dart';
import 'network/api_client.dart';

String _formatDioError(String action, DioException e) {
  final status = e.response?.statusCode;
  if (status != null) {
    return '$action ($status)';
  }
  final inner = e.error;
  if (inner != null) {
    return '$action ($inner)';
  }
  return '$action (${e.type.name}: ${e.message})';
}

class PaginatedRecipes {
  final List<Recipe> recipes;
  final int total;

  PaginatedRecipes({required this.recipes, required this.total});

  bool get hasMore => recipes.length < total;
}

class RecipeRepository {
  final ApiClient _apiClient;

  RecipeRepository(this._apiClient);

  Future<PaginatedRecipes> getRecipes({int limit = 20, int offset = 0, String search = ''}) async {
    try {
      dev.log('Fetching recipes (limit=$limit, offset=$offset, search="$search")', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/recipes', queryParameters: {
        'limit': limit,
        'offset': offset,
        if (search.isNotEmpty) 'search': search,
      });
      final Map<String, dynamic> data = response.data;
      final List<dynamic> recipesJson = data['recipes'];
      final int total = data['total'] as int;
      final recipes = recipesJson.map((json) => Recipe.fromJson(json)).toList();
      dev.log('Fetched ${recipes.length}/$total recipes', name: 'RecipeRepository');
      return PaginatedRecipes(recipes: recipes, total: total);
    } on DioException catch (e, stack) {
      dev.log('Failed to load recipes: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to load recipes', e));
    }
  }

  Future<List<Recipe>> getAllRecipes() async {
    final result = await getRecipes(limit: 100);
    return result.recipes;
  }

  Future<List<Recipe>> getFavouriteRecipes() async {
    try {
      dev.log('Fetching favourite recipes', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/recipes/meal-plan');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> recipes = data['recipes'];
      dev.log('Fetched ${recipes.length} favourite recipes', name: 'RecipeRepository');
      return recipes.map((json) => Recipe.fromJson(json)).toList();
    } on DioException catch (e, stack) {
      dev.log('Failed to load favourite recipes: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to load meal plan', e));
    }
  }

  Future<Recipe> getRecipe(int id) async {
    try {
      dev.log('Fetching recipe $id', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/recipes/$id');
      return Recipe.fromJson(response.data);
    } on DioException catch (e, stack) {
      dev.log('Failed to load recipe $id: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to load recipe', e));
    }
  }

  Future<void> toggleFavourite(int id) async {
    try {
      await _apiClient.dio.post('/recipes/$id/favourite');
    } on DioException catch (e, stack) {
      dev.log('Failed to toggle favourite for recipe $id: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to toggle favourite', e));
    }
  }

  Future<void> addToMealPlan(String uuid) async {
    try {
      dev.log('Adding $uuid to meal plan', name: 'RecipeRepository');
      await _apiClient.dio.post('/recipes/$uuid/meal-plan');
    } on DioException catch (e, stack) {
      dev.log('Failed to add $uuid to meal plan: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to add to meal plan', e));
    }
  }

  Future<void> removeFromMealPlan(String uuid) async {
    try {
      dev.log('Removing $uuid from meal plan', name: 'RecipeRepository');
      await _apiClient.dio.delete('/recipes/$uuid/meal-plan');
    } on DioException catch (e, stack) {
      dev.log('Failed to remove $uuid from meal plan: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to remove from meal plan', e));
    }
  }
}
