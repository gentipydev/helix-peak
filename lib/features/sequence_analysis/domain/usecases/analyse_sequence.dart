import '../entities/analysis_result.dart';
import '../entities/sequence_input.dart';
import '../repositories/sequence_repository.dart';

final class AnalyseSequence {
  const AnalyseSequence(this._repository);

  final SequenceRepository _repository;

  Future<AnalysisResult> call(SequenceInput input) =>
      _repository.analyse(input);
}
