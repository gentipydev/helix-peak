import 'dart:ui';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/structure/structure_model.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  // A stored model's box: centred, its longest side 1 (the bake normalises it).
  final vm.Aabb3 bounds = vm.Aabb3.minMax(
    vm.Vector3(-0.358553, -0.319856, -0.5),
    vm.Vector3(0.358553, 0.319856, 0.5),
  );

  test('the fold page frames a model as it always has', () {
    final PerspectiveCamera camera = structureCamera(bounds);
    final PerspectiveCamera framed = PerspectiveCamera.framing(
      bounds,
      margin: 1.35,
    );
    expect(structureFramingMargin, 1.35);
    expect(camera.position, framed.position);
    expect(camera.target, framed.target);
    expect(camera.up, framed.up);
    expect(camera.fovRadiansY, framed.fovRadiansY);
    expect(camera.fovNear, framed.fovNear);
    expect(camera.fovFar, framed.fovFar);
  });

  test('the model sits in the middle of the view it frames', () {
    const Size view = Size(390, 520);
    final Offset? centre = structureCamera(
      bounds,
    ).worldToScreen(vm.Vector3.zero(), view);
    expect(centre!.dx, closeTo(view.width / 2, 1e-9));
    expect(centre.dy, closeTo(view.height / 2, 1e-9));
  });
}
