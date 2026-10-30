import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_format.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_inks.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_drawing.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene_painter.dart';

import 'support/toy_trace.dart';

/// The page's inks and kit, as the screen builds them from the theme.
Future<(LmInks, LmKit)> _drawing(WidgetTester tester) async {
  late LmInks inks;
  late LmKit kit;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          inks = LmInks.of(context);
          kit = LmKit(
            mono: AppTypography.sequenceSmall(theme.colorScheme.onSurfaceVariant),
            sans: theme.caption!,
            scaler: TextScaler.noScaling,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (inks, kit);
}

void main() {
  final TrainingTrace trace = toyTrace();
  final TrainingTimeline timeline = TrainingTimeline(steps: trace.steps.count);

  LmView view(LmInks inks, LmKit kit, {int checkpoint = 0, int peptide = 0, int position = 3, int? head}) =>
      LmView(
        trace: trace,
        checkpoint: trace.checkpoints[checkpoint],
        peptide: peptide,
        position: position,
        head: head,
        inks: inks,
        kit: kit,
      );

  void paint(LmView view, Size size, double t) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    LmScenePainter(view: view, frame: () => timeline.stateAt(t)).paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }

  testWidgets('every stage paints at every frame of a second, at every checkpoint', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final int frames = timeline.beats * 60;
    for (int c = 0; c < trace.checkpoints.length; c++) {
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: trace.peptides[p].inputs - 1);
        for (int i = 0; i <= frames; i += c == 0 && p == 0 ? 1 : 7) {
          paint(scene, const Size(393, 540), i / frames);
        }
      }
    }
    // A cramped phone, and a head shown alone.
    for (int i = 0; i <= frames; i += 5) {
      paint(view(inks, kit, head: 1), const Size(320, 300), i / frames);
    }
  });

  testWidgets("each stage's caption says the run's own numbers", (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView last = view(inks, kit, checkpoint: trace.checkpoints.length - 1);
    String caption(LmStage stage, double local) {
      final TrainingFrame frame = timeline.stateAt(
        timeline.startOf(stage) + local * stage.beats / timeline.beats,
      );
      return sceneOf(frame.stage).caption(last, frame);
    }

    expect(caption(LmStage.tokenise, 0.2), 'Two peptides, 23 residues, become ids in a 23-token vocabulary');
    expect(caption(LmStage.tokenise, 0.6), 'One batch: both peptides in one table, read by Forward in one pass');
    expect(caption(LmStage.tokenise, 0.99), startsWith('The vocabulary, counted: '));
    expect(caption(LmStage.forward, 0.05), contains('× ${trace.model.width} numbers'));
    expect(caption(LmStage.predict, 0.99), contains('next is ${trace.token(last.target)}'));
    expect(caption(LmStage.loss, 0.99), contains(nats(trace.loss(last.step))));
    expect(caption(LmStage.update, 0.5), contains(scientific(trace.steps.learningRate[last.step - 1])));
    final TrainingFrame end = timeline.stateAt(1);
    expect(sceneOf(LmStage.loop).caption(last, end), startsWith('Step 20 of 20 · ${nats(trace.loss(20))} nats'));
  });

  testWidgets('a tap asks for what lies under it', (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    final LmView scene = view(inks, kit);

    // Tokenise: a peptide's row puts it in focus.
    LmHit? found;
    for (double y = 0; y < size.height && found is! FocusPeptide; y += 2) {
      final LmHit? hit = sceneOf(LmStage.tokenise).hit(size, scene, Offset(200, y));
      if (hit is FocusPeptide && hit.peptide == 1) {
        found = hit;
      }
    }
    expect(found, isA<FocusPeptide>());

    // Tokenise, its table closed: a row of the table puts its peptide in focus.
    final TrainingFrame closed = timeline.stateAt(
      timeline.startOf(LmStage.tokenise) + 0.99 * LmStage.tokenise.beats / timeline.beats,
    );
    final Set<int> rows = <int>{};
    for (double y = 0; y < size.height; y += 1) {
      final LmHit? hit = sceneOf(LmStage.tokenise).hitAt(size, scene, Offset(200, y), closed);
      if (hit is FocusPeptide) {
        rows.add(hit.peptide);
      }
    }
    expect(rows, <int>{for (int p = 0; p < trace.peptides.length; p++) p});

    // Loop: the last checkpoint's tick, at the right of the chart.
    LmHit? pick;
    for (double y = 0; y < size.height && pick == null; y += 2) {
      final LmHit? hit = sceneOf(LmStage.loop).hit(size, scene, Offset(size.width - 16, y));
      if (hit is PickCheckpoint) {
        pick = hit;
      }
    }
    expect((pick! as PickCheckpoint).index, trace.checkpoints.length - 1);

    // Forward: a head's map shows it alone; again, all of them.
    LmHit? head;
    for (double x = 80; x < size.width && head == null; x += 2) {
      for (double y = 0; y < size.height / 2 && head == null; y += 2) {
        final LmHit? hit = sceneOf(LmStage.forward).hit(size, scene, Offset(x, y));
        if (hit is FocusHead) {
          head = hit;
        }
      }
    }
    expect((head! as FocusHead).head, 0);
  });

  test('numbers are written as the page writes them', () {
    expect(nats(3.14482), '3.145');
    expect(percent(0.991), '99%');
    expect(percent(0.0423), '4.2%');
    expect(scientific(1e-5), '1.0e−5');
    expect(scientific(0.00099996), '1.0e−3');
    expect(signed(-0.0123, 2), '−0.01');
  });
}
