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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skeletal_muscle/thigh_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skeletal_muscle/thigh_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skeletal_muscle/thigh_style.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['skeletal muscle']!;
final AnatomyPart _part = AnatomyFigure.female.parts[_anatomy.uberon]!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.muscleUpright;

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

ThighForm _form() =>
    ThighForm.place(part: _part, figure: AnatomyFigure.female, view: _view);

OrganArt _organ([CellShape cell = CellShape.myofibre]) => OrganArt.forTissue(
  _anatomy,
  _part,
  _view,
  figure: AnatomyFigure.female,
  shape: cell,
);

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// does the red the vessels are drawn in, and the clay the muscles are
/// warmed toward.
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
  testWidgets('the mark shows only on the vastus lateralis, one flat tone, '
      'and the bed it comes up on; no mesh leans to it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final ThighForm form = _form();
    expect(
      ThighArt.homeOf(inks),
      Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)),
    );
    expect(ThighArt.bedOf(inks), ThighArt.homeOf(inks));
    final ThighArt art = ThighArt(form, inks);
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
      ..paint(canvas, form.mm(0.5));
    expect(canvas.points, isEmpty);
    final Rect lateralis =
        (Path()..addPolygon(form.vastusLateralis.outline, true)).getBounds();
    final List<(Rect, Color)> marked = <(Rect, Color)>[
      for (final (Rect bounds, Color colour) in canvas.paths)
        if (_tealness(colour.toARGB32()) > 0.01) (bounds, colour),
    ];
    expect(marked, hasLength(1));
    expect(marked.single.$1, lateralis);
    expect(marked.single.$2.toARGB32(), ThighArt.homeOf(inks).toARGB32());
  });

  testWidgets('at the hand-over the thigh is the body’s own outlines, the '
      'vastus lateralis’s flat in the mark and the other four beside it, '
      'with no layer, mesh or point; at its stop the thigh, with no layer, '
      'the figure’s own parts round it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    Offset placed(Offset p) => (p - _part.centre) / _view;
    final Rect body = Contour(<Offset>[
      for (final Offset p in _part.followed) placed(p),
    ]).toPath().getBounds();
    final Path othersPath = Path();
    for (final List<Offset> other in _part.others) {
      othersPath.addPolygon(<Offset>[
        for (final Offset p in other) placed(p),
      ], true);
    }
    final Rect others = othersPath.getBounds();
    final OrganArt art = _organ();
    expect(art.followsBody, isTrue);
    expect(art.real, 1);
    final _Record handed = _Record();
    art.paint(handed, inks, 1 / 390, 1, detail: 0);
    expect(handed.layers, 0);
    expect(handed.meshes, 0);
    expect(handed.points, isEmpty);
    final List<Rect> drawn = <Rect>[
      for (final (Rect bounds, Color _) in handed.paths) bounds,
    ];
    expect(drawn, contains(body));
    expect(
      drawn.where(
        (Rect r) =>
            (r.left - others.left).abs() < 1e-6 &&
            (r.bottom - others.bottom).abs() < 1e-6,
      ),
      isNotEmpty,
    );
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
    expect(
      rest.paths.where(
        ((Rect, Color) p) =>
            (p.$1.left - others.left).abs() < 1e-6 &&
            (p.$1.bottom - others.bottom).abs() < 1e-6,
      ),
      isEmpty,
    );
    // The figure's own parts stay round it, faint, as the body drew them:
    // the pelvis and the other leg, reaching well past it.
    final Rect thigh = art.outline.getBounds();
    expect(
      rest.paths.where(
        ((Rect, Color) p) =>
            p.$1.right > thigh.right + thigh.width * 0.5 &&
            p.$1.height > thigh.height,
      ),
      isNotEmpty,
    );
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final List<(String, Float32List, Int32List)> a = ThighArt(
      _form(),
      inks,
    ).meshData;
    final List<(String, Float32List, Int32List)> b = ThighArt(
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

  test('it names the vastus lateralis, in the mark, at the place its tissue '
      'is sampled, and the rectus femoris, the sartorius and the vastus '
      'medialis, in the quiet ink, in columns at either edge, the lateral '
      'ones on the left; whatever the cell', () {
    for (final CellShape cell in CellShape.values) {
      final OrganArt art = _organ(cell);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          'vastus\nlateralis',
          'rectus\nfemoris',
          'sartorius',
          'vastus\nmedialis',
        ],
        reason: cell.name,
      );
      expect(
        <bool>[for (final OrganName n in art.names) n.home],
        <bool>[true, false, false, false],
      );
      expect(art.names.first.at, art.site);
      expect(art.named, isEmpty);
      expect(
        <String, double>{
          for (final MapEntry<String, OrganColumn> c in art.columns.entries)
            c.key: c.value.side,
        },
        <String, double>{
          'home': -1,
          'rectus': -1,
          'sartorius': 1,
          'medialis': 1,
        },
      );
      expect(art.outline.contains(art.site), isTrue);
    }
  });

  testWidgets('on the steps to the thigh and back nothing pops or jumps: the '
      'vastus lateralis’s outline drawn in, the other four giving way, the '
      'thigh coming up', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final String slug in <String>['myoglobin', 'dystrophin']) {
      final ProteinTarget t = TestCatalog.bySlug(slug)!;
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ZoomSubject subject = stage.subject;
      expect(subject.anatomy!.organ, OrganKind.skeletalMuscle);
      final ThighForm form = ThighForm.place(
        part: subject.bodyPart!,
        figure: subject.body,
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
          // The thigh comes up as the four give way.
          final double shown = frame.opacity * SpecimenStep.come(detail);
          final String where =
              '$slug from ${flight.from} to ${flight.to}, '
              'frame $f';
          if (lastShown != null) {
            expect(
              (shown - lastShown).abs(),
              lessThanOrEqualTo(0.08),
              reason: '$where: the thigh',
            );
          }
          lastShown = shown;
          final double grown = scene.grownAt(frame);
          final List<Offset> outline = form.outlineAt(
            SpecimenStep.settle(detail, span: ThighStyle.settling),
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
