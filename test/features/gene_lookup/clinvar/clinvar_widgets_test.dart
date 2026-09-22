import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/variant_evidence.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/sequence_scrubber.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/clinvar_block.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_row.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_sections.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/sources_note.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/variants_overview.dart';

import '../anatomy/anatomy_fixture.dart';
import 'gene_clinvar_test.dart' show snapshot;
import 'variant_evidence_test.dart' show insulinConstraint, insulinEvidence;

Future<void> capture(WidgetTester tester, String name) async {
  final String? directory = Platform.environment['SHOT_DIR'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(const ValueKey<String>('capture')),
  );
  final ByteData? data = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return bytes!;
  });
  Directory(directory).createSync(recursive: true);
  File('$directory/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

// The list is built lazily, so what is below the screen is offstage rather
// than absent; a key is found wherever it is built.
Finder _key(String value) =>
    find.byKey(ValueKey<String>(value), skipOffstage: false);

/// The rows built under one of the list's sections.
Iterable<EvidenceRow> _rowsIn(WidgetTester tester, String section) => tester
    .widgetList<EvidenceRow>(find.byType(EvidenceRow, skipOffstage: false))
    .where((EvidenceRow row) => row.evidence.section == section);

/// The overview, pushed from a host so its result can be read back — the way
/// the walk pushes it.
Future<List<VariantTarget?>> _overview(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  List<String> focus = const <String>[],
  VariantsOverviewMemory? memory,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final GeneClinVar data = snapshot();
  final List<VariantEvidence> evidence = insulinEvidence();
  final List<GeneRun> runs = geneRuns(
    AnatomyModel.derive(insulin(), chain: ProteinCatalog.insulin.chain),
  );
  final List<VariantTarget?> results = <VariantTarget?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      debugShowCheckedModeBanner: false,
      // Pushed routes read the app's media query, not one set under `home`.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(
          key: const ValueKey<String>('capture'),
          child: child!,
        ),
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey<String>('open-overview'),
              onPressed: () async => results.add(
                await Navigator.of(context).push<VariantTarget>(
                  MaterialPageRoute<VariantTarget>(
                    builder: (_) => VariantsOverview(
                      snapshot: data,
                      evidence: evidence,
                      constraint: insulinConstraint(),
                      exons: <(int, int)>[
                        for (final e in insulin().exons) (e.start, e.end),
                      ],
                      runs: runs,
                      focus: focus,
                      memory: memory,
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open-overview'));
  await tester.pumpAndSettle();
  return results;
}

ScrollPosition _scrollOf(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

/// Where the strip draws a record's head, from the panel's own geometry: a
/// 30-point gutter, 8 points at the right, the AVI area from 8 points down to
/// its ground over a ceiling of 40, and a row of names under the ground.
Offset _head(
  WidgetTester tester,
  StripPanel panel,
  double u,
  double avi, {
  (double, double) window = (0, 110),
}) {
  final Rect rect = tester.getRect(_key('evidence-strip-${panel.name}'));
  final double plot = rect.height - 8 - 14 - 10 - 6;
  final double ground = 8 + plot;
  final double width = rect.width - 38;
  return Offset(
    rect.left + 30 + (u - window.$1) / (window.$2 - window.$1) * width,
    rect.top + ground - 2 - avi / 40 * (ground - 2 - 8),
  );
}

EvidenceStrip _strip(WidgetTester tester) => tester.widget<EvidenceStrip>(
  find.byType(EvidenceStrip, skipOffstage: false),
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final (ClinVarStatus, bool, String) state
      in <(ClinVarStatus, bool, String)>[
        (ClinVarStatus.loading, false, 'ClinVar · loading…'),
        (ClinVarStatus.unavailable, false, 'ClinVar · unavailable'),
        (ClinVarStatus.ready, false, 'ClinVar · none at Val26 in this snapshot'),
        (ClinVarStatus.ready, true, 'ClinVar · 3 records here'),
      ]) {
    testWidgets('a sheet says one line about ClinVar: ${state.$3}', (
      tester,
    ) async {
      final List<VariantEvidence> here = state.$2
          ? insulinEvidence().where((e) => e.variant.residue == 96).toList()
          : const <VariantEvidence>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClinVarBlock(
                status: state.$1,
                records: here,
                scope: 'Val26',
                total: 166,
                column: EvidenceColumn.avi,
                onOpenAll: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text(state.$3), findsOneWidget);
      // A sheet never turns a missing record into a finding, and never
      // repeats what ClinVar is: that is said once, elsewhere.
      expect(find.text('Benign'), findsNothing);
      expect(find.textContaining('benign effect'), findsNothing);
      expect(find.textContaining('snapshot 20'), findsNothing);
      expect(
        _key('clinvar-open-all'),
        state.$1 == ClinVarStatus.ready ? findsOneWidget : findsNothing,
      );
      expect(find.byType(EvidenceRow), findsNWidgets(here.length));
      expect(tester.takeException(), isNull);
    });
  }

  for (final (bool, String?, String) note in <(bool, String?, String)>[
    (false, null, 'Not yet included for this gene.'),
    // Loading, or failed: the gene has a snapshot, just no date to give yet.
    (true, null, 'NCBI, germline classifications. Single-base records only.'),
    (
      true,
      '2026-09-22',
      'NCBI, germline classifications, snapshot 2026-09-22. Single-base '
          'records only.',
    ),
  ]) {
    testWidgets('the sources note says what the gene has: ${note.$3}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourcesNote(included: note.$1, snapshotDate: note.$2),
          ),
        ),
      );
      expect(find.textContaining(note.$3, findRichText: true), findsOneWidget);
      expect(
        find.textContaining('Not yet included', findRichText: true),
        note.$1 ? findsNothing : findsOneWidget,
      );
    });
  }

  test('zoomed residue numbers keep their distance at any scale', () {
    // Five apart where five residues span the room a number needs, and the
    // next of 10, 20, 50, 100… where they do not.
    expect(EvidenceStrip.residueStep(8, 24), 5);
    expect(EvidenceStrip.residueStep(4, 24), 10);
    expect(EvidenceStrip.residueStep(2, 24), 20);
    expect(EvidenceStrip.residueStep(1, 30), 50);
    expect(EvidenceStrip.residueStep(0.2, 30), 200);
    expect(EvidenceStrip.residueStep(0.02, 30), 2000);
    expect(EvidenceStrip.residueStep(0, 30), 5);
  });

  for (final (Size, double, String) config in <(Size, double, String)>[
    (const Size(390, 844), 1, 'phone'),
    (const Size(320, 568), 1, 'small'),
    (const Size(390, 844), 2, 'large-text'),
    (const Size(844, 390), 1, 'landscape'),
  ]) {
    testWidgets('the overview reads as one picture and one list: ${config.$3}', (
      tester,
    ) async {
      await _overview(tester, size: config.$1, textScale: config.$2);
      expect(tester.takeException(), isNull);
      expect(
        find.text('166 single-base records · snapshot 2026-09-21'),
        findsOneWidget,
      );
      expect(find.byType(EvidenceStrip), findsOneWidget);
      expect(
        find.text('Protein · residues 1–110'),
        findsOneWidget,
      );
      expect(find.text('DNA · 5′ UTR · introns · 3′ UTR'), findsOneWidget);
      expect(
        find.text(
          'Height: AVI of each allele · band: ESM · colour: ClinVar '
          'categorisation',
        ),
        findsOneWidget,
      );
      for (final (String, int) chip in <(String, int)>[
        ('pathogenic', 37),
        ('conflicting', 24),
        ('uncertain', 54),
        ('benign', 42),
        ('other', 9),
      ]) {
        expect(_key('variants-chip-${chip.$1}'), findsOneWidget);
      }
      await capture(tester, 'overview-${config.$3}');
      for (final String section in <String>[
        'Signal peptide · 1–24 · 22 records',
        'B chain · 25–54 · 39 records',
        'C-peptide · 57–87 · 21 records',
        'A chain · 90–110 · 26 records',
        'Intron 2 · 32 records',
        '3′ UTR · 8 records',
      ]) {
        final Finder header = find.text(section, skipOffstage: false);
        await tester.ensureVisible(header);
        await tester.pumpAndSettle();
        expect(header, findsOneWidget, reason: section);
      }
      final Finder footer = find.text(
        'About these sources',
        skipOffstage: false,
      );
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      expect(_key('sources-note'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'overview-${config.$3}-footer');
    });
  }

  testWidgets('every region starts open and closes from its own heading', (
    tester,
  ) async {
    await _overview(tester);
    // Every region's rows follow its heading. The list builds the rows near
    // the screen, so each heading is brought to it before its rows are read.
    for (final (String key, String section) in <(String, String)>[
      ('Signal peptide@1', 'Signal peptide'),
      ('B chain@25', 'B chain'),
      ('C-peptide@57', 'C-peptide'),
      ('A chain@90', 'A chain'),
    ]) {
      await tester.ensureVisible(_key('variants-section-toggle-$key'));
      await tester.pumpAndSettle();
      expect(_rowsIn(tester, section), isNotEmpty, reason: section);
    }
    // One control per region, and none for all of them at once.
    expect(find.text('Expand all'), findsNothing);
    expect(find.text('Collapse all'), findsNothing);
    await _tapKey(tester, 'variants-section-toggle-B chain@25');
    expect(_rowsIn(tester, 'B chain'), isEmpty);
    // Closed down to its heading and count.
    expect(find.text('B chain · 25–54 · 39 records'), findsOneWidget);
    await _tapKey(tester, 'variants-section-toggle-B chain@25');
    expect(_rowsIn(tester, 'B chain'), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scrubber is a plain thumb: no ticks, no bubble', (
    tester,
  ) async {
    await _overview(tester);
    expect(_key('sequence-scrubber'), findsOneWidget);
    final SequenceScrubber scrubber = tester.widget<SequenceScrubber>(
      find.byType(SequenceScrubber),
    );
    expect(scrubber.landmarks, isEmpty);
    expect(scrubber.labelAt, isNull);
    // Dragging it moves through the list with nothing written beside it.
    final Rect strip = tester.getRect(_key('sequence-scrubber'));
    final TestGesture drag = await tester.startGesture(
      Offset(strip.center.dx, strip.top + 30),
    );
    await drag.moveBy(const Offset(0, 40));
    await drag.moveTo(Offset(strip.center.dx, strip.center.dy));
    await tester.pump();
    expect(_scrollOf(tester).pixels, greaterThan(0));
    expect(
      find.descendant(
        of: find.byType(SequenceScrubber),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    await capture(tester, 'overview-scrubber-drag');
    await drag.up();
    await tester.pumpAndSettle();
  });

  testWidgets('closing a region redraws the thumb for the shorter page', (
    tester,
  ) async {
    await _overview(tester);
    double thumbTop() => tester
        .getTopLeft(
          find
              .descendant(
                of: find.byType(SequenceScrubber),
                matching: find.byType(DecoratedBox),
              )
              .first,
        )
        .dy;
    await tester.ensureVisible(_key('variants-section-toggle-A chain@90'));
    await tester.pumpAndSettle();
    final double before = thumbTop();
    // Closing a region above the view shortens the page without scrolling it
    // by hand; the thumb has to move down to say so.
    await tester.tap(_key('variants-section-toggle-A chain@90'));
    await tester.pumpAndSettle();
    await tester.tap(_key('variants-section-toggle-A chain@90'));
    await tester.pumpAndSettle();
    expect(thumbTop(), before);
    final ScrollPosition position = _scrollOf(tester);
    final double extent = position.maxScrollExtent;
    await tester.tap(_key('variants-section-toggle-A chain@90'));
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, lessThan(extent));
    expect(thumbTop(), greaterThan(before));
  });

  testWidgets('a mark on the strip opens its record; coincident ones cycle', (
    tester,
  ) async {
    await _overview(tester);
    // Cys96's two heads at AVI 31.5 share the one spot.
    final Offset head = _head(tester, StripPanel.protein, 95.5, 31.5);
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    final Set<String> first = _strip(tester).selected;
    expect(first, hasLength(1));
    expect(first.single, isIn(<String>['13387', '68730']));
    // Its region opened with it.
    expect(_key('evidence-detail-${first.single}'), findsOneWidget);
    // Opening the record scrolled the list to it; back to the strip.
    _scrollOf(tester).jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(_strip(tester).selected.single, isNot(first.single));
  });

  testWidgets('a region under a panel zooms it, and the ground zooms back', (
    tester,
  ) async {
    await _overview(tester);
    final Rect protein = tester.getRect(_key('evidence-strip-protein'));
    final double width = protein.width - 38;
    // The B chain's name, under the band.
    await tester.tapAt(
      Offset(protein.left + 30 + 39.5 / 110 * width, protein.bottom - 8),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protein · B chain 25–54'), findsOneWidget);
    expect(_strip(tester).proteinZoom, 'B chain@25');
    await capture(tester, 'overview-zoom-b-chain');
    // Two residues either side keep the RR cut at 55–56 in view. Cys31 is
    // alone at its residue, wherever it lands on the AVI axis.
    final VariantEvidence cys31 = insulinEvidence().firstWhere(
      (VariantEvidence e) => e.variant.shortLabel == 'Cys31=',
    );
    await tester.tapAt(
      _head(tester, StripPanel.protein, 30.5, cys31.avi!, window: (22, 56)),
    );
    await tester.pumpAndSettle();
    expect(_strip(tester).selected.single, cys31.variant.id);
    await _tapKey(tester, 'evidence-whole-protein');
    expect(find.text('Protein · residues 1–110'), findsOneWidget);

    // The gene's own 5′ UTR is 42 bases, a few points at this scale; a finger
    // at the left end still means it.
    final Rect dna = tester.getRect(_key('evidence-strip-dna'));
    await tester.tapAt(Offset(dna.left + 31, dna.bottom - 8));
    await tester.pumpAndSettle();
    expect(find.text('DNA · 5′ UTR · 42 bp'), findsOneWidget);
    await capture(tester, 'overview-zoom-5utr');
    await tester.tapAt(Offset(dna.center.dx, dna.bottom - 8));
    await tester.pumpAndSettle();
    expect(find.text('DNA · 5′ UTR · introns · 3′ UTR'), findsOneWidget);
    await tester.tapAt(Offset(dna.left + 30 + 0.6 * (dna.width - 38), dna.bottom - 8));
    await tester.pumpAndSettle();
    expect(find.text('DNA · Intron 2 · 787 bp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a class chip filters the list and keeps the strip in place', (
    tester,
  ) async {
    await _overview(tester);
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    expect(_strip(tester).highlight, ClinVarGroup.pathogenic);
    // The C-peptide has no pathogenic record, so its section goes.
    expect(
      find.textContaining('C-peptide', skipOffstage: false),
      findsNothing,
    );
    final Iterable<EvidenceRow> rows = tester.widgetList<EvidenceRow>(
      find.byType(EvidenceRow, skipOffstage: false),
    );
    expect(rows, isNotEmpty);
    expect(
      rows.every(
        (EvidenceRow row) =>
            row.evidence.variant.group == ClinVarGroup.pathogenic,
      ),
      isTrue,
    );
    await tester.ensureVisible(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    expect(_strip(tester).highlight, isNull);
  });

  testWidgets('the list comes back as it was left', (tester) async {
    final VariantsOverviewMemory memory = VariantsOverviewMemory();
    await _overview(tester, memory: memory);
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'variants-section-toggle-B chain@25');
    final String id = insulinEvidence()
        .firstWhere(
          (VariantEvidence e) =>
              e.variant.residue == 96 &&
              e.variant.group == ClinVarGroup.pathogenic,
        )
        .variant
        .id;
    await _tapKey(tester, 'evidence-row-$id');
    _scrollOf(tester).jumpTo(0);
    await tester.pumpAndSettle();
    final Rect protein = tester.getRect(_key('evidence-strip-protein'));
    await tester.tapAt(
      Offset(
        protein.left + 30 + 99.5 / 110 * (protein.width - 38),
        protein.bottom - 8,
      ),
    );
    await tester.pumpAndSettle();
    // The list builds its rows as they come near the screen, so the open
    // record is scrolled to rather than looked up.
    await tester.scrollUntilVisible(
      _key('evidence-detail-$id'),
      200,
      scrollable: find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    final double offset = _scrollOf(tester).pixels;
    expect(offset, greaterThan(0));
    expect(memory.collapsed, <String>{'B chain@25'});

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    await tester.tap(_key('open-overview'));
    await tester.pumpAndSettle();
    expect(_scrollOf(tester).pixels, offset);
    expect(_key('evidence-detail-$id'), findsOneWidget);
    expect(_strip(tester).highlight, ClinVarGroup.pathogenic);
    expect(_strip(tester).selected, <String>{id});
    expect(_strip(tester).proteinZoom, 'A chain@90');
    // The region it was closed in stays closed.
    expect(
      find.text('B chain · 25–54 · 17 records', skipOffstage: false),
      findsOneWidget,
    );
    expect(_rowsIn(tester, 'B chain'), isEmpty);
  });

  testWidgets('an opened record names each condition under its own class', (
    tester,
  ) async {
    await _overview(tester, focus: const <String>['1455986']);
    final Finder conditions = _key('evidence-conditions-1455986');
    await tester.ensureVisible(conditions);
    await tester.pumpAndSettle();
    // Identifiers are kept whole with no-break spaces; read them as spaces.
    String text(Finder of) => <String>[
      for (final Text t in tester.widgetList<Text>(
        find.descendant(of: of, matching: find.byType(Text)),
      ))
        (t.data ?? t.textSpan!.toPlainText()).replaceAll(' ', ' '),
    ].join(' | ');
    expect(
      text(conditions),
      'Pathogenic | not provided | Likely pathogenic | '
      'Diabetes mellitus, permanent neonatal 4 | PNDM4 · MIM 618858 | '
      'Hyperproinsulinemia | MIM 616214 | '
      'Maturity-onset diabetes of the young type 10 | MODY10 · MIM 613370 | '
      'Type 1 diabetes mellitus 2 | IDDM2 · MIM 125852 | '
      'criteria provided, multiple submitters, no conflicts',
    );
    // What ClinVar says stays inside its boundary, and the date is gone.
    expect(
      find.ancestor(of: conditions, matching: find.byType(ClinVarSourced)),
      findsOneWidget,
    );
    expect(find.textContaining('evaluated'), findsNothing);
    await capture(tester, 'overview-met1val-detail');
  });

  testWidgets('a conflict shows what it is split between, once', (tester) async {
    await _overview(tester, focus: const <String>['13387']);
    final Finder conditions = _key('evidence-conditions-13387');
    await tester.ensureVisible(conditions);
    await tester.pumpAndSettle();
    for (final String label in <String>[
      'Pathogenic',
      'Likely pathogenic',
      'Uncertain significance',
    ]) {
      expect(
        find.descendant(of: conditions, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.textContaining('Split by condition'), findsNothing);
  });

  testWidgets('a record’s links return to the walk at its residue or base', (
    tester,
  ) async {
    final List<VariantTarget?> results = await _overview(
      tester,
      focus: const <String>['13387'],
    );
    // Opened on the record it was sent for, already expanded.
    expect(_key('evidence-detail-13387'), findsOneWidget);
    expect(
      find.text('Both models at their strong end.'),
      findsOneWidget,
    );
    await _tapKey(tester, 'evidence-residue-13387');
    expect(results.single, isA<ResidueTarget>());
    expect((results.single! as ResidueTarget).number, 96);

    // Opened again on the same record, which is open already.
    await tester.tap(_key('open-overview'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-base-13387');
    expect((results.last! as BaseTarget).position, 6297);
  });
}
