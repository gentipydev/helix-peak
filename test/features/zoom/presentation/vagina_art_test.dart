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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vagina/vagina_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vagina/vagina_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vagina/vagina_style.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['vagina']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.vaginaUpright;

/// The vagina is the female figure's alone.
final AnatomyFigure _figure = AnatomyFigure.female;
final AnatomyPart _part = _figure.parts[_anatomy.uberon]!;

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

VaginaForm _form() =>
    VaginaForm.place(part: _part, anatomy: _anatomy, view: _view);

/// The vagina as the zoom draws it: no cell the Atlas names lives there,
/// so the zoom draws the tissue's own, a squamous cell.
OrganArt _organ() => OrganArt.forTissue(
  _anatomy,
  _part,
  _view,
  figure: _figure,
  shape: CellShape.epithelial,
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
  testWidgets('the mark shows only where the zoom goes in, the front wall: '
      'one flat tone, its anatomy cut into it; no mesh leans to it, and the '
      'bed is the back wall', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = VaginaArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    final VaginaForm form = _form();
    final VaginaArt art = VaginaArt(form, inks);
    expect(VaginaArt.bedOf(inks), art.fills['back wall']);
    for (final (String part, Float32List _, Int32List colours)
        in art.meshData) {
      expect(
        colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
        isEmpty,
        reason: part,
      );
    }
    for (final MapEntry<String, Color> fill in art.fills.entries) {
      expect(
        fill.value.toARGB32() == home.toARGB32(),
        fill.key == 'front wall',
        reason: fill.key,
      );
      if (fill.key != 'front wall') {
        expect(
          _tealness(fill.value.toARGB32()),
          lessThan(0.01),
          reason: fill.key,
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
    // The front wall's halves, once.
    expect(marked, <int>[home.toARGB32()]);
    expect(canvas.points, isEmpty);
  });

  testWidgets('at the hand-over the vagina is the body’s own outline of it, '
      'flat in the mark, with no layer, mesh or point, the figure round it; '
      'at its stop the pinned specimen, with no layer, the figure gone', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final double real = _anatomy.metres / _part.extent;
    Offset placed(Offset p) => (p - _part.centre) * (real / _view);
    final Rect cup = Contour(<Offset>[
      for (final Offset p in _part.followed) placed(p),
    ]).toPath().getBounds();
    final OrganArt art = _organ();
    expect(art.followsBody, isTrue);
    expect(art.real, closeTo(real, 1e-12));
    final _Record handed = _Record();
    art.paint(handed, inks, 1 / 390, 1 / real, detail: 0);
    expect(handed.layers, 0);
    expect(handed.meshes, 0);
    expect(handed.points, isEmpty);
    expect(handed.shaded, isNotEmpty);
    expect(<Rect>[
      for (final (Rect b, Color _) in handed.paths) b,
    ], contains(cup));
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
    // Laid open at its size, the figure's parts round it lie nowhere true:
    // they have given way.
    expect(rest.shaded, isEmpty);
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final VaginaArt first = VaginaArt(_form(), inks);
    final List<(String, Float32List, Int32List)> a = first.meshData;
    final List<(String, Float32List, Int32List)> b = VaginaArt(
      _form(),
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
          reason: a[i].$1,
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
        reason: '$r',
      );
    }
  });

  test('it names where the zoom goes in, in the mark, and the cervix, the '
      'posterior fornix, the rugae and the hymen in the quiet ink, set round '
      'it', () {
    final OrganArt art = _organ();
    expect(
      <String>[for (final OrganName n in art.names) n.word],
      <String>['anterior wall', 'cervix', 'posterior fornix', 'rugae', 'hymen'],
    );
    expect(
      <bool>[for (final OrganName n in art.names) n.home],
      <bool>[true, for (int i = 1; i < art.names.length; i++) false],
    );
    expect(art.columns, isEmpty);
    expect(art.named, isNotEmpty);
    expect(art.names.first.at, art.site);
    expect(art.outline.contains(art.site), isTrue);
  });

  testWidgets('on the steps to the vagina and back nothing pops or jumps: '
      'the body’s cup drawn in, the vagina coming up, the figure giving '
      'way', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('alox12')!;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.vagina);
    final VaginaForm form = VaginaForm.place(
      part: subject.bodyPart!,
      anatomy: subject.anatomy!,
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
            reason: '$where: the vagina',
          );
        }
        lastShown = shown;
        final double grown = scene.grownAt(frame);
        final List<Offset> outline = form.outlineAt(
          SpecimenStep.settle(detail, span: VaginaStyle.settling),
        );
        final List<Offset> now = <Offset>[
          for (int i = 0; i < outline.length; i += 12)
            frame.toScreen(outline[i] * grown),
        ];
        if (before != null && last != null) {
          final Offset centre = _canvas.center(Offset.zero);
          for (int i = 0; i < now.length; i++) {
            final Offset second = now[i] - last[i] * 2 + before[i];
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
