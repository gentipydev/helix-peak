import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/heart/heart_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/heart/heart_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/heart/heart_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/specimen_step.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card.
const Size _canvas = Size(390, 560);

final TissueAnatomy _anatomy = tissueAnatomy['heart muscle']!;
final AnatomyPart _part = AnatomyFigure.female.parts[_anatomy.uberon]!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.heartUpright;

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

HeartForm _form() => HeartForm.place(part: _part, view: _view);

OrganArt _organ(CellShape cell) => OrganArt.forTissue(
  _anatomy,
  _part,
  _view,
  figure: AnatomyFigure.female,
  shape: cell,
);

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// does the red the vessels are drawn in.
double _tealness(int colour) {
  final double r = (colour >> 16 & 255) / 255;
  final double g = (colour >> 8 & 255) / 255;
  final double b = (colour & 255) / 255;
  return b < g ? g - r : 2 * g - r - b;
}

/// A canvas that keeps what is drawn on it: each path's bounds and colour,
/// each set of points and its colour, and how many layers and meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> paths = <(Rect, Color)>[];
  final List<(Float32List, Color)> points = <(Float32List, Color)>[];
  int layers = 0;
  int meshes = 0;

  @override
  void drawPath(Path path, Paint paint) =>
      paths.add((path.getBounds(), paint.color));

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      meshes++;

  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) =>
      this.points.add((points, paint.color));

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A flight from [from] to [to] as the screen flies it.
ZoomFlight _flight(ZoomDepth depth, double from, double to) => ZoomFlight(
  from,
  to,
  minimum: depth.leastFlight(from, to),
  cruise: depth.cruiseOf(from, to),
);

/// The organ's scene and its frame at each 60th of a second of [flight],
/// where it is drawn.
List<(OrganScene, ZoomFrame)?> _organFrames(
  ZoomStage stage,
  ZoomFlight flight,
  ZoomInks inks,
) {
  final int frames = (flight.duration.inMicroseconds / 1e6 * 60).ceil();
  return <(OrganScene, ZoomFrame)?>[
    for (int f = 0; f <= frames; f++)
      () {
        final double d = flight.at(
          Duration(microseconds: (f * 1e6 / 60).round()),
        );
        for (final (ZoomScene s, ZoomFrame frame) in stage.frames(
          d,
          _canvas,
          inks,
        )) {
          if (s is OrganScene) {
            return (s, frame);
          }
        }
        return null;
      }(),
  ];
}

void main() {
  testWidgets('the mark shows only where the zoom’s cell lives: for a heart '
      'muscle cell its muscle, one flat tone, and for an epicardial cell its '
      'epicardium; no mesh leans to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final HeartForm form = _form();
    expect(
      HeartArt.muscleOf(inks),
      Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)),
    );
    for (final HeartHome home in HeartHome.values) {
      final HeartArt art = HeartArt(form, inks, home: home);
      for (final (String part, Float32List _, Int32List colours)
          in art.meshData) {
        expect(
          colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
          isEmpty,
          reason: '${home.name}: $part',
        );
      }
      final _Record canvas = _Record();
      art
        ..prepare()
        ..paint(canvas, form.mm(0.25));
      final List<Color> marked = <Color>[
        for (final (Rect _, Color colour) in canvas.paths)
          if (_tealness(colour.toARGB32()) > 0.01) colour,
      ];
      expect(canvas.points, isEmpty);
      switch (home) {
        case HeartHome.myocardium:
          // The atria, the ventricles, the papillary muscles and the
          // moderator band, and the outflow's walls: all one tone.
          expect(marked.length, greaterThanOrEqualTo(4));
          expect(
            <int>{for (final Color c in marked) c.toARGB32()},
            <int>{HeartArt.muscleOf(inks).toARGB32()},
          );
        case HeartHome.epicardium:
          expect(
            <int>[for (final Color c in marked) c.toARGB32()],
            <int>[inks.glow(0.95).toARGB32()],
          );
      }
    }
    // Where each kind of cell lives in it.
    expect(HeartHome.of(CellShape.cardiomyocyte), HeartHome.myocardium);
    expect(HeartHome.of(CellShape.dividing), HeartHome.myocardium);
    expect(HeartHome.of(CellShape.spindle), HeartHome.myocardium);
    expect(HeartHome.of(CellShape.endothelial), HeartHome.myocardium);
    expect(HeartHome.of(CellShape.epithelial), HeartHome.epicardium);
  });

  testWidgets('at the hand-over the heart is the body’s own outline, flat in '
      'the mark, with no layer, mesh or point; at its stop the heart, with '
      'no layer, the figure’s own parts round it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final double real = HeartForm.realFor(_part);
    final Rect body = Contour(<Offset>[
      for (final Offset p in _part.followed)
        (p - _part.centre) * (real / _view),
    ]).toPath().getBounds();
    final OrganArt art = _organ(CellShape.cardiomyocyte);
    expect(art.followsBody, isTrue);
    expect(art.real, closeTo(real, 1e-12));
    final _Record handed = _Record();
    art.paint(handed, inks, 1 / 390, 1 / real, detail: 0);
    expect(handed.layers, 0);
    expect(handed.meshes, 0);
    expect(handed.points, isEmpty);
    expect(<Rect>[
      for (final (Rect bounds, Color _) in handed.paths) bounds,
    ], contains(body));
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
    // The figure's own parts stay round it, faint, as the body drew them:
    // the lungs either side of it reach well past its box.
    final Rect heart = art.outline.getBounds();
    expect(
      rest.paths.where(
        ((Rect, Color) p) =>
            p.$1.left < heart.left - heart.width * 0.1 &&
            p.$1.height > heart.height,
      ),
      isNotEmpty,
    );
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final HeartHome home in HeartHome.values) {
      final List<(String, Float32List, Int32List)> a = HeartArt(
        _form(),
        inks,
        home: home,
      ).meshData;
      final List<(String, Float32List, Int32List)> b = HeartArt(
        _form(),
        inks,
        home: home,
      ).meshData;
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i].$1, b[i].$1);
        expect(a[i].$2, b[i].$2);
        expect(a[i].$3, b[i].$3);
        expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
      }
    }
  });

  test('it names its four chambers, in the quiet ink, and where the zoom’s '
      'cell lives, in the mark: its muscle at the place its tissue is '
      'sampled, or its epicardium beside it; set round all of it', () {
    final OrganArt muscle = _organ(CellShape.cardiomyocyte);
    expect(
      <String>[for (final OrganName n in muscle.names) n.word],
      <String>[
        'right atrium',
        'left atrium',
        'right ventricle',
        'left ventricle',
        'myocardium',
      ],
    );
    expect(muscle.names.last.home, isTrue);
    expect(muscle.names.last.at, muscle.site);
    expect(muscle.names.take(4).every((OrganName n) => !n.home), isTrue);
    expect(muscle.columns, isEmpty);
    expect(muscle.named, isNotEmpty);
    expect(muscle.outline.contains(muscle.site), isTrue);
    final OrganArt surface = _organ(CellShape.epithelial);
    expect(surface.names.last.word, 'epicardium');
    expect(surface.names.last.home, isTrue);
    expect(
      (surface.names.last.at - surface.site).distance / _form().scale,
      lessThan(8),
    );
  });

  testWidgets('on the steps to the heart and back nothing pops or jumps: its '
      'outline drawn in, the heart coming up, the figure staying round '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('phospholamban')!;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.heart);
    final HeartForm form = HeartForm.place(
      part: subject.bodyPart!,
      view: subject.depth.widthOf(ZoomStop.organ),
    );
    final ZoomDepth depth = stage.depth;
    final double body = depth.depthOf(ZoomStop.body);
    final double organ = depth.depthOf(ZoomStop.organ);
    for (final ZoomFlight flight in <ZoomFlight>[
      _flight(depth, body, organ),
      _flight(depth, organ, body),
    ]) {
      double? lastShown;
      List<Offset>? before;
      List<Offset>? last;
      int f = 0;
      for (final (OrganScene, ZoomFrame)? at in _organFrames(
        stage,
        flight,
        inks,
      )) {
        f++;
        if (at == null) {
          lastShown = null;
          before = null;
          last = null;
          continue;
        }
        final (OrganScene scene, ZoomFrame frame) = at;
        final double detail = OrganScene.detailAt(frame);
        final double shown = frame.opacity * SpecimenStep.come(detail);
        final String where = 'from ${flight.from} to ${flight.to}, frame $f';
        if (lastShown != null) {
          expect(
            (shown - lastShown).abs(),
            lessThanOrEqualTo(0.08),
            reason: '$where: the heart',
          );
        }
        lastShown = shown;
        final double grown = scene.grownAt(frame);
        final List<Offset> outline = form.outlineAt(
          SpecimenStep.settle(detail, span: HeartStyle.settling),
        );
        final List<Offset> now = <Offset>[
          for (int i = 0; i < outline.length; i += 12)
            frame.toScreen(outline[i] * grown),
        ];
        if (before != null && last != null) {
          final Offset centre = _canvas.center(Offset.zero);
          for (int i = 0; i < now.length; i++) {
            final Offset second = now[i] - last[i] * 2 + before[i];
            // Near the middle nothing may jolt; further out things fly
            // outward as the view narrows, so the check is for a break.
            final bool focus = (last[i] - centre).distance < 160;
            final double allowed = focus
                ? 1.5
                : math.max(1.5, 0.3 * (now[i] - last[i]).distance + 2);
            expect(
              second.distance,
              lessThanOrEqualTo(allowed),
              reason: '$where: outline point ${i * 12}',
            );
          }
        }
        before = last;
        last = now;
      }
    }
  });
}
