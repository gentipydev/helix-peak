import 'package:freezed_annotation/freezed_annotation.dart';

part 'analysis_event.freezed.dart';

/// Everything that can drive the analysis feature.
///
/// The union doubles as documentation: the feature's entire input surface is
/// one readable file, and each case is a named, loggable, testable value.
@freezed
sealed class AnalysisEvent with _$AnalysisEvent {
  /// The user submitted raw text for analysis.
  ///
  /// Raw rather than pre-parsed on purpose — validation is business logic, so
  /// it belongs in the bloc where it can be tested without a widget.
  const factory AnalysisEvent.requested(String rawText) = AnalysisRequested;

  /// Re-run the last request. Carries no payload: the bloc remembers what was
  /// submitted, so the user never retypes and the UI never has to hold on to
  /// the input just to be able to retry.
  const factory AnalysisEvent.retried() = AnalysisRetried;

  /// Discard the current result and return to the empty state.
  const factory AnalysisEvent.cleared() = AnalysisCleared;
}
