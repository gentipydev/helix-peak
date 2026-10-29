import 'package:flutter/foundation.dart';

import '../../../shared/motion/animation_timeline.dart';

/// One training step told in six stages, then the loop over every step: the
/// order the page plays them in, each with its share of the time.
enum LmStage {
  tokenise('Tokenise', 8),
  forward('Forward', 19),
  predict('Predict', 7),
  loss('Loss', 7),
  backward('Backward', 8),
  update('Update', 8),
  loop('Loop', 25);

  const LmStage(this.label, this.beats);

  final String label;
  final int beats;
}

/// What the page shows at one moment.
@immutable
final class TrainingFrame {
  const TrainingFrame({
    required this.stage,
    required this.local,
    required this.step,
  });

  final LmStage stage;

  /// How far through its stage, from 0 to 1.
  final double local;

  /// The step the loop has reached, from 1 to the run's last, and between
  /// two while it moves. 1 outside the loop.
  final double step;

  /// The stage played through: the still frame reduced motion shows.
  TrainingFrame completed(int steps) => TrainingFrame(
    stage: stage,
    local: 1,
    step: stage == LmStage.loop ? steps.toDouble() : step,
  );

  @override
  bool operator ==(Object other) =>
      other is TrainingFrame &&
      other.stage == stage &&
      other.local == local &&
      other.step == step;

  @override
  int get hashCode => Object.hash(stage, local, step);

  @override
  String toString() => 'TrainingFrame(${stage.name} $local, step $step)';
}

/// The run as a pure function of time: a stage and how far into it, and in
/// the loop, the step. The clock and the reader's controls are the
/// `TimelineController`'s.
final class TrainingTimeline extends AnimationTimeline<TrainingFrame> {
  const TrainingTimeline({required this.steps}) : assert(steps >= 1, 'a run takes a step');

  /// How many steps the run took.
  final int steps;

  static final List<int> _starts = <int>[
    for (int i = 0; i < LmStage.values.length; i++)
      LmStage.values.take(i).fold<int>(0, (int sum, LmStage s) => sum + s.beats),
  ];

  static final int _beats =
      LmStage.values.fold<int>(0, (int sum, LmStage s) => sum + s.beats);

  static final List<PhaseMark> _phases = <PhaseMark>[
    for (final LmStage stage in LmStage.values)
      PhaseMark(
        name: stage.label,
        t: _starts[stage.index] / _beats,
        captionKey: stage.name,
      ),
  ];

  // Two `t`s this close are one place.
  static const double _epsilon = 1e-9;

  @override
  int get beats => _beats;

  @override
  List<PhaseMark> get phases => _phases;

  /// Where [stage] begins.
  double startOf(LmStage stage) => _starts[stage.index] / _beats;

  /// Where the loop reaches [step].
  double loopAt(double step) {
    final double through = steps <= 1 ? 1 : ((step - 1) / (steps - 1)).clamp(0.0, 1.0);
    return (_starts[LmStage.loop.index] + LmStage.loop.beats * through) / _beats;
  }

  @override
  TrainingFrame stateAt(double t) {
    final double at = t.clamp(0.0, 1.0) * _beats;
    LmStage stage = LmStage.values.first;
    for (final LmStage candidate in LmStage.values) {
      if (_starts[candidate.index] <= at + _epsilon) {
        stage = candidate;
      }
    }
    final double local =
        ((at - _starts[stage.index]) / stage.beats).clamp(0.0, 1.0);
    return TrainingFrame(
      stage: stage,
      local: local,
      step: stage == LmStage.loop ? 1 + local * (steps - 1) : 1,
    );
  }
}
