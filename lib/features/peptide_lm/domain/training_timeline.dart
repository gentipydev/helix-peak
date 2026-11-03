import 'package:flutter/foundation.dart';

import '../../../shared/motion/animation_timeline.dart';

/// One training step told in eleven stages, then the loop over every step:
/// the order the page plays them in, each with its share of the time. The
/// forward pass is four of them: block 1's attention in two, its scores and
/// then what it hands over, and its feed-forward, each close up; then one
/// place's row through the whole pass, layer to layer. How the loop spends
/// its own beats is `LoopPace`'s.
enum LmStage {
  tokenise('Tokenise', 11),
  shift('Shift', 5),
  embedding('Embedding', 15),
  scores('Scores', 20),
  attention('Attention', 25),
  feedForward('Feed-forward', 20),
  forward('Forward', 12),
  predict('Predict', 14),
  loss('Loss', 17),
  backward('Backward', 44),
  update('Update', 38),
  loop('Loop', 44);

  const LmStage(this.label, this.beats);

  final String label;
  final int beats;
}

/// What the page shows at one moment: a stage, and how far into it. Where
/// the loop has got to is `LoopPace`'s to say, from [local].
@immutable
final class TrainingFrame {
  const TrainingFrame({
    required this.stage,
    required this.local,
  });

  final LmStage stage;

  /// How far through its stage, from 0 to 1.
  final double local;

  /// The stage played through: the still frame reduced motion shows.
  TrainingFrame completed() => TrainingFrame(stage: stage, local: 1);

  @override
  bool operator ==(Object other) =>
      other is TrainingFrame && other.stage == stage && other.local == local;

  @override
  int get hashCode => Object.hash(stage, local);

  @override
  String toString() => 'TrainingFrame(${stage.name} $local)';
}

/// The run as a pure function of time: a stage and how far into it. The page
/// plays one stage at a time ([frameIn]); [stateAt] reads the whole run end
/// to end.
final class TrainingTimeline extends AnimationTimeline<TrainingFrame> {
  const TrainingTimeline();

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

  /// [stage], [local] of the way through: at 1, the stage played through,
  /// never the next stage's first frame.
  TrainingFrame frameIn(LmStage stage, double local) =>
      TrainingFrame(stage: stage, local: local.clamp(0.0, 1.0));

  @override
  TrainingFrame stateAt(double t) {
    final double at = t.clamp(0.0, 1.0) * _beats;
    LmStage stage = LmStage.values.first;
    for (final LmStage candidate in LmStage.values) {
      if (_starts[candidate.index] <= at + _epsilon) {
        stage = candidate;
      }
    }
    // A moment this close to its stage's start is the start, not a hair
    // past it.
    final double into = at - _starts[stage.index];
    return frameIn(stage, into <= _epsilon ? 0.0 : into / stage.beats);
  }
}
