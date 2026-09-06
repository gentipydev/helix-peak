import 'package:freezed_annotation/freezed_annotation.dart';

import 'nucleotide_counts.dart';
import 'sequence_input.dart';

part 'analysis_result.freezed.dart';

/// One predicted property of the sequence.
///
/// Stands in for the AI predictions the FastAPI backend will eventually
/// return. [confidence] is a 0–1 fraction; the UI shows it because a
/// prediction without a confidence is not a useful prediction.
@freezed
abstract class PropertyPrediction with _$PropertyPrediction {
  const factory PropertyPrediction({
    required String label,
    required String value,
    required double confidence,
  }) = _PropertyPrediction;
}

/// The complete outcome of analysing a sequence.
@freezed
abstract class AnalysisResult with _$AnalysisResult {
  const factory AnalysisResult({
    required String id,
    required SequenceInput input,
    required NucleotideCounts counts,
    required double meltingTemperatureCelsius,
    required double molecularWeightDaltons,
    required DateTime generatedAt,
    @Default(<PropertyPrediction>[]) List<PropertyPrediction> predictions,

    /// Non-fatal observations worth surfacing, e.g. ambiguous bases present.
    @Default(<String>[]) List<String> warnings,
  }) = _AnalysisResult;

  const AnalysisResult._();

  /// Delegated rather than stored, so it cannot drift from [counts].
  double get gcContentPercent => counts.gcContentPercent;

  int get lengthBases => input.length;
}
