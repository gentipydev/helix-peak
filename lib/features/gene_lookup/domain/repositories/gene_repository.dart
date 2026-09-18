import '../entities/gene_record.dart';

abstract interface class GeneRepository {
  Future<GeneRecord> fetchGene({
    required String accession,
    required String gene,
  });
}
