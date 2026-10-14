import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/band_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/dna_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card.
const Size _canvas = Size(390, 560);

ZoomStage _stage(ProteinTarget t) =>
    ZoomStage(ZoomSubject(track: locusOf(t), record: recordOf(t)));

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

/// A canvas that keeps only where words are set, on screen.
class _Words implements Canvas {
  final List<Rect> boxes = <Rect>[];
  final List<Matrix4> _saved = <Matrix4>[];
  Matrix4 _now = Matrix4.identity();

  @override
  void save() => _saved.add(_now.clone());

  @override
  void saveLayer(Rect? bounds, Paint paint) => save();

  @override
  void restore() => _now = _saved.removeLast();

  @override
  void translate(double dx, double dy) => _now.translateByDouble(dx, dy, 0, 1);

  @override
  void scale(double sx, [double? sy]) => _now.scaleByDouble(sx, sy ?? sx, 1, 1);

  @override
  void rotate(double radians) => _now.rotateZ(radians);

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => boxes.add(
    MatrixUtils.transformRect(
      _now,
      offset & Size(paragraph.maxIntrinsicWidth, paragraph.height),
    ),
  );

  // Everything else it draws is not words.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A canvas that keeps only the dots and lines drawn on it: each one's size
/// (a dot's radius, a line's width) and colour.
class _Marks implements Canvas {
  final List<(double, Color)> drawn = <(double, Color)>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      drawn.add((radius, paint.color));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      drawn.add((paint.strokeWidth, paint.color));

  // Everything else it draws is neither.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

bool _onCanvas(Offset p) =>
    p.dx > -_canvas.width &&
    p.dx < 2 * _canvas.width &&
    p.dy > -_canvas.height &&
    p.dy < 2 * _canvas.height;

/// Walks [depths] in order, staging each without drawing, and fails on a
/// pop (something appearing or vanishing at more than [pop] opacity), a
/// blink (opacity changing by more than [pop] in one step) or a jump (a
/// position's second difference past [jerk] pixels) of anything on or near
/// the canvas.
void _expectSmooth(
  ZoomStage stage,
  ZoomInks inks,
  List<double> depths, {
  double pop = 0.08,
  double jerk = 1.5,
  required String what,
}) {
  Map<String, (Offset, double)>? before;
  Map<String, (Offset, double)>? last;
  for (final double d in depths) {
    final Map<String, (Offset, double)> now = stage
        .stage(d, _canvas, inks)
        .items;
    if (last != null) {
      for (final String key in <String>{...now.keys, ...last.keys}) {
        final double a = last[key]?.$2 ?? 0;
        final double b = now[key]?.$2 ?? 0;
        expect(
          (b - a).abs(),
          lessThanOrEqualTo(pop),
          reason: '$what: $key blinks or pops at depth $d ($a → $b)',
        );
      }
      if (before != null) {
        for (final String key in now.keys) {
          final (Offset, double)? p0 = before[key];
          final (Offset, double)? p1 = last[key];
          final (Offset, double) p2 = now[key]!;
          if (p0 == null || p1 == null) {
            continue;
          }
          if (p2.$2 < 0.02 || !_onCanvas(p0.$1) || !_onCanvas(p2.$1)) {
            continue;
          }
          final Offset second = p2.$1 - p1.$1 * 2 + p0.$1;
          final Offset centre = _canvas.center(Offset.zero);
          final bool focus = (p1.$1 - centre).distance < 160;
          // Near the focus nothing may jolt. Further out, things fly outward
          // as the view narrows, faster the further they are, so there the
          // check is for a break: a step that is not of a piece with the
          // last.
          final double allowed = focus
              ? jerk
              : math.max(jerk, 0.3 * (p2.$1 - p1.$1).distance + 2);
          expect(
            second.distance,
            lessThanOrEqualTo(allowed),
            reason: '$what: $key jumps at depth $d',
          );
        }
      }
    }
    before = last;
    last = now;
  }
}

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(File(path).readAsBytesSync().buffer),
      ),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(
    () => _loadFont(AppTypography.sansFamily, <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
    ]),
  );

  testWidgets('every protein’s dive moves without a pop, a blink or a jump, '
      'at fine steps of depth', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      const int steps = 6000;
      _expectSmooth(stage, inks, <double>[
        for (int i = 0; i <= steps; i++) depth.total * i / steps,
      ], what: t.slug);
    }
  });

  testWidgets('every step, either way, moves without a pop, a blink or a '
      'jump, at 60 fps', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    List<double> frames(ZoomFlight flight) => <double>[
      for (
        int f = 0;
        f <= (flight.duration.inMicroseconds / 1e6 * 60).ceil();
        f++
      )
        flight.at(Duration(microseconds: (f * 1e6 / 60).round())),
    ];
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      for (int k = 0; k + 1 < ZoomStop.values.length; k++) {
        final double a = depth.depthOf(ZoomStop.values[k]);
        final double b = depth.depthOf(ZoomStop.values[k + 1]);
        _expectSmooth(
          stage,
          inks,
          frames(ZoomFlight(a, b)),
          what: '${t.slug} stepping in from ${ZoomStop.values[k].name}',
        );
        _expectSmooth(
          stage,
          inks,
          frames(ZoomFlight(b, a)),
          what: '${t.slug} stepping out to ${ZoomStop.values[k].name}',
        );
      }
    }
  });

  test('a step asked for mid-flight takes over at the speed the depth has', () {
    final ZoomDepth depth = _stage(TestCatalog.hemoglobin).depth;
    final ZoomFlight first = ZoomFlight(
      depth.depthOf(ZoomStop.organ),
      depth.depthOf(ZoomStop.tissue),
    );
    for (final double share in <double>[0.2, 0.5, 0.8]) {
      final Duration at = first.duration * share;
      final double speed = first.speedAt(at);
      for (final ZoomStop to in <ZoomStop>[ZoomStop.cell, ZoomStop.organ]) {
        final ZoomFlight second = ZoomFlight(
          first.at(at),
          depth.depthOf(to),
          velocity: speed,
        );
        expect(second.at(Duration.zero), closeTo(first.at(at), 1e-12));
        // The speed carries over wherever it is not more than the new
        // flight can carry without passing its stop.
        final double span = (depth.depthOf(to) - first.at(at)).abs();
        final double most = 2 * span / (second.duration.inMicroseconds / 1e6);
        expect(
          second.speedAt(Duration.zero),
          closeTo(speed.clamp(-most, most), 1e-9),
          reason: '$share to ${to.name}',
        );
        expect(second.at(second.duration), closeTo(depth.depthOf(to), 1e-12));
        expect(second.speedAt(second.duration).abs(), lessThan(1e-9));
        // It never passes the stop it is bound for. Turned back, it carries
        // on a little the way it was going before it turns, as a hand
        // would.
        final double from = first.at(at);
        final double stop = depth.depthOf(to);
        for (int f = 0; f <= 60; f++) {
          final double d = second.at(second.duration * (f / 60));
          if (stop > from) {
            expect(d, lessThanOrEqualTo(stop + 1e-9));
            expect(d, greaterThanOrEqualTo(from - 1e-9));
          } else {
            expect(d, greaterThanOrEqualTo(stop - 1e-9));
            expect(d, lessThanOrEqualTo(from + 0.35 * span + 1e-9));
          }
        }
      }
    }
  });

  testWidgets('the scenes build what they cache ahead of their first frame, '
      'the nearest a stop first', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ZoomStage stage = _stage(TestCatalog.insulin);
    final List<ZoomStop> order = <ZoomStop>[];
    for (
      ZoomStop? next = stage.unprepared(ZoomStop.cell);
      next != null;
      next = stage.unprepared(ZoomStop.cell)
    ) {
      order.add(next);
      stage.prepare(next, inks);
    }
    // Deeper first of two as near: a step is more often taken in.
    expect(order, <ZoomStop>[
      ZoomStop.cell,
      ZoomStop.nucleus,
      ZoomStop.tissue,
      ZoomStop.chromosome,
      ZoomStop.organ,
      ZoomStop.band,
      ZoomStop.body,
      ZoomStop.dna,
    ]);
    expect(stage.prepared, isTrue);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage each = _stage(t);
      for (final ZoomStop stop in ZoomStop.values) {
        each.prepare(stop, inks);
      }
      expect(each.prepared, isTrue, reason: t.slug);
    }
  });

  testWidgets('the band never sets two of its words over each other, at it '
      'or on the way in or out', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in <Size>[_canvas, const Size(320, 420)]) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final ZoomDepth depth = stage.depth;
        final double band = depth.depthOf(ZoomStop.band);
        final double inward = depth.travelOf(ZoomStop.chromosome.index);
        final double outward = depth.travelOf(ZoomStop.band.index);
        for (final double d in <double>[
          for (int i = 20; i <= 40; i++) band - inward * (40 - i) / 40,
          for (int i = 1; i <= 24; i++) band + outward * i / 40,
        ]) {
          for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
            d,
            size,
            inks,
            labels: labels,
          )) {
            if (scene.stop != ZoomStop.band) {
              continue;
            }
            final _Words words = _Words();
            scene.paint(words, frame);
            final List<Rect> boxes = words.boxes;
            for (int i = 0; i < boxes.length; i++) {
              for (int j = i + 1; j < boxes.length; j++) {
                expect(
                  boxes[i].deflate(0.5).overlaps(boxes[j].deflate(0.5)),
                  isFalse,
                  reason:
                      '${t.slug} at ${size.width} wide, depth $d: '
                      '${boxes[i]} and ${boxes[j]}',
                );
              }
            }
          }
        }
      }
    }
  });

  testWidgets('the gene’s DNA opens out of its bar on the band’s map, its 5′ '
      'end at the bar’s left whatever its strand', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final double band = depth.depthOf(ZoomStop.band);
      final double step = depth.travelOf(ZoomStop.band.index);
      // While the band still shows, giving way to the gene.
      for (final double s in <double>[0.05, 0.15, 0.25, 0.35]) {
        final List<(ZoomScene, ZoomFrame)> frames = stage.frames(
          band + s * step,
          _canvas,
          inks,
        );
        final (ZoomScene map, ZoomFrame onMap) = frames.firstWhere(
          ((ZoomScene, ZoomFrame) f) => f.$1 is BandScene,
        );
        final (ZoomScene dna, ZoomFrame inDna) = frames.firstWhere(
          ((ZoomScene, ZoomFrame) f) => f.$1 is DnaScene,
        );
        double onBand(double position) =>
            onMap.toScreen(Offset((map as BandScene).unitOf(position), 0)).dx;
        double inGene(double offset) =>
            inDna.toScreen(Offset((dna as DnaScene).unitAlong(offset), 0)).dx;
        final double left = onBand(stage.subject.track.spanStart.toDouble());
        final double right = onBand(stage.subject.track.spanEnd + 1.0);
        expect(inGene(0), closeTo(left, 0.5), reason: '${t.slug} at $s');
        // The record's span and MANE's differ by a few dozen base pairs at
        // most.
        expect(
          inGene(stage.subject.layout.length),
          closeTo(right, math.max(1, 0.005 * (right - left))),
          reason: '${t.slug} at $s',
        );
      }
    }
  });

  testWidgets('the gene’s exons show on the way in to the DNA, and none at '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      double shown(double d) {
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          d,
          _canvas,
          inks,
        )) {
          if (scene is DnaScene) {
            return scene.geneShown(frame);
          }
        }
        return 0;
      }

      final double band = depth.depthOf(ZoomStop.band);
      final double step = depth.travelOf(ZoomStop.band.index);
      expect(shown(band + 0.3 * step), 1, reason: t.slug);
      expect(shown(depth.depthOf(ZoomStop.dna)), 0, reason: t.slug);
    }
  });

  testWidgets('the helix at the DNA is whole: nothing reads it, so no '
      'strand peels away from it at any moment of its turn', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    // The mark, or the mark shaded toward the ground as the helix's painter
    // shades a strand by its depth.
    bool isMark(Color c) {
      final Color g = inks.ground;
      final Color m = inks.mark;
      final double kr = (c.r - g.r) / (m.r - g.r);
      final double kg = (c.g - g.g) / (m.g - g.g);
      final double kb = (c.b - g.b) / (m.b - g.b);
      return kg > 0.3 && (kg - kb).abs() < 0.03 && (kg - kr).abs() < 0.1;
    }

    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.dystrophin,
    ]) {
      final ZoomStage stage = _stage(t);
      final double d = stage.depth.depthOf(ZoomStop.dna);
      // Two minutes of its clock, longer than any pass a polymerase made.
      for (int s = 0; s <= 120; s += 3) {
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          d,
          _canvas,
          inks,
          clock: s.toDouble(),
          dwell: s.toDouble(),
        )) {
          final _Marks marks = _Marks();
          scene.paint(marks, frame);
          scene.paintAmbient(marks, frame);
          expect(
            marks.drawn.where(
              ((double, Color) c) => c.$1 > 0.01 && isMark(c.$2),
            ),
            isEmpty,
            reason: '${t.slug}, ${s}s into its turn',
          );
        }
      }
    }
  });

  testWidgets('no two names overlap, and each keeps clear of the edges, at '
      'any stop, at two widths', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in <Size>[_canvas, const Size(320, 420)]) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        for (final ZoomStop stop in ZoomStop.values) {
          final ZoomStaging staging = stage.stage(
            stage.depth.depthOf(stop),
            size,
            inks,
          );
          final List<Rect> placed = <Rect>[];
          for (final ZoomCallout callout in staging.callouts) {
            final TextPainter text = calloutText(callout, labels, inks, size);
            final Rect plate = placePlate(
              callout.target,
              text.size,
              size,
              placed,
            );
            text.dispose();
            for (final Rect other in placed) {
              expect(
                plate.overlaps(other),
                isFalse,
                reason: '${t.slug} at ${stop.name}: ${callout.text} overlaps',
              );
            }
            expect(
              plate.right,
              lessThanOrEqualTo(size.width - ZoomOverlayPainter.margin),
              reason: '${t.slug} at ${stop.name}: ${callout.text} at the edge',
            );
            expect(plate.left, greaterThanOrEqualTo(0));
            expect(plate.top, greaterThanOrEqualTo(0));
            placed.add(plate);
          }
          // A stop names what it follows only where the card does not:
          // the card names the organ and the territory, and the cell where
          // the Atlas says nothing of where its protein sits.
          final bool named = switch (stop) {
            ZoomStop.body || ZoomStop.organ || ZoomStop.nucleus => false,
            ZoomStop.cell => locusOf(t).subcellular.main.isNotEmpty,
            _ => true,
          };
          expect(
            staging.callouts.where((ZoomCallout c) => c.opacity > 0.5),
            named ? isNotEmpty : isEmpty,
            reason: '${t.slug} at ${stop.name}',
          );
        }
      }
    }
  });

  test('the callout plate lands where its line can reach its target', () {
    const Size size = Size(390, 560);
    const Offset target = Offset(200, 300);
    final Rect plate = placePlate(target, const Size(60, 16), size, <Rect>[]);
    expect(plate.left, greaterThan(target.dx));
    expect(plate.bottom, lessThan(target.dy));
    final Rect second = placePlate(target, const Size(60, 16), size, <Rect>[
      plate,
    ]);
    expect(second.overlaps(plate), isFalse);
    expect(
      math.max(second.top - plate.bottom, plate.top - second.bottom),
      greaterThan(-1),
    );
  });
}
