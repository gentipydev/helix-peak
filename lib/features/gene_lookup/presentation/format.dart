import 'dart:math' as math;

import '../domain/entities/gene_impact.dart';

export '../../../shared/format.dart';

/// Where a Phred score sits against every SNV in the genome, in the Atlas's
/// own words: `top 0.071%`, or `bottom 90%`.
///
/// Below Phred 10 it is the bottom nine tenths of the genome and says so,
/// because 'top 87.1%' is not a thing anyone means: the percentile is the share
/// scoring at least this high, and at the quiet end that reading is worse than
/// useless.
String genomeRank(double phred) {
  if (phred < GeneImpact.middlePhred) {
    return 'bottom 90%';
  }
  final double value = math.pow(10, -phred / 10) * 100;
  // Enough figures to stay true at both ends: `1.0%` near the middle of the
  // scale, `0.0032%` out at the tail where every digit is the point. Two
  // significant figures there, written out: the bundled tracks reach Phred 70,
  // `0.000010%`, and `3.2e-3%` is not how a percentile is read.
  if (value >= 1) {
    return 'top ${value.toStringAsFixed(1)}%';
  }
  if (value >= 0.01) {
    return 'top ${value.toStringAsFixed(3)}%';
  }
  return 'top ${value.toStringAsPrecision(2)}%';
}
