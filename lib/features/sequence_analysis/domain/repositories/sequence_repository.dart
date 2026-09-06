import '../entities/analysis_result.dart';
import '../entities/sequence_input.dart';

/// The analysis capability, stated without reference to how it is fulfilled.
///
/// Everything above this line — the bloc, both screens, the tests — depends
/// only on this interface. That is what makes the eventual move from
/// [StubSequenceRepository] to a FastAPI-backed implementation a one-line
/// change at the composition root rather than a refactor.
abstract interface class SequenceRepository {
  /// Analyses [input], or throws an [ApiException] on failure.
  Future<AnalysisResult> analyse(SequenceInput input);
}
