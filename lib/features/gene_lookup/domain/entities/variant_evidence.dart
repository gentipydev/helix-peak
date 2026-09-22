import 'package:flutter/foundation.dart';

import 'gene_clinvar.dart';
import 'gene_impact.dart';
import 'protein_constraint.dart';

/// How the two models read one record's exact change, in molecular words.
///
/// Never a verdict about the record: ClinVar's classification is quoted beside
/// it and the two are left to the reader. The lines are about where each model
/// puts this change on its own scale, and about which model has anything to say
/// at all — a change that leaves the protein alone is AVI's alone.
enum EvidenceReading {
  bothStrong('Both models at their strong end.'),
  aviOnly('Only AVI at its strong end.'),
  esmOnly('Only ESM at its strong end.'),
  neither('Neither model at its strong end.'),
  synonymous('Same amino acid: only AVI applies.'),
  stop('Premature stop: only AVI applies.'),
  start('Start codon change: only AVI applies.'),
  stopCodon('Stop codon change: only AVI applies.'),
  outside('Outside the protein: only AVI applies.');

  const EvidenceReading(this.line);
  final String line;
}

/// One ClinVar record with both models' readings of its own allele.
///
/// The join the screens used to repeat per sheet, done once: the exact AVI
/// alternative at the record's base, never the base's peak, and the ESM score
/// of the record's own amino acid, never the residue's constraint. Either is
/// null where the model has no exact answer — an estimated base, a track that
/// does not match, a change that is not a substitution.
@immutable
final class VariantEvidence {
  const VariantEvidence({
    required this.variant,
    required this.section,
    required this.protein,
    required this.order,
    this.avi,
    this.esm,
    this.residue,
  });

  final ClinVarVariant variant;

  /// The exact alternative's AVI Phred.
  final double? avi;

  /// The alternative amino acid's ESM score, for a missense record.
  final SubstitutionScore? esm;

  /// The residue the record sits in, where it sits in one and the constraint
  /// track matches the protein.
  final ResidueConstraint? residue;

  /// What the record is listed under: the precursor's own region — `B chain`,
  /// `C-peptide` — or the piece of the gene around it, `Intron 2`, `5′ UTR`.
  final String section;

  /// Whether [section] is a stretch of the protein.
  final bool protein;

  /// Transcript order: the residue number on the protein, and the base's place
  /// along the transcript off it.
  final int order;

  /// The line published for ESM-1b variant scores, used here as a reference
  /// point on the same log-ratio scale rather than as a calibration of ESM-2.
  static const double esmStrong = -7.5;

  /// Records at one residue or one base in transcript order: a codon's bases
  /// run against the coordinates on a minus-strand record. Records at one base
  /// keep the snapshot's own order, by allele and then by Variation ID.
  static int Function(VariantEvidence, VariantEvidence) transcriptOrder({
    required bool reversed,
  }) => (VariantEvidence a, VariantEvidence b) {
    final int place = reversed
        ? b.variant.position.compareTo(a.variant.position)
        : a.variant.position.compareTo(b.variant.position);
    if (place != 0) {
      return place;
    }
    final int alt = a.variant.alt.compareTo(b.variant.alt);
    return alt != 0
        ? alt
        : int.parse(a.variant.id).compareTo(int.parse(b.variant.id));
  };

  EvidenceReading? get reading {
    final double? phred = avi;
    if (phred == null) {
      return null;
    }
    final bool aviStrong = phred >= GeneImpact.highPhred;
    if (variant.residue == null) {
      // A stop codon's own bases carry a consequence but no residue: the
      // protein ends there, so only the base-level model has anything to say.
      return switch (variant.consequence) {
        null => EvidenceReading.outside,
        'stop lost' || 'stop retained' => EvidenceReading.stopCodon,
        _ => null,
      };
    }
    return switch (variant.consequence) {
      'missense' => switch (esm) {
        null => null,
        final SubstitutionScore score => switch ((
          score.score <= esmStrong,
          aviStrong,
        )) {
          (true, true) => EvidenceReading.bothStrong,
          (false, true) => EvidenceReading.aviOnly,
          (true, false) => EvidenceReading.esmOnly,
          (false, false) => EvidenceReading.neither,
        },
      },
      'synonymous' => EvidenceReading.synonymous,
      'stop gained' => EvidenceReading.stop,
      'start codon' => EvidenceReading.start,
      _ => null,
    };
  }

  /// Every record of [snapshot], read against whichever tracks match it.
  ///
  /// [nonCoding] names the piece of the gene a record off the protein sits in,
  /// with its place along the transcript; the gene's layout is the screen's to
  /// know, not this layer's.
  static List<VariantEvidence> build(
    GeneClinVar snapshot, {
    required ({String label, int order}) Function(int position) nonCoding,
    GeneImpact? impact,
    ProteinConstraint? constraint,
  }) {
    final GeneImpact? track = impact != null && snapshot.matchesImpact(impact)
        ? impact
        : null;
    final ProteinConstraint? esm =
        constraint != null && constraint.sequence == snapshot.proteinSequence
        ? constraint
        : null;
    return <VariantEvidence>[
      for (final ClinVarVariant v in snapshot.variants)
        _read(v, track, esm, nonCoding),
    ];
  }

  static VariantEvidence _read(
    ClinVarVariant v,
    GeneImpact? impact,
    ProteinConstraint? constraint,
    ({String label, int order}) Function(int position) nonCoding,
  ) {
    final double? avi = v.aviScore(impact?.at(v.position));
    final int? number = v.residue;
    if (number == null) {
      final ({String label, int order}) piece = nonCoding(v.position);
      return VariantEvidence(
        variant: v,
        avi: avi,
        section: piece.label,
        protein: false,
        order: piece.order,
      );
    }
    final ResidueConstraint? residue =
        constraint != null && number <= constraint.positions.length
        ? constraint.positions[number - 1]
        : null;
    final String? alt = v.altResidue;
    return VariantEvidence(
      variant: v,
      avi: avi,
      esm: residue == null ||
              alt == null ||
              residue.wildtype != v.wildtypeResidue
          ? null
          : residue.ranked
                .where((SubstitutionScore s) => s.aminoAcid == alt)
                .firstOrNull,
      residue: residue,
      section: residue?.domain ?? 'Coding sequence',
      protein: true,
      order: number,
    );
  }
}
