import '../entities/analysis_result.dart';
import '../entities/sequence_input.dart';

abstract interface class SequenceRepository {
  Future<AnalysisResult> analyse(SequenceInput input);
}
