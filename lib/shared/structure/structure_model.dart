import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/fscene.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../core/catalog/protein_target.dart';
import '../../core/catalog/protein_track.dart';
import '../../core/network/track_source.dart';
import '../../core/theme/anatomy_colors.dart';

/// How far back of a snug fit the camera sits.
///
/// The model is normalised to a longest axis of 1 when it is baked, so the
/// camera is framed once and left alone: `framing` fits the bounding sphere,
/// and every rotation stays inside that same sphere, so nothing here needs a
/// scale constant and nothing can swing out of shot.
///
/// Measured on the page, and it has to be measured on *this* page. `framing`
/// fits to the vertical field of view, so the shorter the box the larger the
/// molecule: judged in a full-screen harness 1.35 looked lost, but the page
/// gives up 96 points to the header and 48 to the stage bar, and in that
/// box the same number is right. At 1.15 the silhouette reached 96% of the
/// width and touched both edges. 1.35 holds it near 82%, which leaves the
/// widest yaw — the x-z diagonal, 1.30 against the longest axis' 1.0 — clear
/// of the sides.
const double structureFramingMargin = 1.35;

/// The camera the fold page frames a model with, given the model's bounds.
///
/// Named so that anything drawn in the model's own frame is seen through the
/// same lens: the lab's fold animation projects its CA trace through it, and
/// its last frame lands where the page draws the fold.
PerspectiveCamera structureCamera(vm.Aabb3 bounds) =>
    PerspectiveCamera.framing(bounds, margin: structureFramingMargin);

/// Loads the molecule into [scene], paints and frames it, and compiles what
/// its first frame needs.
///
/// [StructureView.prepare] runs this into a scene it then drops, so that
/// when the page runs it for real everything expensive is already cached.
Future<(Node, PerspectiveCamera)> buildStructureModel(
  Scene scene,
  AnatomyColors anatomy,
  ProteinTarget target,
  TrackSource tracks,
) async {
  await Scene.initializeStaticResources();
  if (!Scene.isReadyToRender) {
    throw StateError('The 3D renderer did not initialize');
  }
  // The `.fsceneb` the bake compiled, fetched rather than compiled into the
  // bundle by `hook/build.dart`. No glTF is imported on the device: the
  // container is already the realized form, and the `.glb` it came from is
  // kept in storage only so a flutter_scene upgrade — which invalidates every
  // `.fsceneb` — can re-compile without the repo and another PyMOL run.
  final Node molecule = await loadFscenebBytesAsync(
    await tracks.read(target.slug, TrackKind.structure),
  );
  for (final StructureChain chain in target.chains) {
    _paint(molecule, target, chain.node, chain.tint.of(anatomy));
  }

  scene.add(molecule);
  final vm.Aabb3? bounds = molecule.combinedWorldBounds;
  final PerspectiveCamera camera = bounds == null
      ? PerspectiveCamera()
      : structureCamera(bounds);

  // Compile the pipelines the first frame needs before the SceneView is
  // mounted, rather than letting it warm up behind a loadingBuilder: that
  // builder is a second pulse, mounted in the frame the page's own is torn
  // down, and it starts over from frame 0. This is the same single view the
  // SceneView would warm up with.
  await scene.warmUp(<RenderView>[RenderView(camera: camera)]);
  return (molecule, camera);
}

/// Gives every primitive of one named node its own material.
///
/// The nodes are named in the `.glb` by the bake, which is what lets the
/// colour live here in the theme rather than baked into vertices where it
/// could never answer to a token. A name the model does not have means the
/// bake and the catalog have come apart, and the page says so rather than
/// drawing what is left.
void _paint(Node root, ProteinTarget target, String name, Color colour) {
  final Mesh? mesh = _find(root, name)?.mesh;
  if (mesh == null) {
    // Thrown, where this used to assert. An assert is right while the model
    // is compiled into the build from a file beside the catalog, because the
    // two can only come apart at build time and the assert fires. A fetched
    // container can be from an older bake than the row that named it, and in
    // release the assert is gone — so the page would draw an unpainted grey
    // molecule and say nothing. It says so instead.
    throw StateError('The model for ${target.slug} has no node named "$name".');
  }
  for (final MeshPrimitive primitive in mesh.primitives) {
    primitive.material = PhysicallyBasedMaterial()
      ..baseColorFactor = _linear(colour)
      // Protein illustration convention: matte, so the form is read from
      // shading rather than from highlights sliding over it as it turns.
      ..metallicFactor = 0
      ..roughnessFactor = 0.65;
  }
}

/// The importer is free to nest what it loads, so the node is looked for
/// rather than indexed.
Node? _find(Node node, String name) {
  if (node.name == name) {
    return node;
  }
  for (final Node child in node.children) {
    final Node? hit = _find(child, name);
    if (hit != null) {
      return hit;
    }
  }
  return null;
}

/// sRGB to linear, per the glTF specification's `baseColorFactor`.
vm.Vector4 _linear(Color colour) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return vm.Vector4(channel(colour.r), channel(colour.g), channel(colour.b), 1);
}
