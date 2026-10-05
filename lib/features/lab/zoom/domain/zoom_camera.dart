import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'zoom_depth.dart';

/// Where on screen one stop's scene is drawn: how many pixels one of its
/// units is, and which of its points is at the centre of the view.
///
/// A scene's unit is the width of the view at its own stop, so at its stop a
/// scene is drawn [Size.width] pixels to the unit with its own origin at the
/// centre.
@immutable
final class ZoomView {
  const ZoomView({
    required this.stop,
    required this.pixelsPerUnit,
    required this.centre,
    required this.progress,
    required this.isChild,
  });

  final ZoomStop stop;
  final double pixelsPerUnit;

  /// The scene's point at the centre of the view, in its units.
  final Offset centre;

  /// How far along the segment showing the view is, from 0 to 1.
  final double progress;

  /// Whether this is the stop the segment is going to, drawn inside the one
  /// it is leaving.
  final bool isChild;

  /// Where the scene's point [p] is on a view of [size].
  Offset toScreen(Offset p, Size size) =>
      size.center(Offset.zero) + (p - centre) * pixelsPerUnit;

  /// The scene's point on screen at [screen].
  Offset fromScreen(Offset screen, Size size) =>
      centre + (screen - size.center(Offset.zero)) / pixelsPerUnit;

  /// A length of [pixels] on screen, in the scene's units.
  double unitsOf(double pixels) => pixels / pixelsPerUnit;
}

/// The view at any depth, as two nested scenes: the stop the segment leaves,
/// and the next one drawn inside it at the place it lies.
///
/// Each scene says where in it the next stop lies (its portal, in its own
/// units). Across a segment the camera narrows by the segment's factor, and
/// the portal's place on screen glides to the centre over the first
/// [settle] of the segment: the camera is worked out from where the portal
/// is on screen, so the portal never leaves the view, however much the view
/// narrows meanwhile. Every value here is a continuous function of depth.
///
/// Positions are worked out in doubles for each scene in its own units, so
/// no transform anywhere composes the hundred-million-fold narrowing from a
/// body to its DNA.
final class ZoomCamera {
  ZoomCamera(this.depth, {required this.portalOf});

  final ZoomDepth depth;

  /// Where the stop after [stop] lies in [stop]'s scene, in its units.
  final Offset Function(ZoomStop stop) portalOf;

  /// How much of a segment the portal takes to reach the centre: half of
  /// it, so the glide eases out well before the next stop and stays gentle
  /// even inside a flight's own ease.
  static const double settle = 0.5;

  /// The two scenes at [d] on a view of [size]: the stop being left, and the
  /// one being entered.
  (ZoomView, ZoomView) at(double d, Size size) {
    final (int k, double s) = depth.segmentAt(d);
    final double ratio = depth.ratioOf(k);
    final double narrowed = math.pow(ratio, s).toDouble();
    final double ppu = size.width / narrowed;
    final ZoomStop from = ZoomStop.values[k];
    final Offset portal = portalOf(from);
    final double glide = smootherstep(s / settle);
    // The portal's offset from the centre, in the scene's units, shrinks
    // from where the stop frames it to nothing by `settle`.
    final Offset centre = portal * (1 - (1 - glide) * narrowed);
    return (
      ZoomView(
        stop: from,
        pixelsPerUnit: ppu,
        centre: centre,
        progress: s,
        isChild: false,
      ),
      ZoomView(
        stop: ZoomStop.values[k + 1],
        pixelsPerUnit: ppu * ratio,
        centre: (centre - portal) / ratio,
        progress: s,
        isChild: true,
      ),
    );
  }
}

/// 0 to 1 with no speed at either end, nor any change of speed: a move that
/// eases in and out without a jolt.
double smootherstep(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

/// 0 to 1 with no speed at either end.
double smoothstep(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
