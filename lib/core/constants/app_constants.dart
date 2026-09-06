/// Domain-level constants shared across features.
abstract final class AppConstants {
  static const String appName = 'HelixPeak';
  static const String tagline = 'Sequence analysis for molecular biology';

  /// Below this, composition statistics are noise rather than signal.
  static const int minSequenceLength = 10;

  /// Guards the UI against pasted genomes. The real limit will come from the
  /// backend once it exists; this keeps the stub path responsive.
  static const int maxSequenceLength = 50000;

  /// A FASTA record begins with a single header line marked by '>'.
  static const String fastaHeaderMarker = '>';

  /// The IUPAC nucleotide alphabet, plus the gap characters that appear in
  /// aligned sequences.
  ///
  /// This is intentionally broader than `ACGT`: real data carries ambiguity
  /// codes (N for any base, R for purines, and so on), and rejecting them
  /// would make the validator wrong rather than strict.
  static const String iupacNucleotideCodes = 'ACGTURYKMSWBDHVN-.';
}
