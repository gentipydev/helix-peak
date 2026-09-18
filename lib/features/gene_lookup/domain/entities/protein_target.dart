import 'package:flutter/material.dart';

import '../../../../core/theme/anatomy_colors.dart';
import 'gene_query.dart';

/// Which theme token paints one chain of a baked model.
///
/// The colours are not free choices. A chain keeps the colour it had as
/// squares one page earlier, where the mature-peptide stage hands the peptides
/// `roleMature1/2/3` in the order the record lists them — which is why
/// insulin's B chain is the first and its A chain the third. The continuity is
/// the point of the structure page rather than a nicety: the reader has to
/// recognise the fold as *these* chains and not as a new picture.
enum ChainTint {
  /// The first mature peptide the record names.
  mature1,

  /// The second.
  mature2,

  /// The third.
  mature3,

  /// Cystine. Needs no special case — a disulfide bridge is two cysteines, and
  /// that is already the residue's colour in the palette.
  cysteine;

  Color of(AnatomyColors anatomy) => switch (this) {
    ChainTint.mature1 => anatomy.roleMature1,
    ChainTint.mature2 => anatomy.roleMature2,
    ChainTint.mature3 => anatomy.roleMature3,
    ChainTint.cysteine => anatomy.aminoCysteine,
  };
}

/// One named node of a baked `.glb`, and how to paint it.
///
/// The names are the contract with the bake in `tool/structure/`: renaming a
/// node there takes its colour off here. A model has a `chainA`, may have a
/// `chainB`, and has a `bonds` node only where the entry has disulfides the
/// page is about.
@immutable
final class StructureChain {
  const StructureChain(this.node, this.tint);

  final String node;
  final ChainTint tint;
}

/// What the last page of the walk says about the fold it is drawing.
///
/// Prose rather than a template, because the interesting thing differs per
/// protein: insulin's page is about three bridges surviving a cut, dystrophin's
/// is about how little of it anyone has ever solved.
@immutable
final class StructureChrome {
  const StructureChrome({
    required this.pdb,
    required this.label,
    required this.count,
    required this.unit,
    required this.sentence,
    required this.semantics,
    this.modelled,
  });

  /// The PDB entry the model is cut from — `tool/targets.py` bakes it, and
  /// `check_assets.py` holds the two to each other.
  final String pdb;

  /// The precursor span the model covers, where it is not the whole mature
  /// protein: p53's DNA-binding core is 96–289 of 393. Null for an entry that
  /// covers its chains whole.
  final (int, int)? modelled;

  final String label;
  final int count;
  final String unit;

  /// The single line under the count. Never a paragraph.
  final String sentence;

  /// What a screen reader is told, in place of a picture it cannot describe.
  final String semantics;
}

/// The figures a reader weighs a protein by before walking it, as the search
/// list shows them. Each is a fact about the baked assets, and the catalog
/// tests derive every one of them again from those assets.
@immutable
final class ProteinFacts {
  const ProteinFacts({
    required this.residues,
    required this.exons,
    required this.chains,
    required this.bridges,
  });

  /// Residues in the precursor the record translates.
  final int residues;

  /// Exons in the transcript.
  final int exons;

  /// Chains the precursor is cut into, or 1 where the walk ends at one chain.
  final int chains;

  /// Disulfide bridges in the constraint track's table.
  final int bridges;
}

/// One protein the app can walk, and every asset that walk reads.
///
/// This is the whole of what used to be hardcoded. The gene the screen asks
/// for, the fixture that answers when there is no backend, the constraint track
/// the protein page colours itself with and the model the last page draws were
/// each named in a different file, each of them insulin's; they are one row
/// here, and adding a protein is adding a row plus its baked assets — two of
/// them, or three where it is [scored].
@immutable
final class ProteinTarget {
  const ProteinTarget({
    required this.slug,
    required this.display,
    required this.gene,
    required this.uniprot,
    required this.accession,
    required this.summary,
    required this.facts,
    required this.chains,
    required this.structure,
    this.chain,
    this.scored = true,
  });

  /// URL-safe, and the stem of every asset this target owns.
  final String slug;

  /// What the search screen calls it.
  final String display;

  /// The `/gene` qualifier, and the second half of the backend's path.
  final String gene;

  final String uniprot;

  /// The GenBank record the gene is lifted out of, and the first half of the
  /// backend's path. A RefSeqGene where one exists; a chromosome accession for
  /// the two genes that have none.
  final String accession;

  /// One line on the search card. Why a reader might want this one.
  final String summary;

  /// The figures the search card leads with.
  final ProteinFacts facts;

  final List<StructureChain> chains;
  final StructureChrome structure;

  /// What the gene page calls the coding sequence of a protein that is never
  /// cut into chains: 'hemoglobin beta chain', 'p53'.
  ///
  /// A cut precursor needs none — its record names every chain, and the page
  /// labels each stretch by the chain it becomes. An uncut one has no such
  /// feature, so its gene page read "coding sequence" where every other one
  /// read what the gene makes. The record's own `/product` is no substitute:
  /// "cellular tumor antigen p53 isoform a" does not fit a band.
  final String? chain;

  /// Whether a constraint track has been baked for this protein.
  ///
  /// Every protein in the catalog is. One added before its track is baked is
  /// not, and that is a state the walk draws — the protein page without its
  /// conservation toolbar, a tap following the tracer as on every other page —
  /// and not a file that failed to load, so nothing asks for [constraintAsset]
  /// where this is false. `scored` in `tool/targets.py` says the same, and
  /// `check_assets.py` holds the two to each other.
  final bool scored;

  GeneQuery get query => GeneQuery(accession: accession, gene: gene);

  String get mockAsset => 'assets/mock/gene_${gene.toLowerCase()}.json';

  /// Where the track is, or would be. Read only where [scored].
  String get constraintAsset => 'assets/constraint/${slug}_esm_constraint.json';

  /// The bake's own path, not a shipped one: `hook/build.dart` compiles it into
  /// `flutter_scene_generated/`, and `loadScene` resolves it back by this name.
  String get structureAsset => 'assets/models/$slug.glb';

  @override
  bool operator ==(Object other) => other is ProteinTarget && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;

  @override
  String toString() => 'ProteinTarget($slug)';
}
