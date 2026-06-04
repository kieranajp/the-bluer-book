import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/domain/recipe.dart';
import 'package:app/application/providers/recipe_providers.dart';
import 'package:app/infrastructure/network/api_client.dart';
import 'package:app/infrastructure/recipe_repository.dart';

Recipe _recipe(String uuid, String name) => Recipe(
      uuid: uuid,
      name: name,
      description: '',
      preparationTime: 5,
      cookingTime: 10,
      servings: 2,
      isInMealPlan: false,
      ingredients: const [],
      steps: const [],
      labels: const [],
    );

/// A repository that serves a fixed list and records delete calls, so the
/// notifier's optimistic logic can be exercised without touching the network.
class _FakeRepository extends RecipeRepository {
  _FakeRepository(this.seed) : super(ApiClient());

  final List<Recipe> seed;
  bool shouldFailDelete = false;
  final List<String> deleted = [];

  @override
  Future<PaginatedRecipes> getRecipes({
    int limit = 20,
    int offset = 0,
    String search = '',
    String sort = '',
    List<String> labels = const [],
  }) async {
    return PaginatedRecipes(recipes: List.of(seed), total: seed.length);
  }

  @override
  Future<void> deleteRecipe(String uuid) async {
    if (shouldFailDelete) throw Exception('delete failed');
    deleted.add(uuid);
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('RecipeListNotifier.deleteRecipe', () {
    late _FakeRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeRepository([
        _recipe('a', 'Apple pie'),
        _recipe('b', 'Banana bread'),
        _recipe('c', 'Carrot cake'),
      ]);
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

    test('removes the recipe from the list and shrinks the total', () async {
      final notifier = await loadedNotifier();
      expect(container.read(recipeListProvider).value, hasLength(3));
      expect(notifier.total, 3);

      await notifier.deleteRecipe('b');

      final remaining = container.read(recipeListProvider).value!;
      expect(remaining.map((r) => r.uuid), ['a', 'c']);
      expect(notifier.total, 2);
      expect(repo.deleted, ['b']);
    });

    test('reverts the list and total when the API call fails', () async {
      repo.shouldFailDelete = true;
      final notifier = await loadedNotifier();

      await expectLater(notifier.deleteRecipe('b'), throwsException);

      final remaining = container.read(recipeListProvider).value!;
      expect(remaining.map((r) => r.uuid), ['a', 'b', 'c']);
      expect(notifier.total, 3);
    });

    test('is a no-op for an unknown uuid', () async {
      final notifier = await loadedNotifier();

      await notifier.deleteRecipe('does-not-exist');

      expect(container.read(recipeListProvider).value, hasLength(3));
      expect(notifier.total, 3);
      expect(repo.deleted, isEmpty);
    });
  });
}
