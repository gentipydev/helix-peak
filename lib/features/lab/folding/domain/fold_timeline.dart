import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../shared/motion/animation_timeline.dart';
import 'fold_geometry.dart';
import 'folding_track.dart';

/// The four steps the illustration tells a fold in, in order.
enum FoldStep { collapse, helices, strands, bridges }

/// One frame of the fold animation.
@immutable
final class FoldFrame {
  const FoldFrame({
    required this.t,
    required this.step,
    required this.positions,
    required this.closure,
    required this.emphasis,
  });

  final double t;
  final FoldStep step;

  /// Where each drawn residue is, three doubles apiece in the model's frame,
  /// in [FoldGeometry.drawn]'s order.
  final Float64List positions;

  /// How far each drawn bridge has closed: 0 open, 1 shut.
  final Float64List closure;

  /// How strongly the water-avoiding residues are marked: it rises through
  /// the collapse and fades as the helices coil.
  final double emphasis;
}

/// A chain folding, in four staged steps, as a pure function of time.
///
/// 1. **Hydrophobic collapse.** The loose chain draws together, and its
///    water-avoiding residues move furthest in.
/// 2. **Helices coil.** The residues the entry assigns to helices wind into
///    them, from the smooth rod the collapse left.
/// 3. **Strands pair into sheets.** The strands, and the loops between,
///    move into place beside their partners.
/// 4. **Disulfide bridges snap shut.** Each pair of cysteines, held a little
///    apart until now, closes.
///
/// The order is the textbook's, told once for every protein; it is an
/// illustration, and nothing here computes how a chain really folds. What
/// is measured is the last frame: at `t = 1` every ordered residue is exactly
/// the CA the track places it at, in the stored model's frame, so it lands on
/// the fold the walk's page draws. Disordered residues never get there. They
/// hang loose from their anchors and keep moving for as long as the timeline,
/// or the screen's own clock ([frameAt]'s `idle`), does.
class FoldTimeline extends AnimationTimeline<FoldFrame> {
  FoldTimeline(this.geometry);

  final FoldGeometry geometry;

  /// Each step is this many beats long.
  static const int beatsPerStep = 3;

  @override
  int get beats => FoldStep.values.length * beatsPerStep;

  static const List<PhaseMark> _phases = <PhaseMark>[
    PhaseMark(name: 'Hydrophobic collapse', t: 0, captionKey: 'collapse'),
    PhaseMark(name: 'Helices coil', t: 0.25, captionKey: 'helices'),
    PhaseMark(name: 'Strands pair', t: 0.5, captionKey: 'strands'),
    PhaseMark(name: 'Bridges snap shut', t: 0.75, captionKey: 'bridges'),
  ];

  @override
  List<PhaseMark> get phases => _phases;

  @override
  FoldFrame stateAt(double t) => frameAt(t);

  /// The step [t] is in.
  static FoldStep stepAt(double t) =>
      FoldStep.values[(t.clamp(0.0, 1.0) * FoldStep.values.length)
          .floor()
          .clamp(0, FoldStep.values.length - 1)];

  /// [stateAt], with the loose residues moved on by [idle] seconds of the
  /// screen's own clock, so that they go on moving once the timeline stops.
  /// Nothing ordered depends on [idle].
  FoldFrame frameAt(double t, {double idle = 0}) {
    final double at = t.clamp(0.0, 1.0);
    final double collapse = AnimationTimeline.slice(at, 0, 0.25);
    final double coil = AnimationTimeline.slice(at, 0.25, 0.5);
    final double pair = AnimationTimeline.slice(at, 0.5, 0.75);
    // The bridges close quickly, in the middle of their step: a snap.
    final double snap = AnimationTimeline.slice(at, 0.8375, 0.9125);

    final FoldGeometry g = geometry;
    final Float64List p = Float64List(3 * g.length);
    for (int i = 0; i < g.length; i++) {
      final FoldResidue residue = g.drawn[i];
      if (!residue.isOrdered) {
        continue;
      }
      final double settle = residue.shape == FoldShape.helix ? coil : pair;
      for (int axis = 0; axis < 3; axis++) {
        final int k = 3 * i + axis;
        final double finish = snap >= 1
            ? g.folded[k]
            : g.folded[k] + g.hold[k] * (1 - snap);
        final double collapsed = _between(
          g.unfolded[k],
          g.globule[k],
          collapse,
        );
        p[k] = _between(collapsed, finish, settle);
      }
    }

    // The loose residues leave the unfolded chain as it collapses, and hang
    // from wherever their anchors are now, never still.
    final double cycles = at * _loosePace + idle * _idlePace;
    for (final LooseRun run in g.loose) {
      for (int k = run.start; k < run.end; k++) {
        final ModelPoint base = g.looseBase(run, k, p);
        final int fromAnchor = run.before >= 0
            ? k - run.before
            : run.after >= 0
            ? run.after - k
            : k - run.start + 1;
        final double amplitude =
            _looseAmplitude *
            g.unit *
            (0.4 + 0.6 * math.min(1, fromAnchor / 8));
        final double along = 0.35 * k;
        final List<double> rest = <double>[base.$1, base.$2, base.$3];
        for (int axis = 0; axis < 3; axis++) {
          final int i = 3 * k + axis;
          final double wave = math.sin(
            2 * math.pi * cycles * _axisPace[axis] + along + axis * 2.1,
          );
          p[i] =
              _between(g.unfolded[i], rest[axis], collapse) + wave * amplitude;
        }
      }
    }

    return FoldFrame(
      t: at,
      step: stepAt(at),
      positions: p,
      closure: Float64List(g.bridges.length)
        ..fillRange(0, g.bridges.length, snap),
      emphasis: collapse * (1 - coil),
    );
  }

  /// From [from] to [to] by [f], landing on [to] itself at 1 rather than a
  /// rounding error beside it.
  static double _between(double from, double to, double f) =>
      f >= 1 ? to : (f <= 0 ? from : from + (to - from) * f);

  // How a loose residue moves: this far, in angstroms, and this many times
  // over the timeline, or a second of the screen's clock.
  static const double _looseAmplitude = 1.6;
  static const double _loosePace = 3;
  static const double _idlePace = 0.35;
  static const List<double> _axisPace = <double>[1, 1.3, 1.7];
}
