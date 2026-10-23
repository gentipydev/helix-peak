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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/kidney/kidney_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/kidney/kidney_form.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['kidney']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.kidneyUpright;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

/// A cell the Atlas names for each part of the kidney a cell lives in.
const Map<KidneyHome, String> _cells = <KidneyHome, String>{
  KidneyHome.cortex: 'Proximal tubular cells',
  KidneyHome.loops: 'Ascending Loop of Henle cells',
  KidneyHome.ducts: 'Renal collecting duct principal cells',
  KidneyHome.papillae: 'Papillary tip epithelial cells',
  KidneyHome.glomeruli: 'Podocytes',
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

KidneyForm _form(AnatomyFigure figure, KidneyHome home) => KidneyForm.place(
  part: _part(figure),
  anatomy: _anatomy,
  view: _view,
  home: home,
);

OrganArt _organ(AnatomyFigure figure, KidneyHome home) => OrganArt.forTissue(
  _anatomy,
  _part(figure),
  _view,
  figure: figure,
  shape: CellShape.epithelial,
  cellName: _cells[home],
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
  testWidgets('the mark shows only where the zoom’s cell lives, one flat '
      'tone: the cortex, the outer medulla and the rays, the pyramids and '
      'the rays, the papillae, or the glomeruli as a dust in it; no mesh '
      'leans to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = KidneyArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final AnatomyFigure figure in _figures) {
      for (final KidneyHome where in KidneyHome.values) {
        final String what = '${figure.name} ${where.name}';
        final KidneyForm form = _form(figure, where);
        final KidneyArt art = KidneyArt(form, inks);
        for (final (String part, Float32List _, Int32List colours)
            in art.meshData) {
          expect(
            colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
            isEmpty,
            reason: '$what: $part',
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
        final List<Color> dust = <Color>[
          for (final (Float32List _, Color colour) in canvas.points) colour,
        ];
        expect(dust, hasLength(1), reason: what);
        if (where == KidneyHome.glomeruli) {
          expect(marked, isEmpty, reason: what);
          expect(dust.single.toARGB32(), inks.mark.toARGB32(), reason: what);
        } else {
          expect(
            _tealness(dust.single.toARGB32()),
            lessThan(0.01),
            reason: what,
          );
          expect(
            <int>{for (final Color c in marked) c.toARGB32()},
            <int>{home.toARGB32()},
            reason: what,
          );
          expect(
            marked,
            hasLength(switch (where) {
              // The cortex, under everything else.
              KidneyHome.cortex => 1,
              // The outer medullae, or the pyramids, and the rays.
              KidneyHome.loops || KidneyHome.ducts => 2,
              KidneyHome.papillae => 1,
              KidneyHome.glomeruli => 0,
            }),
            reason: what,
          );
        }
      }
    }
  });

  testWidgets('at the hand-over the kidney is the body’s own outline, flat in '
      'the mark, with no layer, mesh or point; at its stop the kidney, with '
      'no layer, the other kidney and the figure’s own parts round it', (
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
      // The other kidney, as the body drew it: its outline's corners.
      final Rect other =
          (Path()..addPolygon(<Offset>[
                for (final Offset p in part.others.first)
                  (p - part.centre) * (real / _view),
              ], true))
              .getBounds();
      final OrganArt art = _organ(figure, KidneyHome.loops);
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
      // The other kidney stays as the body drew it, and the figure's parts
      // round it reach well past the kidney's box.
      for (final _Record at in <_Record>[handed, rest]) {
        expect(
          at.paths.where(
            ((Rect, Color) p) => (p.$1.center - other.center).distance < 1e-6,
          ),
          isNotEmpty,
          reason: what,
        );
      }
      final Rect kidney = art.outline.getBounds();
      expect(
        rest.paths.where(
          ((Rect, Color) p) =>
              p.$1.width > kidney.width * 2 && p.$1.height > kidney.height,
        ),
        isNotEmpty,
        reason: what,
      );
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final KidneyHome home in KidneyHome.values) {
      final List<(String, Float32List, Int32List)> a = KidneyArt(
        _form(AnatomyFigure.female, home),
        inks,
      ).meshData;
      final List<(String, Float32List, Int32List)> b = KidneyArt(
        _form(AnatomyFigure.female, home),
        inks,
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

  test('it names where the zoom’s cell lives, in the mark, and the cortex, '
      'the medulla, the renal pelvis and the ureter in the quiet ink, each in '
      'a column on its own side: the parenchyma’s lateral, the hilum’s '
      'medial', () {
    const Map<KidneyHome, String> words = <KidneyHome, String>{
      KidneyHome.cortex: 'cortex',
      KidneyHome.loops: 'loops of\nHenle',
      KidneyHome.ducts: 'collecting\nducts',
      KidneyHome.papillae: 'papillae',
      KidneyHome.glomeruli: 'glomeruli',
    };
    for (final AnatomyFigure figure in _figures) {
      for (final KidneyHome home in KidneyHome.values) {
        final String what = '${figure.name} ${home.name}';
        final OrganArt art = _organ(figure, home);
        final KidneyForm form = _form(figure, home);
        expect(
          <String>[for (final OrganName n in art.names) n.word],
          <String>[
            words[home]!,
            if (home != KidneyHome.cortex) 'cortex',
            'medulla',
            'renal\npelvis',
            'ureter',
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
          home == KidneyHome.papillae ? form.papillaNear(form.site) : art.site,
          reason: what,
        );
        expect(art.named, isEmpty, reason: what);
        for (final OrganName n in art.names) {
          final bool medial = n.key == 'pelvis' || n.key == 'ureter';
          expect(
            art.columns[n.key]!.side,
            medial ? form.side : -form.side,
            reason: '$what: ${n.word}',
          );
        }
        expect(art.outline.contains(art.site), isTrue, reason: what);
      }
    }
  });

  testWidgets('on the steps to the kidney and back nothing pops or jumps: its '
      'outline drawn in, the kidney coming up, the figure staying round '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('uromodulin')!;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.kidney);
    final KidneyForm form = KidneyForm.place(
      part: subject.bodyPart!,
      anatomy: subject.anatomy!,
      view: subject.depth.widthOf(ZoomStop.organ),
      home: KidneyHome.of(subject.path.cellName),
    );
    expect(form.home, KidneyHome.loops);
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
            reason: '$where: the kidney',
          );
        }
        lastShown = shown;
        final double grown = scene.grownAt(frame);
        final List<Offset> outline = form.outlineAt(
          SpecimenStep.settle(detail),
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
