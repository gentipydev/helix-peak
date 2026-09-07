import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/analysis_result.dart';

part 'analysis_result_dto.freezed.dart';
part 'analysis_result_dto.g.dart';

@freezed
abstract class AnalysisResultDto with _$AnalysisResultDto {
  const factory AnalysisResultDto({
    required String id,
    required String summary,
    @JsonKey(name: 'generated_at') required DateTime generatedAt,
  }) = _AnalysisResultDto;

  factory AnalysisResultDto.fromJson(Map<String, dynamic> json) =>
      _$AnalysisResultDtoFromJson(json);
}

extension AnalysisResultDtoMapper on AnalysisResultDto {
  AnalysisResult toEntity() =>
      AnalysisResult(id: id, summary: summary, generatedAt: generatedAt);
}
