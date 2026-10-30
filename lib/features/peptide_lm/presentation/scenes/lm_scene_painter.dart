import 'package:flutter/material.dart';

import '../../domain/training_timeline.dart';
import 'backward_scene.dart';
import 'forward_scene.dart';
import 'lm_scene.dart';
import 'loop_scene.dart';
import 'loss_scene.dart';
import 'predict_scene.dart';
import 'shift_scene.dart';
import 'tokenise_scene.dart';
import 'update_scene.dart';

LmScene sceneOf(LmStage stage) => switch (stage) {
  LmStage.tokenise => const TokeniseScene(),
  LmStage.shift => const ShiftScene(),
  LmStage.forward => const ForwardScene(),
  LmStage.predict => const PredictScene(),
  LmStage.loss => const LossScene(),
  LmStage.backward => const BackwardScene(),
  LmStage.update => const UpdateScene(),
  LmStage.loop => const LoopScene(),
};

/// Paints whichever stage the frame is in, at the frame it asks for.
final class LmScenePainter extends CustomPainter {
  LmScenePainter({required this.view, required this.frame, super.repaint});

  final LmView view;

  /// The moment to draw, read when painting, so a running clock repaints
  /// without a rebuild.
  final TrainingFrame Function() frame;

  @override
  void paint(Canvas canvas, Size size) {
    final TrainingFrame now = frame();
    canvas.clipRect(Offset.zero & size);
    sceneOf(now.stage).paint(canvas, size, view, now);
  }

  @override
  bool shouldRepaint(LmScenePainter oldDelegate) => !identical(oldDelegate.view, view);
}
