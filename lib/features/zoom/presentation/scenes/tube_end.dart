import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'specimen_light.dart';
import 'tube_course.dart';

/// The far end of a tube cut short, as an anatomy plate cuts what it has
/// taken away (the heart's great vessels): its wall, lit, round its dark
/// lumen, seen a little from the side.
final class TubeEnd {
  const TubeEnd(
    this.palette,
    this.shadow, {
    required this.length,
    required this.wall,
  });

  final SpecimenPalette palette;

  /// The ink deep in its lumen.
  final Color shadow;

  /// How long the cut end shows along its tube, and how thick its wall is,
  /// shares of its width.
  final double length;
  final double wall;

  /// Draws [tube]'s last row cut, in [tone] at [light].
  void paint(Canvas canvas, TubeCourse tube, SpecimenTone tone, double light) {
    final int row = tube.length - 1;
    final Offset c = tube.centres[row];
    final Offset m = tube.across[row];
    final double r = tube.radius[row];
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.atan2(m.dy, m.dx));
    final Rect end = Rect.fromCenter(
      center: Offset.zero,
      width: 2 * r,
      height: 2 * r * length,
    );
    canvas.drawOval(
      end,
      Paint()..color = Color(palette.colour(tone, light * 1.15)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: end.width * (1 - wall),
        height: end.height * (1 - wall),
      ),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.4),
          colors: <Color>[shadow, Color(palette.colour(tone, light * 0.35))],
        ).createShader(end),
    );
    canvas.restore();
  }
}
