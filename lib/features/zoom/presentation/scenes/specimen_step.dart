import 'dart:math' as math;

import '../../domain/zoom_camera.dart';

/// How an organ drawn as a specimen of its own comes up on the step from
/// the body, by how far the organ has become its own (its scene's detail, 0
/// at the hand-over and 1 at its stop): its outline drawn in from the
/// body's, the specimen and its neighbours coming up over it, and the
/// figure's own parts giving way.
abstract final class SpecimenStep {
  /// How far the outline has been drawn in from the body's to the organ's,
  /// over [span] of the detail.
  static double settle(double detail, {double span = settling}) =>
      detail <= 0 ? 0 : smootherstep(detail / span);

  /// How much of the specimen and its neighbours shows.
  static double come(double detail) => detail <= 0
      ? 0
      : math.pow(math.min(1, detail), comePower).toDouble();

  /// How much of the figure's own parts round it still shows.
  static double figure(double detail) => 1 - detail.clamp(0.0, 1.0);

  /// Over how much of its detail the outline morphs from the body's to the
  /// organ's own; how the specimen and its neighbours come up with the
  /// detail, as its power: slow at first, while the outline settles, and
  /// never faster a frame than the detail itself rises.
  static const double settling = 0.45;
  static const double comePower = 1.25;
}
