// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_result_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnalysisResultDto _$AnalysisResultDtoFromJson(Map<String, dynamic> json) =>
    _AnalysisResultDto(
      id: json['id'] as String,
      summary: json['summary'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );

Map<String, dynamic> _$AnalysisResultDtoToJson(_AnalysisResultDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'summary': instance.summary,
      'generated_at': instance.generatedAt.toIso8601String(),
    };
