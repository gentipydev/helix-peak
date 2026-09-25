import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/variant_evidence.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/sequence_scrubber.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/clinvar_block.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_row.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_sections.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/sources_note.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';

import '../../../support/test_catalog.dart';
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
/// The overview over a stand-in page, as the walk pushes it. Every record link
/// followed is recorded in the returned list, and [answer] says what the page
/// it opened asks the list for on the way back.
///
/// Without a [size], the page is as large as the test's view — see [_phone].
Future<List<VariantTarget>> _overview(
  WidgetTester tester, {
  Size? size = const Size(390, 844),
  double textScale = 1,
  List<String> focus = const <String>[],
  VariantsOverviewMemory? memory,
  List<String>? Function(VariantTarget target)? answer,
}) async {
  if (size != null) {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  final GeneClinVar data = snapshot();
  final List<VariantEvidence> evidence = insulinEvidence();
  final List<GeneRun> runs = geneRuns(
    AnatomyModel.derive(insulin(), chain: TestCatalog.insulin.chain),
  );
  final List<VariantTarget> results = <VariantTarget>[];
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
              onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
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
                      onOpen: (VariantTarget target) async {
                        results.add(target);
                        return answer?.call(target);
                      },
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
/// 30-point gutter, 8 points at the right, the AVI area from 22 points down —
/// under the axis's name — to its ground over a ceiling of 40, and a row of
/// 11-point names under the ground.
Offset _head(
  WidgetTester tester,
  StripPanel panel,
  double u,
  double avi, {
  (double, double) window = (0, 110),
  bool onPage = false,
}) {
  // On a panel's own page the list's strip is still built, under it.
  final Rect rect = tester.getRect(
    onPage
        ? find.byKey(ValueKey<String>('evidence-strip-${panel.name}'))
        : _key('evidence-strip-${panel.name}'),
  );
  final double plot = rect.height - 22 - 14 - 11 - 6;
  final double ground = 22 + plot;
  final double width = rect.width - 38;
  return Offset(
    rect.left + 30 + (u - window.$1) / (window.$2 - window.$1) * width,
    rect.top + ground - 2 - avi / 40 * (ground - 2 - 22),
  );
}

EvidenceStrip _strip(WidgetTester tester) => tester.widget<EvidenceStrip>(
  find.byType(EvidenceStrip, skipOffstage: false),
);

/// A phone held upright. A panel's own page turns the screen by the media
/// query and tells a phone by its display, which a surface size reaches
/// neither of, so the view itself is set.
void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.display.size = const Size(1170, 2532);
  tester.view.physicalSize = const Size(1170, 2532);
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.reset);
}

/// The phone as the platform leaves it once asked: on its side, or upright.
Future<void> _turn(WidgetTester tester, {required bool landscape}) async {
  final Size upright = tester.view.display.size;
  tester.view.physicalSize = landscape ? upright.flipped : upright;
  await tester.pumpAndSettle();
}

/// Opens [panel] on its own page, and turns the phone as asked.
Future<void> _openPanel(WidgetTester tester, StripPanel panel) async {
  await tester.tap(_key('evidence-expand-${panel.name}'));
  await tester.pumpAndSettle();
  // Nothing is drawn while the screen turns.
  expect(find.byType(EvidenceStrip), findsNothing);
  await _turn(tester, landscape: true);
}

/// Closes [panel]'s page, and turns the phone back upright as asked.
Future<void> _closePanel(WidgetTester tester, StripPanel panel) async {
  await tester.tap(find.byKey(ValueKey<String>('evidence-close-${panel.name}')));
  await tester.pumpAndSettle();
  // The list is uncovered only once the screen is upright again.
  expect(find.byType(VariantsOverview), findsNothing);
  await _turn(tester, landscape: false);
  expect(find.byType(VariantsOverview), findsOneWidget);
}

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

  testWidgets('a mark on the strip is named under it; heads drawn over one '
      'another cycle, then let go', (tester) async {
    await _overview(tester);
    expect(find.text('Tap a mark for its record'), findsOneWidget);
    await capture(tester, 'readout-idle');
    // Cys96's two heads at AVI 31.5 share the one spot. The conflicting
    // record is drawn over the one with no classification, so it is first.
    final Offset head = _head(tester, StripPanel.protein, 95.5, 31.5);
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, <String>{'13387'});
    // Named under the strip, which stays where it is: no row opens and the
    // page does not scroll.
    expect(_scrollOf(tester).pixels, 0);
    expect(_key('evidence-detail-13387'), findsNothing);
    expect(find.text('1 of 2 here'), findsOneWidget);
    await capture(tester, 'readout-cys96-first');
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, <String>{'68730'});
    expect(find.text('2 of 2 here'), findsOneWidget);
    // Past the last of them, the spot lets go.
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, isEmpty);
    expect(find.text('Tap a mark for its record'), findsOneWidget);
    // And from a record, the way to its row.
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, <String>{'13387'});
    await tester.tap(_key('evidence-readout-show'));
    await tester.pumpAndSettle();
    expect(_key('evidence-detail-13387'), findsOneWidget);
  });

  testWidgets('a second tap on a mark lets it go, whatever is within reach', (
    tester,
  ) async {
    await _overview(tester);
    // Gly32Ser has four heads within a finger's reach and none drawn over
    // it: a tap on it is its own, and a second puts it down rather than
    // moving on to a neighbour.
    for (final String label in <String>['Gly32Ser', 'Gln65Ter']) {
      final VariantEvidence e = insulinEvidence().firstWhere(
        (VariantEvidence e) => e.variant.shortLabel == label,
      );
      final Offset head = _head(
        tester,
        StripPanel.protein,
        e.variant.residue! - 0.5,
        e.avi!,
      );
      await tester.tapAt(head);
      await tester.pumpAndSettle();
      expect(_strip(tester).selected, <String>{e.variant.id}, reason: label);
      expect(find.textContaining(' here'), findsNothing, reason: label);
      await tester.tapAt(head);
      await tester.pumpAndSettle();
      expect(_strip(tester).selected, isEmpty, reason: label);
      expect(find.text('Tap a mark for its record'), findsOneWidget);
    }
  });

  testWidgets('a tap away from every mark lets go; the ground still zooms', (
    tester,
  ) async {
    await _overview(tester);
    final Offset cys96 = _head(tester, StripPanel.protein, 95.5, 31.5);
    await tester.tapAt(cys96);
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, <String>{'13387'});
    // High over the signal peptide, 39 points from the nearest head.
    await tester.tapAt(_head(tester, StripPanel.protein, 15.5, 39));
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, isEmpty);
    expect(find.text('Tap a mark for its record'), findsOneWidget);
    // A tap on the ground is still the zoom's, and keeps the selection.
    await tester.tapAt(cys96);
    await tester.pumpAndSettle();
    final Rect protein = tester.getRect(_key('evidence-strip-protein'));
    await tester.tapAt(
      Offset(protein.left + 30 + 39.5 / 110 * (protein.width - 38), protein.bottom - 8),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protein · B chain 25–54'), findsOneWidget);
    expect(_strip(tester).selected, <String>{'13387'});
  });

  for (final Size size in <Size>[const Size(390, 844), const Size(360, 800)]) {
    testWidgets('the page under the strip stays put as marks are tapped and '
        'let go: ${size.width.round()} wide', (tester) async {
      await _overview(tester, size: size);
      Rect key() => tester.getRect(_key('variants-key'));
      Size readout() => tester.getSize(_key('evidence-readout'));
      final Rect idleKey = key();
      final Size idle = readout();
      // The pile's first, its second, and let go.
      final Offset head = _head(tester, StripPanel.protein, 95.5, 31.5);
      for (int tap = 0; tap < 3; tap++) {
        await tester.tapAt(head);
        await tester.pumpAndSettle();
        expect(readout(), idle);
        expect(key(), idleKey);
      }
      expect(_strip(tester).selected, isEmpty);
    });
  }

  testWidgets('the readout names a record whole at a phone’s width', (
    tester,
  ) async {
    // As the reader left it: Val42Ala tapped on the protein, zoomed to 16–70.
    await _overview(
      tester,
      size: const Size(360, 800),
      memory: VariantsOverviewMemory()
        ..selected = const <String>{'253331'}
        ..proteinWindow = (15, 70),
    );
    expect(find.text('Protein · residues 16–70 of 110'), findsOneWidget);
    final Finder readout = _key('evidence-readout');
    Finder inReadout(Finder finder) =>
        find.descendant(of: readout, matching: finder);
    expect(inReadout(find.text('Val42Ala')), findsOneWidget);
    expect(inReadout(find.text('c.125T>C')), findsOneWidget);
    expect(
      inReadout(find.text('AVI 24.4', findRichText: true)),
      findsOneWidget,
    );
    expect(inReadout(_key('evidence-readout-show')), findsOneWidget);
    // The change is drawn at its own size, not shrunk to fit.
    final Finder fitted = find.ancestor(
      of: inReadout(find.text('Val42Ala')),
      matching: find.byType(FittedBox),
    );
    expect(
      tester
          .renderObject<RenderBox>(
            find.descendant(of: fitted, matching: find.byType(Row)).first,
          )
          .size
          .width,
      lessThanOrEqualTo(tester.getSize(fitted).width),
    );
    // And what ClinVar calls it is read whole.
    final RenderParagraph classification = tester.renderObject(
      _key('evidence-readout-class'),
    );
    expect(classification.text.toPlainText(), 'Pathogenic/Likely pathogenic');
    expect(classification.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
    await capture(tester, 'readout-val42ala');
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
    expect(_strip(tester).proteinWindow, (22.0, 56.0));
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

  testWidgets('the keys zoom a panel and name what it shows', (tester) async {
    await _overview(tester);
    expect(find.text('Protein · residues 1–110'), findsOneWidget);
    // Nothing to zoom out of yet.
    expect(
      tester
          .widget<IconButton>(_key('evidence-zoom-out-protein'))
          .onPressed,
      isNull,
    );
    await _tapKey(tester, 'evidence-zoom-in-protein');
    expect(_strip(tester).proteinWindow, (27.5, 82.5));
    expect(find.text('Protein · residues 28–83 of 110'), findsOneWidget);
    expect(_key('evidence-window-protein'), findsOneWidget);
    await _tapKey(tester, 'evidence-zoom-out-protein');
    expect(_strip(tester).proteinWindow, isNull);
    expect(find.text('Protein · residues 1–110'), findsOneWidget);
    expect(_key('evidence-window-protein'), findsNothing);

    // With a record selected, + closes in on it.
    await tester.tapAt(_head(tester, StripPanel.protein, 95.5, 31.5));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-zoom-in-protein');
    final (double, double) window = _strip(tester).proteinWindow!;
    expect(window.$1, lessThan(95.5));
    expect(window.$2, greaterThan(95.5));
    expect(window.$2 - window.$1, 55);
  });

  testWidgets('the bar under a zoomed panel moves its window', (tester) async {
    await _overview(tester);
    await _tapKey(tester, 'evidence-zoom-in-protein');
    await _tapKey(tester, 'evidence-zoom-in-protein');
    final (double, double) before = _strip(tester).proteinWindow!;
    final Finder bar = _key('evidence-window-protein');
    await tester.ensureVisible(bar);
    await tester.pumpAndSettle();
    await tester.drag(bar, const Offset(60, 0));
    await tester.pumpAndSettle();
    final (double, double) dragged = _strip(tester).proteinWindow!;
    expect(dragged.$1, greaterThan(before.$1));
    expect(dragged.$2 - dragged.$1, closeTo(before.$2 - before.$1, 1e-6));
    // A tap on the bar centres the window where it fell.
    final Rect rect = tester.getRect(bar);
    await tester.tapAt(Offset(rect.left + 30 + 2, rect.center.dy));
    await tester.pumpAndSettle();
    expect(_strip(tester).proteinWindow!.$1, 0);
  });

  testWidgets('two fingers pinch a panel; one finger still scrolls the page', (
    tester,
  ) async {
    await _overview(tester);
    final Rect plot = tester.getRect(_key('evidence-strip-protein'));
    final Offset middle = Offset(plot.center.dx, plot.top + 60);
    // One finger drawn upward across the plot is the page's, not the zoom's.
    await tester.dragFrom(middle, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(_scrollOf(tester).pixels, greaterThan(0));
    expect(_strip(tester).proteinWindow, isNull);
    _scrollOf(tester).jumpTo(0);
    await tester.pumpAndSettle();

    final TestGesture left = await tester.startGesture(
      middle - const Offset(30, 0),
    );
    final TestGesture right = await tester.startGesture(
      middle + const Offset(30, 0),
    );
    await tester.pump();
    for (int i = 0; i < 6; i++) {
      await left.moveBy(const Offset(-15, 0));
      await right.moveBy(const Offset(15, 0));
      await tester.pump();
    }
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    final (double, double)? window = _strip(tester).proteinWindow;
    expect(window, isNotNull);
    expect(window!.$2 - window.$1, lessThan(110));
    expect(_scrollOf(tester).pixels, 0);
  });

  testWidgets('a zoomed strip narrows the list, and Show all widens it', (
    tester,
  ) async {
    await _overview(tester);
    final Rect protein = tester.getRect(_key('evidence-strip-protein'));
    // The B chain's name, under the band.
    await tester.tapAt(
      Offset(protein.left + 30 + 39.5 / 110 * (protein.width - 38), protein.bottom - 8),
    );
    await tester.pumpAndSettle();
    expect(_key('variants-window-note'), findsOneWidget);
    // The window keeps two residues either side of the chain, so the end of
    // the signal peptide is in it, and its region says how much.
    expect(
      find.textContaining(
        RegExp(r'^Signal peptide · 1–24 · \d+ of 22 records$'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('A chain · 90–110', skipOffstage: false),
      findsNothing,
    );
    expect(
      find.text('B chain · 25–54 · 39 records', skipOffstage: false),
      findsOneWidget,
    );
    await _tapKey(tester, 'variants-window-all');
    expect(_key('variants-window-note'), findsNothing);
    expect(_strip(tester).proteinWindow, isNull);
    expect(
      find.text('Signal peptide · 1–24 · 22 records', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('each panel opens on a page of its own, alone and taller', (
    tester,
  ) async {
    _phone(tester);
    await _overview(tester, size: null);
    for (final StripPanel panel in StripPanel.values) {
      final Finder drawing = find.byKey(
        ValueKey<String>('evidence-strip-${panel.name}'),
      );
      final double inList = tester.getRect(drawing).height;
      await _openPanel(tester, panel);
      expect(drawing, findsOneWidget);
      for (final StripPanel other in StripPanel.values) {
        if (other != panel) {
          expect(
            find.byKey(ValueKey<String>('evidence-strip-${other.name}')),
            findsNothing,
          );
        }
      }
      expect(tester.getRect(drawing).height, greaterThan(inList));
      // Its own way out instead of the way to it, and the readout under it.
      expect(
        find.byKey(ValueKey<String>('evidence-expand-${panel.name}')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('evidence-readout')), findsOneWidget);
      expect(find.text('Tap a mark for its record'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'panel-page-${panel.name}');
      await _closePanel(tester, panel);
      expect(
        find.byKey(ValueKey<String>('evidence-expand-${panel.name}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('a window chosen on a panel’s page is the list’s once it closes', (
    tester,
  ) async {
    _phone(tester);
    await _overview(tester, size: null);
    await _openPanel(tester, StripPanel.protein);
    final Finder drawing = find.byKey(
      const ValueKey<String>('evidence-strip-protein'),
    );
    final Rect whole = tester.getRect(drawing);
    await tester.tap(
      find.byKey(const ValueKey<String>('evidence-zoom-in-protein')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protein · residues 28–83 of 110'), findsOneWidget);
    // The bar's room was kept for it, so the drawing it frames stays put.
    expect(
      find.byKey(const ValueKey<String>('evidence-window-protein')),
      findsOneWidget,
    );
    expect(tester.getRect(drawing), whole);
    await _closePanel(tester, StripPanel.protein);
    expect(_strip(tester).proteinWindow, (27.5, 82.5));
    expect(find.text('Protein · residues 28–83 of 110'), findsOneWidget);
    expect(_key('variants-window-note'), findsOneWidget);
  });

  testWidgets('a mark tapped on a panel’s page is named there and let go '
      'there, and Show in list opens its row', (tester) async {
    _phone(tester);
    await _overview(tester, size: null);
    final double inList = tester.getSize(_key('evidence-readout')).height;
    await _openPanel(tester, StripPanel.protein);
    // The page is wide: the way to the row sits beside the record's lines
    // rather than under them, and the drawing keeps that height.
    final Finder readout = find.byKey(
      const ValueKey<String>('evidence-readout'),
    );
    expect(tester.getSize(readout).height, lessThan(inList));
    Set<String> selected() =>
        tester.widget<EvidenceStrip>(find.byType(EvidenceStrip)).selected;
    // Cys96's two heads at AVI 31.5 share the one spot.
    final Offset head = _head(
      tester,
      StripPanel.protein,
      95.5,
      31.5,
      onPage: true,
    );
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(selected(), <String>{'13387'});
    expect(find.text('1 of 2 here'), findsOneWidget);
    await capture(tester, 'panel-page-readout');
    // Past the last of the spot, the page lets go too.
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(selected(), isEmpty);
    expect(find.text('Tap a mark for its record'), findsOneWidget);
    await tester.tapAt(head);
    await tester.pumpAndSettle();
    expect(selected(), <String>{'13387'});
    await tester.tap(
      find.byKey(const ValueKey<String>('evidence-readout-show')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    await _turn(tester, landscape: false);
    expect(_key('evidence-detail-13387'), findsOneWidget);
    expect(_strip(tester).selected, <String>{'13387'});
  });

  testWidgets('Back on a panel’s page returns to the list', (tester) async {
    _phone(tester);
    await _overview(tester, size: null);
    await _openPanel(tester, StripPanel.dna);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    await _turn(tester, landscape: false);
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(find.text('DNA · 5′ UTR · introns · 3′ UTR'), findsOneWidget);
  });

  test('stems and head sizes give way to density', () {
    expect(EvidenceStrip.stems(2.8), isTrue);
    expect(EvidenceStrip.stems(0.3), isFalse);
    expect(EvidenceStrip.headRadius(2.8), 3.4);
    expect(EvidenceStrip.headRadius(0.5), 2.6);
    expect(EvidenceStrip.headRadius(0.04), 2.0);
  });

  testWidgets('class chips choose what is drawn, one or several', (
    tester,
  ) async {
    await _overview(tester);
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    expect(_strip(tester).classes, <ClinVarGroup>{ClinVarGroup.pathogenic});
    // The C-peptide has no pathogenic record, so its section goes.
    expect(
      find.textContaining('C-peptide', skipOffstage: false),
      findsNothing,
    );
    Set<ClinVarGroup> listed() => <ClinVarGroup>{
      for (final EvidenceRow row in tester.widgetList<EvidenceRow>(
        find.byType(EvidenceRow, skipOffstage: false),
      ))
        row.evidence.variant.group,
    };
    expect(listed(), <ClinVarGroup>{ClinVarGroup.pathogenic});
    // A region the choice narrows says so.
    expect(
      find.text('B chain · 25–54 · 17 of 39 records', skipOffstage: false),
      findsOneWidget,
    );

    // A second chip adds its class; the first taken away leaves the second.
    await tester.tap(_key('variants-chip-benign'));
    await tester.pumpAndSettle();
    expect(_strip(tester).classes, <ClinVarGroup>{
      ClinVarGroup.pathogenic,
      ClinVarGroup.benign,
    });
    expect(listed(), <ClinVarGroup>{
      ClinVarGroup.pathogenic,
      ClinVarGroup.benign,
    });
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    expect(_strip(tester).classes, <ClinVarGroup>{ClinVarGroup.benign});
    // The last one taken away shows every class again.
    await tester.tap(_key('variants-chip-benign'));
    await tester.pumpAndSettle();
    expect(_strip(tester).classes, isEmpty);
    expect(
      find.text('B chain · 25–54 · 39 records', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a class left out is not drawn and cannot be tapped', (
    tester,
  ) async {
    await _overview(tester);
    await tester.tap(_key('variants-chip-benign'));
    await tester.pumpAndSettle();
    final VariantEvidence benign = insulinEvidence().firstWhere(
      (VariantEvidence e) =>
          e.variant.group == ClinVarGroup.benign &&
          e.variant.residue != null &&
          e.avi != null,
    );
    expect(_strip(tester).drawn(benign), isTrue);
    await tester.tap(_key('variants-chip-benign'));
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    expect(_strip(tester).drawn(benign), isFalse);
    await tester.tapAt(
      _head(
        tester,
        StripPanel.protein,
        benign.variant.residue! - 0.5,
        benign.avi!,
      ),
    );
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, isNot(contains(benign.variant.id)));
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
    expect(_strip(tester).classes, <ClinVarGroup>{ClinVarGroup.pathogenic});
    expect(_strip(tester).selected, <String>{id});
    expect(_strip(tester).proteinWindow, (85.0, 110.0));
    // Zoomed to the A chain, the list holds the A chain; the B chain comes
    // back with "Show all", as closed as it was left.
    expect(
      find.textContaining('B chain · 25–54', skipOffstage: false),
      findsNothing,
    );
    _scrollOf(tester).jumpTo(0);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'variants-window-all');
    expect(
      find.text('B chain · 25–54 · 17 of 39 records', skipOffstage: false),
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

  testWidgets('every key and link is a finger\'s height', (tester) async {
    // Written as 44 and drawn at 36 while they were compact: a density takes
    // its eight points off whatever size it is paired with. The strip's keys
    // keep the 32 points of width the title row can spare them.
    await _overview(tester, focus: const <String>['13387']);
    Size size(String key) => tester.getSize(_key(key));
    for (final String key in <String>[
      'evidence-zoom-out-protein',
      'evidence-zoom-in-protein',
      'evidence-expand-protein',
    ]) {
      expect(size(key).width, greaterThanOrEqualTo(32), reason: key);
      expect(size(key).height, greaterThanOrEqualTo(44), reason: key);
    }
    for (final String key in <String>[
      'evidence-readout-show',
      'evidence-copy-13387',
      'evidence-residue-13387',
      'evidence-base-13387',
    ]) {
      expect(size(key).height, greaterThanOrEqualTo(44), reason: key);
    }
    await _tapKey(tester, 'evidence-zoom-in-protein');
    for (final String key in <String>[
      'evidence-whole-protein',
      'variants-window-all',
    ]) {
      expect(size(key).height, greaterThanOrEqualTo(44), reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a record’s links open its residue or base above the list', (
    tester,
  ) async {
    final List<VariantTarget> results = await _overview(
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
    expect((results.single as ResidueTarget).number, 96);
    // The list stays: the residue opens above it rather than in its place.
    expect(find.byType(VariantsOverview), findsOneWidget);
    await _tapKey(tester, 'evidence-base-13387');
    expect((results.last as BaseTarget).position, 6297);
  });

  testWidgets('a record’s accession opens it on ClinVar, or copies it', (
    tester,
  ) async {
    await _overview(tester, focus: const <String>['13387']);
    final String url = insulinEvidence()
        .firstWhere((VariantEvidence e) => e.variant.id == '13387')
        .variant
        .url;
    String? opened;
    bool launches = true;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (MethodCall call) async {
        opened = (call.arguments as Map<dynamic, dynamic>)['url'] as String?;
        return launches;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        )
        ..setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await _tapKey(tester, 'evidence-copy-13387');
    expect(opened, url);
    expect(copied, isNull);

    // Nowhere to open it: the link is copied, and the reader told so.
    launches = false;
    await _tapKey(tester, 'evidence-copy-13387');
    expect(copied, url);
    expect(find.textContaining('link copied'), findsOneWidget);
  });

  testWidgets('what the opened page asks for, the list opens on', (
    tester,
  ) async {
    await _overview(
      tester,
      focus: const <String>['13387'],
      answer: (VariantTarget target) => const <String>['68730'],
    );
    await _tapKey(tester, 'evidence-residue-13387');
    expect(_strip(tester).selected, <String>{'68730'});
    expect(_key('evidence-detail-68730'), findsOneWidget);
    expect(_key('evidence-detail-13387'), findsNothing);
  });
}
