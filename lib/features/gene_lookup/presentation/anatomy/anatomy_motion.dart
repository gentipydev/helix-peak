import 'dart:math' as math;
import 'dart:ui';

/// How a cell travels between two stages.
///
/// The painter reproduces this arithmetic inline over typed arrays so its hot
/// loop allocates nothing; keeping the constants here is what stops the two
/// copies drifting apart, and `AnatomyScene.positionOf` is the reference the
/// widget and the tests read.
///
/// Its own file rather than the scene's, because the layout grooves the
/// reading frame open on the same ripple and cannot import the scene: the
/// scene is already built on the layout.
abstract final class AnatomyMotion {
  /// How much of the transition is spent letting the 5' end set off before the
  /// 3' end follows. The reflow ripples in the direction transcription and
  /// translation both run, which is why it reads as organic rather than as a
  /// spreadsheet re-sorting.
  static const double stagger = 0.28;

  /// The same idea for the reading frame opening, and a longer one.
  ///
  /// [stagger] is tuned for 1,431 cells reflowing at once, where the ripple
  /// is one detail among many. The groove is the only thing moving on a
  /// settled page, so it can afford to be read as a sweep down the block —
  /// and at 0.28 over twenty-three rows it was over before the eye arrived.
  static const double codonStagger = 0.45;

  /// Perpendicular bow of a cell's path, as a fraction of the distance it
  /// travels. Straight lines between grid positions look computed; a slight arc
  /// reads as something physical moving.
  static const double bow = 0.12;

  /// How far a departing cell drifts, in cells. It went somewhere, so the
  /// motion has to say so — it must never simply blink out. Kept short, and
  /// paired with a shrink: a long drift tears a visible hole in the middle of
  /// the composition, which reads as an explosion rather than an excision.
  static const double driftCells = 1.4;

  /// Departures part sideways rather than radially. A purely radial drift has a
  /// singularity at the centre of the canvas — every cell near it flees a point
  /// no cell is left to occupy — and the star-shaped hole that opens there is
  /// the first thing the eye goes to. Flattening the vertical component turns
  /// that into two halves of a curtain drawing back.
  static const double driftFlatten = 0.28;

  /// How far a departing cell shrinks by the time it is gone.
  static const double driftShrink = 0.6;

  /// The outward direction for a cell leaving from [origin].
  static Offset driftDirection(Offset origin, Size canvas) {
    final double dx = origin.dx - canvas.width / 2;
    final double dy = (origin.dy - canvas.height / 2) * driftFlatten;
    final double distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 1e-6) {
      return const Offset(0, -1);
    }
    return Offset(dx / distance, dy / distance);
  }

  /// [t] as cell [u] of the way along the sequence experiences it, where
  /// [u] runs 0 at the 5' end to 1 at the 3'.
  static double staggered(double t, double u, {double lead = stagger}) =>
      ((t - lead * u) / (1 - lead)).clamp(0.0, 1.0);

  /// easeInOutCubic, spelled out so the painter and the widget agree without
  /// reaching into the widgets layer for a Curve.
  static double ease(double t) => t < 0.5
      ? 4 * t * t * t
      : 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2;
}
