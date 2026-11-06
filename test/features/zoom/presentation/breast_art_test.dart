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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/breast/breast_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/breast/breast_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/breast/breast_style.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['breast']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.breastUpright;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

/// A cell of each part of the breast the Atlas's names light.
const Map<BreastHome, String> _cells = <BreastHome, String>{
  BreastHome.gland: 'Breast lactating cells',
  BreastHome.fat: 'Adipocytes (Breast)',
  BreastHome.nipple: 'Smooth muscle cells',
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

BreastForm _form(AnatomyFigure figure, [BreastHome home = BreastHome.gland]) =>
    BreastForm.place(
      part: _part(figure),
      anatomy: _anatomy,
      view: _view,
      figure: figure,
      home: home,
    );

OrganArt _organ(AnatomyFigure figure, [BreastHome home = BreastHome.gland]) =>
    OrganArt.forTissue(
      _anatomy,
      _part(figure),
      _view,
      figure: figure,
      shape: CellShape.acinar,
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
/// each path drawn with a shader, each set of points and its colour, and
/// how many layers and meshes.
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
  testWidgets('the mark shows only where the zoom’s cell lives: the lobes '
      'and their ducts, the fat, or the nipple and the areola, one flat '
      'tone, its anatomy cut into it; no mesh leans to it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = BreastArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    expect(_tealness(BreastArt.bedOf(inks).toARGB32()), lessThan(0.01));
    // Where each home is drawn flat, by the names its fills go by.
    const Map<BreastHome, Set<String>> marked = <BreastHome, Set<String>>{
      BreastHome.gland: <String>{'gland', 'duct'},
      BreastHome.fat: <String>{'fat'},
      BreastHome.nipple: <String>{'nipple', 'areola'},
    };
    for (final AnatomyFigure figure in _figures) {
      for (final BreastHome where in BreastHome.values) {
        final String what = '${figure.name}, ${where.name}';
        final BreastForm form = _form(figure, where);
        final BreastArt art = BreastArt(form, inks);
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
            marked[where]!.contains(fill.key),
            reason: '$what: ${fill.key}',
          );
          if (!marked[where]!.contains(fill.key)) {
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
        final List<int> teal = <int>[
          for (final (Rect _, Color colour) in canvas.paths)
            if (_tealness(colour.toARGB32()) > 0.01) colour.toARGB32(),
        ];
        // The home's own fills, and nothing else: the lobes and each width
        // of duct; the fat's lobules; or the areola and the nipple.
        expect(teal, isNotEmpty, reason: what);
        expect(
          teal.every((int c) => c == home.toARGB32()),
          isTrue,
          reason: what,
        );
        expect(teal.length, switch (where) {
          BreastHome.gland => 1 + form.ducts.map((d) => d.width).toSet().length,
          BreastHome.fat => 1,
          BreastHome.nipple => 2,
        }, reason: what);
        expect(canvas.points, isEmpty, reason: what);
      }
    }
  });

  testWidgets('at the hand-over the breast is the body’s own outline, flat '
      'in the mark, with no layer, mesh or point; at its stop the breast, '
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
      // The figure's parts round it reach well past the breast's box.
      final Rect breast = art.outline.getBounds();
      expect(
        rest.paths.where(
          ((Rect, Color) p) =>
              p.$1.width > breast.width * 2 && p.$1.height > breast.height,
        ),
        isNotEmpty,
        reason: what,
      );
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in _figures) {
      for (final BreastHome where in BreastHome.values) {
        final String what = '${figure.name}, ${where.name}';
        final BreastArt first = BreastArt(_form(figure, where), inks);
        final List<(String, Float32List, Int32List)> a = first.meshData;
        final List<(String, Float32List, Int32List)> b = BreastArt(
          _form(figure, where),
          inks,
        ).meshData;
        expect(a.length, b.length, reason: what);
        for (int i = 0; i < a.length; i++) {
          expect(a[i].$1, b[i].$1);
          expect(a[i].$2, b[i].$2);
          expect(a[i].$3, b[i].$3);
          expect(
            a[i].$2.length ~/ 2,
            lessThanOrEqualTo(65000),
            reason: a[i].$1,
          );
          final Float32List xy = a[i].$2;
          for (int k = 0; k < xy.length; k += 2) {
            expect(
              first.bounds.contains(Offset(xy[k], xy[k + 1])),
              isTrue,
              reason: '$what: ${a[i].$1}',
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
            reason: '$what: $r',
          );
        }
      }
    }
  });

  test('it names where the zoom’s cell lives, in the mark, and its nipple, '
      'its areola, a ligament, the fat, the pectoralis, its axillary tail '
      'and the figure’s axillary nodes in the quiet ink, each but the one '
      'the home’s name stands for, set round it', () {
    const Map<BreastHome, List<String>> words = <BreastHome, List<String>>{
      BreastHome.gland: <String>[
        'ducts and\nlobules',
        'nipple',
        'areola',
        'Cooper’s\nligament',
        'fat',
        'pectoralis\nmajor',
        'axillary\ntail',
        'axillary\nnodes',
      ],
      BreastHome.fat: <String>[
        'fat',
        'nipple',
        'areola',
        'ducts and\nlobules',
        'Cooper’s\nligament',
        'pectoralis\nmajor',
        'axillary\ntail',
        'axillary\nnodes',
      ],
      BreastHome.nipple: <String>[
        'nipple and\nareola',
        'ducts and\nlobules',
        'Cooper’s\nligament',
        'fat',
        'pectoralis\nmajor',
        'axillary\ntail',
        'axillary\nnodes',
      ],
    };
    for (final AnatomyFigure figure in _figures) {
      for (final BreastHome where in BreastHome.values) {
        final String what = '${figure.name}, ${where.name}';
        final OrganArt art = _organ(figure, where);
        final BreastForm form = _form(figure, where);
        expect(
          <String>[for (final OrganName n in art.names) n.word],
          words[where],
          reason: what,
        );
        expect(
          <bool>[for (final OrganName n in art.names) n.home],
          <bool>[true, for (int i = 1; i < art.names.length; i++) false],
          reason: what,
        );
        expect(art.columns, isEmpty, reason: what);
        expect(art.named, isNotEmpty, reason: what);
        OrganName name(String key) =>
            art.names.firstWhere((OrganName n) => n.key == key);
        // Its parts named inside it, the muscle it lies on and the figure's
        // nodes outside it.
        for (final OrganName n in art.names) {
          final bool inside = form.contains(n.at);
          expect(
            inside,
            n.key != 'pectoralis' && n.key != 'nodes',
            reason: '$what: ${n.key}',
          );
        }
        // The home where the zoom's cell lives, by its kind.
        final Offset home = name('home').at;
        switch (where) {
          case BreastHome.gland:
            expect(home, art.site, reason: what);
          case BreastHome.fat:
            expect(
              form.fatLobules.any((l) => l.centre == home),
              isTrue,
              reason: what,
            );
          case BreastHome.nipple:
            expect(
              (home - form.nipple).distance,
              lessThan(form.nippleRadius),
              reason: what,
            );
        }
        // The pectoralis above it, the tail and the nodes up and out
        // toward the axilla, the fat and the ligament below the cut.
        expect(
          name('pectoralis').at.dy,
          lessThan(form.box.top + 10 * form.scale),
        );
        expect(
          name('tail').at.dx,
          lessThan(form.box.left + form.box.width / 4),
        );
        expect(name('nodes').at.dx, lessThan(name('tail').at.dx));
        expect(name('ligament').at.dy, greaterThan(form.cutLine.$1.dy));
        expect(art.outline.contains(art.site), isTrue, reason: what);
      }
    }
    // Without a figure, no nodes to name.
    final OrganArt bare = OrganArt.forTissue(
      _anatomy,
      _part(AnatomyFigure.female),
      _view,
      cellName: 'Breast lactating cells',
    );
    expect(bare.names, hasLength(7));
  });

  testWidgets('on the steps to the breast and back nothing pops or jumps: '
      'its outline drawn in, the breast coming up, the figure staying round '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('lactalbumin')!;
    final ZoomStage stage = ZoomStage(
      ZoomSubject(track: locusOf(t), record: recordOf(t)),
    );
    final ZoomSubject subject = stage.subject;
    expect(subject.anatomy!.organ, OrganKind.breast);
    final BreastForm form = BreastForm.place(
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
            reason: '$where: the breast',
          );
        }
        lastShown = shown;
        final double grown = scene.grownAt(frame);
        final List<Offset> outline = form.outlineAt(
          SpecimenStep.settle(detail, span: BreastStyle.settling),
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
