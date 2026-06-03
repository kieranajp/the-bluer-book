// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Label _$LabelFromJson(Map<String, dynamic> json) =>
    _Label(type: json['type'] as String, name: json['name'] as String);

Map<String, dynamic> _$LabelToJson(_Label instance) => <String, dynamic>{
  'type': instance.type,
  'name': instance.name,
};

_LabelSummary _$LabelSummaryFromJson(Map<String, dynamic> json) =>
    _LabelSummary(
      type: json['type'] as String,
      name: json['name'] as String,
      uses: (json['uses'] as num).toInt(),
    );

Map<String, dynamic> _$LabelSummaryToJson(_LabelSummary instance) =>
    <String, dynamic>{
      'type': instance.type,
      'name': instance.name,
      'uses': instance.uses,
    };
