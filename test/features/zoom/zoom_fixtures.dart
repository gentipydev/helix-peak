import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';

import '../../support/test_catalog.dart';

/// The twenty `locus` payloads `pipeline/locus/` baked, kept beside these
/// tests rather than in `test/fixtures/`, which belongs to the walk.
String locusAsset(ProteinTarget target) =>
    'test/features/zoom/fixtures/${target.slug}_locus.json';

Map<String, dynamic> locusJson(ProteinTarget target) =>
    jsonDecode(File(locusAsset(target)).readAsStringSync())
        as Map<String, dynamic>;

final Map<String, LocusTrack> _tracks = <String, LocusTrack>{};

LocusTrack locusOf(ProteinTarget target) => _tracks.putIfAbsent(
  target.slug,
  () => LocusTrack.fromJson(locusJson(target), target),
);

/// [target], with its row saying [state] for the locus track.
ProteinTarget withLocus(
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
    TrackKind.locus: TrackRef(state: state, reason: reason),
  },
);

/// The locus payloads, and the walk's own fixtures for everything else.
final class ZoomTrackSource implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) {
    final ProteinTarget target = TestCatalog.bySlug(slug)!;
    return switch (kind) {
      TrackKind.locus => File(locusAsset(target)).readAsBytes(),
      _ => File(target.asset(kind)!).readAsBytes(),
    };
  }
}
