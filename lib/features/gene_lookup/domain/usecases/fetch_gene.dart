import '../entities/gene_query.dart';
import '../entities/gene_record.dart';
import '../repositories/gene_repository.dart';

final class FetchGene {
  const FetchGene(this._repository);

  final GeneRepository _repository;

  Future<GeneRecord> call(GeneQuery query) =>
      _repository.fetchGene(accession: query.accession, gene: query.gene);
}
