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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bone_marrow/marrow_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bone_marrow/marrow_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bone_marrow/marrow_style.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['bone marrow']!;
final AnatomyPart _part = AnatomyFigure.female.parts[_anatomy.uberon]!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.phoneAspect;

/// The curated proteins whose zoom goes into the bone marrow: an
/// erythroblast, a megakaryocyte and two white cells.
final List<ProteinTarget> _marrow = <ProteinTarget>[
  for (final String slug in <String>['hemoglobin', 'ppbp', 'fpr1', 'tnf'])
    TestCatalog.bySlug(slug)!,
];

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

MarrowForm _form() =>
    MarrowForm.place(part: _part, anatomy: _anatomy, view: _view);

OrganArt _organ(CellShape cell) => OrganArt.forTissue(
  _anatomy,
  _part,
  _view,
  figure: AnatomyFigure.female,
  shape: cell,
);

/// Kinds of cell a path may land in in the marrow, as the Atlas's cells
/// there are drawn, and one of no blood-forming kind.
const List<CellShape> _cells = <CellShape>[
  CellShape.erythroid,
  CellShape.megakaryocyte,
  CellShape.leukocyte,
  CellShape.adipocyte,
];

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// does the red the artery is drawn in.
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
  testWidgets('the mark shows only in the red marrow, for every kind of '
      'cell: no mesh leans to it, and of what it draws only the red marrow '
      'is in it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final MarrowForm form = _form();
    final MarrowArt art = MarrowArt(form, inks);
    for (final (String part, Float32List _, Int32List colours)
        in art.meshData) {
      expect(
        colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
        isEmpty,
        reason: part,
      );
    }
    final _Record canvas = _Record();
    art
      ..prepare()
      ..paint(canvas, form.mm(0.25));
    final List<Rect> marked = <Rect>[
      for (final (Rect bounds, Color colour) in canvas.paths)
        if (_tealness(colour.toARGB32()) > 0.01) bounds,
    ];
    expect(marked, <Rect>[form.red.getBounds()]);
    expect(canvas.points, isEmpty);
    // The red marrow is the brain's cortex's one flat tone.
    expect(
      MarrowArt.redOf(inks),
      Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)),
    );
    // Whatever the kind of cell, it is the red marrow the zoom goes into.
    for (final CellShape cell in _cells) {
      final OrganArt organ = _organ(cell);
      expect(organ.names.first.word, 'red marrow', reason: cell.name);
      expect(organ.names.first.home, isTrue, reason: cell.name);
    }
  });

  testWidgets('at the hand-over the femur is the body’s own outline, flat in '
      'the mark, with no layer, mesh or point; at its stop the femur, with '
      'no layer, the figure’s own parts round it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final double real = _anatomy.metres / _part.extent;
    final Rect body = Contour(<Offset>[
      for (final Offset p in _part.followed)
        (p - _part.centre) * (real / _view),
    ]).toPath().getBounds();
    final OrganArt art = _organ(CellShape.erythroid);
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
    // the pelvis above it and the legs beside it reach well past its box.
    final Rect femur = art.outline.getBounds();
    expect(
      rest.paths.where(
        ((Rect, Color) p) =>
            p.$1.top < femur.top - femur.height * 0.05 &&
            p.$1.width > femur.width * 2,
      ),
      isNotEmpty,
    );
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final List<(String, Float32List, Int32List)> a = MarrowArt(
      _form(),
      inks,
    ).meshData;
    final List<(String, Float32List, Int32List)> b = MarrowArt(
      _form(),
      inks,
    ).meshData;
    expect(a.length, b.length);
    for (int i = 0; i < a.length; i++) {
      expect(a[i].$1, b[i].$1);
      expect(a[i].$2, b[i].$2);
      expect(a[i].$3, b[i].$3);
      expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
    }
  });

  test('it names the red marrow, where the tissue is sampled, and the '
      'trabecular bone, the cortical bone and the yellow marrow, no more, '
      'each in a column: the bone’s on the left, the marrow’s on the '
      'right', () {
    final OrganArt art = _organ(CellShape.leukocyte);
    expect(
      <String>[for (final OrganName n in art.names) n.word],
      <String>[
        'red marrow',
        'trabecular bone',
        'cortical bone',
        'yellow marrow',
      ],
    );
    expect(art.names.first.at, art.site);
    expect(art.names.skip(1).every((OrganName n) => !n.home), isTrue);
    expect(art.outline.contains(art.site), isTrue);
    expect(art.columns.keys, <String>[
      for (final OrganName n in art.names) n.key,
    ]);
    for (final OrganName name in art.names) {
      final OrganColumn column = art.columns[name.key]!;
      expect(
        column.side,
        name.word.endsWith('bone') ? -1 : 1,
        reason: name.word,
      );
      expect(column.left.dy, name.at.dy);
      expect(column.right.dy, name.at.dy);
      expect(column.left.dx, lessThanOrEqualTo(name.at.dx));
      expect(column.right.dx, greaterThanOrEqualTo(name.at.dx));
    }
  });

  testWidgets('the finer trabeculae come in as the view closes on the bone, '
      'none at its stop, never faster than 0.08 a frame on the steps to the '
      'tissue and back', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final MarrowForm form = _form();
    // At the stop the femur is under a pixel a millimetre.
    final double stop = form.mm(1) * 390;
    expect(MarrowArt.levelShown(0, stop), 1);
    expect(MarrowArt.levelShown(1, stop), 0);
    expect(MarrowArt.levelShown(2, stop), 0);
    for (int level = 1; level < 3; level++) {
      expect(MarrowArt.levelShown(level, MarrowStyle.levelIn[level].$2), 1);
    }
    for (final ProteinTarget t in _marrow) {
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ZoomDepth depth = stage.depth;
      final double organ = depth.depthOf(ZoomStop.organ);
      final double tissue = depth.depthOf(ZoomStop.tissue);
      for (final ZoomFlight flight in <ZoomFlight>[
        _flight(depth, organ, tissue),
        _flight(depth, tissue, organ),
      ]) {
        List<double>? last;
        int f = 0;
        for (final (OrganScene, ZoomFrame)? at in _organFrames(
          stage,
          flight,
          inks,
        )) {
          f++;
          if (at == null) {
            last = null;
            continue;
          }
          final (OrganScene scene, ZoomFrame frame) = at;
          final double perMm = form.mm(1) * scene.grownAt(frame) / frame.pixel;
          final List<double> now = <double>[
            for (int level = 1; level < 3; level++)
              frame.opacity * MarrowArt.levelShown(level, perMm),
          ];
          if (last != null) {
            for (int k = 0; k < now.length; k++) {
              expect(
                (now[k] - last[k]).abs(),
                lessThanOrEqualTo(0.08),
                reason:
                    '${t.slug} from ${flight.from} to ${flight.to}, frame $f, '
                    'level ${k + 1}',
              );
            }
          }
          last = now;
        }
      }
    }
  });

  testWidgets('on the steps to the femur and back nothing pops or jumps: its '
      'outline drawn in, the femur coming up, the figure staying round '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in _marrow) {
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ZoomSubject subject = stage.subject;
      expect(subject.anatomy!.organ, OrganKind.boneMarrow, reason: t.slug);
      final MarrowForm form = MarrowForm.place(
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
          final String where =
              '${t.slug} from ${flight.from} to ${flight.to}, frame $f';
          if (lastShown != null) {
            expect(
              (shown - lastShown).abs(),
              lessThanOrEqualTo(0.08),
              reason: '$where: the femur',
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
    }
  });
}
