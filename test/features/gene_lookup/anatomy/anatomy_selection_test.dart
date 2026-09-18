import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_layout.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_ruler.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_scene.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_selection.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import 'anatomy_fixture.dart';

const Key _captureKey = ValueKey<String>('selection-capture');
Finder _paint() => find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is AnatomyPainter,
);
AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint()).painter! as AnatomyPainter;

Finder _lift() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is CustomPaint && widget.painter is LiftedBasePainter,
);
LiftedBasePainter _lifter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_lift()).painter! as LiftedBasePainter;

/// The roles a ribosome reads. A region of any other kind is never in frame.
const Set<RoleKind> _translated = <RoleKind>{
  RoleKind.signalPeptide,
  RoleKind.coding,
  RoleKind.maturePeptide,
  RoleKind.dibasic,
  RoleKind.trimmed,
  RoleKind.startCodon,
  RoleKind.stopCodon,
};

/// The first base of insulin's C-peptide: 93 bases in two pieces, read in
/// threes across the intron that splits them.
int _cPeptide(WidgetTester tester) {
  final AnatomyStage gene = _painter(tester).scene.from;
  return gene.positionAt(
    gene.runs.firstWhere((StageRun run) => run.label == 'C-peptide').start,
  );
}

/// Taps base [cell] of the open DNA where it is drawn at rest.
Future<void> _tapBase(WidgetTester tester, int cell) async {
  final Rect box = tester.getRect(_paint());
  await tester.tapAt(
    box.topLeft + _painter(tester).scene.toLayout.centreOf(cell),
  );
  await tester.pumpAndSettle();
}

Future<void> _screen(
  WidgetTester tester, {
  double width = 390,
  bool reduced = false,
  double textScale = 1,
  ProteinTarget target = ProteinCatalog.insulin,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final record = GeneRecordDto.fromJson(
    jsonDecode(File(target.mockAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: AnatomyScreen(target: target, record: record),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _select(WidgetTester tester, int position) {
  // Exercise the screen's selection contract without hunting for a tiny source
  // cell on the page. Other screen tests cover physical hit testing.
  tester
      .widget<AnatomyCanvas>(find.byType(AnatomyCanvas))
      .onTapped(position, asRun: true);
}

/// Taps the strip's action that opens the selected region, and lands one frame
/// so the reveal's clock has taken its zero.
Future<void> _openAction(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open-dna')));
  await tester.pump();
}

Future<void> _open(WidgetTester tester, int position) async {
  _select(tester, position);
  await tester.pump();
  await _openAction(tester);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  final String? directory = Platform.environment['SELECTION_SHOT_DIR'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    image.dispose();
    File('$directory/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('all catalog features retain their exact DNA and genomic order', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      final record = GeneRecordDto.fromJson(
        jsonDecode(File(target.mockAsset).readAsStringSync())
            as Map<String, dynamic>,
      ).toEntity();
      final AnatomyModel model = AnatomyModel.derive(
        record,
        chain: target.chain,
      );
      final AnatomyStage gene = model.stages.first;
      for (final int feature
          in gene.runs.map((StageRun run) => run.feature).toSet()) {
        final StageRun run = gene.runs.firstWhere(
          (StageRun run) => run.feature == feature,
        );
        final AnatomySelection selection = AnatomySelection.of(
          model,
          gene.positionAt(run.start),
        );
        // Read in threes exactly where a ribosome reads it.
        final bool framed = selection.stage.blocks.single.framed;
        expect(
          framed,
          _translated.contains(run.kind),
          reason: '${target.slug}: ${run.label}',
        );
        final List<int> expected = <int>[
          for (int i = 0; i < gene.count; i++)
            if (gene.featureAt(i) == feature) i,
        ];
        expect(
          selection.stage.letters,
          expected.map((int i) => gene.letters[i]).join(),
        );
        expect(selection.stage.positions, expected.map(gene.positionAt));
        expect(selection.stage.letters.contains('U'), isFalse);
        for (int i = 0; i < selection.stage.count; i++) {
          expect(selection.stage.cellAt(selection.stage.positionAt(i)), i);
          // The frame's two ends are the transcript's to mark, not a region's,
          // and a region forms its codons on a groove of its own.
          expect(selection.stage.codonMarkAt(i), CodonMark.none);
          expect(selection.stage.codonCellsAt(i), isEmpty);
        }
        final AnatomyLayout layout = AnatomyLayout.forStage(
          selection.stage,
          const Size(390, 660),
          const Size(390, 660),
        );
        expect(layout.side, greaterThan(AnatomyLayout.baseSide));
        if (!framed) {
          expect(
            layout.side,
            greaterThanOrEqualTo(AnatomyLayout.inspectionSide),
          );
        }
        expect(layout.columns % 3 == 0 || !framed, isTrue);
        expect(
          layout.radius / layout.side,
          closeTo(AnatomyLayout.tileRadiusRatio, 1e-9),
        );
        // The grid, grooves and all, fills the width between the gutters and
        // beside the ruler.
        expect(
          layout.size.width + layout.gap,
          closeTo(
            390 -
                2 * AnatomyLayout.inspectionGutter -
                AnatomyRuler.gutterFor(selection.stage),
            1e-9,
          ),
          reason: '${target.slug}: ${run.label}',
        );
        expect(layout.serpentine, isFalse);
        expect(layout.foldTo.every((int end) => end == 0), isTrue);
      }
    }
  });

  testWidgets(
    'holds the highlight until asked, then joins and reveals DNA in 700ms',
    (tester) async {
      await _screen(tester);
      await _shot(tester, 'gene');
      final AnatomyStage gene = _painter(tester).scene.from;
      final StageRun utr = gene.runs.firstWhere(
        (StageRun run) => run.kind == RoleKind.utr5,
      );
      _select(tester, gene.positionAt(utr.start));
      await tester.pump();
      expect(_painter(tester).tracer!.asRun, isTrue);
      // Nothing opens by itself: the page stays the gene for as long as the
      // reader is reading, and says what the region is.
      expect(find.text('Whole gene'), findsNothing);
      expect(find.byKey(const ValueKey<String>('open-dna')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(AnatomySelectionCanvas), findsNothing);
      await _shot(tester, 'highlight');
      await _openAction(tester);
      expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
      expect(find.text('Whole gene'), findsOneWidget);
      final AnatomyScene scene = _painter(tester).scene;
      expect(scene.to.count, 59);
      expect(scene.to.kind, StageKind.dna);
      expect(scene.target.where((int landing) => landing >= 0).length, 59);
      for (int i = 0; i < gene.count; i++) {
        expect(scene.positionOf(i, 0), scene.fromLayout.centreOf(i));
        if (scene.target[i] >= 0) {
          expect(
            (scene.positionOf(i, 1) - scene.toLayout.centreOf(scene.target[i]))
                .distance,
            lessThan(1e-8),
          );
        }
      }
      for (final String frame in <String>[
        'reveal-175ms',
        'reveal-350ms',
        'reveal-525ms',
        'dna',
      ]) {
        await tester.pump(const Duration(milliseconds: 175));
        await _shot(tester, frame);
      }
      // An animation completes only once its elapsed time is past its
      // duration, and the resting scene is built on the frame after that.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(_painter(tester).scene.isTransition, isFalse);
      await _shot(tester, 'settled-dna');
      expect(find.text('59'), findsOneWidget);
      expect(find.textContaining('2 pieces joined'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Whole gene'));
      await tester.pumpAndSettle();
      expect(find.byType(AnatomyCanvas), findsOneWidget);
      expect(find.text('1,431'), findsOneWidget);
      expect(_painter(tester).tracer, isNull);
    },
  );

  testWidgets('the action announces itself, once per region named', (
    tester,
  ) async {
    double labelOpacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('open-dna')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    await _screen(tester);
    _select(tester, 6000);
    await tester.pump();
    // The highlight it lands in: the tint is at its strongest and the label
    // has not arrived.
    expect(labelOpacity(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(labelOpacity(), 1);

    // A second region picked without letting go of the first leaves the action
    // on screen, so it is replayed rather than remounted.
    _select(tester, 5301);
    await tester.pump();
    expect(labelOpacity(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(labelOpacity(), 1);
  });

  testWidgets('a second tap lets go, and a new region replaces the old', (
    tester,
  ) async {
    await _screen(tester);
    _select(tester, 6000);
    await tester.pump();
    _select(tester, 6100);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AnatomySelectionCanvas), findsNothing);
    expect(find.byKey(const ValueKey<String>('open-dna')), findsNothing);
    _select(tester, 6000);
    await tester.pump();
    _select(tester, 5301);
    await tester.pump();
    expect(find.byType(AnatomySelectionCanvas), findsNothing);
    await _openAction(tester);
    await tester.pumpAndSettle();
    expect(_painter(tester).scene.from.count, 90);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AnatomyCanvas), findsOneWidget);
  });

  testWidgets('back reverses the current frame and keeps the gene route', (
    tester,
  ) async {
    await _screen(tester);
    _select(tester, 6000);
    await tester.pump();
    await _openAction(tester);
    await tester.pump(const Duration(milliseconds: 280));
    final double progress = _painter(tester).progress.value;
    final Offset point = _painter(tester).scene.positionOf(700, progress);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_painter(tester).progress.value, progress);
    expect(_painter(tester).scene.positionOf(700, progress), point);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_painter(tester).progress.value, lessThan(progress));
    await tester.pumpAndSettle();
    expect(find.byType(AnatomyScreen), findsOneWidget);
    expect(find.byType(AnatomyCanvas), findsOneWidget);
  });

  testWidgets('long detail scrolls; returning preserves the scrolled gene', (
    tester,
  ) async {
    await _screen(tester, target: ProteinCatalog.dystrophin);
    ScrollPosition scroll() =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    scroll().jumpTo(300);
    await tester.pump();
    final AnatomyStage gene = _painter(tester).scene.from;
    // The 3' UTR: 2,691 bases, where a coding exon is now its own few hundred.
    final StageRun utr3 = gene.runs.firstWhere(
      (StageRun run) => run.kind == RoleKind.utr3,
    );
    await _open(tester, gene.positionAt(utr3.start));
    expect(scroll().pixels, 0);
    expect(scroll().maxScrollExtent, greaterThan(1000));
    await tester.dragFrom(const Offset(190, 580), const Offset(0, -220));
    await tester.pumpAndSettle();
    final double detailOffset = scroll().pixels;
    expect(detailOffset, greaterThan(0));
    await tester.tap(find.text('Whole gene'));
    await tester.pump();
    expect(_painter(tester).scene.toLayout.origin.dy, -detailOffset);
    await tester.pumpAndSettle();
    expect(scroll().pixels, closeTo(300, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion and a narrow enlarged-text header remain usable',
    (tester) async {
      await _screen(tester, width: 320, reduced: true, textScale: 1.5);
      await _open(tester, 6000);
      expect(_painter(tester).scene.isTransition, isFalse);
      expect(_painter(tester).scene.from.count, 787);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Whole gene'))
            .didExceedMaxLines,
        isFalse,
      );
      await _shot(tester, 'narrow-dna');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Whole gene'));
      await tester.pump();
      expect(find.byType(AnatomyCanvas), findsOneWidget);
    },
  );

  testWidgets('a tapped base lifts, and a second tap sets it down', (
    tester,
  ) async {
    await _screen(tester);
    await _open(tester, 6000);
    expect(_lift(), findsOneWidget);
    expect(_lifter(tester).cell.value, isNull);

    await _tapBase(tester, 20);
    expect(_lifter(tester).cell.value, 20);
    expect(_lifter(tester).lift.value, 1);
    await _shot(tester, 'lifted-base');

    await _tapBase(tester, 21);
    expect(_lifter(tester).cell.value, 21);
    await _tapBase(tester, 21);
    expect(_lifter(tester).cell.value, isNull);

    // Empty space sets a lifted base down too: here, the gutter beside it.
    await _tapBase(tester, 20);
    final Rect box = tester.getRect(_paint());
    final Offset base = _painter(tester).scene.toLayout.centreOf(20);
    await tester.tapAt(
      Offset(box.left + AnatomyLayout.inspectionGutter / 2, box.top + base.dy),
    );
    await tester.pumpAndSettle();
    expect(_lifter(tester).cell.value, isNull);

    // A lifted base does not ride the return to the whole gene.
    await _tapBase(tester, 20);
    await tester.tap(find.text('Whole gene'));
    await tester.pump();
    expect(_lift(), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(AnatomyCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a base cannot be lifted while the DNA is still arriving', (
    tester,
  ) async {
    await _screen(tester);
    _select(tester, 6000);
    await tester.pump();
    await _openAction(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
    expect(_lift(), findsNothing);
    final Rect box = tester.getRect(_paint());
    await tester.tapAt(
      box.topLeft + _painter(tester).scene.toLayout.centreOf(20),
    );
    await tester.pumpAndSettle();
    expect(_lifter(tester).cell.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion a base is lifted at once', (tester) async {
    await _screen(tester, reduced: true);
    await _open(tester, 6000);
    final Rect box = tester.getRect(_paint());
    await tester.tapAt(
      box.topLeft + _painter(tester).scene.toLayout.centreOf(20),
    );
    expect(_lifter(tester).cell.value, 20);
    expect(_lifter(tester).lift.value, 1);
  });

  testWidgets('a coding region forms its codons once its DNA has landed', (
    tester,
  ) async {
    await _screen(tester);
    _select(tester, _cPeptide(tester));
    await tester.pump();
    await _openAction(tester);
    await tester.pump(const Duration(milliseconds: 350));
    // Travelling in, flush: the reveal is the only thing moving.
    expect(_painter(tester).scene.isTransition, isTrue);
    expect(_painter(tester).scene.to.blocks.single.framed, isTrue);
    expect(_painter(tester).scene.toLayout.codonOpen, 0);
    expect(_painter(tester).groove.value, 0);

    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).scene.isTransition, isFalse);
    expect(_painter(tester).groove.value, 0);
    await tester.pump(const Duration(milliseconds: 350));
    expect(_painter(tester).groove.value, closeTo(0.5, 1e-9));
    await _shot(tester, 'codons-forming');
    await tester.pumpAndSettle();
    expect(_painter(tester).groove.value, 1);
    await _shot(tester, 'codons-formed');

    // A tap finds the base where the formed codons put it.
    await _tapBase(tester, 40);
    expect(_lifter(tester).cell.value, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a region that is never translated forms nothing', (
    tester,
  ) async {
    await _screen(tester);
    await _open(tester, 6000);
    expect(_painter(tester).scene.to.blocks.single.framed, isFalse);
    expect(_painter(tester).groove.value, 1);
  });

  testWidgets('a return leaves from wherever the codons had got to', (
    tester,
  ) async {
    await _screen(tester);
    _select(tester, _cPeptide(tester));
    await tester.pump();
    await _openAction(tester);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump(const Duration(milliseconds: 350));
    final double formed = _painter(tester).groove.value;
    expect(formed, closeTo(0.5, 1e-9));
    await tester.tap(find.text('Whole gene'));
    await tester.pump();
    expect(_painter(tester).scene.isTransition, isTrue);
    expect(_painter(tester).scene.toLayout.codonOpen, formed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).groove.value, formed);
    await tester.pumpAndSettle();
    expect(find.byType(AnatomyCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion a coding region arrives formed', (
    tester,
  ) async {
    await _screen(tester, reduced: true);
    await _open(tester, _cPeptide(tester));
    expect(_painter(tester).scene.isTransition, isFalse);
    expect(_painter(tester).groove.value, 1);
  });

  testWidgets('leaving the gene lets go of a selected region', (tester) async {
    await _screen(tester);
    _select(tester, 6000);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.dragFrom(const Offset(230, 800), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AnatomySelectionCanvas), findsNothing);
    expect(find.text('465'), findsOneWidget);
  });

  testWidgets('a lifted base says where it is, and joins are marked', (
    tester,
  ) async {
    await _screen(tester, reduced: true);
    await _open(tester, _cPeptide(tester));
    final AnatomyPainter painter = _painter(tester);
    // Two pieces, joined where intron 2 was: one mark, at the second's start.
    expect(painter.junctions, hasLength(1));
    final int join = painter.junctions.single;
    expect(join, greaterThan(0));
    expect(join, lessThan(93));

    await _tapBase(tester, 0);
    expect(
      find.textContaining(RegExp(r'^c\.169 · [ACGT] · exon 2$')),
      findsOneWidget,
    );
    expect(find.text('codon 57 · GAG · Glu57'), findsOneWidget);

    // A base on the far side of the join is in the next exon.
    await _tapBase(tester, join);
    expect(
      find.textContaining(RegExp(r'^c\.\d+ · [ACGT] · exon 3$')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
