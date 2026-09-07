import 'package:freezed_annotation/freezed_annotation.dart';

part 'analysis_result.freezed.dart';

@freezed
abstract class AnalysisResult with _$AnalysisResult {
  const factory AnalysisResult({
    required String id,
    required String summary,
    required DateTime generatedAt,
  }) = _AnalysisResult;
}
