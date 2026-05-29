// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LabelImpl _$$LabelImplFromJson(Map<String, dynamic> json) => _$LabelImpl(
      type: json['type'] as String,
      name: json['name'] as String,
    );

Map<String, dynamic> _$$LabelImplToJson(_$LabelImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'name': instance.name,
    };

_$LabelSummaryImpl _$$LabelSummaryImplFromJson(Map<String, dynamic> json) =>
    _$LabelSummaryImpl(
      type: json['type'] as String,
      name: json['name'] as String,
      uses: (json['uses'] as num).toInt(),
    );

Map<String, dynamic> _$$LabelSummaryImplToJson(_$LabelSummaryImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'name': instance.name,
      'uses': instance.uses,
    };
