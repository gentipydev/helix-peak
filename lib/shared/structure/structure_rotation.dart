import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math.dart' as vm;

/// Rotation shared by touch input and the molecule's slow idle turn.
class StructureRotation {
  double _yaw = 0;
  double _pitch = 0;

  /// A full idle revolution in forty seconds.
  static const double _idleRate = 2 * math.pi / 40;
  static const double _dragRate = 0.01;
  static const double _pitchLimit = math.pi / 2 - 0.15;

  // Apply yaw first, then pitch around the fixed screen-horizontal axis.
  // Euler yaw/pitch applies pitch in the molecule's frame, reversing vertical
  // drags after a half-turn and turning them into rolls at a quarter-turn.
  vm.Quaternion get value =>
      vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), _pitch) *
      vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _yaw);

  void tick(double deltaSeconds) {
    _yaw += _idleRate * deltaSeconds;
  }

  void drag(Offset delta) {
    // From the negative-Z camera, negative yaw moves the front surface right.
    _yaw -= delta.dx * _dragRate;
    // The viewer's camera looks from negative Z; negative X rotation moves
    // the visible surface down, matching positive (downward) screen Y.
    _pitch = (_pitch - delta.dy * _dragRate).clamp(-_pitchLimit, _pitchLimit);
  }
}
