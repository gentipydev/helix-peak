import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/shared/anatomy/anatomy_address.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/format.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

final GeneImpact _track = GeneImpact.fromJson(
  jsonDecode(File(TestCatalog.insulin.impactAsset).readAsStringSync())
      as Map<String, dynamic>,
  TestCatalog.insulin,
);

void main() {
  final GeneRecord record = insulin();
  final AnatomyAddress address = AnatomyAddress.of(
    AnatomyModel.derive(record, chain: TestCatalog.insulin.chain),
  );
  final List<int> positions = <int>[
    for (int p = record.start; p <= record.end; p++) p,
  ];

  test('every base of insulin is in one part, counted as the page counts '
      'them', () {
    final Map<RoleKind?, int> counts = <RoleKind?, int>{};
    for (final int p in positions) {
      counts.update(address.partOf(p), (int n) => n + 1, ifAbsent: () => 1);
    }
    // 5′ UTR 59 · CDS 333 · 3′ UTR 73 nt, as the transcript's header says,
    // and the two introns' 179 and 787 bases.
    expect(counts, <RoleKind?, int>{
      RoleKind.utr5: 59,
      RoleKind.coding: 333,
      RoleKind.utr3: 73,
      RoleKind.intron: 966,
    });
    expect(address.partOf(5000), RoleKind.utr5);
    expect(address.partOf(5224), RoleKind.coding);
    expect(address.partOf(5410), RoleKind.coding);
    expect(address.partOf(5411), RoleKind.intron);
    expect(address.partOf(6380), RoleKind.utr3);
    expect(address.partOf(record.start - 1), isNull);
  });

  test('a rank is one more than the bases of its part that score higher', () {
    final ImpactRanking<RoleKind> ranking = _track.rankedBy(address.partOf);
    final Map<int, (RoleKind, double)> scored = <int, (RoleKind, double)>{
      for (final int p in positions)
        p: (address.partOf(p)!, _track.at(p)!.peak),
    };
    for (final MapEntry<int, (RoleKind, double)> base in scored.entries) {
      final (RoleKind part, double peak) = base.value;
      final int higher = scored.values
          .where(
            ((RoleKind, double) other) => other.$1 == part && other.$2 > peak,
          )
          .length;
      final int total = scored.values
          .where(((RoleKind, double) other) => other.$1 == part)
          .length;
      expect(ranking.of(peak, part), (
        rank: higher + 1,
        total: total,
      ), reason: '${base.key}');
    }
  });

  test('bases that score alike share a rank', () {
    final ImpactRanking<RoleKind> ranking = _track.rankedBy(address.partOf);
    // Every substitution at this 5′ UTR base scores 0.1, as do others there.
    final double peak = _track.at(5000)!.peak;
    final List<int> alike = <int>[
      for (final int p in positions)
        if (address.partOf(p) == RoleKind.utr5 && _track.at(p)!.peak == peak) p,
    ];
    expect(alike.length, greaterThan(1));
    expect(ranking.of(peak, RoleKind.utr5)!.rank, 55);
  });

  test('a base its parts leave out is in no count, and an empty part has no '
      'rank', () {
    final ImpactRanking<String> ranking = _track.rankedBy<String>(
      (int p) => p < 5224 ? null : 'from the start codon',
    );
    expect(
      ranking.of(0, 'from the start codon')!.total,
      positions.where((int p) => p >= 5224).length,
    );
    expect(ranking.of(0, 'before it'), isNull);
  });

  test('the scale\'s marks read as the genome\'s shares, a tenfold step '
      'each', () {
    expect(genomeShare(10), '10%');
    expect(genomeShare(20), '1%');
    expect(genomeShare(30), '0.1%');
    expect(genomeShare(40), '0.01%');
  });
}
