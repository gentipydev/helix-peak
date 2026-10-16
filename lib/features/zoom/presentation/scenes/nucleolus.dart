import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../zoom_inks.dart';
import 'contour.dart';
import 'nucleus_shape.dart';
import 'sculpt.dart';

/// The nucleolus, where the cell makes its ribosomes: a dense body in the
/// nucleus with no membrane round it, lobed rather than round, near black
/// against the chromatin about it, and plain: its fibrillar centres are left
/// out (the user's choice of 2026-10-16, to keep the picture simple). The
/// cell's scene and the nucleus's draw it from here, each in its own units,
/// so it keeps its place, its shape and its tone across the step between
/// them.
final class Nucleolus {
  /// The nucleolus of a nucleus of [shape] and [radius], in that nucleus's
  /// units.
  Nucleolus(this.shape, this.radius) : centre = shape.place(at, radius);

  final NucleusShape shape;

  /// The nucleus's radius.
  final double radius;

  /// Where the nucleolus lies, in the nucleus's units.
  final Offset centre;

  /// Where it lies, as a point of the nucleus's unit disc: off the middle,
  /// toward the light.
  static const Offset at = Offset(-0.32, -0.28);

  /// Its radius as a share of the nucleus's: a body a micron or two across
  /// in a nucleus of six to ten.
  static const double reach = 0.18;

  /// Its outline's waves: how many round it, how far each pushes out, and
  /// where it starts. A broad ovoid, its edge uneven, with no notch deep
  /// enough to read as a cleft.
  static const List<(int, double, double)> _lobes = <(int, double, double)>[
    (1, 0.04, 0),
    (2, 0.08, 1.6),
    (3, 0.05, 3.3),
    (5, 0.04, 0.9),
    (8, 0.025, 2.6),
    (13, 0.012, 4),
  ];

  /// Its radii across and down: drawn out along a long nucleus, as far as
  /// the nucleus is, by the square root.
  (double, double) get radii {
    final (double ax, double ay) = shape.axes;
    return (radius * reach * math.sqrt(ax), radius * reach * math.sqrt(ay));
  }

  /// Its outline.
  late final Contour outline = () {
    final (double rx, double ry) = radii;
    const int count = 96;
    return Contour(<Offset>[
      for (int i = 0; i < count; i++)
        () {
          final double a = -math.pi / 2 + 2 * math.pi * i / count;
          double push = 1;
          for (final (int k, double size, double phase) in _lobes) {
            push += size * math.sin(k * a + phase);
          }
          return centre +
              Offset(math.cos(a) * rx * push, math.sin(a) * ry * push);
        }(),
    ]);
  }();

  late final Path path = outline.toPath();

  /// Draws it, [pixel] the scene's pixel: one dark body, lit a little on
  /// the side the light falls from.
  void paint(Canvas canvas, ZoomInks inks, double pixel) {
    final Rect box = path.getBounds();
    // No membrane: its edge softens into the nucleoplasm.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * pixel
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: Sculpt.highlight,
          radius: 1,
          colors: <Color>[inks.shade(0.2), inks.shade(0.08), inks.shadow],
          stops: const <double>[0, 0.55, 1],
        ).createShader(box),
    );
    Sculpt.rim(canvas, path, box, inks, width: 1.2 * pixel, strength: 0.18);
  }
}
