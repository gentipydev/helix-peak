/// The standard nuclear DNA code used by the catalog's human transcripts.
abstract final class GeneticCode {
  static const String _bases = 'TCAG';
  static const String _aminoAcids =
      'FFLLSSSSYY**CC*W'
      'LLLLPPPPHHQQRRRR'
      'IIIMTTTTNNKKSSRR'
      'VVVVAAAADDEEGGGG';

  /// A one-letter amino acid, `*` for a stop, or null for an unknown triplet.
  static String? translate(String triplet) {
    if (triplet.length != 3) return null;
    final List<int> bases = triplet.split('').map(_bases.indexOf).toList();
    if (bases.any((int base) => base < 0)) return null;
    return _aminoAcids[bases[0] * 16 + bases[1] * 4 + bases[2]];
  }
}
