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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/intestine/intestine_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/intestine/intestine_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/intestine/intestine_style.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['intestine']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.intestineUpright;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

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

IntestineForm _form(
  AnatomyFigure figure, [
  IntestineHome home = IntestineHome.colon,
]) => IntestineForm.place(
  part: _part(figure),
  anatomy: _anatomy,
  view: _view,
  home: home,
);

/// A cell the Atlas names for each home.
const Map<IntestineHome, String> _cells = <IntestineHome, String>{
  IntestineHome.colon: 'Colon enteroendocrine cells',
  IntestineHome.ileum: 'Enterocytes',
  IntestineHome.both: 'Goblet cells',
  IntestineHome.muscle: 'Smooth muscle cells',
};

OrganArt _organ(
  AnatomyFigure figure, [
  IntestineHome home = IntestineHome.colon,
]) => OrganArt.forTissue(
  _anatomy,
  _part(figure),
  _view,
  figure: figure,
  shape: CellShape.endocrine,
  cellName: _cells[home],
);

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// does the red the arteries are drawn in.
double _tealness(int colour) {
  final double r = (colour >> 16 & 255) / 255;
  final double g = (colour >> 8 & 255) / 255;
  final double b = (colour & 255) / 255;
  return b < g ? g - r : 2 * g - r - b;
}

/// A canvas that keeps what is drawn on it: each path's bounds and colour,
/// each path drawn with a shader (the figure's faint parts), each set of
/// points and its colour, and how many layers and meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> paths = <(Rect, Color)>[];
  final List<Path> shaded = <Path>[];
  final List<(Float32List, Color)> points = <(Float32List, Color)>[];
  int layers = 0;
  int meshes = 0;

  @override
  void drawPath(Path path, Paint paint) {
    paths.add((path.getBounds(), paint.color));
    if (paint.shader != null && paint.style == PaintingStyle.fill) {
      shaded.add(path);
    }
  }

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
  testWidgets('the mark shows only where the zoom’s cell lives, by the '
      'Atlas’s name for it: the colon’s lining, the ileum’s, both, or the '
      'muscle; one flat tone, lining the cut wall; no mesh leans to it but '
      'the colon’s band for a muscle cell', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = IntestineArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    expect(_tealness(IntestineArt.bedOf(inks).toARGB32()), lessThan(0.01));
    for (final AnatomyFigure figure in _figures) {
      for (final IntestineHome kind in IntestineHome.values) {
        final String what = '${figure.name}, ${kind.name}';
        final IntestineForm form = _form(figure, kind);
        expect(form.home, IntestineHome.of(_cells[kind]), reason: what);
        final IntestineArt art = IntestineArt(form, inks);
        for (final (String part, Float32List _, Int32List colours)
            in art.meshData) {
          final Iterable<int> teal = colours.where(
            (int c) => c >>> 24 != 0 && _tealness(c) > 0.01,
          );
          if (kind == IntestineHome.muscle && part.contains('colon')) {
            // The band, flat in the mark.
            expect(teal, isNotEmpty, reason: '$what: $part');
            expect(
              teal.every((int c) => c.toUnsigned(32) == home.toARGB32()),
              isTrue,
              reason: '$what: $part',
            );
          } else {
            expect(teal, isEmpty, reason: '$what: $part');
          }
        }
        final Map<String, Color> fills = art.fills;
        bool marked(String key) => switch (key) {
          'colon lining' => kind.inColon,
          'ileum lining' => kind.inIleum,
          'muscle' => kind == IntestineHome.muscle,
          _ => false,
        };
        for (final MapEntry<String, Color> fill in fills.entries) {
          expect(
            fill.value.toARGB32() == home.toARGB32(),
            marked(fill.key),
            reason: '$what: ${fill.key}',
          );
          if (!marked(fill.key)) {
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
        final List<int> paths = <int>[
          for (final (Rect _, Color colour) in canvas.paths)
            if (_tealness(colour.toARGB32()) > 0.01) colour.toARGB32(),
        ];
        // Each lining where it is the cell's: its cut face, its floor along
        // the cut and its surface; or each opening's two muscle coats and
        // their floor.
        final int openings = switch (kind) {
          IntestineHome.both || IntestineHome.muscle => 2,
          _ => 1,
        };
        expect(paths, hasLength(3 * openings), reason: what);
        expect(paths.toSet(), <int>{home.toARGB32()}, reason: what);
        // The patch's nodules, in the shadow ink.
        expect(canvas.points, hasLength(1), reason: what);
        expect(
          _tealness(canvas.points.single.$2.toARGB32()),
          lessThan(0.01),
          reason: what,
        );
      }
    }
  });

  testWidgets('at the hand-over the intestines are the body’s own outline, '
      'flat in the mark, with no layer, mesh or point; at their stop the '
      'intestines, with no layer, the figure’s own parts round them', (
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
      final OrganArt art = _organ(figure);
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
      // The figure's parts round them reach well past their box.
      final Rect intestines = art.outline.getBounds();
      expect(
        rest.paths.where(
          ((Rect, Color) p) =>
              p.$1.width > intestines.width * 1.5 &&
              p.$1.height > intestines.height,
        ),
        isNotEmpty,
        reason: what,
      );
      expect(rest.shaded, isNotEmpty, reason: what);
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in _figures) {
      final IntestineArt first = IntestineArt(_form(figure), inks);
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = IntestineArt(
        _form(figure),
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
            reason: '${figure.name}: ${a[i].$1}',
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
          reason: '${figure.name}: $r',
        );
      }
    }
  });

  test('it names where the zoom’s cell lives, in the mark, and the '
      'transverse and the descending colon, the jejunum, the ileum and the '
      'appendix in the quiet ink, set round it', () {
    for (final AnatomyFigure figure in _figures) {
      for (final IntestineHome kind in IntestineHome.values) {
        final String what = '${figure.name}, ${kind.name}';
        final OrganArt art = _organ(figure, kind);
        final IntestineForm form = _form(figure, kind);
        expect(
          <String>[for (final OrganName n in art.names) n.word],
          <String>[
            if (kind == IntestineHome.muscle) 'muscularis' else 'mucosa',
            'transverse\ncolon',
            'jejunum',
            'descending\ncolon',
            'ileum',
            'appendix',
          ],
          reason: what,
        );
        expect(
          <bool>[for (final OrganName n in art.names) n.home],
          <bool>[true, for (int i = 1; i < art.names.length; i++) false],
          reason: what,
        );
        expect(art.names.first.at, form.homeName, reason: what);
        expect(art.columns, isEmpty, reason: what);
        expect(art.named, isNotEmpty, reason: what);
        for (final OrganName n in art.names) {
          expect(form.contains(n.at), isTrue, reason: '$what: ${n.key}');
        }
        expect(art.outline.contains(art.site), isTrue, reason: what);
      }
    }
  });

  testWidgets('on the steps to the intestines and back nothing pops or '
      'jumps: their outline drawn in, the intestines coming up, the figure '
      'staying round them; nor on the steps on to their tissue and back, '
      'where only the view moves them', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('fabp6')!;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.intestine);
    final IntestineForm form = IntestineForm.place(
      part: subject.bodyPart!,
      anatomy: subject.anatomy!,
      view: subject.depth.widthOf(ZoomStop.organ),
      home: IntestineHome.of(subject.path.cellName),
    );
    expect(form.home, IntestineHome.colon);
    final ZoomDepth depth = stage.depth;
    final double body = depth.depthOf(ZoomStop.body);
    final double organ = depth.depthOf(ZoomStop.organ);
    final double tissue = depth.depthOf(ZoomStop.tissue);
    for (final ZoomFlight flight in <ZoomFlight>[
      _flight(depth, body, organ),
      _flight(depth, organ, body),
      _flight(depth, organ, tissue),
      _flight(depth, tissue, organ),
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
            reason: '$where: the intestines',
          );
        }
        lastShown = shown;
        // Settled, on the steps to the tissue, the outline moves only as
        // the view does, as every organ's does.
        if (flight.from == tissue || flight.to == tissue) {
          continue;
        }
        final double grown = scene.grownAt(frame);
        final List<Offset> outline = form.outlineAt(
          SpecimenStep.settle(detail, span: IntestineStyle.settling),
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
