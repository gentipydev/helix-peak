import '../../../../core/biology/amino_acids.dart';
import '../../../../core/biology/gene_record.dart';
import '../../../../shared/format.dart';
import '../domain/apply_edit.dart';

/// One sentence saying what an edit did to the molecule, built from the
/// outcome and the two records.
///
/// Mechanism only. It says what the codons, the mRNA and the protein now are;
/// what that means for a person is not something a record can say, and no
/// sentence here tries. Where ClinVar has the exact change, its own words are
/// shown beside this, quoted, never folded into it.
String outcomeSentence(
  EditOutcome outcome, {
  required GeneRecord before,
  required GeneRecord after,
}) {
  final int? codon = outcome.codonIndex;
  final int length = before.protein?.translation.length ?? 0;
  final int edited = after.protein?.translation.length ?? 0;
  final bool stops = _stops(after);
  final String? was = _residue(outcome.oldResidue);
  final String? now = _residue(outcome.newResidue);
  return switch (outcome.kind) {
    EditOutcomeKind.synonymous =>
      'Codon ${grouped(codon!)} still reads $was, so the protein is '
          'unchanged.',
    EditOutcomeKind.missense =>
      'Codon ${grouped(codon!)} now reads $now where it read $was: one '
          'residue of ${grouped(length)} changes.',
    EditOutcomeKind.nonsense =>
      'Codon ${grouped(codon!)} is now a stop, so the protein ends after '
          '${grouped(codon - 1)} of its ${grouped(length)} residues.',
    EditOutcomeKind.frameshift =>
      'From codon ${grouped(codon!)} the reading frame shifts, so every '
          'codon after it reads differently, '
          '${stops ? 'until a stop at codon ${grouped(edited + 1)}' : 'and no stop comes before the mRNA ends'}.',
    EditOutcomeKind.inFrameIndel =>
      '${spelledLeading((edited - length).abs())} '
          '${(edited - length).abs() == 1 ? 'codon' : 'codons'} '
          '${edited > length ? 'gained' : 'lost'} at codon ${grouped(codon!)}; '
          'the frame holds, and the protein is ${grouped(edited)} residues '
          'instead of ${grouped(length)}.',
    EditOutcomeKind.stopLoss =>
      'The stop codon now reads $now, so translation runs on into the '
          '3′ UTR '
          '${stops ? 'to a stop at codon ${grouped(edited + 1)}' : 'and meets no stop before the mRNA ends'}.',
    EditOutcomeKind.spliceSite =>
      'This breaks a splice site: the intron no longer starts and ends with '
          'a pair splicing recognises (GT–AG, GC–AG or AT–AC), so the mRNA '
          'drawn here may no longer be the one made.',
    EditOutcomeKind.intronic =>
      'Inside an intron, clear of its splice sites: the intron is spliced '
          'out, so the mRNA and the protein are unchanged.',
    EditOutcomeKind.utr =>
      'In an untranslated end of the mRNA: every codon, and so the protein, '
          'is unchanged.',
    EditOutcomeKind.mrnaDegraded =>
      'Codon ${grouped(codon!)} is now a stop more than '
          '${spelled(nmdThresholdBp)} bases before the last exon junction: '
          'nonsense-mediated decay destroys this mRNA, so no short protein '
          'is made.',
  };
}

/// A residue as a sentence names it: `alanine`, or `a stop`.
String? _residue(String? letter) => switch (letter) {
  null => null,
  '*' => 'a stop',
  final String code => AminoAcids.nameOf(code).toLowerCase(),
};

/// Whether the edited record's reading ends at a stop codon.
///
/// The edit engine reads the protein to the first stop and keeps it without
/// the stop, so a reading that stopped is one whose coding sequence covers
/// exactly one codon more than its residues.
bool _stops(GeneRecord record) {
  final Protein? protein = record.protein;
  if (protein == null) {
    return false;
  }
  final int bases = protein.segments.fold<int>(
    0,
    (int sum, Segment s) => sum + s.end - s.start + 1,
  );
  return bases == 3 * (protein.translation.length + 1);
}
