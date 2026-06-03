// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Ingredient _$IngredientFromJson(Map<String, dynamic> json) => _Ingredient(
  quantity: (json['quantity'] as num).toDouble(),
  detail: IngredientDetail.fromJson(json['ingredient'] as Map<String, dynamic>),
  unit: json['unit'] == null
      ? null
      : IngredientUnit.fromJson(json['unit'] as Map<String, dynamic>),
  preparation: json['preparation'] as String?,
  component: json['component'] as String?,
);

Map<String, dynamic> _$IngredientToJson(_Ingredient instance) =>
    <String, dynamic>{
      'quantity': instance.quantity,
      'ingredient': instance.detail,
      'unit': instance.unit,
      'preparation': instance.preparation,
      'component': instance.component,
    };

_IngredientDetail _$IngredientDetailFromJson(Map<String, dynamic> json) =>
    _IngredientDetail(name: json['name'] as String);

Map<String, dynamic> _$IngredientDetailToJson(_IngredientDetail instance) =>
    <String, dynamic>{'name': instance.name};

_IngredientUnit _$IngredientUnitFromJson(Map<String, dynamic> json) =>
    _IngredientUnit(
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String?,
    );

Map<String, dynamic> _$IngredientUnitToJson(_IngredientUnit instance) =>
    <String, dynamic>{
      'name': instance.name,
      'abbreviation': instance.abbreviation,
    };
