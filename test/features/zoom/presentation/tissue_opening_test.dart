import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/sculpt.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tissue_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, and on a narrow one.
const List<Size> _canvases = <Size>[Size(390, 560), Size(320, 420)];

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

/// A canvas that keeps the circles drawn on it as they land on screen:
/// each one's centre, its radius and whether it is filled.
class _Circles implements Canvas {
  final List<(Offset, double, PaintingStyle)> drawn =
      <(Offset, double, PaintingStyle)>[];
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
  void drawCircle(Offset c, double radius, Paint paint) => drawn.add((
    MatrixUtils.transformPoint(_now, c),
    radius * _now.getMaxScaleOnAxis(),
    paint.style,
  ));

  // Nothing else is looked at.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The tissue's own frame at depth [d], the step from the organ's: the
/// field as it is entered.
ZoomFrame _entering(ZoomStage stage, double d, Size size, ZoomInks inks) =>
    stage
        .frames(d, size, inks)
        .firstWhere(
          ((ZoomScene, ZoomFrame) f) => f.$1 is TissueScene && f.$2.isChild,
        )
        .$2;

void main() {
  testWidgets('at the organ, the place its tissue is sampled is marked once, '
      'and the same either side of the stop', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in _canvases) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final double organ = stage.depth.depthOf(ZoomStop.organ);
        final Offset site = stage
            .stage(organ, size, inks)
            .items['organ:target']!
            .$1;
        // Coming to rest from the body, at rest, and setting off for the
        // tissue: the organ's own scene draws it on the way in, the
        // tissue's from the stop on.
        for (final double d in <double>[organ - 1e-9, organ, organ + 1e-9]) {
          final _Circles canvas = _Circles();
          ZoomPainter(
            stage: stage,
            at: () => d,
            inks: inks,
            labels: labels,
          ).paint(canvas, size);
          bool at(Offset c) => (c - site).distance < 0.01;
          final String where = '${t.slug} at ${size.width}, depth $d';
          expect(
            canvas.drawn.where(
              ((Offset, double, PaintingStyle) c) =>
                  at(c.$1) &&
                  c.$3 == PaintingStyle.fill &&
                  (c.$2 - (Sculpt.beaconRadius - 1.4)).abs() < 1e-6,
            ),
            hasLength(1),
            reason: '$where: its dot',
          );
          expect(
            canvas.drawn.where(
              ((Offset, double, PaintingStyle) c) =>
                  at(c.$1) &&
                  c.$3 == PaintingStyle.stroke &&
                  (c.$2 - TissueScene.markerRing).abs() < 1e-6,
            ),
            hasLength(1),
            reason: '$where: its ring',
          );
        }
      }
    }
  });

  testWidgets('the field opens out of the marker, never smaller than it is, '
      'and arrives at the camera’s own scale and speed', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final Size size in _canvases) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final ZoomDepth depth = stage.depth;
        final TissueScene tissue =
            stage.scenes[ZoomStop.tissue.index] as TissueScene;
        final double from = depth.depthOf(ZoomStop.organ);
        final double travel = depth.travelOf(ZoomStop.organ.index);
        final String what = '${t.slug} at ${size.width}';
        (double, double, double) at(double s) {
          final ZoomFrame frame = _entering(
            stage,
            from + travel * s,
            size,
            inks,
          );
          final (double r, double o) = tissue.openingAt(frame);
          return (r, o, TissueScene.field * frame.view.pixelsPerUnit);
        }

        final double atOrgan = at(0).$3;
        double radius = 0;
        double open = 0;
        const int steps = 1000;
        for (int i = 0; i < steps; i++) {
          final (double r, double o, double own) = at(i / steps);
          if (i == 0) {
            // At the organ it is the marker's ring, closed.
            expect(r, TissueScene.markerRing, reason: what);
            expect(o, 0, reason: what);
          }
          expect(r, greaterThanOrEqualTo(radius), reason: '$what at $i');
          expect(o, greaterThanOrEqualTo(open), reason: '$what at $i');
          // Never smaller than the field is, once it has grown from the
          // size it had at the organ.
          if (own >= 2 * atOrgan) {
            expect(r, greaterThanOrEqualTo(own * (1 - 1e-9)), reason: what);
          }
          radius = r;
          open = o;
        }
        // Arriving, it is the field at the camera's own scale, growing as
        // the camera grows it, and at the stop the eyepiece's, whole.
        final (double r1, double _, double own1) = at(1 - 2e-3);
        final (double r2, double o2, double own2) = at(1 - 1e-3);
        expect(r2 / own2, closeTo(1, 1e-3), reason: what);
        expect(
          math.log(r2 / r1) / math.log(own2 / own1),
          closeTo(1, 0.02),
          reason: what,
        );
        expect(o2, closeTo(1, 1e-6), reason: what);
        final (double r, double _, double _) = at(1 - 1e-12);
        expect(r, closeTo(TissueScene.field * size.width, 0.01), reason: what);
      }
    }
  });

  test('the organ gives way before it is magnified past what it is drawn '
      'for, and is gone before the tissue', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final OrganScene organ = stage.scenes[ZoomStop.organ.index] as OrganScene;
      final double from = depth.depthOf(ZoomStop.organ);
      final double travel = depth.travelOf(ZoomStop.organ.index);
      const int steps = 1000;
      for (int i = 0; i <= steps; i++) {
        final double s = i / steps;
        final double magnified =
            depth.widthOf(ZoomStop.organ) / depth.widthAt(from + travel * s);
        final double shown = organ.asParent(s);
        final String what = '${t.slug} at $s, ×${magnified.toStringAsFixed(1)}';
        if (magnified <= 1.5) {
          expect(shown, 1, reason: what);
        }
        if (magnified >= 9) {
          expect(shown, lessThanOrEqualTo(0.25), reason: what);
        }
        if (s >= 0.95) {
          expect(shown, lessThan(0.005), reason: what);
        }
      }
      // And it never comes back on the way.
      double last = 1;
      for (int i = 0; i <= steps; i++) {
        final double shown = organ.asParent(i / steps);
        expect(shown, lessThanOrEqualTo(last), reason: t.slug);
        last = shown;
      }
    }
  });
}
