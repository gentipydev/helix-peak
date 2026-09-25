import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';

import '../../../support/test_catalog.dart';

Map<String, dynamic> _asset([ProteinTarget? target]) =>
    jsonDecode(
          File((target ?? TestCatalog.insulin).impactAsset).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// A track with holes in it, to exercise the borrowing path that a complete
/// track never reaches.
Map<String, dynamic> _sparse() {
  final Map<String, dynamic> json = _asset();
  final Map<String, dynamic> positions =
      json['positions'] as Map<String, dynamic>;
  final int start = (json['start'] as num).toInt();
  json['positions'] = <String, dynamic>{
    for (final MapEntry<String, dynamic> e in positions.entries)
      if ((int.parse(e.key) - start) % 10 == 0) e.key: e.value,
  };
  return json;
}

void main() {
  group('the bundled track', () {
    late GeneImpact impact;

    setUpAll(() {
      impact = GeneImpact.fromJson(_asset(), TestCatalog.insulin);
    });

    test('covers every drawn base of the gene record', () {
      expect(impact.sequence.length, 1431);
      expect(impact.length, impact.sequence.length);
      expect(impact.chromosome, 'chr11');
      expect(impact.orientation, -1);
      expect(impact.complemented, isTrue);
    });

    test('each base ranks its three substitutions, best first', () {
      for (int local = impact.start;
          local < impact.start + impact.sequence.length;
          local++) {
        final BaseImpact reading = impact.at(local)!;
        expect(reading.estimated, isFalse, reason: '$local');
        expect(reading.ranked.length, 3);
        expect(
          reading.ranked.map((AltScore s) => s.base).contains(reading.wildtype),
          isFalse,
          reason: 'the reference base is not one of its own substitutions',
        );
        for (int i = 1; i < 3; i++) {
          expect(
            reading.ranked[i].phred,
            lessThanOrEqualTo(reading.ranked[i - 1].phred),
            reason: '$local',
          );
        }
        expect(reading.peak, reading.ranked.first.phred);
      }
    });

    test('the coordinate map round-trips to GRCh38', () {
      // INS is reverse-complemented against chr11, so the record counts up as
      // the chromosome counts down: genomic = 2,166,195 - local throughout.
      expect(impact.genomicOf(impact.start), 2161209);
      expect(impact.genomicOf(6416), 2159779);
      for (int local = impact.start;
          local < impact.start + impact.sequence.length;
          local++) {
        expect(impact.genomicOf(local), 2166195 - local, reason: '$local');
      }
      expect(impact.genomicOf(impact.start - 1), isNull);
      expect(impact.genomicOf(impact.start + impact.sequence.length), isNull);
    });

    test('a position outside the record answers with nothing', () {
      expect(impact.at(impact.start - 1), isNull);
      expect(impact.at(impact.start + impact.sequence.length), isNull);
    });

    test('exons and splice boundaries outscore intron interiors', () {
      // The claim the feature is for, checked on the shipped asset rather than
      // on the bake's own report of it.
      double median(Iterable<int> locals) {
        final List<double> values =
            locals.map((int l) => impact.at(l)!.peak).toList()..sort();
        return values[values.length ~/ 2];
      }

      // INS exon 2 and the interior of intron 2, in record coordinates.
      final double exon = median(List<int>.generate(204, (int i) => 5207 + i));
      final double interior =
          median(List<int>.generate(760, (int i) => 5425 + i));
      final double splice = median(<int>[
        for (int i = 0; i < 6; i++) ...<int>[5411 + i, 6192 + i],
      ]);
      expect(exon, greaterThan(interior));
      expect(splice, greaterThan(interior));
      expect(interior, lessThan(GeneImpact.middlePhred));
    });
  });

  group('buckets', () {
    BaseImpact at(double peak) => BaseImpact(
      position: 1,
      genomic: 1,
      wildtype: 'A',
      ranked: <AltScore>[AltScore('C', peak), const AltScore('G', 0)],
    );

    test('are the Atlas’s own calibration, at the boundary', () {
      expect(at(20).level, ImpactLevel.high);
      expect(at(19.9).level, ImpactLevel.middle);
      expect(at(10).level, ImpactLevel.middle);
      expect(at(9.9).level, ImpactLevel.low);
      expect(at(0).level, ImpactLevel.low);
    });

    test('the bar fills against a fixed forty-Phred scale', () {
      expect(const AltScore('C', 0).barFraction, 0);
      expect(const AltScore('C', 20).barFraction, 0.5);
      expect(const AltScore('C', 40).barFraction, 1);
      expect(const AltScore('C', 60).barFraction, 1, reason: 'saturates');
    });

    test('the top percentile follows the Phred it came from', () {
      expect(at(10).topPercentile, closeTo(10, 1e-6));
      expect(at(20).topPercentile, closeTo(1, 1e-6));
      expect(at(30).topPercentile, closeTo(0.1, 1e-6));
    });
  });

  group('a gap in the track', () {
    late GeneImpact sparse;

    setUpAll(() {
      sparse = GeneImpact.fromJson(_sparse(), TestCatalog.insulin);
    });

    test('borrows the nearest scored base and says so', () {
      final BaseImpact exact = sparse.at(sparse.start)!;
      expect(exact.estimated, isFalse);
      expect(exact.distance, 0);

      final BaseImpact borrowed = sparse.at(sparse.start + 3)!;
      expect(borrowed.estimated, isTrue);
      expect(borrowed.estimatedFrom, sparse.start);
      expect(borrowed.distance, 3);
      // Still this base's own letter and its own coordinate: only the scores
      // came from somewhere else.
      expect(borrowed.wildtype, sparse.sequence[3]);
      expect(borrowed.genomic, sparse.genomicOf(sparse.start + 3));
    });

    test('a tie goes to the earlier base, from either side', () {
      final BaseImpact midpoint = sparse.at(sparse.start + 5)!;
      expect(midpoint.estimatedFrom, sparse.start);
      expect(midpoint.distance, 5);
    });

    test('borrowed scores are read under the neighbour’s own base', () {
      final BaseImpact borrowed = sparse.at(sparse.start + 3)!;
      final String lender = sparse.sequence[0];
      expect(
        borrowed.ranked.map((AltScore s) => s.base).contains(lender),
        isFalse,
      );
      expect(borrowed.ranked.length, 3);
    });
  });

  group('a track it cannot vouch for', () {
    test('is refused when the header disagrees', () {
      for (final String key in <String>[
        'gene',
        'uniprot',
        'accession',
        'assembly',
        'annotation',
        'scorer',
        'score_units',
        'alt_order',
      ]) {
        final Map<String, dynamic> json = _asset()..[key] = 'something else';
        expect(
          () => GeneImpact.fromJson(json, TestCatalog.insulin),
          throwsFormatException,
          reason: key,
        );
      }
    });

    test('is refused when a retuned bucket would be half-applied', () {
      final Map<String, dynamic> json = _asset()..['high_phred'] = 25;
      expect(
        () => GeneImpact.fromJson(json, TestCatalog.insulin),
        throwsFormatException,
      );
    });

    test('is refused when it belongs to another gene', () {
      expect(
        () => GeneImpact.fromJson(_asset(), TestCatalog.hemoglobin),
        throwsFormatException,
      );
    });

    test('is refused when the coordinate map does not cover the record', () {
      final Map<String, dynamic> json = _asset();
      final List<dynamic> runs = json['runs'] as List<dynamic>;
      (runs.first as Map<String, dynamic>)['length'] = 12;
      expect(
        () => GeneImpact.fromJson(json, TestCatalog.insulin),
        throwsFormatException,
      );
    });

    test('is refused when a position is short of its three scores', () {
      final Map<String, dynamic> json = _asset();
      final Map<String, dynamic> positions =
          json['positions'] as Map<String, dynamic>;
      positions[positions.keys.first] = <double>[1, 2];
      expect(
        () => GeneImpact.fromJson(json, TestCatalog.insulin),
        throwsFormatException,
      );
    });

    test('is refused when a score sits outside the record', () {
      final Map<String, dynamic> json = _asset();
      (json['positions'] as Map<String, dynamic>)['999999'] = <double>[1, 2, 3];
      expect(
        () => GeneImpact.fromJson(json, TestCatalog.insulin),
        throwsFormatException,
      );
    });
  });

  test('every catalog entry has a track that loads and covers its record', () {
    for (final ProteinTarget target in TestCatalog.all) {
      if (!target.impactScored) {
        continue;
      }
      final GeneImpact impact = GeneImpact.fromJson(_asset(target), target);
      expect(impact.gene, target.gene, reason: target.slug);
      expect(impact.chromosome, startsWith('chr'), reason: target.slug);
      // A gene page is at most the budget; a track larger than that is scoring
      // something the page cannot show.
      expect(impact.sequence.length, lessThanOrEqualTo(24000), reason: target.slug);
      expect(
        impact.at(impact.start)!.ranked.length,
        3,
        reason: target.slug,
      );
      expect(
        impact.genomicOf(impact.start + impact.sequence.length - 1),
        isNotNull,
        reason: target.slug,
      );
    }
  });
}
