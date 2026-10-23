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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/stomach/stomach_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/stomach/stomach_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/stomach/stomach_style.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['stomach']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.stomachUpright;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

/// A cell the Atlas names for each part of the stomach a cell lives in,
/// and the shape it is drawn as.
const Map<StomachHome, (String, CellShape)> _cells =
    <StomachHome, (String, CellShape)>{
      StomachHome.mucosa: ('Mitotic cells (Stomach)', CellShape.dividing),
      StomachHome.muscularis: ('Smooth muscle cells', CellShape.spindle),
    };

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

StomachForm _form(AnatomyFigure figure, StomachHome home) => StomachForm.place(
  part: _part(figure),
  anatomy: _anatomy,
  view: _view,
  home: home,
);

OrganArt _organ(AnatomyFigure figure, StomachHome home) => OrganArt.forTissue(
  _anatomy,
  _part(figure),
  _view,
  figure: figure,
  shape: _cells[home]!.$2,
  cellName: _cells[home]!.$1,
);

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// do the red the arteries are drawn in and the clay of the gut.
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
  testWidgets('the mark shows only where the zoom’s cell lives: the mucosa, '
      'one flat tone, its rugae cut into it, or the muscularis in the cut '
      'wall; no mesh leans to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = StomachArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final AnatomyFigure figure in _figures) {
      for (final StomachHome where in StomachHome.values) {
        final String what = '${figure.name} ${where.name}';
        final StomachForm form = _form(figure, where);
        final StomachArt art = StomachArt(form, inks);
        for (final (String part, Float32List _, Int32List colours)
            in art.meshData) {
          expect(
            colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
            isEmpty,
            reason: '$what: $part',
          );
        }
        final Map<String, Color> fills = art.fills;
        for (final MapEntry<String, Color> fill in fills.entries) {
          expect(
            fill.value.toARGB32() == home.toARGB32(),
            fill.key == where.name,
            reason: '$what: ${fill.key}',
          );
          if (fill.key != where.name) {
            expect(
              _tealness(fill.value.toARGB32()),
              lessThan(0.01),
              reason: '$what: ${fill.key}',
            );
          }
        }
        final _Record canvas = _Record();
        art
          ..prepare()
          ..paint(canvas, form.mm(0.25));
        final List<int> marked = <int>[
          for (final (Rect _, Color colour) in canvas.paths)
            if (_tealness(colour.toARGB32()) > 0.01) colour.toARGB32(),
        ];
        // The mucosa where the wall is cut and its surface; or the
        // muscularis, and its floor along it.
        expect(marked, <int>[home.toARGB32(), home.toARGB32()], reason: what);
        expect(canvas.points, isEmpty, reason: what);
        expect(
          StomachArt.bedOf(inks, where) == home,
          where == StomachHome.mucosa,
        );
      }
    }
  });

  testWidgets('at the hand-over the stomach is the body’s own outline, flat '
      'in the mark, with no layer, mesh or point; at its stop the stomach, '
      'with no layer, the figure’s own parts round it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final double real = _anatomy.metres / part.extent;
      final Rect body = Contour(<Offset>[
        for (final Offset p in part.followed)
          (p - part.centre) * (real / _view),
      ]).toPath().getBounds();
      final OrganArt art = _organ(figure, StomachHome.mucosa);
      expect(art.followsBody, isTrue, reason: what);
      expect(art.real, closeTo(real, 1e-12), reason: what);
      final _Record handed = _Record();
      art.paint(handed, inks, 1 / 390, 1 / real, detail: 0);
      expect(handed.layers, 0, reason: what);
      expect(handed.meshes, 0, reason: what);
      expect(handed.points, isEmpty, reason: what);
      expect(
        <Rect>[for (final (Rect bounds, Color _) in handed.paths) bounds],
        contains(body),
        reason: what,
      );
      final _Record rest = _Record();
      art.paint(rest, inks, 1 / 390, 1);
      expect(rest.layers, 0, reason: what);
      expect(rest.meshes, greaterThan(0), reason: what);
      // The figure's parts round it reach well past the stomach's box.
      final Rect stomach = art.outline.getBounds();
      expect(
        rest.paths.where(
          ((Rect, Color) p) =>
              p.$1.width > stomach.width * 2 && p.$1.height > stomach.height,
        ),
        isNotEmpty,
        reason: what,
      );
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final StomachHome home in StomachHome.values) {
      final StomachArt first = StomachArt(
        _form(AnatomyFigure.female, home),
        inks,
      );
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = StomachArt(
        _form(AnatomyFigure.female, home),
        inks,
      ).meshData;
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i].$1, b[i].$1);
        expect(a[i].$2, b[i].$2);
        expect(a[i].$3, b[i].$3);
        expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
        final Float32List xy = a[i].$2;
        for (int k = 0; k < xy.length; k += 2) {
          expect(
            first.bounds.contains(Offset(xy[k], xy[k + 1])),
            isTrue,
            reason: '${home.name}: ${a[i].$1}',
          );
        }
      }
      final _Record canvas = _Record();
      first
        ..prepare()
        ..paint(canvas, first.form.mm(0.25));
      for (final (Rect r, Color _) in canvas.paths) {
        expect(
          first.bounds.inflate(1e-9).contains(r.topLeft) &&
              first.bounds.inflate(1e-9).contains(r.bottomRight),
          isTrue,
          reason: '${home.name}: $r',
        );
      }
    }
  });

  test('it names where the zoom’s cell lives, in the mark, and its parts, '
      'what runs on from it and its rugae in the quiet ink, set round it', () {
    for (final AnatomyFigure figure in _figures) {
      for (final StomachHome home in StomachHome.values) {
        final String what = '${figure.name} ${home.name}';
        final OrganArt art = _organ(figure, home);
        final StomachForm form = _form(figure, home);
        expect(
          <String>[for (final OrganName n in art.names) n.word],
          <String>[
            home.name,
            'esophagus',
            'fundus',
            'body',
            'rugae',
            'antrum',
            'pylorus',
            'duodenum',
          ],
          reason: what,
        );
        expect(
          <bool>[for (final OrganName n in art.names) n.home],
          <bool>[true, for (int i = 1; i < art.names.length; i++) false],
          reason: what,
        );
        expect(
          art.names.first.at,
          home == StomachHome.muscularis ? form.wallNear(form.site) : art.site,
          reason: what,
        );
        expect(art.columns, isEmpty, reason: what);
        expect(art.named, isNotEmpty, reason: what);
        OrganName name(String key) =>
            art.names.firstWhere((OrganName n) => n.key == key);
        // Its parts named inside it, what runs on from it outside.
        for (final String key in <String>[
          'fundus',
          'body',
          'rugae',
          'antrum',
          'pylorus',
        ]) {
          expect(form.contains(name(key).at), isTrue, reason: '$what: $key');
        }
        for (final String key in <String>['esophagus', 'duodenum']) {
          expect(form.contains(name(key).at), isFalse, reason: '$what: $key');
        }
        // The fundus above the cardia, the antrum below the body, the
        // pylorus at its far end.
        expect(name('fundus').at.dy, lessThan(form.zLine.first.dy));
        expect(name('antrum').at.dy, greaterThan(name('body').at.dy));
        expect(name('pylorus').at.dx, lessThan(name('antrum').at.dx));
        expect(
          (name('rugae').at - art.site).distance / form.scale,
          greaterThan(30),
          reason: what,
        );
        expect(art.outline.contains(art.site), isTrue, reason: what);
      }
    }
  });

  testWidgets('on the steps to the stomach and back nothing pops or jumps: '
      'its outline drawn in, the stomach coming up, the figure staying round '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.p53;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.stomach);
    final StomachForm form = StomachForm.place(
      part: subject.bodyPart!,
      anatomy: subject.anatomy!,
      view: subject.depth.widthOf(ZoomStop.organ),
      home: StomachHome.of(subject.path.cellName),
    );
    expect(form.home, StomachHome.mucosa);
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
            reason: '$where: the stomach',
          );
        }
        lastShown = shown;
        final double grown = scene.grownAt(frame);
        final List<Offset> outline = form.outlineAt(
          SpecimenStep.settle(detail, span: StomachStyle.settling),
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
