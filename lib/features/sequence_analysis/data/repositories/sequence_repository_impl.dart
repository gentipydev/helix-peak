import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/sequence_input.dart';
import '../../domain/repositories/sequence_repository.dart';
import '../datasources/sequence_remote_data_source.dart';
import '../models/analysis_result_dto.dart';

final class SequenceRepositoryImpl implements SequenceRepository {
  const SequenceRepositoryImpl(this._remoteDataSource);

  final SequenceRemoteDataSource _remoteDataSource;

  @override
  Future<AnalysisResult> analyse(SequenceInput input) async {
    final AnalysisResultDto dto =
        await _remoteDataSource.analyse(input.rawText);
    return dto.toEntity();
  }
}
