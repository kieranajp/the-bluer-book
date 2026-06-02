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
class PantryNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  final PantryRepository _repository;

  PantryNotifier(this._repository) : super(const AsyncValue.loading()) {
    load();
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

  bool has(String ingredient) => state.valueOrNull?.contains(ingredient) ?? false;

  /// Flip whether [ingredient] is in the pantry, optimistically updating local
  /// state and reverting if the API call fails.
  Future<void> toggle(String ingredient) async {
    final current = state.valueOrNull ?? const <String>{};
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
    StateNotifierProvider<PantryNotifier, AsyncValue<Set<String>>>((ref) {
  return PantryNotifier(ref.watch(pantryRepositoryProvider));
});
