import '../../domain/entities/gene_record.dart';
import '../../domain/repositories/gene_repository.dart';
import '../datasources/gene_remote_data_source.dart';
import '../models/gene_record_dto.dart';

final class GeneRepositoryImpl implements GeneRepository {
  const GeneRepositoryImpl(this._remoteDataSource);

  final GeneRemoteDataSource _remoteDataSource;

  @override
  Future<GeneRecord> fetchGene({
    required String accession,
    required String gene,
  }) async {
    final GeneRecordDto dto = await _remoteDataSource.fetchGene(
      accession: accession,
      gene: gene,
    );
    return dto.toEntity();
  }
}
