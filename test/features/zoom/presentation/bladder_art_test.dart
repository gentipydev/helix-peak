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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bladder/bladder_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bladder/bladder_form.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['urinary bladder']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.bladderUpright;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

/// The figure's parts never drawn round an organ (the skin, the fat), and
/// its smooth muscle, which the anatomogram draws as the bladder's wall.
const String _skin = 'UBERON_0000014';
const String _fat = 'UBERON_0001013';
const String _smoothMuscle = 'UBERON_0001135';

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

BladderForm _form(AnatomyFigure figure) => BladderForm.place(
  part: _part(figure),
  anatomy: _anatomy,
  view: _view,
  figure: figure,
);

OrganArt _organ(AnatomyFigure figure) => OrganArt.forTissue(
  _anatomy,
  _part(figure),
  _view,
  figure: figure,
  shape: CellShape.epithelial,
  cellName: 'Urothelial cells',
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
  testWidgets('the mark shows only where the zoom’s cell lives, the '
      'urothelium: one flat tone, its anatomy cut into it, lining the cut '
      'wall; no mesh leans to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = BladderArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    expect(BladderArt.bedOf(inks), home);
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final BladderForm form = _form(figure);
      final BladderArt art = BladderArt(form, inks);
      for (final (String part, Float32List _, Int32List colours)
          in art.meshData) {
        expect(
          colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
          isEmpty,
          reason: '$what: $part',
        );
      }
      for (final MapEntry<String, Color> fill in art.fills.entries) {
        expect(
          fill.value.toARGB32() == home.toARGB32(),
          fill.key == 'urothelium',
          reason: '$what: ${fill.key}',
        );
        if (fill.key != 'urothelium') {
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
      // The urothelium where the wall is cut, its floor along the cut, and
      // its surface.
      expect(marked, <int>[
        home.toARGB32(),
        home.toARGB32(),
        home.toARGB32(),
      ], reason: what);
      expect(canvas.points, isEmpty, reason: what);
    }
  });

  testWidgets('at the hand-over the bladder is the body’s own outline, flat '
      'in the mark, with no layer, mesh or point; at its stop the bladder, '
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
      // The figure's parts round it reach well past the bladder's box.
      final Rect bladder = art.outline.getBounds();
      expect(
        rest.paths.where(
          ((Rect, Color) p) =>
              p.$1.width > bladder.width * 2 && p.$1.height > bladder.height,
        ),
        isNotEmpty,
        reason: what,
      );
    }
  });

  testWidgets('the figure’s smooth muscle, which the anatomogram draws as '
      'the bladder’s own wall, is not drawn round it, and its other parts '
      'are', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    int checked = 0;
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final double real = _anatomy.metres / part.extent;
      Offset placed(Offset p) => (p - part.centre) * (real / _view);
      Path outlineOf(List<Offset> contour) => Path()
        ..addPolygon(<Offset>[for (final Offset p in contour) placed(p)], true);
      final OrganArt art = _organ(figure);
      final _Record canvas = _Record();
      art.paint(canvas, inks, 1 / 390, 1);
      expect(canvas.shaded, isNotEmpty, reason: what);
      final Path around = canvas.shaded.first;
      // What the figure draws besides, each outline on its own.
      final List<Path> others = <Path>[
        for (final MapEntry<String, AnatomyPart> other in figure.parts.entries)
          if (!<String>{_skin, _fat, _smoothMuscle}.contains(other.key))
            for (final List<Offset> contour in other.value.contours)
              outlineOf(contour),
      ];
      final AnatomyPart muscle = figure.parts[_smoothMuscle]!;
      final double step = 2.5e-4 / _view;
      for (final List<Offset> contour in muscle.contours) {
        final Path band = outlineOf(contour);
        final Rect box = band.getBounds();
        for (double y = box.top; y <= box.bottom; y += step) {
          for (double x = box.left; x <= box.right; x += step) {
            final Offset p = Offset(x, y);
            if (!band.contains(p) ||
                art.outline.contains(p) ||
                others.any((Path o) => o.contains(p))) {
              continue;
            }
            expect(around.contains(p), isFalse, reason: '$what at $p');
            checked++;
          }
        }
      }
      // The figure's uterus or prostate below it is still drawn round it.
      final BladderForm form = _form(figure);
      expect(around.contains(form.neighbourName!), isTrue, reason: what);
    }
    expect(checked, greaterThan(20));
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in _figures) {
      final BladderArt first = BladderArt(_form(figure), inks);
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = BladderArt(
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

  test('it names where the zoom’s cell lives, in the mark, and its trigone, '
      'a ureter’s orifice, that ureter, its detrusor, its urethra and the '
      'figure’s uterus or prostate below it in the quiet ink, set round '
      'it', () {
    for (final (AnatomyFigure figure, String neighbour)
        in <(AnatomyFigure, String)>[
          (AnatomyFigure.female, 'uterus'),
          (AnatomyFigure.male, 'prostate'),
        ]) {
      final String what = figure.name;
      final OrganArt art = _organ(figure);
      final BladderForm form = _form(figure);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          'urothelium',
          'trigone',
          'ureteric orifice',
          'ureter',
          'detrusor',
          'urethra',
          neighbour,
        ],
        reason: what,
      );
      expect(
        <bool>[for (final OrganName n in art.names) n.home],
        <bool>[true, for (int i = 1; i < art.names.length; i++) false],
        reason: what,
      );
      expect(art.names.first.at, art.site, reason: what);
      expect(art.columns, isEmpty, reason: what);
      expect(art.named, isNotEmpty, reason: what);
      OrganName name(String key) =>
          art.names.firstWhere((OrganName n) => n.key == key);
      // Its parts named inside it, what runs on from it and the figure's
      // neighbour outside.
      for (final String key in <String>['trigone', 'orifice', 'detrusor']) {
        expect(form.contains(name(key).at), isTrue, reason: '$what: $key');
      }
      for (final String key in <String>['ureter', 'urethra', 'neighbour']) {
        expect(form.contains(name(key).at), isFalse, reason: '$what: $key');
      }
      // The trigone below the place the zoom goes in, the urethra below the
      // bladder, the ureter beside it, on the side its orifice is named.
      expect(name('trigone').at.dy, greaterThan(art.site.dy));
      expect(name('urethra').at.dy, greaterThan(form.box.bottom));
      expect(name('ureter').at.dx, lessThan(form.box.left));
      expect(name('orifice').at.dx, lessThan(form.box.center.dx));
      expect(name('neighbour').at.dx, greaterThan(form.box.center.dx));
      expect(name('detrusor').at.dx, greaterThan(form.box.center.dx));
      expect(art.outline.contains(art.site), isTrue, reason: what);
    }
    // Without a figure, nothing round it to name.
    final OrganArt bare = OrganArt.forTissue(
      _anatomy,
      _part(AnatomyFigure.female),
      _view,
      cellName: 'Urothelial cells',
    );
    expect(bare.names, hasLength(6));
  });

  testWidgets('on the steps to the bladder and back nothing pops or jumps: '
      'its outline drawn in, the bladder coming up, the figure staying round '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('s100p')!;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.bladder);
    final BladderForm form = BladderForm.place(
      part: subject.bodyPart!,
      anatomy: subject.anatomy!,
      view: subject.depth.widthOf(ZoomStop.organ),
      figure: subject.body,
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
            reason: '$where: the bladder',
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
