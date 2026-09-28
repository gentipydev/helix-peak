import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/core/catalog/protein_target.dart';
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

FoldGeometry geometryOf(ProteinTarget target) => _geometries.putIfAbsent(
  target.slug,
  () => FoldGeometry.of(foldingOf(target)),
);

ProteinTarget target(String slug) => TestCatalog.bySlug(slug)!;
