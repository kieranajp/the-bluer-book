// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$IngredientImpl _$$IngredientImplFromJson(Map<String, dynamic> json) =>
    _$IngredientImpl(
      quantity: (json['quantity'] as num).toDouble(),
      detail: IngredientDetail.fromJson(
        json['ingredient'] as Map<String, dynamic>,
      ),
      unit: json['unit'] == null
          ? null
          : IngredientUnit.fromJson(json['unit'] as Map<String, dynamic>),
      preparation: json['preparation'] as String?,
    );

Map<String, dynamic> _$$IngredientImplToJson(_$IngredientImpl instance) =>
    <String, dynamic>{
      'quantity': instance.quantity,
      'ingredient': instance.detail,
      'unit': instance.unit,
      'preparation': instance.preparation,
    };

_$IngredientDetailImpl _$$IngredientDetailImplFromJson(
  Map<String, dynamic> json,
) => _$IngredientDetailImpl(name: json['name'] as String);

Map<String, dynamic> _$$IngredientDetailImplToJson(
  _$IngredientDetailImpl instance,
) => <String, dynamic>{'name': instance.name};

_$IngredientUnitImpl _$$IngredientUnitImplFromJson(Map<String, dynamic> json) =>
    _$IngredientUnitImpl(
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String?,
    );

Map<String, dynamic> _$$IngredientUnitImplToJson(
  _$IngredientUnitImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'abbreviation': instance.abbreviation,
};
