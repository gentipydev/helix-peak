import '../../../../core/network/api_client.dart';
import '../models/analysis_result_dto.dart';

abstract interface class SequenceRemoteDataSource {
  Future<AnalysisResultDto> analyse(String rawText);
}

final class SequenceRemoteDataSourceImpl implements SequenceRemoteDataSource {
  const SequenceRemoteDataSourceImpl(this._client);

  static const String _analysePath = '/analyse';

  final ApiClient _client;

  @override
  Future<AnalysisResultDto> analyse(String rawText) async {
    final Map<String, dynamic> json = await _client.postJson(
      _analysePath,
      body: <String, dynamic>{'sequence': rawText},
    );
    return AnalysisResultDto.fromJson(json);
  }
}
