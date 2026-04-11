import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:app/infrastructure/recipe_repository.dart';
import 'package:app/infrastructure/network/api_client.dart';
import 'package:app/domain/recipe.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/step.dart' as domain_step;
import 'package:app/domain/label.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockResponse<T> extends Mock implements Response<T> {}
class MockRequestOptions extends Mock implements RequestOptions {}

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late RecipeRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    repository = RecipeRepository(mockApiClient);
  });

  // A basic mock recipe to return
  final mockRecipeJson = <String, dynamic>{
    'uuid': '123-abc',
    'name': 'Test Recipe',
    'description': 'A delicious test recipe',
    'prepTime': 10,
    'cookTime': 20,
    'servings': 2,
    'mainPhoto': null,
    'isInMealPlan': false,
    'ingredients': <dynamic>[],
    'steps': <dynamic>[],
    'labels': <dynamic>[]
  };

  group('getRecipes', () {
    test('fetches recipes and handles pagination', () async {
      final mockResponse = MockResponse<Map<String, dynamic>>();
      when(() => mockResponse.data).thenReturn({
        'recipes': [mockRecipeJson],
        'total': 1
      });

      when(() => mockDio.get(
            '/recipes',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => mockResponse);

      final result = await repository.getRecipes(limit: 5, offset: 0, search: 'test');

      expect(result.total, 1);
      expect(result.recipes, isNotEmpty);
      expect(result.recipes.first.name, 'Test Recipe');
      expect(result.hasMore, false);

      verify(() => mockDio.get('/recipes', queryParameters: {'limit': 5, 'offset': 0, 'search': 'test'})).called(1);
    });

    test('throws wrapped exception on Dio error', () async {
      final mockDioException = DioException(
        requestOptions: RequestOptions(path: '/recipes'),
        response: Response(requestOptions: RequestOptions(path: '/recipes'), statusCode: 404),
      );

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(mockDioException);

      expect(
        () => repository.getRecipes(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Failed to load recipes (404)'))),
      );
    });
  });

  group('getAllRecipes', () {
    test('calls getRecipes with limit 100', () async {
      final mockResponse = MockResponse<Map<String, dynamic>>();
      when(() => mockResponse.data).thenReturn({
        'recipes': [mockRecipeJson],
        'total': 1
      });

      when(() => mockDio.get('/recipes', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => mockResponse);

      final recipes = await repository.getAllRecipes();

      expect(recipes.length, 1);
      verify(() => mockDio.get('/recipes', queryParameters: {'limit': 100, 'offset': 0})).called(1);
    });
  });

  group('getFavouriteRecipes', () {
    test('fetches favourite recipes successfully', () async {
      final mockResponse = MockResponse<Map<String, dynamic>>();
      when(() => mockResponse.data).thenReturn({
        'recipes': [mockRecipeJson]
      });

      when(() => mockDio.get('/recipes/meal-plan'))
          .thenAnswer((_) async => mockResponse);

      final recipes = await repository.getFavouriteRecipes();

      expect(recipes.length, 1);
      expect(recipes.first.name, 'Test Recipe');
      verify(() => mockDio.get('/recipes/meal-plan')).called(1);
    });
  });

  group('getRecipe', () {
    test('fetches single recipe successfully', () async {
      final mockResponse = MockResponse<dynamic>();
      when(() => mockResponse.data).thenReturn(mockRecipeJson);

      when(() => mockDio.get('/recipes/123'))
          .thenAnswer((_) async => mockResponse);

      final recipe = await repository.getRecipe(123);

      expect(recipe.name, 'Test Recipe');
      verify(() => mockDio.get('/recipes/123')).called(1);
    });
  });

  group('toggleFavourite', () {
    test('posts to toggle endpoint', () async {
      when(() => mockDio.post('/recipes/123/favourite'))
          .thenAnswer((_) async => MockResponse<dynamic>());

      await repository.toggleFavourite(123);

      verify(() => mockDio.post('/recipes/123/favourite')).called(1);
    });
  });

  group('addToMealPlan', () {
    test('posts to meal plan endpoint', () async {
      when(() => mockDio.post('/recipes/abc-123/meal-plan'))
          .thenAnswer((_) async => MockResponse<dynamic>());

      await repository.addToMealPlan('abc-123');

      verify(() => mockDio.post('/recipes/abc-123/meal-plan')).called(1);
    });
  });

  group('removeFromMealPlan', () {
    test('deletes from meal plan endpoint', () async {
      when(() => mockDio.delete('/recipes/abc-123/meal-plan'))
          .thenAnswer((_) async => MockResponse<dynamic>());

      await repository.removeFromMealPlan('abc-123');

      verify(() => mockDio.delete('/recipes/abc-123/meal-plan')).called(1);
    });
  });

  group('updateRecipe', () {
    test('puts updated data and returns updated recipe', () async {
      final mockResponse = MockResponse<dynamic>();
      when(() => mockResponse.data).thenReturn(mockRecipeJson);

      final recipeToUpdate = Recipe.fromJson(mockRecipeJson);

      when(() => mockDio.put('/recipes/abc-123', data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse);

      final result = await repository.updateRecipe('abc-123', recipeToUpdate);

      expect(result.name, 'Test Recipe');
      verify(() => mockDio.put('/recipes/abc-123', data: recipeToUpdate.toJson())).called(1);
    });
  });
}
