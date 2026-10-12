// A fold the backend has baked for a protein built on demand, held to what the
// walk's fold page will do with it, before any of it is stored.
//
// Opt-in, like the live checks: it is skipped unless FOLD_BUNDLE names a
// directory, so the default `flutter test` stays offline and deterministic.
//
//   FOLD_BUNDLE=/path/to/bundle flutter test test/fold_bundle_check.dart
//
// The backend's worker runs it on every model it bakes from an experimental
// entry (`pipeline/structure/experimental.py`). The directory holds:
//
// - `row.json`: the protein's row as the service will serve it (its slug,
//   gene and accession, the model's `chains` with their tints);
// - `model.glb` and `model.fsceneb`: the model, and the scene compiled from it;
// - `folding.json`: its `folding` track.
//
// What is held is what `fold_skin_test.dart` holds the twenty to, on this one
// model, with the mesh read out of the compiled scene itself, which is the
// one the phone loads: the scene is the model as the compiler bakes it; the
// track parses; every chain's mesh binds to its chain, ring by ring; the
// bridges bind; once the bridges close the fold is the stored mesh, float for
// float; and nothing jumps between two frames.
//
// How it ended is written to `check.json` beside them, with what it measured,
// and that file is what the backend reads, not this process's exit status:
//
// - `"verdict": "ok"`: every step held.
// - `"verdict": "unsuitable"`: a rule the fold must hold failed on this entry
//   (`rule` below). `failed` names the step and says how. The backend goes on
//   to the next candidate.
// - `"verdict": "fault"`: the bundle is not one the app can read, or this
//   check broke (`sound` below, and anything unforeseen). That is no verdict
//   on the entry, and the backend tries again.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/fscene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/shared/folding/fold_backbone.dart';
import 'package:helixpeek/shared/folding/fold_bonds.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_mesh.dart';
import 'package:helixpeek/shared/folding/fold_skin.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';

import 'shared/folding/stored_models.dart';

/// The scene's vertex buffer, as flutter_scene 0.23.0's importer lays it out:
/// one stream after another (positions, normals, two texture coordinates,
/// colours, tangents), 72 bytes a vertex.
const String _layout = 'unskinned_soa_uv1_tangent';
const int _vertexBytes = 72;

/// Each mesh of a compiled scene, by its node's name, as the scene holds it.
List<SkinMesh> meshesOfScene(Uint8List bytes) {
  final SceneDocument document = readFsceneb(bytes);
  final List<SkinMesh> meshes = <SkinMesh>[];
  for (final NodeSpec node in document.nodes.values) {
    for (final ComponentSpec component in node.components) {
      if (component.type != 'mesh') {
        continue;
      }
      final Object? reference = component.properties['geometry'];
      if (reference is! ResourceRefValue) {
        throw FormatException('The ${node.name} mesh names no geometry');
      }
      final Object? resource = document.resource(reference.id);
      if (resource is! GeometryResource ||
          resource.topology != 'triangle' ||
          resource.legacyWinding) {
        throw FormatException(
          'The ${node.name} geometry is not a triangle list',
        );
      }
      final PayloadSpec vertices = document.payload(resource.vertices!)!;
      final PayloadSpec indices = document.payload(resource.indices!)!;
      if (vertices.layout != _layout || indices.format != 'uint32') {
        throw FormatException(
          'The ${node.name} mesh is laid out as ${vertices.layout}, '
          'indexed as ${indices.format}',
        );
      }
      final Uint8List buffer = vertices.bytes!;
      final int count = buffer.lengthInBytes ~/ _vertexBytes;
      final ByteData data = ByteData.sublistView(buffer);
      final Float32List positions = Float32List(3 * count);
      final Float32List normals = Float32List(3 * count);
      for (int i = 0; i < 3 * count; i++) {
        positions[i] = data.getFloat32(4 * i, Endian.little);
        normals[i] = data.getFloat32(12 * count + 4 * i, Endian.little);
      }
      final ByteData corners = ByteData.sublistView(indices.bytes!);
      meshes.add(
        SkinMesh(
          node: node.name,
          positions: positions,
          normals: normals,
          indices: Uint32List.fromList(<int>[
            for (int i = 0; i < corners.lengthInBytes ~/ 4; i++)
              corners.getUint32(4 * i, Endian.little),
          ]),
        ),
      );
    }
  }
  return meshes;
}

/// Where the backbone runs [s] residues along run [run] of [chain] now: the
/// same reading `fold_skin_test.dart` takes.
List<double> _backboneAt(
  FoldBackbone backbone,
  SkinChainBinding chain,
  int run,
  double s,
) {
  final int start = chain.runStarts[run];
  final int m = chain.runEnds[run] - start;
  final List<double> point = <double>[0, 0, 0];
  final List<double> direction = <double>[0, 0, 0];
  final int k = math.min(s.floor(), m - 2);
  catmullRom(backbone.centres, start, m, k, s - k, point, direction);
  return point;
}

LinearColour _grey(String letter) => (0.5, 0.5, 0.5);

void main() {
  final String bundle = Platform.environment['FOLD_BUNDLE'] ?? '';
  final bool on = bundle.isNotEmpty;
  const FoldPalette palette = FoldPalette(
    chains: <String, LinearColour>{},
    loose: (0.3, 0.3, 0.3),
    bridge: (0.8, 0.7, 0.4),
    property: _grey,
  );

  late ProteinTarget target;
  late FoldGeometry geometry;
  late List<SkinMesh> scene;
  late SkinBinding skin;
  BondsBinding? bonds;
  final Map<String, Object?> measured = <String, Object?>{};

  Uint8List read(String name) => File('$bundle/$name').readAsBytesSync();

  // The step that failed first. What follows it reads what it would have
  // made, so it is not run.
  String? failed;
  int declared = 0;
  int held = 0;

  void fails(String step, String verdict, Object detail) {
    failed = step;
    measured['verdict'] = verdict;
    measured['failed'] = <String, String>{'step': step, 'detail': '$detail'};
  }

  /// One step. Where [rule], a failed expectation, or a model the binder
  /// refuses in its own words, is a verdict on the entry; anything else, and
  /// anything at all where not, is a fault.
  void step(String name, {required bool rule, required void Function() body}) {
    declared++;
    test(name, () {
      if (failed != null) {
        markTestSkipped('Not run: "$failed" failed first.');
        return;
      }
      try {
        body();
        held++;
      } on TestFailure catch (failure) {
        fails(name, rule ? 'unsuitable' : 'fault', failure.message ?? '');
        rethrow;
      } on FormatException catch (refusal) {
        fails(name, rule ? 'unsuitable' : 'fault', refusal.message);
        rethrow;
      } on Object catch (error) {
        fails(name, 'fault', error);
        rethrow;
      }
    });
  }

  /// A rule the fold must hold for this entry to be animated.
  void rule(String name, void Function() body) =>
      step(name, rule: true, body: body);

  /// What is so of every bundle the backend makes, whatever the entry.
  void sound(String name, void Function() body) =>
      step(name, rule: false, body: body);

  setUpAll(() {
    if (!on) {
      return;
    }
    try {
      target = ProteinTarget.fromJson(
        jsonDecode(utf8.decode(read('row.json'))) as Map<String, dynamic>,
      );
      scene = meshesOfScene(read('model.fsceneb'));
    } on Object catch (error) {
      fails('(reading the bundle)', 'fault', error);
      rethrow;
    }
  });

  tearDownAll(() {
    if (on) {
      measured['steps'] = held;
      if (failed == null && held != declared) {
        // A step that was filtered out or never reached has held nothing.
        fails(
          '(the whole check)',
          'fault',
          'only $held of $declared steps ran',
        );
      }
      measured.putIfAbsent('verdict', () => 'ok');
      File('$bundle/check.json').writeAsStringSync('${jsonEncode(measured)}\n');
    }
  });

  group('a fold baked for a protein built on demand', () {
    sound('its scene is its model, as the compiler bakes it', () {
      final List<SkinMesh> model = meshesOfGlb(read('model.glb'));
      expect(
        <String>[for (final SkinMesh mesh in scene) mesh.node],
        <String>[for (final SkinMesh mesh in model) mesh.node],
      );
      // And every node the row paints, no more and no fewer.
      expect(
        <String>{for (final SkinMesh mesh in scene) mesh.node},
        <String>{for (final StructureChain chain in target.chains) chain.node},
      );
      int vertices = 0;
      for (int m = 0; m < scene.length; m++) {
        expect(scene[m].positions, model[m].positions, reason: scene[m].node);
        expect(scene[m].normals, model[m].normals, reason: scene[m].node);
        expect(scene[m].indices, model[m].indices, reason: scene[m].node);
        vertices += scene[m].positions.length ~/ 3;
      }
      measured['vertices'] = vertices;
    });

    sound('its track is one the fold page parses, for its own chains', () {
      final FoldingTrack track = FoldingTrack.fromJson(
        jsonDecode(utf8.decode(read('folding.json'))) as Map<String, dynamic>,
        target,
      );
      geometry = FoldGeometry.of(track);
      expect(
        <String>[for (final FoldChain chain in track.chains) chain.node],
        <String>[
          for (final StructureChain chain in target.chains)
            if (chain.node != 'bonds') chain.node,
        ],
      );
      // The page binds bridges exactly where the model draws them.
      expect(
        geometry.bridges.isNotEmpty,
        scene.any((SkinMesh mesh) => mesh.node == 'bonds'),
      );
      measured['residues'] = geometry.length;
      measured['bridges'] = geometry.bridges.length;
    });

    rule('every ring of its model lies on its own stretch of chain', () {
      final Stopwatch watch = Stopwatch()..start();
      skin = SkinBinding.bind(geometry, scene);
      measured['bind_ms'] = watch.elapsedMilliseconds;
      int rings = 0;
      double nudge = 0;
      for (final SkinChainBinding chain in skin.chains) {
        rings += chain.ringCount;
        // The rings run in order along the chain; keeping them so moves
        // none as far as a quarter of a residue. (The twenty's move under
        // 0.05, their helices being the depositors'. A helix as DSSP assigns
        // it can stop a residue short of a gap, and the few rings PyMOL
        // stacks where it ends are pooled: 0.13 of a residue at most, over
        // the 43 entries the dry run of 2026-10-12 baked.)
        nudge = math.max(nudge, chain.largestNudge);
        expect(chain.largestNudge, lessThan(0.25), reason: chain.node);
        // The copy draws the stored triangles, corner for corner.
        final SkinMesh stored = scene.firstWhere(
          (SkinMesh mesh) => mesh.node == chain.node,
        );
        expect(chain.indices.length, stored.indices.length, reason: chain.node);
        for (int k = 0; k < stored.indices.length; k++) {
          final int from = stored.indices[k];
          final int to = chain.indices[k];
          for (int a = 0; a < 3; a++) {
            expect(chain.positions[3 * to + a], stored.positions[3 * from + a]);
            expect(chain.normals[3 * to + a], stored.normals[3 * from + a]);
          }
        }
        // Every placed residue has rings along it.
        for (int run = 0; run < chain.runStarts.length; run++) {
          final int m = chain.runEnds[run] - chain.runStarts[run];
          final List<double> at = <double>[
            for (int r = 0; r < chain.ringCount; r++)
              if (chain.ringRun[r] == run) chain.ringAt[r],
          ]..sort();
          expect(at, isNotEmpty, reason: '${chain.node} run $run');
          final List<double> stops = <double>[0, ...at, m - 1.0];
          for (int k = 1; k < stops.length; k++) {
            expect(
              stops[k] - stops[k - 1],
              lessThan(1.5),
              reason: '${chain.node} run $run near ${stops[k]}',
            );
          }
        }
      }
      measured['rings'] = rings;
      measured['largest_nudge'] = nudge;
    });

    rule('its bridges are the model’s own rods and joints', () {
      if (geometry.bridges.isEmpty) {
        return;
      }
      final SkinMesh stored = scene.firstWhere(
        (SkinMesh mesh) => mesh.node == 'bonds',
      );
      final BondsBinding binding = bonds = BondsBinding.bind(geometry, stored);
      expect(binding.stored, stored.positions.length ~/ 3);
      for (int bridge = 0; bridge < geometry.bridges.length; bridge++) {
        final Set<int> pieces = <int>{
          for (int v = 0; v < binding.stored; v++)
            if (binding.vertexBridge[v] == bridge)
              10 * binding.vertexHalf[v] + binding.vertexPiece[v],
        };
        expect(pieces, <int>{
          0,
          1,
          2,
          3,
          4,
          10,
          11,
          13,
          14,
        }, reason: 'bridge $bridge');
      }
    });

    rule(
      'once the bridges close, the fold is the stored model, float for float',
      () {
        final FoldMesh mesh = FoldMesh(FoldTimeline(geometry), palette);
        final FoldSkin copy = FoldSkin(skin, geometry);
        final FoldBonds? rods = bonds == null
            ? null
            : FoldBonds(bonds!, geometry);
        for (final double t in <double>[
          0.86,
          FoldTimeline.bridgesClosedAt,
          0.95,
          1,
        ]) {
          mesh.update(t, idle: 3.7);
          copy.update(mesh.frame, mesh.backbone);
          rods?.update(mesh.frame, mesh.backbone);
          if (t < FoldTimeline.bridgesClosedAt) {
            continue;
          }
          for (final SkinChain chain in copy.chains) {
            final SkinChainBinding b = chain.binding;
            for (int v = 0; v < b.vertexCount; v++) {
              // The marks across a gap grow in until the very end.
              if (b.ringPiece[b.vertexRing[v]] >= 0 && t < 1) {
                continue;
              }
              for (int a = 0; a < 3; a++) {
                expect(
                  chain.positions[3 * v + a],
                  b.positions[3 * v + a],
                  reason: '${b.node} $v at $t',
                );
                expect(
                  chain.normals[3 * v + a],
                  b.normals[3 * v + a],
                  reason: '${b.node} $v at $t',
                );
              }
            }
          }
          if (rods != null) {
            final BondsBinding b = rods.binding;
            for (int i = 0; i < 3 * b.stored; i++) {
              expect(rods.positions[i], b.positions[i], reason: 'bonds at $t');
              expect(rods.normals[i], b.normals[i], reason: 'bonds at $t');
            }
          }
        }
        expect(copy.chains.every((SkinChain chain) => chain.isStored), isTrue);
      },
    );

    rule('nothing jumps from one frame to the next', () {
      // 480 frames over the fold, as `fold_skin_test.dart` walks the twenty: a
      // vertex moves with the backbone under it, and a ring turned right
      // round in one frame would move its edge by its whole width.
      final FoldMesh mesh = FoldMesh(FoldTimeline(geometry), palette);
      final FoldSkin copy = FoldSkin(skin, geometry);
      final FoldBonds? rods = bonds == null
          ? null
          : FoldBonds(bonds!, geometry);
      final List<Float32List> before = <Float32List>[];
      final List<Float64List> under = <Float64List>[];
      double worst = 0;
      int slowest = 0;
      final Stopwatch whole = Stopwatch()..start();
      for (int frame = 0; frame <= 480; frame++) {
        final Stopwatch one = Stopwatch()..start();
        mesh.update(frame / 480);
        copy.update(mesh.frame, mesh.backbone);
        rods?.update(mesh.frame, mesh.backbone);
        slowest = math.max(slowest, one.elapsedMicroseconds);
        for (int c = 0; c < copy.chains.length; c++) {
          final SkinChain chain = copy.chains[c];
          final SkinChainBinding b = chain.binding;
          final Float64List points = Float64List(3 * b.ringCount);
          for (int r = 0; r < b.ringCount; r++) {
            if (b.ringRun[r] >= 0) {
              points.setRange(
                3 * r,
                3 * r + 3,
                _backboneAt(mesh.backbone, b, b.ringRun[r], b.ringAt[r]),
              );
            }
          }
          if (frame > 0) {
            for (int v = 0; v < b.vertexCount; v++) {
              final int r = b.vertexRing[v];
              if (b.ringRun[r] < 0) {
                continue;
              }
              double d = 0;
              for (int a = 0; a < 3; a++) {
                final double moved =
                    chain.positions[3 * v + a] - before[c][3 * v + a];
                final double carried = points[3 * r + a] - under[c][3 * r + a];
                d += (moved - carried) * (moved - carried);
              }
              worst = math.max(worst, math.sqrt(d) / geometry.unit);
            }
            before[c] = Float32List.fromList(chain.positions);
            under[c] = points;
          } else {
            before.add(Float32List.fromList(chain.positions));
            under.add(points);
          }
        }
      }
      measured['frames_ms'] = whole.elapsedMilliseconds;
      measured['slowest_frame_us'] = slowest;
      measured['largest_step'] = worst;
      expect(worst, lessThan(1.1));
    });
  }, skip: on ? false : 'Set FOLD_BUNDLE to a baked bundle to run this check.');
}
