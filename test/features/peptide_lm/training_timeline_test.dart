import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';

void main() {
  const TrainingTimeline timeline = TrainingTimeline(steps: 200);

  test('the twelve stages, in order, named as the page names them', () {
    expect(
      timeline.phases.map((PhaseMark mark) => mark.name),
      <String>[
        'Tokenise',
        'Shift',
        'Embedding',
        'Scores',
        'Attention',
        'Feed-forward',
        'Forward',
        'Predict',
        'Loss',
        'Backward',
        'Update',
        'Loop',
      ],
    );
    expect(timeline.phases.first.t, 0);
    expect(timeline.beats, 155);
  });

  test('every stage begins where its phase does, at its start', () {
    for (final LmStage stage in LmStage.values) {
      final TrainingFrame frame = timeline.stateAt(timeline.startOf(stage));
      expect(frame.stage, stage);
      expect(frame.local, closeTo(0, 1e-9));
    }
  });

  test('outside the loop the step is the first; the loop runs every step', () {
    expect(timeline.stateAt(timeline.startOf(LmStage.update) + 0.01).step, 1);
    expect(timeline.stateAt(timeline.startOf(LmStage.loop)).step, 1);
    expect(timeline.stateAt(1).stage, LmStage.loop);
    expect(timeline.stateAt(1).step, 200);
    for (final double step in <double>[1, 8, 35.5, 100, 200]) {
      expect(timeline.stateAt(timeline.loopAt(step)).step, closeTo(step, 1e-6));
    }
  });

  test('time only moves forward through a stage and through the loop', () {
    TrainingFrame before = timeline.stateAt(0);
    for (int i = 1; i <= 105 * 60; i++) {
      final TrainingFrame now = timeline.stateAt(i / (105 * 60));
      if (now.stage == before.stage) {
        expect(now.local, greaterThanOrEqualTo(before.local));
        expect(now.step, greaterThanOrEqualTo(before.step));
      } else {
        expect(now.stage.index, before.stage.index + 1);
      }
      before = now;
    }
  });

  test('a stage on its own clock ends played through, never in the next stage', () {
    for (final LmStage stage in LmStage.values) {
      expect(timeline.frameIn(stage, 0), timeline.stateAt(timeline.startOf(stage)));
      expect(
        timeline.frameIn(stage, 1),
        timeline.stateAt(timeline.startOf(stage)).completed(200),
      );
      expect(timeline.frameIn(stage, 1.5).local, 1);
    }
    for (final double step in <double>[1, 8, 35.5, 100, 200]) {
      expect(
        timeline.frameIn(LmStage.loop, timeline.loopThrough(step)).step,
        closeTo(step, 1e-6),
      );
    }
  });

  test('a stage played through is its still frame, the loop at its last step', () {
    final TrainingFrame start = timeline.stateAt(timeline.startOf(LmStage.loop));
    expect(start.completed(200).local, 1);
    expect(start.completed(200).step, 200);
    final TrainingFrame forward = timeline.stateAt(timeline.startOf(LmStage.forward));
    expect(forward.completed(200).step, 1);
  });
}
