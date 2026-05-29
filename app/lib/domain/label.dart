import 'package:freezed_annotation/freezed_annotation.dart';

part 'label.freezed.dart';
part 'label.g.dart';

@freezed
class Label with _$Label {
  const factory Label({
    required String type,
    required String name,
  }) = _Label;

  factory Label.fromJson(Map<String, dynamic> json) => _$LabelFromJson(json);
}

@freezed
class LabelSummary with _$LabelSummary {
  const factory LabelSummary({
    required String type,
    required String name,
    required int uses,
  }) = _LabelSummary;

  factory LabelSummary.fromJson(Map<String, dynamic> json) =>
      _$LabelSummaryFromJson(json);

  const LabelSummary._();

  String get key => '$type:$name';
}
