import 'package:freezed_annotation/freezed_annotation.dart';
import 'ingredient.dart';
import 'step.dart';
import 'label.dart';

part 'recipe.freezed.dart';
part 'recipe.g.dart';

@freezed
class Recipe with _$Recipe {
  const factory Recipe({
    required String uuid,
    required String name,
    required String description,
    @JsonKey(name: 'prepTime') required int preparationTime,
    @JsonKey(name: 'cookTime') required int cookingTime,
    required int servings,
    @JsonKey(name: 'mainPhoto') String? imageUrl,
    @JsonKey(name: 'isInMealPlan') required bool isFavourite,
    required List<Ingredient> ingredients,
    required List<Step> steps,
    required List<Label> labels,
  }) = _Recipe;

  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);
}
