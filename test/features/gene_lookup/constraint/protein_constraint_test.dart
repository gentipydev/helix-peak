import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_target.dart';

Map<String, dynamic> _asset() =>
    jsonDecode(File(ProteinCatalog.insulin.constraintAsset).readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('bundled scores pass the precursor and six-cysteine gate', () {
    final ProteinConstraint data = ProteinConstraint.fromJson(_asset(), ProteinCatalog.insulin);
    expect(File(ProteinCatalog.insulin.constraintAsset).lengthSync(), lessThan(100000));
    expect(data.positions.length, 110);
    final List<ResidueConstraint> ranked = data.positions.toList()
      ..sort(
        (ResidueConstraint a, ResidueConstraint b) =>
            b.conservation.compareTo(a.conservation),
      );
    expect(
      ranked.take(6).map((ResidueConstraint p) => p.index + 1).toSet(),
      <int>{31, 43, 95, 96, 100, 109},
    );
    for (final ResidueConstraint p in data.positions) {
      expect(p.ranked.length, 20);
      expect(
        p.ranked
            .singleWhere((SubstitutionScore s) => s.aminoAcid == p.wildtype)
            .score,
        0,
      );
      for (int i = 1; i < 20; i++) {
        expect(p.ranked[i].score, lessThanOrEqualTo(p.ranked[i - 1].score));
      }
    }
  });

  test('bar scale keeps constrained and tolerant panels comparable', () {
    for (final (double, double) pair in <(double, double)>[
      (-15, 0),
      (-10, 0),
      (-5, 0.5),
      (-1, 0.9),
      (0, 1),
      (3, 1),
    ]) {
      expect(SubstitutionScore('A', pair.$1).barFraction, pair.$2);
    }
  });

  test('residues are cited by precursor number, then by chain', () {
    final ProteinConstraint data = ProteinConstraint.fromJson(_asset(), ProteinCatalog.insulin);
    // The precursor number leads everywhere; a released chain adds its own,
    // and nothing removed with a cut has one.
    for (final (int, String, int, String) expected
        in <(int, String, int, String)>[
          (24, 'Signal peptide', 24, 'Ala24'),
          (25, 'B chain', 1, 'Phe25 · B1'),
          (54, 'B chain', 30, 'Thr54 · B30'),
          (55, 'B / C cleavage site', 55, 'Arg55'),
          (56, 'B / C cleavage site', 56, 'Arg56'),
          (57, 'C-peptide', 57, 'Glu57'),
          (87, 'C-peptide', 87, 'Gln87'),
          (88, 'C / A cleavage site', 88, 'Lys88'),
          (89, 'C / A cleavage site', 89, 'Arg89'),
          (90, 'A chain', 1, 'Gly90 · A1'),
          (110, 'A chain', 21, 'Asn110 · A21'),
        ]) {
      final ResidueConstraint p = data.positions[expected.$1 - 1];
      expect(
        (p.domain, p.domainPosition, p.title),
        (expected.$2, expected.$3, expected.$4),
      );
    }
    expect(
      <int, String?>{
        for (final int n in <int>[31, 43, 95, 96, 100, 109])
          n: data.positions[n - 1].bondPartner,
      },
      <int, String>{
        31: 'Cys96 (A7)',
        43: 'Cys109 (A20)',
        95: 'Cys100 (A11)',
        96: 'Cys31 (B7)',
        100: 'Cys95 (A6)',
        109: 'Cys43 (B19)',
      },
    );
    // The six cysteines rank first, and a rank is a place in the whole protein.
    expect(
      <int>{for (final int n in <int>[31, 43, 95, 96, 100, 109]) data.positions[n - 1].rank},
      <int>{1, 2, 3, 4, 5, 6},
    );
    expect(data.positions[94].note, contains('closing a loop within the A chain'));
    // Names both ends rather than counting them. The wording generalised when
    // the catalog did: 'the two mature chains' is only true of a precursor cut
    // into exactly two, and relaxin's bridges say 'link the B chain to the A
    // chain' off the same sentence.
    expect(data.positions[30].note, contains('link the B chain to the A chain'));
  });

  test('notes follow measured constraint and distinguish C-peptide', () {
    final ProteinConstraint data = ProteinConstraint.fromJson(_asset(), ProteinCatalog.insulin);
    final ResidueConstraint high = data.positions[30];
    final ResidueConstraint middle = data.positions.firstWhere(
      (ResidueConstraint p) => p.level == ConstraintLevel.middle,
    );
    final ResidueConstraint low = data.positions[70];
    expect(high.level, ConstraintLevel.high);
    expect(low.level, ConstraintLevel.low);
    expect(<String>{high.note, middle.note, low.note}.length, 3);
    expect(low.note, contains('C-peptide'));
  });

  test('rejects shifted, incomplete, or incompatible positional data', () {
    for (final void Function(Map<String, dynamic>) corrupt
        in <void Function(Map<String, dynamic>)>[
          (Map<String, dynamic> j) => j['sequence'] = 'M',
          (Map<String, dynamic> j) => j['method'] = 'wt_marginals',
          (Map<String, dynamic> j) =>
              (j['positions'] as List<dynamic>).removeLast(),
          (Map<String, dynamic> j) =>
              ((j['positions'] as List<dynamic>)[0]
                      as Map<String, dynamic>)['index'] =
                  1,
        ]) {
      final Map<String, dynamic> json = _asset();
      corrupt(json);
      expect(() => ProteinConstraint.fromJson(json, ProteinCatalog.insulin), throwsFormatException);
    }
  });

  group('citation follows the field for every protein', () {
    ProteinConstraint track(ProteinTarget target) => ProteinConstraint.fromJson(
      jsonDecode(File(target.constraintAsset).readAsStringSync())
          as Map<String, dynamic>,
      target,
    );

    test('the residues a reader looks for read the way they are cited', () {
      for (final (ProteinTarget, int, String) expected
          in <(ProteinTarget, int, String)>[
            // One chain after a leader: the precursor number, then the mature.
            (ProteinCatalog.prion, 179, 'Cys179 · mature 157'),
            (ProteinCatalog.sod1, 5, 'Ala5 · mature 4'),
            (ProteinCatalog.hemoglobin, 7, 'Glu7 · mature 6'),
            (ProteinCatalog.myoglobin, 65, 'His65 · mature 64'),
            // A domain is not a numbering of its own.
            (ProteinCatalog.p53, 175, 'Arg175'),
            (ProteinCatalog.p53, 248, 'Arg248'),
            (ProteinCatalog.dystrophin, 15, 'Asp15'),
            (ProteinCatalog.cftr, 508, 'Phe508'),
            // A precursor cut into pieces numbers each piece.
            (ProteinCatalog.ubiquitin, 124, 'Lys124 · U2 48'),
            (ProteinCatalog.insulin, 96, 'Cys96 · A7'),
          ]) {
        expect(
          track(expected.$1).positions[expected.$2 - 1].title,
          expected.$3,
          reason: expected.$1.slug,
        );
      }
      expect(
        track(ProteinCatalog.prion).positions[178].bondPartner,
        'Cys214 (mature 192)',
      );
    });

    test('every disulfide names its partner by precursor number', () {
      for (final ProteinTarget target in ProteinCatalog.all) {
        final Map<String, dynamic> json =
            jsonDecode(File(target.constraintAsset).readAsStringSync())
                as Map<String, dynamic>;
        final ProteinConstraint data = track(target);
        for (final dynamic pair in json['disulfides'] as List<dynamic>) {
          final int a = (pair as List<dynamic>)[0] as int;
          final int b = pair[1] as int;
          expect(data.positions[a - 1].bondPartner, startsWith('Cys$b'), reason: target.slug);
          expect(data.positions[b - 1].bondPartner, startsWith('Cys$a'), reason: target.slug);
          expect(data.positions[a - 1].title, startsWith('Cys$a'), reason: target.slug);
        }
        final List<int> ranks = data.positions.map((ResidueConstraint p) => p.rank).toList()..sort();
        expect(ranks, List<int>.generate(ranks.length, (int i) => i + 1), reason: target.slug);
      }
    });
  });
}
