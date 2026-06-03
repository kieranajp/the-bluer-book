import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/pantry_repository.dart';
import 'recipe_providers.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository(ref.watch(apiClientProvider));
});

/// Holds the set of ingredient names currently in the pantry. Kept as a set of
/// names because that's the lingua franca of the rest of the app (recipe
/// ingredients reference their ingredient by name) — membership is all the
/// "have / don't-have" model needs.
class PantryNotifier extends Notifier<AsyncValue<Set<String>>> {
  PantryRepository get _repository => ref.read(pantryRepositoryProvider);

  @override
  AsyncValue<Set<String>> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getPantry();
      state = AsyncValue.data(items.map((e) => e.ingredient).toSet());
    } catch (e, stack) {
      dev.log('Failed to load pantry', name: 'PantryNotifier', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  bool has(String ingredient) => state.value?.contains(ingredient) ?? false;

  /// Flip whether [ingredient] is in the pantry, optimistically updating local
  /// state and reverting if the API call fails.
  Future<void> toggle(String ingredient) async {
    final current = state.value ?? const <String>{};
    final wasIn = current.contains(ingredient);

    final next = {...current};
    if (wasIn) {
      next.remove(ingredient);
    } else {
      next.add(ingredient);
    }
    state = AsyncValue.data(next);

    try {
      if (wasIn) {
        await _repository.removeFromPantry(ingredient);
      } else {
        await _repository.addToPantry(ingredient);
      }
    } catch (e, stack) {
      dev.log('Failed to toggle pantry item "$ingredient"',
          name: 'PantryNotifier', error: e, stackTrace: stack);
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<void> add(String ingredient) {
    if (has(ingredient)) return Future.value();
    return toggle(ingredient);
  }

  Future<void> remove(String ingredient) {
    if (!has(ingredient)) return Future.value();
    return toggle(ingredient);
  }
}

final pantryProvider =
    NotifierProvider<PantryNotifier, AsyncValue<Set<String>>>(
        PantryNotifier.new);

/// The shopping list: ingredients needed for the meal plan that aren't in the
/// pantry. autoDispose so it re-fetches each time the screen is opened (it
/// depends on both the meal plan and the pantry, which change elsewhere).
class ShoppingListNotifier extends Notifier<AsyncValue<List<String>>> {
  PantryRepository get _repository => ref.read(pantryRepositoryProvider);

  @override
  AsyncValue<List<String>> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repository.getShoppingList());
    } catch (e, stack) {
      dev.log('Failed to load shopping list',
          name: 'ShoppingListNotifier', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  /// Mark an item as bought: it goes into the pantry and leaves the list.
  /// Optimistic — reverts if the API call fails.
  Future<void> check(String ingredient) async {
    final current = state.value ?? const <String>[];
    state = AsyncValue.data(current.where((e) => e != ingredient).toList());
    try {
      await _repository.addToPantry(ingredient);
      ref.invalidate(pantryProvider);
    } catch (e, stack) {
      dev.log('Failed to check off "$ingredient"',
          name: 'ShoppingListNotifier', error: e, stackTrace: stack);
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}

final shoppingListProvider =
    NotifierProvider.autoDispose<ShoppingListNotifier, AsyncValue<List<String>>>(
        ShoppingListNotifier.new);
