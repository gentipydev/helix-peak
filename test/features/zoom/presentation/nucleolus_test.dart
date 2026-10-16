import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/cell_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/nucleolus.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/nucleus_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/nucleus_shape.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card, and
/// on a narrow one.
const List<Size> _canvases = <Size>[Size(390, 560), Size(320, 420)];

ZoomStage _stage(ProteinTarget t, [LocusTrack? track]) =>
    ZoomStage(ZoomSubject(track: track ?? locusOf(t), record: recordOf(t)));

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

/// The frame [scene] is drawn with at depth [d], if it shows.
ZoomFrame? _frameOf(
  ZoomStage stage,
  ZoomScene scene,
  double d,
  Size size,
  ZoomInks inks,
) {
  for (final (ZoomScene s, ZoomFrame frame) in stage.frames(d, size, inks)) {
    if (identical(s, scene)) {
      return frame;
    }
  }
  return null;
}

/// [contour] on screen, as [frame] draws it.
Path _onScreen(Contour contour, ZoomFrame frame) =>
    Contour(<Offset>[for (final Offset p in contour.points) frame.toScreen(p)])
        .toPath();

/// A canvas that keeps the lines drawn on it.
class _Lines implements Canvas {
  final List<(Offset, Offset, Color)> lines = <(Offset, Offset, Color)>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      lines.add((p1, p2, paint.color));

  // Everything else it draws is not a line.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A canvas that counts the round shapes drawn on it.
class _Rounds implements Canvas {
  int rounds = 0;
  int paths = 0;

  @override
  void drawOval(Rect rect, Paint paint) => rounds++;

  @override
  void drawCircle(Offset c, double radius, Paint paint) => rounds++;

  @override
  void drawPath(Path path, Paint paint) => paths++;

  // Nothing else is drawn by a nucleolus.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// [scene] drawn at [frame] on its own, as pixels of a canvas of [size].
Future<Uint8List> _pixels(
  WidgetTester tester,
  ZoomScene scene,
  ZoomFrame frame,
  Size size,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  scene.paint(Canvas(recorder), frame);
  final ui.Picture picture = recorder.endRecording();
  final Uint8List? bytes = await tester.runAsync(() async {
    final ui.Image image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final ByteData data = (await image.toByteData())!;
    image.dispose();
    return data.buffer.asUint8List();
  });
  picture.dispose();
  return bytes!;
}

void main() {
  testWidgets('the nucleolus is named at the cell, and nowhere else, for all '
      'twenty; the nucleus names nothing', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final Size size in _canvases) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        for (final ZoomStop stop in ZoomStop.values) {
          final List<ZoomCallout> callouts = stage
              .stage(stage.depth.depthOf(stop), size, inks)
              .callouts;
          final List<ZoomCallout> named = <ZoomCallout>[
            for (final ZoomCallout c in callouts)
              if (c.text == 'nucleolus') c,
          ];
          if (stop == ZoomStop.nucleus) {
            expect(callouts, isEmpty, reason: '${t.slug} at the nucleus');
          }
          final bool seen = stop == ZoomStop.cell;
          expect(
            named,
            hasLength(seen ? 1 : 0),
            reason: '${t.slug} at ${stop.name}',
          );
          if (seen) {
            expect(named.single.quiet, isTrue, reason: t.slug);
            expect(named.single.opacity, closeTo(1, 1e-9), reason: t.slug);
          }
        }
      }
    }
  });

  testWidgets('its name at the cell lands on it and is set off the nucleus, '
      'hiding none of it, at two widths', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in _canvases) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final CellScene cell = stage.scenes[ZoomStop.cell.index] as CellScene;
        for (final (
              ZoomStop stop,
              ZoomScene scene,
              Nucleolus nucleolus,
              Contour outline,
            )
            in <(ZoomStop, ZoomScene, Nucleolus, Contour)>[
              (
                ZoomStop.cell,
                cell,
                cell.nucleolus,
                cell.nucleusShape.outline(cell.nucleus),
              ),
            ]) {
          final double d = stage.depth.depthOf(stop);
          final ZoomFrame frame = _frameOf(stage, scene, d, size, inks)!;
          final List<Rect> placed = <Rect>[];
          for (final ZoomCallout c in stage.stage(d, size, inks).callouts) {
            final TextPainter text = calloutText(c, labels, inks, size);
            final Rect plate = placePlate(
              c.target,
              text.size,
              size,
              placed,
              anchors: c.anchors,
            );
            text.dispose();
            placed.add(plate);
            if (c.text != 'nucleolus') {
              continue;
            }
            final String where = '${t.slug} at ${stop.name}, ${size.width}';
            expect(
              _onScreen(nucleolus.outline, frame).contains(c.target),
              isTrue,
              reason: where,
            );
            final Path round = _onScreen(outline, frame);
            for (final Offset corner in <Offset>[
              plate.topLeft,
              plate.topRight,
              plate.bottomLeft,
              plate.bottomRight,
              plate.center,
            ]) {
              expect(round.contains(corner), isFalse, reason: where);
            }
          }
        }
      }
    }
  });

  testWidgets('its name keeps its place by it as the view moves, from the '
      'tissue to the chromosome, at two widths', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in _canvases) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final double from = stage.depth.depthOf(ZoomStop.tissue);
        final double to = stage.depth.depthOf(ZoomStop.chromosome);
        Map<String, Offset> before = <String, Offset>{};
        for (int i = 0; i <= 1500; i++) {
          final double d = from + (to - from) * i / 1500;
          final Map<String, Offset> now = <String, Offset>{};
          final List<Rect> placed = <Rect>[];
          for (final ZoomCallout c in stage.stage(d, size, inks).callouts) {
            final TextPainter text = calloutText(c, labels, inks, size);
            final Rect plate = calloutPlate(
              stage,
              d,
              c,
              text.size,
              size,
              placed,
              inks,
              labels,
            );
            text.dispose();
            placed.add(plate);
            // Where the plate is from what it names: a jump in it is the
            // plate leaping to another place while it shows.
            now[c.key] = plate.center - c.target;
            final Offset? last = before[c.key];
            if (last != null && c.opacity > 0.02) {
              expect(
                (now[c.key]! - last).distance,
                lessThan(6),
                reason: '${t.slug}, ${c.text} at ${i / 15}%, ${size.width}',
              );
            }
          }
          before = now;
        }
      }
    }
  });

  testWidgets('the cell and the nucleus draw one nucleolus, in one place, '
      'across the step between them', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final CellScene cell = stage.scenes[ZoomStop.cell.index] as CellScene;
      final NucleusScene nucleus =
          stage.scenes[ZoomStop.nucleus.index] as NucleusScene;
      final double from = stage.depth.depthOf(ZoomStop.cell);
      final double to = stage.depth.depthOf(ZoomStop.nucleus);
      int both = 0;
      for (int i = 1; i < 40; i++) {
        final double d = from + (to - from) * i / 40;
        final ZoomFrame? outer = _frameOf(stage, cell, d, size, inks);
        final ZoomFrame? inner = _frameOf(stage, nucleus, d, size, inks);
        if (outer == null || inner == null) {
          continue;
        }
        both++;
        final List<Offset> a = cell.nucleolus.outline.points;
        final List<Offset> b = nucleus.nucleolus.outline.points;
        expect(a, hasLength(b.length));
        double worst = 0;
        for (int k = 0; k < a.length; k++) {
          worst = math.max(
            worst,
            (outer.toScreen(a[k]) - inner.toScreen(b[k])).distance,
          );
        }
        expect(worst, lessThan(0.5), reason: '${t.slug} at $i/40');
      }
      expect(both, greaterThan(5), reason: t.slug);
    }
  });

  testWidgets('its line is in the quiet ink: the mark is the gene\'s', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    const TextStyle labels = TextStyle(fontSize: 12);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      for (final ZoomStop stop in <ZoomStop>[ZoomStop.cell]) {
        final double d = stage.depth.depthOf(stop);
        final ZoomCallout named = stage
            .stage(d, size, inks)
            .callouts
            .singleWhere((ZoomCallout c) => c.text == 'nucleolus');
        final _Lines canvas = _Lines();
        ZoomOverlayPainter(
          stage: stage,
          at: () => d,
          inks: inks,
          labels: labels,
          caption: labels,
          credit: '',
        ).paint(canvas, size);
        final Color line = canvas.lines
            .singleWhere(((Offset, Offset, Color) l) => l.$2 == named.target)
            .$3;
        expect(
          line.toARGB32(),
          inks.label.toARGB32(),
          reason: '${t.slug} at ${stop.name}',
        );
      }
    }
  });

  testWidgets('where the Atlas puts the protein in the nucleolus, the '
      'protein\'s own name says so, and the nucleolus is not named twice', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    final ProteinTarget t = TestCatalog.insulin;
    final Map<String, dynamic> json =
        jsonDecode(jsonEncode(locusJson(t))) as Map<String, dynamic>;
    final Map<String, dynamic> expression =
        json['expression'] as Map<String, dynamic>;
    expression['subcellular'] = <String, dynamic>{
      'main': <String>['Nucleoli'],
      'additional': <String>[],
    };
    final ZoomStage stage = _stage(t, LocusTrack.fromJson(json, t));
    final CellScene cell = stage.scenes[ZoomStop.cell.index] as CellScene;
    final double d = stage.depth.depthOf(ZoomStop.cell);
    final List<ZoomCallout> callouts = stage.stage(d, size, inks).callouts;
    expect(
      <String>[for (final ZoomCallout c in callouts) c.text],
      <String>['nucleoli'],
    );
    expect(callouts.single.quiet, isFalse);
    final ZoomFrame frame = _frameOf(stage, cell, d, size, inks)!;
    expect(
      (callouts.single.target - frame.toScreen(cell.nucleolus.centre)).distance,
      lessThan(1e-6),
    );
    // The nucleus, where the Atlas reading is not drawn, names nothing.
    expect(
      stage.stage(stage.depth.depthOf(ZoomStop.nucleus), size, inks).callouts,
      isEmpty,
    );
  });

  testWidgets('it is one plain body, with no spots in it however near it is '
      'seen', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final CellShape shape in CellShape.values) {
      for (final double radius in <double>[40, 400, 4000]) {
        final _Rounds canvas = _Rounds();
        Nucleolus(NucleusShape(shape), radius).paint(canvas, inks, 1);
        expect(canvas.rounds, 0, reason: '${shape.name} at $radius');
        expect(canvas.paths, greaterThan(0), reason: shape.name);
      }
    }
  });

  testWidgets('at the nucleus it is darker than everything round it, for all '
      'twenty, and near black, no lighter than the app\'s raised surface, '
      'where the glow of the gene\'s territory does not reach it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    int nearBlack = 0;
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final NucleusScene nucleus =
          stage.scenes[ZoomStop.nucleus.index] as NucleusScene;
      final double d = stage.depth.depthOf(ZoomStop.nucleus);
      final ZoomFrame frame = _frameOf(stage, nucleus, d, size, inks)!;
      final Uint8List pixels = await _pixels(tester, nucleus, frame, size);
      double light(Offset p) {
        final int i = (p.dy.round() * size.width.toInt() + p.dx.round()) * 4;
        return 0.2126 * pixels[i] + 0.7152 * pixels[i + 1] +
            0.0722 * pixels[i + 2];
      }

      // Where the gene's chromosome is an acrocentric, its territory, in
      // the mark, lies over the nucleolus's edge, its glowing edge a few
      // pixels past it: only what shows of the nucleolus is read, and only
      // what lies in the nucleus round it.
      final Contour territory = nucleus.territoryShape(
        locusOf(t).chromosome,
        0,
      );
      final Path inTerritory = territory.toPath();
      final List<Offset> edge = <Offset>[
        for (final Offset p in territory.resampled(160).points)
          frame.toScreen(p),
      ];
      bool covered(Offset q) =>
          inTerritory.contains(q) ||
          edge.any((Offset e) => (e - frame.toScreen(q)).distance < 8);
      final Path held = Contour(<Offset>[
        for (final Offset p
            in nucleus.shape.outline(nucleus.radius).resampled(96).points)
          p * 0.94,
      ]).toPath();
      final Nucleolus body = nucleus.nucleolus;
      final List<Offset> rim = body.outline.resampled(24).points;
      final List<double> inside = <double>[
        for (final Offset q in <Offset>[
          body.centre,
          for (final Offset r in rim) Offset.lerp(body.centre, r, 0.6)!,
        ])
          if (!covered(q)) light(frame.toScreen(q)),
      ];
      final List<double> round = <double>[
        for (final Offset r in rim)
          if (held.contains(body.centre + (r - body.centre) * 1.5))
            light(frame.toScreen(body.centre + (r - body.centre) * 1.5)),
      ];
      expect(inside, hasLength(greaterThan(8)), reason: t.slug);
      expect(round, hasLength(greaterThan(8)), reason: t.slug);
      // The glow round the gene's territory, in the mark, washes over what
      // it reaches: an acrocentric's, lying against the nucleolus, or a
      // territory's in a flat nucleus.
      final Rect box = inTerritory.getBounds();
      final List<double> unlit = <double>[
        for (final Offset q in <Offset>[
          body.centre,
          for (final Offset r in rim) Offset.lerp(body.centre, r, 0.6)!,
        ])
          if ((q - box.center).distance > box.longestSide)
            light(frame.toScreen(q)),
      ];
      if (unlit.isNotEmpty) {
        nearBlack++;
        final Color raised = inks.raised;
        expect(
          unlit.reduce(math.max),
          lessThanOrEqualTo(
            255 * (0.2126 * raised.r + 0.7152 * raised.g + 0.0722 * raised.b) +
                2,
          ),
          reason: t.slug,
        );
      }
      expect(
        inside.reduce(math.max),
        lessThan(round.reduce(math.min)),
        reason: t.slug,
      );
    }
    expect(nearBlack, greaterThanOrEqualTo(12));
  });

  test('the nucleoplasm a protein glows in is the nucleus less its '
      'nucleolus', () {
    final ZoomStage stage = _stage(TestCatalog.p53);
    final CellScene cell = stage.scenes[ZoomStop.cell.index] as CellScene;
    final Path nucleus = cell.nucleusShape.outline(cell.nucleus).toPath();
    for (final Offset p in <Offset>[
      cell.nucleolus.centre,
      ...cell.nucleolus.outline
          .resampled(12)
          .points
          .map((Offset q) => Offset.lerp(cell.nucleolus.centre, q, 0.9)!),
    ]) {
      expect(nucleus.contains(p), isTrue);
      expect(cell.nucleoplasm.contains(p), isFalse);
    }
    expect(cell.nucleoplasm.contains(cell.nucleolus.centre * -0.9), isTrue);
  });
}
