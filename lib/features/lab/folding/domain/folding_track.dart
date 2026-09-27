import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/track_source.dart';

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

/// The `folding` track: each chain of a fold as its CA trace, residue by
/// residue, in the stored structure model's own frame.
///
/// Baked by `pipeline/folding/` in the backend from the entry the fold page's
/// model was cut from, and placed in that model's frame: the last frame of a
/// fold animation drawn from it lands on the fold the page draws.
@immutable
final class FoldingTrack {
  const FoldingTrack({
    required this.pdb,
    required this.chains,
    required this.boundsMin,
    required this.boundsMax,
    required this.angstromsPerUnit,
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
    return FoldingTrack(
      pdb: json['pdb'] as String? ?? '',
      chains: List<FoldChain>.unmodifiable(chains),
      boundsMin: _point(bounds['min'], target),
      boundsMax: _point(bounds['max'], target),
      angstromsPerUnit: length.toDouble(),
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
      out.add(
        FoldResidue(
          number: number,
          letter: letter,
          place: kind,
          shape: FoldShape.fromWire(shape),
          ca: _point(ca, target),
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
