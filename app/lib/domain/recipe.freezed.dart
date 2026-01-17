// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Recipe _$RecipeFromJson(Map<String, dynamic> json) {
  return _Recipe.fromJson(json);
}

/// @nodoc
mixin _$Recipe {
  String get uuid => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'prepTime')
  int get preparationTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'cookTime')
  int get cookingTime => throw _privateConstructorUsedError;
  int get servings => throw _privateConstructorUsedError;
  @JsonKey(name: 'mainPhoto')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'isInMealPlan')
  bool get isFavourite => throw _privateConstructorUsedError;
  List<Ingredient> get ingredients => throw _privateConstructorUsedError;
  List<Step> get steps => throw _privateConstructorUsedError;
  List<Label> get labels => throw _privateConstructorUsedError;

  /// Serializes this Recipe to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeCopyWith<Recipe> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeCopyWith<$Res> {
  factory $RecipeCopyWith(Recipe value, $Res Function(Recipe) then) =
      _$RecipeCopyWithImpl<$Res, Recipe>;
  @useResult
  $Res call({
    String uuid,
    String name,
    String description,
    @JsonKey(name: 'prepTime') int preparationTime,
    @JsonKey(name: 'cookTime') int cookingTime,
    int servings,
    @JsonKey(name: 'mainPhoto') String? imageUrl,
    @JsonKey(name: 'isInMealPlan') bool isFavourite,
    List<Ingredient> ingredients,
    List<Step> steps,
    List<Label> labels,
  });
}

/// @nodoc
class _$RecipeCopyWithImpl<$Res, $Val extends Recipe>
    implements $RecipeCopyWith<$Res> {
  _$RecipeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uuid = null,
    Object? name = null,
    Object? description = null,
    Object? preparationTime = null,
    Object? cookingTime = null,
    Object? servings = null,
    Object? imageUrl = freezed,
    Object? isFavourite = null,
    Object? ingredients = null,
    Object? steps = null,
    Object? labels = null,
  }) {
    return _then(
      _value.copyWith(
            uuid: null == uuid
                ? _value.uuid
                : uuid // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            preparationTime: null == preparationTime
                ? _value.preparationTime
                : preparationTime // ignore: cast_nullable_to_non_nullable
                      as int,
            cookingTime: null == cookingTime
                ? _value.cookingTime
                : cookingTime // ignore: cast_nullable_to_non_nullable
                      as int,
            servings: null == servings
                ? _value.servings
                : servings // ignore: cast_nullable_to_non_nullable
                      as int,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isFavourite: null == isFavourite
                ? _value.isFavourite
                : isFavourite // ignore: cast_nullable_to_non_nullable
                      as bool,
            ingredients: null == ingredients
                ? _value.ingredients
                : ingredients // ignore: cast_nullable_to_non_nullable
                      as List<Ingredient>,
            steps: null == steps
                ? _value.steps
                : steps // ignore: cast_nullable_to_non_nullable
                      as List<Step>,
            labels: null == labels
                ? _value.labels
                : labels // ignore: cast_nullable_to_non_nullable
                      as List<Label>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeImplCopyWith<$Res> implements $RecipeCopyWith<$Res> {
  factory _$$RecipeImplCopyWith(
    _$RecipeImpl value,
    $Res Function(_$RecipeImpl) then,
  ) = __$$RecipeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String uuid,
    String name,
    String description,
    @JsonKey(name: 'prepTime') int preparationTime,
    @JsonKey(name: 'cookTime') int cookingTime,
    int servings,
    @JsonKey(name: 'mainPhoto') String? imageUrl,
    @JsonKey(name: 'isInMealPlan') bool isFavourite,
    List<Ingredient> ingredients,
    List<Step> steps,
    List<Label> labels,
  });
}

/// @nodoc
class __$$RecipeImplCopyWithImpl<$Res>
    extends _$RecipeCopyWithImpl<$Res, _$RecipeImpl>
    implements _$$RecipeImplCopyWith<$Res> {
  __$$RecipeImplCopyWithImpl(
    _$RecipeImpl _value,
    $Res Function(_$RecipeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uuid = null,
    Object? name = null,
    Object? description = null,
    Object? preparationTime = null,
    Object? cookingTime = null,
    Object? servings = null,
    Object? imageUrl = freezed,
    Object? isFavourite = null,
    Object? ingredients = null,
    Object? steps = null,
    Object? labels = null,
  }) {
    return _then(
      _$RecipeImpl(
        uuid: null == uuid
            ? _value.uuid
            : uuid // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        preparationTime: null == preparationTime
            ? _value.preparationTime
            : preparationTime // ignore: cast_nullable_to_non_nullable
                  as int,
        cookingTime: null == cookingTime
            ? _value.cookingTime
            : cookingTime // ignore: cast_nullable_to_non_nullable
                  as int,
        servings: null == servings
            ? _value.servings
            : servings // ignore: cast_nullable_to_non_nullable
                  as int,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isFavourite: null == isFavourite
            ? _value.isFavourite
            : isFavourite // ignore: cast_nullable_to_non_nullable
                  as bool,
        ingredients: null == ingredients
            ? _value._ingredients
            : ingredients // ignore: cast_nullable_to_non_nullable
                  as List<Ingredient>,
        steps: null == steps
            ? _value._steps
            : steps // ignore: cast_nullable_to_non_nullable
                  as List<Step>,
        labels: null == labels
            ? _value._labels
            : labels // ignore: cast_nullable_to_non_nullable
                  as List<Label>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeImpl implements _Recipe {
  const _$RecipeImpl({
    required this.uuid,
    required this.name,
    required this.description,
    @JsonKey(name: 'prepTime') required this.preparationTime,
    @JsonKey(name: 'cookTime') required this.cookingTime,
    required this.servings,
    @JsonKey(name: 'mainPhoto') this.imageUrl,
    @JsonKey(name: 'isInMealPlan') required this.isFavourite,
    required final List<Ingredient> ingredients,
    required final List<Step> steps,
    required final List<Label> labels,
  }) : _ingredients = ingredients,
       _steps = steps,
       _labels = labels;

  factory _$RecipeImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeImplFromJson(json);

  @override
  final String uuid;
  @override
  final String name;
  @override
  final String description;
  @override
  @JsonKey(name: 'prepTime')
  final int preparationTime;
  @override
  @JsonKey(name: 'cookTime')
  final int cookingTime;
  @override
  final int servings;
  @override
  @JsonKey(name: 'mainPhoto')
  final String? imageUrl;
  @override
  @JsonKey(name: 'isInMealPlan')
  final bool isFavourite;
  final List<Ingredient> _ingredients;
  @override
  List<Ingredient> get ingredients {
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingredients);
  }

  final List<Step> _steps;
  @override
  List<Step> get steps {
    if (_steps is EqualUnmodifiableListView) return _steps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_steps);
  }

  final List<Label> _labels;
  @override
  List<Label> get labels {
    if (_labels is EqualUnmodifiableListView) return _labels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_labels);
  }

  @override
  String toString() {
    return 'Recipe(uuid: $uuid, name: $name, description: $description, preparationTime: $preparationTime, cookingTime: $cookingTime, servings: $servings, imageUrl: $imageUrl, isFavourite: $isFavourite, ingredients: $ingredients, steps: $steps, labels: $labels)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeImpl &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.preparationTime, preparationTime) ||
                other.preparationTime == preparationTime) &&
            (identical(other.cookingTime, cookingTime) ||
                other.cookingTime == cookingTime) &&
            (identical(other.servings, servings) ||
                other.servings == servings) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.isFavourite, isFavourite) ||
                other.isFavourite == isFavourite) &&
            const DeepCollectionEquality().equals(
              other._ingredients,
              _ingredients,
            ) &&
            const DeepCollectionEquality().equals(other._steps, _steps) &&
            const DeepCollectionEquality().equals(other._labels, _labels));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    uuid,
    name,
    description,
    preparationTime,
    cookingTime,
    servings,
    imageUrl,
    isFavourite,
    const DeepCollectionEquality().hash(_ingredients),
    const DeepCollectionEquality().hash(_steps),
    const DeepCollectionEquality().hash(_labels),
  );

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeImplCopyWith<_$RecipeImpl> get copyWith =>
      __$$RecipeImplCopyWithImpl<_$RecipeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeImplToJson(this);
  }
}

abstract class _Recipe implements Recipe {
  const factory _Recipe({
    required final String uuid,
    required final String name,
    required final String description,
    @JsonKey(name: 'prepTime') required final int preparationTime,
    @JsonKey(name: 'cookTime') required final int cookingTime,
    required final int servings,
    @JsonKey(name: 'mainPhoto') final String? imageUrl,
    @JsonKey(name: 'isInMealPlan') required final bool isFavourite,
    required final List<Ingredient> ingredients,
    required final List<Step> steps,
    required final List<Label> labels,
  }) = _$RecipeImpl;

  factory _Recipe.fromJson(Map<String, dynamic> json) = _$RecipeImpl.fromJson;

  @override
  String get uuid;
  @override
  String get name;
  @override
  String get description;
  @override
  @JsonKey(name: 'prepTime')
  int get preparationTime;
  @override
  @JsonKey(name: 'cookTime')
  int get cookingTime;
  @override
  int get servings;
  @override
  @JsonKey(name: 'mainPhoto')
  String? get imageUrl;
  @override
  @JsonKey(name: 'isInMealPlan')
  bool get isFavourite;
  @override
  List<Ingredient> get ingredients;
  @override
  List<Step> get steps;
  @override
  List<Label> get labels;

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeImplCopyWith<_$RecipeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
