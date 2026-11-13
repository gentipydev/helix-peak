import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';

import '../../support/test_catalog.dart';

/// Proteins built on demand that take the zoom where no curated one does,
/// each as the backend makes it with nothing written live: its record from
/// the resolver's own build (`scripts/dry_resolve.py --out`), its row as the
/// service serves it, and its schema 3 `locus` track from the pinned
/// snapshot (`pipeline/locus/survey.py`, the index of 2026-11-13). Kept beside
/// the zoom's tests, never in `test/fixtures/`, which belongs to the walk.
abstract final class Coverage {
  /// Each protein, and what it brings that the curated do not.
  static const Map<String, String> why = <String, String>{
    'b2m': 'chromosome 15, built on demand',
    'mc4r': 'chromosome 18',
    'sry': 'Y, a male body',
    'miurf': 'the shortest gene offered, 213 bases, one exon',
    'h4c12': 'an intronless histone gene of 387 bases; lands in megakaryocytes',
    'cntnap2': 'the longest gene offered, 2.3 million bases, longer than DMD',
    'cacnb2': 'a gene across three bands',
    'polr2a': 'a gene MANE puts on a fix patch, placed on chromosome 17',
    'p2ry8': 'a pseudoautosomal gene, drawn on X',
    'bbs9': 'sperm-tail words a lactotroph does not have, left out',
    'tekt4': 'the longest plate a cell has, a spermatid: two lines',
    'xpo1': 'an organ and a cell chosen by level (rule v3)',
  };

  static const String folder = 'test/features/zoom/fixtures/coverage';

  static bool holds(String slug) => why.containsKey(slug);

  static String locusAsset(String slug) => '$folder/${slug}_locus.json';

  static String recordAsset(String slug) => '$folder/${slug}_record.json';

  static final Map<String, ProteinTarget> _targets = <String, ProteinTarget>{};

  /// [slug]'s row as the service serves it, its record and its `locus`
  /// track ready.
  static ProteinTarget target(String slug) => _targets.putIfAbsent(slug, () {
    final Map<String, dynamic> row = jsonDecode(
      File('$folder/${slug}_row.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return ProteinTarget.fromJson(<String, dynamic>{
      ...row,
      'tracks': <String, String>{'record': 'ready', 'locus': 'ready'},
    });
  });

  static List<ProteinTarget> get all => <ProteinTarget>[
    for (final String slug in why.keys) target(slug),
  ];

  /// The bytes of [slug]'s [kind]: its record or its locus.
  static File file(String slug, TrackKind kind) => File(switch (kind) {
    TrackKind.locus => locusAsset(slug),
    TrackKind.record => recordAsset(slug),
    _ => throw ArgumentError('$slug has no $kind fixture'),
  });
}

/// The curated, and the proteins built on demand the coverage set adds: every
/// protein the zoom's tests walk.
List<ProteinTarget> get zoomProteins => <ProteinTarget>[
  ...TestCatalog.all,
  ...Coverage.all,
];

/// [slug]'s row, curated or built on demand.
ProteinTarget zoomTarget(String slug) =>
    Coverage.holds(slug) ? Coverage.target(slug) : TestCatalog.bySlug(slug)!;
