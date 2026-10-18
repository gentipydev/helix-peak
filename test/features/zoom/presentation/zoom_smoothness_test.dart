import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/zoom/domain/cell_parts.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/band_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/dna_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/gene_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
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

/// A flight from [from] to [to] as the screen flies it: the step into the
/// DNA takes its time.
ZoomFlight _flight(ZoomDepth depth, double from, double to) => ZoomFlight(
  from,
  to,
  minimum: depth.leastFlight(from, to),
  cruise: depth.cruiseOf(from, to),
);

/// The depth on the step from the gene to the DNA at which the view is
/// [width] base pairs across.
double _depthWhere(ZoomDepth depth, double width) {
  double high = depth.depthOf(ZoomStop.gene);
  double low = depth.depthOf(ZoomStop.dna);
  for (int i = 0; i < 80; i++) {
    final double mid = (high + low) / 2;
    if (depth.widthAt(mid) > width) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return (high + low) / 2;
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
    final ZoomStaging staging = stage.stage(d, _canvas, inks);
    final Map<String, (Offset, double)> now = staging.items;
    // What a name set in a row names lies along the gene, away from where
    // the view closes in: it flies with the view as the gene under it does,
    // and the step into the DNA spends its depth unevenly, its empty
    // decades in a rush, so only its coming and going is held here.
    final Set<String> spread = <String>{
      for (final ZoomCallout c in staging.callouts)
        if (c.row != null) 'callout:${c.key}',
    };
    // What a name set round a shape names is a point of the shape, and it
    // may lie well away from where the view closes in, however near the
    // canvas's middle (a brain's thalamus, as the view closes in on its
    // cortex): it flies outward with the shape as the view narrows, so it
    // is held to the check for a break, as anything away from the focus is.
    final Set<String> round = <String>{
      for (final ZoomCallout c in staging.callouts)
        if (c.ring != null) 'callout:${c.key}',
    };
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
          if (spread.contains(key)) {
            continue;
          }
          final Offset second = p2.$1 - p1.$1 * 2 + p0.$1;
          final Offset centre = _canvas.center(Offset.zero);
          final bool focus =
              !round.contains(key) && (p1.$1 - centre).distance < 160;
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
          frames(_flight(depth, a, b)),
          what: '${t.slug} stepping in from ${ZoomStop.values[k].name}',
        );
        _expectSmooth(
          stage,
          inks,
          frames(_flight(depth, b, a)),
          what: '${t.slug} stepping out to ${ZoomStop.values[k].name}',
        );
      }
    }
  });

  test('the scale bar reads a round length at every stop, and glides from '
      'one to the next without springing back', () {
    for (final Size size in <Size>[_canvas, const Size(320, 420)]) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomDepth depth = _stage(t).depth;
        for (final ZoomStop stop in ZoomStop.values) {
          final (double _, double round, String label) = scaleBar(
            depth.widthOf(stop),
            size.width,
            unit: ZoomDepth.unitOf(stop),
            share: ZoomDepth.barShareOf(stop),
          );
          final (double pixels, String reads) = scaleBarAt(
            depth,
            depth.depthOf(stop),
            size,
          );
          final String where = '${t.slug} at ${stop.name}, ${size.width}';
          expect(pixels, closeTo(round, 1e-6), reason: where);
          expect(reads, label, reason: where);
        }
        // Every step either way at 60 fps: the bar never changes its length
        // by as much as two pixels from one frame to the next.
        for (int k = 0; k + 1 < ZoomStop.values.length; k++) {
          final double a = depth.depthOf(ZoomStop.values[k]);
          final double b = depth.depthOf(ZoomStop.values[k + 1]);
          for (final ZoomFlight flight in <ZoomFlight>[
            _flight(depth, a, b),
            _flight(depth, b, a),
          ]) {
            final int frames = (flight.duration.inMicroseconds / 1e6 * 60)
                .ceil();
            double? last;
            for (int f = 0; f <= frames; f++) {
              final (double pixels, String _) = scaleBarAt(
                depth,
                flight.at(Duration(microseconds: (f * 1e6 / 60).round())),
                size,
              );
              if (last != null) {
                expect(
                  (pixels - last).abs(),
                  lessThan(2),
                  reason:
                      '${t.slug} from ${ZoomStop.values[k].name}, frame $f, '
                      '${size.width}',
                );
              }
              last = pixels;
            }
          }
        }
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
      ZoomStop.gene,
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

  testWidgets('the gene opens out of its mark on the band’s strip, its 5′ '
      'end at the mark’s left whatever its strand', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final double band = depth.depthOf(ZoomStop.band);
      final double step = depth.travelOf(ZoomStop.band.index);
      int seen = 0;
      // Wherever the band still shows, giving way to the gene.
      for (int i = 1; i < 40; i++) {
        final double s = i / 40;
        final List<(ZoomScene, ZoomFrame)> frames = stage.frames(
          band + s * step,
          _canvas,
          inks,
        );
        final Iterable<(ZoomScene, ZoomFrame)> map = frames.where(
          ((ZoomScene, ZoomFrame) f) => f.$1 is BandScene,
        );
        final Iterable<(ZoomScene, ZoomFrame)> gene = frames.where(
          ((ZoomScene, ZoomFrame) f) => f.$1 is GeneScene,
        );
        if (map.isEmpty || gene.isEmpty) {
          continue;
        }
        seen++;
        final (ZoomScene strip, ZoomFrame onMap) = map.single;
        final (ZoomScene drawn, ZoomFrame inGene) = gene.single;
        double onBand(double position) =>
            (strip as BandScene).stripX(onMap, position);
        double inGeneAt(double offset) =>
            (drawn as GeneScene).screenX(inGene, offset);
        final String what = '${t.slug} at $s';
        // The gene's 5′ end at the mark's left, its 3′ end at its right.
        expect(
          inGeneAt(0),
          closeTo(onBand(stage.subject.track.spanStart.toDouble()), 0.5),
          reason: what,
        );
        expect(
          inGeneAt(stage.subject.layout.length),
          closeTo(onBand(stage.subject.track.spanEnd + 1.0), 0.5),
          reason: what,
        );
      }
      expect(seen, greaterThan(8), reason: t.slug);
    }
  });

  testWidgets('the gene’s exons show whole at its stop, sink into its DNA on '
      'the way in, and are gone before the helix’s bases come up', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      (DnaScene, ZoomFrame)? dna(double d) {
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          d,
          _canvas,
          inks,
        )) {
          if (scene is DnaScene) {
            return (scene, frame);
          }
        }
        return null;
      }

      final double gene = depth.depthOf(ZoomStop.gene);
      final double end = depth.depthOf(ZoomStop.dna);
      // From the gene's stop on, the DNA's scene draws the gene's DNA, its
      // exons whole there.
      final (DnaScene atStop, ZoomFrame stopFrame) = dna(gene)!;
      expect(atStop.exonsShown(stopFrame), 1, reason: t.slug);
      expect(stopFrame.opacity, 1, reason: t.slug);
      // Where the view is as narrow as the exons last to: gone.
      final (DnaScene gone, ZoomFrame goneFrame) = dna(
        _depthWhere(depth, DnaScene.exonsGone) + 1e-9,
      )!;
      expect(gone.exonsShown(goneFrame), lessThan(1e-6), reason: t.slug);
      // Never the exons' colours and the bases at once.
      for (int i = 0; i <= 400; i++) {
        final (DnaScene scene, ZoomFrame frame) = dna(
          gene + (end - gene) * i / 400,
        )!;
        final (double _, double bases) = scene.helixShown(frame);
        expect(
          scene.exonsShown(frame) * bases,
          lessThan(1e-9),
          reason: '${t.slug} at $i',
        );
      }
    }
  });

  testWidgets('the DNA starts where the gene does: across the step from the '
      'gene, their 5′ ends are one', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final double at = depth.depthOf(ZoomStop.gene);
      final double step = depth.travelOf(ZoomStop.gene.index);
      int seen = 0;
      for (int i = 1; i <= 30; i++) {
        final double s = i / 40;
        final List<(ZoomScene, ZoomFrame)> frames = stage.frames(
          at + s * step,
          _canvas,
          inks,
        );
        final Iterable<(ZoomScene, ZoomFrame)> gene = frames.where(
          ((ZoomScene, ZoomFrame) f) => f.$1 is GeneScene,
        );
        final Iterable<(ZoomScene, ZoomFrame)> dna = frames.where(
          ((ZoomScene, ZoomFrame) f) => f.$1 is DnaScene,
        );
        if (gene.isEmpty || dna.isEmpty) {
          continue;
        }
        seen++;
        final (ZoomScene g, ZoomFrame inGene) = gene.single;
        final (ZoomScene n, ZoomFrame inDna) = dna.single;
        expect(
          inDna.toScreen(Offset((n as DnaScene).unitAlong(0), 0)).dx,
          closeTo((g as GeneScene).screenX(inGene, 0), 0.5),
          reason: '${t.slug} at $s',
        );
      }
      expect(seen, greaterThan(8), reason: t.slug);
    }
  });

  testWidgets('nothing the gene or its DNA draws changes by more than 0.08 a '
      'frame at 60 fps, on any step to the gene or from it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      // Each part's showing, the scene's own times the part's.
      Map<String, double> shown(double d) {
        final Map<String, double> out = <String, double>{};
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          d,
          _canvas,
          inks,
        )) {
          if (scene is GeneScene) {
            out['gene'] = frame.opacity;
            // On the step from the band the gene's scene draws its exons,
            // whole; from its stop on the DNA's scene draws the same.
            if (frame.isChild) {
              out['the exons'] = frame.opacity;
            }
            out['annotations'] =
                frame.opacity * scene.annotationsShown(frame);
          }
          if (scene is DnaScene) {
            final (double helix, double bases) = scene.helixShown(frame);
            out['the exons'] = frame.opacity * scene.exonsShown(frame);
            out['the packing'] = frame.opacity * scene.packedShown(frame);
            out['the helix'] = frame.opacity * helix;
            out['its bases'] = frame.opacity * bases;
          }
        }
        return out;
      }

      final double band = depth.depthOf(ZoomStop.band);
      final double gene = depth.depthOf(ZoomStop.gene);
      final double dna = depth.depthOf(ZoomStop.dna);
      for (final ZoomFlight flight in <ZoomFlight>[
        _flight(depth, band, gene),
        _flight(depth, gene, band),
        _flight(depth, gene, dna),
        _flight(depth, dna, gene),
      ]) {
        final int frames = (flight.duration.inMicroseconds / 1e6 * 60).ceil();
        Map<String, double>? last;
        for (int f = 0; f <= frames; f++) {
          final Map<String, double> now = shown(
            flight.at(Duration(microseconds: (f * 1e6 / 60).round())),
          );
          if (last != null) {
            for (final String part in <String>{...now.keys, ...last.keys}) {
              expect(
                ((now[part] ?? 0) - (last[part] ?? 0)).abs(),
                lessThanOrEqualTo(0.08),
                reason:
                    '${t.slug} from ${flight.from} to ${flight.to}, frame '
                    '$f: $part',
              );
            }
          }
          last = now;
        }
      }
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
          // The names set in a row or round a shape first, as the painter
          // sets them.
          final Map<String, Rect> rows = <String, Rect>{
            ...rowPlates(staging.callouts, labels, inks, size),
            for (final MapEntry<String, RingPlate> ring in stage
                .ringsAt(stage.depth.depthOf(stop), size, inks, labels)
                .entries)
              ring.key: ring.value.plate,
          };
          final List<Rect> placed = <Rect>[];
          for (final ZoomCallout callout in <ZoomCallout>[
            ...staging.callouts.where(
              (ZoomCallout c) => rows.containsKey(c.key),
            ),
            ...staging.callouts.where(
              (ZoomCallout c) => !rows.containsKey(c.key),
            ),
          ]) {
            final TextPainter text = calloutText(callout, labels, inks, size);
            final Rect plate =
                rows[callout.key] ??
                placePlate(
                  callout.target,
                  text.size,
                  size,
                  placed,
                  anchors: callout.anchors,
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
          // the Atlas says nothing of where its protein sits. An organ
          // names where in it the zoom's cell lives, where it draws that.
          final List<OrganName> organ = (stage.scenes[1] as OrganScene).names;
          final bool named = switch (stop) {
            ZoomStop.body || ZoomStop.nucleus => false,
            ZoomStop.organ => organ.any((OrganName n) => n.home),
            ZoomStop.cell => locusOf(t).subcellular.main.isNotEmpty,
            _ => true,
          };
          expect(
            staging.callouts.where(
              (ZoomCallout c) => c.opacity > 0.5 && !c.quiet,
            ),
            named ? isNotEmpty : isEmpty,
            reason: '${t.slug} at ${stop.name}',
          );
          // A landmark is named where it is seen: an organ drawn among its
          // neighbours names them, a cell drawn part by part the parts that
          // tell it apart, and the gene its own; the nucleolus is named
          // nowhere (the user's choice of 2026-10-18).
          final bool landmarks = switch (stop) {
            ZoomStop.organ => organ.any((OrganName n) => !n.home),
            ZoomStop.cell => partsToName(
              recipeOf(stage.depth.archetype.shape),
              locusOf(t).subcellular.main,
            ).isNotEmpty,
            ZoomStop.gene => true,
            _ => false,
          };
          expect(
            staging.callouts.where(
              (ZoomCallout c) => c.opacity > 0.5 && c.quiet,
            ),
            landmarks ? isNotEmpty : isEmpty,
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
