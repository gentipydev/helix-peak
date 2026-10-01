import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One subunit's share of a ring between two angles, whether either end is
/// only where the ring's near and far halves meet rather than the subunit's
/// own end, and how far its top face reaches: a hair past a cut, for a far
/// part, under the near part drawn after it, so no seam shows between them.
typedef _Part = ({
  int j,
  double a,
  double b,
  bool cutA,
  bool cutB,
  double faceA,
  double faceB,
});

/// A ring of protein subunits around the DNA, seen from the side and a little
/// from above. Each subunit is a rounded block with square-cut ends, and a
/// recessed core runs under them, so a seam between two is a groove with a
/// floor, never a hole. The far half, with the inner wall seen through the
/// hole, is drawn before the DNA; the near half and its outer wall after it,
/// so the DNA threads the hole. PCNA as its 1AXC trimer shows it; MCM2–7 as
/// the helicase's motor; RFC open; ORC with Cdc6.
///
/// Everything drawn is a continuous function of the ring's angles: a subunit
/// passing from the back half to the front keeps its light, its edges and
/// its details, so a turning ring cannot flicker.
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
    this.round = 4,
    this.shine = 0.22,
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

  /// Each subunit's place around the ring, radians: 0 to the right, π/2
  /// nearest the viewer.
  final List<double> angles;

  /// How far each subunit reaches before and after its angle, radians. The
  /// gap to the next subunit is a seam; a wider one, an open interface.
  final List<(double, double)> extents;
  final List<Color> colors;

  /// How flat the ring looks from above: its top face's height over width.
  final double tilt;

  /// How squarely a subunit's shoulders turn into its ends: low is rounder,
  /// high is blockier. The ends themselves are always cut square.
  final double round;

  /// How much light the top face catches.
  final double shine;

  /// A warm light on each subunit, 0 to 1: an ATPase site firing.
  final List<double> glow;
  final double opacity;

  static const Color _warm = Color(0xFFFFF1D6);

  /// A subunit's half-thickness at its ends, as a share of the full.
  static const double _end = 0.72;

  /// The core's half-thickness, as a share of a subunit's: inside every
  /// subunit, so it shows only in the seams.
  static const double _core = 0.66;

  /// The core's rims are sampled at this spacing, radians.
  static const double _lattice = 0.04;

  /// Where a subunit is split between the halves, its far part's face runs
  /// this far under the near part, radians, so no seam shows between them.
  static const double _overlap = 0.01;

  // The light, from the upper left in front: x to the right, y up and z
  // towards the viewer.
  static const double _lx = -0.52;
  static const double _ly = 0.55;
  static const double _lz = 0.65;

  Offset _on(Offset level, double r, double angle) =>
      level + Offset(math.cos(angle) * r, math.sin(angle) * r * tilt);

  /// How far subunit [j]'s wall reaches either side of the ring's middle at
  /// [angle]: full across the subunit, easing to [_end] at its square ends,
  /// and a little uneven, as a folded domain is.
  double _half(int j, double angle) {
    final double offset = angle - angles[j];
    final double reach = offset < 0 ? extents[j].$1 : extents[j].$2;
    final double u = (offset / reach).clamp(-1.0, 1.0);
    final double shoulder = math.pow(u.abs(), round).toDouble();
    return thickness *
        (1 - (1 - _end) * shoulder) *
        (1 + 0.04 * math.sin(u * 3.1 + j * 1.7));
  }

  /// Angles from [a] to [b] round the core: both ends exactly, and between
  /// them a lattice fixed to [base]. A lattice point too close to an end is
  /// left out, so no segment is ever next to nothing.
  static List<double> _steps(double base, double a, double b) {
    const double clear = _lattice / 4;
    final List<double> steps = <double>[a];
    for (
      double k = ((a + clear - base) / _lattice).floorToDouble() + 1;
      base + k * _lattice < b - clear;
      k++
    ) {
      steps.add(base + k * _lattice);
    }
    return steps..add(b);
  }

  /// Where subunit [j]'s rims are sampled, as shares of its reach either
  /// side of its angle: densest at its shoulders, where its outline turns
  /// most, and fixed to the subunit, so the samples turn with it and widen
  /// and narrow with it as the ring opens.
  static const List<double> _shares = <double>[
    -0.99, -0.975, -0.95, -0.91, -0.86, -0.8, -0.7, -0.6, -0.5, -0.4, -0.3,
    -0.2, -0.1, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.86, 0.91, 0.95,
    0.975, 0.99,
  ];

  /// Angles from [a] to [b] across subunit [j]: both ends exactly, and its
  /// samples between them. Only where the halves meet does a sample come
  /// and go, and one too close to that cut is left out.
  List<double> _across(int j, double a, double b, bool cutA, bool cutB) {
    const double clear = _lattice / 4;
    final List<double> steps = <double>[a];
    for (final double u in _shares) {
      final double t =
          angles[j] + u * (u < 0 ? extents[j].$1 : extents[j].$2);
      if (t > a + (cutA ? clear : 1e-9) && t < b - (cutB ? clear : 1e-9)) {
        steps.add(t);
      }
    }
    return steps..add(b);
  }

  /// The shape between two curves over [steps]: along [first], then back
  /// along [second].
  static Path _band(
    List<double> steps,
    Offset Function(double) first,
    Offset Function(double) second,
  ) {
    final Path path = Path();
    final Offset start = first(steps.first);
    path.moveTo(start.dx, start.dy);
    for (int k = 1; k < steps.length; k++) {
      final Offset p = first(steps[k]);
      path.lineTo(p.dx, p.dy);
    }
    for (int k = steps.length - 1; k >= 0; k--) {
      final Offset p = second(steps[k]);
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// A curve over [steps], to be stroked.
  static Path _curve(List<double> steps, Offset Function(double) at) {
    final Path path = Path();
    final Offset start = at(steps.first);
    path.moveTo(start.dx, start.dy);
    for (int k = 1; k < steps.length; k++) {
      final Offset p = at(steps[k]);
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// The parts of [from]..[to] on the near side (sin ≥ 0) or the far side,
  /// cut at every multiple of π, where the ring passes from front to back.
  static List<({double a, double b, bool cutA, bool cutB})> _split(
    double from,
    double to,
    bool near,
  ) {
    final List<({double a, double b, bool cutA, bool cutB})> parts =
        <({double a, double b, bool cutA, bool cutB})>[];
    double start = from;
    while (start < to - 1e-9) {
      final double cut = math.min(
        to,
        (((start + 1e-9) / math.pi).floorToDouble() + 1) * math.pi,
      );
      if ((math.sin((start + cut) / 2) >= 0) == near) {
        parts.add((
          a: start,
          b: cut,
          cutA: start > from + 1e-9,
          cutB: cut < to - 1e-9,
        ));
      }
      start = cut;
    }
    return parts;
  }

  /// Lambert light on a surface whose normal is (nx, ny, nz), 0 to 1.
  static double _lit(double nx, double ny, double nz) =>
      math.max(0.0, nx * _lx + ny * _ly + nz * _lz);

  /// A wall lit as a cylinder seen from the front: brightest on the left of
  /// its front, dark at its right edge. [outward] is false for the inner
  /// wall, which faces the axis.
  ui.Gradient _cylinder(Color color, double r, {required bool outward}) {
    const List<double> across = <double>[
      -1,
      -0.85,
      -0.6,
      -0.3,
      0,
      0.3,
      0.6,
      0.85,
      1,
    ];
    final Color dark = Color.lerp(color, Colors.black, outward ? 0.6 : 0.78)!;
    final Color light = outward
        ? Color.lerp(color, Colors.white, 0.08)!
        : Color.lerp(color, Colors.black, 0.4)!;
    return ui.Gradient.linear(
      centre - Offset(r, 0),
      centre + Offset(r, 0),
      <Color>[
        for (final double c in across)
          Color.lerp(
            dark,
            light,
            0.28 +
                0.72 *
                    _lit(
                      outward ? c : -c,
                      0,
                      math.sqrt(math.max(0.0, 1 - c * c)),
                    ),
          )!,
      ],
      <double>[for (final double c in across) (c + 1) / 2],
    );
  }

  void draw(Canvas canvas, {required bool near}) {
    if (opacity <= 0) {
      return;
    }
    final double outer = radius + thickness;
    if (opacity < 1) {
      canvas.saveLayer(
        Rect.fromCenter(
          center: centre,
          width: outer * 2 + 8,
          height: outer * 2 * tilt + height + 8,
        ),
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }
    final Offset top = centre - Offset(0, height / 2);
    final Offset bottom = centre + Offset(0, height / 2);
    _drawCore(canvas, top, bottom, near: near);
    final List<_Part> parts = <_Part>[
      for (int j = 0; j < angles.length; j++)
        for (final ({double a, double b, bool cutA, bool cutB}) part
            in _split(
              angles[j] - extents[j].$1,
              angles[j] + extents[j].$2,
              near,
            ))
          (
            j: j,
            a: part.a,
            b: part.b,
            cutA: part.cutA,
            cutB: part.cutB,
            // A far part's face reaches a hair under the near part, which
            // covers it, but never past the subunit's own end.
            faceA: !near && part.cutA
                ? math.max(part.a - _overlap, angles[j] - extents[j].$1)
                : part.a,
            faceB: !near && part.cutB
                ? math.min(part.b + _overlap, angles[j] + extents[j].$2)
                : part.b,
          ),
    ];
    // Back to front. Two parts at the same depth are mirror images across
    // the ring's front, so they never overlap and their order cannot show.
    parts.sort(
      (_Part p, _Part q) =>
          math.sin((p.a + p.b) / 2).compareTo(math.sin((q.a + q.b) / 2)),
    );
    for (final _Part part in parts) {
      _drawPart(canvas, part, top, bottom, near: near);
    }
    if (opacity < 1) {
      canvas.restore();
    }
  }

  /// The core under the subunits: a lower, thinner band of the darkest tint.
  /// It is whole round a closed ring and stops inside the end subunits at an
  /// open interface, easing between the two as the interface opens.
  void _drawCore(
    Canvas canvas,
    Offset top,
    Offset bottom, {
    required bool near,
  }) {
    final int n = angles.length;
    final double first = angles.first - extents.first.$1;
    final double last = angles[n - 1] + extents[n - 1].$2;
    final double gap = math.pi * 2 - (last - first);
    final double closed = 1 - _ease((gap - 0.2) / 0.25);
    const double inset = 0.12;
    final double from = first + inset * (1 - closed) - gap / 2 * closed;
    // Closed, its two ends overlap a little in the last seam.
    final double to =
        last - inset * (1 - closed) + gap / 2 * closed + 0.02 * closed;
    if (to <= from) {
      return;
    }
    final Color base = Color.lerp(_mean, Colors.black, 0.5)!;
    final Offset coreTop = top + Offset(0, height * 0.1);
    final Offset coreBottom = bottom - Offset(0, height * 0.04);
    final double half = thickness * _core;
    final Paint fill = Paint();
    for (final ({double a, double b, bool cutA, bool cutB}) part
        in _split(from, to, near)) {
      final List<double> steps = _steps(0, part.a, part.b);
      canvas.drawPath(
        _band(
          steps,
          (double t) => _on(coreTop, radius + (near ? half : -half), t),
          (double t) => _on(coreBottom, radius + (near ? half : -half), t),
        ),
        fill..color = Color.lerp(base, Colors.black, near ? 0.2 : 0.45)!,
      );
      canvas.drawPath(
        _band(
          steps,
          (double t) => _on(coreTop, radius + half, t),
          (double t) => _on(coreTop, radius - half, t),
        ),
        fill..color = base,
      );
    }
  }

  Color get _mean {
    double r = 0;
    double g = 0;
    double b = 0;
    for (final Color color in colors) {
      r += color.r;
      g += color.g;
      b += color.b;
    }
    return Color.from(
      alpha: 1,
      red: r / colors.length,
      green: g / colors.length,
      blue: b / colors.length,
    );
  }

  static double _ease(double t) {
    final double v = t.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  void _drawPart(
    Canvas canvas,
    _Part part,
    Offset top,
    Offset bottom, {
    required bool near,
  }) {
    final int j = part.j;
    final Color color = colors[j];
    final double warmth = j < glow.length ? glow[j] : 0;
    final List<double> steps = _across(j, part.a, part.b, part.cutA, part.cutB);
    double outerAt(double t) => radius + _half(j, t);
    double innerAt(double t) => radius - _half(j, t);
    final Paint fill = Paint();
    // Butt ends: where a subunit has only just crossed into a half, its part
    // there is next to nothing, and a round end would draw it as a dot.
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;

    if (near) {
      // The outer wall, lit as a cylinder, darkening towards its base.
      final Path wall = _band(
        steps,
        (double t) => _on(top, outerAt(t), t),
        (double t) => _on(bottom, outerAt(t), t),
      );
      canvas.drawPath(
        wall,
        fill
          ..color = Colors.black
          ..shader = _cylinder(color, radius + thickness, outward: true),
      );
      fill.shader = null;
      for (final double from in const <double>[0.5, 0.74]) {
        canvas.drawPath(
          _band(
            steps,
            (double t) => _on(top + Offset(0, height * from), outerAt(t), t),
            (double t) => _on(bottom, outerAt(t), t),
          ),
          fill..color = Colors.black.withValues(alpha: 0.1),
        );
      }
      if (warmth > 0) {
        canvas.drawPath(
          wall,
          fill..color = _warm.withValues(alpha: 0.32 * warmth),
        );
      }
      canvas.drawPath(
        _curve(steps, (double t) => _on(bottom, outerAt(t), t)),
        line
          ..strokeWidth = 0.8
          ..color = Color.lerp(color, Colors.black, 0.75)!.withValues(
            alpha: 0.6,
          ),
      );
    } else {
      // The inner wall, facing the viewer through the hole: the interior.
      canvas.drawPath(
        _band(
          steps,
          (double t) => _on(top, innerAt(t), t),
          (double t) => _on(bottom, innerAt(t), t),
        ),
        fill
          ..color = Colors.black
          ..shader = _cylinder(color, radius - thickness, outward: false),
      );
      fill.shader = null;
      // The helices lining the hole, two to a subunit, as short coils. Each
      // shows as its own place on the wall turns to face the hole.
      for (final double u in const <double>[-0.42, 0.42]) {
        final double angle =
            angles[j] + u * (u < 0 ? extents[j].$1 : extents[j].$2);
        if (angle < part.a || angle > part.b) {
          continue;
        }
        final double facing = _ease((-math.sin(angle) - 0.05) / 0.3);
        if (facing <= 0) {
          continue;
        }
        final Offset c = _on(centre, innerAt(angle), angle);
        line
          ..strokeWidth = 0.9
          ..color = Colors.black.withValues(alpha: 0.4 * facing);
        for (int turn = -1; turn <= 1; turn++) {
          canvas.drawArc(
            Rect.fromCenter(
              center: c + Offset(0, turn * height * 0.26),
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

    // The square-cut ends that face the viewer, lit by which way they face.
    for (final (bool cut, double angle, double sign) in <(bool, double, double)>[
      (part.cutA, part.a, -1),
      (part.cutB, part.b, 1),
    ]) {
      // An end faces the viewer when its normal, ±(−sin, 0, cos), does.
      final double nx = -sign * math.sin(angle);
      final double nz = sign * math.cos(angle);
      if (cut || nz <= 0) {
        continue;
      }
      final Offset topIn = _on(top, innerAt(angle), angle);
      final Offset topOut = _on(top, outerAt(angle), angle);
      final Offset bottomOut = _on(bottom, outerAt(angle), angle);
      final Offset bottomIn = _on(bottom, innerAt(angle), angle);
      final Path end = Path()
        ..moveTo(topIn.dx, topIn.dy)
        ..lineTo(topOut.dx, topOut.dy)
        ..lineTo(bottomOut.dx, bottomOut.dy)
        ..lineTo(bottomIn.dx, bottomIn.dy)
        ..close();
      canvas.drawPath(
        end,
        fill
          ..color = Color.lerp(
            Color.lerp(color, Colors.black, 0.62)!,
            Color.lerp(color, Colors.black, 0.06)!,
            0.2 + 0.8 * _lit(nx, 0, nz),
          )!,
      );
      if (warmth > 0) {
        canvas.drawPath(
          end,
          fill..color = _warm.withValues(alpha: 0.3 * warmth),
        );
      }
    }

    // The top face: the light from the upper left that the rings have
    // always caught, and the back of the ring a little deeper in shade.
    final double reach = (radius + thickness) * tilt;
    final Path face = _band(
      part.faceA == part.a && part.faceB == part.b
          ? steps
          : _across(j, part.faceA, part.faceB, part.cutA, part.cutB),
      (double t) => _on(top, outerAt(t), t),
      (double t) => _on(top, innerAt(t), t),
    );
    canvas.drawPath(
      face,
      fill
        ..color = Colors.black
        ..shader = ui.Gradient.radial(
          top + Offset(-radius * 0.6, -radius * tilt * 0.8),
          radius * 2.6,
          <Color>[
            Color.lerp(color, Colors.white, shine)!,
            Color.lerp(color, Colors.black, 0.16)!,
          ],
        ),
    );
    fill.shader = ui.Gradient.linear(
      top - Offset(0, reach),
      top + Offset(0, reach * 0.2),
      <Color>[
        Colors.black.withValues(alpha: 0.24),
        Colors.black.withValues(alpha: 0),
      ],
    );
    canvas.drawPath(face, fill);
    fill.shader = null;
    // Folds on the surface: a few soft, lighter lumps, fixed to the subunit
    // and cut at the seam between the halves rather than moved across it.
    final double lump = thickness * 0.45 / radius;
    for (final double u in const <double>[-0.45, 0.1, 0.55]) {
      final double angle =
          angles[j] + u * (u < 0 ? extents[j].$1 : extents[j].$2);
      if (angle < part.a - lump || angle > part.b + lump) {
        continue;
      }
      final bool whole = angle > part.a + lump && angle < part.b - lump;
      if (!whole) {
        canvas.save();
        canvas.clipPath(face);
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: _on(top, radius + thickness * 0.15 * u, angle),
          width: thickness * 0.9,
          height: thickness * 0.9 * math.max(tilt, 0.5),
        ),
        fill..color = Colors.white.withValues(alpha: 0.06),
      );
      if (!whole) {
        canvas.restore();
      }
    }
    if (warmth > 0) {
      canvas.drawPath(face, fill..color = _warm.withValues(alpha: 0.4 * warmth));
    }

    // Edges: only the subunit's own. The outer rim is a dark line where it
    // is the ring's far silhouette and a soft light where the wall turns
    // down towards the viewer, blended by height, so it never switches.
    final Color edge = Color.lerp(color, Colors.black, 0.65)!;
    canvas.drawPath(
      _curve(steps, (double t) => _on(top, outerAt(t), t)),
      line
        ..strokeWidth = 0.8
        ..color = Colors.black
        ..shader = ui.Gradient.linear(
          top - Offset(0, reach),
          top + Offset(0, reach),
          <Color>[
            edge.withValues(alpha: 0.6),
            edge.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.24),
          ],
          <double>[0, 0.45, 0.7, 1],
        ),
    );
    line.shader = null;
    canvas.drawPath(
      _curve(steps, (double t) => _on(top, innerAt(t), t)),
      line
        ..strokeWidth = 0.7
        ..color = edge.withValues(alpha: 0.5),
    );
    for (final (bool cut, double angle) in <(bool, double)>[
      (part.cutA, part.a),
      (part.cutB, part.b),
    ]) {
      if (cut) {
        continue;
      }
      final Offset from = _on(top, innerAt(angle), angle);
      final Offset to = _on(top, outerAt(angle), angle);
      canvas.drawLine(from, to, line);
    }
  }
}

/// Angles for [count] domains in [groups] subunits: a subunit's domains sit
/// closer together than neighbours across a subunit interface, which is how
/// a trimer of two-domain PCNA subunits reads as three. [open] pulls the
/// interface between the last domain and the first apart, radians, as RFC
/// holds the ring open: the closed layout is pressed into the rest of the
/// circle, so no domain ever overlaps another. Give [ringExtents] the same
/// [open].
List<double> ringAngles({
  required int count,
  int groups = 0,
  double rotation = 0,
  double open = 0,
}) {
  final int perGroup = groups > 0 ? count ~/ groups : 1;
  final double step = math.pi * 2 / count;
  final double squeeze = 1 - open / (math.pi * 2);
  return <double>[
    for (int j = 0; j < count; j++)
      rotation +
          open / 2 +
          squeeze *
              (((j ~/ perGroup) + 0.5) * step * perGroup +
                  ((j % perGroup) - (perGroup - 1) / 2) *
                      step *
                      (groups > 0 ? 0.8 : 1)),
  ];
}

/// How far each domain of [ringAngles]' layout reaches either side, leaving
/// a thin seam within a subunit and a wider one between subunits. An [open]
/// ring's domains are pressed together to leave room for the opening.
List<(double, double)> ringExtents({
  required int count,
  int groups = 0,
  double seam = 0.05,
  double open = 0,
}) {
  final int perGroup = groups > 0 ? count ~/ groups : 1;
  final double step = math.pi * 2 / count;
  final double squeeze = 1 - open / (math.pi * 2);
  if (groups <= 0) {
    final double half = (step / 2 - seam) * squeeze;
    return <(double, double)>[for (int j = 0; j < count; j++) (half, half)];
  }
  // Within a subunit the domains are 0.8 steps apart; across an interface,
  // the rest.
  final double inner = (step * 0.8 / 2 - seam * 0.6) * squeeze;
  final double outer =
      ((step * perGroup - step * 0.8 * (perGroup - 1)) / 2 - seam * 1.6) *
      squeeze;
  return <(double, double)>[
    for (int j = 0; j < count; j++)
      (
        j % perGroup == 0 ? outer : inner,
        j % perGroup == perGroup - 1 ? outer : inner,
      ),
  ];
}
