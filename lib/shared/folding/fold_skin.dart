import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'fold_backbone.dart';
import 'fold_geometry.dart';
import 'fold_mesh.dart';
import 'fold_timeline.dart';

/// One node of the stored model as the fold page's scene holds it: its
/// vertices in the scene's frame (the model's, with z turned round) and its
/// triangles, in the order and the winding the scene draws them.
@immutable
final class SkinMesh {
  const SkinMesh({
    required this.node,
    required this.positions,
    required this.normals,
    required this.indices,
  });

  final String node;
  final Float32List positions;
  final Float32List normals;
  final Uint32List indices;
}

/// Where each vertex of one chain's stored mesh sits on the chain.
///
/// PyMOL sweeps a cartoon along the chain as rings, one cross-section at a
/// time, and emits it as triangle strips running along each piece of
/// secondary structure. The two vertices each step of a strip adds lie on
/// one ring, so the strips give every vertex its ring without asking where it
/// is, and a ring is bound to the chain as a whole: its centre to a point of
/// the backbone, and its vertices to that point's frame. A tightly packed
/// sheet cannot pull one vertex onto a neighbouring strand, because no vertex
/// is bound alone. Rings are bound in order along the mesh from the ones only
/// one stretch of chain could hold, so a ring that sits as close to two
/// stretches as to its own takes the one its neighbours are on.
///
/// Computed once per protein, off the page, and sent across isolates: it is
/// plain data.
@immutable
final class SkinChainBinding {
  const SkinChainBinding._({
    required this.node,
    required this.runStarts,
    required this.runEnds,
    required this.positions,
    required this.normals,
    required this.indices,
    required this.vertexRing,
    required this.ringRun,
    required this.ringAt,
    required this.ringRest,
    required this.ringOffset,
    required this.ringExtent,
    required this.ringPiece,
    required this.pieceCentres,
    required this.sigma,
    required this.nu,
    required this.tau,
    required this.largestNudge,
  });

  final String node;

  /// The chain's ordered runs, as ranges of [FoldGeometry.drawn]: a run ends
  /// where a residue the entry never placed begins.
  final Int32List runStarts;
  final Int32List runEnds;

  /// The copy's vertices: the stored floats, one vertex for each distinct
  /// position and normal, and the stored triangles in order, over them.
  final Float32List positions;
  final Float32List normals;
  final Uint32List indices;

  /// Each vertex's ring.
  final Int32List vertexRing;

  /// Each ring's run, or -1 for a ring of the model's marks across a gap.
  final Int32List ringRun;

  /// Where along its run each ring sits: 0 on the run's first residue, 1 on
  /// the next, and so on.
  final Float64List ringAt;

  /// Each ring's frame on the finished fold, twelve doubles: the backbone's
  /// point, then its tangent, then the ring's own width and thickness axes.
  final Float64List ringRest;

  /// Where each ring's centre is from the backbone's point, in its frame.
  final Float64List ringOffset;

  /// Each ring's half-width and half-thickness.
  final Float64List ringExtent;

  /// For a ring across a gap, the mark it is part of; otherwise -1.
  final Int32List ringPiece;

  /// Each mark's centre.
  final Float64List pieceCentres;

  /// Each vertex from its ring's centre, and its normal, in its ring's
  /// frame; and the way a thread of the ring's size would face there.
  final Float64List sigma;
  final Float64List nu;
  final Float64List tau;

  /// The furthest any ring was moved along the chain to keep the rings in
  /// order along each strip, in residues.
  final double largestNudge;

  int get vertexCount => positions.length ~/ 3;
  int get ringCount => ringRun.length;
}

/// Every chain node of a model, bound to its chain.
@immutable
final class SkinBinding {
  const SkinBinding(this.chains);

  final List<SkinChainBinding> chains;

  /// Binds each of [meshes] that names a chain of [geometry] to that chain.
  /// Throws if a chain has no mesh, or a ring of one lies on no chain.
  static SkinBinding bind(FoldGeometry geometry, List<SkinMesh> meshes) {
    final FoldBackbone rest = FoldBackbone(geometry)
      ..update(FoldTimeline(geometry).frameAt(1));
    return SkinBinding(<SkinChainBinding>[
      for (int c = 0; c < geometry.chainRuns.length; c++)
        _ChainBinder(
          geometry,
          rest,
          c,
          meshes.firstWhere(
            (SkinMesh m) => m.node == geometry.track.chains[c].node,
            orElse: () => throw StateError(
              'The model has no mesh for ${geometry.track.chains[c].node}',
            ),
          ),
        ).bind(),
    ]);
  }
}

/// The stored model's chains, carried by the chain as it folds.
///
/// Each ring of a chain's mesh rides the backbone at its own point: its
/// frame there is its frame on the finished fold turned, the least way, onto
/// where the backbone now runs. As a residue settles, its rings grow from a
/// thread (the width the unfolded chain is drawn at) to their full size, and
/// their centres from the backbone out to where the model's ribbon runs. So
/// the ribbon a residue settles into is the model's own, and once every
/// residue is in its place the copy is the stored mesh, float for float.
final class FoldSkin {
  FoldSkin(this.binding, this.geometry)
    : chains = <SkinChain>[
        for (final SkinChainBinding chain in binding.chains)
          SkinChain._(chain, geometry.unit),
      ];

  final SkinBinding binding;
  final FoldGeometry geometry;
  final List<SkinChain> chains;

  /// Moves every chain to [frame], where [backbone] now runs.
  void update(FoldFrame frame, FoldBackbone backbone) {
    final double grown = FoldTimeline.finishAt(frame.t);
    for (final SkinChain chain in chains) {
      chain._update(backbone, grown);
    }
  }
}

/// One chain's copy of the stored mesh, as drawn at the last update.
final class SkinChain {
  SkinChain._(this.binding, double unit)
    : positions = Float32List.fromList(binding.positions),
      normals = Float32List.fromList(binding.normals),
      _thread = FoldMesh.threadRadius * unit,
      _frames = Float64List(_perRing * binding.ringCount),
      _atRest = Uint8List(binding.ringCount);

  final SkinChainBinding binding;

  /// The copy's vertices as they are now.
  final Float32List positions;
  final Float32List normals;

  /// Whether the last update changed anything since the one before.
  bool get changed => _changed;
  bool _changed = true;

  /// Whether the copy is the stored mesh, float for float.
  bool get isStored => _stored;
  bool _stored = false;

  final double _thread;

  // Per ring: point (3), tangent (3), width axis (3), thickness axis (3),
  // growth, and the two scales.
  static const int _perRing = 15;
  final Float64List _frames;
  final Uint8List _atRest;

  double _lastGrown = -1;
  bool _stillBefore = false;

  final List<double> _point = <double>[0, 0, 0];
  final List<double> _tangent = <double>[0, 0, 0];

  void _update(FoldBackbone backbone, double grown) {
    final SkinChainBinding b = binding;
    final Float64List rest = b.ringRest;
    bool allAtRest = true;
    for (int r = 0; r < b.ringCount; r++) {
      final int run = b.ringRun[r];
      if (run < 0) {
        continue;
      }
      final int start = b.runStarts[run];
      final int m = b.runEnds[run] - start;
      final double s = b.ringAt[r];
      final int o = _perRing * r;
      double g;
      if (m >= 2) {
        final int k = math.min(s.floor(), m - 2);
        final double u = s - k;
        catmullRom(backbone.centres, start, m, k, u, _point, _tangent);
        _normalise(_tangent);
        final double from = backbone.settled[start + k];
        g = from + (backbone.settled[start + k + 1] - from) * u;
      } else {
        for (int a = 0; a < 3; a++) {
          _point[a] = backbone.centres[3 * start + a];
          _tangent[a] = rest[12 * r + 3 + a];
        }
        g = backbone.settled[start];
      }
      // A ring pointing more than a right angle from the way it will lie
      // stays a thread until it turns back: the least turn onto a tangent
      // nearly reversed from rest is ill-defined, and a round thread shows
      // no turn about its own axis.
      g *= _facing(
        _tangent[0] * rest[12 * r + 3] +
            _tangent[1] * rest[12 * r + 4] +
            _tangent[2] * rest[12 * r + 5],
      );
      final bool still =
          g >= 1 &&
          _point[0] == rest[12 * r] &&
          _point[1] == rest[12 * r + 1] &&
          _point[2] == rest[12 * r + 2] &&
          _tangent[0] == rest[12 * r + 3] &&
          _tangent[1] == rest[12 * r + 4] &&
          _tangent[2] == rest[12 * r + 5];
      _atRest[r] = still ? 1 : 0;
      if (still) {
        continue;
      }
      allAtRest = false;
      _frame(r, o, g);
    }

    final bool pieces = b.pieceCentres.isNotEmpty;
    // Every ring still, as it was last time, and the marks across a gap no
    // further grown: nothing to write.
    if (allAtRest && _stillBefore && (!pieces || grown == _lastGrown)) {
      _changed = false;
      return;
    }
    _changed = true;
    _stillBefore = allAtRest;
    _stored = allAtRest && (!pieces || grown >= 1);
    _lastGrown = grown;

    final int n = b.vertexCount;
    for (int v = 0; v < n; v++) {
      final int r = b.vertexRing[v];
      final int piece = b.ringPiece[r];
      if (piece >= 0) {
        _mark(v, piece, grown);
        continue;
      }
      if (_atRest[r] == 1) {
        for (int a = 0; a < 3; a++) {
          positions[3 * v + a] = b.positions[3 * v + a];
          normals[3 * v + a] = b.normals[3 * v + a];
        }
        continue;
      }
      _carry(v, r);
    }
  }

  /// Ring [r]'s frame now, at [o] in [_frames], with the backbone's point and
  /// tangent in [_point] and [_tangent].
  void _frame(int r, int o, double g) {
    final Float64List rest = binding.ringRest;
    final int q = 12 * r;
    final double tx = rest[q + 3];
    final double ty = rest[q + 4];
    final double tz = rest[q + 5];
    final double sx = rest[q + 6];
    final double sy = rest[q + 7];
    final double sz = rest[q + 8];
    final double nx = _tangent[0];
    final double ny = _tangent[1];
    final double nz = _tangent[2];
    // The rest frame turned the least way that takes the rest tangent onto
    // the tangent now: Rodrigues, with v = t0 × t and c = t0 · t.
    final double vx = ty * nz - tz * ny;
    final double vy = tz * nx - tx * nz;
    final double vz = tx * ny - ty * nx;
    final double c = tx * nx + ty * ny + tz * nz;
    double wx;
    double wy;
    double wz;
    if (1 + c > 1e-6) {
      // side + v × side + v × (v × side) / (1 + c)
      final double ax = vy * sz - vz * sy;
      final double ay = vz * sx - vx * sz;
      final double az = vx * sy - vy * sx;
      final double bx = vy * az - vz * ay;
      final double by = vz * ax - vx * az;
      final double bz = vx * ay - vy * ax;
      final double f = 1 / (1 + c);
      wx = sx + ax + bx * f;
      wy = sy + ay + by * f;
      wz = sz + az + bz * f;
    } else {
      // Turned right round: any half-turn about an axis across the chain
      // will do. Only a thread, still round, is ever turned this far.
      wx = sx;
      wy = sy;
      wz = sz;
    }
    // Square to the tangent, and unit.
    final double d = wx * nx + wy * ny + wz * nz;
    wx -= d * nx;
    wy -= d * ny;
    wz -= d * nz;
    double l = math.sqrt(wx * wx + wy * wy + wz * wz);
    if (l < 1e-12) {
      // The width axis lies along the tangent: take the thickness axis's.
      final double ux = rest[q + 9];
      final double uy = rest[q + 10];
      final double uz = rest[q + 11];
      final double e = ux * nx + uy * ny + uz * nz;
      wx = ux - e * nx;
      wy = uy - e * ny;
      wz = uz - e * nz;
      l = math.sqrt(wx * wx + wy * wy + wz * wz);
    }
    wx /= l;
    wy /= l;
    wz /= l;
    final double width = binding.ringExtent[2 * r];
    final double thickness = binding.ringExtent[2 * r + 1];
    _frames
      ..[o] = _point[0]
      ..[o + 1] = _point[1]
      ..[o + 2] = _point[2]
      ..[o + 3] = nx
      ..[o + 4] = ny
      ..[o + 5] = nz
      ..[o + 6] = wx
      ..[o + 7] = wy
      ..[o + 8] = wz
      ..[o + 9] = ny * wz - nz * wy
      ..[o + 10] = nz * wx - nx * wz
      ..[o + 11] = nx * wy - ny * wx
      ..[o + 12] = g
      ..[o + 13] = (_thread + (width - _thread) * g) / width
      ..[o + 14] = (_thread + (thickness - _thread) * g) / thickness;
  }

  /// Vertex [v] of ring [r], carried by the ring's frame now.
  void _carry(int v, int r) {
    final SkinChainBinding b = binding;
    final Float64List f = _frames;
    final int o = _perRing * r;
    final double g = f[o + 12];
    final double a = f[o + 13];
    final double bt = f[o + 14];
    final double dx = b.ringOffset[3 * r];
    final double dy = b.ringOffset[3 * r + 1];
    final double dt = b.ringOffset[3 * r + 2];
    final double x = g * dx + a * b.sigma[3 * v];
    final double y = g * dy + bt * b.sigma[3 * v + 1];
    final double z = g * (dt + b.sigma[3 * v + 2]);
    for (int k = 0; k < 3; k++) {
      positions[3 * v + k] =
          f[o + k] + f[o + 6 + k] * x + f[o + 9 + k] * y + f[o + 3 + k] * z;
    }

    double lx;
    double ly;
    double lz;
    final double nx = b.nu[3 * v];
    final double ny = b.nu[3 * v + 1];
    final double nz = b.nu[3 * v + 2];
    if (g >= 1) {
      lx = nx;
      ly = ny;
      lz = nz;
    } else {
      // The stored normal as the ring is scaled now, leaning towards a
      // round thread's the less grown the ring is.
      double sx = nx / a;
      double sy = ny / bt;
      double sz = nz;
      final double sl = math.sqrt(sx * sx + sy * sy + sz * sz);
      if (sl > 0) {
        sx /= sl;
        sy /= sl;
        sz /= sl;
      }
      lx = b.tau[3 * v] * (1 - g) + sx * g;
      ly = b.tau[3 * v + 1] * (1 - g) + sy * g;
      lz = b.tau[3 * v + 2] * (1 - g) + sz * g;
      final double l = math.sqrt(lx * lx + ly * ly + lz * lz);
      if (l > 0) {
        lx /= l;
        ly /= l;
        lz /= l;
      }
    }
    for (int k = 0; k < 3; k++) {
      normals[3 * v + k] =
          f[o + 6 + k] * lx + f[o + 9 + k] * ly + f[o + 3 + k] * lz;
    }
  }

  /// Vertex [v] of a mark across a gap: nothing until the bridges have
  /// closed, then grown about its own centre, to the stored mesh at the end.
  void _mark(int v, int piece, double grown) {
    final SkinChainBinding b = binding;
    if (grown >= 1) {
      for (int a = 0; a < 3; a++) {
        positions[3 * v + a] = b.positions[3 * v + a];
        normals[3 * v + a] = b.normals[3 * v + a];
      }
      return;
    }
    for (int a = 0; a < 3; a++) {
      final double centre = b.pieceCentres[3 * piece + a];
      positions[3 * v + a] =
          centre + (b.positions[3 * v + a] - centre) * grown;
      normals[3 * v + a] = b.normals[3 * v + a];
    }
  }

  /// How much of its growth a ring shows, by how far its tangent [c] (the
  /// cosine to its rest tangent) has turned: all of it within a right angle,
  /// none past about 127 degrees.
  static double _facing(double c) {
    final double x = ((c + 0.6) / 0.6).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static void _normalise(List<double> v) {
    final double l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (l > 0) {
      v
        ..[0] = v[0] / l
        ..[1] = v[1] / l
        ..[2] = v[2] / l;
    }
  }
}

// -- binding -----------------------------------------------------------------

/// Binds one chain's mesh to the chain.
final class _ChainBinder {
  _ChainBinder(this.g, this.rest, this.chain, this.mesh);

  final FoldGeometry g;
  final FoldBackbone rest;
  final int chain;
  final SkinMesh mesh;

  /// Candidates further than this from the backbone are not considered.
  static const double _reach = 3.5;

  /// A ring is bound where it is without asking its neighbours when no other
  /// stretch of chain comes within this much of as close.
  static const double _margin = 1.0;

  /// Samples a residue, looking for where a ring's centre is closest.
  static const int _samples = 16;

  SkinChainBinding bind() {
    final int corners = mesh.indices.length;
    final int soup = mesh.positions.length ~/ 3;
    if (corners % 3 != 0 || mesh.normals.length != mesh.positions.length) {
      throw FormatException('The ${mesh.node} mesh is not a triangle list');
    }

    // Positions, welded by their exact floats: which vertices are the same
    // point of the surface.
    final Uint32List positionWords = Uint32List.view(
      mesh.positions.buffer,
      mesh.positions.offsetInBytes,
      mesh.positions.length,
    );
    final (Int32List pointOf, Int32List pointRow) = _group(
      <Uint32List>[positionWords],
      <int>[3],
      soup,
    );
    final int points = pointRow.length;

    // The copy's vertices: each distinct position and normal once.
    final Uint32List normalWords = Uint32List.view(
      mesh.normals.buffer,
      mesh.normals.offsetInBytes,
      mesh.normals.length,
    );
    final (Int32List vertexOf, Int32List vertexRow) = _group(
      <Uint32List>[positionWords, normalWords],
      <int>[3, 3],
      soup,
    );
    final int vertices = vertexRow.length;

    // Rings, from the strips.
    final Int32List parent = Int32List(points);
    for (int p = 0; p < points; p++) {
      parent[p] = p;
    }
    final Uint8List ringed = Uint8List(points);
    final List<List<int>> strips = _strips(pointOf);
    for (final List<int> strip in strips) {
      for (int j = 0; j + 1 < strip.length; j += 2) {
        _union(parent, strip[j], strip[j + 1]);
        ringed[strip[j]] = 1;
        ringed[strip[j + 1]] = 1;
      }
    }
    // A point no strip reached (a cap's centre, say) joins a ring it shares
    // a triangle with.
    final int triangles = corners ~/ 3;
    bool grew = true;
    while (grew) {
      grew = false;
      for (int t = 0; t < triangles; t++) {
        int ringedPoint = -1;
        for (int k = 0; k < 3; k++) {
          final int p = pointOf[mesh.indices[3 * t + k]];
          if (ringed[p] == 1) {
            ringedPoint = p;
          }
        }
        if (ringedPoint < 0) {
          continue;
        }
        for (int k = 0; k < 3; k++) {
          final int p = pointOf[mesh.indices[3 * t + k]];
          if (ringed[p] == 0) {
            _union(parent, ringedPoint, p);
            ringed[p] = 1;
            grew = true;
          }
        }
      }
    }
    final Int32List ringOfPoint = Int32List(points);
    final Map<int, int> rootRing = <int, int>{};
    for (int p = 0; p < points; p++) {
      ringOfPoint[p] = rootRing.putIfAbsent(
        _find(parent, p),
        () => rootRing.length,
      );
    }
    final int rings = rootRing.length;

    // Each ring's centre, and its neighbours across the mesh.
    final Float64List centroid = Float64List(3 * rings);
    final Int32List members = Int32List(rings);
    for (int p = 0; p < points; p++) {
      final int r = ringOfPoint[p];
      final int row = pointRow[p];
      for (int a = 0; a < 3; a++) {
        centroid[3 * r + a] += mesh.positions[3 * row + a];
      }
      members[r]++;
    }
    for (int r = 0; r < rings; r++) {
      for (int a = 0; a < 3; a++) {
        centroid[3 * r + a] /= members[r];
      }
    }
    final List<Set<int>> adjacent = <Set<int>>[
      for (int r = 0; r < rings; r++) <int>{},
    ];
    for (int t = 0; t < triangles; t++) {
      final int a = ringOfPoint[pointOf[mesh.indices[3 * t]]];
      final int b = ringOfPoint[pointOf[mesh.indices[3 * t + 1]]];
      final int c = ringOfPoint[pointOf[mesh.indices[3 * t + 2]]];
      for (final (int x, int y) in <(int, int)>[(a, b), (b, c), (a, c)]) {
        if (x != y) {
          adjacent[x].add(y);
          adjacent[y].add(x);
        }
      }
    }

    // The chain's ordered runs, and the backbone of each on the finished
    // fold.
    final (int chainStart, int chainEnd) = g.chainRuns[chain];
    final List<int> runStarts = <int>[];
    final List<int> runEnds = <int>[];
    for (int i = chainStart; i < chainEnd; i++) {
      if (!g.drawn[i].isOrdered) {
        continue;
      }
      if (runEnds.isNotEmpty && runEnds.last == i) {
        runEnds[runEnds.length - 1] = i + 1;
      } else {
        runStarts.add(i);
        runEnds.add(i + 1);
      }
    }
    final _Runs runs = _Runs(rest.centres, runStarts, runEnds);

    // Bind each ring's centre to the backbone.
    final double reach = _reach * g.unit;
    final double margin = _margin * g.unit;
    final List<List<_Candidate>> candidates = <List<_Candidate>>[
      for (int r = 0; r < rings; r++)
        runs.candidates(
          centroid[3 * r],
          centroid[3 * r + 1],
          centroid[3 * r + 2],
          reach,
        ),
    ];
    final Int32List ringRun = Int32List(rings)..fillRange(0, rings, -1);
    final Float64List ringAt = Float64List(rings);
    final List<int> queue = <int>[];
    for (int r = 0; r < rings; r++) {
      final List<_Candidate> cs = candidates[r];
      if (cs.length == 1 ||
          (cs.length > 1 && cs[1].distance > cs[0].distance + margin)) {
        ringRun[r] = cs[0].run;
        ringAt[r] = cs[0].at;
        queue.add(r);
      }
    }
    void spread() {
      for (int head = 0; head < queue.length; head++) {
        for (final int w in adjacent[queue[head]]) {
          if (ringRun[w] >= 0 || candidates[w].isEmpty) {
            continue;
          }
          final Map<int, int> votes = <int, int>{};
          for (final int x in adjacent[w]) {
            if (ringRun[x] >= 0) {
              votes[ringRun[x]] = (votes[ringRun[x]] ?? 0) + 1;
            }
          }
          int run = -1;
          int most = 0;
          votes.forEach((int key, int count) {
            if (count > most) {
              most = count;
              run = key;
            }
          });
          double sum = 0;
          int count = 0;
          for (final int x in adjacent[w]) {
            if (ringRun[x] == run) {
              sum += ringAt[x];
              count++;
            }
          }
          final double near = sum / count;
          _Candidate? best;
          for (final _Candidate c in candidates[w]) {
            if (c.run == run &&
                (best == null || (c.at - near).abs() < (best.at - near).abs())) {
              best = c;
            }
          }
          if (best != null && (best.at - near).abs() < 1.5) {
            ringRun[w] = best.run;
            ringAt[w] = best.at;
            queue.add(w);
          }
        }
      }
    }

    spread();
    // A piece no seed reached takes its closest stretch, and passes it on.
    for (int r = 0; r < rings; r++) {
      if (ringRun[r] < 0 && candidates[r].isNotEmpty) {
        ringRun[r] = candidates[r].first.run;
        ringAt[r] = candidates[r].first.at;
        queue
          ..clear()
          ..add(r);
        spread();
      }
    }

    // The model's marks across a gap: rings between the two ends of a gap,
    // not on either run. PyMOL draws a short gap as a dashed line.
    final Int32List ringPiece = Int32List(rings)..fillRange(0, rings, -1);
    final Uint8List mark = Uint8List(rings);
    for (int gap = 0; gap + 1 < runStarts.length; gap++) {
      final int a = runEnds[gap] - 1;
      final int b = runStarts[gap + 1];
      for (int r = 0; r < rings; r++) {
        final int run = ringRun[r];
        final bool atEnd =
            run < 0 ||
            (run == gap && ringAt[r] >= runEnds[gap] - runStarts[gap] - 1.05) ||
            (run == gap + 1 && ringAt[r] <= 0.05);
        if (!atEnd) {
          continue;
        }
        final (double u, double d) = _across(rest.centres, a, b, centroid, r);
        if (u > 0.02 && u < 0.98 && d < 1.5 * g.unit) {
          mark[r] = 1;
        }
      }
    }
    for (int r = 0; r < rings; r++) {
      if (ringRun[r] < 0 && mark[r] == 0) {
        throw FormatException(
          'A ring of ${mesh.node} lies on no stretch of its chain',
        );
      }
      if (mark[r] == 1) {
        ringRun[r] = -1;
      }
    }
    final List<List<int>> pieces = <List<int>>[];
    for (int r = 0; r < rings; r++) {
      if (mark[r] == 0 || ringPiece[r] >= 0) {
        continue;
      }
      final List<int> piece = <int>[r];
      ringPiece[r] = pieces.length;
      for (int head = 0; head < piece.length; head++) {
        for (final int w in adjacent[piece[head]]) {
          if (mark[w] == 1 && ringPiece[w] < 0) {
            ringPiece[w] = pieces.length;
            piece.add(w);
          }
        }
      }
      pieces.add(piece);
    }
    final Float64List pieceCentres = Float64List(3 * pieces.length);
    for (int piece = 0; piece < pieces.length; piece++) {
      int count = 0;
      for (final int r in pieces[piece]) {
        for (int a = 0; a < 3; a++) {
          pieceCentres[3 * piece + a] += centroid[3 * r + a] * members[r];
        }
        count += members[r];
      }
      for (int a = 0; a < 3; a++) {
        pieceCentres[3 * piece + a] /= count;
      }
    }

    // Keep the rings in order along each strip.
    final double nudge = _order(strips, ringOfPoint, ringRun, ringAt);

    // Each ring's frame on the finished fold.
    final Float64List ringRest = Float64List(12 * rings);
    final Float64List ringOffset = Float64List(3 * rings);
    final Float64List ringExtent = Float64List(2 * rings);
    final List<double> point = <double>[0, 0, 0];
    final List<double> tangent = <double>[0, 0, 0];
    final List<List<int>> pointsOfRing = <List<int>>[
      for (int r = 0; r < rings; r++) <int>[],
    ];
    for (int p = 0; p < points; p++) {
      pointsOfRing[ringOfPoint[p]].add(p);
    }
    final double floor = 0.02 * g.unit;
    for (int r = 0; r < rings; r++) {
      final int run = ringRun[r];
      if (run < 0) {
        continue;
      }
      runs.at(run, ringAt[r], point, tangent);
      SkinChain._normalise(tangent);
      final (List<double> side, List<double> up) = _axes(
        tangent,
        pointsOfRing[r],
        pointRow,
        centroid,
        r,
      );
      for (int a = 0; a < 3; a++) {
        ringRest
          ..[12 * r + a] = point[a]
          ..[12 * r + 3 + a] = tangent[a]
          ..[12 * r + 6 + a] = side[a]
          ..[12 * r + 9 + a] = up[a];
      }
      final List<double> d = <double>[
        for (int a = 0; a < 3; a++) centroid[3 * r + a] - point[a],
      ];
      ringOffset
        ..[3 * r] = _dot(d, side)
        ..[3 * r + 1] = _dot(d, up)
        ..[3 * r + 2] = _dot(d, tangent);
      double width = 0;
      double thickness = 0;
      for (final int p in pointsOfRing[r]) {
        final int row = pointRow[p];
        final List<double> e = <double>[
          for (int a = 0; a < 3; a++)
            mesh.positions[3 * row + a] - centroid[3 * r + a],
        ];
        width = math.max(width, _dot(e, side).abs());
        thickness = math.max(thickness, _dot(e, up).abs());
      }
      ringExtent
        ..[2 * r] = math.max(width, floor)
        ..[2 * r + 1] = math.max(thickness, floor);
    }

    // The copy's vertices, in their rings' frames.
    final Float32List positions = Float32List(3 * vertices);
    final Float32List normals = Float32List(3 * vertices);
    final Int32List vertexRing = Int32List(vertices);
    final Float64List sigma = Float64List(3 * vertices);
    final Float64List nu = Float64List(3 * vertices);
    final Float64List tau = Float64List(3 * vertices);
    for (int v = 0; v < vertices; v++) {
      final int row = vertexRow[v];
      for (int a = 0; a < 3; a++) {
        positions[3 * v + a] = mesh.positions[3 * row + a];
        normals[3 * v + a] = mesh.normals[3 * row + a];
      }
      final int r = ringOfPoint[pointOf[row]];
      vertexRing[v] = r;
      if (ringRun[r] < 0) {
        continue;
      }
      final List<double> t = <double>[
        for (int a = 0; a < 3; a++) ringRest[12 * r + 3 + a],
      ];
      final List<double> side = <double>[
        for (int a = 0; a < 3; a++) ringRest[12 * r + 6 + a],
      ];
      final List<double> up = <double>[
        for (int a = 0; a < 3; a++) ringRest[12 * r + 9 + a],
      ];
      final List<double> e = <double>[
        for (int a = 0; a < 3; a++) positions[3 * v + a] - centroid[3 * r + a],
      ];
      final List<double> n = <double>[
        for (int a = 0; a < 3; a++) normals[3 * v + a].toDouble(),
      ];
      final double ex = _dot(e, side);
      final double ey = _dot(e, up);
      sigma
        ..[3 * v] = ex
        ..[3 * v + 1] = ey
        ..[3 * v + 2] = _dot(e, t);
      final double nx = _dot(n, side);
      final double ny = _dot(n, up);
      final double nz = _dot(n, t);
      nu
        ..[3 * v] = nx
        ..[3 * v + 1] = ny
        ..[3 * v + 2] = nz;
      // A thread faces straight out from its centre; a cap keeps facing
      // along the chain.
      final double qx = ex / ringExtent[2 * r];
      final double qy = ey / ringExtent[2 * r + 1];
      final double q = math.sqrt(qx * qx + qy * qy);
      if (nz.abs() > 0.7 || q < 1e-6) {
        tau
          ..[3 * v] = nx
          ..[3 * v + 1] = ny
          ..[3 * v + 2] = nz;
      } else {
        tau
          ..[3 * v] = qx / q
          ..[3 * v + 1] = qy / q
          ..[3 * v + 2] = 0;
      }
    }
    final Uint32List indices = Uint32List(corners);
    for (int k = 0; k < corners; k++) {
      indices[k] = vertexOf[mesh.indices[k]];
    }

    return SkinChainBinding._(
      node: mesh.node,
      runStarts: Int32List.fromList(runStarts),
      runEnds: Int32List.fromList(runEnds),
      positions: positions,
      normals: normals,
      indices: indices,
      vertexRing: vertexRing,
      ringRun: ringRun,
      ringAt: ringAt,
      ringRest: ringRest,
      ringOffset: ringOffset,
      ringExtent: ringExtent,
      ringPiece: ringPiece,
      pieceCentres: pieceCentres,
      sigma: sigma,
      nu: nu,
      tau: tau,
      largestNudge: nudge,
    );
  }

  /// The triangle strips in index order, each as the sequence of points it
  /// adds: its first triangle's three, then one a triangle. The two points a
  /// step adds lie on one ring. A strip of fewer than three triangles, whose
  /// order cannot be told, is left out, as is a run of triangles that is not
  /// a strip (a cap's fan, say).
  List<List<int>> _strips(Int32List pointOf) {
    final int triangles = mesh.indices.length ~/ 3;
    final List<List<int>> strips = <List<int>>[];
    final List<List<int>> run = <List<int>>[];
    void close() {
      if (run.length >= 3) {
        final List<int>? sequence = _sequence(run);
        if (sequence != null) {
          strips.add(sequence);
        }
      }
      run.clear();
    }

    for (int t = 0; t < triangles; t++) {
      final List<int> tri = <int>[
        pointOf[mesh.indices[3 * t]],
        pointOf[mesh.indices[3 * t + 1]],
        pointOf[mesh.indices[3 * t + 2]],
      ];
      if (tri[0] == tri[1] || tri[1] == tri[2] || tri[0] == tri[2]) {
        close();
        continue;
      }
      if (run.isNotEmpty &&
          tri.where((int p) => run.last.contains(p)).length != 2) {
        close();
      }
      run.add(tri);
    }
    close();
    return strips;
  }

  /// The points [run] adds in order, or null if it is not a strip.
  static List<int>? _sequence(List<List<int>> run) {
    final List<int> t0 = run[0];
    final List<int> t1 = run[1];
    final List<int> t2 = run[2];
    final List<int> dropped = <int>[
      for (final int p in t0)
        if (!t1.contains(p)) p,
    ];
    final List<int> shared = <int>[
      for (final int p in t0)
        if (t1.contains(p)) p,
    ];
    final List<int> leaving = <int>[
      for (final int p in shared)
        if (!t2.contains(p)) p,
    ];
    if (dropped.length != 1 || shared.length != 2 || leaving.length != 1) {
      return null;
    }
    final List<int> sequence = <int>[
      dropped.single,
      leaving.single,
      shared.firstWhere((int p) => p != leaving.single),
    ];
    for (int i = 1; i < run.length; i++) {
      final int last = sequence[sequence.length - 1];
      final int before = sequence[sequence.length - 2];
      if (!run[i].contains(last) || !run[i].contains(before)) {
        return null;
      }
      sequence.add(run[i].firstWhere((int p) => p != last && p != before));
    }
    return sequence;
  }

  /// How far along from [a] to [b] ring [r]'s centre is, and how far off
  /// the straight line between them, on the finished fold.
  static (double, double) _across(
    Float64List centres,
    int a,
    int b,
    Float64List centroid,
    int r,
  ) {
    double ab = 0;
    double ap = 0;
    for (int k = 0; k < 3; k++) {
      final double d = centres[3 * b + k] - centres[3 * a + k];
      ab += d * d;
      ap += (centroid[3 * r + k] - centres[3 * a + k]) * d;
    }
    final double u = ab > 0 ? ap / ab : 0;
    final double w = u.clamp(0.0, 1.0);
    double off = 0;
    for (int k = 0; k < 3; k++) {
      final double on =
          centres[3 * a + k] + (centres[3 * b + k] - centres[3 * a + k]) * w;
      off += (centroid[3 * r + k] - on) * (centroid[3 * r + k] - on);
    }
    return (u, math.sqrt(off));
  }

  /// Ring [r]'s width and thickness axes: square to [tangent], the width
  /// along the ring's widest spread.
  (List<double>, List<double>) _axes(
    List<double> tangent,
    List<int> ringPoints,
    Int32List pointRow,
    Float64List centroid,
    int r,
  ) {
    final List<double> e1 = <double>[0, 0, 0];
    final List<double> axis = tangent[0].abs() < 0.9
        ? <double>[1, 0, 0]
        : <double>[0, 1, 0];
    _cross(tangent, axis, e1);
    SkinChain._normalise(e1);
    final List<double> e2 = <double>[0, 0, 0];
    _cross(tangent, e1, e2);
    double xx = 0;
    double yy = 0;
    double xy = 0;
    for (final int p in ringPoints) {
      final int row = pointRow[p];
      final List<double> e = <double>[
        for (int a = 0; a < 3; a++)
          mesh.positions[3 * row + a] - centroid[3 * r + a],
      ];
      final double x = _dot(e, e1);
      final double y = _dot(e, e2);
      xx += x * x;
      yy += y * y;
      xy += x * y;
    }
    final double theta = 0.5 * math.atan2(2 * xy, xx - yy);
    final List<double> side = <double>[
      for (int a = 0; a < 3; a++)
        math.cos(theta) * e1[a] + math.sin(theta) * e2[a],
    ];
    final List<double> up = <double>[0, 0, 0];
    _cross(tangent, side, up);
    return (side, up);
  }

  /// Keeps each run's rings in order along every strip, pooling any that
  /// come out of order; returns the furthest a ring was moved, in residues.
  static double _order(
    List<List<int>> strips,
    Int32List ringOfPoint,
    Int32List ringRun,
    Float64List ringAt,
  ) {
    final Set<String> seen = <String>{};
    double furthest = 0;
    for (final List<int> strip in strips) {
      final List<int> order = <int>[];
      for (int j = 0; j < strip.length; j += 2) {
        final int r = ringOfPoint[strip[j]];
        if (ringRun[r] < 0) {
          continue;
        }
        if (order.isEmpty || order.last != r) {
          order.add(r);
        }
      }
      if (order.length < 3 || !seen.add(order.join(','))) {
        continue;
      }
      // Split where the run changes.
      int from = 0;
      for (int k = 1; k <= order.length; k++) {
        if (k == order.length || ringRun[order[k]] != ringRun[order[from]]) {
          furthest = math.max(
            furthest,
            _pool(order.sublist(from, k), ringAt),
          );
          from = k;
        }
      }
    }
    return furthest;
  }

  /// Pool adjacent violators over [rings], in the direction they mostly run.
  static double _pool(List<int> rings, Float64List ringAt) {
    if (rings.length < 2) {
      return 0;
    }
    final double sign = ringAt[rings.last] >= ringAt[rings.first] ? 1 : -1;
    final List<double> sums = <double>[];
    final List<int> counts = <int>[];
    for (final int r in rings) {
      sums.add(sign * ringAt[r]);
      counts.add(1);
      while (sums.length > 1 &&
          sums[sums.length - 2] / counts[counts.length - 2] >
              sums.last / counts.last) {
        sums[sums.length - 2] += sums.last;
        counts[counts.length - 2] += counts.last;
        sums.removeLast();
        counts.removeLast();
      }
    }
    double furthest = 0;
    int k = 0;
    for (int block = 0; block < sums.length; block++) {
      final double value = sign * sums[block] / counts[block];
      for (int j = 0; j < counts[block]; j++, k++) {
        final int r = rings[k];
        if (ringAt[r] != value) {
          furthest = math.max(furthest, (ringAt[r] - value).abs());
          ringAt[r] = value;
        }
      }
    }
    return furthest;
  }

  /// Groups rows of equal words: each row's group, and each group's first
  /// row. Rows are the concatenation of each of [arrays]' [widths] words.
  static (Int32List, Int32List) _group(
    List<Uint32List> arrays,
    List<int> widths,
    int rows,
  ) {
    int capacity = 16;
    while (capacity < 2 * rows) {
      capacity <<= 1;
    }
    final Int32List table = Int32List(capacity)..fillRange(0, capacity, -1);
    final Int32List groupOf = Int32List(rows);
    final List<int> firstRow = <int>[];
    bool same(int x, int y) {
      for (int k = 0; k < arrays.length; k++) {
        final int w = widths[k];
        for (int j = 0; j < w; j++) {
          if (arrays[k][w * x + j] != arrays[k][w * y + j]) {
            return false;
          }
        }
      }
      return true;
    }

    for (int row = 0; row < rows; row++) {
      int h = 17;
      for (int k = 0; k < arrays.length; k++) {
        final int w = widths[k];
        for (int j = 0; j < w; j++) {
          h = (h * 31 + arrays[k][w * row + j]) & 0x3fffffff;
        }
      }
      h ^= h >> 13;
      int slot = h & (capacity - 1);
      while (true) {
        final int group = table[slot];
        if (group < 0) {
          table[slot] = firstRow.length;
          groupOf[row] = firstRow.length;
          firstRow.add(row);
          break;
        }
        if (same(firstRow[group], row)) {
          groupOf[row] = group;
          break;
        }
        slot = (slot + 1) & (capacity - 1);
      }
    }
    return (groupOf, Int32List.fromList(firstRow));
  }

  static int _find(Int32List parent, int x) {
    int p = x;
    while (parent[p] != p) {
      parent[p] = parent[parent[p]];
      p = parent[p];
    }
    return p;
  }

  static void _union(Int32List parent, int x, int y) {
    final int a = _find(parent, x);
    final int b = _find(parent, y);
    if (a != b) {
      parent[b] = a;
    }
  }

  static double _dot(List<double> a, List<double> b) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

  static void _cross(List<double> a, List<double> b, List<double> out) {
    final double x = a[1] * b[2] - a[2] * b[1];
    final double y = a[2] * b[0] - a[0] * b[2];
    final double z = a[0] * b[1] - a[1] * b[0];
    out
      ..[0] = x
      ..[1] = y
      ..[2] = z;
  }
}

/// A place on the backbone a ring's centre could be bound to.
final class _Candidate {
  const _Candidate(this.run, this.at, this.distance);
  final int run;
  final double at;
  final double distance;
}

/// A chain's ordered runs on the finished fold, sampled to search.
final class _Runs {
  _Runs(this.centres, this.starts, this.ends) {
    for (int run = 0; run < starts.length; run++) {
      final int m = ends[run] - starts[run];
      _first.add(_at.length);
      if (m == 1) {
        _add(run, 0);
      } else {
        final int last = (m - 1) * _ChainBinder._samples;
        for (int j = 0; j <= last; j++) {
          _add(run, j / _ChainBinder._samples);
        }
      }
      _last.add(_at.length - 1);
    }
  }

  final Float64List centres;
  final List<int> starts;
  final List<int> ends;

  final List<int> _run = <int>[];
  final List<double> _at = <double>[];
  final List<double> _xyz = <double>[];
  final List<int> _first = <int>[];
  final List<int> _last = <int>[];
  final Map<int, List<int>> _cells = <int, List<int>>{};
  double _cell = 0;

  final List<double> _point = <double>[0, 0, 0];
  final List<double> _tangent = <double>[0, 0, 0];

  void _add(int run, double at) {
    this.at(run, at, _point, _tangent);
    _run.add(run);
    _at.add(at);
    _xyz.addAll(_point);
  }

  /// The backbone's point and direction [s] residues along [run].
  void at(int run, double s, List<double> point, List<double> tangent) {
    final int start = starts[run];
    final int m = ends[run] - start;
    if (m == 1) {
      for (int a = 0; a < 3; a++) {
        point[a] = centres[3 * start + a];
        tangent[a] = a == 0 ? 1 : 0;
      }
      return;
    }
    final int k = math.min(s.floor(), m - 2);
    catmullRom(centres, start, m, k, s - k, point, tangent);
  }

  int _key(double x, double y, double z) {
    final int ix = (x / _cell).floor() + 512;
    final int iy = (y / _cell).floor() + 512;
    final int iz = (z / _cell).floor() + 512;
    return (ix * 1024 + iy) * 1024 + iz;
  }

  /// The places within [reach] of (x, y, z) where the backbone comes
  /// closest, nearest first, no two within half a residue on one run.
  List<_Candidate> candidates(double x, double y, double z, double reach) {
    if (_cell != reach) {
      _cell = reach;
      _cells.clear();
      for (int i = 0; i < _at.length; i++) {
        _cells
            .putIfAbsent(
              _key(_xyz[3 * i], _xyz[3 * i + 1], _xyz[3 * i + 2]),
              () => <int>[],
            )
            .add(i);
      }
    }
    double distance(int i) {
      final double dx = _xyz[3 * i] - x;
      final double dy = _xyz[3 * i + 1] - y;
      final double dz = _xyz[3 * i + 2] - z;
      return math.sqrt(dx * dx + dy * dy + dz * dz);
    }

    final List<_Candidate> found = <_Candidate>[];
    final int ix = (x / _cell).floor() + 512;
    final int iy = (y / _cell).floor() + 512;
    final int iz = (z / _cell).floor() + 512;
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        for (int dz = -1; dz <= 1; dz++) {
          final List<int>? cell =
              _cells[((ix + dx) * 1024 + iy + dy) * 1024 + iz + dz];
          if (cell == null) {
            continue;
          }
          for (final int i in cell) {
            final double d = distance(i);
            if (d >= reach) {
              continue;
            }
            final int run = _run[i];
            final double before = i > _first[run] ? distance(i - 1) : double.infinity;
            final double after = i < _last[run] ? distance(i + 1) : double.infinity;
            if (d > before || d > after) {
              continue;
            }
            found.add(_refine(run, i, x, y, z));
          }
        }
      }
    }
    found.sort((_Candidate a, _Candidate b) => a.distance.compareTo(b.distance));
    final List<_Candidate> kept = <_Candidate>[];
    for (final _Candidate c in found) {
      if (kept.every(
        (_Candidate k) => k.run != c.run || (k.at - c.at).abs() >= 0.5,
      )) {
        kept.add(c);
      }
    }
    return kept;
  }

  /// The closest place to (x, y, z) between the samples either side of [i].
  _Candidate _refine(int run, int i, double x, double y, double z) {
    final int m = ends[run] - starts[run];
    if (m == 1) {
      final int c = 3 * starts[run];
      final double dx = centres[c] - x;
      final double dy = centres[c + 1] - y;
      final double dz = centres[c + 2] - z;
      return _Candidate(run, 0, math.sqrt(dx * dx + dy * dy + dz * dz));
    }
    double lo = i > _first[run] ? _at[i - 1] : _at[i];
    double hi = i < _last[run] ? _at[i + 1] : _at[i];
    double measure(double s) {
      at(run, s, _point, _tangent);
      final double dx = _point[0] - x;
      final double dy = _point[1] - y;
      final double dz = _point[2] - z;
      return dx * dx + dy * dy + dz * dz;
    }

    const double phi = 0.6180339887498949;
    double c = hi - (hi - lo) * phi;
    double d = lo + (hi - lo) * phi;
    double fc = measure(c);
    double fd = measure(d);
    for (int step = 0; step < 40; step++) {
      if (fc < fd) {
        hi = d;
        d = c;
        fd = fc;
        c = hi - (hi - lo) * phi;
        fc = measure(c);
      } else {
        lo = c;
        c = d;
        fc = fd;
        d = lo + (hi - lo) * phi;
        fd = measure(d);
      }
    }
    final double s = (lo + hi) / 2;
    return _Candidate(run, s, math.sqrt(measure(s)));
  }
}
