import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/folding/fold_backbone.dart';
import 'package:helixpeek/shared/folding/fold_bonds.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_mesh.dart';
import 'package:helixpeek/shared/folding/fold_skin.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';

import 'folding_fixtures.dart';
import 'stored_models.dart';

/// Every protein in the catalog: each model has to bind, not a sample.
const List<String> _slugs = <String>[
  'amylase',
  'app',
  'cftr',
  'dystrophin',
  'erythropoietin',
  'glucagon',
  'hemoglobin',
  'insulin',
  'leptin',
  'lysozyme',
  'myoglobin',
  'oxytocin',
  'p53',
  'prion',
  'relaxin',
  'sod1',
  'somatotropin',
  'tnf',
  'ubiquitin',
  'vasopressin',
];

final Map<String, SkinBinding> _skins = <String, SkinBinding>{};

SkinBinding skinOf(String slug) => _skins.putIfAbsent(
  slug,
  () => SkinBinding.bind(geometryOf(target(slug)), storedMeshes(slug)),
);

SkinMesh storedOf(String slug, String node) =>
    storedMeshes(slug).firstWhere((SkinMesh mesh) => mesh.node == node);

/// Where the backbone runs [s] residues along run [run] of [chain] now.
List<double> backboneAt(
  FoldBackbone backbone,
  SkinChainBinding chain,
  int run,
  double s, {
  List<double>? tangent,
}) {
  final int start = chain.runStarts[run];
  final int m = chain.runEnds[run] - start;
  final List<double> point = <double>[0, 0, 0];
  final List<double> direction = tangent ?? <double>[0, 0, 0];
  final int k = math.min(s.floor(), m - 2);
  catmullRom(backbone.centres, start, m, k, s - k, point, direction);
  final double l = math.sqrt(
    direction[0] * direction[0] +
        direction[1] * direction[1] +
        direction[2] * direction[2],
  );
  for (int a = 0; a < 3; a++) {
    direction[a] /= l;
  }
  return point;
}

void main() {
  const FoldPalette palette = FoldPalette(
    chains: <String, LinearColour>{
      'chainA': (0.1, 0.5, 0.3),
      'chainB': (0.1, 0.3, 0.1),
      'bonds': (0.8, 0.7, 0.4),
    },
    loose: (0.3, 0.3, 0.3),
    bridge: (0.8, 0.7, 0.4),
    property: _grey,
  );

  group('the model’s chains, bound to the chain', () {
    test('every ring of every model lies on its own stretch of chain', () {
      for (final String slug in _slugs) {
        for (final SkinChainBinding chain in skinOf(slug).chains) {
          final int marks = chain.ringRun.where((int run) => run < 0).length;
          // Only somatotropin's model draws across a gap: PyMOL's dashed
          // line over the three residues its entry never placed.
          expect(marks > 0, slug == 'somatotropin', reason: slug);
          // The rings run in order along the chain; keeping them so moves
          // none by more than a fraction of a residue.
          expect(chain.largestNudge, lessThan(0.05), reason: slug);
        }
      }
      final SkinChainBinding somatotropin = skinOf('somatotropin').chains.single;
      expect(somatotropin.pieceCentres.length ~/ 3, 3);
    });

    test('the copy draws the stored triangles, corner for corner', () {
      for (final String slug in _slugs) {
        for (final SkinChainBinding chain in skinOf(slug).chains) {
          final SkinMesh stored = storedOf(slug, chain.node);
          expect(chain.indices.length, stored.indices.length, reason: slug);
          for (int k = 0; k < stored.indices.length; k++) {
            final int from = stored.indices[k];
            final int to = chain.indices[k];
            for (int a = 0; a < 3; a++) {
              expect(chain.positions[3 * to + a], stored.positions[3 * from + a]);
              expect(chain.normals[3 * to + a], stored.normals[3 * from + a]);
            }
          }
        }
      }
    });

    test('every placed residue has rings along it', () {
      for (final String slug in _slugs) {
        for (final SkinChainBinding chain in skinOf(slug).chains) {
          for (int run = 0; run < chain.runStarts.length; run++) {
            final int m = chain.runEnds[run] - chain.runStarts[run];
            final List<double> at = <double>[
              for (int r = 0; r < chain.ringCount; r++)
                if (chain.ringRun[r] == run) chain.ringAt[r],
            ]..sort();
            expect(at, isNotEmpty, reason: '$slug run $run');
            final List<double> stops = <double>[0, ...at, m - 1.0];
            for (int k = 1; k < stops.length; k++) {
              // CFTR's model has one ring a residue; the rest more.
              expect(
                stops[k] - stops[k - 1],
                lessThan(1.5),
                reason: '$slug run $run near ${stops[k]}',
              );
            }
          }
        }
      }
    });

    test('once the bridges close, the copy is the stored mesh, float for float', () {
      for (final String slug in _slugs) {
        final FoldGeometry g = geometryOf(target(slug));
        final FoldMesh mesh = FoldMesh(FoldTimeline(g), palette);
        final FoldSkin skin = FoldSkin(skinOf(slug), g);
        for (final double t in <double>[FoldTimeline.bridgesClosedAt, 0.95, 1]) {
          mesh.update(t, idle: 3.7);
          skin.update(mesh.frame, mesh.backbone);
          for (final SkinChain chain in skin.chains) {
            final SkinChainBinding b = chain.binding;
            for (int v = 0; v < b.vertexCount; v++) {
              // The marks across a gap grow in until the very end.
              if (b.ringPiece[b.vertexRing[v]] >= 0 && t < 1) {
                continue;
              }
              for (int a = 0; a < 3; a++) {
                expect(chain.positions[3 * v + a], b.positions[3 * v + a],
                    reason: '$slug ${b.node} $v at $t');
                expect(chain.normals[3 * v + a], b.normals[3 * v + a],
                    reason: '$slug ${b.node} $v at $t');
              }
            }
          }
          expect(
            skin.chains.every((SkinChain chain) => chain.isStored),
            t == 1 || slug != 'somatotropin',
            reason: '$slug at $t',
          );
        }
      }
    });

    test('the unfolded chain is a thread round the backbone', () {
      for (final String slug in <String>['insulin', 'lysozyme', 'tnf', 'cftr', 'vasopressin']) {
        final FoldGeometry g = geometryOf(target(slug));
        final FoldMesh mesh = FoldMesh(FoldTimeline(g), palette)..update(0);
        final FoldSkin skin = FoldSkin(skinOf(slug), g)
          ..update(mesh.frame, mesh.backbone);
        final double thread = FoldMesh.threadRadius * g.unit;
        for (final SkinChain chain in skin.chains) {
          final SkinChainBinding b = chain.binding;
          for (int v = 0; v < b.vertexCount; v++) {
            final int r = b.vertexRing[v];
            if (b.ringRun[r] < 0) {
              continue;
            }
            final List<double> tangent = <double>[0, 0, 0];
            final List<double> centre = backboneAt(
              mesh.backbone,
              b,
              b.ringRun[r],
              b.ringAt[r],
              tangent: tangent,
            );
            final List<double> d = <double>[
              for (int a = 0; a < 3; a++) chain.positions[3 * v + a] - centre[a],
            ];
            final double along = d[0] * tangent[0] + d[1] * tangent[1] + d[2] * tangent[2];
            final double off = math.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]);
            // Square to the backbone, and no further out than a thread: a
            // strand's four corners sit on a square the thread's width.
            expect(along.abs(), lessThan(1e-6), reason: '$slug $v');
            expect(off, lessThanOrEqualTo(math.sqrt2 * thread + 1e-6), reason: '$slug $v');
          }
        }
      }
    });

    test('the marks across a gap wait for the bridges, then grow in place', () {
      final FoldGeometry g = geometryOf(target('somatotropin'));
      final FoldMesh mesh = FoldMesh(FoldTimeline(g), palette);
      final FoldSkin skin = FoldSkin(skinOf('somatotropin'), g);
      final SkinChain chain = skin.chains.single;
      final SkinChainBinding b = chain.binding;
      double spread(int piece) {
        double furthest = 0;
        for (int v = 0; v < b.vertexCount; v++) {
          if (b.ringPiece[b.vertexRing[v]] != piece) {
            continue;
          }
          double d = 0;
          for (int a = 0; a < 3; a++) {
            d += math.pow(chain.positions[3 * v + a] - b.pieceCentres[3 * piece + a], 2);
          }
          furthest = math.max(furthest, math.sqrt(d));
        }
        return furthest;
      }

      for (final double t in <double>[0, 0.5, FoldTimeline.bridgesClosedAt]) {
        mesh.update(t);
        skin.update(mesh.frame, mesh.backbone);
        for (int piece = 0; piece < 3; piece++) {
          expect(spread(piece), lessThan(1e-7), reason: 'at $t');
        }
      }
      mesh.update(0.95);
      skin.update(mesh.frame, mesh.backbone);
      final List<double> part = <double>[for (int p = 0; p < 3; p++) spread(p)];
      mesh.update(1);
      skin.update(mesh.frame, mesh.backbone);
      for (int piece = 0; piece < 3; piece++) {
        expect(part[piece], greaterThan(0));
        expect(part[piece], lessThan(spread(piece)));
      }
    });

    test('nothing jumps from one frame to the next', () {
      // At 480 frames over the fold, a vertex moves with the backbone under
      // it, and turns with the backbone's direction; a ring turned right
      // round in one frame would move its edge by its whole width.
      for (final String slug in <String>['insulin', 'lysozyme', 'hemoglobin', 'somatotropin', 'amylase', 'cftr']) {
        final FoldGeometry g = geometryOf(target(slug));
        final FoldMesh mesh = FoldMesh(FoldTimeline(g), palette);
        final FoldSkin skin = FoldSkin(skinOf(slug), g);
        final List<Float32List> before = <Float32List>[];
        final List<Float64List> under = <Float64List>[];
        double worst = 0;
        for (int frame = 0; frame <= 480; frame++) {
          mesh.update(frame / 480);
          skin.update(mesh.frame, mesh.backbone);
          for (int c = 0; c < skin.chains.length; c++) {
            final SkinChain chain = skin.chains[c];
            final SkinChainBinding b = chain.binding;
            final Float64List points = Float64List(3 * b.ringCount);
            for (int r = 0; r < b.ringCount; r++) {
              if (b.ringRun[r] >= 0) {
                points.setRange(3 * r, 3 * r + 3, backboneAt(mesh.backbone, b, b.ringRun[r], b.ringAt[r]));
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
                  final double moved = chain.positions[3 * v + a] - before[c][3 * v + a];
                  final double carried = points[3 * r + a] - under[c][3 * r + a];
                  d += (moved - carried) * (moved - carried);
                }
                worst = math.max(worst, math.sqrt(d) / g.unit);
              }
              before[c] = Float32List.fromList(chain.positions);
              under[c] = points;
            } else {
              before.add(Float32List.fromList(chain.positions));
              under.add(points);
            }
          }
        }
        expect(worst, lessThan(1.1), reason: slug);
      }
    });

    test('the same moment is the same copy', () {
      final FoldGeometry g = geometryOf(target('lysozyme'));
      final FoldMesh mesh = FoldMesh(FoldTimeline(g), palette)..update(0.6);
      final FoldSkin one = FoldSkin(skinOf('lysozyme'), g)
        ..update(mesh.frame, mesh.backbone);
      final FoldSkin two = FoldSkin(skinOf('lysozyme'), g)
        ..update(mesh.frame, mesh.backbone);
      expect(two.chains.single.positions, one.chains.single.positions);
      expect(two.chains.single.normals, one.chains.single.normals);
    });
  });

  group('the backbone', () {
    test('the ribbon follows its held cysteine all the way through closure', () {
      final FoldGeometry g = geometryOf(target('insulin'));
      final FoldTimeline timeline = FoldTimeline(g);
      final FoldBackbone backbone = FoldBackbone(g);
      int checked = 0;
      for (final double t in <double>[0.8, 0.86, 0.89, 0.91, 1]) {
        final FoldFrame frame = timeline.frameAt(t);
        backbone.update(frame);
        for (int i = 0; i < g.length; i++) {
          final ModelPoint? at = g.drawn[i].ribbonAt;
          if (at == null) {
            continue;
          }
          final List<double> rest = <double>[at.$1, at.$2, -at.$3];
          for (int a = 0; a < 3; a++) {
            final double offset =
                (frame.positions[3 * i + a] - g.folded[3 * i + a]) *
                (a == 2 ? -1 : 1);
            expect(
              backbone.centres[3 * i + a],
              closeTo(rest[a] + offset, 1e-12),
              reason: '$i axis $a at $t',
            );
            if (offset.abs() > 1e-5) {
              checked++;
            }
          }
        }
      }
      expect(checked, greaterThan(0));
    });
  });

  group('the model’s bridges', () {
    final List<String> bridged = <String>[
      for (final String slug in _slugs)
        if (geometryOf(target(slug)).bridges.isNotEmpty) slug,
    ];

    test('each bridge is the model’s own five rods and four joints', () {
      expect(bridged, hasLength(13));
      for (final String slug in bridged) {
        final FoldGeometry g = geometryOf(target(slug));
        final SkinMesh stored = storedOf(slug, 'bonds');
        final BondsBinding b = BondsBinding.bind(g, stored);
        expect(b.stored, stored.positions.length ~/ 3, reason: slug);
        for (int k = 0; k < stored.indices.length; k++) {
          expect(b.indices[k], stored.indices[k]);
        }
        for (int bridge = 0; bridge < g.bridges.length; bridge++) {
          final Set<int> pieces = <int>{
            for (int v = 0; v < b.stored; v++)
              if (b.vertexBridge[v] == bridge) 10 * b.vertexHalf[v] + b.vertexPiece[v],
          };
          // Each half: its rods to CB, to SG and to the middle, and its
          // joints at CB and SG; the second half's middle rod is the copy.
          expect(pieces, <int>{0, 1, 2, 3, 4, 10, 11, 13, 14}, reason: '$slug $bridge');
        }
      }
    });

    test('open, a bridge draws nothing', () {
      for (final String slug in bridged) {
        final FoldGeometry g = geometryOf(target(slug));
        final FoldBonds bonds = FoldBonds(BondsBinding.bind(g, storedOf(slug, 'bonds')), g);
        final FoldMesh mesh = FoldMesh(FoldTimeline(g), palette)..update(0.8);
        bonds.update(mesh.frame, mesh.backbone);
        expect(_largestTriangle(bonds.positions, bonds.binding.indices), 0, reason: slug);
      }
    });

    test('closed, the bridges are the stored node, float for float', () {
      for (final String slug in bridged) {
        final FoldGeometry g = geometryOf(target(slug));
        final BondsBinding binding = BondsBinding.bind(g, storedOf(slug, 'bonds'));
        final FoldBonds bonds = FoldBonds(binding, g);
        final FoldMesh mesh = FoldMesh(FoldTimeline(g), palette);
        for (final double t in <double>[0.86, FoldTimeline.bridgesClosedAt, 1]) {
          mesh.update(t);
          bonds.update(mesh.frame, mesh.backbone);
        }
        for (int i = 0; i < 3 * binding.stored; i++) {
          expect(bonds.positions[i], binding.positions[i], reason: slug);
          expect(bonds.normals[i], binding.normals[i], reason: slug);
        }
        // The second copies of the middle rods are gone.
        final Uint32List copies = Uint32List.sublistView(
          binding.indices,
          storedOf(slug, 'bonds').indices.length,
        );
        expect(_largestTriangle(bonds.positions, copies), 0, reason: slug);
      }
    });

    test('each half grows from its own CA, along its own atoms', () {
      final FoldGeometry g = geometryOf(target('insulin'));
      final BondsBinding binding = BondsBinding.bind(g, storedOf('insulin', 'bonds'));
      final FoldBonds bonds = FoldBonds(binding, g);
      final FoldTimeline timeline = FoldTimeline(g);
      final FoldBackbone backbone = FoldBackbone(g);
      final double rod = g.track.cartoon.rodRadius * g.unit;
      for (final double t in <double>[0.845, 0.86, 0.88, 0.9]) {
        final FoldFrame frame = timeline.frameAt(t);
        backbone.update(frame);
        bonds.update(frame, backbone);
        for (int v = 0; v < binding.vertexCount; v++) {
          final int bridge = binding.vertexBridge[v];
          final int half = binding.vertexHalf[v];
          final (int i, int j) = g.bridges[bridge];
          final int residue = half == 0 ? i : j;
          // Every vertex lies within a rod's radius of the half's atoms,
          // carried with its CA.
          final List<List<double>> atoms = <List<double>>[
            for (final int k in half == 0 ? <int>[0, 1, 2, 3] : <int>[5, 4, 3, 2])
              <double>[
                for (int a = 0; a < 3; a++)
                  binding.paths[18 * bridge + 3 * k + a] +
                      backbone.native[3 * residue + a] -
                      binding.paths[18 * bridge + 3 * (half == 0 ? 0 : 5) + a],
              ],
          ];
          double nearest = double.infinity;
          for (int s = 0; s < 3; s++) {
            nearest = math.min(nearest, _toSegment(bonds.positions, v, atoms[s], atoms[s + 1]));
          }
          expect(nearest, lessThanOrEqualTo(rod * 1.01 + 1e-6), reason: 'vertex $v at $t');
        }
      }
    });
  });
}

double _toSegment(Float32List p, int v, List<double> a, List<double> b) {
  double ab = 0;
  double ap = 0;
  for (int k = 0; k < 3; k++) {
    ab += (b[k] - a[k]) * (b[k] - a[k]);
    ap += (p[3 * v + k] - a[k]) * (b[k] - a[k]);
  }
  final double u = ab == 0 ? 0 : (ap / ab).clamp(0.0, 1.0);
  double d = 0;
  for (int k = 0; k < 3; k++) {
    final double on = a[k] + (b[k] - a[k]) * u;
    d += (p[3 * v + k] - on) * (p[3 * v + k] - on);
  }
  return math.sqrt(d);
}

/// The largest triangle of [indices] over [positions], by area.
double _largestTriangle(Float32List positions, Uint32List indices) {
  double largest = 0;
  for (int k = 0; k + 2 < indices.length; k += 3) {
    final List<double> e1 = <double>[
      for (int a = 0; a < 3; a++)
        positions[3 * indices[k + 1] + a] - positions[3 * indices[k] + a],
    ];
    final List<double> e2 = <double>[
      for (int a = 0; a < 3; a++)
        positions[3 * indices[k + 2] + a] - positions[3 * indices[k] + a],
    ];
    final double x = e1[1] * e2[2] - e1[2] * e2[1];
    final double y = e1[2] * e2[0] - e1[0] * e2[2];
    final double z = e1[0] * e2[1] - e1[1] * e2[0];
    largest = math.max(largest, math.sqrt(x * x + y * y + z * z) / 2);
  }
  return largest;
}

LinearColour _grey(String letter) => (0.5, 0.5, 0.5);
