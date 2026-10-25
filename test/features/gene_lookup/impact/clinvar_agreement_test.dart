import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/clinvar_agreement.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/gene_agreement.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/clinvar/evidence_sections.dart';

import '../../../support/test_catalog.dart';

/// Where a gene's ClinVar missense records stand on both models' scales. The
/// pinned numbers were read off the same fixtures by a script apart from the
/// app, which joins each record to AVI's Phred for its own allele and ESM-2's
/// score for its own amino acid. The app holds a Phred to single precision,
/// so the two agree to a millionth.

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// One gene's tracks, read as the walk reads them.
final class _Gene {
  factory _Gene(ProteinTarget target) {
    final AnatomyModel model = AnatomyModel.derive(
      GeneRecordDto.fromJson(_json(target.mockAsset)).toEntity(),
      chain: target.chain,
    );
    final GeneImpact impact = GeneImpact.fromJson(
      _json(target.impactAsset),
      target,
    );
    final ProteinConstraint constraint = ProteinConstraint.fromJson(
      _json(target.constraintAsset),
      target,
    );
    return _Gene._(
      GeneAgreement.of(model: model, impact: impact, constraint: constraint)!,
      VariantEvidence.build(
        GeneClinVar.fromJson(_json(target.clinvarAsset), target),
        impact: impact,
        constraint: constraint,
        nonCoding: nonCodingSections(model),
      ),
    );
  }

  _Gene._(this.agreement, this.evidence);

  final GeneAgreement agreement;
  final List<VariantEvidence> evidence;

  ClinVarAgreement get placed =>
      ClinVarAgreement.of(agreement: agreement, evidence: evidence)!;

  /// The records the page can place: missense, both models scoring them.
  List<VariantEvidence> get scored => <VariantEvidence>[
    for (final VariantEvidence e in evidence)
      if (e.variant.consequence == 'missense' && e.avi != null && e.esm != null)
        e,
  ];
}

void _expectClasses(
  ClinVarAgreement placed,
  List<(ClinVarGroup, int, double, double)> expected,
) {
  expect(
    <ClinVarGroup>[for (final ClinVarClass c in placed.classes) c.group],
    <ClinVarGroup>[for (final (ClinVarGroup g, _, _, _) in expected) g],
  );
  for (final (int i, (ClinVarGroup, int, double, double) row)
      in expected.indexed) {
    final ClinVarClass c = placed.classes[i];
    expect(c.records, row.$2, reason: row.$1.short);
    expect(c.phred, closeTo(row.$3, 1e-6), reason: row.$1.short);
    expect(c.esm, closeTo(row.$4, 1e-6), reason: row.$1.short);
  }
}

void main() {
  test('insulin: 89 records on 89 changes, P/LP 31, conflicting 11, VUS 39, '
      'other 8, and no B/LB', () {
    final _Gene gene = _Gene(TestCatalog.insulin);
    final ClinVarAgreement placed = gene.placed;
    expect(placed.records, 89);
    expect(placed.marks, hasLength(89));
    _expectClasses(placed, <(ClinVarGroup, int, double, double)>[
      (ClinVarGroup.pathogenic, 31, 26.9, -8.639),
      (ClinVarGroup.conflicting, 11, 22.1, -5.869),
      (ClinVarGroup.uncertain, 39, 21.3, -5.612),
      (ClinVarGroup.other, 8, 29.55, -8.588),
    ]);
    // The gene's every missense substitution, which the classes are read
    // against.
    expect(gene.agreement.count, 687);
    expect(gene.agreement.medianPhred, closeTo(22.3, 1e-6));
    expect(gene.agreement.medianEsm, closeTo(-3.923, 1e-6));
  });

  test('every mark is one of the gene\'s changes, in the most severe class '
      'of its records', () {
    final _Gene gene = _Gene(TestCatalog.insulin);
    final Map<(int, String), List<VariantEvidence>> byChange =
        <(int, String), List<VariantEvidence>>{};
    for (final VariantEvidence e in gene.scored) {
      (byChange[(e.variant.position, e.variant.alt)] ??= <VariantEvidence>[])
          .add(e);
    }
    final ClinVarAgreement placed = gene.placed;
    expect(placed.marks, hasLength(byChange.length));
    for (final ClinVarMarked mark in placed.marks) {
      final List<VariantEvidence> records =
          byChange[(mark.change.position, mark.change.alt)]!;
      expect(gene.agreement.changes, contains(same(mark.change)));
      expect(
        mark.group,
        ClinVarGroup.mostSevere(
          records.map((VariantEvidence e) => e.variant.group),
        ),
      );
      for (final VariantEvidence e in records) {
        expect(mark.change.phred, e.avi);
        expect(mark.change.esm, e.esm!.score);
      }
    }
    // c.268's Cys, the record the sheet shows at Gly90.
    final ClinVarMarked g90c = placed.marks.firstWhere(
      (ClinVarMarked m) => m.change.position == 6278 && m.change.alt == 'T',
    );
    expect(g90c.group, ClinVarGroup.uncertain);
    expect(g90c.change.phred, closeTo(31.2, 1e-6));
    expect(g90c.change.esm, closeTo(-10.367, 1e-6));
  });

  test('p53: benign records placed with the rest, in the order a reader '
      'scans the classes', () {
    final ClinVarAgreement placed = _Gene(TestCatalog.p53).placed;
    expect(placed.records, 1433);
    _expectClasses(placed, <(ClinVarGroup, int, double, double)>[
      (ClinVarGroup.pathogenic, 242, 28.1, -6.3955),
      (ClinVarGroup.conflicting, 451, 23.2, -2.0),
      (ClinVarGroup.uncertain, 581, 22.7, -1.502),
      (ClinVarGroup.benign, 158, 16.5, -0.696),
      (ClinVarGroup.other, 1, 5.7, 0.525),
    ]);
  });

  test('a minus-strand record: glucagon\'s three', () {
    final ClinVarAgreement placed = _Gene(TestCatalog.glucagon).placed;
    expect(placed.records, 3);
    expect(placed.marks, hasLength(3));
    _expectClasses(placed, <(ClinVarGroup, int, double, double)>[
      (ClinVarGroup.uncertain, 2, 15.7, -0.0555),
      (ClinVarGroup.benign, 1, 7.7, 0.09),
    ]);
  });

  test('none placed is no table at all', () {
    final _Gene gene = _Gene(TestCatalog.insulin);
    expect(
      ClinVarAgreement.of(
        agreement: gene.agreement,
        evidence: <VariantEvidence>[
          for (final VariantEvidence e in gene.evidence)
            if (e.variant.consequence != 'missense') e,
        ],
      ),
      isNull,
    );
  });

  test('worked out once per list of records, again for another agreement', () {
    final _Gene gene = _Gene(TestCatalog.insulin);
    final ClinVarAgreement first = gene.placed;
    expect(gene.placed, same(first));
    final ClinVarAgreement again = ClinVarAgreement.of(
      agreement: _Gene(TestCatalog.insulin).agreement,
      evidence: gene.evidence,
    )!;
    expect(again, isNot(same(first)));
    expect(again.records, first.records);
  });

  test('every scored curated protein: each missense record both models score '
      'is placed, once', () {
    int proteins = 0;
    for (final ProteinTarget target in TestCatalog.all) {
      if (!File(target.constraintAsset).existsSync() ||
          !File(target.clinvarAsset).existsSync()) {
        continue;
      }
      proteins++;
      final _Gene gene = _Gene(target);
      final List<VariantEvidence> scored = gene.scored;
      final ClinVarAgreement? placed = ClinVarAgreement.of(
        agreement: gene.agreement,
        evidence: gene.evidence,
      );
      if (scored.isEmpty) {
        expect(placed, isNull, reason: target.slug);
        continue;
      }
      expect(placed!.records, scored.length, reason: target.slug);
      expect(
        placed.classes.fold<int>(0, (int n, ClinVarClass c) => n + c.records),
        scored.length,
        reason: target.slug,
      );
      expect(
        placed.marks,
        hasLength(
          <(int, String)>{
            for (final VariantEvidence e in scored)
              (e.variant.position, e.variant.alt),
          }.length,
        ),
        reason: target.slug,
      );
    }
    expect(proteins, greaterThanOrEqualTo(37));
  });
}
