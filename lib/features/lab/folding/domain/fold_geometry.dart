import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'folding_track.dart';

/// Hydropathy on the Kyte–Doolittle scale (J. Mol. Biol. 1982, 157:105–132).
///
/// The fold's first step is told with it: a residue scoring above zero is
/// water-avoiding, and those are I, V, L, F, C, M and A. Kept here rather than
/// with the amino-acid table, because it is this illustration's criterion and
/// not a fact the walk draws.
const Map<String, double> kyteDoolittle = <String, double>{
  'I': 4.5,
  'V': 4.2,
  'L': 3.8,
  'F': 2.8,
  'C': 2.5,
  'M': 1.9,
  'A': 1.8,
  'G': -0.4,
  'T': -0.7,
  'S': -0.8,
  'W': -0.9,
  'Y': -1.3,
  'P': -1.6,
  'H': -3.2,
  'E': -3.5,
  'Q': -3.5,
  'D': -3.5,
  'N': -3.5,
  'K': -3.9,
  'R': -4.5,
};

bool isWaterAvoiding(String letter) => (kyteDoolittle[letter] ?? 0) > 0;

/// A run of disordered residues and the ordered residues it hangs from.
@immutable
final class LooseRun {
  const LooseRun({
    required this.start,
    required this.end,
    required this.before,
    required this.after,
  });

  /// Drawn indices, [start] inclusive and [end] exclusive.
  final int start;
  final int end;

  /// The ordered residue before the run in its chain, or -1 at the chain's
  /// start; the one after it, or -1 at its end.
  final int before;
  final int after;

  int get length => end - start;
}

/// Everything about one protein's fold animation that does not change with
/// time: which residues are drawn, and the shapes the chain moves between.
///
/// Positions are in the stored structure model's frame, three doubles per
/// drawn residue, in drawn order: chain after chain, each chain's residues in
/// sequence. A disordered residue is drawn, loose; an absent one is not drawn.
@immutable
final class FoldGeometry {
  const FoldGeometry._({
    required this.track,
    required this.drawn,
    required this.chainRuns,
    required this.centre,
    required this.unit,
    required this.reach,
    required this.folded,
    required this.unfolded,
    required this.globule,
    required this.hold,
    required this.tails,
    required this.loose,
    required this.bridges,
    required this.bridgeNumbers,
  });

  /// The shapes of [track]'s chains. [bridges] are the catalog's disulfide
  /// pairs, in precursor numbering; a pair is drawn where both of its
  /// cysteines have a place in the fold.
  factory FoldGeometry.of(
    FoldingTrack track, {
    List<(int, int)> bridges = const <(int, int)>[],
  }) {
    final List<FoldResidue> drawn = <FoldResidue>[];
    final List<(int, int)> runs = <(int, int)>[];
    for (final FoldChain chain in track.chains) {
      final int start = drawn.length;
      drawn.addAll(
        chain.residues.where((FoldResidue r) => r.place != FoldPlace.absent),
      );
      runs.add((start, drawn.length));
    }
    final int n = drawn.length;
    final double unit = 1 / track.angstromsPerUnit;
    final (double, double, double) low = track.boundsMin;
    final (double, double, double) high = track.boundsMax;
    final double reach =
        0.5 *
        math.sqrt(
          _square(high.$1 - low.$1) +
              _square(high.$2 - low.$2) +
              _square(high.$3 - low.$3),
        );

    // The finished fold, and its centre.
    final Float64List folded = Float64List(3 * n)
      ..fillRange(0, 3 * n, double.nan);
    double cx = 0;
    double cy = 0;
    double cz = 0;
    int placed = 0;
    for (int i = 0; i < n; i++) {
      final ModelPoint? ca = drawn[i].ca;
      if (ca != null) {
        folded
          ..[3 * i] = ca.$1
          ..[3 * i + 1] = ca.$2
          ..[3 * i + 2] = ca.$3;
        cx += ca.$1;
        cy += ca.$2;
        cz += ca.$3;
        placed++;
      }
    }
    final (double, double, double) centre = (
      cx / placed,
      cy / placed,
      cz / placed,
    );

    // The loose runs, and where each tail rests once its anchor has settled.
    final List<LooseRun> loose = <LooseRun>[];
    for (final (int start, int end) in runs) {
      int i = start;
      while (i < end) {
        if (drawn[i].isOrdered) {
          i++;
          continue;
        }
        final int first = i;
        while (i < end && !drawn[i].isOrdered) {
          i++;
        }
        loose.add(
          LooseRun(
            start: first,
            end: i,
            before: first > start ? first - 1 : -1,
            after: i < end ? i : -1,
          ),
        );
      }
    }
    final Float64List tails = Float64List(3 * n);
    for (final LooseRun run in loose) {
      if ((run.before < 0) != (run.after < 0)) {
        _layTail(run, folded, centre, reach, unit, tails);
      }
    }

    // Where every drawn residue is when the fold is done, loose ones at rest.
    final Float64List rest = Float64List.fromList(folded);
    for (final LooseRun run in loose) {
      for (int k = run.start; k < run.end; k++) {
        final ModelPoint at = _looseBase(
          run,
          k,
          rest,
          centre,
          reach,
          unit,
          tails,
        );
        rest
          ..[3 * k] = at.$1
          ..[3 * k + 1] = at.$2
          ..[3 * k + 2] = at.$3;
      }
    }

    // The collapsed globule: the fold smoothed of its helices and strands,
    // water-avoiding residues pulled furthest in.
    final Float64List globule = Float64List(3 * n);
    final Float64List smooth = _smoothed(rest, runs, 3);
    for (int i = 0; i < n; i++) {
      final double pull = isWaterAvoiding(drawn[i].letter) ? 0.7 : 0.95;
      globule
        ..[3 * i] = centre.$1 + (smooth[3 * i] - centre.$1) * pull
        ..[3 * i + 1] = centre.$2 + (smooth[3 * i + 1] - centre.$2) * pull
        ..[3 * i + 2] = centre.$3 + (smooth[3 * i + 2] - centre.$3) * pull;
    }

    // The unfolded chain: the fold's path smoothed further, spread out and
    // loosened, then held inside the frame the page draws the fold in.
    final Float64List unfolded = _smoothed(rest, runs, 6);
    final math.Random wander = math.Random(_seed);
    final List<double> phases = <double>[
      for (int j = 0; j < 9; j++) wander.nextDouble() * 2 * math.pi,
    ];
    double furthest = 0;
    for (int i = 0; i < n; i++) {
      final double s = i / math.max(1, n - 1);
      for (int axis = 0; axis < 3; axis++) {
        final double c = axis == 0
            ? centre.$1
            : axis == 1
            ? centre.$2
            : centre.$3;
        final double wave =
            math.sin(2 * math.pi * 3 * s + phases[axis]) +
            0.5 * math.sin(2 * math.pi * 7 * s + phases[3 + axis]) +
            0.25 * math.sin(2 * math.pi * 13 * s + phases[6 + axis]);
        unfolded[3 * i + axis] =
            c + (unfolded[3 * i + axis] - c) * 1.7 + wave * 0.18 * reach;
      }
      furthest = math.max(furthest, _distance(unfolded, i, centre));
    }
    final double fit = furthest > 0.9 * reach ? 0.9 * reach / furthest : 1;
    for (int i = 0; i < n; i++) {
      unfolded
        ..[3 * i] = centre.$1 + (unfolded[3 * i] - centre.$1) * fit
        ..[3 * i + 1] = centre.$2 + (unfolded[3 * i + 1] - centre.$2) * fit
        ..[3 * i + 2] = centre.$3 + (unfolded[3 * i + 2] - centre.$3) * fit;
    }

    // The bridges whose cysteines both have a place, and the hold that keeps
    // each pair, and its neighbours, a little apart until it closes.
    final List<(int, int)> drawnBridges = <(int, int)>[];
    final List<(int, int)> numbers = <(int, int)>[];
    final Float64List hold = Float64List(3 * n);
    for (final (int a, int b) in bridges) {
      final int? i = _orderedIndex(track, runs, drawn, a);
      final int? j = _orderedIndex(track, runs, drawn, b);
      if (i == null || j == null) {
        continue;
      }
      drawnBridges.add((i, j));
      numbers.add((a, b));
      for (final (int from, int to) in <(int, int)>[(i, j), (j, i)]) {
        final double dx = folded[3 * from] - folded[3 * to];
        final double dy = folded[3 * from + 1] - folded[3 * to + 1];
        final double dz = folded[3 * from + 2] - folded[3 * to + 2];
        final double length = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (length == 0) {
          continue;
        }
        final (int, int) chain = runs.firstWhere(
          ((int, int) r) => from >= r.$1 && from < r.$2,
        );
        for (int step = -2; step <= 2; step++) {
          final int k = from + step;
          if (k < chain.$1 || k >= chain.$2 || !drawn[k].isOrdered) {
            continue;
          }
          final double reachOut = _holdApart * unit * _holdFalloff[step.abs()];
          hold
            ..[3 * k] += dx / length * reachOut
            ..[3 * k + 1] += dy / length * reachOut
            ..[3 * k + 2] += dz / length * reachOut;
        }
      }
    }

    return FoldGeometry._(
      track: track,
      drawn: List<FoldResidue>.unmodifiable(drawn),
      chainRuns: List<(int, int)>.unmodifiable(runs),
      centre: centre,
      unit: unit,
      reach: reach,
      folded: folded,
      unfolded: unfolded,
      globule: globule,
      hold: hold,
      tails: tails,
      loose: List<LooseRun>.unmodifiable(loose),
      bridges: List<(int, int)>.unmodifiable(drawnBridges),
      bridgeNumbers: List<(int, int)>.unmodifiable(numbers),
    );
  }

  final FoldingTrack track;

  /// Every residue drawn, ordered or disordered, chain after chain.
  final List<FoldResidue> drawn;

  /// Each chain's drawn residues, as a range of [drawn]: start inclusive, end
  /// exclusive.
  final List<(int, int)> chainRuns;

  /// The centre of the placed residues, and how many model units one
  /// angstrom is.
  final ModelPoint centre;
  final double unit;

  /// Half the diagonal of the model's box: the radius the page frames.
  final double reach;

  /// The finished fold: each ordered residue's CA. Not a number for a loose one.
  final Float64List folded;

  /// Where the chain starts: loose, spread out, inside the frame.
  final Float64List unfolded;

  /// Where the chain is once it has collapsed: compact, no helix or strand
  /// yet, water-avoiding residues furthest in.
  final Float64List globule;

  /// How far each residue near a bridge is held from its place until the
  /// bridge closes. Zero everywhere else.
  final Float64List hold;

  /// A loose tail's resting offsets, from the place its anchor settles in.
  final Float64List tails;

  final List<LooseRun> loose;

  /// Each drawn bridge, as the drawn indices of its two cysteines, and the
  /// same pair in precursor numbering.
  final List<(int, int)> bridges;
  final List<(int, int)> bridgeNumbers;

  int get length => drawn.length;

  /// Where a residue of [run] rests, loose, given where the ordered residues
  /// are in [positions]: along a bowed path between its two anchors, or
  /// trailing from its one.
  ModelPoint looseBase(LooseRun run, int k, Float64List positions) =>
      _looseBase(run, k, positions, centre, reach, unit, tails);

  // A disulfide's cysteines rest this far apart, in angstroms, until it
  // closes, and their neighbours a falling share of it.
  static const double _holdApart = 2.5;
  static const List<double> _holdFalloff = <double>[1, 0.55, 0.2];

  // One seed for every protein: the unfolded chain is an illustration, and
  // it is the same illustration each time the flow is opened.
  static const int _seed = 7;

  static double _square(double v) => v * v;

  static double _distance(Float64List p, int i, ModelPoint c) => math.sqrt(
    _square(p[3 * i] - c.$1) +
        _square(p[3 * i + 1] - c.$2) +
        _square(p[3 * i + 2] - c.$3),
  );

  static int? _orderedIndex(
    FoldingTrack track,
    List<(int, int)> runs,
    List<FoldResidue> drawn,
    int number,
  ) {
    for (final (int start, int end) in runs) {
      for (int i = start; i < end; i++) {
        if (drawn[i].number == number && drawn[i].isOrdered) {
          return i;
        }
      }
    }
    return null;
  }

  /// A moving average of [positions] over [half] residues each side, inside
  /// each chain.
  static Float64List _smoothed(
    Float64List positions,
    List<(int, int)> runs,
    int half,
  ) {
    final Float64List out = Float64List(positions.length);
    for (final (int start, int end) in runs) {
      for (int i = start; i < end; i++) {
        final int from = math.max(start, i - half);
        final int to = math.min(end - 1, i + half);
        for (int axis = 0; axis < 3; axis++) {
          double sum = 0;
          for (int k = from; k <= to; k++) {
            sum += positions[3 * k + axis];
          }
          out[3 * i + axis] = sum / (to - from + 1);
        }
      }
    }
    return out;
  }

  /// Lays a loose tail out from where its anchor settles: a meandering walk
  /// heading away from the fold, turned back whenever it would leave the frame.
  static void _layTail(
    LooseRun run,
    Float64List folded,
    ModelPoint centre,
    double reach,
    double unit,
    Float64List tails,
  ) {
    final bool trailing = run.before >= 0;
    final int anchor = trailing ? run.before : run.after;
    final math.Random walk = math.Random(_seed + run.length);
    final List<double> at = <double>[
      folded[3 * anchor],
      folded[3 * anchor + 1],
      folded[3 * anchor + 2],
    ];
    final List<double> heading = <double>[
      at[0] - centre.$1,
      at[1] - centre.$2,
      at[2] - centre.$3,
    ];
    _normalise(heading);
    // A disordered chain is a coil, not a rod: short steps that wander.
    final double step = 3.8 * unit * 0.6;
    final double limit = 0.9 * reach;
    for (int s = 0; s < run.length; s++) {
      final int k = trailing ? run.start + s : run.end - 1 - s;
      for (int axis = 0; axis < 3; axis++) {
        heading[axis] += (walk.nextDouble() * 2 - 1) * 0.9;
      }
      _normalise(heading);
      final List<double> next = <double>[
        for (int axis = 0; axis < 3; axis++) at[axis] + heading[axis] * step,
      ];
      final double out = math.sqrt(
        _square(next[0] - centre.$1) +
            _square(next[1] - centre.$2) +
            _square(next[2] - centre.$3),
      );
      if (out > limit) {
        // Turned back towards the fold rather than walked out of the frame.
        heading
          ..[0] = centre.$1 - at[0]
          ..[1] = centre.$2 - at[1]
          ..[2] = centre.$3 - at[2];
        _normalise(heading);
        for (int axis = 0; axis < 3; axis++) {
          next[axis] = at[axis] + heading[axis] * step;
        }
      }
      for (int axis = 0; axis < 3; axis++) {
        at[axis] = next[axis];
        tails[3 * k + axis] = next[axis] - folded[3 * anchor + axis];
      }
    }
  }

  static void _normalise(List<double> v) {
    final double length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (length == 0) {
      v[0] = 1;
      return;
    }
    for (int axis = 0; axis < 3; axis++) {
      v[axis] /= length;
    }
  }

  static ModelPoint _looseBase(
    LooseRun run,
    int k,
    Float64List positions,
    ModelPoint centre,
    double reach,
    double unit,
    Float64List tails,
  ) {
    if (run.before >= 0 && run.after >= 0) {
      // Between two anchors: a path bowed away from the fold, as long as a
      // loose coil of that many residues is.
      final int a = run.before;
      final int b = run.after;
      final double s = (k - run.start + 1) / (run.length + 1);
      final List<double> mid = <double>[
        for (int axis = 0; axis < 3; axis++)
          (positions[3 * a + axis] + positions[3 * b + axis]) / 2,
      ];
      final List<double> out = <double>[
        mid[0] - centre.$1,
        mid[1] - centre.$2,
        mid[2] - centre.$3,
      ];
      _normalise(out);
      final double bow = math.min(
        0.5 * math.sqrt(run.length.toDouble()) * 3.8 * unit,
        0.4 * reach,
      );
      final List<double> point = <double>[
        for (int axis = 0; axis < 3; axis++)
          (1 - s) * (1 - s) * positions[3 * a + axis] +
              2 * (1 - s) * s * (mid[axis] + out[axis] * bow) +
              s * s * positions[3 * b + axis],
      ];
      return (point[0], point[1], point[2]);
    }
    final int anchor = run.before >= 0 ? run.before : run.after;
    return (
      positions[3 * anchor] + tails[3 * k],
      positions[3 * anchor + 1] + tails[3 * k + 1],
      positions[3 * anchor + 2] + tails[3 * k + 2],
    );
  }
}
