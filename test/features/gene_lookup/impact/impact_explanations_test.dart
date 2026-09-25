import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/impact_explanations.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';

import '../../../support/test_catalog.dart';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final insulin = TestCatalog.insulin;
  final track = GeneImpact.fromJson(readJson(insulin.impactAsset), insulin);
  Map<String, dynamic> fixture() => readJson(insulin.impactExplanationsAsset);
  final request = ImpactExplanationRequest.forAllele(track, 5294, 'C', 'A')!;

  test(
    'every bundled pilot alternative is exact and has a valid attribution',
    () {
      final pilot = TestCatalog.all.where(
        (t) => t.impactExplanationsAvailable,
      );
      expect(pilot.map((t) => t.gene), unorderedEquals(['INS', 'HBB', 'CFTR']));
      int count = 0;
      for (final ProteinTarget target in pilot) {
        final impact = GeneImpact.fromJson(
          readJson(target.impactAsset),
          target,
        );
        final data = GeneImpactExplanations.fromJson(
          readJson(target.impactExplanationsAsset),
          impact,
        );
        for (
          int p = impact.start;
          p < impact.start + impact.sequence.length;
          p++
        ) {
          final base = impact.at(p)!;
          if (base.estimated) continue;
          for (final alt in base.ranked) {
            final r = ImpactExplanationRequest.forAllele(
              impact,
              p,
              base.wildtype,
              alt.base,
            )!;
            expect(data.at(r), isNotNull);
            count++;
          }
        }
      }
      expect(count, 81117);
    },
  );

  test('minus-strand display allele links to its genomic allele', () {
    final data = GeneImpactExplanations.fromJson(fixture(), track);
    expect(data.at(request)!.contributions.first.feature, 'CACTUS_241_WAY');
    expect(data.atlasUrl(request).queryParameters['q'], 'chr11:2160901:G>T');
  });

  test('compressed CFTR coordinate retains exact synonymous attribution', () {
    final target = TestCatalog.all.firstWhere((t) => t.gene == 'CFTR');
    final impact = GeneImpact.fromJson(readJson(target.impactAsset), target);
    final data = GeneImpactExplanations.fromJson(
      readJson(target.impactExplanationsAsset),
      impact,
    );
    final r = ImpactExplanationRequest.forAllele(impact, 32923, 'G', 'A')!;
    expect(data.at(r)!.contributions.first.feature, 'MERGED_SPLICING');
    expect(data.atlasUrl(r).queryParameters['q'], 'chr7:117595058:G>A');
  });

  test('reference, wrong reference, missing positions and unbaked genes have no request', () {
    expect(ImpactExplanationRequest.forAllele(track, 5294, 'C', 'C'), isNull);
    expect(ImpactExplanationRequest.forAllele(track, 5294, 'G', 'A'), isNull);
    final json = readJson(insulin.impactAsset);
    (json['positions'] as Map<String, dynamic>).remove('5294');
    final gap = GeneImpact.fromJson(json, insulin);
    expect(gap.at(5294)!.estimated, isTrue);
    expect(ImpactExplanationRequest.forAllele(gap, 5294, 'C', 'A'), isNull);
    final target = TestCatalog.all.firstWhere((t) => t.gene == 'DMD');
    final dmd = GeneImpact.fromJson(readJson(target.impactAsset), target);
    final base = dmd.at(dmd.start)!;
    expect(
      ImpactExplanationRequest.forAllele(
        dmd,
        base.position,
        base.wildtype,
        base.ranked.first.base,
      ),
      isNull,
    );
  });

  test(
    'negative contribution survives and is described as lowering the score',
    () {
      final json = fixture();
      final rows =
          (json['positions'] as Map<String, dynamic>)['5294'] as List<dynamic>;
      final row = rows.first as List<dynamic>; // C>A in ACGT minus C order.
      row[1] = <dynamic>[
        <dynamic>[0, -0.75],
        <dynamic>[1, 0.25],
      ];
      final data = GeneImpactExplanations.fromJson(json, track);
      expect(data.at(request)!.contributions.first.value, -0.75);
      expect(data.at(request)!.summary, contains('lowering'));
    },
  );

  for (final field in [
    'gene',
    'assembly',
    'transcript',
    'sequence',
    'scope',
    'units',
    'selection',
  ]) {
    test('rejects incompatible $field', () {
      final json = fixture()..[field] = 'incorrect';
      expect(
        () => GeneImpactExplanations.fromJson(json, track),
        throwsFormatException,
      );
    });
  }
  test('rejects shifted genomic map, incomplete coverage and stale scores', () {
    final shifted = fixture();
    ((shifted['runs'] as List<dynamic>).first
            as Map<String, dynamic>)['genomic'] =
        1;
    expect(
      () => GeneImpactExplanations.fromJson(shifted, track),
      throwsFormatException,
    );
    final missing = fixture();
    (missing['positions'] as Map<String, dynamic>).remove('5294');
    expect(
      () => GeneImpactExplanations.fromJson(missing, track),
      throwsFormatException,
    );
    final stale = fixture();
    (((stale['positions'] as Map<String, dynamic>)['5294'] as List<dynamic>)
                .first
            as List<dynamic>)[0] =
        0;
    expect(
      () => GeneImpactExplanations.fromJson(stale, track),
      throwsFormatException,
    );
  });
  test(
    'rejects invalid numbers, duplicate features and unsafe source URLs',
    () {
      for (final values in <List<dynamic>>[
        <dynamic>[
          <dynamic>[0, double.nan],
        ],
        <dynamic>[
          <dynamic>[0, 0.4],
          <dynamic>[0, 0.2],
        ],
        <dynamic>[
          <dynamic>[100, 0.4],
        ],
      ]) {
        final json = fixture();
        (((json['positions'] as Map<String, dynamic>)['5294'] as List<dynamic>)
                    .first
                as List<dynamic>)[1] =
            values;
        expect(
          () => GeneImpactExplanations.fromJson(json, track),
          throwsFormatException,
        );
      }
      final json = fixture()
        ..['atlas_url_template'] = 'https://example.org/?q={variant}';
      expect(
        () => GeneImpactExplanations.fromJson(json, track),
        throwsFormatException,
      );
    },
  );
}
