import 'dart:io';
import 'dart:typed_data';

import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';

import 'test_catalog.dart';

final class FixtureTrackSource implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) =>
      File(TestCatalog.bySlug(slug)!.asset(kind)!).readAsBytes();
}
