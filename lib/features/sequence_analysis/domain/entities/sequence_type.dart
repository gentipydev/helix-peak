/// What kind of molecule a sequence appears to describe.
///
/// Detection is a heuristic over the alphabet used, so [unknown] is a real
/// outcome rather than an error case — ambiguous or mixed input lands here.
enum SequenceType {
  dna('DNA'),
  rna('RNA'),
  protein('Protein'),
  unknown('Unknown');

  const SequenceType(this.label);

  /// Display name, so screens never switch on the enum to render a string.
  final String label;
}
