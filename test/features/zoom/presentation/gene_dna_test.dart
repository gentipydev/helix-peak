import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/dna_dive.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/dna_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/gene_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card.
const Size _canvas = Size(390, 560);

ZoomStage _stage(ProteinTarget t) =>
    ZoomStage(ZoomSubject(track: locusOf(t), record: recordOf(t)));

Future<(ZoomInks, TextStyle)> _inks(WidgetTester tester) async {
  late ZoomInks inks;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          inks = ZoomInks.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return (inks, AppTheme.analysis.textTheme.labelSmall!);
}

/// The whole canvas at depth [d], the scenes and what lies over them, at
/// the ambient clock's 0, as pixels.
Future<Uint8List> _pixels(
  WidgetTester tester,
  ZoomStage stage,
  double d,
  ZoomInks inks,
  TextStyle labels,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & _canvas, Paint()..color = inks.ground);
  ZoomPainter(
    stage: stage,
    at: () => d,
    inks: inks,
    labels: labels,
  ).paint(canvas, _canvas);
  ZoomOverlayPainter(
    stage: stage,
    at: () => d,
    inks: inks,
    labels: labels,
    caption: labels,
    credit: '',
  ).paint(canvas, _canvas);
  final ui.Picture picture = recorder.endRecording();
  final Uint8List? bytes = await tester.runAsync(() async {
    final ui.Image image = await picture.toImage(
      _canvas.width.toInt(),
      _canvas.height.toInt(),
    );
    final ByteData data = (await image.toByteData())!;
    image.dispose();
    return data.buffer.asUint8List();
  });
  picture.dispose();
  return bytes!;
}

void main() {
  testWidgets('the gene’s stop is one picture from either side: its DNA, '
      'drawn by the gene’s scene on the way in, is drawn the same by the '
      'DNA’s from the stop on', (WidgetTester tester) async {
    final (ZoomInks inks, TextStyle labels) = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final double at = stage.depth.depthOf(ZoomStop.gene);
      // The gene's scene as the child of the step from the band, and the
      // gene's and the DNA's as the step to the DNA begins.
      final List<(ZoomScene, ZoomFrame)> before = stage.frames(
        at - 1e-9,
        _canvas,
        inks,
      );
      final List<(ZoomScene, ZoomFrame)> after = stage.frames(
        at,
        _canvas,
        inks,
      );
      expect(
        before.any(((ZoomScene, ZoomFrame) f) => f.$1 is DnaScene),
        isFalse,
      );
      expect(after.any(((ZoomScene, ZoomFrame) f) => f.$1 is DnaScene), isTrue);
      final Uint8List a = await _pixels(tester, stage, at - 1e-9, inks, labels);
      final Uint8List b = await _pixels(tester, stage, at, inks, labels);
      // To the rasteriser's own rounding: four levels, as the chromosome's
      // hand-over is held to.
      int worst = 0;
      for (int i = 0; i < a.length; i++) {
        worst = math.max(worst, (a[i] - b[i]).abs());
      }
      expect(worst, lessThanOrEqualTo(4), reason: t.slug);
    }
  });

  testWidgets('the gene’s 3′ end is the DNA’s across the step between them, '
      'as its 5′ end is', (WidgetTester tester) async {
    final (ZoomInks inks, TextStyle _) = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final double at = depth.depthOf(ZoomStop.gene);
      final double step = depth.travelOf(ZoomStop.gene.index);
      final double length = stage.subject.layout.length;
      for (int i = 0; i <= 20; i++) {
        final List<(ZoomScene, ZoomFrame)> frames = stage.frames(
          at + step * i / 40,
          _canvas,
          inks,
        );
        GeneScene? gene;
        DnaScene? dna;
        ZoomFrame? inGene;
        ZoomFrame? inDna;
        for (final (ZoomScene scene, ZoomFrame frame) in frames) {
          if (scene is GeneScene) {
            gene = scene;
            inGene = frame;
          }
          if (scene is DnaScene) {
            dna = scene;
            inDna = frame;
          }
        }
        if (gene == null || dna == null) {
          continue;
        }
        final double x = gene.screenX(inGene!, length);
        expect(
          dna.screenX(inDna!, length),
          closeTo(x, 0.5 + 1e-9 * x.abs()),
          reason: '${t.slug} at $i',
        );
      }
    }
  });

  testWidgets('the DNA is drawn by one scene at a time: the gene’s on the '
      'way in, the DNA’s from the gene’s stop on, and never a second line '
      'across the canvas past the gene’s ends at its stop', (
    WidgetTester tester,
  ) async {
    final (ZoomInks inks, TextStyle _) = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final double band = depth.depthOf(ZoomStop.band);
      final double gene = depth.depthOf(ZoomStop.gene);
      for (int i = 1; i < 20; i++) {
        final double d = band + (gene - band) * i / 20;
        expect(
          stage
              .frames(d, _canvas, inks)
              .any(((ZoomScene, ZoomFrame) f) => f.$1 is DnaScene),
          isFalse,
          reason: '${t.slug} at $i',
        );
      }
      // At the gene's stop the DNA either side of the gene is not there yet.
      for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
        gene,
        _canvas,
        inks,
      )) {
        if (scene is DnaScene) {
          final double span = depth.widthOf(ZoomStop.gene);
          expect(scene.contextAt(span), 0, reason: t.slug);
          expect(scene.sunkAt(span), 0, reason: t.slug);
          expect(scene.woundShown(frame), 0, reason: t.slug);
          expect(scene.helixShown(frame), (0, 0), reason: t.slug);
        }
      }
    }
  });

  test('each stage of the dive has its time on every gene’s real step, '
      'either way, at 60 fps', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomDepth depth = _stage(t).depth;
      final double gene = depth.widthOf(ZoomStop.gene);
      final double winds = DnaDive.windsFrom(gene);
      final double sinks = math.min(gene, 10 * winds);
      // What happens where, by the view's width, and the least time each
      // is given: the exons sinking, the DNA winding, the beads named, the
      // bare start becoming the helix, its bases coming in.
      final List<(String, double, double, double)> stages =
          <(String, double, double, double)>[
            if (sinks > winds) ('the exons sinking', sinks, winds, 0.3),
            ('the DNA winding', winds, winds / DnaScene.windsOver, 0.4),
            ('the beads named', 600, 220, 0.4),
            ('the helix coming', 800, 300, 0.4),
            ('its bases coming', 220, 40, 0.4),
          ];
      final double from = depth.depthOf(ZoomStop.gene);
      final double to = depth.depthOf(ZoomStop.dna);
      for (final ZoomFlight flight in <ZoomFlight>[
        ZoomFlight(
          from,
          to,
          minimum: depth.leastFlight(from, to),
          cruise: depth.cruiseOf(from, to),
        ),
        ZoomFlight(
          to,
          from,
          minimum: depth.leastFlight(to, from),
          cruise: depth.cruiseOf(to, from),
        ),
      ]) {
        final Map<String, int> frames = <String, int>{};
        final int count = (flight.duration.inMicroseconds / 1e6 * 60).ceil();
        for (int f = 0; f <= count; f++) {
          final double w = depth.widthAt(
            flight.at(Duration(microseconds: (f * 1e6 / 60).round())),
          );
          for (final (String what, double high, double low, double _)
              in stages) {
            if (w <= high && w >= low) {
              frames[what] = (frames[what] ?? 0) + 1;
            }
          }
        }
        for (final (String what, double _, double _, double least) in stages) {
          expect(
            (frames[what] ?? 0) / 60,
            greaterThanOrEqualTo(least),
            reason:
                '${t.slug}, ${flight.from < flight.to ? 'in' : 'out'}: '
                '$what',
          );
        }
      }
    }
  });
}
