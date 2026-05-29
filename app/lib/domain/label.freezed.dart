// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'label.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Label _$LabelFromJson(Map<String, dynamic> json) {
  return _Label.fromJson(json);
}

/// @nodoc
mixin _$Label {
  String get type => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;

  /// Serializes this Label to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Label
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LabelCopyWith<Label> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LabelCopyWith<$Res> {
  factory $LabelCopyWith(Label value, $Res Function(Label) then) =
      _$LabelCopyWithImpl<$Res, Label>;
  @useResult
  $Res call({String type, String name});
}

/// @nodoc
class _$LabelCopyWithImpl<$Res, $Val extends Label>
    implements $LabelCopyWith<$Res> {
  _$LabelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Label
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? name = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
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
abstract class _$$LabelImplCopyWith<$Res> implements $LabelCopyWith<$Res> {
  factory _$$LabelImplCopyWith(
    _$LabelImpl value,
    $Res Function(_$LabelImpl) then,
  ) = __$$LabelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, String name});
}

/// @nodoc
class __$$LabelImplCopyWithImpl<$Res>
    extends _$LabelCopyWithImpl<$Res, _$LabelImpl>
    implements _$$LabelImplCopyWith<$Res> {
  __$$LabelImplCopyWithImpl(
    _$LabelImpl _value,
    $Res Function(_$LabelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Label
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? name = null}) {
    return _then(
      _$LabelImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
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
class _$LabelImpl implements _Label {
  const _$LabelImpl({required this.type, required this.name});

  factory _$LabelImpl.fromJson(Map<String, dynamic> json) =>
      _$$LabelImplFromJson(json);

  @override
  final String type;
  @override
  final String name;

  @override
  String toString() {
    return 'Label(type: $type, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LabelImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, name);

  /// Create a copy of Label
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LabelImplCopyWith<_$LabelImpl> get copyWith =>
      __$$LabelImplCopyWithImpl<_$LabelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LabelImplToJson(this);
  }
}

abstract class _Label implements Label {
  const factory _Label({
    required final String type,
    required final String name,
  }) = _$LabelImpl;

  factory _Label.fromJson(Map<String, dynamic> json) = _$LabelImpl.fromJson;

  @override
  String get type;
  @override
  String get name;

  /// Create a copy of Label
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LabelImplCopyWith<_$LabelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LabelSummary _$LabelSummaryFromJson(Map<String, dynamic> json) {
  return _LabelSummary.fromJson(json);
}

/// @nodoc
mixin _$LabelSummary {
  String get type => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get uses => throw _privateConstructorUsedError;

  /// Serializes this LabelSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LabelSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LabelSummaryCopyWith<LabelSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LabelSummaryCopyWith<$Res> {
  factory $LabelSummaryCopyWith(
    LabelSummary value,
    $Res Function(LabelSummary) then,
  ) = _$LabelSummaryCopyWithImpl<$Res, LabelSummary>;
  @useResult
  $Res call({String type, String name, int uses});
}

/// @nodoc
class _$LabelSummaryCopyWithImpl<$Res, $Val extends LabelSummary>
    implements $LabelSummaryCopyWith<$Res> {
  _$LabelSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LabelSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? name = null, Object? uses = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            uses: null == uses
                ? _value.uses
                : uses // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LabelSummaryImplCopyWith<$Res>
    implements $LabelSummaryCopyWith<$Res> {
  factory _$$LabelSummaryImplCopyWith(
    _$LabelSummaryImpl value,
    $Res Function(_$LabelSummaryImpl) then,
  ) = __$$LabelSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, String name, int uses});
}

/// @nodoc
class __$$LabelSummaryImplCopyWithImpl<$Res>
    extends _$LabelSummaryCopyWithImpl<$Res, _$LabelSummaryImpl>
    implements _$$LabelSummaryImplCopyWith<$Res> {
  __$$LabelSummaryImplCopyWithImpl(
    _$LabelSummaryImpl _value,
    $Res Function(_$LabelSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LabelSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? name = null, Object? uses = null}) {
    return _then(
      _$LabelSummaryImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        uses: null == uses
            ? _value.uses
            : uses // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LabelSummaryImpl extends _LabelSummary {
  const _$LabelSummaryImpl({
    required this.type,
    required this.name,
    required this.uses,
  }) : super._();

  factory _$LabelSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$LabelSummaryImplFromJson(json);

  @override
  final String type;
  @override
  final String name;
  @override
  final int uses;

  @override
  String toString() {
    return 'LabelSummary(type: $type, name: $name, uses: $uses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LabelSummaryImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.uses, uses) || other.uses == uses));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, name, uses);

  /// Create a copy of LabelSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LabelSummaryImplCopyWith<_$LabelSummaryImpl> get copyWith =>
      __$$LabelSummaryImplCopyWithImpl<_$LabelSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LabelSummaryImplToJson(this);
  }
}

abstract class _LabelSummary extends LabelSummary {
  const factory _LabelSummary({
    required final String type,
    required final String name,
    required final int uses,
  }) = _$LabelSummaryImpl;
  const _LabelSummary._() : super._();

  factory _LabelSummary.fromJson(Map<String, dynamic> json) =
      _$LabelSummaryImpl.fromJson;

  @override
  String get type;
  @override
  String get name;
  @override
  int get uses;

  /// Create a copy of LabelSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LabelSummaryImplCopyWith<_$LabelSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
