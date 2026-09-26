import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/gene_query.dart';

abstract interface class GeneRepository {
  Future<GeneRecord> fetchGene(GeneQuery query);
}
