import 'dart:io';
import 'dart:typed_data';

import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/features/lab/listen/domain/audio_track.dart';

import '../../../support/test_catalog.dart';

/// The twenty `audio` files `pipeline/audio/` baked, byte for byte, kept
/// beside these tests rather than in `test/fixtures/`, which belongs to the
/// walk.
String audioAsset(ProteinTarget target) =>
    'test/features/lab/listen/fixtures/${target.slug}.m4a';

Uint8List audioBytes(ProteinTarget target) =>
    File(audioAsset(target)).readAsBytesSync();

final Map<String, AudioTrack> _tracks = <String, AudioTrack>{};

AudioTrack audioOf(ProteinTarget target) => _tracks.putIfAbsent(
  target.slug,
  () => AudioTrack.fromM4a(audioBytes(target), target),
);

/// [target], with its row saying [state] for the audio track.
ProteinTarget withAudio(
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
    TrackKind.audio: TrackRef(state: state, reason: reason),
  },
);

/// The audio files, and the walk's own fixtures for everything else.
final class ListenTrackSource implements TrackSource {
  int audioReads = 0;

  @override
  Future<Uint8List> read(String slug, TrackKind kind) {
    final ProteinTarget target = TestCatalog.bySlug(slug)!;
    if (kind == TrackKind.audio) {
      audioReads++;
      return File(audioAsset(target)).readAsBytes();
    }
    return File(target.asset(kind)!).readAsBytes();
  }
}
