import 'package:freezed_annotation/freezed_annotation.dart';

part 'nucleotide_counts.freezed.dart';

/// How many of each base a sequence contains.
///
/// `other` absorbs ambiguity codes (N, R, Y…) and gap characters, which is why
/// [total] is computed rather than assumed equal to A+T+G+C.
@freezed
abstract class NucleotideCounts with _$NucleotideCounts {
  const factory NucleotideCounts({
    @Default(0) int adenine,
    @Default(0) int thymine,
    @Default(0) int guanine,
    @Default(0) int cytosine,
    @Default(0) int other,
  }) = _NucleotideCounts;

  const NucleotideCounts._();

  /// Tallies a normalised (uppercased, whitespace-free) base string.
  ///
  /// Uracil is counted as thymine: RNA's U occupies T's position, so composition
  /// statistics stay comparable across DNA and RNA.
  factory NucleotideCounts.fromBases(String bases) {
    int a = 0;
    int t = 0;
    int g = 0;
    int c = 0;
    int other = 0;

    for (int i = 0; i < bases.length; i++) {
      switch (bases[i]) {
        case 'A':
          a++;
        case 'T' || 'U':
          t++;
        case 'G':
          g++;
        case 'C':
          c++;
        default:
          other++;
      }
    }

    return NucleotideCounts(
      adenine: a,
      thymine: t,
      guanine: g,
      cytosine: c,
      other: other,
    );
  }

  int get total => adenine + thymine + guanine + cytosine + other;

  /// GC content as a percentage — one of the most-used summary statistics in
  /// molecular biology, since it correlates with duplex stability.
  double get gcContentPercent {
    if (total == 0) {
      return 0;
    }
    return (guanine + cytosine) / total * 100;
  }
}
