import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_layout.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_scene.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeak/features/gene_lookup/presentation/structure/structure_view.dart';

import 'anatomy_fixture.dart';

final ProteinConstraint _constraint = ProteinConstraint.fromJson(
  jsonDecode(File(ProteinCatalog.insulin.constraintAsset).readAsStringSync())
      as Map<String, dynamic>,
  ProteinCatalog.insulin,
);

const Size _phone = Size(390, 844);

/// Residue 26 of the preproprotein — valine, `GTG` at 5,299-5,301, in the
/// insulin B chain, and one of the few residues that survives every cut.
///
/// A tap resolves to a whole codon, so the tracer it creates sits on the
/// codon's *first* base. Naming that base here keeps the argument and the
/// tracer the same number.
const int _valine26 = 5299;

/// The first residue of the signal peptide, cut away at the proprotein.
///
/// Also the first base of the coding sequence, and so of the start codon: the
/// two are the same place, which is the reason the reading frame's ends are not
/// kept in the role table. See [CodonMark].
const int _signalStart = 5224;

/// The first base of the transcript's stop codon — `TAG` at 6,341-6,343, the
/// last three bases of the coding sequence and the last three of the mRNA that
/// the ribosome reads.
const int _stopCodon = 6341;

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: AnatomyScreen(target: ProteinCatalog.insulin, record: insulin(), constraint: _constraint),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The box the grid is actually painted in, which is taller than the canvas's
/// own viewport wherever the stage scrolls.
Finder _paintBox() => find.byWidgetPredicate(
  (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
);

AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paintBox()).painter! as AnatomyPainter;

Future<void> _swipeStructure(WidgetTester tester, {required bool forward}) =>
    _swipe(tester, forward: forward);

double _band(Size viewport) =>
    (viewport.height - TurnZone.sideIn(viewport)) / 2;

Future<void> _swipe(WidgetTester tester, {required bool forward}) async {
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    Offset(forward ? -160 : 160, 0),
  );
  await tester.pump();
}

/// Walks forward to [stage] from the gene, where the screen opens.
///
/// [_tapBase] computes its layout from the stage it is named, but taps the live
/// canvas — so the screen has to be showing that stage already.
Future<void> _toStage(WidgetTester tester, int stage) async {
  for (int i = 0; i < stage; i++) {
    await _swipe(tester, forward: true);
    await tester.pumpAndSettle();
  }
}

/// Taps the square holding a genomic coordinate, scrolling to it first.
///
/// The scroll is not incidental: at a 26pt pitch the transcript page is taller
/// than the phone, so its last codons are below the window until it is brought
/// to them. A test that tapped blind would be testing the window, not the page.
Future<void> _tapBase(WidgetTester tester, int stage, int position) async {
  final AnatomyModel model = AnatomyModel.derive(insulin());
  Rect rect = tester.getRect(_paintBox());
  final AnatomyLayout layout = AnatomyLayout.forStage(
    model.stages[stage],
    rect.size,
    rect.size,
  );
  final Offset centre = layout.centreOf(model.stages[stage].cellAt(position));
  final double top = rect.top + centre.dy;
  if (top < 0 || top > _phone.height - 80) {
    final Finder scroller = find.byType(Scrollable).first;
    if (scroller.evaluate().isNotEmpty) {
      await tester.drag(scroller, Offset(0, -(top - _phone.height / 2)));
      await tester.pumpAndSettle();
      rect = tester.getRect(_paintBox());
    }
  }
  await tester.tapAt(rect.topLeft + centre);
  await tester.pumpAndSettle();
}

/// The protein keeps its overview while the panel explains the masked residue.
const String _precursorSentence = 'signal peptide 1–24 · proinsulin 25–110';

/// The released chains' caption, which nothing on that page replaces.
const String _chainsSentence =
    'B chain (30) · C-peptide (31) · A chain (21) · cut at RR, KR';

/// The transcript page's caption.
const String _transcriptSentence = '5\u2032 UTR 59 · CDS 333 · 3\u2032 UTR 73 nt';

void main() {
  // The header's whole argument is that three lines of prose fit in 79 points,
  // and only the real fonts can settle that.
  setUpAll(loadAppFonts);

  group('navigation', () {
    testWidgets('vertical, diagonal and short drags do not turn pages', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      for (final Offset delta in <Offset>[
        const Offset(0, -160),
        const Offset(0, 160),
        const Offset(-75, -160),
        const Offset(-100, 100),
        const Offset(-30, 0),
      ]) {
        await tester.drag(find.byType(AnatomyCanvas), delta);
        await tester.pumpAndSettle();
        expect(find.text('1,431'), findsOneWidget);
      }
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(AnatomyCanvas)),
      );
      await gesture.moveBy(const Offset(0, 60));
      await gesture.moveBy(const Offset(-180, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('1,431'), findsOneWidget);

      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      final ScrollableState scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(AnatomyCanvas), const Offset(15, -180));
      await tester.pumpAndSettle();
      expect(find.text('465'), findsOneWidget);
      expect(scroll.position.pixels, greaterThan(0));
    });

    testWidgets('horizontal swipes walk the stages and stop at the ends', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      expect(find.text('1,431'), findsOneWidget);
      expect(find.text('bp'), findsOneWidget);
      expect(find.text('  ·  Insulin'), findsOneWidget);

      for (final String count in <String>['465', '110', '82']) {
        await _swipe(tester, forward: true);
        await tester.pumpAndSettle();
        expect(find.text(count), findsOneWidget);
      }

      // Off the last grid and onto the fold, which is a page of the same walk
      // without being a stage of it: 82 residues lying in a row become the 51
      // that are still attached to each other.
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(find.text('51'), findsOneWidget);
      expect(find.text('  ·  Insulin'), findsOneWidget);

      // The last page is the last page; another swipe is not a wrap.
      await _swipeStructure(tester, forward: true);
      await tester.pumpAndSettle();
      expect(find.text('51'), findsOneWidget);

      await _swipeStructure(tester, forward: false);
      await tester.pumpAndSettle();
      expect(find.text('82'), findsOneWidget);

      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
      expect(find.text('110'), findsOneWidget);
    });

    testWidgets('runs the same animation backwards, not a different one', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();

      await _swipe(tester, forward: false);
      final AnatomyPainter painter = _painter(tester);
      expect(painter.scene.fromIndex, 0);
      expect(painter.scene.toIndex, 1);
      expect(painter.reverse, isTrue);
      expect(painter.progress.value, 1);

      await tester.pumpAndSettle();
      expect(find.text('1,431'), findsOneWidget);
    });

    testWidgets('reduced motion jumps, and every stage stays reachable', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, reduceMotion: true);

      for (final String count in <String>['465', '110', '82']) {
        await _swipe(tester, forward: true);
        // No pumpAndSettle: with animations disabled the stage is simply there.
        await tester.pump();
        expect(find.text(count), findsOneWidget);
        expect(_painter(tester).scene.isTransition, isFalse);
      }
    });

    testWidgets('translation reverses from its current frame', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 1);
      await _swipe(tester, forward: true);
      await tester.pump(const Duration(milliseconds: 750));
      final AnatomyPainter before = _painter(tester);
      final AnatomyScene scene = before.scene;
      final double progress = before.progress.value;
      expect(progress, closeTo(0.5, 0.01));

      await _swipe(tester, forward: false);
      final AnatomyPainter after = _painter(tester);
      expect(identical(after.scene, scene), isTrue);
      expect(after.progress.value, progress);
      expect(after.reverse, isTrue);
      await tester.pump(const Duration(milliseconds: 150));
      expect(after.progress.value, lessThan(progress));
      await tester.pumpAndSettle();
      expect(find.text('465'), findsOneWidget);
      expect(_painter(tester).groove.value, 1);
    });

    testWidgets('translation retains the scrolled source and full canvas', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 1);
      await tester.drag(find.byType(AnatomyCanvas), const Offset(0, -200));
      await tester.pumpAndSettle();
      final ScrollPosition scroll = tester
          .widget<Scrollable>(find.byType(Scrollable))
          .controller!
          .position;
      final double offset = scroll.pixels;
      expect(offset, greaterThan(0));
      await _swipe(tester, forward: true);
      final AnatomyScene scene = _painter(tester).scene;
      expect(scene.translation!.sourceScrollOffset, offset);
      expect(tester.getSize(_paintBox()).height, scene.canvas.height);
      expect(
        scene.positionOf(59, 0).dy,
        closeTo(scene.fromLayout.centreOf(59).dy - offset, 1e-8),
      );

      await tester.pump(const Duration(milliseconds: 450));
      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
      expect(find.text('465'), findsOneWidget);
      expect(scroll.pixels, closeTo(offset, 0.01));
    });
  });

  group('the header', () {
    testWidgets('carries name, stage, count and summary in 96 points', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      // Everything the reader needs before the picture, and above it.
      //
      // Ninety-six and not a point more: the grid is the page and the chrome
      // above it is a budget — a 44pt row the back arrow can be hit in, and
      // the two lines of prose under it.
      final Rect header = tester.getRect(find.byType(AppBar));
      expect(header.height, lessThanOrEqualTo(96));

      for (final Finder piece in <Finder>[
        find.text('INS'),
        find.text('  ·  Insulin'),
        find.text('1,431'),
        find.text('bp'),
        find.text('3 exons · 2 introns'),
      ]) {
        expect(piece, findsOneWidget);
        expect(
          tester.getRect(piece).bottom,
          lessThanOrEqualTo(header.bottom),
          reason: 'the summary has to arrive before the map, not after it',
        );
      }
    });

    testWidgets('carries the back arrow once it has been pushed', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(_phone);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      AnatomyScreen(target: ProteinCatalog.insulin, record: insulin()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Navigation is the header's first job, and it is why this stayed an
      // `AppBar` rather than becoming a hand-rolled row.
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('1,431'), findsOneWidget);
    });

    testWidgets('never changes height, traced or untraced', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      final double resting = tester.getSize(find.byType(AppBar)).height;

      await _tapBase(tester, 0, 6000);
      expect(
        find.text('intron 2 · 787 bp · 55% of the gene'),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(AppBar)).height, resting);

      // ...and across every stage, whose sentences are not the same length.
      for (int i = 0; i < 4; i++) {
        await _swipe(tester, forward: true);
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(AppBar)).height, resting);
      }
    });

    testWidgets('gives every line of prose the room to finish', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      // The selected feature and its fact must both remain readable in the
      // fixed header, beside the action that opens its DNA.
      await _tapBase(tester, 0, 6000);
      for (final String text in <String>[
        'intron 2 · 787 bp · 55% of the gene',
        'GT…AG · phase 1',
      ]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(text))
              .didExceedMaxLines,
          isFalse,
          reason: '"$text" is being truncated in the header',
        );
      }

      // ...and so do the captions of the pages after it, untraced.
      await _tapBase(tester, 0, 6000);
      await _toStage(tester, 2);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(_precursorSentence))
            .didExceedMaxLines,
        isFalse,
      );

      // The fold's sentence is written to the same two lines, and it is the
      // one the reader is left on.
      await _toStage(tester, 2);
      expect(
        tester
            .renderObject<RenderParagraph>(
              find.text(
                'The C-peptide is cut out. '
                'Two disulfide bridges join A to B, a third folds A.',
              ),
            )
            .didExceedMaxLines,
        isFalse,
      );
    });
  });

  group('the paginator', () {
    testWidgets(
      'floats clear of the grid without chevrons and accepts swipes',
      (WidgetTester tester) async {
        await _pumpScreen(tester);

        // Where the pill sits: centred, a little off the bottom of the screen.
        final Rect body = tester.getRect(find.byType(AnatomyCanvas));
        final Offset pill = Offset(_phone.width / 2, _phone.height - 28);
        expect(
          body.bottom,
          lessThan(pill.dy),
          reason: 'a translucent thing over data still hides the data',
        );

        expect(find.byIcon(Icons.chevron_left), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        await tester.flingFrom(pill, const Offset(-180, 0), 900);
        await tester.pumpAndSettle();
        expect(find.text('465'), findsOneWidget);
        await tester.fling(
          find.byType(AnatomyCanvas),
          const Offset(-180, 0),
          900,
        );
        await tester.pumpAndSettle();
        expect(find.text('110'), findsOneWidget);
      },
    );
  });

  group('the fold', () {
    testWidgets('carries its own count and sentence, not a stage\'s', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 4);

      // The numbers are the crystal structure's, not the record's: the 31
      // residues of the C-peptide are gone, and 82 - 31 is the arithmetic the
      // page is about.
      expect(find.text('51'), findsOneWidget);
      expect(find.text('aa'), findsOneWidget);
      expect(find.text('  ·  Insulin'), findsOneWidget);
      // And where it comes from, under the sentence.
      expect(find.text('PDB 3I40'), findsOneWidget);
      expect(
        find.text(
          'The C-peptide is cut out. '
          'Two disulfide bridges join A to B, a third folds A.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('leaves a band of the page above the model and below it', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 4);

      // A sideways drag means two things on this page: turn the molecule, or
      // turn the page. The square in the middle is the model's and takes both
      // axes; what is left has to be enough of a strip to throw a swipe in, at
      // either end, or the fold is a page that cannot be left.
      final Size viewport = tester.getSize(find.byType(StructureView));
      expect(TurnZone.sideIn(viewport), viewport.width);
      expect(_band(viewport), greaterThan(44));

      // Where the height is what is scarce — a phone on its side — the square
      // is what gives way, not the page turn.
      const Size landscape = Size(700, 250);
      expect(TurnZone.sideIn(landscape), lessThan(landscape.height));
      expect(_band(landscape), greaterThan(44));
    });

    testWidgets('says so in place when there is no 3D to draw with', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 4);

      // Flutter GPU is opted into per platform and a headless test never has
      // it, which is exactly the state a device without the flag is in. The
      // page has to report that and leave the walk standing — the header, the
      // paginator and the four pages behind it all keep working.
      expect(
        find.text(
          'The structure needs 3D rendering, which is not available here.',
        ),
        findsOneWidget,
      );
      expect(find.text('51'), findsOneWidget);

      await _swipeStructure(tester, forward: false);
      await tester.pumpAndSettle();
      expect(find.text('82'), findsOneWidget);
    });
  });

  group('scrolling', () {
    testWidgets('only the transcript page scrolls, and it scrolls as one', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      ScrollPosition position() => tester
          .widget<Scrollable>(find.byType(Scrollable))
          .controller!
          .position;

      // The gene fits the viewport exactly, so there is nothing to scroll.
      expect(position().maxScrollExtent, 0);

      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(find.text('465'), findsOneWidget);
      expect(
        position().maxScrollExtent,
        greaterThan(0),
        reason: '465 bases at a legible pitch is about twice a phone',
      );

      // The grid scrolls, and nothing else does: the words are all in the
      // header now and the header is chrome, not part of the page.
      await tester.drag(find.byType(AnatomyCanvas), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(position().pixels, greaterThan(0));
      expect(find.text('465'), findsOneWidget);
      expect(
        find.text(_transcriptSentence),
        findsOneWidget,
        reason: 'the count and the sentence stay put while the grid moves',
      );

      // Moving on puts the page back at the top, so the next reflow starts
      // where the reader is looking.
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(find.text('110'), findsOneWidget);
      expect(position().pixels, 0);
      expect(position().maxScrollExtent, 0);
    });
  });

  group('the pace of the walk', () {
    test('splicing and translation have time to show their changes', () {
      // It is the largest reflow in the app and the first one a reader meets,
      // so it is the one that has to be legible as an event rather than as a
      // page that changed. Translation also gives its final growth time to read.
      final Duration splice = AnatomyCanvas.durationOf(StageKind.mrna);
      for (final StageKind other in <StageKind>[
        StageKind.proprotein,
        StageKind.maturePeptides,
      ]) {
        expect(
          AnatomyCanvas.durationOf(other),
          lessThan(splice),
          reason: '$other is not shorter than the splice',
        );
      }
      expect(AnatomyCanvas.durationOf(StageKind.protein), greaterThan(splice));
    });

    test('the frame opens in less time than the splice it follows', () {
      // They run end to end, so the two together are what a reader waits
      // through. The second beat is the smaller one.
      expect(
        AnatomyCanvas.grooveDuration,
        lessThan(AnatomyCanvas.durationOf(StageKind.mrna)),
      );
    });
  });

  group('the reading frame', () {
    testWidgets('arrives shut, and opens only once the splice has settled', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      expect(_painter(tester).groove.value, 1, reason: 'the gene has no frame');

      await _swipe(tester, forward: true);
      // One frame in: the introns are still leaving. The transcript's codons
      // have to land flush under them, or the page arrives already saying the
      // thing it is about to say.
      expect(_painter(tester).scene.isTransition, isTrue);
      expect(_painter(tester).groove.value, 0);

      await tester.pumpAndSettle();
      expect(_painter(tester).scene.isTransition, isFalse);
      expect(_painter(tester).groove.value, 1);
    });

    testWidgets('is not snapped shut on the way out of the page', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 1);
      expect(_painter(tester).groove.value, 1);

      // Closing 111 codons on the first frame of a departure would be a second
      // animation competing with the one the reader is watching.
      await _swipe(tester, forward: true);
      expect(_painter(tester).groove.value, 1);
    });

    testWidgets('reverse translation splits into already open codons', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 2);

      await _swipe(tester, forward: false);
      expect(_painter(tester).groove.value, 1);
      await tester.pump(const Duration(milliseconds: 750));
      expect(_painter(tester).groove.value, 1);
      await tester.pumpAndSettle();
      expect(_painter(tester).groove.value, 1);
    });

    testWidgets('reduced motion arrives with the frame already open', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, reduceMotion: true);
      await _swipe(tester, forward: true);
      // No pumpAndSettle: with animations disabled the page is simply there,
      // and so is its frame. Nothing is lost but the travel.
      await tester.pump();
      expect(find.text('465'), findsOneWidget);
      expect(_painter(tester).scene.isTransition, isFalse);
      expect(_painter(tester).groove.value, 1);
    });
  });

  group('the tracer', () {
    testWidgets('a masked residue still carries its trace to the mature chain', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 2);
      expect(find.text(_precursorSentence), findsOneWidget);

      await _tapBase(tester, 2, _valine26);
      expect(find.text('Val26 · B2'), findsOneWidget);
      expect(
        find.text(_precursorSentence),
        findsOneWidget,
        reason: 'the panel carries the residue details on the protein page',
      );

      // The mature chains renumber it: the same valine, second of the B chain.
      // The precursor did not, and that is the difference between blocks that
      // are stretches of one chain and blocks that are separate molecules.
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(find.text('Val26 · B chain residue 2'), findsOneWidget);
    });

    testWidgets('a traced residue is lost at cleavage', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 2);
      await _tapBase(tester, 2, _signalStart);
      expect(find.text('Met1'), findsOneWidget);

      // It goes on the one swipe off the precursor now, alongside the two cut
      // sites, rather than on a page of its own.
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(
        find.text('removed with the signal peptide · 72 bp'),
        findsOneWidget,
      );
      // Still shown, still inert — never dropped, and never silently moved: it
      // settles where the residue drifted to.
      expect(_painter(tester).inertTracer, isNotNull);

      // And it is still there on the way back, which is the same scene read the
      // other way — and, nothing being masked, the header names it again.
      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^Met1 · ')), findsOneWidget);
      expect(_painter(tester).tracer, isNotNull);
    });

    testWidgets('tapping the traced square again clears it', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 2);
      await _tapBase(tester, 2, _valine26);
      expect(_painter(tester).maskedIndex, 25);

      await _tapBase(tester, 2, _valine26);
      expect(_painter(tester).maskedIndex, isNull);
      expect(find.text(_precursorSentence), findsOneWidget);
    });

    testWidgets('tap selects and never advances the stage', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 2);
      await _tapBase(tester, 2, _valine26);
      expect(find.text('110'), findsOneWidget);
    });

    testWidgets('a tap on the gene names the run it landed in', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _tapBase(tester, 0, 6000);
      expect(
        find.text('intron 2 · 787 bp · 55% of the gene'),
        findsOneWidget,
        reason: 'a tap on a nucleotide stage asks about the region, not a base',
      );
      expect(_painter(tester).tracer, isNotNull);

      // A second tap anywhere in the same run lets go of it.
      await _tapBase(tester, 0, 6100);
      expect(_painter(tester).tracer, isNull);
      expect(find.text('3 exons · 2 introns'), findsOneWidget);
    });

    testWidgets('the same tap on a residue still means that one residue', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 2);
      await _tapBase(tester, 2, _valine26);
      expect(find.text('Val26 · B2'), findsOneWidget);
    });

    testWidgets('a selected region is let go of on the way off the gene', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _tapBase(tester, 0, 5301);
      expect(
        find.text('insulin B chain · exon 2 · 90 bp · 6% of the gene'),
        findsOneWidget,
      );

      // Only the gene is drawn as exons, introns and chains, so a selection
      // made there has nothing left to point at on the transcript — which is
      // drawn as three regions of its own, and names them itself.
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(_painter(tester).tracer, isNull);
      expect(find.text(_transcriptSentence), findsOneWidget);
    });

    testWidgets('the reading frame names itself, at either end', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 1);

      await _tapBase(tester, 1, _signalStart);
      expect(find.text('c.1–3 · ATG · Met1 · start codon'), findsOneWidget);

      await _tapBase(tester, 1, _stopCodon);
      expect(find.text('c.331–333 · TAG · stop codon'), findsOneWidget);
    });

    testWidgets('a frame end answers for its codon, not for the base tapped', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 1);

      // The second base of the start codon. The caption must still name the
      // codon — which of its three squares was hit is not a question anyone
      // has — and the ring must mark all three.
      await _tapBase(tester, 1, _signalStart + 1);
      expect(find.text('c.1–3 · ATG · Met1 · start codon'), findsOneWidget);
      expect(_painter(tester).status!.siblings, hasLength(2));

      // The stop codon codes for no residue, so there is no next-page cell to
      // find its siblings through. It has to know its own three.
      // Bring the stop codon above the fixed navigation controls.
      await tester.drag(find.byType(AnatomyCanvas), const Offset(0, -120));
      await tester.pumpAndSettle();
      await _tapBase(tester, 1, _stopCodon + 2);
      expect(find.text('c.331–333 · TAG · stop codon'), findsOneWidget);
      expect(_painter(tester).status!.siblings, hasLength(2));
    });

    testWidgets('an ordinary base of the transcript names its codon', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 1);

      // A lettered base answers for the codon it is read in: its c. span, its
      // letters and the residue, with the other two bases ringed.
      await _tapBase(tester, 1, _signalStart + 30);
      expect(_painter(tester).tracer, isNotNull);
      expect(
        find.textContaining(RegExp(r'^c\.31–33 · [ACGT]{3} · [A-Z][a-z]{2}11$')),
        findsOneWidget,
      );
      expect(_painter(tester).status!.siblings, hasLength(2));

      // An untranslated base answers with its own coding-DNA position.
      await _tapBase(tester, 1, 4986);
      expect(find.textContaining(RegExp(r'^c\.−59 · [ACGT] · 5′ UTR$')), findsOneWidget);
    });

    testWidgets('the codon is what is selected, and what lets go of it', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 1);

      // c.31–33 is 5,254, 5,255 and 5,256. Picking one of them picks the
      // codon, so a second tap on either of the other two is the tap that
      // lets go of it — the rule a selected region on the gene already keeps.
      await _tapBase(tester, 1, _signalStart + 30);
      expect(_painter(tester).tracer, isNotNull);
      await _tapBase(tester, 1, _signalStart + 31);
      expect(_painter(tester).tracer, isNull);
      expect(find.text(_transcriptSentence), findsOneWidget);

      // A base of the next codon along is a different question, and replaces
      // the selection rather than clearing it.
      await _tapBase(tester, 1, _signalStart + 30);
      await _tapBase(tester, 1, _signalStart + 33);
      expect(_painter(tester).tracer, isNotNull);
      expect(
        find.textContaining(RegExp(r'^c\.34–36 · [ACGT]{3} · [A-Z][a-z]{2}12$')),
        findsOneWidget,
      );
    });

    testWidgets('bonded cysteines carry their bridge, and name their partner', (
      WidgetTester tester,
    ) async {
      expect(_constraint.bridges, <(int, int)>[(31, 96), (43, 109), (95, 100)]);

      await _pumpScreen(tester);
      await _toStage(tester, 3);
      // The chains page: all six cysteines survive the cuts, three bridges.
      final Map<int, int> bridges = _painter(tester).bridges;
      expect(bridges, hasLength(6));
      expect(bridges.values.toList()..sort(), <int>[1, 1, 2, 2, 3, 3]);

      // A7, Cys96: its partner is B7, Cys31, in the other chain.
      final AnatomyModel model = AnatomyModel.derive(insulin());
      final AnatomyStage mature = model.stages[3];
      final int a7 = mature.cellAt(model.stages[2].positionAt(95));
      final int b7 = mature.cellAt(model.stages[2].positionAt(30));
      expect(bridges[a7], bridges[b7]);

      // Nothing on this page is selected by touching it, so the bridge is
      // reached the way every other trace reaches it: picked on the precursor
      // and carried forward.
      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
      await _tapBase(tester, 2, model.stages[2].positionAt(95));
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(find.text('Cys96 · A chain residue 7'), findsOneWidget);
      expect(find.text('S\u2013S Cys31 (B7)'), findsOneWidget);
      expect(_painter(tester).status!.siblings, <int>[b7]);
    });

    testWidgets('a released chain is not selected by tapping it', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 3);

      // Every residue there is already named, numbered and, where it is
      // bonded, ringed. A tap only left a box behind that travelled back to
      // the precursor with the reader.
      final AnatomyModel model = AnatomyModel.derive(insulin());
      final AnatomyStage mature = model.stages[3];
      await _tapBase(tester, 3, mature.positionAt(6));
      expect(_painter(tester).tracer, isNull);
      expect(find.text(_chainsSentence), findsOneWidget);

      // And a trace carried in from the precursor can still be let go of.
      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
      await _tapBase(tester, 2, model.stages[2].positionAt(95));
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(_painter(tester).tracer, isNotNull);
      await _tapBase(tester, 3, mature.positionAt(6));
      expect(_painter(tester).tracer, isNull);
    });

    testWidgets('a tap on no square still clears, at every stage', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _toStage(tester, 2);
      await _tapBase(tester, 2, _valine26);
      expect(_painter(tester).maskedIndex, 25);

      // The fit reserves the connector bulge on both sides, so the grid never
      // starts at the canvas edge and this lands on nothing. Selecting a base
      // is refused here; dismissing one is not.
      final Rect header = tester.getRect(find.byType(AppBar));
      await tester.tapAt(Offset(1, header.bottom + 70));
      await tester.pumpAndSettle();
      expect(_painter(tester).maskedIndex, isNull);
    });
  });
}
