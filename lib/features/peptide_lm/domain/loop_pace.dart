import 'package:flutter/foundation.dart';

import '../../../shared/motion/animation_timeline.dart';
import 'training_timeline.dart';
import 'training_trace.dart';

/// What a moment of the loop shows.
enum LoopPart {
  /// Update's last frame: the step done.
  done,

  /// Step 1's guesses: the map comes in.
  guesses,

  /// Step 1's cost: the curve comes in.
  cost,

  /// On the way to a stop.
  move,

  /// At a stop: a step on the way, or a kept step, held.
  single,
  hold,

  /// After the last step: what no model can learn here; then the run whole.
  left,
  heart,
}

/// A step the loop stops at: one on the way, or a kept one, held; then
/// [checkpoint] is its index among the run's checkpoints.
@immutable
final class LoopStop {
  const LoopStop(this.step, this.checkpoint);

  final int step;
  final int? checkpoint;

  bool get held => checkpoint != null;
}

/// A stretch of the loop, in beats: a [part], about stop [stop] (an index of
/// [LoopPace.stops], or −1 outside them), from [from] to [to].
@immutable
final class LoopSpan {
  const LoopSpan(this.part, this.stop, this.from, this.to);

  final LoopPart part;
  final int stop;
  final double from;
  final double to;
}

/// A moment of the loop: its [span], how far [through] it, the [beat], and
/// the [step] the run has reached, between two while it moves.
@immutable
final class LoopMoment {
  const LoopMoment(this.span, this.through, this.beat, this.step);

  final LoopSpan span;
  final double through;
  final double beat;
  final double step;

  LoopPart get part => span.part;

  int get stop => span.stop;
}

/// How the loop spends its beats: Update's last frame; step 1's guesses and
/// cost; steps 2 to 4 one at a time; then a move to each kept step and a hold
/// there, for its caption and note; then the end. A move of many steps takes
/// at least [leastMove], and what the stage has left goes to the moves by how
/// far the loss falls on them, so the steps where the model learns most get
/// the time. A pure function of the run.
final class LoopPace {
  LoopPace._(this.steps, this.stops, this.spans, this.beats);

  /// Laid out for [steps] steps whose kept steps are [kept] (step 1 first),
  /// the loss at a step being [loss], in [beats].
  factory LoopPace.plan({
    required int steps,
    required List<int> kept,
    required double Function(int step) loss,
    double? beats,
  }) {
    final double total = beats ?? LmStage.loop.beats.toDouble();
    final List<LoopStop> stops = <LoopStop>[
      for (int s = 2; s <= steps; s++)
        if (kept.contains(s))
          LoopStop(s, kept.indexOf(s))
        else if (s <= _lastSingle)
          LoopStop(s, null),
    ];
    int from(int j) => j == 0 ? 1 : stops[j - 1].step;
    bool long(int j) => stops[j].step - from(j) > 1;

    double fixed = done + guesses + cost + left + heart;
    int longs = 0;
    int holds = 0;
    double fallen = 0;
    for (int j = 0; j < stops.length; j++) {
      fixed += stops[j].held ? hold : single;
      holds += stops[j].held ? 1 : 0;
      if (long(j)) {
        longs += 1;
        fallen += _fall(loss, from(j), stops[j].step);
      } else {
        fixed += hop;
      }
    }
    final double spare = total - fixed;
    assert(spare >= 0, 'the loop has no beats left for its moves');
    final double extra = longs == 0 ? 0 : spare - leastMove * longs;
    double moveOf(int j) {
      if (!long(j)) {
        return hop;
      }
      if (extra < 0) {
        return spare / longs;
      }
      return leastMove + (fallen > 0 ? extra * _fall(loss, from(j), stops[j].step) / fallen : extra / longs);
    }

    // With no move of many steps, what is left goes to the holds, or to the end.
    final double heldMore = longs == 0 && holds > 0 ? spare / holds : 0;
    final double endMore = longs == 0 && holds == 0 ? spare : 0;

    final List<LoopSpan> spans = <LoopSpan>[];
    double at = 0;
    void add(LoopPart part, int stop, double length) {
      spans.add(LoopSpan(part, stop, at, at + length));
      at += length;
    }

    add(LoopPart.done, -1, done);
    add(LoopPart.guesses, -1, guesses);
    add(LoopPart.cost, -1, cost);
    for (int j = 0; j < stops.length; j++) {
      add(LoopPart.move, j, moveOf(j));
      add(stops[j].held ? LoopPart.hold : LoopPart.single, j, stops[j].held ? hold + heldMore : single);
    }
    add(LoopPart.left, -1, left + endMore / 2);
    add(LoopPart.heart, -1, heart + endMore / 2);
    // The last span ends where the stage does, whatever the sums' rounding.
    final LoopSpan last = spans.removeLast();
    spans.add(LoopSpan(last.part, last.stop, last.from, total));
    return LoopPace._(steps, List<LoopStop>.unmodifiable(stops), List<LoopSpan>.unmodifiable(spans), total);
  }

  /// The loop of [trace], worked out once.
  factory LoopPace.of(TrainingTrace trace) => _paces[trace] ??= LoopPace.plan(
    steps: trace.steps.count,
    kept: <int>[for (final TraceCheckpoint c in trace.checkpoints) c.step],
    loss: trace.loss,
  );

  static final Expando<LoopPace> _paces = Expando<LoopPace>('the loop of a run');

  /// The parts' lengths, in beats.
  static const double done = 2;
  static const double guesses = 2.5;
  static const double cost = 2.5;
  static const double left = 2.5;
  static const double heart = 2.5;

  /// A move of one step, the dwell at a step on the way, and at a kept one.
  static const double hop = 0.4;
  static const double single = 0.6;
  static const double hold = 2.5;

  /// The least a move of many steps takes.
  static const double leastMove = 1.2;

  /// The steps on the way the loop stops at, one at a time: 2 to this.
  static const int _lastSingle = 4;

  /// How long after a hold starts its note has come in: where a kept step
  /// picked lands.
  static const double _settled = 0.3;

  final int steps;
  final List<LoopStop> stops;
  final List<LoopSpan> spans;
  final double beats;

  /// How far the loss falls from step [a] to step [b], never less than none.
  static double _fall(double Function(int step) loss, int a, int b) {
    final double fall = loss(a) - loss(b);
    return fall > 0 ? fall : 0;
  }

  /// The moment [local] of the way through the loop.
  LoopMoment at(double local) {
    final double beat = local.clamp(0.0, 1.0) * beats;
    LoopSpan span = spans.last;
    for (final LoopSpan candidate in spans) {
      if (beat < candidate.to) {
        span = candidate;
        break;
      }
    }
    final double length = span.to - span.from;
    final double through = length <= 0 ? 1 : ((beat - span.from) / length).clamp(0.0, 1.0);
    return LoopMoment(span, through, beat, _stepAt(span, through));
  }

  double _stepAt(LoopSpan span, double through) {
    switch (span.part) {
      case LoopPart.done:
      case LoopPart.guesses:
      case LoopPart.cost:
        return 1;
      case LoopPart.single:
      case LoopPart.hold:
        return stops[span.stop].step.toDouble();
      case LoopPart.left:
      case LoopPart.heart:
        return stops.isEmpty ? 1 : stops.last.step.toDouble();
      case LoopPart.move:
        final double a = span.stop == 0 ? 1 : stops[span.stop - 1].step.toDouble();
        final double b = stops[span.stop].step.toDouble();
        final double f = b - a > 1 ? cruise(through) : AnimationTimeline.slice(through, 0, 1);
        return a + (b - a) * f;
    }
  }

  /// A move's way along, [t] of its time: even steps, eased in and out over
  /// its first and last [_ramp], so a long move reads at one speed.
  static double cruise(double t) {
    const double top = 1 / (1 - _ramp);
    if (t <= 0) {
      return 0;
    }
    if (t >= 1) {
      return 1;
    }
    if (t < _ramp) {
      return top * t * t / (2 * _ramp);
    }
    if (t > 1 - _ramp) {
      return 1 - top * (1 - t) * (1 - t) / (2 * _ramp);
    }
    return top * (t - _ramp / 2);
  }

  static const double _ramp = 0.15;

  /// The span of [part], the first of them.
  LoopSpan span(LoopPart part) => spans.firstWhere((LoopSpan s) => s.part == part);

  /// The hold at checkpoint [index], or null where the loop holds none (step
  /// 1, which its opening shows).
  LoopSpan? holdOf(int index) {
    for (final LoopSpan s in spans) {
      if (s.part == LoopPart.hold && stops[s.stop].checkpoint == index) {
        return s;
      }
    }
    return null;
  }

  /// Where the loop shows checkpoint [index] settled, as a share of the
  /// stage: its hold once its note has come in; step 1 at the end of its
  /// cost, the curve drawn.
  double landing(int index) {
    final LoopSpan? held = holdOf(index);
    final double beat = held == null ? span(LoopPart.cost).to - _settled : held.from + _settled;
    return beat / beats;
  }

  /// A moment inside every span, as shares of the stage: where the caption
  /// below the canvas is read for its tallest.
  List<double> get samples => <double>[for (final LoopSpan s in spans) (s.from + s.to) / 2 / beats];
}
