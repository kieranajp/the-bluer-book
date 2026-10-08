import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/providers/recipe_providers.dart';
import 'package:app/domain/recipe.dart';
import 'package:app/infrastructure/network/api_client.dart';
import 'package:app/infrastructure/recipe_repository.dart';

Recipe _recipe(String uuid, {bool inPlan = true}) => Recipe(
      uuid: uuid,
      name: uuid,
      description: '',
      preparationTime: 5,
      cookingTime: 10,
      servings: 2,
      isInMealPlan: inPlan,
      ingredients: const [],
      steps: const [],
      labels: const [],
    );

class _FakeRepository extends RecipeRepository {
  _FakeRepository() : super(ApiClient());

  final recipes = {
    'loaded': _recipe('loaded'),
    'outside-page': _recipe('outside-page'),
  };
  final removed = <String>[];
  final added = <String>[];
  bool failMutation = false;
  Completer<void>? listGate;
  Completer<void>? mutationGate;

  @override
  Future<PaginatedRecipes> getRecipes({
    int limit = 20,
    int offset = 0,
    String search = '',
    String sort = '',
    List<String> labels = const [],
  }) async {
    if (listGate != null) await listGate!.future;
    return PaginatedRecipes(recipes: [recipes['loaded']!], total: 2);
  }

  @override
  Future<Recipe> getRecipe(String uuid) async {
    final recipe = recipes[uuid];
    if (recipe == null) throw Exception('Recipe not found');
    return recipe;
  }

  @override
  Future<List<Recipe>> getMealPlanRecipes() async =>
      recipes.values.where((recipe) => recipe.isInMealPlan).toList();

  @override
  Future<void> removeFromMealPlan(String uuid) async {
    if (mutationGate != null) await mutationGate!.future;
    if (failMutation) throw Exception('Removal failed');
    removed.add(uuid);
    recipes[uuid] = recipes[uuid]!.copyWith(isInMealPlan: false);
  }

  @override
  Future<void> addToMealPlan(String uuid) async {
    if (mutationGate != null) await mutationGate!.future;
    if (failMutation) throw Exception('Addition failed');
    added.add(uuid);
    recipes[uuid] = recipes[uuid]!.copyWith(isInMealPlan: true);
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeRepository();
    container = ProviderContainer(overrides: [
      recipeRepositoryProvider.overrideWithValue(repo),
    ]);
  });

  tearDown(() => container.dispose());

  Future<RecipeListNotifier> loadedNotifier() async {
    final notifier = container.read(recipeListProvider.notifier);
    await _settle();
    return notifier;
  }

  test('removes a meal plan recipe outside the loaded page', () async {
    final notifier = await loadedNotifier();
    container.listen(recipeDetailProvider('outside-page'), (_, _) {});
    container.listen(mealPlanRecipesProvider, (_, _) {});
    expect(
      (await container.read(recipeDetailProvider('outside-page').future))
          .isInMealPlan,
      isTrue,
    );
    expect(await container.read(mealPlanRecipesProvider.future), hasLength(2));

    await notifier.toggleMealPlan('outside-page');

    expect(repo.removed, ['outside-page']);
    expect(
      (await container.read(recipeDetailProvider('outside-page').future))
          .isInMealPlan,
      isFalse,
    );
    expect(
      (await container.read(mealPlanRecipesProvider.future))
          .map((recipe) => recipe.uuid),
      ['loaded'],
    );
    expect(
      container.read(recipeListProvider).value!.map((recipe) => recipe.uuid),
      ['loaded'],
    );
    expect(notifier.total, 2);
  });

  test('removes a recipe while the home list is loading', () async {
    repo.listGate = Completer<void>();
    final notifier = container.read(recipeListProvider.notifier);
    await _settle();
    expect(container.read(recipeListProvider).isLoading, isTrue);

    await notifier.toggleMealPlan('outside-page');

    expect(repo.removed, ['outside-page']);
    expect(container.read(recipeListProvider).isLoading, isTrue);
    repo.listGate!.complete();
    await _settle();
  });

  test('can add an outside-page recipe back after removing it', () async {
    final notifier = await loadedNotifier();

    await notifier.toggleMealPlan('outside-page');
    await notifier.toggleMealPlan('outside-page');

    expect(repo.removed, ['outside-page']);
    expect(repo.added, ['outside-page']);
    expect(repo.recipes['outside-page']!.isInMealPlan, isTrue);
  });

  test('propagates removal failures for an outside-page recipe', () async {
    final notifier = await loadedNotifier();
    repo.failMutation = true;

    await expectLater(
      notifier.toggleMealPlan('outside-page'),
      throwsException,
    );

    expect(repo.removed, isEmpty);
    expect(repo.recipes['outside-page']!.isInMealPlan, isTrue);
    expect(container.read(recipeListProvider).value, hasLength(1));
  });

  test('an unknown recipe fails instead of reporting success', () async {
    final notifier = await loadedNotifier();

    await expectLater(notifier.toggleMealPlan('missing'), throwsException);

    expect(repo.removed, isEmpty);
    expect(repo.added, isEmpty);
  });

  test('optimistically updates a loaded recipe and rolls back on failure', () async {
    final notifier = await loadedNotifier();
    repo.failMutation = true;
    repo.mutationGate = Completer<void>();

    final mutation = notifier.toggleMealPlan('loaded');
    final failure = expectLater(mutation, throwsException);
    expect(container.read(recipeListProvider).value!.single.isInMealPlan, isFalse);
    repo.mutationGate!.complete();
    await failure;

    expect(container.read(recipeListProvider).value!.single.isInMealPlan, isTrue);
  });
}
