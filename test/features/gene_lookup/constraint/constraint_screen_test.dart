import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_toolbar.dart';
import 'package:helixpeek/features/gene_lookup/presentation/format.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/score_bar.dart';

import '../anatomy/anatomy_fixture.dart';

final ProteinConstraint _data = ProteinConstraint.fromJson(
  jsonDecode(File(ProteinCatalog.insulin.constraintAsset).readAsStringSync())
      as Map<String, dynamic>,
  ProteinCatalog.insulin,
);

Finder get _paintBox => find.byWidgetPredicate(
  (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
);
AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paintBox).painter! as AnatomyPainter;

Finder get _sheetSurface =>
    find.byKey(const ValueKey<String>('constraint-sheet-surface'));
Finder get _handle =>
    find.byKey(const ValueKey<String>('constraint-sheet-handle'));
Finder get _sheetScroll =>
    find.byKey(const ValueKey<String>('constraint-panel-scroll'));
DraggableScrollableController _sheetController(WidgetTester tester) =>
    tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).controller;
ScrollPosition _contentPosition(WidgetTester tester) =>
    tester.widget<CustomScrollView>(_sheetScroll).controller!.position;

Future<void> _reveal(WidgetTester tester) async {
  await _open(tester);
  await _tap(tester, 30);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  bool reduced = false,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('capture'),
      child: MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: AnatomyScreen(target: ProteinCatalog.insulin, record: insulin(), constraint: _data),
        ),
      ),
    ),
  );
  for (int i = 0; i < 2; i++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
  expect(_painter(tester).constraint, same(_data));
}

Offset _cell(WidgetTester tester, int index) =>
    tester.getRect(_paintBox).topLeft +
    _painter(tester).scene.fromLayout.centreOf(index);

Future<void> _tap(WidgetTester tester, int index) async {
  await tester.tapAt(_cell(tester, index));
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final String? folder = Platform.environment['SHOT_DIR'];
  if (folder == null) {
    return;
  }
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(const ValueKey<String>('capture')),
  );
  await tester.runAsync(() async {
    final ui.Image shot = await boundary.toImage(pixelRatio: 2);
    final ByteData bytes = (await shot.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    Directory(folder).createSync(recursive: true);
    File('$folder/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    shot.dispose();
  });
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('loads the shipped scores through the local asset bundle', (
    WidgetTester tester,
  ) async {
    final ProteinConstraint? loaded = await tester.runAsync(
      () => ProteinConstraint.load(ProteinCatalog.insulin),
    );
    expect(loaded!.positions.length, 110);
    expect(loaded.positions[30].ranked[1].score, -10.253);
  });

  testWidgets('an unscored protein page has no toolbar and loads no track', (
    WidgetTester tester,
  ) async {
    // Every catalog protein is scored, so the state a row is in before its
    // track is baked is held here rather than by the catalog walk. The slug is
    // insulin's on purpose: a screen that ignored `scored` would find the real
    // track, load it, and draw the toolbar.
    const ProteinTarget scored = ProteinCatalog.insulin;
    final ProteinTarget unscored = ProteinTarget(
      slug: scored.slug,
      display: scored.display,
      gene: scored.gene,
      uniprot: scored.uniprot,
      accession: scored.accession,
      summary: scored.summary,
      facts: scored.facts,
      chains: scored.chains,
      structure: scored.structure,
      scored: false,
      // Held to the one state under test; the walk's ClinVar is its own.
      clinvarAvailable: false,
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: AnatomyScreen(target: unscored, record: insulin()),
      ),
    );
    for (int i = 0; i < 2; i++) {
      final Rect screen = tester.getRect(find.byType(AnatomyScreen));
      await tester.dragFrom(
        Offset(screen.center.dx, screen.bottom - 40),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
    }
    // A load, had one started, finishes on the real event loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(_painter(tester).constraint, isNull);
    expect(find.byType(ConstraintToolbar), findsNothing);
    expect(find.text('ESM-2 scores unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'handle expands the sheet; content scrolls with the header pinned',
    (WidgetTester tester) async {
      await _reveal(tester);
      expect(_sheetController(tester).size, ConstraintPanel.initialSize);
      await _capture(tester, 'sheet-medium');
      await tester.drag(_handle, const Offset(0, -170));
      await tester.pumpAndSettle();
      expect(
        _sheetController(tester).size,
        closeTo(ConstraintPanel.maximumSize, 0.001),
      );
      await tester.tap(find.byKey(const ValueKey<String>('constraint-expand')));
      await tester.pumpAndSettle();
      final Rect headerBefore = tester.getRect(find.text('Cys31 · B7'));
      final Rect sheet = tester.getRect(_sheetSurface);
      await tester.dragFrom(
        Offset(sheet.center.dx, sheet.bottom - 65),
        const Offset(0, -330),
      );
      await tester.pumpAndSettle();
      expect(_contentPosition(tester).pixels, greaterThan(100));
      expect(tester.getRect(find.text('Cys31 · B7')), headerBefore);
      expect(_handle.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.byType(SubstitutionBar).last).bottom,
        lessThan(sheet.bottom),
      );
      await _capture(tester, 'sheet-expanded-scrolled');

      final double offsetBefore = _contentPosition(tester).pixels;
      await tester.dragFrom(
        Offset(sheet.center.dx, sheet.bottom - 100),
        const Offset(0, 60),
      );
      await tester.pumpAndSettle();
      expect(_contentPosition(tester).pixels, lessThan(offsetBefore));
      expect(
        _sheetController(tester).size,
        closeTo(ConstraintPanel.maximumSize, 0.001),
      );

      // A handle drag resizes even when the score list is not at its top.
      await tester.drag(_handle, const Offset(0, 140));
      await tester.pumpAndSettle();
      expect(
        _sheetController(tester).size,
        closeTo(ConstraintPanel.initialSize, 0.001),
      );
      expect(_contentPosition(tester).pixels, greaterThan(0));
      await tester.tap(find.byTooltip('About these scores'));
      await tester.pumpAndSettle();
      expect(_contentPosition(tester).pixels, 0);
      expect(
        _sheetController(tester).size,
        closeTo(ConstraintPanel.initialSize, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'content drag expands before scrolling and collapses from the top',
    (WidgetTester tester) async {
      await _reveal(tester);
      final Rect sheet = tester.getRect(_sheetSurface);
      final TestGesture drag = await tester.startGesture(
        Offset(sheet.center.dx, sheet.bottom - 60),
      );
      await drag.moveBy(const Offset(0, -20)); // Win the vertical gesture.
      await tester.pump();
      await drag.moveBy(
        Offset(0, -sheet.height / ConstraintPanel.initialSize * 0.2),
      );
      await tester.pump();
      expect(
        _sheetController(tester).size,
        greaterThan(ConstraintPanel.initialSize),
      );
      expect(_contentPosition(tester).pixels, 0);
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        _sheetController(tester).size,
        closeTo(ConstraintPanel.maximumSize, 0.001),
      );
      expect(_contentPosition(tester).pixels, 0);
      final Rect expanded = tester.getRect(_sheetSurface);
      await tester.dragFrom(
        Offset(expanded.center.dx, expanded.top + 190),
        const Offset(0, 160),
      );
      await tester.pumpAndSettle();
      expect(
        _sheetController(tester).size,
        closeTo(ConstraintPanel.initialSize, 0.001),
      );
    },
  );

  testWidgets('compact stop preserves comparisons; a second drag dismisses', (
    WidgetTester tester,
  ) async {
    await _reveal(tester);
    await tester.drag(_handle, const Offset(0, 260));
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsOneWidget);
    final double compact = _sheetController(tester).size;
    expect(compact, lessThan(ConstraintPanel.initialSize));
    expect(find.text('Cys31 · B7').hitTestable(), findsOneWidget);
    expect(
      find.text(_data.positions[30].level.label).hitTestable(),
      findsOneWidget,
    );
    await _capture(tester, 'sheet-compact');
    await _tap(tester, 31);
    await tester.pumpAndSettle();
    expect(find.text('Gly32 · B8').hitTestable(), findsOneWidget);
    expect(_sheetController(tester).size, closeTo(compact, 0.001));
    await tester.drag(_handle, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsNothing);
    expect(_painter(tester).maskedIndex, isNull);
    expect(_painter(tester).masking!.value, 0);
    await _tap(tester, 108);
    await tester.pumpAndSettle();
    expect(find.text('Cys109 · A20'), findsOneWidget);
    expect(_sheetController(tester).size, ConstraintPanel.initialSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the content down from its top dismisses the sheet', (
    WidgetTester tester,
  ) async {
    await _reveal(tester);
    final Rect sheet = tester.getRect(_sheetSurface);
    await tester.dragFrom(
      Offset(sheet.center.dx, sheet.top + 180),
      const Offset(0, 360),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsOneWidget);
    final Rect compact = tester.getRect(_sheetSurface);
    await tester.dragFrom(
      Offset(compact.center.dx, compact.top + 100),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsNothing);
    expect(_painter(tester).maskedIndex, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drag, Back and Escape dismiss the sheet before leaving the screen',
    (WidgetTester tester) async {
      await _reveal(tester);
      await tester.drag(_handle, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byType(ConstraintPanel), findsOneWidget);
      await tester.drag(_handle, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(find.byType(ConstraintPanel), findsNothing);
      expect(_painter(tester).maskedIndex, isNull);

      await _tap(tester, 30);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AnatomyScreen), findsOneWidget);
      expect(find.byType(ConstraintPanel), findsNothing);

      await _tap(tester, 30);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ConstraintPanel), findsNothing);
      expect(_painter(tester).maskedIndex, isNull);

      // Back during the introductory mask also cancels its pending reveal.
      await _tap(tester, 30);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AnatomyScreen), findsOneWidget);
      expect(find.byType(ConstraintPanel), findsNothing);
    },
  );

  testWidgets(
    'a new tap interrupts dismissal without clearing the new selection',
    (WidgetTester tester) async {
      await _reveal(tester);
      final State<StatefulWidget> state = tester.state(
        find.byType(ConstraintPanel),
      );
      await tester.drag(_handle, const Offset(0, 600));
      await tester.pumpAndSettle();
      await tester.drag(_handle, const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 60));
      await _tap(tester, 31);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ConstraintPanel)), same(state));
      expect(find.text('Gly32 · B8'), findsOneWidget);
      expect(_painter(tester).maskedIndex, 31);
      expect(_painter(tester).masking!.value, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Gly32 · B8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sheet height and expanded ranking survive comparisons', (
    WidgetTester tester,
  ) async {
    await _reveal(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('constraint-expand')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('constraint-expand')));
    await tester.pumpAndSettle();
    _sheetController(tester).jumpTo(0.7);
    await tester.pumpAndSettle();
    await _tap(tester, 31);
    await tester.pumpAndSettle();
    expect(_sheetController(tester).size, closeTo(0.7, 0.001));
    expect(_contentPosition(tester).pixels, 0);
    expect(find.byType(SubstitutionBar), findsNWidgets(20));
    expect(find.text('Gly32 · B8'), findsOneWidget);
  });

  testWidgets(
    'horizontal sheet gestures do not navigate to another molecule stage',
    (WidgetTester tester) async {
      await _reveal(tester);
      await tester.fling(_sheetSurface, const Offset(-180, 0), 900);
      await tester.pumpAndSettle();
      expect(find.text('110'), findsOneWidget);
      expect(find.text('Cys31 · B7'), findsOneWidget);
    },
  );

  testWidgets(
    'every precursor position is tappable while the panel stays open',
    (WidgetTester tester) async {
      await _open(tester, reduced: true);
      State<StatefulWidget>? panelState;
      for (int index = 0; index < 110; index++) {
        if (panelState != null) {
          final ScrollableState grid = tester.state<ScrollableState>(
            find
                .ancestor(of: _paintBox, matching: find.byType(Scrollable))
                .first,
          );
          final double panelTop = tester
              .getRect(find.byType(ConstraintPanel))
              .top;
          final double delta = _cell(tester, index).dy - (panelTop - 65);
          if (delta > 0) {
            grid.position.jumpTo(
              (grid.position.pixels + delta).clamp(
                0.0,
                grid.position.maxScrollExtent,
              ),
            );
            await tester.pump();
          }
        }
        await _tap(tester, index);
        await tester.pumpAndSettle();
        expect(_painter(tester).maskedIndex, index);
        expect(
          tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue,
          same(_data.positions[index]),
        );
        panelState ??= tester.state(find.byType(ConstraintPanel));
        expect(tester.state(find.byType(ConstraintPanel)), same(panelState));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mask holds for 300ms then reveals real scores; comparison stays in place',
    (WidgetTester tester) async {
      await _open(tester);
      final int initialBarriers = find.byType(ModalBarrier).evaluate().length;
      await _capture(tester, 'protein-rest');
      await _tap(tester, 30);
      expect(_painter(tester).maskedIndex, 30);
      expect(find.byType(ConstraintPanel), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ConstraintPanel), findsNothing);
      expect(_painter(tester).masking!.value, closeTo(2 / 3, 0.01));
      await _capture(tester, 'protein-mask');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Cys31 · B7'), findsOneWidget);
      expect(find.text('B chain · S–S Cys96 (A7)'), findsOneWidget);
      expect(find.byType(SubstitutionBar), findsNWidgets(6));
      expect(
        tester
            .widgetList<SubstitutionBar>(find.byType(SubstitutionBar))
            .map((SubstitutionBar b) => b.score.score),
        _data.positions[30].ranked
            .take(6)
            .map((SubstitutionScore s) => s.score),
      );
      expect(find.byType(ModalBarrier), findsNWidgets(initialBarriers));
      await _capture(tester, 'protein-cysteine');
      final State<StatefulWidget> panel = tester.state(
        find.byType(ConstraintPanel),
      );
      await _tap(tester, 31);
      expect(_painter(tester).maskedIndex, 31);
      expect(_painter(tester).masking!.value, 1);
      expect(tester.state(find.byType(ConstraintPanel)), same(panel));
      await tester.pumpAndSettle();
      expect(find.text('Gly32 · B8'), findsOneWidget);
      expect(find.text('Cys31 · B7'), findsNothing);
    },
  );

  testWidgets(
    'rapid taps reveal the latest residue; leaving cancels the reveal',
    (WidgetTester tester) async {
      await _open(tester);
      await _tap(tester, 30);
      await tester.pump(const Duration(milliseconds: 100));
      await _tap(tester, 31);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ConstraintPanel), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Gly32 · B8'), findsOneWidget);
      await _tap(tester, 31); // Same residue restores the resting grid.
      await tester.pumpAndSettle();
      expect(find.byType(ConstraintPanel), findsNothing);
      await _tap(tester, 30);
      final Rect screen = tester.getRect(find.byType(AnatomyScreen));
      await tester.dragFrom(
        Offset(screen.center.dx, screen.bottom - 40),
        const Offset(160, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConstraintPanel), findsNothing);
      expect(find.text('465'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the scale says it is clamped at both ends, over the bars', (
    WidgetTester tester,
  ) async {
    // A narrow phone with type turned up is where the two ends meet: there
    // they are drawn smaller rather than run past the bars.
    for (final (Size size, double scale) in <(Size, double)>[
      (const Size(390, 844), 1),
      (const Size(360, 800), 1.3),
      (const Size(320, 640), 1.5),
    ]) {
      await _open(tester, reduced: true, size: size, textScale: scale);
      await _tap(tester, 30);
      await tester.pumpAndSettle();
      final String at = '$size at $scale';
      expect(find.text('−10 or lower'), findsOneWidget, reason: at);
      final Rect bar = tester.getRect(
        find
            .descendant(of: find.byType(ScoreBar), matching: find.byType(Stack))
            .first,
      );
      expect(
        tester.getRect(find.text('−10 or lower')).left,
        closeTo(bar.left, 1),
        reason: at,
      );
      expect(
        tester.getRect(find.text('0 or higher')).right,
        closeTo(bar.right, 1),
        reason: at,
      );
      expect(tester.takeException(), isNull, reason: at);
    }
  });

  testWidgets('conservation only changes fills; all twenty scores expand', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    expect(find.text('Tap a residue'), findsNothing);
    final Rect toggleAtRest = tester.getRect(
      find.byKey(const ValueKey<String>('conservation-toggle')),
    );
    final List<Offset> original = <Offset>[
      for (int i = 0; i < 110; i++) _cell(tester, i),
    ];
    await tester.tap(find.byKey(const ValueKey<String>('conservation-toggle')));
    await tester.pumpAndSettle();
    expect(_painter(tester).conservation, isTrue);
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('conservation-toggle'))),
      toggleAtRest,
    );
    expect(find.text('low'), findsOneWidget);
    expect(find.text('high'), findsOneWidget);
    expect(<Offset>[for (int i = 0; i < 110; i++) _cell(tester, i)], original);
    await _capture(tester, 'protein-conservation');
    await _tap(tester, 70);
    await tester.pumpAndSettle();
    expect(find.text('tolerant'), findsOneWidget);
    expect(
      _cell(tester, 70).dy,
      lessThan(tester.getRect(find.byType(ConstraintPanel)).top),
    );
    await _capture(tester, 'protein-tolerant');
    final Finder expand = find.byKey(
      const ValueKey<String>('constraint-expand'),
    );
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(find.byType(SubstitutionBar), findsNWidgets(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('last residue stays reachable and the grid accepts another tap', (
    WidgetTester tester,
  ) async {
    await _open(tester, reduced: true);
    await _tap(tester, 109);
    await tester.pumpAndSettle();
    expect(find.text('Asn110 · A21'), findsOneWidget);
    final Rect panel = tester.getRect(find.byType(ConstraintPanel));
    expect(_cell(tester, 109).dy, lessThan(panel.top));
    await _tap(tester, 108);
    await tester.pumpAndSettle();
    expect(find.text('Cys109 · A20'), findsOneWidget);
    expect(find.text('A chain · S–S Cys43 (B19)'), findsOneWidget);
    await tester.dragFrom(Offset(190, panel.top - 70), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small phone with enlarged text remains scrollable without overflow',
    (WidgetTester tester) async {
      await _open(
        tester,
        reduced: true,
        size: const Size(320, 640),
        textScale: 1.3,
      );
      await _tap(tester, 30);
      await tester.pumpAndSettle();
      expect(find.byType(ConstraintPanel), findsOneWidget);
      await tester.tap(find.byTooltip('About these scores'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey<String>('constraint-panel-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final (String name, Size size, double scale) in <(String, Size, double)>[
    ('landscape', const Size(740, 390), 1),
    ('large-text', const Size(390, 844), 2),
  ]) {
    testWidgets('$name keeps long content and dismissal accessible', (
      WidgetTester tester,
    ) async {
      await _open(tester, reduced: true, size: size, textScale: scale);
      await _tap(tester, 30);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ConstraintPanel>(find.byType(ConstraintPanel))
            .pinIdentity,
        isFalse,
      );
      await tester.tap(_handle);
      await tester.pump();
      expect(_sheetController(tester).size, ConstraintPanel.maximumSize);
      final Finder expand = find.byKey(
        const ValueKey<String>('constraint-expand'),
      );
      await tester.ensureVisible(expand);
      await tester.pumpAndSettle();
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(find.byType(SubstitutionBar), findsNWidgets(20));
      for (final SubstitutionScore score in _data.positions[30].ranked) {
        final RenderParagraph number = tester.renderObject(
          find.byKey(ValueKey<String>('substitution-score-${score.aminoAcid}')),
        );
        expect(
          number.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: formatScore(score.score).length,
            ),
          ),
          hasLength(1),
          reason: 'A score must remain readable on one line at $scale× text.',
        );
      }
      final Finder note = find.text(_data.positions[30].note);
      await tester.ensureVisible(note);
      await tester.pumpAndSettle();
      expect(note.hitTestable(), findsOneWidget);
      expect(find.text('Cys31 · B7').hitTestable(), findsNothing);
      expect(_handle.hitTestable(), findsOneWidget);
      await _capture(tester, 'sheet-$name');
      await tester.drag(_handle, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byType(ConstraintPanel), findsOneWidget);
      await tester.drag(_handle, const Offset(0, 80));
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.byType(ConstraintPanel), findsNothing);
      expect(_painter(tester).maskedIndex, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('resizing the window preserves the selected residue and sheet', (
    WidgetTester tester,
  ) async {
    await _reveal(tester);
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(740, 390));
    await tester.pumpAndSettle();
    expect(find.text('Cys31 · B7'), findsOneWidget);
    expect(_sheetController(tester).size, ConstraintPanel.maximumSize);
    expect(_handle.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
