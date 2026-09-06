import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/nucleotide_counts.dart';
import '../../domain/entities/sequence_input.dart';
import '../../domain/entities/sequence_type.dart';

part 'analysis_result_dto.freezed.dart';
part 'analysis_result_dto.g.dart';

/// Wire representation of an analysis response.
///
/// Kept separate from [AnalysisResult] deliberately. The DTO's job is to match
/// whatever the backend emits — snake_case keys, strings for enums, ISO 8601
/// timestamps — so that a change to the wire format is absorbed here by the
/// mapper instead of rippling through the domain and the UI.
///
/// Nothing constructs these yet; the stub repository builds domain objects
/// directly. This exists as the documented contract the FastAPI service will
/// be held to.
@freezed
abstract class AnalysisResultDto with _$AnalysisResultDto {
  const factory AnalysisResultDto({
    required String id,
    @JsonKey(name: 'sequence') required String bases,
    @JsonKey(name: 'sequence_type') required String sequenceType,
    required NucleotideCountsDto counts,
    @JsonKey(name: 'melting_temperature_c')
    required double meltingTemperatureCelsius,
    @JsonKey(name: 'molecular_weight_da')
    required double molecularWeightDaltons,
    @JsonKey(name: 'generated_at') required DateTime generatedAt,
    @JsonKey(name: 'fasta_header') String? fastaHeader,
    @Default(<PropertyPredictionDto>[])
    List<PropertyPredictionDto> predictions,
    @Default(<String>[]) List<String> warnings,
  }) = _AnalysisResultDto;

  factory AnalysisResultDto.fromJson(Map<String, dynamic> json) =>
      _$AnalysisResultDtoFromJson(json);
}

@freezed
abstract class NucleotideCountsDto with _$NucleotideCountsDto {
  const factory NucleotideCountsDto({
    @JsonKey(name: 'a') @Default(0) int adenine,
    @JsonKey(name: 't') @Default(0) int thymine,
    @JsonKey(name: 'g') @Default(0) int guanine,
    @JsonKey(name: 'c') @Default(0) int cytosine,
    @Default(0) int other,
  }) = _NucleotideCountsDto;

  factory NucleotideCountsDto.fromJson(Map<String, dynamic> json) =>
      _$NucleotideCountsDtoFromJson(json);
}

@freezed
abstract class PropertyPredictionDto with _$PropertyPredictionDto {
  const factory PropertyPredictionDto({
    required String label,
    required String value,
    required double confidence,
  }) = _PropertyPredictionDto;

  factory PropertyPredictionDto.fromJson(Map<String, dynamic> json) =>
      _$PropertyPredictionDtoFromJson(json);
}

/// Wire → domain mapping.
///
/// Hand-written rather than generated because this is where wire quirks get
/// normalised — an unrecognised `sequence_type` degrades to
/// [SequenceType.unknown] instead of throwing, since a new backend enum value
/// should not crash the app.
extension AnalysisResultDtoMapper on AnalysisResultDto {
  AnalysisResult toEntity() {
    return AnalysisResult(
      id: id,
      input: SequenceInput(
        bases: bases,
        sequenceType: _parseSequenceType(sequenceType),
        fastaHeader: fastaHeader,
      ),
      counts: NucleotideCounts(
        adenine: counts.adenine,
        thymine: counts.thymine,
        guanine: counts.guanine,
        cytosine: counts.cytosine,
        other: counts.other,
      ),
      meltingTemperatureCelsius: meltingTemperatureCelsius,
      molecularWeightDaltons: molecularWeightDaltons,
      generatedAt: generatedAt,
      predictions: predictions
          .map(
            (PropertyPredictionDto dto) => PropertyPrediction(
              label: dto.label,
              value: dto.value,
              confidence: dto.confidence,
            ),
          )
          .toList(growable: false),
      warnings: warnings,
    );
  }

  static SequenceType _parseSequenceType(String raw) {
    return SequenceType.values.firstWhere(
      (SequenceType type) => type.name == raw.toLowerCase(),
      orElse: () => SequenceType.unknown,
    );
  }
}
