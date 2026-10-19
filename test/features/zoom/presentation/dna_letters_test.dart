import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/dna_scene.dart';
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

/// A canvas that keeps, on screen, each disc drawn and each letter set: a
/// letter's middle, how large it is set and how far it is turned.
class _Letters implements Canvas {
  final List<(Offset, double, Color)> discs = <(Offset, double, Color)>[];
  final List<(Offset, double, double)> letters = <(Offset, double, double)>[];
  final List<Matrix4> _saved = <Matrix4>[];
  Matrix4 _now = Matrix4.identity();

  Offset _screen(Offset p) => MatrixUtils.transformPoint(_now, p);

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
  void drawCircle(Offset c, double radius, Paint paint) => discs.add((
    _screen(c),
    (_screen(c + Offset(radius, 0)) - _screen(c)).distance,
    paint.color,
  ));

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    final Offset middle = _screen(
      offset + Offset(paragraph.longestLine / 2, paragraph.height / 2),
    );
    final Offset across = _screen(offset + Offset(paragraph.longestLine, 0)) -
        _screen(offset);
    letters.add((
      middle,
      (_screen(offset + Offset(0, paragraph.height)) - _screen(offset))
          .distance,
      across.direction,
    ));
  }

  // Everything else the scene draws is neither.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// What the DNA's scene draws on its ambient layer, where the helix is, at
/// depth [d], over its turn at [clock].
_Letters _paint(ZoomStage stage, double d, ZoomInks inks, {double clock = 0}) {
  final _Letters out = _Letters();
  for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
    d,
    _canvas,
    inks,
    clock: clock,
  )) {
    if (scene is DnaScene) {
      scene.paintAmbient(out, frame);
    }
  }
  return out;
}

/// The depth on the step from the gene to the DNA at which the view is
/// [width] base pairs across.
double _depthWhere(ZoomDepth depth, double width) {
  double high = depth.depthOf(ZoomStop.gene);
  double low = depth.depthOf(ZoomStop.dna);
  for (int i = 0; i < 80; i++) {
    final double mid = (high + low) / 2;
    if (depth.widthAt(mid) > width) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return (high + low) / 2;
}

void main() {
  testWidgets('at its stop every base the helix shows carries its letter, '
      'upright, centred in its ball, and as large as the app\'s small print', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final double d = stage.depth.depthOf(ZoomStop.dna);
      for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
        d,
        _canvas,
        inks,
      )) {
        if (scene is DnaScene) {
          expect(scene.lettersShown(frame), 1, reason: t.slug);
        }
      }
      for (final double clock in <double>[0, 7, 15]) {
        final _Letters drawn = _paint(stage, d, inks, clock: clock);
        final List<(Offset, double, Color)> balls = <(Offset, double, Color)>[
          for (final (Offset, double, Color) disc in drawn.discs)
            if (disc.$3.toARGB32() != inks.ground.toARGB32()) disc,
        ];
        final String where = '${t.slug}, ${clock}s into its turn';
        expect(balls, isNotEmpty, reason: where);
        expect(drawn.letters, hasLength(balls.length), reason: where);
        for (int i = 0; i < balls.length; i++) {
          final (Offset middle, double size, double turn) = drawn.letters[i];
          expect((middle - balls[i].$1).distance, lessThan(0.5), reason: where);
          expect(turn, closeTo(0, 1e-9), reason: where);
          expect(size, greaterThanOrEqualTo(11), reason: where);
          expect(size, lessThan(2 * balls[i].$2), reason: where);
        }
      }
    }
  });

  testWidgets('no letter is set before the helix\'s bases show', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      // Wide enough that the helix is up but none of its bases are.
      final double d = _depthWhere(stage.depth, 260);
      expect(_paint(stage, d, inks).letters, isEmpty, reason: t.slug);
    }
  });
}
