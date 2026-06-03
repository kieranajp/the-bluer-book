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

@freezed
abstract class IngredientDetail with _$IngredientDetail {
  const factory IngredientDetail({
    required String name,
  }) = _IngredientDetail;

  factory IngredientDetail.fromJson(Map<String, dynamic> json) => _$IngredientDetailFromJson(json);
}

@freezed
abstract class IngredientUnit with _$IngredientUnit {
  const factory IngredientUnit({
    required String name,
    String? abbreviation,
  }) = _IngredientUnit;

  factory IngredientUnit.fromJson(Map<String, dynamic> json) => _$IngredientUnitFromJson(json);
}
