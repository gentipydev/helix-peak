import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeak/features/gene_lookup/presentation/inspector/impact_panel.dart';

import '../anatomy/anatomy_fixture.dart';

final GeneImpact _track = GeneImpact.fromJson(
  jsonDecode(File(ProteinCatalog.insulin.impactAsset).readAsStringSync())
      as Map<String, dynamic>,
  ProteinCatalog.insulin,
);

Finder get _paintBox => find.byWidgetPredicate(
  (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
);
AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paintBox).painter! as AnatomyPainter;

Finder get _panel => find.byType(ImpactPanel);
Finder get _surface =>
    find.byKey(const ValueKey<String>('impact-sheet-surface'));
Finder get _close => find.byKey(const ValueKey<String>('impact-sheet-close'));
Finder get _level => find.byKey(const ValueKey<String>('impact-level'));
Finder get _estimated =>
    find.byKey(const ValueKey<String>('impact-estimated'));
Finder get _coordinate =>
    find.byKey(const ValueKey<String>('impact-coordinate'));

/// Insulin's row as it would stand before its impact track was baked. Every
/// catalog gene has one, so the state is held here rather than by the catalog
/// walk. The slug stays insulin's on purpose: a screen that ignored the flag
/// would find the real track and load it anyway.
final ProteinTarget _untracked = ProteinTarget(
  slug: ProteinCatalog.insulin.slug,
  display: ProteinCatalog.insulin.display,
  gene: ProteinCatalog.insulin.gene,
  uniprot: ProteinCatalog.insulin.uniprot,
  accession: ProteinCatalog.insulin.accession,
  summary: ProteinCatalog.insulin.summary,
  facts: ProteinCatalog.insulin.facts,
  chains: ProteinCatalog.insulin.chains,
  structure: ProteinCatalog.insulin.structure,
  chain: ProteinCatalog.insulin.chain,
  impactScored: false,
  // A snapshot is placed through the impact track's coordinate map, so a gene
  // without the track has none either.
  clinvarAvailable: false,
);

/// Opens insulin's mRNA page, which is one swipe from the gene.
Future<void> _openTranscript(
  WidgetTester tester, {
  GeneImpact? track,
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      debugShowCheckedModeBanner: false,
      home: AnatomyScreen(
        target: ProteinCatalog.insulin,
        record: insulin(),
        impact: track ?? _track,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    const Offset(-160, 0),
  );
  await tester.pumpAndSettle();
}

Offset _cell(WidgetTester tester, int index) =>
    tester.getRect(_paintBox).topLeft +
    _painter(tester).scene.fromLayout.centreOf(index);

/// Taps a cell and waits out the 300 ms masking beat.
Future<void> _tapCell(WidgetTester tester, int index) async {
  await tester.tapAt(_cell(tester, index));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pumpAndSettle();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = true);

  testWidgets('a tap on a base masks it, then raises the sheet', (
    WidgetTester tester,
  ) async {
    await _openTranscript(tester);
    expect(_panel, findsNothing);
    expect(_painter(tester).maskedIndex, isNull);

    await tester.tapAt(_cell(tester, 30));
    await tester.pump();
    // The mask lands first and the sheet follows it, as on the protein page.
    expect(_painter(tester).maskedIndex, 30);
    expect(_panel, findsNothing);

    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(_surface, findsOneWidget);
  });

  testWidgets('the sheet names the base, its region and its coordinate', (
    WidgetTester tester,
  ) async {
    await _openTranscript(tester);
    await _tapCell(tester, 30);

    final ImpactPanel panel = tester.widget<ImpactPanel>(_panel);
    expect(panel.chromosome, 'chr11');
    expect(panel.impact.wildtype, isNotEmpty);
    expect(panel.impact.estimated, isFalse);
    expect(panel.impact.ranked.length, 3);
    // The coordinate is the one the track resolved, not a guess.
    expect(
      panel.impact.genomic,
      _track.genomicOf(panel.impact.position),
    );
    expect(_coordinate, findsOneWidget);
    expect(
      (tester.widget<Text>(_coordinate).data)!.startsWith('chr11:'),
      isTrue,
    );
    expect(_level, findsOneWidget);
  });

  testWidgets('every substitution is a row, and the reference is not scored', (
    WidgetTester tester,
  ) async {
    await _openTranscript(tester);
    await _tapCell(tester, 30);

    final ImpactPanel panel = tester.widget<ImpactPanel>(_panel);
    for (final AltScore score in panel.impact.ranked) {
      expect(
        find.byKey(ValueKey<String>('impact-score-${score.base}')),
        findsOneWidget,
        reason: score.base,
      );
    }
    // The reference base carries a dash rather than a zero, which would read
    // as a measurement.
    expect(find.text('—'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('impact-score-${panel.impact.wildtype}')),
      findsNothing,
    );
  });

  testWidgets('another base swaps the sheet in place', (
    WidgetTester tester,
  ) async {
    await _openTranscript(tester);
    await _tapCell(tester, 30);
    final int first = tester.widget<ImpactPanel>(_panel).impact.position;

    await tester.tapAt(_cell(tester, 45));
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget, reason: 'no dismiss and reopen');
    expect(
      tester.widget<ImpactPanel>(_panel).impact.position,
      isNot(first),
    );
    expect(_painter(tester).maskedIndex, 45);
  });

  testWidgets('the same base again dismisses, and so does the close button', (
    WidgetTester tester,
  ) async {
    await _openTranscript(tester);
    await _tapCell(tester, 30);
    await tester.tapAt(_cell(tester, 30));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(_painter(tester).maskedIndex, isNull);

    await _tapCell(tester, 30);
    expect(_panel, findsOneWidget);
    await tester.tap(_close);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(_painter(tester).maskedIndex, isNull);
  });

  testWidgets('Back closes the sheet before leaving the page', (
    WidgetTester tester,
  ) async {
    await _openTranscript(tester);
    await _tapCell(tester, 30);
    expect(_panel, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(find.byType(AnatomyScreen), findsOneWidget);
  });

  testWidgets('a borrowed score is said to be borrowed', (
    WidgetTester tester,
  ) async {
    // A track with holes in it. The shipped ones have none, so this state is
    // only reachable on purpose — which is exactly why it is worth a test.
    final Map<String, dynamic> json =
        jsonDecode(File(ProteinCatalog.insulin.impactAsset).readAsStringSync())
            as Map<String, dynamic>;
    final Map<String, dynamic> positions =
        json['positions'] as Map<String, dynamic>;
    final int start = (json['start'] as num).toInt();
    json['positions'] = <String, dynamic>{
      for (final MapEntry<String, dynamic> e in positions.entries)
        if ((int.parse(e.key) - start) % 25 == 0) e.key: e.value,
    };
    await _openTranscript(
      tester,
      track: GeneImpact.fromJson(json, ProteinCatalog.insulin),
    );

    bool sawEstimate = false;
    for (int cell = 0; cell < 8 && !sawEstimate; cell++) {
      await _tapCell(tester, cell);
      if (_estimated.evaluate().isNotEmpty) {
        sawEstimate = true;
        final ImpactPanel panel = tester.widget<ImpactPanel>(_panel);
        expect(panel.impact.estimated, isTrue);
        expect(panel.impact.distance, greaterThan(0));
        expect(
          tester.widget<Text>(_estimated).data,
          contains('Estimated from position'),
        );
      }
    }
    expect(sawEstimate, isTrue, reason: 'a sparse track must borrow somewhere');
  });

  testWidgets('a gene with no track keeps the page it always had', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: AnatomyScreen(
          target: _untracked,
          record: insulin(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();

    await _tapCell(tester, 30);
    // No sheet, no mask, and the tracer answers as it always did.
    expect(_panel, findsNothing);
    expect(_painter(tester).maskedIndex, isNull);
    expect(_painter(tester).tracer, isNotNull);
  });

  testWidgets('the gene page answers a run with what the run scores', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: AnatomyScreen(
          target: ProteinCatalog.insulin,
          record: insulin(),
          impact: _track,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Still the gene page: a tap means the exon, not one of its bases.
    await tester.tapAt(_cell(tester, 30));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(
      find.textContaining(RegExp(r'AVI median \d+\.\d+ · peak \d+\.\d+')),
      findsOneWidget,
    );
  });

  testWidgets('a tap asks nothing of anyone: the scores are already here', (
    WidgetTester tester,
  ) async {
    // The point of baking the tracks. With animations off there is no beat to
    // wait out, so if a single frame produces a fully scored sheet then nothing
    // between the tap and the sheet was awaited — no bundle read, and certainly
    // no call to the Atlas.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AnatomyScreen(
            target: ProteinCatalog.insulin,
            record: insulin(),
            impact: _track,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(_cell(tester, 30));
    await tester.pump();
    expect(_panel, findsOneWidget, reason: 'the sheet is up in one frame');
    final ImpactPanel panel = tester.widget<ImpactPanel>(_panel);
    expect(panel.impact.ranked.length, 3);
    expect(panel.impact.estimated, isFalse);
    expect(find.byType(FutureBuilder<Object?>), findsNothing);

    // And every other base answers just as immediately.
    for (final int cell in <int>[5, 60, 120, 240]) {
      await tester.tapAt(_cell(tester, cell));
      await tester.pump();
      expect(_panel, findsOneWidget, reason: 'cell \$cell');
      expect(
        tester.widget<ImpactPanel>(_panel).impact.ranked.length,
        3,
        reason: 'cell \$cell',
      );
    }
  });

  group('an opened region', () {
    /// Opens the gene page, selects a region and opens it into its DNA.
    Future<void> openDna(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          debugShowCheckedModeBanner: false,
          home: AnatomyScreen(
            target: ProteinCatalog.insulin,
            record: insulin(),
            impact: _track,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(_cell(tester, 900));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('open-dna')));
      await tester.pumpAndSettle();
    }

    final Finder dnaCanvas = find.byType(AnatomySelectionCanvas);

    Future<void> tapBase(WidgetTester tester) async {
      await tester.tapAt(
        tester.getRect(dnaCanvas).topLeft + const Offset(60, 60),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle();
    }

    testWidgets('a lifted base opens the sheet', (WidgetTester tester) async {
      await openDna(tester);
      expect(dnaCanvas, findsOneWidget);
      expect(_panel, findsNothing);

      await tapBase(tester);
      expect(_panel, findsOneWidget);
      final ImpactPanel panel = tester.widget<ImpactPanel>(_panel);
      expect(panel.impact.ranked.length, 3);
      expect(panel.chromosome, 'chr11');
    });

    testWidgets('closing the sheet leaves the bases on screen', (
      WidgetTester tester,
    ) async {
      // The regression this group exists for. The tracer on this page is the
      // region the gene page selected, not the base the sheet is about, and
      // `AnatomySelectionCanvas` is built around it — clearing it on dismiss
      // took the whole grid out, which a release build draws as a grey box.
      await openDna(tester);
      await tapBase(tester);
      expect(_panel, findsOneWidget);

      await tester.tap(_close);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_panel, findsNothing);
      expect(dnaCanvas, findsOneWidget, reason: 'the page is still drawn');
      // And it still answers a tap afterwards.
      await tapBase(tester);
      expect(_panel, findsOneWidget);
    });

    testWidgets('Back and Escape leave the bases on screen too', (
      WidgetTester tester,
    ) async {
      await openDna(tester);
      await tapBase(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(dnaCanvas, findsOneWidget);

      await tapBase(tester);
      expect(_panel, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(dnaCanvas, findsOneWidget);
    });

    testWidgets('returning to the gene still works after a dismissal', (
      WidgetTester tester,
    ) async {
      await openDna(tester);
      await tapBase(tester);
      await tester.tap(_close);
      await tester.pumpAndSettle();

      // With nothing open, Escape means leave the region — and it can only
      // mean that once the sheet has gone, which is the ordering under test.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(dnaCanvas, findsNothing);
      expect(_paintBox, findsWidgets, reason: 'back on the gene page');
    });
  });

  testWidgets('no sheet survives a swipe to another molecule stage', (
    WidgetTester tester,
  ) async {
    await _openTranscript(tester);
    await _tapCell(tester, 30);
    expect(_panel, findsOneWidget);

    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });
}
