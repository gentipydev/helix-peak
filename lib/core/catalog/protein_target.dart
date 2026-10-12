import 'package:flutter/material.dart';

import '../theme/anatomy_colors.dart';
import 'gene_query.dart';
import 'protein_track.dart';

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
  cysteine,

  /// The residues of a predicted model AlphaFold is surest of: pLDDT 90 and
  /// over. A model from AlphaFold DB is not cut into chains but into these
  /// four bands of confidence, one node each (`pipeline/structure/alphafold.py`
  /// in the backend), because what a reader needs of a prediction is how far
  /// to believe each part of it.
  plddtVeryHigh,

  /// pLDDT 70 to 90.
  plddtConfident,

  /// pLDDT 50 to 70.
  plddtLow,

  /// pLDDT under 50: often no fixed shape at all.
  plddtVeryLow;

  /// The tint named on the wire. The names are the enum's own, so a tint the
  /// service invents later is a bug worth hearing about rather than a colour
  /// quietly defaulted to something plausible.
  static ChainTint fromWire(String wire) => ChainTint.values.byName(wire);

  Color of(AnatomyColors anatomy) => switch (this) {
    ChainTint.mature1 => anatomy.roleMature1,
    ChainTint.mature2 => anatomy.roleMature2,
    ChainTint.mature3 => anatomy.roleMature3,
    ChainTint.cysteine => anatomy.aminoCysteine,
    ChainTint.plddtVeryHigh => anatomy.plddtVeryHigh,
    ChainTint.plddtConfident => anatomy.plddtConfident,
    ChainTint.plddtLow => anatomy.plddtLow,
    ChainTint.plddtVeryLow => anatomy.plddtVeryLow,
  };

  /// What a band of confidence is called in the fold's legend, or null for a
  /// tint that is a chain's or the bridges', which the record names.
  String? get confidence => switch (this) {
    ChainTint.plddtVeryHigh => 'pLDDT \u2265 90',
    ChainTint.plddtConfident => 'pLDDT 70\u201390',
    ChainTint.plddtLow => 'pLDDT 50\u201370',
    ChainTint.plddtVeryLow => 'pLDDT < 50',
    ChainTint.mature1 ||
    ChainTint.mature2 ||
    ChainTint.mature3 ||
    ChainTint.cysteine => null,
  };
}

/// One named node of a baked `.glb`, and how to paint it.
///
/// The names are the contract with the bake in `pipeline/structure/`: renaming a
/// node there takes its colour off here. A model has a `chainA`, may have a
/// `chainB`, and has a `bonds` node only where the entry has disulfides the
/// page is about.
@immutable
final class StructureChain {
  const StructureChain(this.node, this.tint);

  factory StructureChain.fromJson(Map<String, dynamic> json) => StructureChain(
    json['node'] as String,
    ChainTint.fromWire(json['tint'] as String),
  );

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

  factory StructureChrome.fromJson(Map<String, dynamic> json) {
    // A record on this side, a two-element array on the wire: JSON has no
    // tuples, and widening this to a class would put a name on a pair that
    // reads fine without one.
    final List<dynamic>? span = json['modelled'] as List<dynamic>?;
    return StructureChrome(
      pdb: json['pdb'] as String,
      label: json['label'] as String,
      count: json['count'] as int,
      unit: json['unit'] as String,
      sentence: json['sentence'] as String,
      semantics: json['semantics'] as String,
      modelled: span == null
          ? null
          : (span[0] as int, span[1] as int),
    );
  }

  /// The PDB entry the model is cut from — `pipeline/targets.py` bakes it, and
  /// `check_assets.py` holds the two to each other. For a protein built on
  /// demand, the AlphaFold DB entry its model is: see [predicted].
  final String pdb;

  /// Whether the model is AlphaFold DB's prediction and not an experiment's
  /// entry. Read off the id itself, which is a rule over every protein and
  /// names none: AlphaFold DB's are `AF-<accession>-F<n>`, and a PDB entry's
  /// is four characters.
  bool get predicted => pdb.startsWith('AF-');

  /// Where the model is from, as the page names it: `PDB 2OCJ`, or
  /// `AlphaFold DB AF-Q04671-F1`.
  String get source => predicted ? 'AlphaFold DB $pdb' : 'PDB $pdb';

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

  factory ProteinFacts.fromJson(Map<String, dynamic> json) => ProteinFacts(
    residues: json['residues'] as int,
    exons: json['exons'] as int,
    chains: json['chains'] as int,
    bridges: json['bridges'] as int,
  );

  /// Residues in the precursor the record translates.
  final int residues;

  /// Exons in the transcript.
  final int exons;

  /// Chains the precursor is cut into, or 1 where the walk ends at one chain.
  final int chains;

  /// Disulfide bridges in the constraint track's table.
  final int bridges;
}

/// A named stretch of the precursor, as the service's table of a protein's
/// regions has it: its signal peptide, a chain, a propeptide. Numbered as the
/// precursor is, 1-based inclusive; [kept] is whether the stretch is still
/// there once the precursor has been cut.
///
/// Only a protein built on demand is served with its table
/// (`/protein/{slug}`): a catalog row carries none, and the twenty's regions
/// are their records' own.
@immutable
final class ProteinRegion {
  const ProteinRegion({
    required this.label,
    required this.start,
    required this.end,
    this.kept = true,
  });

  factory ProteinRegion.fromJson(Map<String, dynamic> json) => ProteinRegion(
    label: json['label'] as String,
    start: json['start'] as int,
    end: json['end'] as int,
    kept: json['kept'] as bool? ?? true,
  );

  final String label;
  final int start;
  final int end;
  final bool kept;
}

/// One protein the service can walk, with its track states and fold metadata.
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
    this.impactExplanationsAvailable = false,
    this.tracks = const <TrackKind, TrackRef>{},
    this.regions = const <ProteinRegion>[],
  });

  /// A catalog or detail row as the service serves it.
  factory ProteinTarget.fromJson(Map<String, dynamic> json) {
    final Map<TrackKind, TrackRef> tracks = tracksFromJson(
      json['tracks'] as Map<String, dynamic>?,
    );
    final Map<String, dynamic>? chrome =
        json['structure'] as Map<String, dynamic>?;
    return ProteinTarget(
      slug: json['slug'] as String,
      display: json['display'] as String,
      gene: json['gene'] as String,
      uniprot: json['uniprot'] as String,
      accession: json['accession'] as String,
      summary: json['summary'] as String,
      facts: ProteinFacts.fromJson(json['facts'] as Map<String, dynamic>),
      chains: <StructureChain>[
        for (final dynamic node in json['chains'] as List<dynamic>? ?? [])
          StructureChain.fromJson(node as Map<String, dynamic>),
      ],
      structure: chrome == null ? null : StructureChrome.fromJson(chrome),
      chain: json['chain'] as String?,
      impactExplanationsAvailable: _ready(tracks, TrackKind.impactExplanations),
      tracks: tracks,
      regions: <ProteinRegion>[
        for (final dynamic region
            in json['regions'] as List<dynamic>? ?? <dynamic>[])
          ProteinRegion.fromJson(region as Map<String, dynamic>),
      ],
    );
  }

  static bool _ready(Map<TrackKind, TrackRef> tracks, TrackKind kind) =>
      tracks[kind]?.state == TrackState.ready;

  /// URL-safe, and the stem of every asset this target owns.
  final String slug;

  /// What the search screen calls it.
  final String display;

  /// The `/gene` qualifier, and the second half of the backend's path.
  final String gene;

  final String uniprot;

  /// The GenBank record the gene is lifted out of, and the first half of the
  /// backend's path. A RefSeqGene where one exists; a chromosome accession for
  /// the genes that have none.
  final String accession;

  /// One line on the search card. Why a reader might want this one.
  final String summary;

  /// The figures the search card leads with.
  final ProteinFacts facts;

  final List<StructureChain> chains;
  final StructureChrome? structure;

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
  /// and not a track that failed to arrive, so nothing asks for the payload
  /// where this is false. `scored` in `pipeline/targets.py` says the same, and
  /// `check_assets.py` holds the two to each other.
  ///
  /// Ready means the stored track exists, not that it is on this device. A
  /// failed fetch remains a failure to retrieve it, never an absent track.
  bool get scored => state(TrackKind.constraint) == TrackState.ready;

  /// Whether an AlphaGenome Variant Impact track has been baked for this gene.
  ///
  /// The same kind of state one level down: [scored] is a per-residue track over
  /// the protein, this is a per-base track over the gene record. Without one the
  /// nucleotide pages are drawn exactly as they were — a tap moves the tracer
  /// and no sheet opens — rather than meeting a track that is not there.
  /// `impact_scored` in `pipeline/targets.py` says the same, and `check_assets.py`
  /// holds the two to each other.
  bool get impactScored => state(TrackKind.impact) == TrackState.ready;

  /// Whether exact-allele AVI contributions are included in this release.
  final bool impactExplanationsAvailable;

  /// Whether a ClinVar snapshot has been baked for this gene.
  ///
  /// Every gene in the catalog has one. One added before its snapshot is baked
  /// has not, and the walk says so — "not yet included", once, in the About
  /// sheet — rather than meeting a snapshot that is not there. False is not a
  /// negative finding. `clinvar_available` in `pipeline/targets.py` says the same,
  /// and `check_assets.py` holds the two to each other.
  ///
  bool get clinvarAvailable => state(TrackKind.clinvar) == TrackState.ready;

  GeneQuery get query =>
      GeneQuery(slug: slug, accession: accession, gene: gene);

  /// The served state of each family, independent of the device cache.
  final Map<TrackKind, TrackRef> tracks;

  /// The precursor's table of regions, in order, where the row carries one:
  /// a protein built on demand's. Empty for a catalog row.
  final List<ProteinRegion> regions;

  /// Where [kind] has got to, or [TrackState.absent] where nothing was said.
  TrackState state(TrackKind kind) =>
      tracks[kind]?.state ?? TrackState.absent;

  /// The sentence behind a [TrackState.refused], and null for every other
  /// state. Never a message to show for an absent track — that one is a state
  /// the walk draws, not a failure it reports.
  String? reason(TrackKind kind) => tracks[kind]?.reason;

  @override
  bool operator ==(Object other) =>
      other is ProteinTarget && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;

  @override
  String toString() => 'ProteinTarget($slug)';
}
