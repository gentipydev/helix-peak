import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/impact_explanations.dart';

import '../../../support/test_catalog.dart';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final insulin = TestCatalog.insulin;
  final track = GeneImpact.fromJson(readJson(insulin.impactAsset), insulin);
  Map<String, dynamic> fixture() => readJson(insulin.impactExplanationsAsset);
  final request = ImpactExplanationRequest.forAllele(track, 5294, 'C', 'A')!;

  test(
    'every insulin alternative is exact and has all 18 attributions',
    () {
      final pilot = TestCatalog.all.where(
        (t) => t.impactExplanationsAvailable,
      );
      expect(pilot.map((t) => t.gene), <String>['INS']);
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
            expect(data.at(r)!.values, hasLength(18));
            count++;
          }
        }
      }
      expect(count, 4293);
    },
  );

  test('minus-strand display allele links to its genomic allele', () {
    final data = GeneImpactExplanations.fromJson(fixture(), track);
    expect(data.at(request)!.contributions.first.feature, 'CACTUS_241_WAY');
    expect(data.atlasUrl(request).queryParameters['q'], 'chr11:2160901:G>T');
  });

  test('each substitution carries its raw score, groups and tracks', () {
    final data = GeneImpactExplanations.fromJson(fixture(), track);
    // c.73 T>C, chr11:2160899:A>G: Phe25Leu.
    final leu = data.at(
      ImpactExplanationRequest.forAllele(track, 5296, 'T', 'C')!,
    )!;
    expect(leu.phred, 25.1);
    expect(leu.raw, closeTo(1.128616, 1e-6));
    expect(leu.total(ContributionGroup.coding), closeTo(0.706, 0.0005));
    expect(leu.sum, closeTo(1.192, 0.0005));
    expect(leu.values['IS_INSERTION'], 0);
    final rna = leu.winners['MAX_ABS_RNA_SEQ']!;
    expect((rna.biosample, rna.gene), ('WTC11', 'INS'));
    expect(leu.winners['MERGED_SPLICING']!.scorer, 'SPLICE_JUNCTIONS');
    // Conservation, AlphaMissense and the flags name no track.
    expect(leu.winners.containsKey('ALPHAMISSENSE'), isFalse);
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
      row[2] = <dynamic>[-0.75, 0.25, for (int i = 2; i < 18; i++) 0];
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
    'rejects invalid numbers, short rows, unknown tracks and unsafe source URLs',
    () {
      List<dynamic> row(Map<String, dynamic> json) =>
          ((json['positions'] as Map<String, dynamic>)['5294'] as List<dynamic>)
                  .first
              as List<dynamic>;
      final int tracks = (fixture()['tracks'] as List<dynamic>).length;
      for (final void Function(List<dynamic>) spoil in <void Function(List<dynamic>)>[
        (r) => (r[2] as List<dynamic>)[0] = double.nan,
        (r) => (r[2] as List<dynamic>).removeLast(),
        (r) => r[1] = double.infinity,
        (r) => (r[3] as List<dynamic>).add(<dynamic>[0, tracks, 0.1]),
        (r) => (r[3] as List<dynamic>).add(<dynamic>[100, 0, 0.1]),
        (r) => (r[3] as List<dynamic>)
          ..add(<dynamic>[1, 0, 0.1])
          ..add(<dynamic>[1, 0, 0.2]),
      ]) {
        final json = fixture();
        spoil(row(json));
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
