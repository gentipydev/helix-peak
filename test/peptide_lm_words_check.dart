// Every caption, note and info page of the Peptide Language Model's stages,
// from a recorded run, written to one text file: what a stage already says
// on screen, which its info page must not say again
// (docs/design/peptide-lm-info-pages.md).
//
// Opt-in: skipped unless WORDS is set, so `flutter test` stays offline.
//
//   WORDS=/tmp/lm_words.txt \
//   TRACE=../helix-peek-backend/pipeline/denovo/runs/curated/trace.json \
//     flutter test test/peptide_lm_words_check.dart
//
// CHECKPOINTS picks the checkpoints by index (default the first and the
// last), PEPTIDE the peptide in focus (default 0) and POSITION its place
// (default its middle, as the page opens). A caption is written once, at the
// beat it first shows; a note with the beats it stays up.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/peptide_lm/domain/loop_pace.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_info_sheet.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_inks.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/attention_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/backward_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/embedding_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/feed_forward_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/forward_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_drawing.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene_painter.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/loop_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/loss_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/predict_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/scores_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/update_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/worked_answer.dart';

void main() {
  testWidgets('every stage says, in captions, notes and its info page', (WidgetTester tester) async {
    final TrainingTrace trace = TrainingTrace.parse(File(Platform.environment['TRACE']!).readAsBytesSync());
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
    addTearDown(kit.dispose);
    const TrainingTimeline timeline = TrainingTimeline();
    final int peptide = int.parse(Platform.environment['PEPTIDE'] ?? '0');
    final int position =
        int.parse(Platform.environment['POSITION'] ?? '${trace.peptides[peptide].inputs ~/ 2}');
    final List<int> checkpoints = Platform.environment['CHECKPOINTS'] == null
        ? <int>[0, trace.checkpoints.length - 1]
        : <int>[for (final String i in Platform.environment['CHECKPOINTS']!.split(',')) int.parse(i)];
    final StringBuffer out = StringBuffer();
    for (final int checkpoint in checkpoints) {
      final LmView view = LmView(
        trace: trace,
        checkpoint: trace.checkpoints[checkpoint],
        peptide: peptide,
        position: position,
        head: null,
        inks: inks,
        kit: kit,
      );
      out.writeln('######## step ${view.step}, ${view.focus.source.label}, place $position');
      for (final LmStage stage in LmStage.values) {
        out.writeln('==== ${stage.label} (${stage.beats} beats)');
        final List<double> moments = stage == LmStage.loop
            ? LoopPace.of(trace).samples
            : <double>[for (int i = 0; i <= 400; i++) i / 400];
        String? last;
        for (final double local in moments) {
          final String caption = sceneOf(stage).caption(view, timeline.frameIn(stage, local));
          if (caption != last) {
            out.writeln('caption  ${(local * stage.beats).toStringAsFixed(2)}: $caption');
            last = caption;
          }
        }
        final List<(double, double, String)> notes = switch (stage) {
          LmStage.tokenise || LmStage.shift => <(double, double, String)>[],
          LmStage.embedding => EmbeddingScene.notes(view),
          LmStage.scores => ScoresScene.notes(view),
          // The worked answer's notes run on its own clock, from its start.
          LmStage.attention => <(double, double, String)>[
            ...AttentionScene.notes(view),
            ...WorkedAnswer.notes(view),
          ],
          LmStage.feedForward => FeedForwardScene.notes(view),
          LmStage.forward => ForwardScene.notes(view),
          LmStage.predict => PredictScene.notes(view),
          LmStage.loss => LossScene.notes(view),
          LmStage.backward => BackwardScene.notes(view),
          LmStage.update => UpdateScene.notes(view),
          LmStage.loop => LoopScene.notes(view),
        };
        for (final (double from, double to, String text) in notes) {
          out.writeln(
            'note     ${from.toStringAsFixed(2)}–${to.isFinite ? to.toStringAsFixed(2) : 'end'}: '
            '${text.replaceAll('\n', ' / ')}',
          );
        }
        final LmInfo? info = sceneOf(stage).info(view);
        if (info != null) {
          out.writeln('info     ${info.title}');
          if (info.lead case final String lead) {
            out.writeln('info       $lead');
          }
          for (final LmInfoSection section in info.sections) {
            out.writeln('info     ${section.title}');
            for (final String paragraph in section.paragraphs) {
              out.writeln('info       $paragraph');
            }
          }
        }
      }
    }
    File(Platform.environment['WORDS']!).writeAsStringSync(out.toString());
  }, skip: Platform.environment['WORDS'] == null);
}
