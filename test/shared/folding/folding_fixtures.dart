import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';

import '../../support/test_catalog.dart';

/// The twenty `folding` payloads `pipeline/folding/` baked, kept beside these
/// tests rather than in `test/fixtures/`, which belongs to the walk.
String foldingAsset(ProteinTarget target) =>
    'test/shared/folding/fixtures/${target.slug}_folding.json';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Parsed once per test file: the tests walk all twenty several times over.
final Map<String, FoldingTrack> _tracks = <String, FoldingTrack>{};
final Map<String, FoldGeometry> _geometries = <String, FoldGeometry>{};

FoldingTrack foldingOf(ProteinTarget target) => _tracks.putIfAbsent(
  target.slug,
  () => FoldingTrack.fromJson(readJson(foldingAsset(target)), target),
);

/// [target]'s disulfide pairs, as the catalog gives them: from its constraint
/// track, which is how the walk reads them.
List<(int, int)> bridgesOf(ProteinTarget target) => ProteinConstraint.fromJson(
  readJson(target.constraintAsset),
  target,
).bridges;

FoldGeometry geometryOf(ProteinTarget target) => _geometries.putIfAbsent(
  target.slug,
  () => FoldGeometry.of(foldingOf(target), bridges: bridgesOf(target)),
);

ProteinTarget target(String slug) => TestCatalog.bySlug(slug)!;

/// [target], with its row saying [state] for the folding track.
ProteinTarget withFolding(
  ProteinTarget target,
  TrackState state, {
  String? reason,
}) => ProteinTarget(
  slug: target.slug,
  display: target.display,
  gene: target.gene,
  uniprot: target.uniprot,
  accession: target.accession,
  summary: target.summary,
  facts: target.facts,
  chains: target.chains,
  structure: target.structure,
  chain: target.chain,
  impactExplanationsAvailable: target.impactExplanationsAvailable,
  tracks: <TrackKind, TrackRef>{
    ...target.tracks,
    TrackKind.folding: TrackRef(state: state, reason: reason),
  },
);

/// The two tracks the fold reads, from the fixtures, and nothing else.
final class FoldTrackSource implements TrackSource {
  FoldTrackSource({this.failing = const <TrackKind>{}});

  /// Kinds whose read fails, as a ready track that could not be fetched.
  final Set<TrackKind> failing;

  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    if (failing.contains(kind)) {
      throw const SocketException('offline');
    }
    final ProteinTarget protein = target(slug);
    return switch (kind) {
      TrackKind.folding => File(foldingAsset(protein)).readAsBytes(),
      TrackKind.constraint => File(protein.constraintAsset).readAsBytes(),
      _ => throw StateError('the fold does not read $kind'),
    };
  }
}
