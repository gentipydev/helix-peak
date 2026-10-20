import 'package:flutter/foundation.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/biology/genetic_code.dart';
import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/evidence/protein_constraint.dart';
import '../../../../shared/anatomy/anatomy_address.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';

/// The transcript joins a specific base to a precursor residue. Genomic
/// arithmetic cannot do this across introns or on a reverse-strand record.
@immutable
final class CodingEvidence {
  const CodingEvidence._({
    required this.codon,
    required this.triplet,
    required this.offset,
    required this.residueName,
    required this.constraint,
  });

  /// The 1-based codon the base is in.
  final int codon;
  final String triplet;
  final int offset;
  final String residueName;
  final ResidueConstraint? constraint;

  static CodingEvidence? at({
    required AnatomyModel model,
    required int position,
    required ProteinConstraint? track,
  }) {
    final AnatomyAddress address = AnatomyAddress.of(model);
    final int? cdsOffset = address.cdsOffsetOf(position);
    if (cdsOffset == null) return null;
    final int codon = cdsOffset ~/ 3 + 1;
    final int? residue = address.residueOfCodon(codon);
    final String? triplet = address.tripletOf(codon);
    // A stop belongs to the CDS but encodes no residue.
    if (residue == null || triplet == null) return null;
    final AnatomyStage protein = model.stages.firstWhere(
      (AnatomyStage stage) => stage.kind == StageKind.protein,
    );
    if (GeneticCode.translate(triplet) != protein.letters[residue - 1]) {
      return null;
    }
    return CodingEvidence._(
      codon: codon,
      triplet: triplet,
      offset: cdsOffset % 3,
      residueName: address.residueName(residue)!,
      // Apply the same whole-sequence check as the protein screen, so an
      // unrelated track never supplies even a coincidentally matching residue.
      constraint: track?.sequence == protein.letters
          ? track!.positions[residue - 1]
          : null,
    );
  }

  /// What [alt] in this base's place makes of the codon, as the base sheet
  /// writes it: the new amino acid's three letters, `=` where it is the same
  /// one, `Ter` for a stop, and `?` anywhere in the start codon, where HGVS
  /// writes p.Met1? because what is made instead cannot be said. Empty for a
  /// letter that is not a base.
  String changeTo(String alt) {
    final String? made = _made(alt);
    if (made == null) return '';
    if (codon == 1) return '?';
    if (made == GeneticCode.translate(triplet)) return '=';
    return made == '*' ? 'Ter' : AminoAcids.abbreviationOf(made);
  }

  /// [changeTo], as a screen reader says it.
  String spokenChangeTo(String alt) {
    final String? made = _made(alt);
    return switch (changeTo(alt)) {
      '' => '',
      '?' => 'start codon lost',
      '=' => 'same amino acid',
      'Ter' => 'stop codon',
      _ => AminoAcids.nameOf(made!),
    };
  }

  /// The one-letter amino acid the codon reads with [alt] in this base's
  /// place, `*` for a stop.
  String? _made(String alt) =>
      GeneticCode.translate(triplet.replaceRange(offset, offset + 1, alt));

  List<String> get synonymousAlternatives => <String>[
    for (final String base in GeneImpact.bases.split(''))
      if (base != triplet[offset] &&
          GeneticCode.translate(
                triplet.replaceRange(offset, offset + 1, base),
              ) ==
              GeneticCode.translate(triplet))
        base,
  ];
}
