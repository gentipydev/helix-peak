import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../core/biology/amino_acids.dart';
import '../../core/catalog/protein_target.dart';
import '../../core/theme/anatomy_colors.dart';
import '../folding/fold_mesh.dart';
import '../folding/fold_timeline.dart';
import 'structure_model.dart';

/// The fold animation as nodes of the fold page's own scene.
///
/// Drawn in the scene, under the camera, the lights and the material the
/// model is drawn with ([structureMaterial]), so that when it ends on the
/// model it is already the same kind of thing: shading, framing and turn all
/// carry across. [FoldMesh] says where everything is; this puts it on the
/// GPU, in buffers updated in place.
final class FoldMorph {
  FoldMorph(FoldTimeline timeline, FoldPalette palette)
    : mesh = FoldMesh(timeline, palette) {
    for (final FoldTube tube in mesh.tubes) {
      final MeshGeometry geometry = MeshGeometry.fromArrays(
        positions: tube.positions,
        normals: tube.normals,
        colors: tube.colours,
        indices: tube.indices,
        storage: GeometryStorage.updatable,
      );
      _tubes.add(geometry);
      node.add(Node(name: 'fold chain', mesh: Mesh(geometry, _surface)));
    }
    _spheres = InstancedMesh(
      geometry: SphereGeometry(radius: 1, segments: 24, rings: 16),
      material: _beads,
    );
    for (int s = 0; s < mesh.sphereCount; s++) {
      _spheres.addInstance(_hidden);
    }
    _rods = InstancedMesh(
      geometry: CylinderGeometry(
        bottomRadius: 1,
        topRadius: 1,
        height: 1,
        radialSegments: 16,
      ),
      material: _bonds,
    );
    for (int r = 0; r < mesh.rodCount; r++) {
      _rods.addInstance(_hidden);
    }
    node
      ..add(Node(name: 'fold beads')..addComponent(InstancedMeshComponent(_spheres)))
      ..add(Node(name: 'fold bridges')..addComponent(InstancedMeshComponent(_rods)));
    _push();
  }

  /// The colours [target] is drawn in on the fold page, linear: its chains
  /// as the model paints them, its bridges as the model's `bonds` node, a
  /// residue with no place in [loose], and the property colours the grid
  /// gave each residue.
  static FoldPalette paletteOf(
    AnatomyColors anatomy,
    Color loose,
    ProteinTarget target,
  ) {
    LinearColour linear(Color colour) {
      final vm.Vector4 v = linearColour(colour);
      return (v.x, v.y, v.z);
    }

    final Map<String, LinearColour> chains = <String, LinearColour>{
      for (final StructureChain chain in target.chains)
        chain.node: linear(chain.tint.of(anatomy)),
    };
    final Map<String, LinearColour> properties = <String, LinearColour>{};
    return FoldPalette(
      chains: chains,
      loose: linear(loose),
      bridge: chains['bonds'] ?? linear(ChainTint.cysteine.of(anatomy)),
      property: (String letter) => properties.putIfAbsent(
        letter,
        () => linear(anatomy.forProperty(AminoAcids.propertyOf(letter))),
      ),
    );
  }

  final FoldMesh mesh;

  /// Everything the fold draws, under one node.
  final Node node = Node(name: 'fold');

  final List<MeshGeometry> _tubes = <MeshGeometry>[];
  late final InstancedMesh _spheres;
  late final InstancedMesh _rods;

  // A base of one, so that the vertex and instance colours are the colour,
  // as the model's base colour is.
  final PhysicallyBasedMaterial _surface = structureMaterialOf(_one());
  final PhysicallyBasedMaterial _beads = structureMaterialOf(_one());
  final PhysicallyBasedMaterial _bonds = structureMaterialOf(_one());

  static vm.Vector4 _one() => vm.Vector4(1, 1, 1, 1);

  static final vm.Matrix4 _hidden = vm.Matrix4.zero();
  final vm.Matrix4 _scratch = vm.Matrix4.zero();
  final vm.Vector4 _colour = vm.Vector4.zero();
  static final vm.Vector3 _up = vm.Vector3(0, 1, 0);

  double _opacity = 1;

  /// Moves the fold to [t], with loose residues moved on by [idle] seconds.
  void update(double t, {double idle = 0}) {
    mesh.update(t, idle: idle);
    _push();
  }

  /// How much of the fold shows: 1 until it hands over to the model, and
  /// down to 0 as it does.
  double get opacity => _opacity;
  set opacity(double value) {
    _opacity = value.clamp(0.0, 1.0);
    for (final PhysicallyBasedMaterial material in <PhysicallyBasedMaterial>[
      _surface,
      _beads,
      _bonds,
    ]) {
      material
        ..alphaMode = _opacity < 1 ? AlphaMode.blend : AlphaMode.opaque
        ..baseColorFactor = vm.Vector4(1, 1, 1, _opacity);
    }
  }

  void _push() {
    for (int i = 0; i < _tubes.length; i++) {
      _tubes[i]
        ..updatePositions(mesh.tubes[i].positions)
        ..updateNormals(mesh.tubes[i].normals);
    }
    for (int s = 0; s < mesh.sphereCount; s++) {
      final double radius = mesh.sphereRadii[s];
      if (radius <= 0) {
        _spheres.setInstanceTransform(s, _hidden);
        continue;
      }
      _scratch
        ..setZero()
        ..setEntry(0, 0, radius)
        ..setEntry(1, 1, radius)
        ..setEntry(2, 2, radius)
        ..setEntry(3, 3, 1)
        ..setTranslationRaw(
          mesh.sphereCentres[3 * s],
          mesh.sphereCentres[3 * s + 1],
          mesh.sphereCentres[3 * s + 2],
        );
      _spheres
        ..setInstanceTransform(s, _scratch)
        ..setInstanceColor(
          s,
          _colour..setValues(
            mesh.sphereColours[4 * s],
            mesh.sphereColours[4 * s + 1],
            mesh.sphereColours[4 * s + 2],
            1,
          ),
        );
    }
    final vm.Vector3 from = vm.Vector3.zero();
    final vm.Vector3 to = vm.Vector3.zero();
    for (int r = 0; r < mesh.rodCount; r++) {
      final double radius = mesh.rodRadii[r];
      from.setValues(
        mesh.rodFrom[3 * r],
        mesh.rodFrom[3 * r + 1],
        mesh.rodFrom[3 * r + 2],
      );
      to.setValues(mesh.rodTo[3 * r], mesh.rodTo[3 * r + 1], mesh.rodTo[3 * r + 2]);
      final vm.Vector3 along = to - from;
      final double length = along.length;
      if (radius <= 0 || length <= 1e-9) {
        _rods.setInstanceTransform(r, _hidden);
        continue;
      }
      // The unit cylinder stands on Y, centred: turned onto the rod, and
      // stretched to its length.
      final vm.Quaternion turn = along.normalized().dot(_up) < -0.999999
          ? vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi)
          : vm.Quaternion.fromTwoVectors(_up, along.normalized());
      _scratch.setFromTranslationRotationScale(
        (from + to)..scale(0.5),
        turn,
        vm.Vector3(radius, length, radius),
      );
      _rods
        ..setInstanceTransform(r, _scratch)
        ..setInstanceColor(
          r,
          _colour..setValues(
            mesh.palette.bridge.$1,
            mesh.palette.bridge.$2,
            mesh.palette.bridge.$3,
            1,
          ),
        );
    }
  }
}
