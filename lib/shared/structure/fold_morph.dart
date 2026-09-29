import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../core/biology/amino_acids.dart';
import '../../core/catalog/protein_target.dart';
import '../../core/theme/anatomy_colors.dart';
import '../folding/fold_bonds.dart';
import '../folding/fold_mesh.dart';
import '../folding/fold_skin.dart';
import '../folding/fold_timeline.dart';
import 'structure_model.dart';
import 'structure_scene_view.dart';

/// Everything the fold's scene needs of the stored model to fold it: a copy
/// of each chain's mesh and of the bridges', bound to the chain.
final class FoldBinding {
  const FoldBinding(this.skin, this.bonds);

  final SkinBinding skin;

  /// Null for a model that draws no bridges.
  final BondsBinding? bonds;
}

/// The fold animation as nodes of the fold page's own scene.
///
/// Drawn in the scene, under the camera and the lights the model is drawn
/// with, and for the most part out of the model's own mesh: a copy of each
/// of its nodes, in that node's material ([structureMaterial]), carried by
/// the chain as it folds ([FoldSkin], [FoldBonds]). What the model does not
/// draw — the beads, and the residues the entry never placed — [FoldMesh]
/// says where it is. By the time the bridges have closed, the copies are the
/// stored model float for float, so when the page swaps the model back in,
/// no pixel changes.
final class FoldMorph {
  FoldMorph(FoldTimeline timeline, FoldPalette palette, FoldBinding binding)
    : mesh = FoldMesh(timeline, palette),
      skin = FoldSkin(binding.skin, timeline.geometry),
      bonds = binding.bonds == null
          ? null
          : FoldBonds(binding.bonds!, timeline.geometry) {
    for (final SkinChain chain in skin.chains) {
      final MeshGeometry geometry = MeshGeometry.fromArrays(
        positions: chain.positions,
        normals: chain.normals,
        indices: chain.binding.indices,
        storage: GeometryStorage.updatable,
      );
      _chains.add(geometry);
      node.add(
        Node(
          name: 'fold ${chain.binding.node}',
          mesh: Mesh(geometry, _material(palette, chain.binding.node)),
        ),
      );
    }
    final FoldBonds? rods = bonds;
    if (rods != null) {
      _bonds = MeshGeometry.fromArrays(
        positions: rods.positions,
        normals: rods.normals,
        indices: rods.binding.indices,
        storage: GeometryStorage.updatable,
      );
      node.add(
        Node(
          name: 'fold bonds',
          mesh: Mesh(_bonds!, structureMaterialOf(_linear(palette.bridge))),
        ),
      );
    }
    for (final FoldTube tube in mesh.tubes) {
      final MeshGeometry geometry = MeshGeometry.fromArrays(
        positions: tube.positions,
        normals: tube.normals,
        colors: tube.colours,
        indices: tube.indices,
        storage: GeometryStorage.updatable,
      );
      _tubes.add(geometry);
      node.add(Node(name: 'fold thread', mesh: Mesh(geometry, _surface)));
    }
    _spheres = InstancedMesh(
      geometry: SphereGeometry(radius: 1, segments: 24, rings: 16),
      material: _beads,
    );
    for (int s = 0; s < mesh.sphereCount; s++) {
      _spheres.addInstance(_hidden);
    }
    node.add(
      Node(name: 'fold beads')..addComponent(InstancedMeshComponent(_spheres)),
    );
    // Layers are per node, not inherited: the fold has a layer of its own,
    // which the page draws until the model takes over.
    node.layers = StructureSceneView.foldLayer;
    for (final Node child in node.children) {
      child.layers = StructureSceneView.foldLayer;
    }
    _push(force: true);
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
  final FoldSkin skin;
  final FoldBonds? bonds;

  /// Everything the fold draws, under one node.
  final Node node = Node(name: 'fold');

  final List<MeshGeometry> _chains = <MeshGeometry>[];
  MeshGeometry? _bonds;
  final List<MeshGeometry> _tubes = <MeshGeometry>[];
  late final InstancedMesh _spheres;

  // A base of one, so that the vertex and instance colours are the colour,
  // as the model's base colour is.
  final PhysicallyBasedMaterial _surface = structureMaterialOf(_one());
  final PhysicallyBasedMaterial _beads = structureMaterialOf(_one());

  static vm.Vector4 _one() => vm.Vector4(1, 1, 1, 1);

  static vm.Vector4 _linear(LinearColour colour) =>
      vm.Vector4(colour.$1, colour.$2, colour.$3, 1);

  /// The material the model gives node [name]: the same colour, so the
  /// copy shades exactly as the node it becomes.
  static PhysicallyBasedMaterial _material(FoldPalette palette, String name) =>
      structureMaterialOf(_linear(palette.chains[name] ?? palette.loose));

  static final vm.Matrix4 _hidden = vm.Matrix4.zero();
  final vm.Matrix4 _scratch = vm.Matrix4.zero();
  final vm.Vector4 _colour = vm.Vector4.zero();

  /// Moves the fold to [t], with loose residues moved on by [idle] seconds.
  void update(double t, {double idle = 0}) {
    mesh.update(t, idle: idle);
    skin.update(mesh.frame, mesh.backbone);
    bonds?.update(mesh.frame, mesh.backbone);
    _push();
  }

  void _push({bool force = false}) {
    for (int i = 0; i < _chains.length; i++) {
      final SkinChain chain = skin.chains[i];
      if (force || chain.changed) {
        _chains[i]
          ..updatePositions(chain.positions)
          ..updateNormals(chain.normals);
      }
    }
    final FoldBonds? rods = bonds;
    if (rods != null && (force || rods.changed)) {
      _bonds!
        ..updatePositions(rods.positions)
        ..updateNormals(rods.normals);
    }
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
  }
}
