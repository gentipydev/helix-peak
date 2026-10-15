import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_camera.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/band_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
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

Future<ZoomInks> _inks(WidgetTester tester) async {
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
  return inks;
}

/// A canvas that keeps the paths filled on it in one colour, on screen,
/// and counts everything drawn on it.
class _Fills implements Canvas {
  final List<(Path, Color)> fills = <(Path, Color)>[];
  int drawn = 0;
  final List<Matrix4> _saved = <Matrix4>[];
  Matrix4 _now = Matrix4.identity();

  @override
  void save() => _saved.add(_now.clone());

  @override
  void saveLayer(Rect? bounds, Paint paint) => save();

  @override
  void restore() => _now = _saved.removeLast();

  @override
  void translate(double dx, double dy) => _now.translateByDouble(dx, dy, 0, 1);

  @override
  void scale(double sx, [double? sy]) => _now.scaleByDouble(sx, sy ?? sx, 1, 1);

  @override
  void rotate(double radians) => _now.rotateZ(radians);

  @override
  void drawPath(Path path, Paint paint) {
    drawn++;
    if (paint.style == PaintingStyle.fill && paint.shader == null) {
      fills.add((path.transform(_now.storage), paint.color));
    }
  }

  // Anything else drawn is counted; the rest is neither drawn nor kept.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('draw')) {
      drawn++;
    }
    return null;
  }
}

/// A canvas that keeps where each mesh drawn on it lies: the transform it
/// was drawn through.
class _Meshes implements Canvas {
  final List<Matrix4> drawn = <Matrix4>[];
  final List<Matrix4> _saved = <Matrix4>[];
  Matrix4 _now = Matrix4.identity();

  @override
  void save() => _saved.add(_now.clone());

  @override
  void saveLayer(Rect? bounds, Paint paint) => save();

  @override
  void restore() => _now = _saved.removeLast();

  @override
  void translate(double dx, double dy) => _now.translateByDouble(dx, dy, 0, 1);

  @override
  void scale(double sx, [double? sy]) => _now.scaleByDouble(sx, sy ?? sx, 1, 1);

  @override
  void rotate(double radians) => _now.rotateZ(radians);

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      drawn.add(_now.clone());

  // Everything else it draws is not a mesh.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The scenes on screen at [d], by the stop each one is.
Map<ZoomStop, (ZoomScene, ZoomFrame)> _at(
  ZoomStage stage,
  ZoomInks inks,
  double d,
) => <ZoomStop, (ZoomScene, ZoomFrame)>{
  for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
    d,
    _canvas,
    inks,
  ))
    scene.stop: (scene, frame),
};

/// Points along [path] every [step] pixels.
List<Offset> _along(Path path, {double step = 0.25}) => <Offset>[
  for (final ui.PathMetric metric in path.computeMetrics())
    for (double d = 0; d < metric.length; d += step)
      metric.getTangentForOffset(d)!.position,
];

/// The farthest any point of [a] lies from [b], and of [b] from [a].
double _apart(List<Offset> a, List<Offset> b) {
  double farthest(List<Offset> from, List<Offset> to) {
    double most = 0;
    for (final Offset p in from) {
      double near = double.infinity;
      for (final Offset q in to) {
        near = math.min(near, (p - q).distanceSquared);
      }
      most = math.max(most, near);
    }
    return math.sqrt(most);
  }

  return math.max(farthest(a, b), farthest(b, a));
}

/// [scene] drawn at [frame] on its own, as pixels.
Future<Uint8List> _pixels(
  WidgetTester tester,
  ZoomScene scene,
  ZoomFrame frame,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  scene.paint(Canvas(recorder), frame);
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

/// [frame] at [progress] along its segment, its view unchanged.
ZoomFrame _moved(ZoomFrame frame, double progress, {required bool isChild}) =>
    ZoomFrame(
      view: ZoomView(
        stop: frame.view.stop,
        pixelsPerUnit: frame.view.pixelsPerUnit,
        centre: frame.view.centre,
        progress: progress,
        isChild: isChild,
      ),
      size: frame.size,
      opacity: frame.opacity,
      inks: frame.inks,
      clock: frame.clock,
    );

void main() {
  group('the step from the nucleus', () {
    testWidgets('the territory is drawn once at the nucleus: the chromosome '
        'draws nothing before the step is under way', (
      WidgetTester tester,
    ) async {
      final ZoomInks inks = await _inks(tester);
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final double d = stage.depth.depthOf(ZoomStop.nucleus);
        final (ZoomScene chromosome, ZoomFrame frame) = _at(
          stage,
          inks,
          d,
        )[ZoomStop.chromosome]!;
        expect(frame.isChild, isTrue);
        expect(frame.progress, 0);
        final _Fills canvas = _Fills();
        chromosome.paint(canvas, frame);
        expect(canvas.drawn, 0, reason: t.slug);
        // The nucleus names it there, and the chromosome does not.
        final ZoomStaging staging = ZoomStaging();
        chromosome.stage(frame, staging);
        expect(
          staging.items.keys.where((String k) => k.startsWith('territory:')),
          isEmpty,
          reason: t.slug,
        );
        expect(
          stage.stage(d, _canvas, inks).items['territory:followed']?.$2,
          1,
          reason: t.slug,
        );
      }
    });

    testWidgets('the chromosome takes the territory over where the nucleus '
        'drew it, to half a pixel', (WidgetTester tester) async {
      final ZoomInks inks = await _inks(tester);
      final Color mark = inks.glow(0.8);
      List<Offset> territory(ZoomScene scene, ZoomFrame frame) {
        final _Fills canvas = _Fills();
        scene.paint(canvas, frame);
        final List<(Path, Color)> marked = <(Path, Color)>[
          for (final (Path, Color) fill in canvas.fills)
            if (fill.$2.toARGB32() == mark.toARGB32()) fill,
        ];
        expect(marked, hasLength(1), reason: scene.stop.name);
        return _along(marked.single.$1);
      }

      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final ZoomDepth depth = stage.depth;
        final double d = depth.depthOf(ZoomStop.nucleus);
        final (ZoomScene nucleus, ZoomFrame atStop) = _at(
          stage,
          inks,
          d,
        )[ZoomStop.nucleus]!;
        final (ZoomScene chromosome, ZoomFrame justPast) = _at(
          stage,
          inks,
          d + 0.001 * depth.travelOf(ZoomStop.nucleus.index),
        )[ZoomStop.chromosome]!;
        final List<Offset> before = territory(nucleus, atStop);
        final List<Offset> after = territory(chromosome, justPast);
        expect(before.length, greaterThan(200), reason: t.slug);
        expect(_apart(before, after), lessThan(0.5), reason: t.slug);
      }
    });

    testWidgets('the step’s last frames draw the chromosome as its stop '
        'does', (WidgetTester tester) async {
      final ZoomInks inks = await _inks(tester);
      for (final ProteinTarget t in <ProteinTarget>[
        TestCatalog.insulin,
        TestCatalog.sod1,
        TestCatalog.amylase,
        TestCatalog.dystrophin,
      ]) {
        final ZoomStage stage = _stage(t);
        final (ZoomScene chromosome, ZoomFrame rest) = _at(
          stage,
          inks,
          stage.depth.depthOf(ZoomStop.chromosome),
        )[ZoomStop.chromosome]!;
        expect(rest.isChild, isFalse);
        final Uint8List atStop = await _pixels(tester, chromosome, rest);
        // Through the same view, every part is at rest from 98% on.
        final Uint8List last = await _pixels(
          tester,
          chromosome,
          _moved(rest, 0.99, isChild: true),
        );
        expect(last, atStop, reason: t.slug);
        // Just before the stop takes over, every part is at rest but for
        // a trace of the fill under the micrograph, drawn in its layer: no
        // pixel more than a few shades away, and next to none at all. (The
        // test's rasteriser draws a bounded layer a few shades apart from
        // the same drawing without one, here and there along an edge.)
        final Uint8List near = await _pixels(
          tester,
          chromosome,
          _moved(rest, 0.979, isChild: true),
        );
        int most = 0;
        int total = 0;
        for (int i = 0; i < near.length; i++) {
          final int off = (near[i] - atStop[i]).abs();
          most = math.max(most, off);
          total += off;
        }
        expect(most, lessThanOrEqualTo(8), reason: t.slug);
        expect(total / near.length, lessThan(0.01), reason: t.slug);
      }
    });
  });

  group('the step to the band', () {
    testWidgets('from a third of the way on, the chromosome is the strip: '
        'every band’s edge on the strip’s, and as thick as the strip is '
        'there', (WidgetTester tester) async {
      final ZoomInks inks = await _inks(tester);
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final ZoomDepth depth = stage.depth;
        final List<CytoBand> bands = stage.subject.track.bands;
        int checked = 0;
        for (final double s in <double>[0.35, 0.4, 0.5, 0.6, 0.7, 0.8]) {
          final Map<ZoomStop, (ZoomScene, ZoomFrame)> at = _at(
            stage,
            inks,
            depth.depthOf(ZoomStop.chromosome) +
                s * depth.travelOf(ZoomStop.chromosome.index),
          );
          final (ZoomScene chromosome, ZoomFrame turning) =
              at[ZoomStop.chromosome]!;
          final (ZoomScene band, ZoomFrame map) = at[ZoomStop.band]!;
          final _Meshes canvas = _Meshes();
          chromosome.paint(canvas, turning);
          expect(canvas.drawn, isNotEmpty, reason: '${t.slug} at $s');
          final Matrix4 onScreen = canvas.drawn.first;
          final BandScene strip = band as BandScene;
          final double y = strip.stripY(map);
          final double from = strip.stripX(map, 1);
          final double to = strip.stripX(map, stage.subject.track.length + 1);
          for (final ({int band, int edge, Offset top, Offset bottom}) row
              in (chromosome as ChromosomeScene).tubeIn(inks).laidRows) {
            if (row.edge == 0) {
              continue;
            }
            final CytoBand own = bands[row.band];
            final double x = strip.stripX(
              map,
              row.edge > 0 ? own.start.toDouble() : own.end + 1.0,
            );
            // On the canvas, and clear of the strip's rounded ends.
            if (x < 0 ||
                x > _canvas.width ||
                x - from < BandScene.strip / 2 ||
                to - x < BandScene.strip / 2) {
              continue;
            }
            final Offset top = MatrixUtils.transformPoint(onScreen, row.top);
            final Offset bottom = MatrixUtils.transformPoint(
              onScreen,
              row.bottom,
            );
            final double half =
                BandScene.strip / 2 * BandScene.thickness(own.stain);
            final String where = '${t.slug} at $s, ${own.name}';
            expect(top.dx, closeTo(x, 0.5), reason: where);
            expect(bottom.dx, closeTo(x, 0.5), reason: where);
            expect(top.dy, closeTo(y - half, 0.5), reason: where);
            expect(bottom.dy, closeTo(y + half, 0.5), reason: where);
            checked++;
          }
        }
        expect(checked, greaterThan(10), reason: t.slug);
      }
    });

    testWidgets('from a third of the way on, the chromosome is drawn in the '
        'strip’s colours', (WidgetTester tester) async {
      final ZoomInks inks = await _inks(tester);
      for (final ProteinTarget t in <ProteinTarget>[
        TestCatalog.insulin,
        TestCatalog.sod1,
        TestCatalog.amylase,
        TestCatalog.dystrophin,
      ]) {
        final ZoomStage stage = _stage(t);
        final ZoomDepth depth = stage.depth;
        final LocusTrack track = stage.subject.track;
        for (final double s in <double>[0.5, 0.7]) {
          final Map<ZoomStop, (ZoomScene, ZoomFrame)> at = _at(
            stage,
            inks,
            depth.depthOf(ZoomStop.chromosome) +
                s * depth.travelOf(ZoomStop.chromosome.index),
          );
          final (ZoomScene chromosome, ZoomFrame turning) =
              at[ZoomStop.chromosome]!;
          final (ZoomScene band, ZoomFrame map) = at[ZoomStop.band]!;
          final Uint8List tube = await _pixels(tester, chromosome, turning);
          final Uint8List drawn = await _pixels(tester, band, map);
          final BandScene strip = band as BandScene;
          final double y = strip.stripY(map);
          // The gene's band is ringed and its spot glows on it: left out.
          final double ringFrom = strip.stripX(map, track.bandStart - 1.0);
          final double ringTo = strip.stripX(map, track.bandEnd + 1.0);
          int probed = 0;
          int most = 0;
          for (final CytoBand own in track.bands) {
            final double a = strip.stripX(map, own.start.toDouble());
            final double b = strip.stripX(map, own.end + 1.0);
            final double reach =
                (BandScene.strip / 2 * BandScene.thickness(own.stain) - 3)
                    .floorToDouble();
            // Inside the band, clear of its edges, on the canvas, and clear
            // of the gene's band.
            for (double x = a + 3; x <= b - 3; x += 4) {
              if (x < 4 ||
                  x > _canvas.width - 4 ||
                  (x > ringFrom - 26 && x < ringTo + 26)) {
                continue;
              }
              for (double dy = -reach; dy <= reach; dy += 2) {
                final int i =
                    ((y + dy).round() * _canvas.width.toInt() + x.round()) * 4;
                for (int c = 0; c < 4; c++) {
                  most = math.max(most, (tube[i + c] - drawn[i + c]).abs());
                }
                probed++;
              }
            }
          }
          expect(probed, greaterThan(20), reason: '${t.slug} at $s');
          expect(most, lessThanOrEqualTo(4), reason: '${t.slug} at $s');
        }
      }
    });
  });

  group('every moment', () {
    testWidgets('the chromosome draws the same whatever the clock or the '
        'dwell: what moves on its own is drawn over it', (
      WidgetTester tester,
    ) async {
      final ZoomInks inks = await _inks(tester);
      for (final ProteinTarget t in <ProteinTarget>[
        TestCatalog.insulin,
        TestCatalog.sod1,
      ]) {
        final ZoomStage stage = _stage(t);
        final ZoomDepth depth = stage.depth;
        for (final (ZoomStop from, double s) in <(ZoomStop, double)>[
          (ZoomStop.nucleus, 0.3),
          (ZoomStop.nucleus, 0.6),
          (ZoomStop.nucleus, 0.99),
          (ZoomStop.chromosome, 0),
          (ZoomStop.chromosome, 0.15),
          (ZoomStop.chromosome, 0.5),
        ]) {
          final (ZoomScene chromosome, ZoomFrame frame) = _at(
            stage,
            inks,
            depth.depthOf(from) + s * depth.travelOf(from.index),
          )[ZoomStop.chromosome]!;
          ZoomFrame at(double clock, double dwell) => ZoomFrame(
            view: frame.view,
            size: frame.size,
            opacity: frame.opacity,
            inks: frame.inks,
            clock: clock,
            dwell: dwell,
          );
          final Uint8List still = await _pixels(tester, chromosome, at(0, 99));
          for (final (double clock, double dwell) in <(double, double)>[
            (12.5, 0.3),
            (3, 0),
            (0.7, 1.2),
          ]) {
            expect(
              await _pixels(tester, chromosome, at(clock, dwell)),
              still,
              reason: '${t.slug}, ${from.name} +$s, $clock s, $dwell s',
            );
          }
        }
      }
    });

    testWidgets('every moment from the nucleus to the band draws, for all '
        'twenty', (WidgetTester tester) async {
      final ZoomInks inks = await _inks(tester);
      const TextStyle labels = TextStyle(fontSize: 12);
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final ZoomDepth depth = stage.depth;
        final double from = depth.depthOf(ZoomStop.nucleus);
        final double to = depth.depthOf(ZoomStop.band);
        for (int i = 0; i <= 60; i++) {
          final double d = from + (to - from) * i / 60;
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
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
            clock: () => 0.4,
            dwell: () => 0.4,
          ).paint(canvas, _canvas);
          recorder.endRecording().dispose();
          expect(tester.takeException(), isNull, reason: '${t.slug} at $d');
        }
      }
    });
  });
}
