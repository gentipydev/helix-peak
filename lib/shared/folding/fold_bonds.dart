import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'fold_backbone.dart';
import 'fold_geometry.dart';
import 'fold_skin.dart';
import 'fold_timeline.dart';
import 'folding_track.dart';

/// The model's `bonds` node taken apart into each bridge's rods and joints.
///
/// The structure bake builds each bridge as five rods, CA to CB to SG to SG to
/// CB to CA, and a joint at each of the four bends, from the entry's own
/// atoms: the same atoms the `folding` track carries. So every piece of the
/// node is found by where it is, and none by its place in the file.
@immutable
final class BondsBinding {
  const BondsBinding._({
    required this.positions,
    required this.normals,
    required this.indices,
    required this.stored,
    required this.vertexBridge,
    required this.vertexHalf,
    required this.vertexPiece,
    required this.vertexFar,
    required this.rimNormals,
    required this.paths,
  });

  /// The node's vertices and triangles, then a second copy of each bridge's
  /// middle rod: the two halves of a bridge grow towards each other along it.
  final Float32List positions;
  final Float32List normals;
  final Uint32List indices;

  /// How many of [positions]' vertices are the node's own; the copies follow.
  final int stored;

  /// Each vertex's bridge, in [FoldGeometry.bridges]' order, and the half it
  /// grows with: 0 from the first cysteine's CA, 1 from the second's.
  final Int32List vertexBridge;
  final Int32List vertexHalf;

  /// Each vertex's piece of its half: 0 the rod from CA to CB, 1 from CB to
  /// SG, 2 from SG to the middle of the S–S bond, 3 the joint at CB, 4 the
  /// joint at SG.
  final Int32List vertexPiece;

  /// Whether a rod's vertex is at the end the rod grows towards.
  final Uint8List vertexFar;

  /// For the growing end of a middle rod, the normal the whole rod has at
  /// the middle, three a vertex: the growing ends turn to it as they meet,
  /// so that the two halves shade as the one rod they become.
  final Float64List rimNormals;

  /// Each bridge's atoms, six points in the scene's frame.
  final Float64List paths;

  int get vertexCount => positions.length ~/ 3;

  /// Takes [mesh] apart into the bridges of [geometry]. Throws if a piece is
  /// not one of theirs, or a bridge is missing one.
  static BondsBinding bind(FoldGeometry geometry, SkinMesh mesh) {
    final double unit = geometry.unit;
    final double radius = geometry.track.cartoon.rodRadius * unit;
    final double slack = 0.02 * unit;
    final int bridges = geometry.bridges.length;
    final Float64List paths = Float64List(18 * bridges);
    for (int b = 0; b < bridges; b++) {
      final List<ModelPoint> path = geometry.bridgePaths[b];
      for (int k = 0; k < 6; k++) {
        paths
          ..[18 * b + 3 * k] = path[k].$1
          ..[18 * b + 3 * k + 1] = path[k].$2
          ..[18 * b + 3 * k + 2] = -path[k].$3;
      }
    }

    // The pieces: vertices joined by triangles.
    final int n = mesh.positions.length ~/ 3;
    final Int32List parent = Int32List(n);
    for (int v = 0; v < n; v++) {
      parent[v] = v;
    }
    int find(int x) {
      int p = x;
      while (parent[p] != p) {
        parent[p] = parent[parent[p]];
        p = parent[p];
      }
      return p;
    }

    for (int k = 0; k < mesh.indices.length; k += 3) {
      final int a = find(mesh.indices[k]);
      for (int j = 1; j < 3; j++) {
        final int b = find(mesh.indices[k + j]);
        if (a != b) {
          parent[b] = a;
        }
      }
    }
    final Map<int, List<int>> pieces = <int, List<int>>{};
    for (int v = 0; v < n; v++) {
      pieces.putIfAbsent(find(v), () => <int>[]).add(v);
    }

    double at(int v, int a) => mesh.positions[3 * v + a].toDouble();
    double point(int b, int k, int a) => paths[18 * b + 3 * k + a];

    // Which rod or joint each piece is.
    final Int32List vertexBridge = Int32List(n)..fillRange(0, n, -1);
    final Int32List vertexHalf = Int32List(n);
    final Int32List vertexPiece = Int32List(n);
    final Uint8List vertexFar = Uint8List(n);
    final List<List<int>> middles = List<List<int>>.generate(
      bridges,
      (_) => <int>[],
    );
    final Set<String> found = <String>{};
    for (final List<int> piece in pieces.values) {
      String? name;
      search:
      for (int b = 0; b < bridges; b++) {
        // A joint: every vertex a rod's radius from one of the four bends.
        for (int k = 1; k <= 4; k++) {
          if (piece.every((int v) {
            double d = 0;
            for (int a = 0; a < 3; a++) {
              d += math.pow(at(v, a) - point(b, k, a), 2).toDouble();
            }
            return (math.sqrt(d) - radius).abs() <= slack;
          })) {
            // The joints at CB and SG, of the half each belongs to.
            final int half = k <= 2 ? 0 : 1;
            final int kind = k == 1 || k == 4 ? 3 : 4;
            for (final int v in piece) {
              vertexBridge[v] = b;
              vertexHalf[v] = half;
              vertexPiece[v] = kind;
            }
            name = '$b joint $k';
            break search;
          }
        }
        // A rod: every vertex within a rod's radius of one of the five
        // segments, with vertices at both its ends.
        for (int k = 0; k < 5; k++) {
          bool inside = true;
          bool atStart = false;
          bool atEnd = false;
          double length = 0;
          for (int a = 0; a < 3; a++) {
            length += math.pow(point(b, k + 1, a) - point(b, k, a), 2).toDouble();
          }
          for (final int v in piece) {
            double along = 0;
            for (int a = 0; a < 3; a++) {
              along +=
                  (at(v, a) - point(b, k, a)) *
                  (point(b, k + 1, a) - point(b, k, a));
            }
            final double u = along / length;
            double off = 0;
            for (int a = 0; a < 3; a++) {
              final double on =
                  point(b, k, a) + (point(b, k + 1, a) - point(b, k, a)) * u;
              off += math.pow(at(v, a) - on, 2).toDouble();
            }
            if (math.sqrt(off) > radius + slack ||
                u < -0.01 ||
                u > 1.01) {
              inside = false;
              break;
            }
            atStart |= u < 0.01;
            atEnd |= u > 0.99;
          }
          if (!inside || !atStart || !atEnd) {
            continue;
          }
          // Each half grows from its own CA: the first from atom 0, the
          // second from atom 5, so the second's rods run backwards.
          final int half = k < 2 || (k == 2) ? 0 : 1;
          final int kind = k == 0 || k == 4 ? 0 : (k == 1 || k == 3 ? 1 : 2);
          for (final int v in piece) {
            double along = 0;
            for (int a = 0; a < 3; a++) {
              along +=
                  (at(v, a) - point(b, k, a)) *
                  (point(b, k + 1, a) - point(b, k, a));
            }
            final bool towardsNext = along / length > 0.5;
            vertexBridge[v] = b;
            vertexHalf[v] = half;
            vertexPiece[v] = kind;
            // The far end is the one the half grows towards.
            vertexFar[v] = (half == 0 ? towardsNext : !towardsNext) ? 1 : 0;
          }
          if (k == 2) {
            middles[b] = piece;
          }
          name = '$b rod $k';
          break search;
        }
      }
      if (name == null || !found.add(name)) {
        throw const FormatException(
          'A piece of the bonds mesh is not one of the bridges\' rods',
        );
      }
    }
    if (found.length != 9 * bridges) {
      throw FormatException(
        'The bonds mesh has ${found.length} pieces for $bridges bridges',
      );
    }

    // The second copy of each middle rod, for the second half.
    final int copies = middles.fold(0, (int sum, List<int> p) => sum + p.length);
    final Float32List positions = Float32List(3 * (n + copies))
      ..setRange(0, 3 * n, mesh.positions);
    final Float32List normals = Float32List(3 * (n + copies))
      ..setRange(0, 3 * n, mesh.normals);
    final Int32List bridgeOf = Int32List(n + copies)..setRange(0, n, vertexBridge);
    final Int32List halfOf = Int32List(n + copies)..setRange(0, n, vertexHalf);
    final Int32List pieceOf = Int32List(n + copies)..setRange(0, n, vertexPiece);
    final Uint8List farOf = Uint8List(n + copies)..setRange(0, n, vertexFar);
    final Map<int, int> copyOf = <int, int>{};
    int next = n;
    for (int b = 0; b < bridges; b++) {
      for (final int v in middles[b]) {
        copyOf[v] = next;
        for (int a = 0; a < 3; a++) {
          positions[3 * next + a] = mesh.positions[3 * v + a];
          normals[3 * next + a] = mesh.normals[3 * v + a];
        }
        bridgeOf[next] = b;
        halfOf[next] = 1;
        pieceOf[next] = 2;
        // The copy grows from the second SG: its far end is the first's.
        farOf[next] = vertexFar[v] == 1 ? 0 : 1;
        next++;
      }
    }
    final List<int> extra = <int>[];
    for (int k = 0; k < mesh.indices.length; k += 3) {
      final int? a = copyOf[mesh.indices[k]];
      if (a == null) {
        continue;
      }
      extra.addAll(<int>[
        a,
        copyOf[mesh.indices[k + 1]]!,
        copyOf[mesh.indices[k + 2]]!,
      ]);
    }
    final Uint32List indices = Uint32List(mesh.indices.length + extra.length)
      ..setRange(0, mesh.indices.length, mesh.indices)
      ..setRange(mesh.indices.length, mesh.indices.length + extra.length, extra);

    // The whole rod's normal at its middle, for each growing end of a middle
    // rod: the average of the normals at its two ends, around the same side.
    final Float64List rimNormals = Float64List(3 * (n + copies));
    for (int b = 0; b < bridges; b++) {
      final List<int> rod = middles[b];
      for (final int v in rod) {
        final int w = _across(rod, v, b, positions, paths);
        if (w < 0) {
          continue;
        }
        for (final int x in <int>[v, copyOf[v]!]) {
          for (int a = 0; a < 3; a++) {
            rimNormals[3 * x + a] =
                (normals[3 * v + a] + normals[3 * w + a]) / 2;
          }
        }
      }
    }

    return BondsBinding._(
      positions: positions,
      normals: normals,
      indices: indices,
      stored: n,
      vertexBridge: bridgeOf,
      vertexHalf: halfOf,
      vertexPiece: pieceOf,
      vertexFar: farOf,
      rimNormals: rimNormals,
      paths: paths,
    );
  }

  /// The vertex of middle rod [rod] of bridge [b] at its other end, on the
  /// same side as [v]; -1 for a vertex on the axis.
  static int _across(
    List<int> rod,
    int v,
    int b,
    Float32List positions,
    Float64List paths,
  ) {
    final List<double> s = <double>[
      for (int a = 0; a < 3; a++) paths[18 * b + 6 + a],
    ];
    final List<double> e = <double>[
      for (int a = 0; a < 3; a++) paths[18 * b + 9 + a],
    ];
    List<double> radial(int x) {
      double along = 0;
      double length = 0;
      for (int a = 0; a < 3; a++) {
        along += (positions[3 * x + a] - s[a]) * (e[a] - s[a]);
        length += (e[a] - s[a]) * (e[a] - s[a]);
      }
      final double u = along / length;
      return <double>[
        for (int a = 0; a < 3; a++)
          positions[3 * x + a] - (s[a] + (e[a] - s[a]) * u),
      ];
    }

    double alongOf(int x) {
      double along = 0;
      double length = 0;
      for (int a = 0; a < 3; a++) {
        along += (positions[3 * x + a] - s[a]) * (e[a] - s[a]);
        length += (e[a] - s[a]) * (e[a] - s[a]);
      }
      return along / length;
    }

    final List<double> mine = radial(v);
    if (mine.every((double c) => c.abs() < 1e-9)) {
      return -1;
    }
    final bool near = alongOf(v) < 0.5;
    int best = -1;
    double closest = double.infinity;
    for (final int w in rod) {
      if ((alongOf(w) < 0.5) == near) {
        continue;
      }
      final List<double> theirs = radial(w);
      double d = 0;
      for (int a = 0; a < 3; a++) {
        d += (theirs[a] - mine[a]) * (theirs[a] - mine[a]);
      }
      if (d < closest) {
        closest = d;
        best = w;
      }
    }
    return best;
  }
}

/// The model's bridges, grown from its own rods as the bridges snap shut.
///
/// Each half of a bridge grows as the fold's rods always have, from its
/// cysteine's CA through CB and SG to the middle of the S–S bond, carried
/// with the CA while the bridge still holds the pair apart. A rod grows by
/// its far end sliding out to the tip; a joint rides the tip, rounding it,
/// until the tip reaches the joint's atom. The halves meet in the middle,
/// and from then the bridge is the stored node's, float for float.
final class FoldBonds {
  FoldBonds(this.binding, this.geometry)
    : positions = Float32List.fromList(binding.positions),
      normals = Float32List.fromList(binding.normals) {
    _collapse();
  }

  final BondsBinding binding;
  final FoldGeometry geometry;

  /// The node's vertices as they are now.
  final Float32List positions;
  final Float32List normals;

  /// Whether the last update changed anything since the one before.
  bool get changed => _changed;
  bool _changed = true;

  double _last = -1;

  // Per bridge and half: the shift, and each piece's start, tip and growth.
  final List<double> _shift = <double>[0, 0, 0];

  /// Moves every bridge to [frame], its cysteines where [backbone] has them.
  void update(FoldFrame frame, FoldBackbone backbone) {
    final double closure = frame.closure.isEmpty ? 1 : frame.closure.first;
    if (closure == _last && (closure <= 0 || closure >= 1)) {
      _changed = false;
      return;
    }
    _changed = true;
    _last = closure;
    if (closure <= 0) {
      _collapse();
      return;
    }
    if (closure >= 1) {
      _stored();
      return;
    }
    final BondsBinding b = binding;
    final int bridges = geometry.bridges.length;
    // Per bridge, half and piece: start, tip, how grown (0 to 1).
    final Float64List start = Float64List(bridges * 2 * 3 * 3);
    final Float64List tip = Float64List(bridges * 2 * 3 * 3);
    final Float64List end = Float64List(bridges * 2 * 3 * 3);
    final Float64List grown = Float64List(bridges * 2 * 3);
    final Float64List shift = Float64List(bridges * 2 * 3);
    for (int bridge = 0; bridge < bridges; bridge++) {
      final (int i, int j) = geometry.bridges[bridge];
      final List<double> middle = <double>[
        for (int a = 0; a < 3; a++)
          (b.paths[18 * bridge + 6 + a] + b.paths[18 * bridge + 9 + a]) / 2,
      ];
      for (int half = 0; half < 2; half++) {
        final int residue = half == 0 ? i : j;
        final List<int> atoms = half == 0
            ? <int>[0, 1, 2]
            : <int>[5, 4, 3];
        for (int a = 0; a < 3; a++) {
          _shift[a] =
              backbone.native[3 * residue + a] -
              b.paths[18 * bridge + 3 * atoms[0] + a];
          shift[(bridge * 2 + half) * 3 + a] = _shift[a];
        }
        final List<double> lengths = <double>[];
        for (int k = 0; k < 3; k++) {
          double l = 0;
          for (int a = 0; a < 3; a++) {
            final double from = b.paths[18 * bridge + 3 * atoms[k] + a];
            final double to = k < 2
                ? b.paths[18 * bridge + 3 * atoms[k + 1] + a]
                : middle[a];
            l += (to - from) * (to - from);
          }
          lengths.add(math.sqrt(l));
        }
        double left = closure * (lengths[0] + lengths[1] + lengths[2]);
        for (int k = 0; k < 3; k++) {
          final double piece = math.min(left, lengths[k]);
          left -= piece;
          final double f = lengths[k] == 0 ? 1 : piece / lengths[k];
          final int o = ((bridge * 2 + half) * 3 + k) * 3;
          grown[(bridge * 2 + half) * 3 + k] = piece <= 0 ? 0 : f;
          for (int a = 0; a < 3; a++) {
            final double from = b.paths[18 * bridge + 3 * atoms[k] + a];
            final double to = k < 2
                ? b.paths[18 * bridge + 3 * atoms[k + 1] + a]
                : (half == 0
                      ? b.paths[18 * bridge + 9 + a]
                      : b.paths[18 * bridge + 6 + a]);
            final double stop = k < 2 ? to : middle[a];
            start[o + a] = from;
            end[o + a] = to;
            tip[o + a] = from + (stop - from) * f;
          }
        }
      }
    }

    for (int v = 0; v < b.vertexCount; v++) {
      final int bridge = b.vertexBridge[v];
      final int half = b.vertexHalf[v];
      final int piece = b.vertexPiece[v];
      final int h = (bridge * 2 + half) * 3;
      // A joint rides the tip of the rod before it.
      final int rod = piece >= 3 ? piece - 3 : piece;
      final double f = grown[h + rod];
      final int o = (h + rod) * 3;
      for (int a = 0; a < 3; a++) {
        normals[3 * v + a] = b.normals[3 * v + a];
      }
      if (f <= 0) {
        for (int a = 0; a < 3; a++) {
          positions[3 * v + a] = start[o + a] + shift[h + a];
        }
        continue;
      }
      final bool moves = piece >= 3 || b.vertexFar[v] == 1;
      for (int a = 0; a < 3; a++) {
        // The far end, and a joint, travel with the tip; the near end stays.
        // A middle rod's far end is the far SG, but it stops at the middle.
        final double travel = moves ? tip[o + a] - end[o + a] : 0;
        positions[3 * v + a] = b.positions[3 * v + a] + travel + shift[h + a];
      }
      if (piece == 2 && b.vertexFar[v] == 1) {
        // Turn the growing end's shading to the whole rod's as the halves
        // meet.
        final double e = _smooth((f - 0.5) / 0.5);
        final double rx = b.rimNormals[3 * v];
        final double ry = b.rimNormals[3 * v + 1];
        final double rz = b.rimNormals[3 * v + 2];
        if (rx != 0 || ry != 0 || rz != 0) {
          normals
            ..[3 * v] = b.normals[3 * v] + (rx - b.normals[3 * v]) * e
            ..[3 * v + 1] =
                b.normals[3 * v + 1] + (ry - b.normals[3 * v + 1]) * e
            ..[3 * v + 2] =
                b.normals[3 * v + 2] + (rz - b.normals[3 * v + 2]) * e;
        }
      }
    }
  }

  /// Nothing grown: every piece gathered into a point, which draws nothing.
  void _collapse() {
    final BondsBinding b = binding;
    for (int v = 0; v < b.vertexCount; v++) {
      final int bridge = b.vertexBridge[v];
      final int atom = b.vertexHalf[v] == 0 ? 0 : 5;
      for (int a = 0; a < 3; a++) {
        positions[3 * v + a] = b.paths[18 * bridge + 3 * atom + a];
        normals[3 * v + a] = b.normals[3 * v + a];
      }
    }
  }

  /// Every bridge closed: the stored node, and the copies gathered away.
  void _stored() {
    final BondsBinding b = binding;
    for (int v = 0; v < b.vertexCount; v++) {
      if (v < b.stored) {
        for (int a = 0; a < 3; a++) {
          positions[3 * v + a] = b.positions[3 * v + a];
          normals[3 * v + a] = b.normals[3 * v + a];
        }
      } else {
        final int bridge = b.vertexBridge[v];
        for (int a = 0; a < 3; a++) {
          positions[3 * v + a] = b.paths[18 * bridge + 9 + a];
          normals[3 * v + a] = b.normals[3 * v + a];
        }
      }
    }
  }

  static double _smooth(double x) {
    final double c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }
}
