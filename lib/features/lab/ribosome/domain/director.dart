import 'dart:math' as math;

import '../../../../shared/motion/animation_timeline.dart';
import 'translation_timeline.dart';

/// How a translation is paced on screen, and how long it takes in a cell.
///
/// The director slows where something happens once and hurries through the
/// cycles in between: slow through initiation and the first two cycles, fast
/// through the middle, and slow again for the first residue leaving the
/// tunnel, for the opening of the SRP window and for the stop codon. Every
/// one of those moments is the timeline's own, read off the record.
///
/// The warp is honest only if the real pace is shown beside it, so
/// [cellSeconds] turns any moment into the time a cell would have taken, at
/// [residuesPerSecond].
final class TranslationDirector {
  TranslationDirector(this.timeline);

  final TranslationTimeline timeline;

  /// A typical elongation rate in a human cell.
  static const double residuesPerSecond = 5.6;

  /// Beats of slow playing around each moment worth watching.
  static const int lead = 1;
  static const int hold = 2;

  /// The stretches played at speed 1, as `t` ranges, in order.
  late final List<(double, double)> slow = _slow();

  List<(double, double)> _slow() {
    final double beat = 1 / timeline.beats;
    (double, double) around(double t) =>
        (math.max(0, t - lead * beat), math.min(1, t + hold * beat));
    final List<(double, double)> stretches = <(double, double)>[
      // Initiation, and the first two cycles.
      (
        0,
        timeline.beatStart(
          math.min(timeline.firstElongationBeat + 2, timeline.beats),
        ),
      ),
      if (timeline.firstExit case final double exit) around(exit),
      if (timeline.srpWindow case (final double opens, _)) around(opens),
      // The last cycle, and termination at the stop codon.
      (timeline.beatStart(math.max(0, timeline.firstTerminationBeat - 1)), 1),
    ];
    return stretches
      ..sort(((double, double) a, (double, double) b) => a.$1.compareTo(b.$1));
  }

  bool isSlow(double t) {
    for (final (double from, double to) in slow) {
      if (t >= from && t <= to) {
        return true;
      }
    }
    return false;
  }

  /// How much faster than the slow stretches the middle plays: enough that the
  /// middle takes about forty beats' time however long the protein is, and
  /// never less than four times.
  late final double fast = _fast();

  double _fast() {
    double slowT = 0;
    for (final (double from, double to) in slow) {
      slowT += to - from;
    }
    final double middleBeats = (1 - slowT) * timeline.beats;
    return math.max(4, middleBeats / 40);
  }

  /// The speed curve a `TimelineController` plays the timeline with.
  late final SpeedCurve curve = SpeedCurve.fromRate(
    (double t) => isSlow(t) ? 1 : fast,
    samples: math.max(1024, timeline.beats * 8),
  );

  /// How long a cell takes to reach [state]: its residues at
  /// [residuesPerSecond], counted from the first peptide bond. Initiation and
  /// termination are not timed: a cell's pace for those varies too much to
  /// print one number.
  double cellSeconds(TranslationState state) {
    final double bonds =
        state.residues -
        1 +
        (state.phase == TranslationPhase.peptideBond ? state.chainShift : 0);
    return bonds.clamp(0.0, math.max(0, timeline.protein.length - 1)) /
        residuesPerSecond;
  }

  /// How long the whole chain takes a cell.
  double get cellTotal =>
      math.max(0, timeline.protein.length - 1) / residuesPerSecond;
}
