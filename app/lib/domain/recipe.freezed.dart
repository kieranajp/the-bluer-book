// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Recipe {

 String get uuid; String get name; String get description;@JsonKey(name: 'prepTime') int get preparationTime;@JsonKey(name: 'cookTime') int get cookingTime; int get servings;@JsonKey(name: 'mainPhoto') String? get imageUrl;@JsonKey(name: 'url') String? get url; bool get isInMealPlan; List<Ingredient> get ingredients; List<Step> get steps; List<Label> get labels;
/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecipeCopyWith<Recipe> get copyWith => _$RecipeCopyWithImpl<Recipe>(this as Recipe, _$identity);

  /// Serializes this Recipe to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Recipe&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.preparationTime, preparationTime) || other.preparationTime == preparationTime)&&(identical(other.cookingTime, cookingTime) || other.cookingTime == cookingTime)&&(identical(other.servings, servings) || other.servings == servings)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.url, url) || other.url == url)&&(identical(other.isInMealPlan, isInMealPlan) || other.isInMealPlan == isInMealPlan)&&const DeepCollectionEquality().equals(other.ingredients, ingredients)&&const DeepCollectionEquality().equals(other.steps, steps)&&const DeepCollectionEquality().equals(other.labels, labels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,description,preparationTime,cookingTime,servings,imageUrl,url,isInMealPlan,const DeepCollectionEquality().hash(ingredients),const DeepCollectionEquality().hash(steps),const DeepCollectionEquality().hash(labels));

@override
String toString() {
  return 'Recipe(uuid: $uuid, name: $name, description: $description, preparationTime: $preparationTime, cookingTime: $cookingTime, servings: $servings, imageUrl: $imageUrl, url: $url, isInMealPlan: $isInMealPlan, ingredients: $ingredients, steps: $steps, labels: $labels)';
}


}

/// @nodoc
abstract mixin class $RecipeCopyWith<$Res>  {
  factory $RecipeCopyWith(Recipe value, $Res Function(Recipe) _then) = _$RecipeCopyWithImpl;
@useResult
$Res call({
 String uuid, String name, String description,@JsonKey(name: 'prepTime') int preparationTime,@JsonKey(name: 'cookTime') int cookingTime, int servings,@JsonKey(name: 'mainPhoto') String? imageUrl,@JsonKey(name: 'url') String? url, bool isInMealPlan, List<Ingredient> ingredients, List<Step> steps, List<Label> labels
});




}
/// @nodoc
class _$RecipeCopyWithImpl<$Res>
    implements $RecipeCopyWith<$Res> {
  _$RecipeCopyWithImpl(this._self, this._then);

  final Recipe _self;
  final $Res Function(Recipe) _then;

/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? name = null,Object? description = null,Object? preparationTime = null,Object? cookingTime = null,Object? servings = null,Object? imageUrl = freezed,Object? url = freezed,Object? isInMealPlan = null,Object? ingredients = null,Object? steps = null,Object? labels = null,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,preparationTime: null == preparationTime ? _self.preparationTime : preparationTime // ignore: cast_nullable_to_non_nullable
as int,cookingTime: null == cookingTime ? _self.cookingTime : cookingTime // ignore: cast_nullable_to_non_nullable
as int,servings: null == servings ? _self.servings : servings // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,isInMealPlan: null == isInMealPlan ? _self.isInMealPlan : isInMealPlan // ignore: cast_nullable_to_non_nullable
as bool,ingredients: null == ingredients ? _self.ingredients : ingredients // ignore: cast_nullable_to_non_nullable
as List<Ingredient>,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as List<Step>,labels: null == labels ? _self.labels : labels // ignore: cast_nullable_to_non_nullable
as List<Label>,
  ));
}

}


/// Adds pattern-matching-related methods to [Recipe].
extension RecipePatterns on Recipe {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Recipe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Recipe value)  $default,){
final _that = this;
switch (_that) {
case _Recipe():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Recipe value)?  $default,){
final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  String name,  String description, @JsonKey(name: 'prepTime')  int preparationTime, @JsonKey(name: 'cookTime')  int cookingTime,  int servings, @JsonKey(name: 'mainPhoto')  String? imageUrl, @JsonKey(name: 'url')  String? url,  bool isInMealPlan,  List<Ingredient> ingredients,  List<Step> steps,  List<Label> labels)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that.uuid,_that.name,_that.description,_that.preparationTime,_that.cookingTime,_that.servings,_that.imageUrl,_that.url,_that.isInMealPlan,_that.ingredients,_that.steps,_that.labels);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  String name,  String description, @JsonKey(name: 'prepTime')  int preparationTime, @JsonKey(name: 'cookTime')  int cookingTime,  int servings, @JsonKey(name: 'mainPhoto')  String? imageUrl, @JsonKey(name: 'url')  String? url,  bool isInMealPlan,  List<Ingredient> ingredients,  List<Step> steps,  List<Label> labels)  $default,) {final _that = this;
switch (_that) {
case _Recipe():
return $default(_that.uuid,_that.name,_that.description,_that.preparationTime,_that.cookingTime,_that.servings,_that.imageUrl,_that.url,_that.isInMealPlan,_that.ingredients,_that.steps,_that.labels);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  String name,  String description, @JsonKey(name: 'prepTime')  int preparationTime, @JsonKey(name: 'cookTime')  int cookingTime,  int servings, @JsonKey(name: 'mainPhoto')  String? imageUrl, @JsonKey(name: 'url')  String? url,  bool isInMealPlan,  List<Ingredient> ingredients,  List<Step> steps,  List<Label> labels)?  $default,) {final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that.uuid,_that.name,_that.description,_that.preparationTime,_that.cookingTime,_that.servings,_that.imageUrl,_that.url,_that.isInMealPlan,_that.ingredients,_that.steps,_that.labels);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Recipe implements Recipe {
  const _Recipe({required this.uuid, required this.name, required this.description, @JsonKey(name: 'prepTime') required this.preparationTime, @JsonKey(name: 'cookTime') required this.cookingTime, required this.servings, @JsonKey(name: 'mainPhoto') this.imageUrl, @JsonKey(name: 'url') this.url, required this.isInMealPlan, required final  List<Ingredient> ingredients, required final  List<Step> steps, required final  List<Label> labels}): _ingredients = ingredients,_steps = steps,_labels = labels;
  factory _Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

@override final  String uuid;
@override final  String name;
@override final  String description;
@override@JsonKey(name: 'prepTime') final  int preparationTime;
@override@JsonKey(name: 'cookTime') final  int cookingTime;
@override final  int servings;
@override@JsonKey(name: 'mainPhoto') final  String? imageUrl;
@override@JsonKey(name: 'url') final  String? url;
@override final  bool isInMealPlan;
 final  List<Ingredient> _ingredients;
@override List<Ingredient> get ingredients {
  if (_ingredients is EqualUnmodifiableListView) return _ingredients;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ingredients);
}

 final  List<Step> _steps;
@override List<Step> get steps {
  if (_steps is EqualUnmodifiableListView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_steps);
}

 final  List<Label> _labels;
@override List<Label> get labels {
  if (_labels is EqualUnmodifiableListView) return _labels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_labels);
}


/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecipeCopyWith<_Recipe> get copyWith => __$RecipeCopyWithImpl<_Recipe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecipeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Recipe&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.preparationTime, preparationTime) || other.preparationTime == preparationTime)&&(identical(other.cookingTime, cookingTime) || other.cookingTime == cookingTime)&&(identical(other.servings, servings) || other.servings == servings)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.url, url) || other.url == url)&&(identical(other.isInMealPlan, isInMealPlan) || other.isInMealPlan == isInMealPlan)&&const DeepCollectionEquality().equals(other._ingredients, _ingredients)&&const DeepCollectionEquality().equals(other._steps, _steps)&&const DeepCollectionEquality().equals(other._labels, _labels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,description,preparationTime,cookingTime,servings,imageUrl,url,isInMealPlan,const DeepCollectionEquality().hash(_ingredients),const DeepCollectionEquality().hash(_steps),const DeepCollectionEquality().hash(_labels));

@override
String toString() {
  return 'Recipe(uuid: $uuid, name: $name, description: $description, preparationTime: $preparationTime, cookingTime: $cookingTime, servings: $servings, imageUrl: $imageUrl, url: $url, isInMealPlan: $isInMealPlan, ingredients: $ingredients, steps: $steps, labels: $labels)';
}


}

/// @nodoc
abstract mixin class _$RecipeCopyWith<$Res> implements $RecipeCopyWith<$Res> {
  factory _$RecipeCopyWith(_Recipe value, $Res Function(_Recipe) _then) = __$RecipeCopyWithImpl;
@override @useResult
$Res call({
 String uuid, String name, String description,@JsonKey(name: 'prepTime') int preparationTime,@JsonKey(name: 'cookTime') int cookingTime, int servings,@JsonKey(name: 'mainPhoto') String? imageUrl,@JsonKey(name: 'url') String? url, bool isInMealPlan, List<Ingredient> ingredients, List<Step> steps, List<Label> labels
});




}
/// @nodoc
class __$RecipeCopyWithImpl<$Res>
    implements _$RecipeCopyWith<$Res> {
  __$RecipeCopyWithImpl(this._self, this._then);

  final _Recipe _self;
  final $Res Function(_Recipe) _then;

/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? name = null,Object? description = null,Object? preparationTime = null,Object? cookingTime = null,Object? servings = null,Object? imageUrl = freezed,Object? url = freezed,Object? isInMealPlan = null,Object? ingredients = null,Object? steps = null,Object? labels = null,}) {
  return _then(_Recipe(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,preparationTime: null == preparationTime ? _self.preparationTime : preparationTime // ignore: cast_nullable_to_non_nullable
as int,cookingTime: null == cookingTime ? _self.cookingTime : cookingTime // ignore: cast_nullable_to_non_nullable
as int,servings: null == servings ? _self.servings : servings // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,isInMealPlan: null == isInMealPlan ? _self.isInMealPlan : isInMealPlan // ignore: cast_nullable_to_non_nullable
as bool,ingredients: null == ingredients ? _self._ingredients : ingredients // ignore: cast_nullable_to_non_nullable
as List<Ingredient>,steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as List<Step>,labels: null == labels ? _self._labels : labels // ignore: cast_nullable_to_non_nullable
as List<Label>,
  ));
}


}

// dart format on
