import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/catalog/protein_target.dart';
import '../../core/catalog/protein_track.dart';
import '../../core/network/track_source.dart';

/// Whether the experiment gave a residue a place.
enum FoldPlace {
  /// Its CA is where the entry put it: a place in the fold to settle into.
  ordered,

  /// It was in the experiment and has no place in it. It stays loose for good.
  disordered,

  /// Not in the entry at all, past the ends of what was crystallised. The
  /// track says nothing about it, and nothing is drawn for it.
  absent;

  static FoldPlace fromWire(String wire) => FoldPlace.values.byName(wire);
}

/// What an ordered residue's stretch of chain is, as the entry assigns it.
enum FoldShape {
  helix,
  strand,
  coil;

  static FoldShape fromWire(String wire) => FoldShape.values.byName(wire);
}

/// A point in the stored structure model's frame: centred, longest axis 1.0.
typedef ModelPoint = (double x, double y, double z);

@immutable
final class FoldResidue {
  const FoldResidue({
    required this.number,
    required this.letter,
    required this.place,
    this.shape,
    this.ca,
    this.ribbonAt,
    this.ribbonAcross,
  });

  /// Its position in the precursor, the walk's numbering.
  final int number;

  /// What the gene makes here, one letter.
  final String letter;

  final FoldPlace place;

  /// Only for an ordered residue.
  final FoldShape? shape;

  /// Only for an ordered residue: its CA in the finished fold.
  final ModelPoint? ca;

  /// Only for a helix or strand residue, where the model's ribbon was
  /// measured: where the ribbon passes it, and which way the ribbon lies
  /// across there (a direction, of no particular sign). A helix's runs
  /// within a fraction of an angstrom of its CA; a strand's, flattened into
  /// its sheet, up to three angstroms off.
  final ModelPoint? ribbonAt;
  final ModelPoint? ribbonAcross;

  bool get isOrdered => place == FoldPlace.ordered;
}

/// One node of the structure model, residue by residue.
@immutable
final class FoldChain {
  const FoldChain({required this.node, required this.residues});

  /// The model's node the chain is drawn as, and coloured by: `chainA`.
  final String node;

  /// Every residue of the mature chain the node is cut from, in order and
  /// without a gap.
  final List<FoldResidue> residues;
}

/// What the model draws its chains as.
enum FoldRepresentation {
  /// Helices as ovals, strands as arrows, the rest as a thin loop.
  cartoon,

  /// One round tube down the whole chain: a peptide with no helix or strand.
  tube;

  static FoldRepresentation fromWire(String wire) =>
      FoldRepresentation.values.byName(wire);
}

/// The shapes the model's chains are drawn with, in angstroms: PyMOL's own
/// settings, which the track carries so that a fold drawn from it ends as
/// wide and as thick as the model it hands over to.
@immutable
final class FoldCartoon {
  const FoldCartoon({
    required this.representation,
    required this.loopRadius,
    required this.helixHalfWidth,
    required this.helixHalfThickness,
    required this.strandHalfWidth,
    required this.strandHalfThickness,
    required this.tubeRadius,
    required this.rodRadius,
  });

  /// PyMOL 3.1.0's cartoon, and the structure bake's tube and rods: what a
  /// schema-1 track, which does not say, was drawn with.
  static const FoldCartoon pymol = FoldCartoon(
    representation: FoldRepresentation.cartoon,
    loopRadius: 0.2,
    helixHalfWidth: 1.35,
    helixHalfThickness: 0.25,
    strandHalfWidth: 1.4,
    strandHalfThickness: 0.4,
    tubeRadius: 0.6,
    rodRadius: 0.5,
  );

  factory FoldCartoon.fromJson(Map<String, dynamic> json) {
    double half(String shape, String key) =>
        ((json[shape] as Map<String, dynamic>)[key] as num).toDouble();
    return FoldCartoon(
      representation: FoldRepresentation.fromWire(
        json['representation'] as String,
      ),
      loopRadius: (json['loop_radius'] as num).toDouble(),
      helixHalfWidth: half('helix', 'half_width'),
      helixHalfThickness: half('helix', 'half_thickness'),
      strandHalfWidth: half('strand', 'half_width'),
      strandHalfThickness: half('strand', 'half_thickness'),
      tubeRadius: (json['tube_radius'] as num).toDouble(),
      rodRadius: (json['rod_radius'] as num).toDouble(),
    );
  }

  final FoldRepresentation representation;
  final double loopRadius;
  final double helixHalfWidth;
  final double helixHalfThickness;
  final double strandHalfWidth;
  final double strandHalfThickness;
  final double tubeRadius;

  /// A bridge's rods.
  final double rodRadius;
}

/// One disulfide the model draws, as the atoms its rods run through.
@immutable
final class FoldBridge {
  const FoldBridge({
    required this.a,
    required this.aNode,
    required this.b,
    required this.bNode,
    required this.path,
  });

  /// Its two cysteines, in precursor numbering, the lower first, and the
  /// chain each is in.
  final int a;
  final String aNode;
  final int b;
  final String bNode;

  /// CA, CB and SG of [a], then SG, CB and CA of [b], in the model's frame.
  final List<ModelPoint> path;
}

/// The `folding` track: each chain of a fold as its CA trace, residue by
/// residue, in the stored structure model's own frame.
///
/// Baked by `pipeline/folding/` in the backend from the entry the fold page's
/// model was cut from, and placed in that model's frame: the last frame of a
/// fold animation drawn from it lands on the fold the page draws. Since
/// schema 2 it also carries the model's bridges and the cartoon's sizes.
@immutable
final class FoldingTrack {
  const FoldingTrack({
    required this.pdb,
    required this.chains,
    required this.boundsMin,
    required this.boundsMax,
    required this.angstromsPerUnit,
    this.cartoon = FoldCartoon.pymol,
    this.bridges = const <FoldBridge>[],
  });

  /// Parses one payload, refusing one that names another protein, a chain
  /// the catalog's fold does not have, or residues that are not a chain.
  factory FoldingTrack.fromJson(
    Map<String, dynamic> json,
    ProteinTarget target,
  ) {
    if (json['gene'] != target.gene || json['uniprot'] != target.uniprot) {
      throw FormatException(
        'A folding track for another protein, not ${target.slug}',
      );
    }
    final Map<String, dynamic>? frame = json['frame'] as Map<String, dynamic>?;
    final Map<String, dynamic>? bounds =
        frame?['bounds'] as Map<String, dynamic>?;
    final Object? length = frame?['length_angstrom'];
    if (bounds == null || length is! num || length <= 0) {
      throw FormatException(
        'A folding track for ${target.slug} with no frame to draw it in',
      );
    }
    final Set<String> nodes = <String>{
      for (final StructureChain chain in target.chains) chain.node,
    };
    final List<FoldChain> chains = <FoldChain>[];
    for (final dynamic raw in json['chains'] as List<dynamic>? ?? <dynamic>[]) {
      final Map<String, dynamic> chain = raw as Map<String, dynamic>;
      final String? node = chain['node'] as String?;
      if (node == null || !nodes.contains(node) || node == 'bonds') {
        throw FormatException(
          'A folding track for ${target.slug} with a chain the fold has no '
          'node for: $node',
        );
      }
      chains.add(
        FoldChain(node: node, residues: _residues(chain, target, node)),
      );
    }
    if (chains.isEmpty) {
      throw FormatException('A folding track for ${target.slug} with no chain');
    }
    final Map<String, dynamic>? cartoon =
        json['cartoon'] as Map<String, dynamic>?;
    return FoldingTrack(
      pdb: json['pdb'] as String? ?? '',
      chains: List<FoldChain>.unmodifiable(chains),
      boundsMin: _point(bounds['min'], target),
      boundsMax: _point(bounds['max'], target),
      angstromsPerUnit: length.toDouble(),
      cartoon: cartoon == null
          ? FoldCartoon.pymol
          : FoldCartoon.fromJson(cartoon),
      bridges: List<FoldBridge>.unmodifiable(<FoldBridge>[
        for (final dynamic raw
            in json['bridges'] as List<dynamic>? ?? <dynamic>[])
          _bridge(raw as Map<String, dynamic>, target, chains),
      ]),
    );
  }

  /// [target]'s track, read through [tracks]. Only asked for where the row
  /// says it is ready: a track that is not is a state the screen draws.
  static Future<FoldingTrack> load(
    ProteinTarget target, {
    required TrackSource tracks,
  }) async {
    final Uint8List bytes = await tracks.read(target.slug, TrackKind.folding);
    final Object? json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw FormatException('Malformed folding track for ${target.slug}');
    }
    return FoldingTrack.fromJson(json, target);
  }

  /// The PDB entry the chains were read from.
  final String pdb;

  final List<FoldChain> chains;

  /// The stored model's bounding box: what the fold page frames it by.
  final ModelPoint boundsMin;
  final ModelPoint boundsMax;

  /// How many angstroms one model unit is, so that a length measured on a
  /// molecule (3.8 A from one CA to the next) can be drawn in its frame.
  final double angstromsPerUnit;

  /// What the model draws its chains with.
  final FoldCartoon cartoon;

  /// The model's disulfides, in precursor order. None for a model that draws
  /// none, and for a schema-1 track, which does not say.
  final List<FoldBridge> bridges;

  /// A bridge whose ends are not two ordered cysteines of the chains is
  /// refused: the model's rods start and end on them.
  static FoldBridge _bridge(
    Map<String, dynamic> json,
    ProteinTarget target,
    List<FoldChain> chains,
  ) {
    FoldResidue? residue(String? node, Object? number) {
      for (final FoldChain chain in chains) {
        if (chain.node != node) {
          continue;
        }
        for (final FoldResidue r in chain.residues) {
          if (r.number == number) {
            return r;
          }
        }
      }
      return null;
    }

    final String? aNode = json['a_node'] as String?;
    final String? bNode = json['b_node'] as String?;
    final Object? a = json['a'];
    final Object? b = json['b'];
    final List<dynamic>? path = json['path'] as List<dynamic>?;
    final List<FoldResidue?> ends = <FoldResidue?>[
      residue(aNode, a),
      residue(bNode, b),
    ];
    if (a is! int ||
        b is! int ||
        path == null ||
        path.length != 6 ||
        ends.any(
          (FoldResidue? r) => r == null || !r.isOrdered || r.letter != 'C',
        )) {
      throw FormatException('A malformed bridge in ${target.slug}: $json');
    }
    return FoldBridge(
      a: a,
      aNode: aNode!,
      b: b,
      bNode: bNode!,
      path: List<ModelPoint>.unmodifiable(<ModelPoint>[
        for (final Object? point in path) _point(point, target),
      ]),
    );
  }

  static List<FoldResidue> _residues(
    Map<String, dynamic> chain,
    ProteinTarget target,
    String node,
  ) {
    final List<FoldResidue> out = <FoldResidue>[];
    for (final dynamic raw
        in chain['residues'] as List<dynamic>? ?? <dynamic>[]) {
      final Map<String, dynamic> residue = raw as Map<String, dynamic>;
      final Object? number = residue['n'];
      final String? letter = residue['aa'] as String?;
      final String? place = residue['state'] as String?;
      if (number is! int ||
          letter == null ||
          letter.length != 1 ||
          place == null) {
        throw FormatException(
          'A malformed residue of ${target.slug}: $residue',
        );
      }
      if (out.isNotEmpty && number != out.last.number + 1) {
        throw FormatException(
          'The ${target.slug} $node chain skips from ${out.last.number} to '
          '$number',
        );
      }
      final FoldPlace kind = FoldPlace.fromWire(place);
      if (kind != FoldPlace.ordered) {
        out.add(FoldResidue(number: number, letter: letter, place: kind));
        continue;
      }
      final String? shape = residue['ss'] as String?;
      final List<dynamic>? ca = residue['ca'] as List<dynamic>?;
      if (shape == null || ca == null) {
        throw FormatException(
          'An ordered residue of ${target.slug} with no place: $number',
        );
      }
      final List<dynamic>? ribbon = residue['ribbon'] as List<dynamic>?;
      if (ribbon != null && ribbon.length != 6) {
        throw FormatException(
          'A malformed ribbon in ${target.slug} at $number: $ribbon',
        );
      }
      out.add(
        FoldResidue(
          number: number,
          letter: letter,
          place: kind,
          shape: FoldShape.fromWire(shape),
          ca: _point(ca, target),
          ribbonAt: ribbon == null ? null : _point(ribbon.sublist(0, 3), target),
          ribbonAcross: ribbon == null
              ? null
              : _point(ribbon.sublist(3), target),
        ),
      );
    }
    if (!out.any((FoldResidue r) => r.isOrdered)) {
      throw FormatException(
        'The ${target.slug} $node chain has no residue with a place',
      );
    }
    return List<FoldResidue>.unmodifiable(out);
  }

  static ModelPoint _point(Object? raw, ProteinTarget target) {
    if (raw is! List<dynamic> || raw.length != 3 || raw.any((e) => e is! num)) {
      throw FormatException('A malformed point in ${target.slug}: $raw');
    }
    return (
      (raw[0] as num).toDouble(),
      (raw[1] as num).toDouble(),
      (raw[2] as num).toDouble(),
    );
  }
}
