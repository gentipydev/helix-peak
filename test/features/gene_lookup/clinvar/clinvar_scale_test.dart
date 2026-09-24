import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/variant_evidence.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/clinvar_block.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_row.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_sections.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';

import '../anatomy/anatomy_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The rows built while [action] runs: each row once, however often it is
/// built, so a row that is built and dropped again within one frame counts.
Future<int> _rowsBuilt(Future<void> Function() action) async {
  final Set<Element> built = Set<Element>.identity();
  debugOnRebuildDirtyWidget = (Element element, bool _) {
    if (element.widget is EvidenceRow) {
      built.add(element);
    }
  };
  try {
    await action();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return built.length;
}

/// A gene's overview as the walk draws it, from its own baked files.
VariantsOverview _overviewOf(ProteinTarget target) {
  final GeneRecord record = GeneRecordDto.fromJson(
    _json(target.mockAsset),
  ).toEntity();
  final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
  final GeneClinVar snapshot = GeneClinVar.fromJson(
    _json(target.clinvarAsset),
    target,
  );
  final ProteinConstraint? constraint = target.scored
      ? ProteinConstraint.fromJson(_json(target.constraintAsset), target)
      : null;
  return VariantsOverview(
    key: ValueKey<String>(target.slug),
    snapshot: snapshot,
    evidence: VariantEvidence.build(
      snapshot,
      impact: target.impactScored
          ? GeneImpact.fromJson(_json(target.impactAsset), target)
          : null,
      constraint: constraint,
      nonCoding: nonCodingSections(model),
    ),
    constraint: constraint?.sequence == snapshot.proteinSequence
        ? constraint
        : null,
    exons: <(int, int)>[
      for (final Exon exon in record.exons) (exon.start, exon.end),
    ],
    runs: geneRuns(model),
    reversed: record.strand == -1,
  );
}

Finder _header(String id) => find.byKey(ValueKey<String>('evidence-row-$id'));

/// Every closed row on screen is laid out exactly [EvidenceRow.closedExtent]
/// tall — its own content, not a slot forcing it.
void _expectOneHeight(WidgetTester tester) {
  final List<String> closed = <String>[
    for (final EvidenceRow row in tester.widgetList<EvidenceRow>(
      find.byType(EvidenceRow),
    ))
      if (!row.expanded) row.evidence.variant.id,
  ];
  expect(closed, isNotEmpty);
  for (final String id in closed) {
    expect(
      tester.getSize(_header(id)).height,
      EvidenceRow.closedExtent(tester.element(_header(id))),
      reason: id,
    );
  }
}

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

  // The app's own type, so what fits on a line here fits on a phone.
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> overview(
    WidgetTester tester, {
    List<String> focus = const <String>[],
    Size size = const Size(390, 844),
    double textScale = 1,
    bool motion = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: !motion,
          ),
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

  ScrollPosition listPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('variants-overview-scroll')),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  testWidgets('a jump down the list builds only the rows it lands on', (
    tester,
  ) async {
    await overview(tester);
    final ScrollPosition position = listPosition(tester);
    // A screenful of rows at each place, never the thousands between.
    for (final double at in <double>[0.25, 0.5, 0.75, 0.9]) {
      final int built = await _rowsBuilt(() async {
        position.jumpTo(position.maxScrollExtent * at);
        await tester.pump();
      });
      expect(built, inInclusiveRange(1, 60), reason: 'at $at');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling the page does not paint the strip again', (
    tester,
  ) async {
    await overview(tester);
    final ScrollPosition position = listPosition(tester);
    int painted = 0;
    debugOnProfilePaint = (RenderObject object) {
      if (object is RenderCustomPaint &&
          '${object.painter.runtimeType}' == '_StripPainter') {
        painted++;
      }
    };
    try {
      // A little at a time, so the strip stays on screen throughout.
      for (int step = 1; step <= 5; step++) {
        position.jumpTo(step * 30.0);
        await tester.pump();
      }
    } finally {
      debugOnProfilePaint = null;
    }
    expect(position.pixels, 150);
    expect(painted, 0);
  });

  testWidgets('dragging the thumb builds only the rows under it', (
    tester,
  ) async {
    await overview(tester);
    final Rect track = tester.getRect(
      find.byKey(const ValueKey<String>('sequence-scrubber')),
    );
    final TestGesture finger = await tester.startGesture(
      Offset(track.center.dx, track.top + 30),
    );
    int most = 0;
    for (int step = 0; step < 8; step++) {
      most = math.max(
        most,
        await _rowsBuilt(() async {
          await finger.moveBy(Offset(0, (track.height - 60) / 8));
          await tester.pump();
        }),
      );
    }
    await finger.up();
    await tester.pump();
    final ScrollPosition position = listPosition(tester);
    expect(position.pixels, greaterThan(position.maxScrollExtent * 0.8));
    expect(most, inInclusiveRange(1, 60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row closes in place while the next one opens', (
    tester,
  ) async {
    await overview(tester, motion: true);
    // Past the strip, to rows.
    final ScrollPosition position = listPosition(tester);
    position.jumpTo(position.maxScrollExtent * 0.3);
    await tester.pumpAndSettle();
    final List<String> ids = <String>[
      for (final EvidenceRow row in tester.widgetList<EvidenceRow>(
        find.byType(EvidenceRow),
      ))
        row.evidence.variant.id,
    ];
    expect(ids.length, greaterThanOrEqualTo(3));
    await tester.tap(_header(ids[0]));
    await tester.pumpAndSettle();
    // The open row at the top of the screen, the next two under its detail,
    // so the first is on screen for the whole of its closing.
    await tester.ensureVisible(_header(ids[0]));
    await tester.pumpAndSettle();
    // The next opens while the first is still closing, and a third before
    // either is done.
    await tester.tap(_header(ids[1]));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_header(ids[0]), findsOneWidget);
    await tester.tap(_header(ids[2]));
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final String id in ids.take(2)) {
      expect(
        find.byKey(ValueKey<String>('evidence-detail-$id')),
        findsNothing,
      );
      // Back among the closed rows, at their one height.
      expect(
        find.ancestor(
          of: _header(id),
          matching: find.byType(SliverToBoxAdapter),
        ),
        findsNothing,
        reason: id,
      );
    }
    expect(
      find.byKey(ValueKey<String>('evidence-detail-${ids[2]}')),
      findsOneWidget,
    );
    _expectOneHeight(tester);
  });

  // Not type at twice the size on the narrowest phone: there the row's
  // numbers alone are wider than the screen, whatever its height.
  for (final (Size size, double scale) in const <(Size, double)>[
    (Size(320, 640), 1),
    (Size(320, 640), 1.3),
    (Size(390, 844), 1),
    (Size(390, 844), 1.3),
    (Size(390, 844), 2),
  ]) {
    testWidgets(
      'every closed row is one height: ${size.width.toInt()} points '
      'wide, type at $scale',
      (tester) async {
        await overview(tester, size: size, textScale: scale);
        final ScrollPosition position = listPosition(tester);
        for (final double at in <double>[0.1, 0.5, 0.8]) {
          position.jumpTo(position.maxScrollExtent * at);
          await tester.pump();
          _expectOneHeight(tester);
        }
        // A sheet's rows are the same rows.
        final Map<int, List<VariantEvidence>> byResidue =
            <int, List<VariantEvidence>>{};
        for (final VariantEvidence e in evidence) {
          if (e.variant.residue case final int residue) {
            (byResidue[residue] ??= <VariantEvidence>[]).add(e);
          }
        }
        final List<VariantEvidence> busiest = byResidue.values.reduce(
          (List<VariantEvidence> a, List<VariantEvidence> b) =>
              a.length >= b.length ? a : b,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.analysis,
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ClinVarBlock(
                  status: ClinVarStatus.ready,
                  records: busiest,
                  scope: 'here',
                  total: evidence.length,
                  column: EvidenceColumn.avi,
                ),
              ),
            ),
          ),
        );
        _expectOneHeight(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('thousands of records build only the rows near the screen', (
    tester,
  ) async {
    await overview(tester);
    expect(evidence.length, greaterThan(5000));
    // A heading for every region, and only the rows near the screen: none
    // for the regions further down.
    final int built = find
        .byType(EvidenceRow, skipOffstage: false)
        .evaluate()
        .length;
    expect(built, lessThan(60));
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
    final int built = await _rowsBuilt(
      () => overview(tester, focus: <String>[deep.variant.id]),
    );
    expect(built, lessThan(60));
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
              dnaWindow: EvidenceStrip.runWindow(
                largest,
                geneStart: snapshot.start,
                geneEnd: snapshot.start + snapshot.sequence.length - 1,
              ),
              onSelected: (_, _) {},
              onWindow: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('DNA · ${largest.label} · 248,401 bp'), findsOneWidget);
  });

  // The same list for every gene, not only the largest.
  for (final ProteinTarget target in ProteinCatalog.all) {
    if (!target.clinvarAvailable) {
      continue;
    }
    testWidgets('${target.slug}: a jump builds only the rows it lands on', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: _overviewOf(target),
        ),
      );
      await tester.pumpAndSettle();
      final ScrollPosition position = listPosition(tester);
      for (final double at in <double>[0.5, 0.9, 0]) {
        final int built = await _rowsBuilt(() async {
          position.jumpTo(position.maxScrollExtent * at);
          await tester.pump();
        });
        expect(built, lessThanOrEqualTo(60), reason: 'at $at');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
