import '../entities/gene_query.dart';
import '../entities/gene_record.dart';

abstract interface class GeneRepository {
  Future<GeneRecord> fetchGene(GeneQuery query);
}
