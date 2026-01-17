// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ingredient.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Ingredient _$IngredientFromJson(Map<String, dynamic> json) {
  return _Ingredient.fromJson(json);
}

/// @nodoc
mixin _$Ingredient {
  double get quantity => throw _privateConstructorUsedError;
  @JsonKey(name: 'ingredient')
  IngredientDetail get detail => throw _privateConstructorUsedError;
  IngredientUnit? get unit => throw _privateConstructorUsedError;
  String? get preparation => throw _privateConstructorUsedError;

  /// Serializes this Ingredient to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Ingredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IngredientCopyWith<Ingredient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IngredientCopyWith<$Res> {
  factory $IngredientCopyWith(
    Ingredient value,
    $Res Function(Ingredient) then,
  ) = _$IngredientCopyWithImpl<$Res, Ingredient>;
  @useResult
  $Res call({
    double quantity,
    @JsonKey(name: 'ingredient') IngredientDetail detail,
    IngredientUnit? unit,
    String? preparation,
  });

  $IngredientDetailCopyWith<$Res> get detail;
  $IngredientUnitCopyWith<$Res>? get unit;
}

/// @nodoc
class _$IngredientCopyWithImpl<$Res, $Val extends Ingredient>
    implements $IngredientCopyWith<$Res> {
  _$IngredientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Ingredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? quantity = null,
    Object? detail = null,
    Object? unit = freezed,
    Object? preparation = freezed,
  }) {
    return _then(
      _value.copyWith(
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as double,
            detail: null == detail
                ? _value.detail
                : detail // ignore: cast_nullable_to_non_nullable
                      as IngredientDetail,
            unit: freezed == unit
                ? _value.unit
                : unit // ignore: cast_nullable_to_non_nullable
                      as IngredientUnit?,
            preparation: freezed == preparation
                ? _value.preparation
                : preparation // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of Ingredient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $IngredientDetailCopyWith<$Res> get detail {
    return $IngredientDetailCopyWith<$Res>(_value.detail, (value) {
      return _then(_value.copyWith(detail: value) as $Val);
    });
  }

  /// Create a copy of Ingredient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $IngredientUnitCopyWith<$Res>? get unit {
    if (_value.unit == null) {
      return null;
    }

    return $IngredientUnitCopyWith<$Res>(_value.unit!, (value) {
      return _then(_value.copyWith(unit: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$IngredientImplCopyWith<$Res>
    implements $IngredientCopyWith<$Res> {
  factory _$$IngredientImplCopyWith(
    _$IngredientImpl value,
    $Res Function(_$IngredientImpl) then,
  ) = __$$IngredientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double quantity,
    @JsonKey(name: 'ingredient') IngredientDetail detail,
    IngredientUnit? unit,
    String? preparation,
  });

  @override
  $IngredientDetailCopyWith<$Res> get detail;
  @override
  $IngredientUnitCopyWith<$Res>? get unit;
}

/// @nodoc
class __$$IngredientImplCopyWithImpl<$Res>
    extends _$IngredientCopyWithImpl<$Res, _$IngredientImpl>
    implements _$$IngredientImplCopyWith<$Res> {
  __$$IngredientImplCopyWithImpl(
    _$IngredientImpl _value,
    $Res Function(_$IngredientImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Ingredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? quantity = null,
    Object? detail = null,
    Object? unit = freezed,
    Object? preparation = freezed,
  }) {
    return _then(
      _$IngredientImpl(
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as double,
        detail: null == detail
            ? _value.detail
            : detail // ignore: cast_nullable_to_non_nullable
                  as IngredientDetail,
        unit: freezed == unit
            ? _value.unit
            : unit // ignore: cast_nullable_to_non_nullable
                  as IngredientUnit?,
        preparation: freezed == preparation
            ? _value.preparation
            : preparation // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$IngredientImpl implements _Ingredient {
  const _$IngredientImpl({
    required this.quantity,
    @JsonKey(name: 'ingredient') required this.detail,
    this.unit,
    this.preparation,
  });

  factory _$IngredientImpl.fromJson(Map<String, dynamic> json) =>
      _$$IngredientImplFromJson(json);

  @override
  final double quantity;
  @override
  @JsonKey(name: 'ingredient')
  final IngredientDetail detail;
  @override
  final IngredientUnit? unit;
  @override
  final String? preparation;

  @override
  String toString() {
    return 'Ingredient(quantity: $quantity, detail: $detail, unit: $unit, preparation: $preparation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IngredientImpl &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.preparation, preparation) ||
                other.preparation == preparation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, quantity, detail, unit, preparation);

  /// Create a copy of Ingredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IngredientImplCopyWith<_$IngredientImpl> get copyWith =>
      __$$IngredientImplCopyWithImpl<_$IngredientImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$IngredientImplToJson(this);
  }
}

abstract class _Ingredient implements Ingredient {
  const factory _Ingredient({
    required final double quantity,
    @JsonKey(name: 'ingredient') required final IngredientDetail detail,
    final IngredientUnit? unit,
    final String? preparation,
  }) = _$IngredientImpl;

  factory _Ingredient.fromJson(Map<String, dynamic> json) =
      _$IngredientImpl.fromJson;

  @override
  double get quantity;
  @override
  @JsonKey(name: 'ingredient')
  IngredientDetail get detail;
  @override
  IngredientUnit? get unit;
  @override
  String? get preparation;

  /// Create a copy of Ingredient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IngredientImplCopyWith<_$IngredientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

IngredientDetail _$IngredientDetailFromJson(Map<String, dynamic> json) {
  return _IngredientDetail.fromJson(json);
}

/// @nodoc
mixin _$IngredientDetail {
  String get name => throw _privateConstructorUsedError;

  /// Serializes this IngredientDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of IngredientDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IngredientDetailCopyWith<IngredientDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IngredientDetailCopyWith<$Res> {
  factory $IngredientDetailCopyWith(
    IngredientDetail value,
    $Res Function(IngredientDetail) then,
  ) = _$IngredientDetailCopyWithImpl<$Res, IngredientDetail>;
  @useResult
  $Res call({String name});
}

/// @nodoc
class _$IngredientDetailCopyWithImpl<$Res, $Val extends IngredientDetail>
    implements $IngredientDetailCopyWith<$Res> {
  _$IngredientDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IngredientDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$IngredientDetailImplCopyWith<$Res>
    implements $IngredientDetailCopyWith<$Res> {
  factory _$$IngredientDetailImplCopyWith(
    _$IngredientDetailImpl value,
    $Res Function(_$IngredientDetailImpl) then,
  ) = __$$IngredientDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name});
}

/// @nodoc
class __$$IngredientDetailImplCopyWithImpl<$Res>
    extends _$IngredientDetailCopyWithImpl<$Res, _$IngredientDetailImpl>
    implements _$$IngredientDetailImplCopyWith<$Res> {
  __$$IngredientDetailImplCopyWithImpl(
    _$IngredientDetailImpl _value,
    $Res Function(_$IngredientDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of IngredientDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null}) {
    return _then(
      _$IngredientDetailImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$IngredientDetailImpl implements _IngredientDetail {
  const _$IngredientDetailImpl({required this.name});

  factory _$IngredientDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$IngredientDetailImplFromJson(json);

  @override
  final String name;

  @override
  String toString() {
    return 'IngredientDetail(name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IngredientDetailImpl &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name);

  /// Create a copy of IngredientDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IngredientDetailImplCopyWith<_$IngredientDetailImpl> get copyWith =>
      __$$IngredientDetailImplCopyWithImpl<_$IngredientDetailImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$IngredientDetailImplToJson(this);
  }
}

abstract class _IngredientDetail implements IngredientDetail {
  const factory _IngredientDetail({required final String name}) =
      _$IngredientDetailImpl;

  factory _IngredientDetail.fromJson(Map<String, dynamic> json) =
      _$IngredientDetailImpl.fromJson;

  @override
  String get name;

  /// Create a copy of IngredientDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IngredientDetailImplCopyWith<_$IngredientDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

IngredientUnit _$IngredientUnitFromJson(Map<String, dynamic> json) {
  return _IngredientUnit.fromJson(json);
}

/// @nodoc
mixin _$IngredientUnit {
  String get name => throw _privateConstructorUsedError;
  String? get abbreviation => throw _privateConstructorUsedError;

  /// Serializes this IngredientUnit to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of IngredientUnit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IngredientUnitCopyWith<IngredientUnit> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IngredientUnitCopyWith<$Res> {
  factory $IngredientUnitCopyWith(
    IngredientUnit value,
    $Res Function(IngredientUnit) then,
  ) = _$IngredientUnitCopyWithImpl<$Res, IngredientUnit>;
  @useResult
  $Res call({String name, String? abbreviation});
}

/// @nodoc
class _$IngredientUnitCopyWithImpl<$Res, $Val extends IngredientUnit>
    implements $IngredientUnitCopyWith<$Res> {
  _$IngredientUnitCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IngredientUnit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? abbreviation = freezed}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            abbreviation: freezed == abbreviation
                ? _value.abbreviation
                : abbreviation // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$IngredientUnitImplCopyWith<$Res>
    implements $IngredientUnitCopyWith<$Res> {
  factory _$$IngredientUnitImplCopyWith(
    _$IngredientUnitImpl value,
    $Res Function(_$IngredientUnitImpl) then,
  ) = __$$IngredientUnitImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String? abbreviation});
}

/// @nodoc
class __$$IngredientUnitImplCopyWithImpl<$Res>
    extends _$IngredientUnitCopyWithImpl<$Res, _$IngredientUnitImpl>
    implements _$$IngredientUnitImplCopyWith<$Res> {
  __$$IngredientUnitImplCopyWithImpl(
    _$IngredientUnitImpl _value,
    $Res Function(_$IngredientUnitImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of IngredientUnit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? abbreviation = freezed}) {
    return _then(
      _$IngredientUnitImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        abbreviation: freezed == abbreviation
            ? _value.abbreviation
            : abbreviation // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$IngredientUnitImpl implements _IngredientUnit {
  const _$IngredientUnitImpl({required this.name, this.abbreviation});

  factory _$IngredientUnitImpl.fromJson(Map<String, dynamic> json) =>
      _$$IngredientUnitImplFromJson(json);

  @override
  final String name;
  @override
  final String? abbreviation;

  @override
  String toString() {
    return 'IngredientUnit(name: $name, abbreviation: $abbreviation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IngredientUnitImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.abbreviation, abbreviation) ||
                other.abbreviation == abbreviation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, abbreviation);

  /// Create a copy of IngredientUnit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IngredientUnitImplCopyWith<_$IngredientUnitImpl> get copyWith =>
      __$$IngredientUnitImplCopyWithImpl<_$IngredientUnitImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$IngredientUnitImplToJson(this);
  }
}

abstract class _IngredientUnit implements IngredientUnit {
  const factory _IngredientUnit({
    required final String name,
    final String? abbreviation,
  }) = _$IngredientUnitImpl;

  factory _IngredientUnit.fromJson(Map<String, dynamic> json) =
      _$IngredientUnitImpl.fromJson;

  @override
  String get name;
  @override
  String? get abbreviation;

  /// Create a copy of IngredientUnit
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IngredientUnitImplCopyWith<_$IngredientUnitImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
