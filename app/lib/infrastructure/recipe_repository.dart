import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../domain/ingredient.dart';
import '../domain/label.dart';
import '../domain/recipe.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';

class PaginatedRecipes {
  final List<Recipe> recipes;
  final int total;

  PaginatedRecipes({required this.recipes, required this.total});

  bool get hasMore => recipes.length < total;
}

class RecipeRepository {
  final ApiClient _apiClient;

  RecipeRepository(this._apiClient);

  Future<PaginatedRecipes> getRecipes({
    int limit = 20,
    int offset = 0,
    String search = '',
    String sort = '',
    List<String> labels = const [],
  }) async {
    try {
      dev.log('Fetching recipes (limit=$limit, offset=$offset, search="$search", sort="$sort", labels="${labels.join(',')}")', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/recipes', queryParameters: {
        'limit': limit,
        'offset': offset,
        if (search.isNotEmpty) 'search': search,
        if (sort.isNotEmpty) 'sort': sort,
        if (labels.isNotEmpty) 'labels': labels.join(','),
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
      throw ApiException.fromDio('Failed to load recipes', e);
    }
  }

  Future<List<Recipe>> getAllRecipes() async {
    final result = await getRecipes(limit: 100);
    return result.recipes;
  }

  Future<List<Recipe>> getMealPlanRecipes() async {
    try {
      dev.log('Fetching meal plan recipes', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/recipes/meal-plan');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> recipes = data['recipes'];
      dev.log('Fetched ${recipes.length} meal plan recipes', name: 'RecipeRepository');
      return recipes.map((json) => Recipe.fromJson(json)).toList();
    } on DioException catch (e, stack) {
      dev.log('Failed to load meal plan recipes: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to load meal plan', e);
    }
  }

  Future<Recipe> getRecipe(String uuid) async {
    try {
      dev.log('Fetching recipe $uuid', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/recipes/$uuid');
      return Recipe.fromJson(response.data);
    } on DioException catch (e, stack) {
      dev.log('Failed to load recipe $uuid: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to load recipe', e);
    }
  }

  Future<void> deleteRecipe(String uuid) async {
    try {
      dev.log('Deleting recipe $uuid', name: 'RecipeRepository');
      await _apiClient.dio.delete('/recipes/$uuid');
    } on DioException catch (e, stack) {
      dev.log('Failed to delete recipe $uuid: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to delete recipe', e);
    }
  }

  Future<void> addToMealPlan(String uuid) async {
    try {
      dev.log('Adding $uuid to meal plan', name: 'RecipeRepository');
      await _apiClient.dio.post('/recipes/$uuid/meal-plan');
    } on DioException catch (e, stack) {
      dev.log('Failed to add $uuid to meal plan: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to add to meal plan', e);
    }
  }

  Future<List<IngredientDetail>> getIngredients() async {
    try {
      dev.log('Fetching ingredients', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/ingredients');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> ingredientsJson = data['ingredients'];
      return ingredientsJson
          .map((json) =>
              IngredientDetail.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, stack) {
      dev.log('Failed to load ingredients: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to load ingredients', e);
    }
  }

  Future<List<IngredientUnit>> getUnits() async {
    try {
      dev.log('Fetching units', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/units');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> unitsJson = data['units'];
      return unitsJson
          .map((json) =>
              IngredientUnit.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, stack) {
      dev.log('Failed to load units: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to load units', e);
    }
  }

  Future<List<LabelSummary>> getLabels() async {
    try {
      dev.log('Fetching labels', name: 'RecipeRepository');
      final response = await _apiClient.dio.get('/labels');
      final list = (response.data['labels'] as List)
          .map((json) => LabelSummary.fromJson(json as Map<String, dynamic>))
          .toList();
      dev.log('Fetched ${list.length} labels', name: 'RecipeRepository');
      return list;
    } on DioException catch (e, stack) {
      dev.log('Failed to load labels: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to load labels', e);
    }
  }

  Future<Recipe> createRecipe(Recipe recipe) async {
    try {
      dev.log('Creating recipe "${recipe.name}"', name: 'RecipeRepository');
      final data = recipe.toJson()..remove('uuid');
      final response = await _apiClient.dio.post('/recipes', data: data);
      return Recipe.fromJson(response.data);
    } on DioException catch (e, stack) {
      dev.log('Failed to create recipe: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to create recipe', e);
    }
  }

  Future<Recipe> updateRecipe(String uuid, Recipe recipe) async {
    try {
      dev.log('Updating recipe $uuid', name: 'RecipeRepository');
      final response = await _apiClient.dio.put(
        '/recipes/$uuid',
        data: recipe.toJson(),
      );
      return Recipe.fromJson(response.data);
    } on DioException catch (e, stack) {
      dev.log('Failed to update recipe $uuid: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to update recipe', e);
    }
  }

  Future<void> removeFromMealPlan(String uuid) async {
    try {
      dev.log('Removing $uuid from meal plan', name: 'RecipeRepository');
      await _apiClient.dio.delete('/recipes/$uuid/meal-plan');
    } on DioException catch (e, stack) {
      dev.log('Failed to remove $uuid from meal plan: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to remove from meal plan', e);
    }
  }

  Future<String> uploadRecipePhoto(String uuid, Uint8List bytes, String filename) async {
    try {
      dev.log('Uploading photo for recipe $uuid ($filename, ${bytes.length} bytes)',
          name: 'RecipeRepository');
      final ext = filename.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      });
      final response = await _apiClient.dio.post(
        '/recipes/$uuid/photo',
        data: formData,
      );
      final url = response.data['url'] as String;
      dev.log('Photo uploaded: $url', name: 'RecipeRepository');
      return url;
    } on DioException catch (e, stack) {
      dev.log('Failed to upload photo for recipe $uuid: ${e.message}',
          name: 'RecipeRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to upload photo', e);
    }
  }
}
