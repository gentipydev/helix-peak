import '../../../../core/biology/gene_record.dart';
import '../entities/gene_query.dart';
import '../repositories/gene_repository.dart';

final class FetchGene {
  const FetchGene(this._repository);

  final GeneRepository _repository;

  Future<GeneRecord> call(GeneQuery query) => _repository.fetchGene(query);
}
