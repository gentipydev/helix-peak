import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/replication/presentation/replication_rings.dart';

/// A ring protein drawn alone, its far half then its near half as the scene
/// draws them round the DNA, and read back pixel by pixel.
///
/// A ring must not flicker: swept through a turn, an opening or its ATP wave
/// in steps that move nothing by more than a twentieth of a pixel, no pixel
/// may change by more than smooth motion can, so nothing pops, blinks or
/// jumps. It must draw nothing outside its own outline, and it must be
/// solid: its walls and faces, seams included, hide what lies behind them.
void main() {
  const double scale = 2;
  const Size frame = Size(90, 70);
  const Offset centre = Offset(45, 35);
  final int width = (frame.width * scale).round();
  final int height = (frame.height * scale).round();

  List<Color> tints(Color base, int count) => <Color>[
    for (int j = 0; j < count; j++)
      Color.lerp(base, j.isEven ? Colors.white : Colors.black, 0.04 * j)!,
  ];

  ProteinRing pcna({double rotation = 0, double open = 0}) => ProteinRing(
    centre: centre,
    radius: 20,
    thickness: 7,
    height: 10,
    angles: ringAngles(count: 6, groups: 3, rotation: rotation, open: open),
    extents: ringExtents(count: 6, groups: 3, open: open),
    colors: tints(const Color(0xFF8C8E6B), 6),
  );

  ProteinRing motor({double open = 0, double atp = 0}) => ProteinRing(
    centre: centre,
    radius: 23,
    thickness: 10,
    height: 12,
    tilt: 0.4,
    round: 10,
    angles: ringAngles(count: 6, open: open),
    extents: ringExtents(count: 6, seam: 0.018, open: open),
    colors: tints(const Color(0xFF6E8796), 6),
    glow: <double>[
      for (int j = 0; j < 6; j++)
        0.9 *
            math
                .pow(
                  math.max(0, math.cos(atp * math.pi * 2 - j * math.pi / 3)),
                  6,
                )
                .toDouble(),
    ],
  );

  ProteinRing rfc({double rotation = math.pi}) => ProteinRing(
    centre: centre,
    radius: 13,
    thickness: 5.5,
    height: 8,
    angles: ringAngles(count: 5, rotation: rotation, open: 1.2),
    extents: ringExtents(count: 5, open: 1.2),
    colors: tints(const Color(0xFF8F8378), 5),
  );

  // ORC's five subunits round an open slot, and Cdc6 alone.
  final List<double> slots = ringAngles(count: 6, rotation: math.pi / 2);
  final List<(double, double)> reach = ringExtents(count: 6);
  final ProteinRing orc = ProteinRing(
    centre: centre,
    radius: 20,
    thickness: 8,
    height: 12,
    angles: slots.sublist(0, 5),
    extents: reach.sublist(0, 5),
    colors: tints(const Color(0xFF9C8090), 5),
  );
  final ProteinRing cdc6 = ProteinRing(
    centre: centre,
    radius: 20,
    thickness: 8,
    height: 12,
    angles: <double>[slots[5]],
    extents: <(double, double)>[reach[5]],
    colors: const <Color>[Color(0xFFB59AA8)],
  );

  Future<ui.Image> picture(ProteinRing ring, double zoom, Rect window) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..scale(zoom)
      ..translate(-window.left, -window.top);
    ring.draw(canvas, near: false);
    ring.draw(canvas, near: true);
    final ui.Picture recorded = recorder.endRecording();
    final Future<ui.Image> image = recorded.toImage(
      (window.width * zoom).round(),
      (window.height * zoom).round(),
    );
    recorded.dispose();
    return image;
  }

  /// Each ring over the whole frame, [scale] pixels to a unit.
  Future<List<Uint8List>> render(
    WidgetTester tester,
    Iterable<ProteinRing> rings,
  ) async {
    final List<Uint8List> frames = <Uint8List>[];
    await tester.runAsync(() async {
      for (final ProteinRing ring in rings) {
        final ui.Image image = await picture(ring, scale, Offset.zero & frame);
        frames.add((await image.toByteData())!.buffer.asUint8List());
        image.dispose();
      }
    });
    return frames;
  }

  /// Each ring over [window], a pixel to a unit, as the average of 8 × 8
  /// samples. A rasterizer's antialiasing comes in quarter steps, so an edge
  /// moving a hair can turn a run of single-sample pixels by a quarter at
  /// once; averaged, only a change in what is drawn shows.
  Future<List<Float64List>> sample(
    WidgetTester tester,
    Iterable<ProteinRing> rings,
    Rect window,
  ) async {
    const int fine = 8;
    final int w = window.width.round();
    final int h = window.height.round();
    final List<Float64List> frames = <Float64List>[];
    await tester.runAsync(() async {
      for (final ProteinRing ring in rings) {
        final ui.Image image = await picture(ring, fine.toDouble(), window);
        final Uint8List bytes = (await image.toByteData())!.buffer
            .asUint8List();
        image.dispose();
        final Float64List mean = Float64List(w * h * 4);
        for (int y = 0; y < h * fine; y++) {
          for (int x = 0; x < w * fine; x++) {
            final int from = (y * w * fine + x) * 4;
            final int to = ((y ~/ fine) * w + x ~/ fine) * 4;
            for (int c = 0; c < 4; c++) {
              mean[to + c] += bytes[from + c] / (fine * fine);
            }
          }
        }
        frames.add(mean);
      }
    });
    return frames;
  }

  /// The largest change of any channel of any pixel between neighbouring
  /// frames, and where in the sweep it happened.
  (double, int) largestStep(List<Float64List> frames) {
    double worst = 0;
    int at = 0;
    for (int k = 1; k < frames.length; k++) {
      final Float64List a = frames[k - 1];
      final Float64List b = frames[k];
      for (int i = 0; i < a.length; i++) {
        final double d = (a[i] - b[i]).abs();
        if (d > worst) {
          worst = d;
          at = k;
        }
      }
    }
    return (worst, at);
  }

  // The sweeps move nothing by more than a fortieth of a pixel a step, and
  // the ends of a closing ring's core by a twentieth: an edge changes a pixel
  // by at most that share of its contrast, 13 of 255. Anything that switches
  // on or off changes it by its whole contrast.
  const double smooth = 13;

  Rect around(double outer, double tall, double tilt) => Rect.fromCenter(
    center: centre,
    width: (outer * 2 + 4).ceilToDouble(),
    height: (outer * 2 * tilt + tall + 4).ceilToDouble(),
  );

  testWidgets('PCNA turns without a pop', (WidgetTester tester) async {
    // Subunits and seams through the side of the ring and the front, in
    // steps of 0.0009 rad: 0.025 pixels at the ring's outer edge.
    final (double worst, int at) = largestStep(
      await sample(tester, <ProteinRing>[
        for (int k = 0; k <= 600; k++) pcna(rotation: 1.2 + k * 0.0009),
      ], around(27.3, 10, 0.42)),
    );
    expect(worst, lessThanOrEqualTo(smooth), reason: 'step $at');
  });

  testWidgets('PCNA closes, and RFC turns, without a pop', (
    WidgetTester tester,
  ) async {
    final (double worst, int at) = largestStep(
      await sample(tester, <ProteinRing>[
        for (int k = 0; k <= 600; k++)
          pcna(rotation: 0.4, open: 1.1 - k / 600 * 1.1),
      ], around(27.3, 10, 0.42)),
    );
    expect(worst, lessThanOrEqualTo(smooth), reason: 'closing, step $at');
    final (double rfcWorst, int rfcAt) = largestStep(
      await sample(tester, <ProteinRing>[
        for (int k = 0; k <= 400; k++) rfc(rotation: 2.6 + k * 0.00135),
      ], around(18.8, 8, 0.42)),
    );
    expect(rfcWorst, lessThanOrEqualTo(smooth), reason: 'RFC, step $rfcAt');
  });

  testWidgets('MCM2–7 closes and fires without a pop', (
    WidgetTester tester,
  ) async {
    final (double worst, int at) = largestStep(
      await sample(tester, <ProteinRing>[
        for (int k = 0; k <= 600; k++) motor(open: 1.1 - k / 600 * 1.1),
      ], around(33.4, 12, 0.4)),
    );
    expect(worst, lessThanOrEqualTo(smooth), reason: 'closing, step $at');
    final (double glowWorst, int glowAt) = largestStep(
      await sample(tester, <ProteinRing>[
        for (int k = 0; k <= 100; k++) motor(atp: k / 100 / 3),
      ], around(33.4, 12, 0.4)),
    );
    expect(glowWorst, lessThanOrEqualTo(smooth), reason: 'ATP, step $glowAt');
  });

  testWidgets('a ring draws nothing outside its own outline', (
    WidgetTester tester,
  ) async {
    final List<(String, ProteinRing, double, double, double, double)> rings =
        <(String, ProteinRing, double, double, double, double)>[
          for (final double rotation in <double>[0, 0.7, 1.9, 3.3])
            (
              'PCNA $rotation',
              pcna(rotation: rotation, open: 0.6),
              20,
              7,
              10,
              0.42,
            ),
          ('MCM2–7', motor(open: 0.5, atp: 0.3), 23, 10, 12, 0.4),
          ('RFC', rfc(), 13, 5.5, 8, 0.42),
          ('ORC', orc, 20, 8, 12, 0.42),
          ('Cdc6', cdc6, 20, 8, 12, 0.42),
        ];
    final List<Uint8List> frames = await render(tester, <ProteinRing>[
      for (final (_, ProteinRing ring, _, _, _, _) in rings) ring,
    ]);
    for (int r = 0; r < rings.length; r++) {
      final (
        String name,
        _,
        double radius,
        double thickness,
        double tall,
        double tilt,
      ) = rings[r];
      // The ring's widest reach (its subunits are up to 4% uneven), and the
      // half of an edge's stroke and a pixel of antialiasing beyond it.
      final double outer = (radius + thickness * 1.04) * scale;
      const double margin = 1.5 * scale;
      final List<String> outside = <String>[];
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (frames[r][(y * width + x) * 4 + 3] <= 8) continue;
          final double dx = (x + 0.5 - centre.dx * scale).abs();
          // Within the margin of the outline, sideways as well as up and
          // down: the ellipse's height must be read a margin further in.
          final double across = math.sqrt(
            math.max(
              0,
              1 - math.pow(math.min(math.max(0, dx - margin) / outer, 1), 2),
            ),
          );
          final double top =
              (centre.dy - tall / 2) * scale - across * outer * tilt - margin;
          final double bottom =
              (centre.dy + tall / 2) * scale + across * outer * tilt + margin;
          if (dx > outer + margin || y + 0.5 < top || y + 0.5 > bottom) {
            outside.add('($x, $y)');
          }
        }
      }
      expect(outside, isEmpty, reason: name);
    }
  });

  testWidgets('a closed ring is solid: walls, faces and seams', (
    WidgetTester tester,
  ) async {
    for (final (
          String name,
          ProteinRing ring,
          double radius,
          double thickness,
          double tall,
          double tilt,
        )
        in <(String, ProteinRing, double, double, double, double)>[
          ('PCNA', pcna(rotation: 0.35), 20, 7, 10, 0.42),
          ('PCNA turned', pcna(rotation: 1.4), 20, 7, 10, 0.42),
          ('MCM2–7', motor(), 23, 10, 12, 0.4),
        ]) {
      final Uint8List pixels = (await render(tester, <ProteinRing>[
        ring,
      ])).single;
      int alphaAt(Offset p) {
        final int x = (p.dx * scale).floor();
        final int y = (p.dy * scale).floor();
        return pixels[(y * width + x) * 4 + 3];
      }

      final List<String> holes = <String>[];
      for (double angle = -math.pi; angle < math.pi; angle += 0.01) {
        final double c = math.cos(angle);
        final double s = math.sin(angle);
        // The middle of the top face, wherever it is seen from above.
        if (s.abs() > 0.35) {
          final Offset face =
              centre + Offset(c * radius, -tall / 2 + s * radius * tilt);
          if (alphaAt(face) < 235) holes.add('face at $angle');
        }
        // The middle of the outer wall, across the front.
        if (s > 0.5) {
          final double r = radius + thickness * 0.6;
          final Offset wall = centre + Offset(c * r, s * r * tilt);
          if (alphaAt(wall) < 235) holes.add('wall at $angle');
        }
      }
      expect(holes, isEmpty, reason: name);
    }
  });
}
