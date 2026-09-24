import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/presentation/format.dart';

void main() {
  test('a genome rank is written out, never in exponent notation', () {
    expect(genomeRank(5), 'bottom 90%');
    expect(genomeRank(20), 'top 1.0%');
    expect(genomeRank(31.5), 'top 0.071%');
    // Past Phred 40, where every gene has alleles: two significant figures,
    // as the Atlas writes a percentile, down to the tracks' ceiling of 70.
    expect(genomeRank(45), 'top 0.0032%');
    expect(genomeRank(50), 'top 0.0010%');
    expect(genomeRank(70), 'top 0.000010%');
  });
}
