import 'dart:ui';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/presentation/structure/structure_rotation.dart';
import 'package:vector_math/vector_math.dart' as vm;

const Size _viewport = Size(390, 600);

vm.Matrix4 _transform(StructureRotation rotation) =>
    vm.Matrix4.compose(vm.Vector3.zero(), rotation.value, vm.Vector3.all(1));

void main() {
  // Use the viewer's actual camera convention: it looks from negative Z.
  final PerspectiveCamera camera = PerspectiveCamera.framing(
    vm.Aabb3.minMax(vm.Vector3.all(-0.5), vm.Vector3.all(0.5)),
    margin: 1.35,
  );

  void expectFollowsFinger(StructureRotation rotation, Offset drag) {
    // Track a surface point facing the camera at the current orientation.
    // Project through matrices, as Node and SceneView do when rendering.
    final vm.Vector3 front = vm.Vector3(0, 0, -0.4);
    final vm.Vector3 local = vm.Matrix4.inverted(_transform(rotation))
        .transform3(front.clone());
    final Offset before = camera.worldToScreen(front, _viewport)!;
    rotation.drag(drag);
    final Offset after = camera.worldToScreen(
      _transform(rotation).transform3(local),
      _viewport,
    )!;
    final Offset travel = after - before;

    if (drag.dy != 0) {
      expect(travel.dy * drag.dy, greaterThan(0));
      expect(travel.dx.abs(), lessThan(0.01));
    } else {
      expect(travel.dx * drag.dx, greaterThan(0));
    }
  }

  for (final double seconds in <double>[0, 10, 20, 30]) {
    for (final double tilt in <double>[-60, 0, 60]) {
      for (final double dy in <double>[-10, 10]) {
        test('vertical drag $dy after ${seconds}s idle and $tilt tilt', () {
          final StructureRotation rotation = StructureRotation()
            ..tick(seconds)
            ..drag(Offset(0, tilt));
          expectFollowsFinger(rotation, Offset(0, dy));
        });
      }
      for (final double dx in <double>[-10, 10]) {
        test('horizontal drag $dx after ${seconds}s idle and $tilt tilt', () {
          final StructureRotation rotation = StructureRotation()
            ..tick(seconds)
            ..drag(Offset(0, tilt));
          expectFollowsFinger(rotation, Offset(dx, 0));
        });
      }
    }
  }

  for (final double yawDrag in <double>[0, 157, 314, 471]) {
    for (final Offset drag in const <Offset>[
      Offset(0, -10),
      Offset(0, 10),
      Offset(-10, 0),
      Offset(10, 0),
    ]) {
      test('drag $drag follows the finger after sideways drag $yawDrag', () {
        final StructureRotation rotation = StructureRotation()
          ..drag(Offset(yawDrag, 40));
        expectFollowsFinger(rotation, drag);
      });
    }
  }

  test('can drag back immediately after reaching either tilt limit', () {
    for (final double dy in <double>[-10000, 10000]) {
      final StructureRotation rotation = StructureRotation()
        ..drag(Offset(314, dy));
      expectFollowsFinger(rotation, Offset(0, dy > 0 ? -10 : 10));
    }
  });
}
