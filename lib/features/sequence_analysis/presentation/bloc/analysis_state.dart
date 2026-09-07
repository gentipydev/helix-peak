import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/analysis_result.dart';

part 'analysis_state.freezed.dart';

@freezed
sealed class AnalysisState with _$AnalysisState {
  const factory AnalysisState.initial() = AnalysisInitial;

  const factory AnalysisState.loading() = AnalysisLoading;

  const factory AnalysisState.success(AnalysisResult result) = AnalysisSuccess;

  const factory AnalysisState.failure(String message) = AnalysisFailure;
}
