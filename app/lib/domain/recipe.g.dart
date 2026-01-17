// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecipeImpl _$$RecipeImplFromJson(Map<String, dynamic> json) => _$RecipeImpl(
  uuid: json['uuid'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  preparationTime: (json['prepTime'] as num).toInt(),
  cookingTime: (json['cookTime'] as num).toInt(),
  servings: (json['servings'] as num).toInt(),
  imageUrl: json['mainPhoto'] as String?,
  isFavourite: json['isInMealPlan'] as bool,
  ingredients: (json['ingredients'] as List<dynamic>)
      .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
      .toList(),
  steps: (json['steps'] as List<dynamic>)
      .map((e) => Step.fromJson(e as Map<String, dynamic>))
      .toList(),
  labels: (json['labels'] as List<dynamic>)
      .map((e) => Label.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$RecipeImplToJson(_$RecipeImpl instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'description': instance.description,
      'prepTime': instance.preparationTime,
      'cookTime': instance.cookingTime,
      'servings': instance.servings,
      'mainPhoto': instance.imageUrl,
      'isInMealPlan': instance.isFavourite,
      'ingredients': instance.ingredients,
      'steps': instance.steps,
      'labels': instance.labels,
    };
