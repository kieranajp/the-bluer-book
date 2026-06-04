// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'step.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Step _$StepFromJson(Map<String, dynamic> json) => _Step(
  order: (json['order'] as num).toInt(),
  description: json['description'] as String,
);

Map<String, dynamic> _$StepToJson(_Step instance) => <String, dynamic>{
  'order': instance.order,
  'description': instance.description,
};
