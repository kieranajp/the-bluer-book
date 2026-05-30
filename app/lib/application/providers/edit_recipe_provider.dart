import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../../domain/ingredient.dart';
import '../../domain/step.dart' as domain;
import '../../domain/label.dart';
import '../../infrastructure/recipe_repository.dart';
import 'recipe_providers.dart';

// --- Mutable form state classes ---

int _nextId = 0;
int _generateId() => _nextId++;

class EditableIngredient {
  final int id;
  String name;
  double quantity;
  String unitName;
  String unitAbbreviation;
  String preparation;
  String component;

  EditableIngredient({
    int? id,
    required this.name,
    required this.quantity,
    required this.unitName,
    this.unitAbbreviation = '',
    this.preparation = '',
    this.component = '',
  }) : id = id ?? _generateId();

  EditableIngredient.fromIngredient(Ingredient ingredient)
      : id = _generateId(),
        name = ingredient.detail.name,
        quantity = ingredient.quantity,
        unitName = ingredient.unit?.name ?? '',
        unitAbbreviation = ingredient.unit?.abbreviation ?? '',
        preparation = ingredient.preparation ?? '',
        component = ingredient.component ?? '';

  EditableIngredient clone() => EditableIngredient(
        id: id,
        name: name,
        quantity: quantity,
        unitName: unitName,
        unitAbbreviation: unitAbbreviation,
        preparation: preparation,
        component: component,
      );
}

class EditableStep {
  final int id;
  String description;

  EditableStep({int? id, required this.description})
      : id = id ?? _generateId();

  EditableStep.fromStep(domain.Step step)
      : id = _generateId(),
        description = step.description;

  EditableStep clone() => EditableStep(id: id, description: description);
}

class EditableLabel {
  String type;
  String name;

  EditableLabel({required this.type, required this.name});

  EditableLabel.fromLabel(Label label)
      : type = label.type,
        name = label.name;

  EditableLabel clone() => EditableLabel(type: type, name: name);
}

class EditRecipeState {
  final String name;
  final String description;
  final int preparationTime;
  final int cookingTime;
  final int servings;
  final List<EditableIngredient> ingredients;
  final List<EditableStep> steps;
  final List<EditableLabel> labels;
  final bool isSaving;
  final String? imageUrl;
  final bool isInMealPlan;
  final Uint8List? pendingPhotoBytes;
  final String? pendingPhotoFilename;
  final bool isUploadingPhoto;

  const EditRecipeState({
    required this.name,
    required this.description,
    required this.preparationTime,
    required this.cookingTime,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.labels,
    this.isSaving = false,
    this.imageUrl,
    this.isInMealPlan = false,
    this.pendingPhotoBytes,
    this.pendingPhotoFilename,
    this.isUploadingPhoto = false,
  });

  factory EditRecipeState.fromRecipe(Recipe recipe) {
    return EditRecipeState(
      name: recipe.name,
      description: recipe.description,
      preparationTime: recipe.preparationTime,
      cookingTime: recipe.cookingTime,
      servings: recipe.servings,
      ingredients: recipe.ingredients
          .map((i) => EditableIngredient.fromIngredient(i))
          .toList(),
      steps: recipe.steps.map((s) => EditableStep.fromStep(s)).toList(),
      labels: recipe.labels.map((l) => EditableLabel.fromLabel(l)).toList(),
      imageUrl: recipe.imageUrl,
      isInMealPlan: recipe.isFavourite,
    );
  }

  factory EditRecipeState.blank() => EditRecipeState(
        name: '',
        description: '',
        preparationTime: 0,
        cookingTime: 0,
        servings: 1,
        ingredients: const [],
        steps: const [],
        labels: const [],
      );

  Recipe toRecipe(String uuid) {
    return Recipe(
      uuid: uuid,
      name: name.trim(),
      description: description.trim(),
      preparationTime: preparationTime,
      cookingTime: cookingTime,
      servings: servings,
      imageUrl: imageUrl,
      isFavourite: isInMealPlan,
      ingredients: ingredients
          .map((i) => Ingredient(
                quantity: i.quantity,
                detail: IngredientDetail(name: i.name.trim()),
                unit: i.unitName.trim().isEmpty
                    ? null
                    : IngredientUnit(
                        name: i.unitName.trim(),
                        abbreviation: i.unitAbbreviation.trim().isEmpty
                            ? null
                            : i.unitAbbreviation.trim(),
                      ),
                preparation:
                    i.preparation.trim().isEmpty ? null : i.preparation.trim(),
                component:
                    i.component.trim().isEmpty ? null : i.component.trim(),
              ))
          .toList(),
      steps: List.generate(
        steps.length,
        (i) => domain.Step(
          order: i + 1,
          description: steps[i].description.trim(),
        ),
      ),
      labels: labels
          .map((l) => Label(
                type: l.type.trim(),
                name: l.name.trim(),
              ))
          .toList(),
    );
  }

  EditRecipeState copyWith({
    String? name,
    String? description,
    int? preparationTime,
    int? cookingTime,
    int? servings,
    List<EditableIngredient>? ingredients,
    List<EditableStep>? steps,
    List<EditableLabel>? labels,
    bool? isSaving,
    String? imageUrl,
    bool clearImageUrl = false,
    bool? isInMealPlan,
    Uint8List? pendingPhotoBytes,
    String? pendingPhotoFilename,
    bool clearPendingPhoto = false,
    bool? isUploadingPhoto,
  }) {
    return EditRecipeState(
      name: name ?? this.name,
      description: description ?? this.description,
      preparationTime: preparationTime ?? this.preparationTime,
      cookingTime: cookingTime ?? this.cookingTime,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      labels: labels ?? this.labels,
      isSaving: isSaving ?? this.isSaving,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      isInMealPlan: isInMealPlan ?? this.isInMealPlan,
      pendingPhotoBytes: clearPendingPhoto ? null : (pendingPhotoBytes ?? this.pendingPhotoBytes),
      pendingPhotoFilename: clearPendingPhoto ? null : (pendingPhotoFilename ?? this.pendingPhotoFilename),
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
    );
  }
}

// --- Notifier: all edit logic lives here ---

class EditRecipeNotifier extends StateNotifier<EditRecipeState> {
  final RecipeRepository _repository;
  final Ref _ref;
  final String? _uuid;

  EditRecipeNotifier(this._repository, this._ref, Recipe recipe)
      : _uuid = recipe.uuid,
        super(EditRecipeState.fromRecipe(recipe));

  EditRecipeNotifier.create(this._repository, this._ref)
      : _uuid = null,
        super(EditRecipeState.blank());

  bool get isCreating => _uuid == null;

  // Scalar field updates

  void updateName(String value) {
    state = state.copyWith(name: value);
  }

  void updateDescription(String value) {
    state = state.copyWith(description: value);
  }

  void updatePrepTime(int value) {
    state = state.copyWith(preparationTime: value);
  }

  void updateCookTime(int value) {
    state = state.copyWith(cookingTime: value);
  }

  void updateServings(int value) {
    state = state.copyWith(servings: value);
  }

  void setPhoto(Uint8List bytes, String filename) {
    state = state.copyWith(
      pendingPhotoBytes: bytes,
      pendingPhotoFilename: filename,
    );
  }

  void removePhoto() {
    state = state.copyWith(
      clearImageUrl: true,
      clearPendingPhoto: true,
    );
  }

  // Ingredient CRUD

  void addIngredient() {
    state = state.copyWith(
      ingredients: [
        ...state.ingredients,
        EditableIngredient(name: '', quantity: 0, unitName: ''),
      ],
    );
  }

  void removeIngredient(int index) {
    final updated = [...state.ingredients]..removeAt(index);
    state = state.copyWith(ingredients: updated);
  }

  void updateIngredient(int index, EditableIngredient ingredient) {
    final updated = [...state.ingredients];
    updated[index] = ingredient;
    state = state.copyWith(ingredients: updated);
  }

  // Step CRUD

  void addStep() {
    state = state.copyWith(
      steps: [...state.steps, EditableStep(description: '')],
    );
  }

  void removeStep(int index) {
    final updated = [...state.steps]..removeAt(index);
    state = state.copyWith(steps: updated);
  }

  void updateStep(int index, EditableStep step) {
    final updated = [...state.steps];
    updated[index] = step;
    state = state.copyWith(steps: updated);
  }

  // newIndex arrives already adjusted for the removed item (onReorderItem
  // contract), so no manual `newIndex--` is needed here.
  void reorderIngredients(int oldIndex, int newIndex) {
    final updated = [...state.ingredients];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = state.copyWith(ingredients: updated);
  }

  void reorderSteps(int oldIndex, int newIndex) {
    final updated = [...state.steps];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = state.copyWith(steps: updated);
  }

  // Label CRUD

  void addLabel({required String type, required String name}) {
    final t = type.trim();
    final n = name.trim();
    if (t.isEmpty || n.isEmpty) return;
    final exists = state.labels
        .any((l) => l.type == t && l.name == n);
    if (exists) return;
    state = state.copyWith(
      labels: [...state.labels, EditableLabel(type: t, name: n)],
    );
  }

  void removeLabel(int index) {
    final updated = [...state.labels]..removeAt(index);
    state = state.copyWith(labels: updated);
  }

  // Validation — returns null if valid, or an error message

  String? validate() {
    if (state.name.trim().isEmpty) return 'Recipe name is required';
    if (state.ingredients.isEmpty) {
      return 'At least one ingredient is required';
    }
    for (final ing in state.ingredients) {
      if (ing.name.trim().isEmpty) return 'All ingredients must have a name';
      if (ing.quantity < 0) {
        return 'Ingredient quantity cannot be negative';
      }
    }
    if (state.steps.isEmpty) return 'At least one step is required';
    for (final step in state.steps) {
      if (step.description.trim().isEmpty) {
        return 'All steps must have a description';
      }
    }
    return null;
  }

  // Save — validates, calls API, invalidates list providers

  Future<bool> save() async {
    final error = validate();
    if (error != null) return false;

    state = state.copyWith(isSaving: true);
    try {
      String recipeUuid;
      final uuid = _uuid;
      if (uuid == null) {
        final created = await _repository.createRecipe(state.toRecipe(''));
        recipeUuid = created.uuid;
        dev.log('Recipe $recipeUuid created', name: 'EditRecipeNotifier');
      } else {
        await _repository.updateRecipe(uuid, state.toRecipe(uuid));
        recipeUuid = uuid;
        dev.log('Recipe $uuid updated', name: 'EditRecipeNotifier');
      }

      if (state.pendingPhotoBytes != null && state.pendingPhotoFilename != null) {
        final url = await _repository.uploadRecipePhoto(
          recipeUuid,
          state.pendingPhotoBytes!,
          state.pendingPhotoFilename!,
        );
        dev.log('Photo uploaded for $recipeUuid: $url', name: 'EditRecipeNotifier');
      }

      state = state.copyWith(isSaving: false);
      _ref.invalidate(recipeListProvider);
      _ref.invalidate(favouriteRecipesProvider);
      return true;
    } catch (e, stack) {
      dev.log('Failed to save recipe ${_uuid ?? "(new)"}',
          name: 'EditRecipeNotifier', error: e, stackTrace: stack);
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

// Provider keyed on Recipe — autoDispose cleans up when edit screen pops

final editRecipeProvider = StateNotifierProvider.autoDispose
    .family<EditRecipeNotifier, EditRecipeState, Recipe>((ref, recipe) {
  return EditRecipeNotifier(
    ref.watch(recipeRepositoryProvider),
    ref,
    recipe,
  );
});

final newRecipeProvider =
    StateNotifierProvider.autoDispose<EditRecipeNotifier, EditRecipeState>(
        (ref) {
  return EditRecipeNotifier.create(
    ref.watch(recipeRepositoryProvider),
    ref,
  );
});
