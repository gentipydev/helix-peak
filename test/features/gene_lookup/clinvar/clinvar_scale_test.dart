import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/variant_evidence.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_row.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_sections.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/variants_overview.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Dystrophin, the catalog's largest snapshot: thousands of records over a
/// gene whose introns are drawn shortened.
void main() {
  const ProteinTarget dmd = ProteinCatalog.dystrophin;
  late final GeneRecord record = GeneRecordDto.fromJson(
    _json(dmd.mockAsset),
  ).toEntity();
  late final AnatomyModel model = AnatomyModel.derive(record, chain: dmd.chain);
  late final GeneClinVar snapshot = GeneClinVar.fromJson(
    _json(dmd.clinvarAsset),
    dmd,
  );
  late final ProteinConstraint constraint = ProteinConstraint.fromJson(
    _json(dmd.constraintAsset),
    dmd,
  );
  late final List<VariantEvidence> evidence = VariantEvidence.build(
    snapshot,
    impact: GeneImpact.fromJson(_json(dmd.impactAsset), dmd),
    constraint: constraint,
    nonCoding: nonCodingSections(model),
  );
  late final List<(int, int)> exons = <(int, int)>[
    for (final Exon exon in record.exons) (exon.start, exon.end),
  ];

  Future<void> overview(
    WidgetTester tester, {
    List<String> focus = const <String>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: VariantsOverview(
          snapshot: snapshot,
          evidence: evidence,
          constraint: constraint,
          exons: exons,
          runs: geneRuns(model),
          focus: focus,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('thousands of records build only the rows near the screen', (
    tester,
  ) async {
    await overview(tester);
    expect(evidence.length, greaterThan(5000));
    // A heading for every region, each with the first of its rows; the rest
    // are built as they come on screen.
    final int built = find
        .byType(EvidenceRow, skipOffstage: false)
        .evaluate()
        .length;
    expect(built, lessThan(evidence.length ~/ 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a record far down the list is scrolled to and opened', (
    tester,
  ) async {
    // The protein's last record, below thousands of rows that are not built.
    final VariantEvidence deep = evidence
        .where((VariantEvidence e) => e.variant.residue != null)
        .reduce(
          (VariantEvidence a, VariantEvidence b) =>
              a.variant.residue! >= b.variant.residue! ? a : b,
        );
    await overview(tester, focus: <String>[deep.variant.id]);
    final Finder detail = find.byKey(
      ValueKey<String>('evidence-detail-${deep.variant.id}'),
    );
    expect(detail, findsOneWidget);
    expect(tester.getRect(detail).top, inInclusiveRange(0, 844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a shortened intron is titled by its own length', (
    tester,
  ) async {
    final GeneRun largest = geneRuns(model)
        .where((GeneRun r) => r.label.startsWith('Intron'))
        .reduce((GeneRun a, GeneRun b) => a.lengthBp >= b.lengthBp ? a : b);
    // The gene page's own figure for it, and far more than the page draws.
    expect(largest.lengthBp, 248401);
    expect(largest.end - largest.start + 1, lessThan(1000));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EvidenceStrip(
              evidence: evidence,
              proteinLength: snapshot.proteinSequence.length,
              geneStart: snapshot.start,
              geneEnd: snapshot.start + snapshot.sequence.length - 1,
              exons: exons,
              runs: geneRuns(model),
              constraint: constraint,
              dnaZoom: EvidenceStrip.runKey(largest),
              onSelected: (_) {},
              onZoom: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('DNA · ${largest.label} · 248,401 bp'), findsOneWidget);
  });
}
