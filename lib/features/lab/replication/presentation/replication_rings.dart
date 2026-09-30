import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A ring of protein domains around the DNA, seen from the side and a little
/// from above: a torus cut into one sector per domain. Its far half, and the
/// helix-lined inner wall seen through the hole, are drawn before the DNA;
/// its near half and outer wall after it, so the DNA threads the hole. PCNA
/// as its 1AXC trimer shows it; MCM2–7 as the helicase's motor; RFC open.
@immutable
class ProteinRing {
  const ProteinRing({
    required this.centre,
    required this.radius,
    required this.thickness,
    required this.height,
    required this.angles,
    required this.extents,
    required this.colors,
    this.tilt = 0.42,
    this.round = 6,
    this.shine = 0.22,
    this.window = false,
    this.glow = const <double>[],
    this.opacity = 1,
  });

  final Offset centre;

  /// From the ring's axis to the middle of its wall.
  final double radius;

  /// Half the wall's width, from the hole to the outside.
  final double thickness;

  /// Along the DNA.
  final double height;

  /// Each domain's place around the ring, radians: 0 to the right, π/2
  /// nearest the viewer.
  final List<double> angles;

  /// How far each domain reaches before and after its angle, radians. The
  /// gap to the next domain is a seam; a wider one, an open interface.
  final List<(double, double)> extents;
  final List<Color> colors;

  /// How flat the ring looks from above: its top face's height over width.
  final double tilt;

  /// How squarely a domain ends: low is rounder, high is blockier.
  final double round;

  /// How much light the top face catches.
  final double shine;

  /// Leave out the domain nearest the viewer: a cut-away window onto the
  /// strand inside, as the other enzymes' cut faces are.
  final bool window;

  /// A warm light on each domain, 0 to 1: an ATPase site firing.
  final List<double> glow;
  final double opacity;

  static const Color _warm = Color(0xFFFFF1D6);

  Offset _on(Offset c, double r, double angle) =>
      c + Offset(math.cos(angle) * r, math.sin(angle) * r * tilt);

  /// How far domain [j]'s wall reaches from the ring's middle at [angle]:
  /// full across the domain, rounding off at its ends, and a little uneven,
  /// as a folded domain is.
  double _half(int j, double angle) {
    final double offset = angle - angles[j];
    final double reach = offset < 0 ? extents[j].$1 : extents[j].$2;
    final double u = (offset / reach).clamp(-1.0, 1.0);
    final double end = math.pow(1 - math.pow(u.abs(), round), 1 / 3).toDouble();
    return thickness * end * (1 + 0.07 * math.sin(u * 3.1 + j * 1.7));
  }

  /// Domain [j]'s face (the ring's top) between two angles.
  Path _face(Offset c, int j, double from, double to) {
    final Path path = Path();
    const int steps = 12;
    for (int k = 0; k <= steps; k++) {
      final double angle = from + (to - from) * k / steps;
      final Offset p = _on(c, radius + _half(j, angle), angle);
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    for (int k = steps; k >= 0; k--) {
      final double angle = from + (to - from) * k / steps;
      final Offset p = _on(c, radius - _half(j, angle), angle);
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// Domain [j]'s outer ([outer]) or inner wall between two angles, from the
  /// top rim down.
  Path _wall(int j, double from, double to, {required bool outer}) {
    final Offset top = centre - Offset(0, height / 2);
    final Offset bottom = centre + Offset(0, height / 2);
    double r(double angle) =>
        radius + (outer ? 1 : -1) * _half(j, angle);
    final Path path = Path();
    const int steps = 12;
    for (int k = 0; k <= steps; k++) {
      final double angle = from + (to - from) * k / steps;
      final Offset p = _on(top, r(angle), angle);
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    for (int k = steps; k >= 0; k--) {
      final double angle = from + (to - from) * k / steps;
      final Offset p = _on(bottom, r(angle), angle);
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// The part of [from]..[to] on the near side (sin ≥ 0) or the far side.
  static List<(double, double)> _split(double from, double to, bool near) {
    final List<(double, double)> parts = <(double, double)>[];
    // Cut at every multiple of π, where a domain passes from front to back.
    double start = from;
    while (start < to - 1e-9) {
      final double cut = math.min(
        to,
        ((start / math.pi).floorToDouble() + 1) * math.pi,
      );
      final double middle = (start + cut) / 2;
      if ((math.sin(middle) >= 0) == near) {
        parts.add((start, cut));
      }
      start = cut;
    }
    return parts;
  }

  void draw(Canvas canvas, {required bool near}) {
    if (opacity <= 0) {
      return;
    }
    final Rect bounds = Rect.fromCenter(
      center: centre,
      width: (radius + thickness) * 2 + 8,
      height: (radius + thickness) * 2 * tilt + height + 8,
    );
    if (opacity < 1) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }
    final Offset top = centre - Offset(0, height / 2);
    final Paint fill = Paint()..isAntiAlias = true;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (!near) {
      // Through the hole: the far half of the inner wall, lined with the
      // helices that face the DNA.
      canvas.save();
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCenter(
            center: top,
            width: (radius - thickness) * 2,
            height: (radius - thickness) * 2 * tilt,
          ),
        ),
      );
      for (int j = 0; j < angles.length; j++) {
        final double from = angles[j] - extents[j].$1;
        final double to = angles[j] + extents[j].$2;
        for (final (double a, double b) in _split(from, to, false)) {
          canvas.drawPath(
            _wall(j, a, b, outer: false),
            fill..color = Color.lerp(colors[j], Colors.black, 0.62)!,
          );
          // A helix or two on the inner face, as short coils.
          final double mid = (a + b) / 2;
          final Offset c = _on(centre, radius - thickness, mid);
          line
            ..strokeWidth = 0.9
            ..color = Colors.black.withValues(alpha: 0.35);
          for (int turn = -1; turn <= 1; turn++) {
            canvas.drawArc(
              Rect.fromCenter(
                center: c + Offset(0, turn * height * 0.28),
                width: 3.2,
                height: 2.2,
              ),
              0,
              math.pi,
              false,
              line,
            );
          }
        }
      }
      canvas.restore();
    }

    for (int j = 0; j < angles.length; j++) {
      final double from = angles[j] - extents[j].$1;
      final double to = angles[j] + extents[j].$2;
      final bool cut = window && near && math.sin(angles[j]) > 0.85;
      if (cut) {
        continue;
      }
      final Color color = colors[j];
      final double warmth = j < glow.length ? glow[j] : 0;
      for (final (double a, double b) in _split(from, to, near)) {
        if (near) {
          // The outer wall, where the β-sheets lie, lit from the left.
          final Offset left = _on(top, radius + thickness, math.pi);
          final Offset right = _on(top, radius + thickness, 0);
          canvas.drawPath(
            _wall(j, a, b, outer: true),
            fill
              ..color = Colors.black
              ..shader = ui.Gradient.linear(left, right, <Color>[
                Color.lerp(color, Colors.black, 0.18)!,
                Color.lerp(color, Colors.black, 0.52)!,
              ]),
          );
          fill.shader = null;
          if (warmth > 0) {
            canvas.drawPath(
              _wall(j, a, b, outer: true),
              fill..color = _warm.withValues(alpha: 0.45 * warmth),
            );
          }
          line
            ..strokeWidth = 0.8
            ..color = Colors.white.withValues(alpha: 0.12);
          final int strands = math.max(1, ((b - a) / 0.22).round());
          for (int k = 0; k < strands; k++) {
            final double angle = a + (b - a) * (k + 0.5) / strands;
            final Offset p = _on(centre, radius + thickness, angle);
            canvas.drawLine(
              p + Offset(-1.2, -height * 0.32),
              p + Offset(1.2, height * 0.32),
              line,
            );
          }
        }
        // The top face, lit from above and a little from the left.
        final Path face = _face(top, j, a, b);
        canvas.drawPath(
          face,
          fill
            ..color = Colors.black
            ..shader = ui.Gradient.radial(
              top + Offset(-radius * 0.6, -radius * tilt * 0.8),
              radius * 2.6,
              <Color>[
                Color.lerp(color, Colors.white, near ? shine : shine / 2)!,
                Color.lerp(color, Colors.black, near ? 0.12 : 0.34)!,
              ],
            ),
        );
        fill.shader = null;
        // Folds on the surface: a few soft, lighter lumps per domain.
        for (final double u in const <double>[-0.45, 0.1, 0.55]) {
          final double angle = angles[j] +
              u * (u < 0 ? extents[j].$1 : extents[j].$2);
          if (angle < a || angle > b) {
            continue;
          }
          final Offset p = _on(top, radius + thickness * 0.15 * u, angle);
          canvas.drawOval(
            Rect.fromCenter(
              center: p,
              width: thickness * 0.9,
              height: thickness * 0.9 * math.max(tilt, 0.5),
            ),
            fill
              ..color = Colors.white.withValues(alpha: near ? 0.07 : 0.035),
          );
        }
        if (warmth > 0) {
          canvas.drawPath(face, fill..color = _warm.withValues(alpha: 0.5 * warmth));
        }
        canvas.drawPath(
          face,
          line
            ..strokeWidth = 0.7
            ..color = Color.lerp(color, Colors.black, 0.6)!.withValues(
              alpha: 0.7,
            ),
        );
      }
    }
    if (opacity < 1) {
      canvas.restore();
    }
  }
}

/// Angles for [count] domains in [groups] subunits: a subunit's domains sit
/// closer together than neighbours across a subunit interface, which is how
/// a trimer of two-domain PCNA subunits reads as three. [open] pulls the
/// interface between the last domain and the first apart, radians, as RFC
/// holds the ring open.
List<double> ringAngles({
  required int count,
  int groups = 0,
  double rotation = 0,
  double open = 0,
}) {
  final int perGroup = groups > 0 ? count ~/ groups : 1;
  final double step = math.pi * 2 / count;
  return <double>[
    for (int j = 0; j < count; j++)
      rotation +
          ((j ~/ perGroup) + 0.5) * step * perGroup +
          ((j % perGroup) - (perGroup - 1) / 2) *
              step *
              (groups > 0 ? 0.8 : 1) +
          open * (j / (count - 1) - 0.5),
  ];
}

/// How far each domain of [ringAngles]' closed layout reaches either side,
/// leaving a thin seam within a subunit and a wider one between subunits.
List<(double, double)> ringExtents({
  required int count,
  int groups = 0,
  double seam = 0.05,
}) {
  final int perGroup = groups > 0 ? count ~/ groups : 1;
  final double step = math.pi * 2 / count;
  if (groups <= 0) {
    return <(double, double)>[
      for (int j = 0; j < count; j++) (step / 2 - seam, step / 2 - seam),
    ];
  }
  // Within a subunit the domains are 0.8 steps apart; across an interface,
  // the rest.
  final double inner = step * 0.8 / 2 - seam * 0.6;
  final double outer = (step * perGroup - step * 0.8 * (perGroup - 1)) / 2 - seam * 1.6;
  return <(double, double)>[
    for (int j = 0; j < count; j++)
      (
        j % perGroup == 0 ? outer : inner,
        j % perGroup == perGroup - 1 ? outer : inner,
      ),
  ];
}
