import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/shopping_list_item.dart';
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

/// The shopping list: meal-plan ingredients that aren't in the pantry, plus any
/// free-text custom items the user added or scanned from a photo. autoDispose
/// so it re-fetches each time the screen is opened (it depends on both the meal
/// plan and the pantry, which change elsewhere).
class ShoppingListNotifier
    extends Notifier<AsyncValue<List<ShoppingListItem>>> {
  PantryRepository get _repository => ref.read(pantryRepositoryProvider);

  @override
  AsyncValue<List<ShoppingListItem>> build() {
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

  /// Check an item off the list. A meal-plan ingredient goes into the pantry
  /// (so it stays off the list); a custom item is simply deleted. Optimistic —
  /// reverts if the API call fails.
  Future<void> check(ShoppingListItem item) async {
    final current = state.value ?? const <ShoppingListItem>[];
    state = AsyncValue.data(
        current.where((e) => e.name != item.name).toList());
    try {
      if (item.isCustom) {
        await _repository.removeCustomShoppingItem(item.name);
      } else {
        await _repository.addToPantry(item.name);
        ref.invalidate(pantryProvider);
      }
    } catch (e, stack) {
      dev.log('Failed to check off "${item.name}"',
          name: 'ShoppingListNotifier', error: e, stackTrace: stack);
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Add a free-text custom item to the list. Optimistic — reverts on failure.
  /// No-ops if an item with the same name (case-insensitive) is already there.
  Future<void> addCustom(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final current = state.value ?? const <ShoppingListItem>[];
    if (current.any((e) => e.name.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    state = AsyncValue.data([...current, ShoppingListItem.custom(trimmed)]);
    try {
      await _repository.addCustomShoppingItem(trimmed);
    } catch (e, stack) {
      dev.log('Failed to add custom item "$trimmed"',
          name: 'ShoppingListNotifier', error: e, stackTrace: stack);
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Upload a photo of a physical shopping list; Gemini parses it and the items
  /// are added as custom items. Reloads the list and returns how many were
  /// added.
  Future<int> scan(Uint8List bytes, String filename) async {
    try {
      final added = await _repository.scanShoppingList(bytes, filename);
      await load();
      return added.length;
    } catch (e, stack) {
      dev.log('Failed to scan shopping list',
          name: 'ShoppingListNotifier', error: e, stackTrace: stack);
      rethrow;
    }
  }
}

final shoppingListProvider = NotifierProvider.autoDispose<ShoppingListNotifier,
    AsyncValue<List<ShoppingListItem>>>(ShoppingListNotifier.new);
