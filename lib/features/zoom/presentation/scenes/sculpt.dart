import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../zoom_inks.dart';

/// How the zoom models a form: one light, from the upper left, falling on
/// shapes sculpted in the app's warm neutrals, and the mark glowing where
/// the gene is.
///
/// Each helper takes the box or path of a shape in whatever units its
/// scene draws in, so a scene sculpts at any scale; widths given in pixels
/// are passed already converted by the caller.
abstract final class Sculpt {
  /// Where the light's brightest point falls in a shape's box: toward its
  /// upper left.
  static const Alignment highlight = Alignment(-0.42, -0.5);

  /// A form's body: brightest toward the light, falling into shade on the
  /// far side. [light] is how far toward the ink its brightest point is
  /// lifted.
  static Shader body(
    Rect box,
    ZoomInks inks, {
    double light = 0.3,
    double opacity = 1,
  }) => RadialGradient(
    center: highlight,
    radius: 1.08,
    colors: <Color>[
      inks.lit(light).withValues(alpha: opacity),
      inks.lit(light * 0.42).withValues(alpha: opacity),
      inks.shade(0.82).withValues(alpha: opacity),
      inks.shade(0.56).withValues(alpha: opacity),
    ],
    stops: const <double>[0, 0.36, 0.78, 1],
  ).createShader(box);

  /// The light catching [path]'s edge on the side it falls from, fading
  /// round to nothing on the far side.
  static void rim(
    Canvas canvas,
    Path path,
    Rect box,
    ZoomInks inks, {
    required double width,
    double strength = 0.5,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            inks.text.withValues(alpha: strength),
            inks.text.withValues(alpha: strength * 0.18),
            inks.text.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 0.8],
        ).createShader(box),
    );
  }

  /// The soft shadow a form cast on the ground, under it and a little to
  /// the right, as the light is from the upper left.
  static void shadowUnder(
    Canvas canvas,
    Rect box,
    ZoomInks inks, {
    double strength = 0.6,
    double spread = 1.12,
  }) {
    final Rect under = Rect.fromCenter(
      center: box.center + Offset(box.width * 0.05, box.height * 0.09),
      width: box.width * spread,
      height: box.height * spread,
    );
    canvas.drawOval(
      under,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            inks.shadow.withValues(alpha: strength),
            inks.shadow.withValues(alpha: strength * 0.6),
            inks.shadow.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(under),
    );
  }

  /// A glow of the mark about [centre], [radius] out, [alpha] at its heart.
  static void glow(
    Canvas canvas,
    Offset centre,
    double radius,
    ZoomInks inks,
    double alpha,
  ) {
    if (alpha <= 0.002 || radius <= 0) {
      return;
    }
    final Rect area = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawOval(
      area,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            inks.glow(alpha),
            inks.glow(alpha * 0.32),
            inks.glow(0),
          ],
          stops: const <double>[0, 0.42, 1],
        ).createShader(area),
    );
  }

  /// [path] stroked in the mark, with a soft glow round the stroke: a wide,
  /// faint stroke under a crisp one. Cheaper than a blur, and the same at
  /// any scale.
  static void glowingStroke(
    Canvas canvas,
    Path path,
    ZoomInks inks, {
    required double width,
    double alpha = 1,
  }) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      path,
      paint
        ..strokeWidth = width * 4.5
        ..color = inks.glow(0.1 * alpha),
    );
    canvas.drawPath(
      path,
      paint
        ..strokeWidth = width * 2.4
        ..color = inks.glow(0.22 * alpha),
    );
    canvas.drawPath(
      path,
      paint
        ..strokeWidth = width
        ..color = inks.glow(0.95 * alpha),
    );
  }

  /// How far through a beat that starts [delay] seconds after a stop is
  /// reached and lasts [length] seconds the stop is, [dwell] seconds after
  /// it was reached: 0 before, 1 after.
  static double beat(double dwell, {double delay = 0, double length = 0.9}) =>
      ((dwell - delay) / length).clamp(0.0, 1.0);

  /// A ring of the mark spreading [grow] out from [radius] about [centre]
  /// and fading, [t] of the way through: the beat a stop plays once as it
  /// is reached. Nothing before it starts or after it ends.
  static void ping(
    Canvas canvas,
    Offset centre,
    double radius,
    double grow,
    double t,
    double pixel,
    ZoomInks inks, {
    double opacity = 1,
  }) {
    if (t <= 0 || t >= 1 || opacity <= 0) {
      return;
    }
    final double out = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
      centre,
      radius + grow * out,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.2 - 1.2 * t) * pixel
        ..color = inks.glow((1 - t) * 0.8 * opacity),
    );
  }

  /// A band of light passing across [box], [t] of the way, clipped by the
  /// caller to the form it lights.
  static void sweep(
    Canvas canvas,
    Rect box,
    double t,
    ZoomInks inks, {
    double opacity = 1,
  }) {
    if (t <= 0 || t >= 1 || opacity <= 0) {
      return;
    }
    final double at = -0.2 + 1.4 * Curves.easeInOutCubic.transform(t);
    final double fade = math.sin(math.pi * t) * opacity;
    canvas.drawRect(
      box.inflate(box.shortestSide * 0.1),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            inks.text.withValues(alpha: 0),
            inks.text.withValues(alpha: 0.3 * fade),
            inks.text.withValues(alpha: 0),
          ],
          stops: <double>[
            (at - 0.16).clamp(0.0, 1.0),
            at.clamp(0.0, 1.0),
            (at + 0.16).clamp(0.0, 1.0),
          ],
        ).createShader(box),
    );
  }

  /// How far out a [beacon] reaches, in screen pixels: its dot and the thin
  /// ring round it. A ping spreads from here.
  static const double beaconRadius = 5.6;

  /// Where the zoom goes in, marked as a map marks a place: a dot of the
  /// mark, set off from what lies under it by a thin ring of the bright ink,
  /// in a soft glow. [pixel] is one screen pixel in the caller's units.
  static void beacon(
    Canvas canvas,
    Offset at,
    double pixel,
    ZoomInks inks, {
    double opacity = 1,
  }) {
    if (opacity <= 0.002) {
      return;
    }
    glow(canvas, at, 16 * pixel, inks, 0.32 * opacity);
    canvas.drawCircle(
      at,
      (beaconRadius - 0.7) * pixel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * pixel
        ..color = inks.text.withValues(alpha: 0.92 * opacity),
    );
    canvas.drawCircle(
      at,
      (beaconRadius - 1.4) * pixel,
      Paint()..color = inks.glow(opacity),
    );
  }

  /// A branching tree from [root], heading [angle], [length] long, each
  /// generation [shrink] as long as the one before and turned [spread] to
  /// either side, [depth] generations deep: a duct, a vessel, a bronchus.
  /// Each generation is a path of its own, the trunk first, so it can be
  /// stroked thinner as it branches.
  static List<Path> tree(
    Offset root,
    double angle,
    double length,
    int depth,
    math.Random random, {
    double spread = 0.5,
    double shrink = 0.72,
    double bend = 0.25,
  }) {
    final List<Path> generations = List<Path>.generate(
      depth + 1,
      (_) => Path(),
    );
    void grow(Offset from, double heading, double reach, int generation) {
      final double turn = (random.nextDouble() - 0.5) * bend;
      final Offset mid =
          from +
          Offset(math.cos(heading + turn), math.sin(heading + turn)) *
              (reach * 0.5);
      final Offset to =
          from + Offset(math.cos(heading), math.sin(heading)) * reach;
      generations[generation]
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
      if (generation < depth) {
        final double split = spread * (0.75 + 0.5 * random.nextDouble());
        grow(to, heading - split, reach * shrink, generation + 1);
        grow(to, heading + split, reach * shrink, generation + 1);
      }
    }

    grow(root, angle, length, 0);
    return generations;
  }

  /// Rounded lobules laid over [box] about [step] apart, each nudged a
  /// little from a hexagonal lattice: a gland's lobules, fat's lobes.
  static List<Rect> cobble(Rect box, double step, math.Random random) {
    final List<Rect> out = <Rect>[];
    int row = 0;
    for (double y = box.top; y < box.bottom + step; y += step * 0.866) {
      for (
        double x = box.left - (row.isOdd ? step / 2 : 0);
        x < box.right + step;
        x += step
      ) {
        final Offset at =
            Offset(x, y) +
            Offset(random.nextDouble() - 0.5, random.nextDouble() - 0.5) *
                (step * 0.28);
        final double r = step * (0.42 + 0.1 * random.nextDouble());
        out.add(Rect.fromCircle(center: at, radius: r));
      }
      row++;
    }
    return out;
  }

  /// One lobule: a small dome, lit on its upper left and shaded below.
  static void dome(Canvas canvas, Rect lobule, ZoomInks inks, double light) {
    canvas.drawOval(
      lobule,
      Paint()
        ..shader = RadialGradient(
          center: highlight,
          radius: 1,
          colors: <Color>[
            inks.lit(light).withValues(alpha: 0.55),
            inks.lit(light * 0.3).withValues(alpha: 0.18),
            inks.shadow.withValues(alpha: 0.32),
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(lobule),
    );
  }
}
