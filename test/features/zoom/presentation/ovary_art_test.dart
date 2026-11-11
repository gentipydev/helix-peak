import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/ovary/ovary_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/ovary/ovary_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/ovary/ovary_style.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['ovary']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.ovaryUpright;
final AnatomyFigure _figure = AnatomyFigure.female;
final AnatomyPart _part = _figure.parts[_anatomy.uberon]!;

/// The figure's parts never drawn round an organ, the skin and the fat;
/// the figure's fallopian tube, which the ovary draws itself; and its
/// smooth muscle, the anatomogram's bladder wall, which lies beside it.
const String _skin = 'UBERON_0000014';
const String _fat = 'UBERON_0001013';
const String _tube = 'UBERON_0003889';
const String _muscle = 'UBERON_0001135';

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

OvaryForm _form([OvaryHome home = OvaryHome.follicles]) =>
    OvaryForm.place(part: _part, anatomy: _anatomy, view: _view, home: home);

/// A cell the Atlas names for each home.
const Map<OvaryHome, String> _cells = <OvaryHome, String>{
  OvaryHome.follicles: 'Oocytes',
  OvaryHome.stroma: 'Ovarian stromal cells',
};

OrganArt _organ([OvaryHome home = OvaryHome.follicles]) => OrganArt.forTissue(
  _anatomy,
  _part,
  _view,
  figure: _figure,
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

/// A canvas that keeps what is drawn on it: each path's and circle's bounds
/// and colour, each path drawn with a shader (the figure's faint parts),
/// each set of points and its colour, and how many layers and meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> paths = <(Rect, Color)>[];
  final List<(Rect, Color)> circles = <(Rect, Color)>[];
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
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add((Rect.fromCircle(center: c, radius: radius), paint.color));

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
      'Atlas’s name for it: every follicle’s granulosa and cumulus and the '
      'dust of the earliest, in the mark itself as the kidney’s glomeruli '
      'are; or the stroma, one flat tone cut by its anatomy; no mesh leans '
      'to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = OvaryArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    expect(OvaryArt.bedOf(inks, OvaryHome.stroma), home);
    expect(
      _tealness(OvaryArt.bedOf(inks, OvaryHome.follicles).toARGB32()),
      lessThan(0.01),
    );
    for (final OvaryHome kind in OvaryHome.values) {
      final String what = kind.name;
      final OvaryForm form = _form(kind);
      expect(form.home, OvaryHome.of(_cells[kind]), reason: what);
      final OvaryArt art = OvaryArt(form, inks);
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
        final bool marked = switch (kind) {
          OvaryHome.follicles => fill.key == 'granulosa',
          OvaryHome.stroma => fill.key == 'cortex' || fill.key == 'medulla',
        };
        if (marked) {
          expect(
            fill.value.toARGB32(),
            (kind == OvaryHome.follicles ? inks.mark : home).toARGB32(),
            reason: '$what: ${fill.key}',
          );
        } else {
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
        ..paint(canvas, form.mm(0.2));
      final List<int> paths = <int>[
        for (final (Rect _, Color colour) in canvas.paths)
          if (_tealness(colour.toARGB32()) > 0.01) colour.toARGB32(),
      ];
      final List<int> circles = <int>[
        for (final (Rect _, Color colour) in canvas.circles)
          if (_tealness(colour.toARGB32()) > 0.01) colour.toARGB32(),
      ];
      switch (kind) {
        case OvaryHome.follicles:
          // The cumuli; every follicle's granulosa; the dust, both kinds.
          expect(paths, <int>[inks.mark.toARGB32()], reason: what);
          expect(
            circles,
            List<int>.filled(form.follicles.length, inks.mark.toARGB32()),
            reason: what,
          );
          expect(canvas.points, hasLength(2), reason: what);
          for (final (Float32List _, Color colour) in canvas.points) {
            expect(colour.toARGB32(), inks.mark.toARGB32(), reason: what);
          }
        case OvaryHome.stroma:
          // The cortex and the medulla.
          expect(paths, <int>[home.toARGB32(), home.toARGB32()], reason: what);
          expect(circles, isEmpty, reason: what);
          expect(canvas.points, isEmpty, reason: what);
      }
    }
  });

  testWidgets('at the hand-over the ovary is the body’s own disc without its '
      'slit, flat in the mark, the other ovary the body’s, flat, with no '
      'layer or mesh; at its stop the ovary, with no layer, the other ovary '
      'still flat beside it and the figure’s own parts round it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final double real = _anatomy.metres / _part.extent;
    Offset placed(Offset p) => (p - _part.centre) * (real / _view);
    final Rect body = Contour(
      OvaryForm.rimOf(<Offset>[
        for (final Offset p in _part.followed) placed(p),
      ]),
    ).toPath().getBounds();
    final OrganArt art = _organ();
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
    // The body's other ovary, flat, beside it.
    final Rect other =
        (Path()..addPolygon(
              OvaryForm.rimOf(<Offset>[
                for (final Offset p in _part.others.single) placed(p),
              ]),
              true,
            ))
            .getBounds();
    expect(handed.paths.where(((Rect, Color) p) => p.$1 == other), isNotEmpty);
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
    expect(rest.paths.where(((Rect, Color) p) => p.$1 == other), isNotEmpty);
    expect(rest.shaded, isNotEmpty);
  });

  testWidgets('the figure’s fallopian tube, which the ovary draws arching '
      'over it, is not drawn round it, and its smooth muscle, the bladder’s '
      'wall, is', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final double real = _anatomy.metres / _part.extent;
    Offset placed(Offset p) => (p - _part.centre) * (real / _view);
    Path outlineOf(List<Offset> contour) => Path()
      ..addPolygon(<Offset>[for (final Offset p in contour) placed(p)], true);
    final OrganArt art = _organ();
    final _Record canvas = _Record();
    art.paint(canvas, inks, 1 / 390, 1);
    expect(canvas.shaded, isNotEmpty);
    final Path around = canvas.shaded.first;
    final List<Path> others = <Path>[
      for (final MapEntry<String, AnatomyPart> other in _figure.parts.entries)
        if (!<String>{_skin, _fat, _tube}.contains(other.key))
          for (final List<Offset> contour in other.value.contours)
            outlineOf(contour),
    ];
    int checked = 0;
    final double step = 5e-4 / _view;
    for (final List<Offset> contour in _figure.parts[_tube]!.contours) {
      final Path tube = outlineOf(contour);
      final Rect box = tube.getBounds();
      for (double y = box.top; y <= box.bottom; y += step) {
        for (double x = box.left; x <= box.right; x += step) {
          final Offset p = Offset(x, y);
          if (!tube.contains(p) ||
              art.outline.contains(p) ||
              others.any((Path o) => o.contains(p))) {
            continue;
          }
          expect(around.contains(p), isFalse, reason: '$p');
          checked++;
        }
      }
    }
    expect(checked, greaterThan(20));
    bool found = false;
    for (final List<Offset> contour in _figure.parts[_muscle]!.contours) {
      final Path muscle = outlineOf(contour);
      final Rect box = muscle.getBounds();
      for (double y = box.top; y <= box.bottom && !found; y += step) {
        for (double x = box.left; x <= box.right && !found; x += step) {
          final Offset p = Offset(x, y);
          found = muscle.contains(p) && around.contains(p);
        }
      }
    }
    expect(found, isTrue);
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final OvaryHome kind in OvaryHome.values) {
      final OvaryArt first = OvaryArt(_form(kind), inks);
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = OvaryArt(
        _form(kind),
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
            reason: '${kind.name}: ${a[i].$1}',
          );
        }
      }
      final _Record canvas = _Record();
      first
        ..prepare()
        ..paint(canvas, first.form.mm(0.2));
      for (final (Rect r, Color _) in <(Rect, Color)>[
        ...canvas.paths,
        ...canvas.circles,
      ]) {
        expect(
          first.bounds.inflate(1e-9).contains(r.topLeft) &&
              first.bounds.inflate(1e-9).contains(r.bottomRight),
          isTrue,
          reason: '${kind.name}: $r',
        );
      }
    }
  });

  test('it names where the zoom’s cell lives, in the mark, and the tube, '
      'the two ligaments, the corpus luteum, the medulla outside the stroma '
      'and a corpus albicans in the quiet ink, set round them', () {
    for (final OvaryHome kind in OvaryHome.values) {
      final String what = kind.name;
      final OrganArt art = _organ(kind);
      final OvaryForm form = _form(kind);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          kind.word,
          'fallopian\ntube',
          'suspensory\nligament',
          'corpus\nluteum',
          if (kind != OvaryHome.stroma) 'medulla',
          'corpus\nalbicans',
          'ovarian\nligament',
        ],
        reason: what,
      );
      expect(
        <bool>[for (final OrganName n in art.names) n.home],
        <bool>[true, for (int i = 1; i < art.names.length; i++) false],
        reason: what,
      );
      expect(art.names.first.at, form.homeName, reason: what);
      expect(art.names.first.at, art.site, reason: what);
      expect(art.columns, isEmpty, reason: what);
      expect(art.named, isNotEmpty, reason: what);
      for (final OrganName n in art.names) {
        if (n.key == 'tube' || n.key == 'suspensory' || n.key == 'ligament') {
          continue;
        }
        expect(form.contains(n.at), isTrue, reason: '$what: ${n.key}');
      }
      expect(art.outline.contains(art.site), isTrue, reason: what);
    }
  });

  testWidgets('on the steps to the ovary and back nothing pops or jumps: '
      'the body’s disc drawn in, the ovary coming up, the figure staying '
      'round it; nor on the steps on to its tissue and back, where only the '
      'view moves it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('padi6')!;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.ovary);
    final OvaryForm form = OvaryForm.place(
      part: subject.bodyPart!,
      anatomy: subject.anatomy!,
      view: subject.depth.widthOf(ZoomStop.organ),
      home: OvaryHome.of(subject.path.cellName),
    );
    expect(form.home, OvaryHome.follicles);
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
            reason: '$where: the ovary',
          );
        }
        lastShown = shown;
        if (flight.from == tissue || flight.to == tissue) {
          continue;
        }
        final double grown = scene.grownAt(frame);
        final List<Offset> outline = form.outlineAt(
          SpecimenStep.settle(detail, span: OvaryStyle.settling),
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
