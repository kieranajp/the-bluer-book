import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient.freezed.dart';
part 'ingredient.g.dart';

@freezed
abstract class Ingredient with _$Ingredient {
  const factory Ingredient({
    required double quantity,
    @JsonKey(name: 'ingredient') required IngredientDetail detail,
    IngredientUnit? unit,
    String? preparation,
    String? component,
  }) = _Ingredient;

  factory Ingredient.fromJson(Map<String, dynamic> json) => _$IngredientFromJson(json);
}

/// Derives the matching key for an ingredient name, mirroring the backend's
/// `canonical_name` (`lower(btrim(name))`). Only a fallback: prefer the
/// `canonical` the API sends, which is authoritative.
///
/// Matching on the display name is what used to make "Salt" in the pantry fail
/// to tick the "salt" row in a recipe.
String ingredientKey(String name) => name.trim().toLowerCase();

@freezed
abstract class IngredientDetail with _$IngredientDetail {
  const IngredientDetail._();

  const factory IngredientDetail({
    required String name,
    String? canonical,
    @Default(false) bool isStaple,
  }) = _IngredientDetail;

  factory IngredientDetail.fromJson(Map<String, dynamic> json) => _$IngredientDetailFromJson(json);

  /// What to compare on. [name] is for display only — it keeps whatever casing
  /// it was written with, because names like "MSG" don't survive lowercasing.
  String get key => canonical ?? ingredientKey(name);
}

@freezed
abstract class IngredientUnit with _$IngredientUnit {
  const factory IngredientUnit({
    required String name,
    String? abbreviation,
  }) = _IngredientUnit;

  factory IngredientUnit.fromJson(Map<String, dynamic> json) => _$IngredientUnitFromJson(json);
}
