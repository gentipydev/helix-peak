// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_result_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnalysisResultDto _$AnalysisResultDtoFromJson(
  Map<String, dynamic> json,
) => _AnalysisResultDto(
  id: json['id'] as String,
  bases: json['sequence'] as String,
  sequenceType: json['sequence_type'] as String,
  counts: NucleotideCountsDto.fromJson(json['counts'] as Map<String, dynamic>),
  meltingTemperatureCelsius: (json['melting_temperature_c'] as num).toDouble(),
  molecularWeightDaltons: (json['molecular_weight_da'] as num).toDouble(),
  generatedAt: DateTime.parse(json['generated_at'] as String),
  fastaHeader: json['fasta_header'] as String?,
  predictions:
      (json['predictions'] as List<dynamic>?)
          ?.map(
            (e) => PropertyPredictionDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <PropertyPredictionDto>[],
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$AnalysisResultDtoToJson(_AnalysisResultDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sequence': instance.bases,
      'sequence_type': instance.sequenceType,
      'counts': instance.counts,
      'melting_temperature_c': instance.meltingTemperatureCelsius,
      'molecular_weight_da': instance.molecularWeightDaltons,
      'generated_at': instance.generatedAt.toIso8601String(),
      'fasta_header': instance.fastaHeader,
      'predictions': instance.predictions,
      'warnings': instance.warnings,
    };

_NucleotideCountsDto _$NucleotideCountsDtoFromJson(Map<String, dynamic> json) =>
    _NucleotideCountsDto(
      adenine: (json['a'] as num?)?.toInt() ?? 0,
      thymine: (json['t'] as num?)?.toInt() ?? 0,
      guanine: (json['g'] as num?)?.toInt() ?? 0,
      cytosine: (json['c'] as num?)?.toInt() ?? 0,
      other: (json['other'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$NucleotideCountsDtoToJson(
  _NucleotideCountsDto instance,
) => <String, dynamic>{
  'a': instance.adenine,
  't': instance.thymine,
  'g': instance.guanine,
  'c': instance.cytosine,
  'other': instance.other,
};

_PropertyPredictionDto _$PropertyPredictionDtoFromJson(
  Map<String, dynamic> json,
) => _PropertyPredictionDto(
  label: json['label'] as String,
  value: json['value'] as String,
  confidence: (json['confidence'] as num).toDouble(),
);

Map<String, dynamic> _$PropertyPredictionDtoToJson(
  _PropertyPredictionDto instance,
) => <String, dynamic>{
  'label': instance.label,
  'value': instance.value,
  'confidence': instance.confidence,
};
