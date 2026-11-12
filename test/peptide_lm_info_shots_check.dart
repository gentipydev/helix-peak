// The Peptide Language Model's info pages as a phone shows them, as PNGs, in
// the app's fonts, from a recorded run (docs/design/peptide-lm-info-pages.md):
// each stage played through to its last frame, its ⓘ tapped, and the page
// scrolled to its end where it scrolls.
//
// Opt-in: skipped unless SHOTS is set, so `flutter test` stays offline.
//
//   SHOTS=/tmp/lm_info TRACE=../helix-peek-backend/pipeline/denovo/runs/curated/trace.json \
//   STAGES=tokenise,shift SIZES=440x956,393x852,375x667 \
//     flutter test test/peptide_lm_info_shots_check.dart
//
// STAGES are LmStage names (default tokenise), SIZES phones in points (default
// 393x852), STEP the checkpoint by its step (default the first). Beside each
// `<stage>_<size>.png` a `.txt` gives how far the page scrolls: 0 is a page
// that fits.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/peptide_lm_screen.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene_painter.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';

void main() {
  const double dpr = 3;
  final String? dir = Platform.environment['SHOTS'];
  final List<String> sizes = (Platform.environment['SIZES'] ?? '393x852').split(',');

  setUpAll(() async {
    await loadAppFonts();
    final String sdkFonts = '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    final File roboto = File('$sdkFonts/Roboto-Regular.ttf');
    if (roboto.existsSync()) {
      await (FontLoader('Roboto')
            ..addFont(Future<ByteData>.value(ByteData.sublistView(roboto.readAsBytesSync()))))
          .load();
    }
  });

  TrainingTrace run() => TrainingTrace.parse(File(Platform.environment['TRACE']!).readAsBytesSync());

  /// A phone of [size] points, with a notch and a home bar where it is tall.
  void phone(WidgetTester tester, Size size) {
    final bool tall = size.height >= 800;
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = FakeViewPadding(top: (tall ? 59 : 20) * dpr, bottom: (tall ? 34 : 0) * dpr);
  }

  Future<void> shoot(WidgetTester tester, GlobalKey boundary, String name) => tester.runAsync(() async {
    final RenderRepaintBoundary box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await box.toImage(pixelRatio: dpr);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });

  Size sizeOf(String s) {
    final List<String> wh = s.split('x');
    return Size(double.parse(wh[0]), double.parse(wh[1]));
  }

  testWidgets("each stage's info page over its last frame", (WidgetTester tester) async {
    final TrainingTrace trace = run();
    final List<LmStage> stages = <LmStage>[
      for (final String name in (Platform.environment['STAGES'] ?? 'tokenise').split(',')) LmStage.values.byName(name),
    ];
    final String? step = Platform.environment['STEP'];
    for (final String s in sizes) {
      for (final LmStage stage in stages) {
        phone(tester, sizeOf(s));
        final GlobalKey boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: AppTheme.analysis,
              debugShowCheckedModeBanner: false,
              home: TrainingRunView(trace: trace),
            ),
          ),
        );
        await tester.pump();
        if (stage != LmStage.tokenise) {
          final Finder name = find.byKey(ValueKey<String>('stage-${stage.label}'));
          await tester.ensureVisible(name);
          await tester.pump();
          await tester.tap(name);
          await tester.pump();
        }
        // Only a stage that changes with the step offers the menu.
        if (step != null && sceneOf(stage).stepped) {
          await tester.tap(find.byKey(const ValueKey<String>('peptide-lm-checkpoint')));
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('Step $step ·').last);
          await tester.pumpAndSettle();
          // The menu's settle ran the stage on: play it again from its start.
          final Finder name = find.byKey(ValueKey<String>('stage-${stage.label}'));
          await tester.ensureVisible(name);
          await tester.pump();
          await tester.tap(name);
          await tester.pump();
        }
        await tester.pump(TrainingRunView.beat * (stage.beats + 1));
        await tester.tap(find.byKey(const ValueKey<String>('peptide-lm-info')));
        await tester.pumpAndSettle();
        final String shot = '${stage.name}${step == null ? '' : '_step$step'}_$s';
        await shoot(tester, boundary, shot);
        final ScrollableState scroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('peptide-lm-info-sheet')),
            matching: find.byType(Scrollable),
          ),
        );
        final double extent = scroll.position.maxScrollExtent;
        File('$dir/$shot.txt').writeAsStringSync('scrolls ${extent.toStringAsFixed(1)} pt\n');
        if (extent > 0) {
          scroll.position.jumpTo(extent);
          await tester.pumpAndSettle();
          await shoot(tester, boundary, '${shot}_end');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    tester.view.reset();
  }, skip: dir == null);
}
