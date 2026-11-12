import 'package:flutter/material.dart';

import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_info_sheet.dart';
import '../lm_inks.dart';
import 'lm_drawing.dart';

/// Everything a scene draws from, but the moment: the run, the checkpoint the
/// eight stages show, what the reader has put in focus, and how to draw.
@immutable
final class LmView {
  const LmView({
    required this.trace,
    required this.checkpoint,
    required this.peptide,
    required this.position,
    required this.inks,
    required this.kit,
  });

  final TrainingTrace trace;
  final TraceCheckpoint checkpoint;

  /// The peptide in focus, and the position in it whose prediction is shown.
  final int peptide;
  final int position;
  final LmInks inks;
  final LmKit kit;

  TracePeptide get focus => trace.peptides[peptide];

  int get step => checkpoint.step;

  /// The id the position in focus is trained to predict.
  int get target => trace.targetAt(peptide, position);
}

/// What a tap on a scene asks for.
sealed class LmHit {
  const LmHit();
}

final class FocusPeptide extends LmHit {
  const FocusPeptide(this.peptide);

  final int peptide;
}

final class FocusPosition extends LmHit {
  const FocusPosition(this.position);

  final int position;
}

final class PickCheckpoint extends LmHit {
  const PickCheckpoint(this.index);

  final int index;
}

/// One stage, drawn as a pure function of the frame: the same frame always
/// draws the same picture, whatever was drawn before it.
abstract class LmScene {
  const LmScene();

  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame);

  /// The line under the canvas: what this moment shows, in the run's numbers.
  String caption(LmView view, TrainingFrame frame);

  /// What a screen reader hears for the picture.
  String describe(LmView view, TrainingFrame frame) => caption(view, frame);

  /// The stage's own info page, which the ⓘ opens: what it takes and gives,
  /// then the parts of its canvas the page adds to, each a section under its
  /// tag, in the run's numbers.
  LmInfo info(LmView view);

  /// Whether the step picked changes anything here. A stage made once,
  /// before training, draws, says and explains the same at every
  /// checkpoint, and the page shows it no Step menu.
  bool get stepped => true;

  LmHit? hit(Size size, LmView view, Offset at) => null;

  /// What a tap asks for at [frame]: [hit], for a scene whose layout holds
  /// still through its stage.
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) => hit(size, view, at);

  /// The position under a finger dragged along the token row, where the
  /// scene has one there.
  int? positionAt(Size size, LmView view, Offset at) => null;
}
