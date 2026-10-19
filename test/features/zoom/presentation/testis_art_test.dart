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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/testis/testis_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/testis/testis_form.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['testis']!;
final AnatomyPart _part = AnatomyFigure.male.parts[_anatomy.uberon]!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.testisUpright;

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

TestisForm _form() =>
    TestisForm.place(part: _part, anatomy: _anatomy, view: _view);

OrganArt _organ(CellShape cell) => OrganArt.forTissue(
  _anatomy,
  _part,
  _view,
  figure: AnatomyFigure.male,
  shape: cell,
);

/// The kinds of cell that live in the testis, as the Atlas's cells there
/// are drawn: germ cells, Sertoli cells, Leydig cells, peritubular cells.
const List<CellShape> _cells = <CellShape>[
  CellShape.germ,
  CellShape.epithelial,
  CellShape.endocrine,
  CellShape.spindle,
];

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

void main() {
  testWidgets('the mark shows only where the zoom’s cell lives: the '
      'tubules, or for a Leydig cell the interstitium between them; never '
      'the tunica, the mediastinum, the epididymis or the cord', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final TestisForm form = _form();
    for (final CellShape cell in _cells) {
      final TestisHome home = TestisHome.of(cell);
      expect(
        home,
        cell == CellShape.endocrine
            ? TestisHome.interstitium
            : TestisHome.tubules,
      );
      final Map<String, int> teal = <String, int>{};
      for (final (String part, Float32List _, Int32List colours) in TestisArt(
        form,
        inks,
        home: home,
      ).meshData) {
        int leaning = 0;
        for (final int colour in colours) {
          if (colour >>> 24 != 0 && _tealness(colour) > 0.01) {
            leaning++;
          }
        }
        teal[part] = (teal[part] ?? 0) + leaning;
      }
      expect(
        teal.keys,
        containsAll(<String>[
          'tubules',
          'tunica',
          'mediastinum',
          'epididymis',
          'ductules',
          'vas',
          'vessels',
        ]),
      );
      for (final MapEntry<String, int> part in teal.entries) {
        expect(
          part.value > 0,
          part.key == 'tubules' && home == TestisHome.tubules,
          reason: '${cell.name}: ${part.key}',
        );
      }
      final _Record canvas = _Record();
      TestisArt(form, inks, home: home)
        ..prepare()
        ..paint(canvas, form.mm(0.15));
      // No path is drawn in the mark: not the bed, the septa, the rete or
      // the tunica vaginalis.
      expect(
        <Color>[
          for (final (Rect _, Color colour) in canvas.paths)
            if (_tealness(colour.toARGB32()) > 0.01) colour,
        ],
        isEmpty,
        reason: cell.name,
      );
      // Points in the mark are the Leydig cells' clusters, for theirs, in
      // the cut face and out of the mediastinum.
      final List<Float32List> marked = <Float32List>[
        for (final (Float32List points, Color colour) in canvas.points)
          if (_tealness(colour.toARGB32()) > 0.01) points,
      ];
      if (home == TestisHome.tubules) {
        expect(marked, isEmpty, reason: cell.name);
      } else {
        expect(marked, isNotEmpty);
        for (final Float32List points in marked) {
          for (int i = 0; i < points.length; i += 2) {
            final Offset at = Offset(points[i], points[i + 1]);
            expect(form.cut.contains(at), isTrue, reason: '$at');
            expect(form.mediastinum.contains(at), isFalse, reason: '$at');
          }
        }
      }
    }
  });

  testWidgets('at the hand-over the testis is the body’s own outline, flat '
      'in the mark, with no layer, mesh or point; at its stop the testis, '
      'with no layer', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final double real = _anatomy.metres / _part.extent;
    final Rect body = Contour(<Offset>[
      for (final Offset p in _part.followed)
        (p - _part.centre) * (real / _view),
    ]).toPath().getBounds();
    for (final CellShape cell in _cells) {
      final OrganArt art = _organ(cell);
      expect(art.followsBody, isTrue);
      expect(art.real, closeTo(real, 1e-12));
      final _Record handed = _Record();
      art.paint(handed, inks, 1 / 390, 1 / real, detail: 0);
      expect(handed.layers, 0, reason: cell.name);
      expect(handed.meshes, 0, reason: cell.name);
      expect(handed.points, isEmpty, reason: cell.name);
      expect(
        <Rect>[for (final (Rect bounds, Color _) in handed.paths) bounds],
        contains(body),
        reason: cell.name,
      );
      final _Record rest = _Record();
      art.paint(rest, inks, 1 / 390, 1);
      expect(rest.layers, 0, reason: cell.name);
      expect(rest.meshes, greaterThan(0), reason: cell.name);
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final List<(String, Float32List, Int32List)> a = TestisArt(
      _form(),
      inks,
      home: TestisHome.tubules,
    ).meshData;
    final List<(String, Float32List, Int32List)> b = TestisArt(
      _form(),
      inks,
      home: TestisHome.tubules,
    ).meshData;
    expect(a.length, b.length);
    for (int i = 0; i < a.length; i++) {
      expect(a[i].$1, b[i].$1);
      expect(a[i].$2, b[i].$2);
      expect(a[i].$3, b[i].$3);
      expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
    }
  });

  test('it names where the zoom’s cell lives, at the place its tissue is '
      'sampled, and the epididymis, the rete testis and the vas deferens; '
      'no more', () {
    for (final CellShape cell in _cells) {
      final OrganArt art = _organ(cell);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          if (cell == CellShape.endocrine)
            'interstitium'
          else
            'seminiferous tubules',
          'epididymis',
          'rete testis',
          'vas deferens',
        ],
      );
      expect(art.names.first.home, isTrue);
      expect(art.names.first.at, art.site);
      expect(art.names.skip(1).every((OrganName n) => !n.home), isTrue);
      expect(art.outline.contains(art.site), isTrue);
      expect(art.named, isNotEmpty);
    }
  });

  testWidgets('on the steps to the testis and back nothing pops or jumps: '
      'its outline drawn in, the testis coming up, the figure going', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.ubiquitin,
      TestCatalog.bySlug('gapdhs')!,
    ]) {
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ZoomSubject subject = stage.subject;
      expect(subject.anatomy!.organ, OrganKind.testis, reason: t.slug);
      final TestisForm form = TestisForm.place(
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
        final int frames = (flight.duration.inMicroseconds / 1e6 * 60).ceil();
        (double, double)? lastShown;
        List<Offset>? before;
        List<Offset>? last;
        for (int f = 0; f <= frames; f++) {
          final double d = flight.at(
            Duration(microseconds: (f * 1e6 / 60).round()),
          );
          OrganScene? scene;
          ZoomFrame? frame;
          for (final (ZoomScene s, ZoomFrame fr) in stage.frames(
            d,
            _canvas,
            inks,
          )) {
            if (s is OrganScene) {
              scene = s;
              frame = fr;
            }
          }
          if (scene == null || frame == null) {
            lastShown = null;
            before = null;
            last = null;
            continue;
          }
          final double detail = OrganScene.detailAt(frame);
          final (double, double) shown = (
            frame.opacity * SpecimenStep.come(detail),
            frame.opacity * SpecimenStep.figure(detail),
          );
          final String where =
              '${t.slug} from ${flight.from} to ${flight.to}, frame $f';
          if (lastShown != null) {
            expect(
              (shown.$1 - lastShown.$1).abs(),
              lessThanOrEqualTo(0.08),
              reason: '$where: the testis',
            );
            expect(
              (shown.$2 - lastShown.$2).abs(),
              lessThanOrEqualTo(0.08),
              reason: '$where: the figure',
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
