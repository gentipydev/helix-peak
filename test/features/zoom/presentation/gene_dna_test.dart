import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/chromatin_layout.dart';
import 'package:helixpeek/features/zoom/domain/dna_dive.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromatin_beads.dart';
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
/// [clock] seconds of the ambient clock, as pixels.
Future<Uint8List> _pixels(
  WidgetTester tester,
  ZoomStage stage,
  double d,
  ZoomInks inks,
  TextStyle labels, {
  double clock = 0,
}) async {
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
    clock: () => clock,
    dwell: () => clock,
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
      'way in, the DNA’s from the gene’s stop on, the DNA either side of the '
      'gene all there at the stop and nothing of the dive begun', (
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
      // At the gene's stop the gene is a stretch of chromatin, its DNA
      // going on either side of it; nothing has sunk, wound or opened.
      for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
        gene,
        _canvas,
        inks,
      )) {
        if (scene is DnaScene) {
          final double span = depth.widthOf(ZoomStop.gene);
          expect(scene.contextAt(span), 1, reason: t.slug);
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
      // bare start becoming the helix, its bases coming in. The user would
      // have the step really slow: three times as long as when it took
      // 2.7 s, a second or more each.
      final List<(String, double, double, double)> stages =
          <(String, double, double, double)>[
            if (sinks > winds) ('the exons sinking', sinks, winds, 0.9),
            ('the DNA winding', winds, winds / DnaScene.windsOver, 1.2),
            ('the beads named', 600, 220, 1.2),
            ('the helix coming', 800, 300, 1.2),
            ('its bases coming', 220, 40, 1.2),
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

  testWidgets('the gene is still: at its stop no scene asks for the ambient '
      'clock, and it is drawn the same at any moment', (
    WidgetTester tester,
  ) async {
    final (ZoomInks inks, TextStyle labels) = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final double at = stage.depth.depthOf(ZoomStop.gene);
      for (final double dwell in <double>[0, 0.5, 60]) {
        expect(
          stage.wantsClock(at, _canvas, inks, dwell: dwell),
          isFalse,
          reason: '${t.slug}, ${dwell}s there',
        );
      }
    }
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.relaxin,
      TestCatalog.dystrophin,
    ]) {
      final ZoomStage stage = _stage(t);
      final double at = stage.depth.depthOf(ZoomStop.gene);
      final Uint8List a = await _pixels(tester, stage, at, inks, labels);
      final Uint8List b = await _pixels(
        tester,
        stage,
        at,
        inks,
        labels,
        clock: 7.3,
      );
      int worst = 0;
      for (int i = 0; i < a.length; i++) {
        worst = math.max(worst, (a[i] - b[i]).abs());
      }
      expect(worst, 0, reason: t.slug);
    }
  });

  testWidgets('the gene’s beads are its own nucleosomes, at their places in '
      'the packing, as many as the view can tell apart, the first past its '
      'start always', (WidgetTester tester) async {
    const ChromatinLayout chromatin = ChromatinLayout();
    for (final Size size in <Size>[_canvas, const Size(320, 420)]) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final double gene = stage.depth.widthOf(ZoomStop.gene);
        final double perBase = size.width / gene;
        final String what = '${t.slug} at ${size.width.toInt()}';
        // The whole view, from its left edge to its right, in base pairs
        // from the gene's 5′ end.
        final double from = -0.15 * gene - 100;
        final double to = 1.15 * gene + 100;
        final Set<double> starts = <double>{
          for (final (double start, double _) in chromatin.nucleosomesWithin(
            from,
            to,
          ))
            start,
        };
        final List<(double, int, double)> beads = ChromatinBeads.within(
          from,
          to,
          ChromatinBeads.levelAt(perBase),
        );
        expect(beads, isNotEmpty, reason: what);
        double? last;
        for (final (double at, int index, double shown) in beads) {
          expect(
            starts.any(
              (double start) =>
                  (start - (at - ChromatinLayout.across / 2)).abs() < 1e-6,
            ),
            isTrue,
            reason: '$what: bead $index',
          );
          if (shown > 0.999) {
            if (last != null) {
              expect(
                (at - last) * perBase,
                greaterThanOrEqualTo(ChromatinBeads.apart - 1e-6),
                reason: '$what: bead $index',
              );
            }
            last = at;
          }
        }
        expect(
          beads.where(((double, int, double) b) => b.$2 == 0).single.$3,
          1,
          reason: what,
        );
      }
    }
  });

  testWidgets('the beads come and go without a pop, and none moves along the '
      'DNA, on the steps either side of the gene, at 60 fps', (
    WidgetTester tester,
  ) async {
    final (ZoomInks inks, TextStyle _) = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final double gene = depth.widthOf(ZoomStop.gene);
      final double end = stage.subject.track.geneLengthBp.toDouble();
      // How much of each bead shows at depth [d], by which nucleosome it
      // is, as the scene drawing the gene's DNA there shows it: the gene's
      // on the way in, coming up with its annotations; the DNA's from the
      // stop on, the DNA either side of the gene going before the bases.
      Map<int, double> shown(double d) {
        final Map<int, double> out = <int, double>{};
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          d,
          _canvas,
          inks,
        )) {
          final double span = depth.widthAt(d);
          if (scene is GeneScene && frame.isChild) {
            // The beads its stop shows, coming up with the gene.
            for (final (double _, int index, double alpha)
                in ChromatinBeads.within(
                  -gene,
                  2 * gene,
                  ChromatinBeads.levelAt(_canvas.width / gene),
                )) {
              out[index] =
                  alpha * frame.opacity * scene.annotationsShown(frame);
            }
          }
          if (scene is DnaScene) {
            final double around = scene.contextAt(span);
            for (final (double at, int index, double alpha)
                in ChromatinBeads.within(
                  -gene,
                  2 * gene,
                  scene.beadLevel(frame),
                )) {
              out[index] =
                  alpha * frame.opacity * (at < 0 || at > end ? around : 1);
            }
          }
        }
        return out;
      }

      final double band = depth.depthOf(ZoomStop.band);
      final double at = depth.depthOf(ZoomStop.gene);
      final double dna = depth.depthOf(ZoomStop.dna);
      for (final ZoomFlight flight in <ZoomFlight>[
        ZoomFlight(band, at),
        ZoomFlight(at, band),
        ZoomFlight(
          at,
          dna,
          minimum: depth.leastFlight(at, dna),
          cruise: depth.cruiseOf(at, dna),
        ),
        ZoomFlight(
          dna,
          at,
          minimum: depth.leastFlight(dna, at),
          cruise: depth.cruiseOf(dna, at),
        ),
      ]) {
        final int frames = (flight.duration.inMicroseconds / 1e6 * 60).ceil();
        Map<int, double>? last;
        for (int f = 0; f <= frames; f++) {
          final Map<int, double> now = shown(
            flight.at(Duration(microseconds: (f * 1e6 / 60).round())),
          );
          if (last != null) {
            for (final int index in <int>{...now.keys, ...last.keys}) {
              expect(
                ((now[index] ?? 0) - (last[index] ?? 0)).abs(),
                lessThanOrEqualTo(0.08),
                reason:
                    '${t.slug} from ${flight.from} to ${flight.to}, frame '
                    '$f: bead $index',
              );
            }
          }
          last = now;
        }
      }
    }
  });
}
