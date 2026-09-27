import 'package:flutter/foundation.dart';

import '../../../../core/evidence/protein_constraint.dart';

/// What a trafficking route is derived from: whether the precursor has a
/// signal peptide, a transmembrane span or a GPI-anchor signal, which
/// cysteines it bridges, and where it is cut.
///
/// Four of the five are read off the protein's region table, the gapless
/// tiling of the precursor that the constraint track carries. That table is
/// where the bake writes what the precursor is cut into (section 3 of
/// `docs/protein-pipeline-rules.md`), so every stretch the precursor loses is
/// in it: a signal peptide, a GPI-anchor signal or a cut it does not name is
/// one the protein does not have.
///
/// The fifth is not. A region table names what a precursor is cut into, not
/// where any of it sits, so no record says whether a stretch crosses a
/// membrane. [transmembrane] is null until something does, and null is not
/// the same as none.
@immutable
final class RouteEvidence {
  const RouteEvidence({
    required this.regions,
    this.bridges = const <(int, int)>[],
    this.transmembrane,
  });

  /// The records' evidence for one protein, and whatever [transmembrane]
  /// says about its topology.
  factory RouteEvidence.of(
    ProteinConstraint constraint, {
    List<(int, int)>? transmembrane,
  }) => RouteEvidence(
    regions: constraint.regions,
    bridges: constraint.bridges,
    transmembrane: transmembrane,
  );

  /// What `pipeline/targets.py` calls the two stretches that only a name can
  /// tell from any other removed end: UniProt's `Signal`, and the
  /// `Propeptide` that a `GPI-anchor` lipidation takes the place of.
  static const String signalPeptideLabel = 'Signal peptide';
  static const String gpiSignalLabel = 'GPI-anchor signal';

  /// The precursor's region table: residues 1 to N, with no gaps.
  final List<ConstraintRegion> regions;

  /// Every disulfide once, lower precursor number first.
  final List<(int, int)> bridges;

  /// The stretches that cross a membrane, in precursor numbering, or null
  /// where nothing has said.
  final List<(int, int)>? transmembrane;

  /// The leader that takes the chain into the ER as it is made, where the
  /// precursor has one.
  ConstraintRegion? get signalPeptide {
    final ConstraintRegion? first = regions.firstOrNull;
    return first != null && !first.kept && first.label == signalPeptideLabel
        ? first
        : null;
  }

  /// The C-terminal stretch that is cut off in the ER, and a GPI anchor put
  /// in its place.
  ///
  /// The walk has no name for it: its record's one chain stops short of it,
  /// so the gene page draws it as the C-terminal extension (R3.6). Only the
  /// region table says what it is for.
  ConstraintRegion? get gpiSignal {
    final ConstraintRegion? last = regions.lastOrNull;
    return last != null && !last.kept && last.label == gpiSignalLabel
        ? last
        : null;
  }

  /// The pieces a cut precursor is divided into, in order, or none where it
  /// is not divided.
  ///
  /// The bake numbers each piece of a precursor cut into several from its
  /// own start, and every stretch of a single chain from the chain's first
  /// residue (`partition` in `pipeline/targets.py`). So two or more kept
  /// regions counted from their own starts are pieces, and a single chain
  /// has at most one.
  List<ConstraintRegion> get pieces {
    final List<ConstraintRegion> own = <ConstraintRegion>[
      for (final ConstraintRegion region in regions)
        if (region.kept && region.origin == region.start) region,
    ];
    return own.length >= 2 ? own : const <ConstraintRegion>[];
  }

  /// What a cut removes: every stretch the precursor loses, except the three
  /// that go some other way.
  ///
  /// The signal peptide is cut off by signal peptidase as the chain enters
  /// the ER. The GPI-anchor signal is swapped for the anchor. And residue 1
  /// removed on its own is the initiator methionine, whatever the table calls
  /// it: methionine aminopeptidase clips it as the chain leaves the ribosome
  /// (R3.7), which is not a cut of the precursor.
  List<ConstraintRegion> get cutOut {
    final ConstraintRegion? signal = signalPeptide;
    final ConstraintRegion? gpi = gpiSignal;
    return <ConstraintRegion>[
      for (final ConstraintRegion region in regions)
        if (!region.kept &&
            !identical(region, signal) &&
            !identical(region, gpi) &&
            !(region.start == 1 && region.end == 1))
          region,
    ];
  }

  /// Whether the precursor is cut: into pieces, or around a stretch it loses.
  bool get cut => pieces.isNotEmpty || cutOut.isNotEmpty;
}
