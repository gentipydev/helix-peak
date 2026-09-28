import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'fold_geometry.dart';
import 'fold_timeline.dart';
import 'folding_track.dart';

/// A colour as a GPU takes it: linear red, green and blue.
typedef LinearColour = (double r, double g, double b);

/// The colours the fold is drawn in, already linear.
@immutable
final class FoldPalette {
  const FoldPalette({
    required this.chains,
    required this.loose,
    required this.bridge,
    required this.property,
  });

  /// Each chain's colour, by the model node it is drawn as.
  final Map<String, LinearColour> chains;

  /// A residue the entry never placed.
  final LinearColour loose;

  /// The bridges, and a cysteine about to form one.
  final LinearColour bridge;

  /// The colour the grid gives a residue's property, by its letter.
  final LinearColour Function(String letter) property;
}

/// One chain's backbone: a swept tube whose rings are [FoldMesh.ring]
/// vertices round, [FoldMesh.samplesFor] rings a residue.
final class FoldTube {
  FoldTube._(this.start, this.end, this.stations)
    : positions = Float32List(3 * stations * FoldMesh.ring),
      normals = Float32List(3 * stations * FoldMesh.ring),
      colours = Float32List(4 * stations * FoldMesh.ring),
      indices = _stitch(stations);

  /// Its residues, as a range of [FoldGeometry.drawn].
  final int start;
  final int end;

  /// Rings along it: one on every residue, and the samples between.
  final int stations;

  final Float32List positions;
  final Float32List normals;

  /// Four per vertex, fixed: the chain's colour, or a loose stretch's.
  final Float32List colours;

  /// Fixed: the topology never changes, so a GPU buffer can be updated in
  /// place frame after frame.
  final Uint32List indices;

  /// The rings joined into a tube, wound as flutter_scene winds its own
  /// swept geometry: round each ring with `binormal = tangent × normal`, so
  /// that the outside faces out.
  static Uint32List _stitch(int stations) {
    const int k = FoldMesh.ring;
    final Uint32List out = Uint32List(6 * k * (stations - 1));
    int o = 0;
    for (int s = 0; s + 1 < stations; s++) {
      for (int j = 0; j < k; j++) {
        final int a = s * k + j;
        final int b = s * k + (j + 1) % k;
        final int c = (s + 1) * k + j;
        final int d = (s + 1) * k + (j + 1) % k;
        out
          ..[o++] = a
          ..[o++] = b
          ..[o++] = c
          ..[o++] = b
          ..[o++] = d
          ..[o++] = c;
      }
    }
    return out;
  }
}

/// Everything the fold's scene draws at one moment, in arrays a GPU mesh
/// takes in place: each chain's backbone as a tube, each residue as a bead,
/// and each bridge as the rods the model draws it with.
///
/// The residues start as beads on a thin thread. The water-avoiding ones
/// take their property's colour as the chain collapses round them. As each
/// residue settles, its bead melts into the backbone, and the backbone
/// takes the shape the model gives that residue: an oval for a helix, a
/// flat arrow for a strand, a thin loop for the rest. The cysteines of the
/// model's bridges stay beads until their bridge snaps shut, which it does
/// along the very atoms the model's rods run through. So at `t = 1` every
/// ordered residue's bead is gone, the tube runs where the model's ribbon
/// was measured to run, lying the way it lies (through the CA, where it was
/// not measured), as wide and as thick as the model draws it, and each
/// bridge is the model's rods. What is left over is only the residues the
/// entry never placed, which the model does not draw.
///
/// Positions are in the scene's own frame, which is the model's with its z
/// turned round: flutter_scene bakes a glTF into its native frame by
/// negating z (`GltfCoordinatePolicy.bakeNative`), and the fold has to land
/// on the model as the scene holds it.
final class FoldMesh {
  FoldMesh(this.timeline, this.palette)
    : samples = samplesFor(timeline.geometry.length),
      bead = beadFor(timeline.geometry) {
    final FoldGeometry g = geometry;
    tubes = <FoldTube>[
      for (final (int start, int end) in g.chainRuns)
        if (end - start >= 2) FoldTube._(start, end, (end - start - 1) * samples + 1),
    ];
    final int spheres = g.length + _spheresPerBridge * g.bridges.length;
    sphereCentres = Float32List(3 * spheres);
    sphereRadii = Float32List(spheres);
    sphereColours = Float32List(4 * spheres);
    final int rods = _rodsPerBridge * g.bridges.length;
    rodFrom = Float32List(3 * rods);
    rodTo = Float32List(3 * rods);
    rodRadii = Float32List(rods);
    _native = Float64List(3 * g.length);
    _layOut();
    update(0);
  }

  final FoldTimeline timeline;
  final FoldPalette palette;

  FoldGeometry get geometry => timeline.geometry;

  /// Vertices round each ring of a tube.
  static const int ring = 8;

  /// Rings a residue: fewer for a long chain, so that CFTR's 1,480 residues
  /// cost no more a frame than a few hundred would.
  static int samplesFor(int residues) => residues <= 200
      ? 8
      : residues <= 600
      ? 6
      : 4;

  final int samples;

  /// One per chain of two residues or more.
  late final List<FoldTube> tubes;

  /// The beads, one per drawn residue in [FoldGeometry.drawn]'s order, then
  /// for each bridge the four joints its rods bend at (CB, SG, SG, CB) and
  /// the two tips that grow towards each other. A radius of 0 is not drawn.
  late final Float32List sphereCentres;
  late final Float32List sphereRadii;
  late final Float32List sphereColours;

  /// The rods: for each bridge, three from each cysteine's CA, through its
  /// CB and SG, to the middle of the SG–SG bond. A radius of 0 is not drawn.
  late final Float32List rodFrom;
  late final Float32List rodTo;
  late final Float32List rodRadii;

  int get sphereCount => sphereRadii.length;
  int get rodCount => rodRadii.length;

  /// The tube a residue is before it settles, in angstroms.
  static const double threadRadius = 0.35;

  /// A bead's radius, in angstroms, and a loose residue's against it.
  final double bead;
  static const double looseBead = 0.72;

  /// Beads as large as the unfolded chain leaves room for, so that each
  /// residue stays a bead of its own rather than running into the next:
  /// [beadShare] of the middle gap between neighbours, and never outside
  /// [beadRange]. A short chain spreads out; a long one is packed into the
  /// same frame, closer.
  static const double beadShare = 0.42;
  static const (double, double) beadRange = (0.7, 1.4);

  static double beadFor(FoldGeometry g) {
    final List<double> gaps = <double>[];
    final Float64List u = g.unfolded;
    for (final (int start, int end) in g.chainRuns) {
      for (int i = start; i + 1 < end; i++) {
        final double dx = u[3 * i + 3] - u[3 * i];
        final double dy = u[3 * i + 4] - u[3 * i + 1];
        final double dz = u[3 * i + 5] - u[3 * i + 2];
        gaps.add(math.sqrt(dx * dx + dy * dy + dz * dz) / g.unit);
      }
    }
    if (gaps.isEmpty) {
      return beadRange.$2;
    }
    gaps.sort();
    return (beadShare * gaps[gaps.length ~/ 2]).clamp(
      beadRange.$1,
      beadRange.$2,
    );
  }

  /// A strand's arrowhead, at its widest, against the strand's own width:
  /// what PyMOL's is, measured on the stored models.
  static const double arrowWidening = 1.7;

  /// How far into its step a residue's bead starts to melt.
  static const double _meltFrom = 0.3;

  static const int _spheresPerBridge = 6;
  static const int _rodsPerBridge = 6;

  /// The timeline's positions, in the scene's frame, for the frame last
  /// updated.
  late final Float64List _native;

  // Per residue and fixed: where the model has it end up, in model units.
  late final Float64List _finalWidth;
  late final Float64List _finalThickness;
  late final Float64List _finalPower;
  late final List<bool> _bridged;

  /// The ring's angles, once.
  static final Float64List _cos = Float64List.fromList(<double>[
    for (int j = 0; j < ring; j++) math.cos(2 * math.pi * j / ring),
  ]);
  static final Float64List _sin = Float64List.fromList(<double>[
    for (int j = 0; j < ring; j++) math.sin(2 * math.pi * j / ring),
  ]);

  /// The fixed parts: each residue's final section, and the colours.
  void _layOut() {
    final FoldGeometry g = geometry;
    final FoldCartoon cartoon = g.track.cartoon;
    final double unit = g.unit;
    final int n = g.length;
    _finalWidth = Float64List(n);
    _finalThickness = Float64List(n);
    _finalPower = Float64List(n)..fillRange(0, n, 2);
    _bridged = List<bool>.filled(n, false);
    for (final (int i, int j) in g.bridges) {
      _bridged[i] = true;
      _bridged[j] = true;
    }

    for (final (int start, int end) in g.chainRuns) {
      for (int i = start; i < end; i++) {
        final FoldResidue r = g.drawn[i];
        double width;
        double thickness;
        if (!r.isOrdered) {
          width = thickness = threadRadius;
        } else if (cartoon.representation == FoldRepresentation.tube) {
          width = thickness = cartoon.tubeRadius;
        } else {
          switch (r.shape!) {
            case FoldShape.helix:
              width = cartoon.helixHalfWidth;
              thickness = cartoon.helixHalfThickness;
            case FoldShape.strand:
              // The arrow: widest one residue before the strand's last, and
              // closing to a point on the last.
              final bool last = !_isStrand(g, i + 1, end);
              final bool beforeLast =
                  !last && !_isStrand(g, i + 2, end);
              if (last) {
                width = thickness = cartoon.loopRadius;
              } else {
                width = cartoon.strandHalfWidth *
                    (beforeLast ? arrowWidening : 1);
                thickness = cartoon.strandHalfThickness;
                _finalPower[i] = 4;
              }
            case FoldShape.coil:
              width = thickness = cartoon.loopRadius;
          }
        }
        _finalWidth[i] = width * unit;
        _finalThickness[i] = thickness * unit;
      }
    }

    // A tube's colour at each ring: its nearer residue's.
    for (final FoldTube tube in tubes) {
      int v = 0;
      for (int s = 0; s < tube.stations; s++) {
        final int k = tube.start + (s + samples ~/ 2) ~/ samples;
        final FoldResidue r = g.drawn[math.min(k, tube.end - 1)];
        final LinearColour colour = r.isOrdered
            ? palette.chains[_nodeOf(k)] ?? palette.loose
            : palette.loose;
        for (int j = 0; j < ring; j++, v++) {
          tube.colours
            ..[4 * v] = colour.$1
            ..[4 * v + 1] = colour.$2
            ..[4 * v + 2] = colour.$3
            ..[4 * v + 3] = 1;
        }
      }
    }

    // The bridges are one colour throughout.
    for (int s = g.length; s < sphereCount; s++) {
      _colour(s, palette.bridge);
    }
  }

  static bool _isStrand(FoldGeometry g, int i, int end) =>
      i < end && g.drawn[i].isOrdered && g.drawn[i].shape == FoldShape.strand;

  String _nodeOf(int i) {
    final FoldGeometry g = geometry;
    for (int c = 0; c < g.chainRuns.length; c++) {
      if (i < g.chainRuns[c].$2) {
        return g.track.chains[c].node;
      }
    }
    return g.track.chains.last.node;
  }

  /// Moves everything to [t], with loose residues moved on by [idle]
  /// seconds of the screen's clock.
  void update(double t, {double idle = 0}) {
    final FoldGeometry g = geometry;
    final FoldFrame frame = timeline.frameAt(t, idle: idle);
    final Float64List p = frame.positions;
    for (int i = 0; i < g.length; i++) {
      _native
        ..[3 * i] = p[3 * i]
        ..[3 * i + 1] = p[3 * i + 1]
        ..[3 * i + 2] = -p[3 * i + 2];
    }
    for (final FoldTube tube in tubes) {
      _sweep(tube, frame);
    }
    _beads(frame);
    _bridges(frame);
  }

  /// How settled residue [i] is: 0 as the chain lies after the collapse, 1 in
  /// the model's place. A loose residue never settles.
  double _settled(int i, FoldFrame frame) {
    final FoldResidue r = geometry.drawn[i];
    if (!r.isOrdered) {
      return 0;
    }
    return r.shape == FoldShape.helix ? frame.coil : frame.pair;
  }

  // -- the backbone ------------------------------------------------------------

  void _sweep(FoldTube tube, FoldFrame frame) {
    final FoldGeometry g = geometry;
    final int m = tube.end - tube.start;
    final double thread = threadRadius * g.unit;

    // The points the tube runs through: each residue's CA, until it
    // settles onto where the model's ribbon was measured to pass it. A
    // strand the model's ribbon was not measured by is smoothed of its
    // pleat instead, as PyMOL's flat sheets are.
    final Float64List c = Float64List(3 * m);
    final Float64List settled = Float64List(m);
    final Float64List width = Float64List(m);
    final Float64List thickness = Float64List(m);
    final Float64List power = Float64List(m);
    for (int k = 0; k < m; k++) {
      final int i = tube.start + k;
      final FoldResidue r = g.drawn[i];
      final double s = _settled(i, frame);
      settled[k] = s;
      final ModelPoint? on = r.ribbonAt;
      final bool smooth =
          on == null &&
          r.isOrdered &&
          r.shape == FoldShape.strand &&
          k > 0 &&
          k + 1 < m &&
          g.drawn[i - 1].isOrdered &&
          g.drawn[i + 1].isOrdered;
      for (int a = 0; a < 3; a++) {
        final double here = _native[3 * i + a];
        final double there = on == null
            ? (smooth
                  ? (_native[3 * (i - 1) + a] +
                            2 * here +
                            _native[3 * (i + 1) + a]) /
                        4
                  : here)
            : (a == 0 ? on.$1 : (a == 1 ? on.$2 : -on.$3));
        c[3 * k + a] = here + s * (there - here);
      }
      width[k] = thread + (_finalWidth[i] - thread) * s;
      thickness[k] = thread + (_finalThickness[i] - thread) * s;
      power[k] = 2 + (_finalPower[i] - 2) * s;
    }

    // Each residue's width axis: across a helix, along its axis, which is
    // the tangent crossed with the way the chain curves there; across a
    // strand the same, flipped as the pleat alternates. As it settles, it
    // turns to the way the model's ribbon was measured to lie. Kept from
    // turning over from one residue to the next.
    final Float64List across = Float64List(3 * m);
    final List<double> t = <double>[0, 0, 0];
    final List<double> w = <double>[0, 0, 0];
    final List<double> previous = <double>[0, 0, 0];
    for (int k = 0; k < m; k++) {
      final int before = math.max(0, k - 1);
      final int after = math.min(m - 1, k + 1);
      for (int a = 0; a < 3; a++) {
        t[a] = c[3 * after + a] - c[3 * before + a];
      }
      _normalise(t);
      bool curved = false;
      if (k > 0 && k + 1 < m) {
        final List<double> bend = <double>[
          for (int a = 0; a < 3; a++)
            (c[3 * before + a] + c[3 * after + a]) / 2 - c[3 * k + a],
        ];
        _reject(bend, t);
        if (_length(bend) > 0.05 * g.unit) {
          _normalise(bend);
          _cross(t, bend, w);
          curved = true;
        }
      }
      if (!curved) {
        if (k == 0) {
          _anyPerpendicular(t, w);
        } else {
          w
            ..[0] = previous[0]
            ..[1] = previous[1]
            ..[2] = previous[2];
          _reject(w, t);
          if (_length(w) < 1e-9) {
            _anyPerpendicular(t, w);
          }
          _normalise(w);
        }
      }
      final ModelPoint? lies = g.drawn[tube.start + k].ribbonAcross;
      if (lies != null && settled[k] > 0) {
        final List<double> measured = <double>[lies.$1, lies.$2, -lies.$3];
        _reject(measured, t);
        if (_length(measured) > 1e-9) {
          _normalise(measured);
          final double sign =
              measured[0] * w[0] + measured[1] * w[1] + measured[2] * w[2] < 0
              ? -1
              : 1;
          for (int a = 0; a < 3; a++) {
            w[a] += (sign * measured[a] - w[a]) * settled[k];
          }
          if (_length(w) < 1e-9) {
            w
              ..[0] = measured[0]
              ..[1] = measured[1]
              ..[2] = measured[2];
          }
          _normalise(w);
        }
      }
      if (k > 0 && w[0] * previous[0] + w[1] * previous[1] + w[2] * previous[2] < 0) {
        w
          ..[0] = -w[0]
          ..[1] = -w[1]
          ..[2] = -w[2];
      }
      across
        ..[3 * k] = w[0]
        ..[3 * k + 1] = w[1]
        ..[3 * k + 2] = w[2];
      previous
        ..[0] = w[0]
        ..[1] = w[1]
        ..[2] = w[2];
    }

    // The rings: a Catmull–Rom spline through the points, each ring a
    // superellipse across it, from an oval (a power of 2) to a slab (4).
    final Float32List out = tube.positions;
    final Float32List normals = tube.normals;
    final List<double> centre = <double>[0, 0, 0];
    final List<double> tangent = <double>[0, 0, 0];
    final List<double> side = <double>[0, 0, 0];
    final List<double> up = <double>[0, 0, 0];
    int v = 0;
    for (int s = 0; s < tube.stations; s++) {
      final int k = math.min(s ~/ samples, m - 2);
      final double u = (s - k * samples) / samples;
      _spline(c, m, k, u, centre, tangent);
      _normalise(tangent);
      for (int a = 0; a < 3; a++) {
        side[a] = across[3 * k + a] + (across[3 * (k + 1) + a] - across[3 * k + a]) * u;
      }
      _reject(side, tangent);
      if (_length(side) < 1e-9) {
        side
          ..[0] = across[3 * k]
          ..[1] = across[3 * k + 1]
          ..[2] = across[3 * k + 2];
        _reject(side, tangent);
      }
      _normalise(side);
      _cross(tangent, side, up);
      final double a = width[k] + (width[k + 1] - width[k]) * u;
      final double b = thickness[k] + (thickness[k + 1] - thickness[k]) * u;
      final double e = power[k] + (power[k + 1] - power[k]) * u;
      final bool oval = (e - 2).abs() < 1e-3;
      for (int j = 0; j < ring; j++, v++) {
        final double cj = _cos[j];
        final double sj = _sin[j];
        double x;
        double y;
        double nx;
        double ny;
        if (oval) {
          x = a * cj;
          y = b * sj;
          nx = cj / a;
          ny = sj / b;
        } else {
          final double shape = 2 / e;
          final double slope = shape * (e - 1);
          x = a * _signedPow(cj, shape);
          y = b * _signedPow(sj, shape);
          nx = _signedPow(cj, slope) / a;
          ny = _signedPow(sj, slope) / b;
        }
        double lx = side[0] * nx + up[0] * ny;
        double ly = side[1] * nx + up[1] * ny;
        double lz = side[2] * nx + up[2] * ny;
        final double l = math.sqrt(lx * lx + ly * ly + lz * lz);
        if (l > 0) {
          lx /= l;
          ly /= l;
          lz /= l;
        }
        out
          ..[3 * v] = centre[0] + side[0] * x + up[0] * y
          ..[3 * v + 1] = centre[1] + side[1] * x + up[1] * y
          ..[3 * v + 2] = centre[2] + side[2] * x + up[2] * y;
        normals
          ..[3 * v] = lx
          ..[3 * v + 1] = ly
          ..[3 * v + 2] = lz;
      }
    }
  }

  /// The point [u] of the way from control point [k] to the next, and the
  /// direction the curve runs there: a uniform Catmull–Rom spline, which
  /// passes through every control point, with its ends continued straight.
  static void _spline(
    Float64List c,
    int m,
    int k,
    double u,
    List<double> point,
    List<double> tangent,
  ) {
    final double u2 = u * u;
    final double u3 = u2 * u;
    for (int a = 0; a < 3; a++) {
      final double p1 = c[3 * k + a];
      final double p2 = c[3 * (k + 1) + a];
      final double p0 = k > 0 ? c[3 * (k - 1) + a] : 2 * p1 - p2;
      final double p3 = k + 2 < m ? c[3 * (k + 2) + a] : 2 * p2 - p1;
      point[a] =
          0.5 *
          (2 * p1 +
              (-p0 + p2) * u +
              (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 +
              (-p0 + 3 * p1 - 3 * p2 + p3) * u3);
      tangent[a] =
          0.5 *
          ((-p0 + p2) +
              2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * u +
              3 * (-p0 + 3 * p1 - 3 * p2 + p3) * u2);
    }
  }

  // -- the beads ---------------------------------------------------------------

  void _beads(FoldFrame frame) {
    final FoldGeometry g = geometry;
    // Cysteines turn the bridges' colour as their step begins, and are the
    // colour when the bridge starts to close.
    final double cysteine = _smooth((frame.t - 0.75) / 0.0875);
    for (int i = 0; i < g.length; i++) {
      final FoldResidue r = g.drawn[i];
      _centre(i, _native[3 * i], _native[3 * i + 1], _native[3 * i + 2]);
      if (!r.isOrdered) {
        sphereRadii[i] = looseBead * bead * g.unit;
        _colour(i, palette.loose);
        continue;
      }
      LinearColour colour = palette.chains[_nodeOf(i)] ?? palette.loose;
      if (isWaterAvoiding(r.letter) && frame.emphasis > 0) {
        colour = _mix(colour, palette.property(r.letter), frame.emphasis);
      }
      double scale;
      if (_bridged[i]) {
        colour = _mix(colour, palette.bridge, cysteine);
        final int b = _bridgeOf(i);
        scale = 1 - frame.closure[b];
      } else {
        scale = 1 - _smooth((_settled(i, frame) - _meltFrom) / (1 - _meltFrom));
      }
      sphereRadii[i] = bead * g.unit * scale;
      _colour(i, colour);
    }
  }

  int _bridgeOf(int i) {
    final List<(int, int)> bridges = geometry.bridges;
    for (int b = 0; b < bridges.length; b++) {
      if (bridges[b].$1 == i || bridges[b].$2 == i) {
        return b;
      }
    }
    return 0;
  }

  // -- the bridges -------------------------------------------------------------

  void _bridges(FoldFrame frame) {
    final FoldGeometry g = geometry;
    final double rod = g.track.cartoon.rodRadius * g.unit;
    for (int b = 0; b < g.bridges.length; b++) {
      final (int i, int j) = g.bridges[b];
      final List<ModelPoint> path = g.bridgePaths[b];
      final double closure = frame.closure[b];
      // The path in the scene's frame, each half carried with its own CA
      // while the hold still keeps the two apart.
      final List<List<double>> q = <List<double>>[
        for (final ModelPoint point in path) <double>[point.$1, point.$2, -point.$3],
      ];
      final List<double> middle = <double>[
        for (int a = 0; a < 3; a++) (q[2][a] + q[3][a]) / 2,
      ];
      for (int half = 0; half < 2; half++) {
        final int residue = half == 0 ? i : j;
        final List<List<double>> run = half == 0
            ? <List<double>>[q[0], q[1], q[2], middle]
            : <List<double>>[q[5], q[4], q[3], middle];
        final List<double> shift = <double>[
          for (int a = 0; a < 3; a++) _native[3 * residue + a] - run[0][a],
        ];
        final List<List<double>> at = <List<double>>[
          for (final List<double> point in run)
            <double>[for (int a = 0; a < 3; a++) point[a] + shift[a]],
        ];
        final List<double> lengths = <double>[
          for (int s = 0; s < 3; s++) _distance(at[s], at[s + 1]),
        ];
        double left = closure * (lengths[0] + lengths[1] + lengths[2]);
        List<double> tip = at[0];
        for (int s = 0; s < 3; s++) {
          final int r = b * _rodsPerBridge + half * 3 + s;
          final int joint = g.length + b * _spheresPerBridge + half * 2 + s;
          final double grown = math.min(left, lengths[s]);
          left -= grown;
          if (closure <= 0 || grown <= 0) {
            rodRadii[r] = 0;
            _rod(r, at[s], at[s]);
          } else {
            final double f = lengths[s] == 0 ? 1 : grown / lengths[s];
            tip = <double>[
              for (int a = 0; a < 3; a++) at[s][a] + (at[s + 1][a] - at[s][a]) * f,
            ];
            rodRadii[r] = rod;
            _rod(r, at[s], tip);
          }
          // The joints at the CB and the SG, once the rod has reached them.
          if (s < 2) {
            final bool reached = closure > 0 && left > 0;
            sphereRadii[joint] = reached ? rod : 0;
            _centre(joint, at[s + 1][0], at[s + 1][1], at[s + 1][2]);
          }
        }
        // The growing end, rounded.
        final int end = g.length + b * _spheresPerBridge + 4 + half;
        sphereRadii[end] = closure > 0 ? rod : 0;
        _centre(end, tip[0], tip[1], tip[2]);
      }
    }
  }

  void _rod(int r, List<double> from, List<double> to) {
    rodFrom
      ..[3 * r] = from[0]
      ..[3 * r + 1] = from[1]
      ..[3 * r + 2] = from[2];
    rodTo
      ..[3 * r] = to[0]
      ..[3 * r + 1] = to[1]
      ..[3 * r + 2] = to[2];
  }

  void _centre(int s, double x, double y, double z) {
    sphereCentres
      ..[3 * s] = x
      ..[3 * s + 1] = y
      ..[3 * s + 2] = z;
  }

  void _colour(int s, LinearColour colour) {
    sphereColours
      ..[4 * s] = colour.$1
      ..[4 * s + 1] = colour.$2
      ..[4 * s + 2] = colour.$3
      ..[4 * s + 3] = 1;
  }

  // -- vector arithmetic, in place ----------------------------------------------

  static double _smooth(double x) {
    final double c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static LinearColour _mix(LinearColour a, LinearColour b, double f) => (
    a.$1 + (b.$1 - a.$1) * f,
    a.$2 + (b.$2 - a.$2) * f,
    a.$3 + (b.$3 - a.$3) * f,
  );

  static double _signedPow(double v, double e) =>
      v == 0 ? 0 : (v < 0 ? -math.pow(-v, e).toDouble() : math.pow(v, e).toDouble());

  static double _length(List<double> v) =>
      math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);

  static double _distance(List<double> a, List<double> b) {
    final double dx = a[0] - b[0];
    final double dy = a[1] - b[1];
    final double dz = a[2] - b[2];
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  static void _normalise(List<double> v) {
    final double l = _length(v);
    if (l > 0) {
      v
        ..[0] = v[0] / l
        ..[1] = v[1] / l
        ..[2] = v[2] / l;
    }
  }

  /// Takes out of [v] the part along the unit vector [along].
  static void _reject(List<double> v, List<double> along) {
    final double d = v[0] * along[0] + v[1] * along[1] + v[2] * along[2];
    v
      ..[0] = v[0] - d * along[0]
      ..[1] = v[1] - d * along[1]
      ..[2] = v[2] - d * along[2];
  }

  static void _cross(List<double> a, List<double> b, List<double> out) {
    final double x = a[1] * b[2] - a[2] * b[1];
    final double y = a[2] * b[0] - a[0] * b[2];
    final double z = a[0] * b[1] - a[1] * b[0];
    out
      ..[0] = x
      ..[1] = y
      ..[2] = z;
  }

  static void _anyPerpendicular(List<double> t, List<double> out) {
    final List<double> axis = t[0].abs() < 0.9
        ? <double>[1, 0, 0]
        : <double>[0, 1, 0];
    _cross(t, axis, out);
    _normalise(out);
  }
}
