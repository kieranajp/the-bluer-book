// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ingredient.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Ingredient {

 double get quantity;@JsonKey(name: 'ingredient') IngredientDetail get detail; IngredientUnit? get unit; String? get preparation; String? get component;
/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IngredientCopyWith<Ingredient> get copyWith => _$IngredientCopyWithImpl<Ingredient>(this as Ingredient, _$identity);

  /// Serializes this Ingredient to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Ingredient&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.preparation, preparation) || other.preparation == preparation)&&(identical(other.component, component) || other.component == component));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,quantity,detail,unit,preparation,component);

@override
String toString() {
  return 'Ingredient(quantity: $quantity, detail: $detail, unit: $unit, preparation: $preparation, component: $component)';
}


}

/// @nodoc
abstract mixin class $IngredientCopyWith<$Res>  {
  factory $IngredientCopyWith(Ingredient value, $Res Function(Ingredient) _then) = _$IngredientCopyWithImpl;
@useResult
$Res call({
 double quantity,@JsonKey(name: 'ingredient') IngredientDetail detail, IngredientUnit? unit, String? preparation, String? component
});


$IngredientDetailCopyWith<$Res> get detail;$IngredientUnitCopyWith<$Res>? get unit;

}
/// @nodoc
class _$IngredientCopyWithImpl<$Res>
    implements $IngredientCopyWith<$Res> {
  _$IngredientCopyWithImpl(this._self, this._then);

  final Ingredient _self;
  final $Res Function(Ingredient) _then;

/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? quantity = null,Object? detail = null,Object? unit = freezed,Object? preparation = freezed,Object? component = freezed,}) {
  return _then(_self.copyWith(
quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as IngredientDetail,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as IngredientUnit?,preparation: freezed == preparation ? _self.preparation : preparation // ignore: cast_nullable_to_non_nullable
as String?,component: freezed == component ? _self.component : component // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IngredientDetailCopyWith<$Res> get detail {
  
  return $IngredientDetailCopyWith<$Res>(_self.detail, (value) {
    return _then(_self.copyWith(detail: value));
  });
}/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IngredientUnitCopyWith<$Res>? get unit {
    if (_self.unit == null) {
    return null;
  }

  return $IngredientUnitCopyWith<$Res>(_self.unit!, (value) {
    return _then(_self.copyWith(unit: value));
  });
}
}


/// Adds pattern-matching-related methods to [Ingredient].
extension IngredientPatterns on Ingredient {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Ingredient value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Ingredient() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Ingredient value)  $default,){
final _that = this;
switch (_that) {
case _Ingredient():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Ingredient value)?  $default,){
final _that = this;
switch (_that) {
case _Ingredient() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double quantity, @JsonKey(name: 'ingredient')  IngredientDetail detail,  IngredientUnit? unit,  String? preparation,  String? component)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Ingredient() when $default != null:
return $default(_that.quantity,_that.detail,_that.unit,_that.preparation,_that.component);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double quantity, @JsonKey(name: 'ingredient')  IngredientDetail detail,  IngredientUnit? unit,  String? preparation,  String? component)  $default,) {final _that = this;
switch (_that) {
case _Ingredient():
return $default(_that.quantity,_that.detail,_that.unit,_that.preparation,_that.component);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double quantity, @JsonKey(name: 'ingredient')  IngredientDetail detail,  IngredientUnit? unit,  String? preparation,  String? component)?  $default,) {final _that = this;
switch (_that) {
case _Ingredient() when $default != null:
return $default(_that.quantity,_that.detail,_that.unit,_that.preparation,_that.component);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Ingredient implements Ingredient {
  const _Ingredient({required this.quantity, @JsonKey(name: 'ingredient') required this.detail, this.unit, this.preparation, this.component});
  factory _Ingredient.fromJson(Map<String, dynamic> json) => _$IngredientFromJson(json);

@override final  double quantity;
@override@JsonKey(name: 'ingredient') final  IngredientDetail detail;
@override final  IngredientUnit? unit;
@override final  String? preparation;
@override final  String? component;

/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IngredientCopyWith<_Ingredient> get copyWith => __$IngredientCopyWithImpl<_Ingredient>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IngredientToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Ingredient&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.preparation, preparation) || other.preparation == preparation)&&(identical(other.component, component) || other.component == component));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,quantity,detail,unit,preparation,component);

@override
String toString() {
  return 'Ingredient(quantity: $quantity, detail: $detail, unit: $unit, preparation: $preparation, component: $component)';
}


}

/// @nodoc
abstract mixin class _$IngredientCopyWith<$Res> implements $IngredientCopyWith<$Res> {
  factory _$IngredientCopyWith(_Ingredient value, $Res Function(_Ingredient) _then) = __$IngredientCopyWithImpl;
@override @useResult
$Res call({
 double quantity,@JsonKey(name: 'ingredient') IngredientDetail detail, IngredientUnit? unit, String? preparation, String? component
});


@override $IngredientDetailCopyWith<$Res> get detail;@override $IngredientUnitCopyWith<$Res>? get unit;

}
/// @nodoc
class __$IngredientCopyWithImpl<$Res>
    implements _$IngredientCopyWith<$Res> {
  __$IngredientCopyWithImpl(this._self, this._then);

  final _Ingredient _self;
  final $Res Function(_Ingredient) _then;

/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? quantity = null,Object? detail = null,Object? unit = freezed,Object? preparation = freezed,Object? component = freezed,}) {
  return _then(_Ingredient(
quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as IngredientDetail,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as IngredientUnit?,preparation: freezed == preparation ? _self.preparation : preparation // ignore: cast_nullable_to_non_nullable
as String?,component: freezed == component ? _self.component : component // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IngredientDetailCopyWith<$Res> get detail {
  
  return $IngredientDetailCopyWith<$Res>(_self.detail, (value) {
    return _then(_self.copyWith(detail: value));
  });
}/// Create a copy of Ingredient
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IngredientUnitCopyWith<$Res>? get unit {
    if (_self.unit == null) {
    return null;
  }

  return $IngredientUnitCopyWith<$Res>(_self.unit!, (value) {
    return _then(_self.copyWith(unit: value));
  });
}
}


/// @nodoc
mixin _$IngredientDetail {

 String get name;
/// Create a copy of IngredientDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IngredientDetailCopyWith<IngredientDetail> get copyWith => _$IngredientDetailCopyWithImpl<IngredientDetail>(this as IngredientDetail, _$identity);

  /// Serializes this IngredientDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IngredientDetail&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'IngredientDetail(name: $name)';
}


}

/// @nodoc
abstract mixin class $IngredientDetailCopyWith<$Res>  {
  factory $IngredientDetailCopyWith(IngredientDetail value, $Res Function(IngredientDetail) _then) = _$IngredientDetailCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$IngredientDetailCopyWithImpl<$Res>
    implements $IngredientDetailCopyWith<$Res> {
  _$IngredientDetailCopyWithImpl(this._self, this._then);

  final IngredientDetail _self;
  final $Res Function(IngredientDetail) _then;

/// Create a copy of IngredientDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [IngredientDetail].
extension IngredientDetailPatterns on IngredientDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IngredientDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IngredientDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IngredientDetail value)  $default,){
final _that = this;
switch (_that) {
case _IngredientDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IngredientDetail value)?  $default,){
final _that = this;
switch (_that) {
case _IngredientDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IngredientDetail() when $default != null:
return $default(_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name)  $default,) {final _that = this;
switch (_that) {
case _IngredientDetail():
return $default(_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name)?  $default,) {final _that = this;
switch (_that) {
case _IngredientDetail() when $default != null:
return $default(_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IngredientDetail implements IngredientDetail {
  const _IngredientDetail({required this.name});
  factory _IngredientDetail.fromJson(Map<String, dynamic> json) => _$IngredientDetailFromJson(json);

@override final  String name;

/// Create a copy of IngredientDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IngredientDetailCopyWith<_IngredientDetail> get copyWith => __$IngredientDetailCopyWithImpl<_IngredientDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IngredientDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IngredientDetail&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'IngredientDetail(name: $name)';
}


}

/// @nodoc
abstract mixin class _$IngredientDetailCopyWith<$Res> implements $IngredientDetailCopyWith<$Res> {
  factory _$IngredientDetailCopyWith(_IngredientDetail value, $Res Function(_IngredientDetail) _then) = __$IngredientDetailCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class __$IngredientDetailCopyWithImpl<$Res>
    implements _$IngredientDetailCopyWith<$Res> {
  __$IngredientDetailCopyWithImpl(this._self, this._then);

  final _IngredientDetail _self;
  final $Res Function(_IngredientDetail) _then;

/// Create a copy of IngredientDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(_IngredientDetail(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$IngredientUnit {

 String get name; String? get abbreviation;
/// Create a copy of IngredientUnit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IngredientUnitCopyWith<IngredientUnit> get copyWith => _$IngredientUnitCopyWithImpl<IngredientUnit>(this as IngredientUnit, _$identity);

  /// Serializes this IngredientUnit to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IngredientUnit&&(identical(other.name, name) || other.name == name)&&(identical(other.abbreviation, abbreviation) || other.abbreviation == abbreviation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,abbreviation);

@override
String toString() {
  return 'IngredientUnit(name: $name, abbreviation: $abbreviation)';
}


}

/// @nodoc
abstract mixin class $IngredientUnitCopyWith<$Res>  {
  factory $IngredientUnitCopyWith(IngredientUnit value, $Res Function(IngredientUnit) _then) = _$IngredientUnitCopyWithImpl;
@useResult
$Res call({
 String name, String? abbreviation
});




}
/// @nodoc
class _$IngredientUnitCopyWithImpl<$Res>
    implements $IngredientUnitCopyWith<$Res> {
  _$IngredientUnitCopyWithImpl(this._self, this._then);

  final IngredientUnit _self;
  final $Res Function(IngredientUnit) _then;

/// Create a copy of IngredientUnit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? abbreviation = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,abbreviation: freezed == abbreviation ? _self.abbreviation : abbreviation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [IngredientUnit].
extension IngredientUnitPatterns on IngredientUnit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IngredientUnit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IngredientUnit() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IngredientUnit value)  $default,){
final _that = this;
switch (_that) {
case _IngredientUnit():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IngredientUnit value)?  $default,){
final _that = this;
switch (_that) {
case _IngredientUnit() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? abbreviation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IngredientUnit() when $default != null:
return $default(_that.name,_that.abbreviation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? abbreviation)  $default,) {final _that = this;
switch (_that) {
case _IngredientUnit():
return $default(_that.name,_that.abbreviation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? abbreviation)?  $default,) {final _that = this;
switch (_that) {
case _IngredientUnit() when $default != null:
return $default(_that.name,_that.abbreviation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IngredientUnit implements IngredientUnit {
  const _IngredientUnit({required this.name, this.abbreviation});
  factory _IngredientUnit.fromJson(Map<String, dynamic> json) => _$IngredientUnitFromJson(json);

@override final  String name;
@override final  String? abbreviation;

/// Create a copy of IngredientUnit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IngredientUnitCopyWith<_IngredientUnit> get copyWith => __$IngredientUnitCopyWithImpl<_IngredientUnit>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IngredientUnitToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IngredientUnit&&(identical(other.name, name) || other.name == name)&&(identical(other.abbreviation, abbreviation) || other.abbreviation == abbreviation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,abbreviation);

@override
String toString() {
  return 'IngredientUnit(name: $name, abbreviation: $abbreviation)';
}


}

/// @nodoc
abstract mixin class _$IngredientUnitCopyWith<$Res> implements $IngredientUnitCopyWith<$Res> {
  factory _$IngredientUnitCopyWith(_IngredientUnit value, $Res Function(_IngredientUnit) _then) = __$IngredientUnitCopyWithImpl;
@override @useResult
$Res call({
 String name, String? abbreviation
});




}
/// @nodoc
class __$IngredientUnitCopyWithImpl<$Res>
    implements _$IngredientUnitCopyWith<$Res> {
  __$IngredientUnitCopyWithImpl(this._self, this._then);

  final _IngredientUnit _self;
  final $Res Function(_IngredientUnit) _then;

/// Create a copy of IngredientUnit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? abbreviation = freezed,}) {
  return _then(_IngredientUnit(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,abbreviation: freezed == abbreviation ? _self.abbreviation : abbreviation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
