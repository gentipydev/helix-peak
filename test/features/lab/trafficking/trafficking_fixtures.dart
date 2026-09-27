import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/features/lab/trafficking/domain/route_evidence.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_route.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_track.dart';

import '../../../support/test_catalog.dart';

/// The twenty `trafficking` payloads `pipeline/trafficking/` baked from
/// UniProt release 2026_03, kept beside these tests rather than in
/// `test/fixtures/`, which belongs to the walk.
String traffickingAsset(ProteinTarget target) =>
    'test/features/lab/trafficking/fixtures/${target.slug}_trafficking.json';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Parsed once per test file: dystrophin's constraint track alone is 1.1 MB,
/// and the tests walk all twenty several times over.
final Map<String, ProteinConstraint> _constraints =
    <String, ProteinConstraint>{};
final Map<String, TraffickingTrack> _topologies = <String, TraffickingTrack>{};

ProteinConstraint constraintOf(ProteinTarget target) =>
    _constraints.putIfAbsent(
      target.slug,
      () =>
          ProteinConstraint.fromJson(readJson(target.constraintAsset), target),
    );

TraffickingTrack topologyOf(ProteinTarget target) => _topologies.putIfAbsent(
  target.slug,
  () => TraffickingTrack.fromJson(readJson(traffickingAsset(target)), target),
);

/// [target]'s route as the scene derives it: from its records alone, or with
/// the trafficking track's topology as well.
TraffickingRoute routeOf(ProteinTarget target, {bool topology = true}) =>
    TraffickingRoute.derive(
      RouteEvidence.of(
        constraintOf(target),
        transmembrane: topology ? topologyOf(target).transmembrane : null,
      ),
    );

/// [target], with its row saying [state] for the trafficking track.
ProteinTarget withTrafficking(
  ProteinTarget target,
  TrackState state, {
  String? reason,
  bool scored = true,
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
    TrackKind.trafficking: TrackRef(state: state, reason: reason),
    if (!scored) TrackKind.constraint: const TrackRef(state: TrackState.absent),
  },
);

/// The two tracks the scene reads, from the fixtures, and nothing else.
final class SceneTrackSource implements TrackSource {
  SceneTrackSource({this.failing = const <TrackKind>{}});

  /// Kinds whose read fails, as a ready track that could not be fetched.
  final Set<TrackKind> failing;

  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    if (failing.contains(kind)) {
      throw const SocketException('offline');
    }
    final ProteinTarget target = TestCatalog.bySlug(slug)!;
    return switch (kind) {
      TrackKind.constraint => File(target.constraintAsset).readAsBytes(),
      TrackKind.trafficking => File(traffickingAsset(target)).readAsBytes(),
      _ => throw StateError('the scene does not read $kind'),
    };
  }
}

/// Words that would say where a protein is made or found: a tissue, an organ,
/// a cell type, or a measurement of expression.
final RegExp tissueWords = RegExp(
  r'pancrea|islet|beta cell|intestin|colon|liver|hepat|kidney|renal|brain|'
  r'neuron|nerve|hypothalam|pituitar|muscle|cardiac|blood|erythrocyte|saliva|'
  r'adipo|tissue|expressed|expression|found in|made in the|secreted by|'
  r'\b(gut|fat|tears?|heart|organs?|milk|skin|bone)\b',
  caseSensitive: false,
);

/// Whether [text] names a protein of the catalog: its display name, or its
/// gene symbol as a word (except a symbol that is itself a codon).
bool namesAProtein(String text) {
  for (final ProteinTarget target in TestCatalog.all) {
    if (text.toLowerCase().contains(target.display.toLowerCase())) {
      return true;
    }
    final String gene = target.gene;
    if (!RegExp(r'^[ACGT]+$').hasMatch(gene) &&
        RegExp('\\b${RegExp.escape(gene)}\\b').hasMatch(text)) {
      return true;
    }
  }
  return false;
}
