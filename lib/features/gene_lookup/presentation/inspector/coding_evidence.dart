import 'package:flutter/foundation.dart';

import '../../../../core/biology/genetic_code.dart';
import '../../domain/entities/gene_impact.dart';
import '../../domain/entities/protein_constraint.dart';
import '../anatomy/anatomy_address.dart';
import '../anatomy/anatomy_stages.dart';

/// The transcript joins a specific base to a precursor residue. Genomic
/// arithmetic cannot do this across introns or on a reverse-strand record.
@immutable
final class CodingEvidence {
  const CodingEvidence._({
    required this.triplet,
    required this.offset,
    required this.residueName,
    required this.constraint,
  });

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
