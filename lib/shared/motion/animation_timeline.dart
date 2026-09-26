import 'package:flutter/foundation.dart';

import '../anatomy/anatomy_motion.dart';

/// Where one named phase of a timeline begins.
@immutable
final class PhaseMark {
  const PhaseMark({
    required this.name,
    required this.t,
    required this.captionKey,
  });

  /// What the transport bar shows and a screen reader hears. Never a raw `t`.
  final String name;

  /// Where the phase begins, from 0 at the start of the timeline to 1 at its
  /// end.
  final double t;

  /// Which caption belongs to the phase: a key, not prose. The words come
  /// from the flow's own caption generator, which builds them from the record.
  final String captionKey;

  @override
  bool operator ==(Object other) =>
      other is PhaseMark &&
      other.name == name &&
      other.t == t &&
      other.captionKey == captionKey;

  @override
  int get hashCode => Object.hash(name, t, captionKey);

  @override
  String toString() => 'PhaseMark($name @ $t, $captionKey)';
}

/// An animation as a pure function of time.
///
/// This is the pattern the walk's anatomy already follows: `AnatomyMotion`
/// and `AnatomyScene.positionOf` know nothing of the clock, only of `t`, which
/// is why a frame can be drawn, tested or rendered offscreen at any `t` without
/// playing up to it. A timeline says how long it is in [beats], where its
/// named [phases] begin, and what is on screen at each `t` ([stateAt]). The
/// clock, the speed and the reader's controls belong to `TimelineController`.
///
/// `t` runs from 0 at the start to 1 at the end, across every beat.
abstract class AnimationTimeline<S> {
  const AnimationTimeline();

  /// How long the timeline is, in beats: the unit the flow counts in, such as
  /// one codon read. The controller turns beats into seconds.
  int get beats;

  /// Named phase boundaries, in order of `t`, the first at 0. The last phase
  /// runs to the end, `t = 1`, which is itself a boundary.
  List<PhaseMark> get phases;

  /// What is on screen at [t]. Pure, deterministic and light on allocation:
  /// the same [t] always gives an equal state, and nothing in it depends on
  /// the clock, the frame or what was asked for before.
  S stateAt(double t);

  /// Where [beat] begins.
  double beatStart(num beat) => beat / beats;

  /// The beat [t] falls in, and how far through it, from 0 to 1. The very end,
  /// `t = 1`, is the last beat completed rather than a beat past it.
  (int, double) beatAt(double t) {
    final double at = t.clamp(0.0, 1.0) * beats;
    final int beat = at.floor().clamp(0, beats - 1);
    return (beat, (at - beat).clamp(0.0, 1.0));
  }

  /// Every `t` a still frame may sit on: each phase's start, and the end.
  List<double> get boundaries => <double>[
    for (final PhaseMark mark in phases) mark.t,
    if (phases.isEmpty || phases.last.t < 1) 1,
  ];

  /// The phase [t] is in: the last one to begin at or before it.
  PhaseMark? phaseAt(double t) {
    final int index = _lastAtOrBefore(t);
    return index < 0 ? null : phases[index];
  }

  /// The next boundary after [t], and never past the end.
  double nextBoundary(double t) {
    final int index = _lastAtOrBefore(t) + 1;
    return index < phases.length ? phases[index].t : 1;
  }

  /// The last boundary before [t], and never before the start.
  double previousBoundary(double t) {
    int index = _lastAtOrBefore(t);
    while (index >= 0 && phases[index].t >= t - _epsilon) {
      index--;
    }
    return index < 0 ? 0 : phases[index].t;
  }

  /// [t] held back to the boundary it has most recently passed: the still
  /// frame reduced motion shows in its place.
  double snapToPhase(double t) {
    if (t >= 1 - _epsilon) {
      return 1;
    }
    final int index = _lastAtOrBefore(t);
    return index < 0 ? 0 : phases[index].t;
  }

  /// How far [local] is through the slice from [start] to [end] of a beat:
  /// 0 before it, 1 after it, and in between eased the way the anatomy
  /// eases ([AnatomyMotion.ease]) unless [eased] is false.
  static double slice(
    double local,
    double start,
    double end, {
    bool eased = true,
  }) {
    final double raw = end <= start
        ? (local >= end ? 1.0 : 0.0)
        : ((local - start) / (end - start)).clamp(0.0, 1.0);
    return eased ? AnatomyMotion.ease(raw) : raw;
  }

  /// Binary search: the index of the last phase beginning at or before [t],
  /// or -1 before the first.
  int _lastAtOrBefore(double t) {
    int low = 0;
    int high = phases.length - 1;
    int found = -1;
    while (low <= high) {
      final int middle = (low + high) >> 1;
      if (phases[middle].t <= t + _epsilon) {
        found = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return found;
  }

  /// Two `t` values this close are one boundary. A beat is at least 1e-6 of
  /// the longest timeline in the catalog, so this never merges two phases.
  static const double _epsilon = 1e-9;
}

/// How wall-clock progress becomes timeline progress: 0 at 0, 1 at 1, and never
/// backwards. It is the hook a flow uses to linger where something happens and
/// hurry where nothing does, without changing what happens at any `t`.
abstract class SpeedCurve {
  const SpeedCurve();

  /// Every moment given the same time.
  static const SpeedCurve linear = _LinearSpeed();

  /// A curve from a relative [rate] at each `t`: 2 plays that stretch twice as
  /// fast as 1. Sampled into [samples] straight pieces, so both directions are
  /// cheap to read. A rate at or below zero is read as the slowest rate
  /// allowed, [minimumRate], so time always moves.
  factory SpeedCurve.fromRate(
    double Function(double t) rate, {
    int samples,
  }) = _SampledSpeed;

  /// The slowest a rate may make a stretch: a hundredth of its plain speed.
  static const double minimumRate = 0.01;

  /// The timeline's `t` once [wall] of the playing time has passed.
  double tAt(double wall);

  /// How much of the playing time has passed when the timeline reaches [t].
  double wallAt(double t);
}

final class _LinearSpeed extends SpeedCurve {
  const _LinearSpeed();

  @override
  double tAt(double wall) => wall.clamp(0.0, 1.0);

  @override
  double wallAt(double t) => t.clamp(0.0, 1.0);
}

final class _SampledSpeed extends SpeedCurve {
  _SampledSpeed(double Function(double t) rate, {int samples = 1024})
    : assert(samples > 0, 'a curve needs at least one piece'),
      _walls = _integrate(rate, samples);

  /// `_walls[i]` is the wall fraction at `t = i / samples`; the last is 1.
  final Float64List _walls;

  int get _samples => _walls.length - 1;

  static Float64List _integrate(double Function(double t) rate, int samples) {
    final Float64List walls = Float64List(samples + 1);
    double total = 0;
    for (int i = 0; i < samples; i++) {
      final double middle = (i + 0.5) / samples;
      final double speed = rate(middle);
      total += 1 / (speed > SpeedCurve.minimumRate
          ? speed
          : SpeedCurve.minimumRate);
      walls[i + 1] = total;
    }
    for (int i = 1; i <= samples; i++) {
      walls[i] /= total;
    }
    walls[samples] = 1;
    return walls;
  }

  @override
  double wallAt(double t) {
    final double at = t.clamp(0.0, 1.0) * _samples;
    final int i = at.floor().clamp(0, _samples - 1);
    final double f = at - i;
    return _walls[i] + (_walls[i + 1] - _walls[i]) * f;
  }

  @override
  double tAt(double wall) {
    final double w = wall.clamp(0.0, 1.0);
    int low = 0;
    int high = _samples;
    while (high - low > 1) {
      final int middle = (low + high) >> 1;
      if (_walls[middle] <= w) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final double span = _walls[high] - _walls[low];
    final double f = span <= 0 ? 0 : (w - _walls[low]) / span;
    return ((low + f) / _samples).clamp(0.0, 1.0);
  }
}
