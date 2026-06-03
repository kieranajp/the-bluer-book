// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'label.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Label {

 String get type; String get name;
/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabelCopyWith<Label> get copyWith => _$LabelCopyWithImpl<Label>(this as Label, _$identity);

  /// Serializes this Label to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Label&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,name);

@override
String toString() {
  return 'Label(type: $type, name: $name)';
}


}

/// @nodoc
abstract mixin class $LabelCopyWith<$Res>  {
  factory $LabelCopyWith(Label value, $Res Function(Label) _then) = _$LabelCopyWithImpl;
@useResult
$Res call({
 String type, String name
});




}
/// @nodoc
class _$LabelCopyWithImpl<$Res>
    implements $LabelCopyWith<$Res> {
  _$LabelCopyWithImpl(this._self, this._then);

  final Label _self;
  final $Res Function(Label) _then;

/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? name = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Label].
extension LabelPatterns on Label {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Label value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Label() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Label value)  $default,){
final _that = this;
switch (_that) {
case _Label():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Label value)?  $default,){
final _that = this;
switch (_that) {
case _Label() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Label() when $default != null:
return $default(_that.type,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String name)  $default,) {final _that = this;
switch (_that) {
case _Label():
return $default(_that.type,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String name)?  $default,) {final _that = this;
switch (_that) {
case _Label() when $default != null:
return $default(_that.type,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Label implements Label {
  const _Label({required this.type, required this.name});
  factory _Label.fromJson(Map<String, dynamic> json) => _$LabelFromJson(json);

@override final  String type;
@override final  String name;

/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LabelCopyWith<_Label> get copyWith => __$LabelCopyWithImpl<_Label>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LabelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Label&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,name);

@override
String toString() {
  return 'Label(type: $type, name: $name)';
}


}

/// @nodoc
abstract mixin class _$LabelCopyWith<$Res> implements $LabelCopyWith<$Res> {
  factory _$LabelCopyWith(_Label value, $Res Function(_Label) _then) = __$LabelCopyWithImpl;
@override @useResult
$Res call({
 String type, String name
});




}
/// @nodoc
class __$LabelCopyWithImpl<$Res>
    implements _$LabelCopyWith<$Res> {
  __$LabelCopyWithImpl(this._self, this._then);

  final _Label _self;
  final $Res Function(_Label) _then;

/// Create a copy of Label
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? name = null,}) {
  return _then(_Label(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$LabelSummary {

 String get type; String get name; int get uses;
/// Create a copy of LabelSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabelSummaryCopyWith<LabelSummary> get copyWith => _$LabelSummaryCopyWithImpl<LabelSummary>(this as LabelSummary, _$identity);

  /// Serializes this LabelSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabelSummary&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.uses, uses) || other.uses == uses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,name,uses);

@override
String toString() {
  return 'LabelSummary(type: $type, name: $name, uses: $uses)';
}


}

/// @nodoc
abstract mixin class $LabelSummaryCopyWith<$Res>  {
  factory $LabelSummaryCopyWith(LabelSummary value, $Res Function(LabelSummary) _then) = _$LabelSummaryCopyWithImpl;
@useResult
$Res call({
 String type, String name, int uses
});




}
/// @nodoc
class _$LabelSummaryCopyWithImpl<$Res>
    implements $LabelSummaryCopyWith<$Res> {
  _$LabelSummaryCopyWithImpl(this._self, this._then);

  final LabelSummary _self;
  final $Res Function(LabelSummary) _then;

/// Create a copy of LabelSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? name = null,Object? uses = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,uses: null == uses ? _self.uses : uses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LabelSummary].
extension LabelSummaryPatterns on LabelSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LabelSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LabelSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LabelSummary value)  $default,){
final _that = this;
switch (_that) {
case _LabelSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LabelSummary value)?  $default,){
final _that = this;
switch (_that) {
case _LabelSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String name,  int uses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LabelSummary() when $default != null:
return $default(_that.type,_that.name,_that.uses);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String name,  int uses)  $default,) {final _that = this;
switch (_that) {
case _LabelSummary():
return $default(_that.type,_that.name,_that.uses);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String name,  int uses)?  $default,) {final _that = this;
switch (_that) {
case _LabelSummary() when $default != null:
return $default(_that.type,_that.name,_that.uses);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LabelSummary extends LabelSummary {
  const _LabelSummary({required this.type, required this.name, required this.uses}): super._();
  factory _LabelSummary.fromJson(Map<String, dynamic> json) => _$LabelSummaryFromJson(json);

@override final  String type;
@override final  String name;
@override final  int uses;

/// Create a copy of LabelSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LabelSummaryCopyWith<_LabelSummary> get copyWith => __$LabelSummaryCopyWithImpl<_LabelSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LabelSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LabelSummary&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.uses, uses) || other.uses == uses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,name,uses);

@override
String toString() {
  return 'LabelSummary(type: $type, name: $name, uses: $uses)';
}


}

/// @nodoc
abstract mixin class _$LabelSummaryCopyWith<$Res> implements $LabelSummaryCopyWith<$Res> {
  factory _$LabelSummaryCopyWith(_LabelSummary value, $Res Function(_LabelSummary) _then) = __$LabelSummaryCopyWithImpl;
@override @useResult
$Res call({
 String type, String name, int uses
});




}
/// @nodoc
class __$LabelSummaryCopyWithImpl<$Res>
    implements _$LabelSummaryCopyWith<$Res> {
  __$LabelSummaryCopyWithImpl(this._self, this._then);

  final _LabelSummary _self;
  final $Res Function(_LabelSummary) _then;

/// Create a copy of LabelSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? name = null,Object? uses = null,}) {
  return _then(_LabelSummary(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,uses: null == uses ? _self.uses : uses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
