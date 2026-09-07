import 'package:freezed_annotation/freezed_annotation.dart';

part 'analysis_event.freezed.dart';

@freezed
sealed class AnalysisEvent with _$AnalysisEvent {
  const factory AnalysisEvent.requested(String rawText) = AnalysisRequested;

  const factory AnalysisEvent.retried() = AnalysisRetried;

  const factory AnalysisEvent.cleared() = AnalysisCleared;
}
