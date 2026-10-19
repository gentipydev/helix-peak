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
import 'package:helixpeek/features/zoom/presentation/scenes/pancreas/pancreas_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/pancreas/pancreas_form.dart';
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

final TissueAnatomy _anatomy = tissueAnatomy['pancreas']!;
final double _view = _anatomy.metres * ZoomDepth.organMargin;

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

PancreasForm _form(AnatomyFigure figure) => PancreasForm.place(
  part: figure.parts[_anatomy.uberon]!,
  anatomy: _anatomy,
  view: _view,
);

OrganArt _art(AnatomyFigure figure, CellShape cell) => OrganArt.forTissue(
  _anatomy,
  figure.parts[_anatomy.uberon],
  _view,
  figure: figure,
  shape: cell,
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

/// A canvas that keeps what is drawn on it: each path's bounds, and how
/// many layers, meshes and points.
class _Record implements Canvas {
  final List<Rect> paths = <Rect>[];
  int layers = 0;
  int meshes = 0;
  int points = 0;

  @override
  void drawPath(Path path, Paint paint) => paths.add(path.getBounds());

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      meshes++;

  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) =>
      this.points++;

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
  testWidgets('at the hand-over the pancreas is the body’s own outline, flat '
      'in the mark, with no layer, mesh or islet; at its stop the gland', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final AnatomyPart part = figure.parts[_anatomy.uberon]!;
      final double real = _anatomy.metres / part.extent;
      final Rect body = Contour(<Offset>[
        for (final Offset p in part.followed)
          (p - part.centre) * (real / _view),
      ]).toPath().getBounds();
      final OrganArt art = _art(figure, CellShape.endocrine);
      final _Record handed = _Record();
      art.paint(handed, inks, 1 / 390, 1 / real, detail: 0);
      expect(handed.layers, 0, reason: figure.name);
      expect(handed.meshes, 0, reason: figure.name);
      expect(handed.points, 0, reason: figure.name);
      expect(handed.paths, contains(body), reason: figure.name);
      final _Record rest = _Record();
      art.paint(rest, inks, 1 / 390, 1);
      expect(rest.layers, 0, reason: figure.name);
      expect(rest.meshes, greaterThan(0), reason: figure.name);
      expect(rest.points, greaterThan(0), reason: figure.name);
    }
  });

  testWidgets('the mark shows only where the zoom’s cell lives: the islets, '
      'the ducts in the window, or the gland itself; never round it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Set<String> neighbours = <String>{
      'spleen',
      'duodenum',
      'vessels',
      'bile',
    };
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final PancreasForm form = _form(figure);
      for (final CellShape cell in <CellShape>[
        CellShape.endocrine,
        CellShape.epithelial,
        CellShape.acinar,
      ]) {
        final String what = '${figure.name}, ${cell.name}';
        final Map<String, (int, int)> teal = <String, (int, int)>{};
        for (final (String part, Float32List positions, Int32List colours)
            in PancreasArt(form, inks, cell: cell).meshData) {
          int leaning = 0;
          int outsideWindow = 0;
          for (int i = 0; i < colours.length; i++) {
            if (_tealness(colours[i]) > 0.01) {
              leaning++;
              final Offset p = Offset(positions[2 * i], positions[2 * i + 1]);
              if (part == 'ducts' &&
                  form.contains(p) &&
                  !form.window.contains(p)) {
                outsideWindow++;
              }
            }
          }
          final (int a, int b) = teal[part] ?? (0, 0);
          teal[part] = (a + leaning, b + outsideWindow);
        }
        for (final String part in neighbours) {
          expect(teal[part]!.$1, 0, reason: '$what: $part');
        }
        switch (cell) {
          case CellShape.endocrine:
            // The islets are points of the mark, drawn over the lobules.
            expect(teal['lobules']!.$1, 0, reason: what);
            expect(teal['uncinate']!.$1, 0, reason: what);
            expect(teal.containsKey('ducts'), isFalse, reason: what);
          case CellShape.epithelial:
            expect(teal['lobules']!.$1, 0, reason: what);
            expect(teal['ducts']!.$1, greaterThan(0), reason: what);
            expect(teal['ducts']!.$2, 0, reason: what);
          default:
            expect(teal['lobules']!.$1, greaterThan(0), reason: what);
            expect(teal.containsKey('ducts'), isFalse, reason: what);
        }
      }
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final PancreasForm form = _form(AnatomyFigure.female);
    final List<(String, Float32List, Int32List)> a = PancreasArt(
      form,
      inks,
      cell: CellShape.epithelial,
    ).meshData;
    final List<(String, Float32List, Int32List)> b = PancreasArt(
      _form(AnatomyFigure.female),
      inks,
      cell: CellShape.epithelial,
    ).meshData;
    expect(a.length, b.length);
    for (int i = 0; i < a.length; i++) {
      expect(a[i].$1, b[i].$1);
      expect(a[i].$2, b[i].$2);
      expect(a[i].$3, b[i].$3);
      expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000));
    }
  });

  testWidgets('on the steps to the pancreas and back nothing pops or jumps: '
      'its outline drawn in, the gland coming up, the figure going', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.cftr,
    ]) {
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ZoomSubject subject = stage.subject;
      final PancreasForm form = PancreasForm.place(
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
              reason: '$where: the gland',
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
