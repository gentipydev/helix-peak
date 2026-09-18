import '../../../../core/network/api_client.dart';
import '../models/gene_record_dto.dart';

abstract interface class GeneRemoteDataSource {
  Future<GeneRecordDto> fetchGene({
    required String accession,
    required String gene,
  });
}

final class GeneRemoteDataSourceImpl implements GeneRemoteDataSource {
  const GeneRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<GeneRecordDto> fetchGene({
    required String accession,
    required String gene,
  }) async {
    final Map<String, dynamic> json = await _client.getJson(
      '/gene/$accession/$gene',
    );
    return GeneRecordDto.fromJson(json);
  }
}
