import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/chromatin_layout.dart';
import '../zoom_inks.dart';
import 'sculpt.dart';

/// A nucleosome's core, the histone octamer the DNA winds round: a lit puck
/// about 6.5 nm across and 5.7 nm thick (Luger et al. 1997), seen from
/// above and in front as [ChromatinLayout] lays its DNA round it, in the
/// zoom's warm neutrals.
abstract final class NucleosomeArt {
  /// The octamer's radius and half its thickness, in base pairs' lengths.
  static const double radius = 3.2 / 0.34;
  static const double half = 2.85 / 0.34;

  /// Draws a core about [centre], [perBase] pixels to a base pair's length,
  /// [grown] of its size, at [alpha].
  static void paint(
    Canvas canvas,
    Offset centre,
    double perBase,
    ZoomInks inks, {
    double grown = 1,
    double alpha = 1,
  }) {
    if (alpha <= 0.002 || grown <= 0) {
      return;
    }
    final double r = radius * perBase * grown;
    final double thick = half * perBase * grown;
    const double tilt = ChromatinLayout.tilt;
    final double faceTall = r * math.cos(tilt);
    final double lift = thick * math.sin(tilt);
    final Rect face = Rect.fromCenter(
      center: centre.translate(0, -lift),
      width: 2 * r,
      height: 2 * faceTall,
    );
    final Rect foot = Rect.fromCenter(
      center: centre.translate(0, lift),
      width: 2 * r,
      height: 2 * faceTall,
    );
    final Rect whole = Rect.fromLTRB(
      face.left,
      face.top,
      face.right,
      foot.bottom,
    );
    final bool fading = alpha < 0.995;
    if (fading) {
      canvas.saveLayer(
        whole.inflate(4),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
    }
    Sculpt.shadowUnder(canvas, whole, inks, strength: 0.45, spread: 1.08);
    // Its side, from the face's edge down to its foot, in shade below.
    final Path side = Path()
      ..addOval(foot)
      ..addRect(Rect.fromLTRB(face.left, face.center.dy, face.right, foot.center.dy));
    canvas.drawPath(
      side,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[inks.lit(0.22), inks.shade(0.7)],
        ).createShader(whole),
    );
    // Its face, lit from the upper left.
    canvas.drawOval(
      face,
      Paint()
        ..shader = RadialGradient(
          center: Sculpt.highlight,
          radius: 1.1,
          colors: <Color>[inks.lit(0.66), inks.lit(0.36), inks.lit(0.12)],
          stops: const <double>[0, 0.55, 1],
        ).createShader(face),
    );
    Sculpt.rim(
      canvas,
      Path()..addOval(face),
      face,
      inks,
      width: math.max(0.8, 0.06 * r),
      strength: 0.5,
    );
    if (fading) {
      canvas.restore();
    }
  }
}
