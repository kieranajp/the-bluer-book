import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:app/infrastructure/recipe_repository.dart';
import 'package:app/application/providers/recipe_providers.dart';
import 'package:app/domain/recipe.dart';
import 'package:app/domain/ingredient.dart';
import 'package:app/domain/step.dart' as domain_step;
import 'package:app/domain/label.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  late MockRecipeRepository mockRepo;
  late ProviderContainer container;

  final defaultRecipe = Recipe(
    uuid: '123-abc',
    name: 'Spaghetti',
    description: 'Pasta',
    preparationTime: 10,
    cookingTime: 15,
    servings: 2,
    ingredients: [],
    steps: [],
    labels: [],
    isFavourite: false,
  );

  setUp(() {
    mockRepo = MockRecipeRepository();
    
    when(() => mockRepo.getRecipes(limit: any(named: 'limit'), offset: any(named: 'offset'), search: any(named: 'search')))
        .thenAnswer((_) async => PaginatedRecipes(recipes: [], total: 0));

    container = ProviderContainer(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('RecipeListNotifier', () {
    test('initial state is loading and calls loadRecipes', () async {
      when(() => mockRepo.getRecipes(limit: 20, offset: 0, search: ''))
          .thenAnswer((_) async => PaginatedRecipes(recipes: [defaultRecipe], total: 1));
          
      // Act
      final container = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      
      final sub = container.listen(recipeListProvider, (_, __) {});

      // Initially it should be loading because loadRecipes is called in constructor
      final value = container.read(recipeListProvider);
      expect(value, const AsyncValue<List<Recipe>>.loading());

      // Wait for it to finish
      await Future.delayed(Duration.zero);
      
      final valueAfter = container.read(recipeListProvider);
      expect(valueAfter.hasValue, true);
      expect(valueAfter.value!.length, 1);
      sub.close();
    });

    test('loadMore appends recipes and handles pagination flags', () async {
      when(() => mockRepo.getRecipes(limit: 20, offset: 0, search: ''))
          .thenAnswer((_) async => PaginatedRecipes(recipes: [defaultRecipe], total: 2));

      final container = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(recipeListProvider.notifier);
      await Future.delayed(Duration.zero);

      expect(notifier.hasMore, true);
      
      // Setup mock to return the second page
      final secondRecipe = defaultRecipe.copyWith(uuid: 'page-2');
      when(() => mockRepo.getRecipes(limit: 20, offset: 1, search: ''))
          .thenAnswer((_) async => PaginatedRecipes(recipes: [secondRecipe], total: 2));

      expect(notifier.isLoadingMore, false);
      
      final loadMoreFuture = notifier.loadMore();
      expect(notifier.isLoadingMore, true);
      
      await loadMoreFuture;

      expect(notifier.isLoadingMore, false);
      expect(notifier.hasMore, false);
      
      final currentRecipes = container.read(recipeListProvider).value!;
      expect(currentRecipes.length, 2);
      expect(currentRecipes.last.uuid, 'page-2');
    });

    test('toggleMealPlan updates state optimistically and reverts on error', () async {
      when(() => mockRepo.getRecipes(limit: 20, offset: 0, search: ''))
          .thenAnswer((_) async => PaginatedRecipes(recipes: [defaultRecipe], total: 1));

      final container = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(recipeListProvider.notifier);
      await Future.delayed(Duration.zero);

      final recipes = container.read(recipeListProvider).value!;
      expect(recipes.first.isFavourite, false);

      // Simulate a repository error
      when(() => mockRepo.addToMealPlan('123-abc')).thenThrow(Exception('Failed to add'));

      await expectLater(
        notifier.toggleMealPlan('123-abc'),
        throwsException,
      );

      // Should be reverted back to false
      final recipesAfter = container.read(recipeListProvider).value!;
      expect(recipesAfter.first.isFavourite, false);

      clearInteractions(mockRepo);

      // Verify success case
      when(() => mockRepo.addToMealPlan('123-abc')).thenAnswer((_) async {});
      await notifier.toggleMealPlan('123-abc');

      final recipesSuccess = container.read(recipeListProvider).value!;
      expect(recipesSuccess.first.isFavourite, true);
      verify(() => mockRepo.addToMealPlan('123-abc')).called(1);
    });
  });

  group('RecipeDetailNotifier', () {
    test('loadRecipe updates state with fetched recipe', () async {
      when(() => mockRepo.getRecipe(1))
          .thenAnswer((_) async => defaultRecipe);

      final notifier = container.read(recipeDetailProvider(1).notifier);

      expect(container.read(recipeDetailProvider(1)), const AsyncValue<Recipe?>.loading());

      await Future.delayed(Duration.zero);

      final value = container.read(recipeDetailProvider(1));
      expect(value.hasValue, true);
      expect(value.value?.name, 'Spaghetti');
    });

    test('toggleMealPlan handles optimistic update and revert', () async {
      when(() => mockRepo.getRecipe(1))
          .thenAnswer((_) async => defaultRecipe);

      final notifier = container.read(recipeDetailProvider(1).notifier);
      await Future.delayed(Duration.zero);

      when(() => mockRepo.addToMealPlan('123-abc')).thenThrow(Exception('Fail'));

      await expectLater(
        notifier.toggleMealPlan(),
        throwsException,
      );

      expect(container.read(recipeDetailProvider(1)).value!.isFavourite, false);

      clearInteractions(mockRepo);

      when(() => mockRepo.addToMealPlan('123-abc')).thenAnswer((_) async {});
      
      await notifier.toggleMealPlan();

      expect(container.read(recipeDetailProvider(1)).value!.isFavourite, true);
    });
  });
}
