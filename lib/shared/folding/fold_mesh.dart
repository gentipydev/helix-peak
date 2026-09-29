import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'fold_backbone.dart';
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

/// A thread through a run of residues the entry never placed: a swept tube
/// whose rings are [FoldMesh.ring] vertices round, [FoldMesh.samplesFor]
/// rings a residue, from the placed residue it hangs from to the one it
/// hangs to, if there is one.
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

  /// Four per vertex, fixed: a loose stretch's colour, or its anchor's
  /// chain's.
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

/// What the fold's scene draws at one moment besides the model's own mesh:
/// each residue as a bead, and the residues the entry never placed as a
/// thread, in arrays a GPU mesh takes in place.
///
/// The residues start as beads on a thin thread. The water-avoiding ones
/// take their property's colour as the chain collapses round them. As each
/// residue settles, its bead melts into the backbone, which is the model's
/// own mesh ([FoldSkin]) growing from the thread into the model's shape for
/// it. The cysteines of the model's bridges stay beads until their bridge
/// snaps shut ([FoldBonds]). What is left over is the residues the entry
/// never placed, which the model does not draw: they shrink away as the fold
/// finishes.
///
/// Positions are in the scene's own frame, which is the model's with its z
/// turned round: flutter_scene bakes a glTF into its native frame by
/// negating z (`GltfCoordinatePolicy.bakeNative`), and the fold has to land
/// on the model as the scene holds it.
final class FoldMesh {
  FoldMesh(this.timeline, this.palette)
    : samples = samplesFor(timeline.geometry.length),
      bead = beadFor(timeline.geometry),
      backbone = FoldBackbone(timeline.geometry) {
    final FoldGeometry g = geometry;
    tubes = <FoldTube>[
      for (final LooseRun run in g.loose)
        _tubeOf(
          run.before >= 0 ? run.before : run.start,
          run.after >= 0 ? run.after + 1 : run.end,
        ),
    ];
    sphereCentres = Float32List(3 * g.length);
    sphereRadii = Float32List(g.length);
    sphereColours = Float32List(4 * g.length);
    _bridged = List<bool>.filled(g.length, false);
    for (final (int i, int j) in g.bridges) {
      _bridged[i] = true;
      _bridged[j] = true;
    }
    _layOut();
    update(0);
  }

  FoldTube _tubeOf(int start, int end) =>
      FoldTube._(start, end, (end - start - 1) * samples + 1);

  final FoldTimeline timeline;
  final FoldPalette palette;

  FoldGeometry get geometry => timeline.geometry;

  /// Where the backbone runs at the frame last updated.
  final FoldBackbone backbone;

  /// The frame last updated.
  FoldFrame get frame => _frame;
  late FoldFrame _frame;

  /// Vertices round each ring of a tube.
  static const int ring = 8;

  /// Rings a residue: fewer for a long chain, so that CFTR's 341 loose
  /// residues cost no more a frame than a few dozen would.
  static int samplesFor(int residues) => residues <= 200
      ? 8
      : residues <= 600
      ? 6
      : 4;

  final int samples;

  /// One per run of loose residues.
  late final List<FoldTube> tubes;

  /// The beads, one per drawn residue in [FoldGeometry.drawn]'s order. A
  /// radius of 0 is not drawn.
  late final Float32List sphereCentres;
  late final Float32List sphereRadii;
  late final Float32List sphereColours;

  int get sphereCount => sphereRadii.length;

  /// The thread the unfolded chain is drawn as, in angstroms.
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

  /// How far into its step a residue's bead starts to melt.
  static const double _meltFrom = 0.3;

  late final List<bool> _bridged;

  /// The ring's angles, once.
  static final Float64List _cos = Float64List.fromList(<double>[
    for (int j = 0; j < ring; j++) math.cos(2 * math.pi * j / ring),
  ]);
  static final Float64List _sin = Float64List.fromList(<double>[
    for (int j = 0; j < ring; j++) math.sin(2 * math.pi * j / ring),
  ]);

  /// The fixed parts: the threads' colours.
  void _layOut() {
    final FoldGeometry g = geometry;
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
  }

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
    _frame = timeline.frameAt(t, idle: idle);
    backbone.update(_frame);
    // The residues the model never places shrink away as the fold finishes.
    final double left = 1 - FoldTimeline.finishAt(_frame.t);
    for (final FoldTube tube in tubes) {
      _sweep(tube, left);
    }
    _beads(_frame, left);
  }

  // -- the threads ---------------------------------------------------------------

  void _sweep(FoldTube tube, double left) {
    final FoldGeometry g = geometry;
    final int m = tube.end - tube.start;
    final double thread = threadRadius * g.unit * left;
    final Float64List c = backbone.centres;

    // Each residue's axis across the thread: the tangent crossed with the
    // way the chain curves there, kept from turning over from one residue to
    // the next. The thread is round, so it only sets where its vertices sit.
    final Float64List across = Float64List(3 * m);
    final List<double> t = <double>[0, 0, 0];
    final List<double> w = <double>[0, 0, 0];
    final List<double> previous = <double>[0, 0, 0];
    for (int k = 0; k < m; k++) {
      final int i = tube.start + k;
      final int before = math.max(tube.start, i - 1);
      final int after = math.min(tube.end - 1, i + 1);
      for (int a = 0; a < 3; a++) {
        t[a] = c[3 * after + a] - c[3 * before + a];
      }
      _normalise(t);
      bool curved = false;
      if (k > 0 && k + 1 < m) {
        final List<double> bend = <double>[
          for (int a = 0; a < 3; a++)
            (c[3 * before + a] + c[3 * after + a]) / 2 - c[3 * i + a],
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
      if (k > 0 &&
          w[0] * previous[0] + w[1] * previous[1] + w[2] * previous[2] < 0) {
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

    // The rings: a Catmull–Rom spline through the backbone, each ring a
    // circle across it. Where the thread meets a placed residue, the model's
    // own mesh takes over, so the thread closes to a point there over half a
    // residue rather than ending open.
    final bool fromAnchor = g.drawn[tube.start].isOrdered;
    final bool toAnchor = g.drawn[tube.end - 1].isOrdered;
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
      catmullRom(c, tube.start, m, k, u, centre, tangent);
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
      final double along = s / samples;
      double taper = 1;
      if (fromAnchor) {
        taper = math.min(taper, _smooth(along / 0.5));
      }
      if (toAnchor) {
        taper = math.min(taper, _smooth((m - 1 - along) / 0.5));
      }
      final double radius = thread * taper;
      for (int j = 0; j < ring; j++, v++) {
        final double cj = _cos[j];
        final double sj = _sin[j];
        out
          ..[3 * v] = centre[0] + (side[0] * cj + up[0] * sj) * radius
          ..[3 * v + 1] = centre[1] + (side[1] * cj + up[1] * sj) * radius
          ..[3 * v + 2] = centre[2] + (side[2] * cj + up[2] * sj) * radius;
        normals
          ..[3 * v] = side[0] * cj + up[0] * sj
          ..[3 * v + 1] = side[1] * cj + up[1] * sj
          ..[3 * v + 2] = side[2] * cj + up[2] * sj;
      }
    }
  }

  // -- the beads ---------------------------------------------------------------

  void _beads(FoldFrame frame, double left) {
    final FoldGeometry g = geometry;
    final Float64List native = backbone.native;
    // Cysteines turn the bridges' colour as their step begins, and are the
    // colour when the bridge starts to close.
    final double cysteine = _smooth((frame.t - 0.75) / 0.0875);
    for (int i = 0; i < g.length; i++) {
      final FoldResidue r = g.drawn[i];
      sphereCentres
        ..[3 * i] = native[3 * i]
        ..[3 * i + 1] = native[3 * i + 1]
        ..[3 * i + 2] = native[3 * i + 2];
      if (!r.isOrdered) {
        sphereRadii[i] = looseBead * bead * g.unit * left;
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
        scale =
            1 -
            _smooth(
              (backbone.settled[i] - _meltFrom) / (1 - _meltFrom),
            );
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

  static double _length(List<double> v) =>
      math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);

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
