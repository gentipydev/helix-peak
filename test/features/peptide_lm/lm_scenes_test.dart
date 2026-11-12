import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/peptide_lm/domain/loop_pace.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_format.dart';
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
import 'package:helixpeek/features/peptide_lm/presentation/scenes/shift_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/stream_table.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/tokenise_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/update_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/worked_answer.dart';
import 'package:helixpeek/shared/format.dart';

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
  const TrainingTimeline timeline = TrainingTimeline();

  LmView view(LmInks inks, LmKit kit, {int checkpoint = 0, int peptide = 0, int position = 3}) =>
      LmView(
        trace: trace,
        checkpoint: trace.checkpoints[checkpoint],
        peptide: peptide,
        position: position,
        inks: inks,
        kit: kit,
      );

  void paint(LmView view, Size size, double t) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    LmScenePainter(view: view, frame: () => timeline.stateAt(t)).paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }

  /// [run] as a page is opened on it: its first checkpoint, the first
  /// peptide in focus.
  LmView on(TrainingTrace run, LmInks inks, LmKit kit, {int checkpoint = 0}) => LmView(
    trace: run,
    checkpoint: run.checkpoints[checkpoint],
    peptide: 0,
    position: 3,
    inks: inks,
    kit: kit,
  );

  /// A page's words: its lead and its paragraphs, one after another.
  String words(LmInfo info) => <String>[
    if (info.lead case final String lead) lead,
    for (final LmInfoSection section in info.sections) ...section.paragraphs,
  ].join('\n');

  /// The toy run, its JSON changed by [edit] first: `TrainingTrace.parse`
  /// checks shapes, not meanings, so a letter, a reason or a number can be
  /// changed where the shapes stay.
  TrainingTrace edited(void Function(Map<String, Object?> json) edit) {
    final Map<String, Object?> json = jsonDecode(utf8.decode(toyBytes())) as Map<String, Object?>;
    edit(json);
    return TrainingTrace.parse(Uint8List.fromList(utf8.encode(jsonEncode(json))), name: 'toy');
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
    // A cramped phone.
    for (int i = 0; i <= frames; i += 5) {
      paint(view(inks, kit), const Size(320, 300), i / frames);
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
    expect(caption(LmStage.tokenise, 0.6), 'One batch: both peptides in one matrix, read by Forward in one pass');
    expect(caption(LmStage.tokenise, 0.99), startsWith('The vocabulary, counted: '));
    // Shift, beat by beat: x, its copy, the copy one place left, and what
    // that makes.
    double shift(double beat) => beat / LmStage.shift.beats;
    expect(
      caption(LmStage.shift, shift(0.5)),
      'Input x: each frame less its last place, ${trace.peptides.length} × ${trace.width} tokens',
    );
    expect(caption(LmStage.shift, shift(2)), 'Target y starts as a copy of the same peptides');
    expect(
      caption(LmStage.shift, shift(3)),
      "One place to the left: each place's answer is the token after it",
    );
    expect(
      caption(LmStage.shift, 0.99),
      'Only x goes in; Loss grades each guess against y: ${trace.targetCount} targets',
    );
    // Embedding, beat by beat: the table, what its numbers are, the lookup,
    // the gather, the position embedding and x0.
    final int width = trace.model.width;
    double embedding(double beat) => beat / LmStage.embedding.beats;
    expect(
      caption(LmStage.embedding, embedding(0.5)),
      'The token embedding, 23 × $width, learned with the rest of the model',
    );
    expect(
      caption(LmStage.embedding, embedding(2)),
      "At step ${last.step} they have had ${last.step - 1} updates; <pad>'s row is zero at every checkpoint",
    );
    final TrainingFrame untrained = timeline.frameIn(LmStage.embedding, embedding(2));
    expect(
      sceneOf(LmStage.embedding).caption(view(inks, kit), untrained),
      "At step 1 no update has moved them yet; <pad>'s row is zero at every checkpoint",
    );
    expect(caption(LmStage.embedding, embedding(3)), "12 places read 9 rows of the table, C's three times");
    expect(caption(LmStage.embedding, embedding(6)), "12 places read 9 rows of the table, C's three times");
    expect(caption(LmStage.embedding, embedding(8)), "Each row is one place: <bos> (<), then toy A's 11 residues");
    expect(
      caption(LmStage.embedding, embedding(12.2)),
      'The position embedding: one trainable row per place, here rows 0–11 of ${trace.model.context}',
    );
    expect(
      caption(LmStage.embedding, embedding(14)),
      'Token + position, number by number: x0, the rows every block reads and adds to',
    );
    expect(caption(LmStage.embedding, embedding(14.9)), caption(LmStage.embedding, embedding(14)));
    // Why the sum, in one note to the stage's end, a sentence a line, from
    // the run's own numbers: what training did to the position rows' size
    // against the token rows', from the first step to the last.
    final int grown = EmbeddingScene.smaller(last);
    final int faint = EmbeddingScene.smaller(last, trace.checkpoints.first);
    expect(grown, isNot(faint));
    expect(
      EmbeddingScene.notes(last).last.$3.split('\n'),
      <String>[
        'Attention, next, reads rows as a bag, blind to their order.',
        'So each token row (what) gets a position row (where) added.',
        'The Cs at 6 and 7 share a token row, but now differ by place.',
        'Training ${grown < faint ? 'grew' : 'shrank'} position rows from $faint× smaller to $grown× by step ${last.step}.',
        "x0: one row per place, carrying what + where; the model's input.",
      ],
    );
    // Scores, block 1's attention up to its shares, at the place in focus
    // (V3), beat by beat.
    final LmView last3 = last;
    final int size = trace.headSize;
    String name(int j) => j == 0 ? '<bos>' : '${trace.peptides.first.sequence[j - 1]}$j';
    double score(int h, int j) => trace.score(last3.checkpoint, 0, h, 0, 3, j);
    // The shares, softmax of the scores as kept.
    List<double> shares(int h) {
      final List<double> e = <double>[for (int j = 0; j <= 3; j++) math.exp(score(h, j))];
      final double sum = e.reduce((double a, double b) => a + b);
      return <double>[for (final double x in e) x / sum];
    }

    String head(int h) {
      final List<double> s = shares(h);
      final List<int> order = <int>[for (int j = 0; j <= 3; j++) j]..sort((int a, int b) => s[b].compareTo(s[a]));
      return '${name(order.first)} ${percent(s[order.first])}'
          '${s[order[1]] >= 0.1 ? ', ${name(order[1])} ${percent(s[order[1]])}' : ''}';
    }

    // The row in focus's x0, its mean and standard deviation as the
    // LayerNorm takes them.
    final List<double> x = <double>[
      for (int d = 0; d < width; d++)
        trace.tokenEmbedding(last3.checkpoint, trace.inputAt(0, 3), d) + trace.positionEmbedding(last3.checkpoint, 3, d),
    ];
    final double mean = x.reduce((double a, double b) => a + b) / width;
    final double sd = math.sqrt(
      x.map((double v) => (v - mean) * (v - mean)).reduce((double a, double b) => a + b) / width + 1e-5,
    );
    int top = 0;
    for (int j = 1; j <= 3; j++) {
      if (score(0, j) > score(0, top)) {
        top = j;
      }
    }
    double scores(double beat) => beat / LmStage.scores.beats;
    expect(
      caption(LmStage.scores, scores(0.5)),
      'Block 1 of ${trace.model.layers}, attention: first a query, key and value a place',
    );
    expect(
      caption(LmStage.scores, scores(2)),
      "V3's row, evened out first: mean ${fixed(mean, 2)}, standard deviation ${fixed(sd, 2)}",
    );
    expect(caption(LmStage.scores, scores(2.8)), 'Less the mean, ${fixed(mean, 2)}: the row centres on zero');
    expect(
      caption(LmStage.scores, scores(3.5)),
      'Over the standard deviation, ${fixed(sd, 2)}: each number a z-score',
    );
    expect(caption(LmStage.scores, scores(4.5)), 'Then evened = z-score × scale + shift, each column its own');
    expect(
      caption(LmStage.scores, scores(5.5)),
      'Scales and shifts after ${last3.step - 1} updates: the row attention reads',
    );
    expect(
      sceneOf(LmStage.scores).caption(view(inks, kit), timeline.frameIn(LmStage.scores, scores(5.5))),
      'At step 1 every scale is 1 and every shift 0: evened = z-score',
    );
    // The row through the query's weights, the model's own: query number 1
    // first, its sum the kept query's, then the rest, then the weights left
    // standing; at step 1 as the seed drew them, later moved by training.
    final LmView first = view(inks, kit);
    String scoresAt(LmView at, double beat) =>
        sceneOf(LmStage.scores).caption(at, timeline.frameIn(LmStage.scores, scores(beat)));
    double query1(LmView at) => trace.query(at.checkpoint, 0, 0, 0, 3, 0);
    for (final LmView at in <LmView>[first, last3]) {
      double sum = trace.projectionBias(at.checkpoint, 0, 0, 0);
      for (int d = 0; d < width; d++) {
        sum += trace.projection(at.checkpoint, 0, 0, 0, d) * trace.attnInput(at.checkpoint, 0, 0, 3, d);
      }
      expect(sum, closeTo(query1(at), 1e-4));
    }
    expect(trace.projectionBias(first.checkpoint, 0, 0, 0), 0);
    expect(scoresAt(first, 7.2), "Query number 1: V3's numbers × weights, summed: ${fixed(query1(first), 2)}");
    expect(
      caption(LmStage.scores, scores(7.2)),
      "Query number 1: V3's numbers × weights, summed, + bias: ${fixed(query1(last3), 2)}",
    );
    expect(
      caption(LmStage.scores, scores(8.5)),
      'The other ${width - 1} the same way, each through its own $width weights',
    );
    expect(caption(LmStage.scores, scores(9.8)), "The query's ${width * width} weights: a string each, $width into every number");
    expect(caption(LmStage.scores, scores(11)), "The key: the same row through the key's own $width × $width weights");
    expect(caption(LmStage.scores, scores(12)), 'The value: the same row again, through a third $width × $width');
    expect(ScoresScene.weightsStatus(first), 'random start (seed ${trace.config.seed}), no update yet');
    expect(
      ScoresScene.weightsStatus(last3),
      'random start (seed ${trace.config.seed}), then ${last3.step - 1} training updates',
    );
    expect(
      caption(LmStage.scores, scores(13)),
      'Cut in two: head 1 takes numbers 1–$size of each, head 2 ${size + 1}–${2 * size}',
    );
    expect(
      caption(LmStage.scores, scores(14)),
      'Every place does the same, with the same weights: 12 keys of $size',
    );
    final String topName = top == 3 ? 'its own' : "${name(top)}'s";
    expect(caption(LmStage.scores, scores(15.5)), "V3's query times $topName key, number by number: $size products");
    expect(
      caption(LmStage.scores, scores(17)),
      'Summed, ${fixed(score(0, top) * math.sqrt(size), 2)}; over √$size, ${fixed(score(0, top), 2)}: $topName score',
    );
    expect(caption(LmStage.scores, scores(17.8)), "V3's query against each key up to its own: 4 scores");
    expect(caption(LmStage.scores, scores(19)), 'Softmax makes the scores shares of one: ${head(0)}');
    expect(caption(LmStage.scores, 0.99), 'Softmax makes the scores shares of one: ${head(0)}');
    // Attention, after Scores: head 1's values, head 2, number 1 of head 1's
    // answer worked out, the answers through the output weights, head 1's map
    // (the row in focus first, then every row), what attention adds.
    double attention(double beat) => beat / LmStage.attention.beats;
    expect(caption(LmStage.attention, attention(0.5)), "Head 1 hands V3 its shares of each place's value: $size numbers");
    expect(caption(LmStage.attention, attention(2.5)), 'Head 2, its own query and keys: V3 reads ${head(1)}');
    // Number 1 of head 1's answer worked out, its number not given till it is
    // made: V3's own value, as Scores made it, then <bos>'s through the same
    // weights, with their bias once training has given them one; every place
    // times its share; their sum, the answer as the run kept it.
    double value1(int j) => trace.value(last3.checkpoint, 0, 0, 0, j, 0);
    final String valueBias = trace.projectionBias(last3.checkpoint, 0, 2, 0) != 0 ? ', + bias' : '';
    expect(valueBias, isNotEmpty);
    final double answer1 = trace.mixed(last3.checkpoint, 0, 0, 0, 3, 0);
    expect(caption(LmStage.attention, attention(4.8)), "Number 1 of head 1's answer, worked out");
    expect(
      caption(LmStage.attention, attention(5.9)),
      "V3's value 1, as in Scores: its row × $width weights$valueBias: ${WorkedAnswer.term(value1(3), 2)}",
    );
    expect(
      caption(LmStage.attention, attention(7.1)),
      "<bos>'s value 1: its own row, the same $width weights$valueBias: ${WorkedAnswer.term(value1(0), 2)}",
    );
    expect(caption(LmStage.attention, attention(8.1)), 'Every place the same: its own row, the same weights');
    final List<double> brought = <double>[for (int j = 0; j <= 3; j++) shares(0)[j] * value1(j)];
    int most = 0;
    int largest = 0;
    for (int j = 1; j <= 3; j++) {
      if (brought[j].abs() > brought[most].abs()) {
        most = j;
      }
      if (shares(0)[j] > shares(0)[largest]) {
        largest = j;
      }
    }
    String share(int j) => WorkedAnswer.tenth(shares(0)[j]);
    expect(caption(LmStage.attention, attention(9.1)), 'Each place adds its value 1 × its share: the last column');
    // Then one place at a time: the largest share, and what it adds; then the
    // place that adds most, and why.
    if (most == largest) {
      final String both = 'Largest share: ${name(most)}, ${share(most)}, of a value of '
          '${WorkedAnswer.term(value1(most), 2)}: it adds most, ${WorkedAnswer.term(brought[most], 3)}';
      expect(caption(LmStage.attention, attention(10.1)), both);
      expect(caption(LmStage.attention, attention(11.1)), both);
    } else {
      expect(
        caption(LmStage.attention, attention(10.1)),
        'Largest share: ${name(largest)}, ${share(largest)}, but its value is '
        '${WorkedAnswer.term(value1(largest), 2)}: it adds only ${WorkedAnswer.term(brought[largest], 3)}',
      );
      expect(
        caption(LmStage.attention, attention(11.1)),
        '${name(most)} adds most, ${WorkedAnswer.term(brought[most], 3)}: a smaller share, '
        '${share(most)}, but its value is ${WorkedAnswer.term(value1(most), 2)}',
      );
    }
    expect(caption(LmStage.attention, attention(12.1)), "Summed: ${fixed(answer1, 2)}, number 1 of head 1's answer");
    expect(caption(LmStage.attention, attention(12.9)), 'Numbers 2–$width the same way, each head with its own shares');
    // Number 1 of what attention adds: the stream's own gain across it, the
    // output weights' sum of the heads' answers, with its bias once training
    // has given it one (every bias starts at 0).
    double gained(LmView at) =>
        trace.stream(at.checkpoint, 1, 0, 3, 0) -
        (trace.tokenEmbedding(at.checkpoint, trace.inputAt(0, 3), 0) + trace.positionEmbedding(at.checkpoint, 3, 0));
    String attentionAt(LmView at, double beat) =>
        sceneOf(LmStage.attention).caption(at, timeline.frameIn(LmStage.attention, attention(beat)));
    expect(trace.outBias(first.checkpoint, 0, 0), 0);
    expect(trace.outBias(last3.checkpoint, 0, 0), isNot(0));
    expect(
      attentionAt(first, 14.1),
      'Output number 1: all $width × their weights, summed: ${fixed(gained(first), 2)}',
    );
    expect(
      attentionAt(last3, 14.1),
      'Output number 1: all $width × their weights, summed, + bias: ${fixed(gained(last3), 2)}',
    );
    expect(
      caption(LmStage.attention, attention(15.1)),
      'The other ${width - 1} the same: ${width * width} output weights, $width into each',
    );
    expect(caption(LmStage.attention, attention(15.7)), 'What attention adds to V3');
    expect(caption(LmStage.attention, attention(16.7)), "Head 1's map: V3's row first, its shares from Scores");
    expect(
      caption(LmStage.attention, attention(18.3)),
      'Every place does what V3 did, its query on the keys up to it',
    );
    // Then head 2's map on the same rows: how many rows read most another
    // place than in head 1's.
    expect(caption(LmStage.attention, attention(20.5)), "Head 2's map: the place read most changes in 11 of 12 rows");
    expect(AttentionScene.movedRows(last, 1), 11);
    expect(
      caption(LmStage.attention, attention(22.7)),
      "Every row made as V3's: both heads' answers × output weights",
    );
    expect(caption(LmStage.attention, 0.99), "Added: x0 + block 1's attention, 12 × $width");
    // Feed-forward, block 1's, at V3.
    double fed(double beat) => beat / LmStage.feedForward.beats;
    final int ff = trace.model.feedForward;
    expect(
      caption(LmStage.feedForward, fed(0.5)),
      'Block 1, feed-forward: one small network, each place on its own',
    );
    // The block's second LayerNorm, worked as Scores worked the first, on
    // x0 + attention's row: the network reads what the run kept it made.
    final Evening fedEven = FeedForwardScene.evening(last);
    final List<double> fedRow = <double>[
      for (int d = 0; d < width; d++) trace.stream(last.checkpoint, 1, last.peptide, 3, d),
    ];
    expect(fedEven.x, fedRow);
    expect(fedEven.mean, closeTo(fedRow.reduce((double a, double b) => a + b) / width, 1e-9));
    expect(fedEven.at(1, 1, 1), <double>[
      for (int d = 0; d < width; d++) trace.ffInput(last.checkpoint, FeedForwardScene.block, last.peptide, 3, d),
    ]);
    expect(
      caption(LmStage.feedForward, fed(1.6)),
      "LayerNorm first evens out V3's row: mean ${fixed(fedEven.mean, 2)}, "
      'standard deviation ${fixed(fedEven.sd, 2)}',
    );
    expect(caption(LmStage.feedForward, fed(2.6)), 'Less the mean, ${fixed(fedEven.mean, 2)}: the row centres on zero');
    expect(
      caption(LmStage.feedForward, fed(3.5)),
      'Over the standard deviation, ${fixed(fedEven.sd, 2)}: each number a z-score',
    );
    // Trained, the norm moved the z-scores; at step 1 it left them alone.
    expect(fedEven.plain, isFalse);
    expect(caption(LmStage.feedForward, fed(4.5)), "Then this norm's own learned scale and shift: the row the network reads");
    expect(FeedForwardScene.evening(view(inks, kit)).plain, isTrue);
    expect(
      sceneOf(LmStage.feedForward).caption(view(inks, kit), timeline.frameIn(LmStage.feedForward, fed(4.5))),
      'At step 1 every scale is 1 and every shift 0: evened = z-score',
    );
    expect(caption(LmStage.feedForward, fed(5.1)), 'Each of the $ff neurons gets all $width inputs, each × its own weight');
    // Each neuron is GELU of its sum, the run's to its int8 step: the
    // brightest worked out, then the one GELU silences most.
    final List<double> z = FeedForwardScene.sums(last);
    final double hiddenStep = last.checkpoint.blocks[FeedForwardScene.block].hiddenScale;
    for (int u = 0; u < ff; u++) {
      expect(
        FeedForwardScene.gelu(z[u]),
        closeTo(trace.hidden(last.checkpoint, FeedForwardScene.block, last.peptide, 3, u), hiddenStep / 2 + 1e-4),
      );
    }
    expect(FeedForwardScene.gelu(0), 0);
    expect(FeedForwardScene.gelu(1), closeTo(0.841345, 1e-6));
    expect(FeedForwardScene.gelu(-0.751791), closeTo(-0.169971, 1e-6));
    final (int bright, int low) = FeedForwardScene.worked(last);
    expect(z[bright], z.reduce(math.max));
    expect(z[low], z.reduce(math.min));
    String sum(double v) => fixed(v, 2);
    String passed(double v) => fixed(FeedForwardScene.gelu(double.parse(sum(v).replaceAll('−', '-'))), 2);
    expect(
      caption(LmStage.feedForward, fed(7.5)),
      'Neuron ${bright + 1} adds up its $width inputs × weights, plus its bias: ${sum(z[bright])}',
    );
    expect(caption(LmStage.feedForward, fed(9.5)), 'GELU decides what it passes on: GELU(${sum(z[bright])}) = ${passed(z[bright])}');
    expect(
      caption(LmStage.feedForward, fed(11.5)),
      'Neuron ${low + 1} adds up to ${sum(z[low])}: GELU(${sum(z[low])}) = ${passed(z[low])}, nearly nothing',
    );
    expect(caption(LmStage.feedForward, fed(13)), 'All $ff the same way: ${FeedForwardScene.litNeurons(last)} light up');
    expect(caption(LmStage.feedForward, fed(16)), '$width out, each a weighted sum of the $ff neurons, plus a bias');
    expect(caption(LmStage.feedForward, fed(17.2)), "Back to V3's row, to be added");
    expect(caption(LmStage.feedForward, fed(18.0)), 'What the feed-forward adds to each place: 12 rows of $width');
    expect(caption(LmStage.feedForward, 0.99), "Added: block 1's output, 12 × $width");
    // Forward: V3's row through the whole pass, a part at a time, then the
    // final LayerNorm, worked as Feed-forward's on the run's own numbers.
    double forward(double beat) => beat / LmStage.forward.beats;
    expect(caption(LmStage.forward, forward(0.5)), 'The whole pass for V3: x0, both blocks, then what Predict reads');
    expect(
      caption(LmStage.forward, forward(2)),
      "Block 1's attention adds what V3 gathered from the places up to it",
    );
    expect(caption(LmStage.forward, forward(4)), "Block 1's feed-forward adds its own: V3's row as block 1 left it");
    // Block 2's attention, followed back a block: the place its head 1 reads
    // most, and what that place's head 1 read most in block 1, as
    // Attention's map reads them. T8 reads C7 most, and C7 had read E4.
    String forwardAt(int position) {
      final TrainingFrame frame = timeline.stateAt(
        timeline.startOf(LmStage.forward) + forward(5.5) * LmStage.forward.beats / timeline.beats,
      );
      final LmView scene = view(inks, kit, checkpoint: trace.checkpoints.length - 1, position: position);
      return sceneOf(frame.stage).caption(scene, frame);
    }

    expect(forwardAt(8), 'In block 2, T8 reads C7 30%, which in block 1 read E4 95%');
    expect(ForwardScene.topRead(last, 1, 8).$1, 7);
    expect(ForwardScene.topRead(last, 0, 7).$1, 4);
    // With no second hop it sets its head 1's top read against block 1's:
    // V3 reads itself most in block 2, and E4 reads <bos>, which can read
    // only itself.
    expect(
      caption(LmStage.forward, forward(5.5)),
      'In block 2, V3 reads ${ForwardScene.readsMost(last, 1)} (block 1: ${ForwardScene.readsMost(last, 0)})',
    );
    expect(ForwardScene.topRead(last, 1, 3).$1, 3);
    final LmView e4 = view(inks, kit, checkpoint: trace.checkpoints.length - 1, position: 4);
    expect(
      forwardAt(4),
      'In block 2, E4 reads ${ForwardScene.readsMost(e4, 1)} (block 1: ${ForwardScene.readsMost(e4, 0)})',
    );
    expect(ForwardScene.topRead(e4, 1, 4).$1, 0);
    expect(ForwardScene.readsMost(last, 0), AttentionScene.readsMost(last, AttentionScene.mapHead).split(', ').first);
    expect(ForwardScene.readsMost(last, 1), isNot(ForwardScene.readsMost(last, 0)));
    expect(
      caption(LmStage.forward, forward(7.5)),
      "Block 2's feed-forward adds its network's output: block 2's output",
    );
    final Evening finalEven = ForwardScene.evening(last);
    final int lastPoint = trace.points.length - 1;
    expect(finalEven.x, <double>[for (int d = 0; d < width; d++) trace.stream(last.checkpoint, lastPoint - 1, 0, 3, d)]);
    expect(finalEven.evened, <double>[for (int d = 0; d < width; d++) trace.stream(last.checkpoint, lastPoint, 0, 3, d)]);
    expect(
      caption(LmStage.forward, forward(9)),
      'The final LayerNorm: mean ${fixed(finalEven.mean, 2)}, standard deviation ${fixed(finalEven.sd, 2)}',
    );
    // Trained, the final norm moved the z-scores; at step 1 it left them
    // alone.
    expect(finalEven.plain, isFalse);
    expect(caption(LmStage.forward, forward(10)), 'Then its own learned scale and shift: the row Predict reads');
    expect(ForwardScene.evening(view(inks, kit)).plain, isTrue);
    expect(
      sceneOf(LmStage.forward).caption(view(inks, kit), timeline.frameIn(LmStage.forward, forward(10))),
      'At step 1 every scale is 1 and every shift 0: evened = z-score',
    );
    expect(caption(LmStage.forward, 0.99), "V3's row as Predict reads it: x0 and four parts' additions, evened");
    // Predict, beat by beat: the last row, the slots, the top logit worked
    // out, the rest, the strike, softmax in two steps, the answer, and every
    // place's guess.
    double predict(double beat) => beat / LmStage.predict.beats;
    final int guess = PredictScene.top(last, 3);
    final String guessed = trace.token(guess);
    final List<double> predicted = PredictScene.logits(last, 3);
    final List<double> given = PredictScene.shares(last, 3);
    expect(caption(LmStage.predict, predict(0.5)), "V3's last row, as Forward left it: what the output layer reads");
    expect(caption(LmStage.predict, predict(2)), 'A logit per token: 23 slots, the vocabulary in id order');
    expect(
      caption(LmStage.predict, predict(2.8)),
      "$guessed's logit: V3's row × $guessed's $width weights, summed, + bias: ${fixed(predicted[guess], 2)}",
    );
    expect(caption(LmStage.predict, predict(4)), 'The other 22 the same way, each through its own $width weights');
    expect(caption(LmStage.predict, predict(5.2)), "The output layer's ${23 * width} weights: a string each, $width into every logit");
    expect(caption(LmStage.predict, predict(6.5)), '<pad> (·) and <bos> (<) can never come next: their logits, −∞');
    double total = 0;
    for (final int id in trace.allowed) {
      total += math.exp(predicted[id]);
    }
    expect(
      caption(LmStage.predict, predict(7.5)),
      "e to each logit: all positive, the largest pulls ahead: $guessed's ${exponential(math.exp(predicted[guess]))}",
    );
    expect(
      caption(LmStage.predict, predict(8.5)),
      startsWith('Over their sum, ${exponential(total)}: shares of 100%, $guessed ${percent(given[guess])}'),
    );
    final String next = trace.token(last.target);
    expect(
      caption(LmStage.predict, predict(10)),
      guess == last.target
          ? 'Top bet after GIV: $next, ${percent(given[guess])}, the true next ${trace.isResidue(last.target) ? 'residue' : 'token'}'
          : 'Top bet after GIV: $guessed, ${percent(given[guess])}. '
                'True next ${trace.isResidue(last.target) ? 'residue' : 'token'}, $next, got ${percent(given[last.target])}',
    );
    expect(caption(LmStage.predict, predict(11)), 'Every place guesses at once, with the same weights: 12 rows of 21');
    expect(
      caption(LmStage.predict, 0.99),
      'Lit, what came next (y): the top guess at ${PredictScene.right(last)} of 12 places',
    );
    // Loss, beat by beat: p(y) alone, −ln on its curve, the place in focus
    // worked out, target y, every target's cost, and their mean.
    double loss(double beat) => beat / LmStage.loss.beats;
    final List<double> answered = <double>[
      for (int i = 0; i < last.focus.inputs; i++) PredictScene.shares(last, i)[trace.targetAt(0, i)],
    ];
    expect(
      caption(LmStage.loss, loss(1)),
      'Loss reads one share a place, p(y): here from ${percent(answered.reduce(math.min))} to ${percent(answered.reduce(math.max))}',
    );
    expect(caption(LmStage.loss, loss(3)), '−ln p(y), in nats: an even guess, 1/21 a token, scores ln 21 = ${nats(trace.uniform)}');
    final (String written, String percentage, String spent) = LossScene.worked(last);
    // The worked sum reads right: the share to three figures, its cost
    // worked out from the share as written.
    expect(double.parse(written), closeTo(given[last.target], given[last.target] * 5e-3));
    expect(spent, LossScene.cost(-math.log(double.parse(written))));
    expect(caption(LmStage.loss, loss(5)), startsWith('V3 gave $next $percentage: −ln $written = $spent nats, '));
    // The peptide in focus alone, then the whole batch.
    expect(caption(LmStage.loss, loss(7)), "Target y, as Shift made it: toy A's 12 targets");
    final List<double> line = LossScene.surprises(last).first;
    expect(
      caption(LmStage.loss, loss(9)),
      "Each target's −ln p(y), as V3's: from ${LossScene.cost(line.reduce(math.min))} to ${LossScene.cost(line.reduce(math.max))} nats",
    );
    expect(caption(LmStage.loss, loss(10.5)), 'The whole batch: 25 targets across two peptides');
    final List<double> costs = <double>[for (final List<double> line in LossScene.surprises(last)) ...line];
    expect(
      caption(LmStage.loss, loss(12)),
      "All 25 targets' −ln p(y): from ${LossScene.cost(costs.reduce(math.min))} to ${LossScene.cost(costs.reduce(math.max))} nats",
    );
    expect(caption(LmStage.loss, 0.99), 'The loss, their mean: ${nats(trace.loss(last.step))} nats; the floor here is ${nats(trace.floor)}');
    // At each checkpoint, the mean says what the step was kept for passing.
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView at = view(inks, kit, checkpoint: c);
      final String head = 'The loss, their mean: ${nats(trace.loss(at.step))} nats';
      final List<String> why = trace.checkpoints[c].why;
      expect(
        LossScene.mean(at),
        why.contains('uniform')
            ? '$head, first under an even guess, ${nats(trace.uniform)}'
            : why.contains('unigram')
            ? '$head, first under residue counts, ${nats(trace.unigram)}'
            : why.contains('bigram')
            ? '$head, first under residue pairs, ${nats(trace.bigram)}'
            : why.contains('one_nat')
            ? '$head, the first step under one nat'
            : why.contains('last')
            ? '$head; the floor here is ${nats(trace.floor)}'
            : '$head, ${trace.loss(at.step) > trace.uniform ? 'worse than' : 'under'} an even guess, ${nats(trace.uniform)}',
        reason: 'step ${at.step}',
      );
    }
    expect(caption(LmStage.update, 21.0 / LmStage.update.beats), contains(nats(trace.steps.gradNorm[last.step - 1])));
    final TrainingFrame end = timeline.stateAt(1);
    expect(
      sceneOf(LmStage.loop).caption(last, end),
      'Step 20 of 20: ${trace.peptides[0].source.label} right at '
      '${PredictScene.right(last)} of its ${trace.peptides[0].inputs} places',
    );
    expect(sceneOf(LmStage.loop).caption(view(inks, kit), timeline.frameIn(LmStage.loop, 0)), startsWith('Step 1 of 20 done'));
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

    // Shift: a row of the matrix it opens on puts its peptide in focus, and
    // a peptide's card once the matrix has opened out.
    for (final double local in <double>[0, 1]) {
      final Set<int> found = <int>{};
      for (double y = 0; y < size.height; y += 1) {
        final LmHit? hit = sceneOf(LmStage.shift)
            .hitAt(size, scene, Offset(200, y), timeline.frameIn(LmStage.shift, local));
        if (hit is FocusPeptide) {
          found.add(hit.peptide);
        }
      }
      expect(found, <int>{for (int p = 0; p < trace.peptides.length; p++) p});
    }

    // Scores, Attention, Feed-forward and Forward: a row, or its row of a
    // map, puts its place in focus, every place reachable.
    for (final (LmStage stage, double local) in <(LmStage, double)>[
      (LmStage.scores, 0),
      (LmStage.scores, 0.3),
      (LmStage.scores, 1),
      (LmStage.attention, 0),
      (LmStage.attention, 1),
      (LmStage.feedForward, 0.01),
      (LmStage.feedForward, 1),
      (LmStage.forward, 0),
    ]) {
      final Set<int> places = <int>{};
      for (double y = 0; y < size.height; y += 1) {
        final LmHit? hit = sceneOf(stage).hitAt(size, scene, Offset(30, y), timeline.frameIn(stage, local));
        if (hit is FocusPosition) {
          places.add(hit.position);
        }
      }
      expect(places, <int>{for (int i = 0; i < trace.peptides.first.inputs; i++) i}, reason: '${stage.label} $local');
    }
    // Forward's ladder is one place's: once the table has gone, a tap asks
    // for nothing.
    expect(
      sceneOf(LmStage.forward).hitAt(size, scene, const Offset(30, 300), timeline.frameIn(LmStage.forward, 0.5)),
      isNull,
    );
    // Predict's bench is one place's: a tap asks for nothing; once its map has
    // come, a row of it puts its place in focus, every place reachable.
    expect(
      sceneOf(LmStage.predict).hitAt(size, scene, const Offset(30, 300), timeline.frameIn(LmStage.predict, 0.4)),
      isNull,
    );
    final PredictLayout predicted = PredictLayout(size, scene);
    for (int i = 0; i < trace.peptides.first.inputs; i++) {
      for (final int k in <int>[0, trace.allowed.length - 1]) {
        final LmHit? hit = sceneOf(LmStage.predict)
            .hitAt(size, scene, predicted.mapCell(i, k).center, timeline.frameIn(LmStage.predict, 1));
        expect((hit! as FocusPosition).position, i, reason: 'row $i, column $k');
      }
      // So does the row's end, where the answer key names what came next.
      final LmHit? key = sceneOf(LmStage.predict)
          .hitAt(size, scene, predicted.answerTile(i).center, timeline.frameIn(LmStage.predict, 1));
      expect((key! as FocusPosition).position, i, reason: 'row $i, its answer');
    }
    // Loss: while the table shows, a row puts its place in focus, every place
    // reachable; while the key swings, or the line shrinks, a tap asks for
    // nothing; on the line alone, a target puts its place in focus; on the
    // batch, a line puts its peptide in focus, and a target of the focus line
    // its place.
    for (final double beat in <double>[1, 4.5]) {
      final Set<int> places = <int>{};
      for (double y = 0; y < size.height; y += 1) {
        final LmHit? hit = sceneOf(LmStage.loss)
            .hitAt(size, scene, Offset(30, y), timeline.frameIn(LmStage.loss, beat / LmStage.loss.beats));
        if (hit is FocusPosition) {
          places.add(hit.position);
        }
      }
      expect(places, <int>{for (int i = 0; i < trace.peptides.first.inputs; i++) i}, reason: 'Loss at $beat');
    }
    expect(
      sceneOf(LmStage.loss).hitAt(size, scene, const Offset(200, 300), timeline.frameIn(LmStage.loss, 7 / LmStage.loss.beats)),
      isNull,
    );
    final LossLayout scored = LossLayout(size, scene);
    final TrainingFrame alone = timeline.frameIn(LmStage.loss, 9 / LmStage.loss.beats);
    for (int i = 0; i < trace.peptides.first.inputs; i++) {
      final LmHit? hit = sceneOf(LmStage.loss).hitAt(size, scene, scored.soloTile(i).center, alone);
      expect((hit! as FocusPosition).position, i, reason: 'target $i alone');
    }
    expect(
      sceneOf(LmStage.loss).hitAt(size, scene, scored.soloTile(0).center, timeline.frameIn(LmStage.loss, 10.3 / LmStage.loss.beats)),
      isNull,
    );
    final TrainingFrame batch = timeline.frameIn(LmStage.loss, 1);
    for (int i = 0; i < trace.peptides.first.inputs; i++) {
      final LmHit? hit = sceneOf(LmStage.loss).hitAt(size, scene, scored.tile(0, i).center, batch);
      expect((hit! as FocusPosition).position, i, reason: 'target $i');
    }
    final LmHit? line = sceneOf(LmStage.loss).hitAt(size, scene, scored.tile(1, 0).center, batch);
    expect((line! as FocusPeptide).peptide, 1);
    // While the network takes Feed-forward's canvas, a tap asks for nothing.
    expect(
      sceneOf(LmStage.feedForward).hitAt(size, scene, const Offset(30, 300), timeline.frameIn(LmStage.feedForward, 0.4)),
      isNull,
    );
    // Embedding reads every place in turn and draws none as followed: there
    // a tap or a drag asks for nothing, so a place is followed only where it
    // shows.
    for (final double local in <double>[0, 0.5, 1]) {
      for (double y = 0; y < size.height; y += 8) {
        for (double x = 0; x < size.width; x += 24) {
          final Offset at = Offset(x, y);
          expect(sceneOf(LmStage.embedding).hitAt(size, scene, at, timeline.frameIn(LmStage.embedding, local)), isNull);
          expect(sceneOf(LmStage.embedding).positionAt(size, scene, at), isNull);
        }
      }
    }

    // Attention's map lies on the table's rows: a tap on a row of it, on a
    // share it reads or on a place it never reads, puts that row's place in
    // focus.
    // So does head 2's, which takes the same rows after it.
    final AttentionLayout attention = AttentionLayout(size, scene);
    final int places = trace.peptides.first.inputs;
    for (final double beat in <double>[19.1, 21.0]) {
      final TrainingFrame map = timeline.frameIn(LmStage.attention, beat / LmStage.attention.beats);
      for (int i = 0; i < places; i++) {
        for (final int j in <int>[0, places - 1]) {
          final LmHit? hit = sceneOf(LmStage.attention).hitAt(size, scene, attention.mapCell(i, j).center, map);
          expect((hit! as FocusPosition).position, i, reason: 'beat $beat, row $i, column $j');
        }
      }
    }
  });

  testWidgets("Loop draws each step's own guesses, and holds each kept step on the run's numbers", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    final LoopPace pace = LoopPace.of(trace);
    for (int p = 0; p < trace.peptides.length; p++) {
      final LmView scene = view(inks, kit, peptide: p, position: 1);
      for (int c = 0; c < trace.checkpoints.length; c++) {
        final TraceCheckpoint at = trace.checkpoints[c];
        // The map the run draws at a kept step is Predict's there, to the
        // 255th the steps keep it in.
        final List<List<double>> drawn = LoopScene.shares(scene, at.step.toDouble());
        final LmView there = LoopScene.at(scene, c);
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          for (int k = 0; k < trace.allowed.length; k++) {
            expect(drawn[i][k], closeTo(PredictScene.shares(there, i)[trace.allowed[k]], 0.5 / 255 + 1e-6));
          }
        }
        if (c == 0) {
          continue;
        }
        // Held there, the caption names the step, its loss and, but where
        // it names the commonest guess, the run's count of right guesses.
        final String held = sceneOf(LmStage.loop).caption(scene, timeline.frameIn(LmStage.loop, pace.landing(c)));
        expect(held, startsWith('Step ${at.step}: ${nats(trace.loss(at.step))}'));
        int right = 0;
        for (int q = 0; q < trace.peptides.length; q++) {
          right += PredictScene.right(LoopScene.at(scene, c, peptide: q));
        }
        if (!at.why.contains('unigram')) {
          expect(held, contains('right at $right of ${trace.targetCount}'));
        }
      }
    }

    // While Update's frame shows, a tap asks for nothing; held, a kept
    // step's tick picks it and a row of the map its place.
    final LmView scene = view(inks, kit);
    final LoopLayout layout = LoopLayout(size, scene);
    final TrainingFrame opening = timeline.frameIn(LmStage.loop, 0.5 / LmStage.loop.beats);
    for (double y = 0; y < size.height; y += 4) {
      expect(sceneOf(LmStage.loop).hitAt(size, scene, Offset(200, y), opening), isNull);
    }
    final TrainingFrame held = timeline.frameIn(LmStage.loop, pace.landing(trace.checkpoints.length - 1));
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmHit? hit = sceneOf(LmStage.loop).hitAt(
        size,
        scene,
        Offset(layout.x(trace.checkpoints[c].step.toDouble()), layout.plot.bottom + 3),
        held,
      );
      expect(hit, isA<PickCheckpoint>());
      expect((hit! as PickCheckpoint).index, c);
    }
    for (int i = 0; i < trace.peptides[0].inputs; i++) {
      final LmHit? hit = sceneOf(LmStage.loop).hitAt(size, scene, layout.map.cell(i, 3).center, held);
      expect(hit, isA<FocusPosition>());
      expect((hit! as FocusPosition).position, i);
    }
  });

  testWidgets('each stage opens on the last frame of the one before, pixel for pixel', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    Future<List<int>> pixels(LmView scene, TrainingFrame frame) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder)..drawRect(Offset.zero & size, Paint()..color = inks.ground);
      LmScenePainter(view: scene, frame: () => frame).paint(canvas, size);
      final ui.Picture picture = recorder.endRecording();
      final List<int> bytes = (await tester.runAsync(() async {
        final ui.Image image = await picture.toImage(size.width.round(), size.height.round());
        final ByteData? data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      }))!;
      picture.dispose();
      return bytes;
    }

    for (int p = 0; p < trace.peptides.length; p++) {
      final LmView scene = view(inks, kit, peptide: p, checkpoint: trace.checkpoints.length - 1);
      for (final (LmStage before, LmStage after) in <(LmStage, LmStage)>[
        (LmStage.tokenise, LmStage.shift),
        (LmStage.shift, LmStage.embedding),
        (LmStage.embedding, LmStage.scores),
        (LmStage.scores, LmStage.attention),
        (LmStage.attention, LmStage.feedForward),
        (LmStage.feedForward, LmStage.forward),
        (LmStage.forward, LmStage.predict),
        (LmStage.predict, LmStage.loss),
        (LmStage.loss, LmStage.backward),
        (LmStage.backward, LmStage.update),
        (LmStage.update, LmStage.loop),
      ]) {
        final List<int> last = await pixels(scene, timeline.frameIn(before, 1));
        final List<int> first = await pixels(scene, timeline.frameIn(after, 0));
        expect(last.any((int b) => b != last.first), isTrue);
        expect(first, last, reason: '${after.label} opens on ${before.label}');
      }
    }
  });

  testWidgets('the followed peptide and place are marked where they are named, clear of all else', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    bool inside(Rect inner, Rect outer) =>
        inner.left >= outer.left && inner.top >= outer.top && inner.right <= outer.right && inner.bottom <= outer.bottom;
    for (final Size size in const <Size>[Size(440, 697), Size(375, 491), Size(320, 300)]) {
      for (final String stage in <String>['Tokenise', 'Shift']) {
        final (Rect, Rect, Rect) Function(Size, LmView) mark =
            stage == 'Tokenise' ? TokeniseScene.followedMark : ShiftScene.followedMark;
        final Set<double> rows = <double>{};
        for (int p = 0; p < trace.peptides.length; p++) {
          final (Rect plate, Rect card, Rect tile) = mark(size, view(inks, kit, peptide: p));
          final String why = '$stage, peptide $p, $size';
          // On the followed peptide's card, on its name's line, over its
          // tiles, and on the canvas.
          expect(inside(plate, card), isTrue, reason: why);
          expect(plate.bottom, lessThanOrEqualTo(tile.top), reason: why);
          expect(plate.right, lessThanOrEqualTo(size.width), reason: why);
          rows.add(plate.top);
        }
        // A tap on another peptide takes the mark with it.
        expect(rows, hasLength(trace.peptides.length), reason: '$stage, $size');
      }
    }
    // Scores names the followed place under the table, all of it left of
    // the chart and on the canvas.
    for (final Size size in const <Size>[Size(440, 697), Size(375, 476), Size(393, 540)]) {
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView scene = view(inks, kit, peptide: p, position: trace.peptides[p].inputs ~/ 2);
        final ScoresLayout layout = ScoresLayout(size, scene);
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final List<Rect> drawn = ScoresScene.followedMark(Canvas(recorder), scene, layout, 0);
        recorder.endRecording().dispose();
        final double under = layout.attention.table.row(scene.focus.inputs - 1).bottom;
        expect(drawn.length, greaterThanOrEqualTo(2), reason: 'peptide $p, $size');
        for (final Rect rect in drawn) {
          expect(rect.top, greaterThan(under), reason: 'peptide $p, $size');
          expect(rect.bottom, lessThanOrEqualTo(size.height), reason: 'peptide $p, $size');
          expect(rect.right, lessThanOrEqualTo(layout.chartLeft - ScoresScene.followedClear), reason: 'peptide $p, $size');
        }
      }
    }
  });

  testWidgets("Embedding's position rows end on the context's last row, under the last place's, on the canvas", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final int context = trace.model.context;
    for (final Size size in const <Size>[Size(440, 697), Size(375, 476), Size(320, 300)]) {
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView scene = view(inks, kit, peptide: p);
        final EmbeddingLayout layout = EmbeddingLayout(size, scene);
        final int n = scene.focus.inputs;
        final (Rect?, Rect)? last = EmbeddingScene.lastRow(layout, n, context);
        final String why = 'peptide $p, $size';
        if (n >= context) {
          expect(last, isNull, reason: why);
          continue;
        }
        final (Rect? skip, Rect row) = last!;
        // A gap for the rows left out only where any are.
        expect(skip == null, n == context - 1, reason: why);
        expect(row.top, greaterThanOrEqualTo(layout.row(n - 1).bottom), reason: why);
        expect(row.height, closeTo(layout.pitch, 1e-9), reason: why);
        // In the room the foot left: never past it, so nothing else moves.
        expect(row.bottom, lessThanOrEqualTo(layout.footTop + layout.footTile.height + 0.01), reason: why);
        expect(row.bottom, lessThanOrEqualTo(size.height), reason: why);
      }
    }
  });

  testWidgets('a stage shows no Step menu exactly where every step draws, says and explains the same', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    Future<List<int>> pixels(LmView scene, TrainingFrame frame) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder)..drawRect(Offset.zero & size, Paint()..color = inks.ground);
      LmScenePainter(view: scene, frame: () => frame).paint(canvas, size);
      final ui.Picture picture = recorder.endRecording();
      final List<int> bytes = (await tester.runAsync(() async {
        final ui.Image image = await picture.toImage(size.width.round(), size.height.round());
        final ByteData? data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      }))!;
      picture.dispose();
      return bytes;
    }

    for (final LmStage stage in LmStage.values) {
      final LmScene scene = sceneOf(stage);
      // What one checkpoint shows of the stage: frames through it, every
      // caption, and its page.
      Future<List<Object>> shown(int c) async {
        final LmView at = view(inks, kit, checkpoint: c);
        return <Object>[
          for (final double local in <double>[0, 0.3, 0.6, 1]) await pixels(at, timeline.frameIn(stage, local)),
          <String>[for (int i = 0; i <= 48; i++) scene.caption(at, timeline.frameIn(stage, i / 48))],
          scene.info(at).title,
          words(scene.info(at)),
          <String>[for (final LmInfoSection section in scene.info(at).sections) section.title],
        ];
      }

      final List<Object> first = await shown(0);
      bool differs = false;
      for (int c = 1; c < trace.checkpoints.length && !differs; c++) {
        final List<Object> other = await shown(c);
        for (int k = 0; k < first.length; k++) {
          final Object a = first[k];
          final Object b = other[k];
          if (a is List && b is List ? !listEquals(a, b) : a != b) {
            differs = true;
          }
        }
      }
      expect(differs, scene.stepped, reason: stage.label);
    }
  });

  testWidgets("Scores, Attention and Feed-forward name the block's parts and sums as block 1's", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView scene = view(inks, kit);
    final int width = trace.model.width;
    final int n = scene.focus.inputs;
    expect(ScoresScene.weightsName(scene, 'query'), 'block 1 · query weights · $width × $width');
    expect(ScoresScene.weightsName(scene, 'output'), 'block 1 · output weights · $width × $width');
    expect(AttentionScene.headTag(0, 'query and keys'), 'block 1 · head 1 · query and keys');
    expect(AttentionScene.headTag(1, 'values'), 'block 1 · head 2 · values');
    expect(AttentionScene.sumTag(scene), "x0 + block 1's attention · $n × $width");
  });

  test("x0's tag steps aside while a head's tag is up, in Scores and in Attention", () {
    final int heads = trace.model.heads;
    final double scoresEnd = LmStage.scores.beats.toDouble();
    for (double beat = 0; beat <= scoresEnd; beat += 0.01) {
      expect(ScoresScene.x0TagShown(beat) * ScoresScene.headTagShown(beat), 0, reason: 'Scores at $beat');
    }
    // Scores ends on head 1's tag alone, as Attention opens.
    expect(ScoresScene.x0TagShown(scoresEnd), 0);
    expect(ScoresScene.headTagShown(scoresEnd), 1);
    expect(AttentionScene.x0TagShown(0, heads), 0);
    expect(AttentionScene.headTagShown(0, 0, heads), 1);
    for (double beat = 0; beat <= LmStage.attention.beats; beat += 0.01) {
      for (int h = 0; h < heads; h++) {
        expect(
          AttentionScene.x0TagShown(beat, heads) * AttentionScene.headTagShown(beat, h, heads),
          0,
          reason: 'Attention at $beat, head ${h + 1}',
        );
      }
    }
    // Back once the heads have read, until the map takes the row.
    expect(AttentionScene.x0TagShown(10, heads), 1);
    expect(AttentionScene.x0TagShown(LmStage.attention.beats.toDouble(), heads), 0);
  });

  testWidgets('Scores draws no strings until the row flows into the query', (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    final LmView scene = view(inks, kit);
    final ScoresLayout layout = ScoresLayout(size, scene);
    // The band between the evened row's column and the query's.
    final Rect band = Rect.fromLTRB(
      layout.inputX + layout.column / 2 + 2,
      layout.columnAt(layout.inputX, 0).top,
      layout.outputX[0] - layout.column / 2 - 2,
      layout.columnAt(layout.inputX, 0).bottom,
    );
    Future<int> inked(double beat) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder)..drawRect(Offset.zero & size, Paint()..color = inks.ground);
      LmScenePainter(view: scene, frame: () => timeline.frameIn(LmStage.scores, beat / LmStage.scores.beats))
          .paint(canvas, size);
      final ui.Picture picture = recorder.endRecording();
      final Uint8List bytes = (await tester.runAsync(() async {
        final ui.Image image = await picture.toImage(size.width.round(), size.height.round());
        final ByteData? data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;
      picture.dispose();
      final int ground = inks.ground.toARGB32();
      int count = 0;
      for (int y = band.top.ceil(); y < band.bottom.floor(); y++) {
        for (int x = band.left.ceil(); x < band.right.floor(); x++) {
          final int i = (y * size.width.round() + x) * 4;
          if (bytes[i] != (ground >> 16) & 0xff || bytes[i + 1] != (ground >> 8) & 0xff || bytes[i + 2] != ground & 0xff) {
            count++;
          }
        }
      }
      return count;
    }

    // The query's slots stand empty: nothing between the two columns.
    expect(await inked(6.9), 0);
    // Number 1's strings running out of the row.
    expect(await inked(7.3), greaterThan(0));
  });

  testWidgets("Attention draws no output strings until the heads' answers flow into the output weights", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    final LmView scene = view(inks, kit);
    // On Scores' bench: the answers stand where the evened row stood, the
    // output where the query stood; the band between them, under the
    // columns' names, as Scores' test takes it.
    final ScoresLayout bench = ScoresLayout(size, scene);
    final Rect band = Rect.fromLTRB(
      bench.inputX + bench.column / 2 + 2,
      bench.columnAt(bench.inputX, 0).top,
      bench.outputX[0] - bench.column / 2 - 2,
      bench.columnAt(bench.inputX, 0).bottom,
    );
    Future<int> inked(double beat) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder)..drawRect(Offset.zero & size, Paint()..color = inks.ground);
      LmScenePainter(view: scene, frame: () => timeline.frameIn(LmStage.attention, beat / LmStage.attention.beats))
          .paint(canvas, size);
      final ui.Picture picture = recorder.endRecording();
      final Uint8List bytes = (await tester.runAsync(() async {
        final ui.Image image = await picture.toImage(size.width.round(), size.height.round());
        final ByteData? data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;
      picture.dispose();
      final int ground = inks.ground.toARGB32();
      int count = 0;
      for (int y = band.top.ceil(); y < band.bottom.floor(); y++) {
        for (int x = band.left.ceil(); x < band.right.floor(); x++) {
          final int i = (y * size.width.round() + x) * 4;
          if (bytes[i] != (ground >> 16) & 0xff || bytes[i + 1] != (ground >> 8) & 0xff || bytes[i + 2] != ground & 0xff) {
            count++;
          }
        }
      }
      return count;
    }

    final double flows = AttentionScene.outputFanAt(0, trace.model.width).$1;
    // The output's slots stand empty: nothing between the two columns.
    expect(await inked(flows - 0.05), 0);
    // Number 1's strings running out of the heads' answers.
    expect(await inked(flows + 0.3), greaterThan(0));
  });

  testWidgets(
    "number 1 of head 1's answer is each place's value times its share, each value its row through the value weights",
    (WidgetTester tester) async {
      final (LmInks inks, LmKit kit) = await _drawing(tester);
      addTearDown(kit.dispose);
      final int width = trace.model.width;
      for (int c = 0; c < trace.checkpoints.length; c++) {
        for (int p = 0; p < trace.peptides.length; p++) {
          final int inputs = trace.peptides[p].inputs;
          for (final int position in <int>{0, inputs ~/ 2, inputs - 1}) {
            final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: position);
            final TraceCheckpoint at = scene.checkpoint;
            final String where = 'step ${scene.step}, peptide $p, place $position';
            // Every place's value, number 1: its evened row through the same
            // 16 weights, and their bias.
            final List<double> values = WorkedAnswer.values(scene);
            expect(values, hasLength(position + 1));
            for (int j = 0; j <= position; j++) {
              double made = trace.projectionBias(at, 0, 2, 0);
              for (int d = 0; d < width; d++) {
                made += trace.projection(at, 0, 2, 0, d) * trace.attnInput(at, 0, p, j, d);
              }
              expect(values[j], closeTo(made, 1e-4), reason: '$where, value of $j');
            }
            // What each brings, summed: number 1 of the answer the column holds.
            final double summed = WorkedAnswer.brought(scene).fold<double>(0, (double a, double b) => a + b);
            expect(summed, closeTo(WorkedAnswer.answer(scene), 1e-4), reason: where);
            expect(WorkedAnswer.answer(scene), AttentionScene.joinedAnswers(scene).first);
          }
        }
      }
    },
  );

  testWidgets('the worked answer fills each value only as its strings land, in order, and number 1 after them', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (int p = 0; p < trace.peptides.length; p++) {
      for (final int position in <int>{0, 1, trace.peptides[p].inputs - 1}) {
        final LmView scene = view(inks, kit, peptide: p, position: position);
        // When place j's cell is whole.
        double whole(int j) {
          for (double local = 0; local <= WorkedAnswer.beats; local += 0.01) {
            if (WorkedAnswer.made(scene, j, local) >= 1) {
              return local;
            }
          }
          return double.infinity;
        }

        // The place in focus's first, as Scores made it; then <bos>'s, through
        // the same weights; then every other place's, top to bottom.
        double last = whole(position);
        expect(WorkedAnswer.made(scene, position, 0.5), 0);
        if (position > 0) {
          expect(WorkedAnswer.second(scene), 0);
          expect(whole(0), greaterThan(last));
          last = whole(0);
          for (int j = 1; j < position; j++) {
            expect(whole(j), greaterThan(last), reason: 'peptide $p, place $j after the one before');
            last = whole(j);
          }
        } else {
          expect(WorkedAnswer.second(scene), isNull);
        }
        // Number 1 of the answer is made again only once every value is in.
        double remade = double.infinity;
        for (double local = 0; local <= WorkedAnswer.beats; local += 0.01) {
          if (WorkedAnswer.answerMade(local) > 0) {
            remade = local;
            break;
          }
        }
        expect(remade, greaterThan(last));
        expect(WorkedAnswer.answerMade(WorkedAnswer.beats), 1);
      }
    }
  });

  testWidgets('the worked answer hands the output weights the column it ends on, pixel for pixel', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    Future<List<int>> pixels(LmView scene, double beat) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder)..drawRect(Offset.zero & size, Paint()..color = inks.ground);
      LmScenePainter(view: scene, frame: () => timeline.frameIn(LmStage.attention, beat / LmStage.attention.beats))
          .paint(canvas, size);
      final ui.Picture picture = recorder.endRecording();
      final List<int> bytes = (await tester.runAsync(() async {
        final ui.Image image = await picture.toImage(size.width.round(), size.height.round());
        final ByteData? data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      }))!;
      picture.dispose();
      return bytes;
    }

    final (double from, double to) = AttentionScene.worked;
    expect(to - from, closeTo(WorkedAnswer.beats, 1e-9));
    for (int p = 0; p < trace.peptides.length; p++) {
      final LmView scene = view(inks, kit, peptide: p, checkpoint: trace.checkpoints.length - 1);
      final List<int> takes = await pixels(scene, to);
      expect(takes.any((int b) => b != takes.first), isTrue);
      // Its last frame, drawn by the worked answer, a hair before the note
      // over it turns over, is the frame the output weights open on.
      expect(await pixels(scene, to - 1e-4), takes, reason: 'peptide $p');
      // In between, the table: not that frame.
      expect(await pixels(scene, from + 4.8), isNot(takes), reason: 'peptide $p');
    }
  });

  test("no number of the heads' answers is written before number 1 is made, and all of them after", () {
    final int width = trace.model.width;
    for (double local = 0; local <= WorkedAnswer.beats; local += 0.01) {
      if (WorkedAnswer.answerMade(local) > 0) {
        break;
      }
      for (int d = 0; d < width; d++) {
        expect(WorkedAnswer.answerWritten(d, local), 0, reason: 'number ${d + 1} at $local');
      }
    }
    for (int d = 0; d < width; d++) {
      expect(WorkedAnswer.answerWritten(d, WorkedAnswer.beats), 1, reason: 'number ${d + 1}');
    }
  });

  test('the worked answer writes its terms signed, but not one that rounds to nothing', () {
    expect(WorkedAnswer.term(0.0074, 3), '+0.007');
    expect(WorkedAnswer.term(-1.2213, 2), '−1.22');
    expect(WorkedAnswer.term(-0.0003, 3), '0.000');
    expect(WorkedAnswer.term(0.0004, 2), '0.00');
    expect(WorkedAnswer.tenth(0.0676), '6.8%');
    expect(WorkedAnswer.tenth(0.2341), '23.4%');
  });

  test('the output weights take the heads\' answers only once number 1 is worked out', () {
    final (double from, double to) = AttentionScene.worked;
    expect(from, greaterThanOrEqualTo(AttentionScene.times(trace.model.heads - 1, trace.model.heads).end));
    expect(AttentionScene.outputFanAt(0, trace.model.width).$1, greaterThan(to));
  });

  test('Attention makes each number it adds only as its strings land, number 1 alone, after the heads', () {
    for (final int width in <int>[trace.model.width, 16]) {
      final double heads = AttentionScene.times(trace.model.heads - 1, trace.model.heads).end;
      double previous = 0;
      for (int out = 0; out < width; out++) {
        final (double from, double to) = AttentionScene.outputFanAt(out, width);
        expect(from, greaterThan(heads), reason: 'number $out of $width, after the heads');
        expect(from, greaterThanOrEqualTo(previous), reason: 'number $out of $width, in order');
        expect(to, greaterThan(from));
        // The number fills only as its strings land.
        expect(AttentionScene.outputMadeAt(out, width, to - 0.11), 0);
        expect(AttentionScene.outputMadeAt(out, width, to + 0.11), 1);
        expect(to, lessThan(LmStage.attention.beats.toDouble()));
        previous = from;
      }
      // Number 1 is made on its own: no other number's strings leave before
      // it lands.
      final double alone = AttentionScene.outputFanAt(0, width).$2;
      for (int out = 1; out < width; out++) {
        expect(AttentionScene.outputFanAt(out, width).$1, greaterThanOrEqualTo(alone));
      }
    }
  });

  testWidgets('what Attention writes as it adds is the output weights times the heads\' answers, and the stream\'s gain', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final int width = trace.model.width;
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView scene = view(inks, kit, checkpoint: c);
      final List<double> answers = AttentionScene.joinedAnswers(scene);
      expect(answers.length, width);
      final List<double> gain = StreamTable(const Size(393, 540), scene).gained(0, 1, scene.position);
      for (int out = 0; out < width; out++) {
        // The strings into number [out] carry its weights times the answers;
        // their sum, with its bias, is what the stream gained.
        double sum = trace.outBias(scene.checkpoint, 0, out);
        for (int d = 0; d < width; d++) {
          sum += trace.outWeight(scene.checkpoint, 0, out, d) * answers[d];
        }
        expect(sum, closeTo(gain[out], 1e-4), reason: 'step ${scene.step}, number ${out + 1}');
        expect(fixed(sum, 2), fixed(gain[out], 2), reason: 'step ${scene.step}, number ${out + 1}');
      }
    }
  });

  testWidgets("Attention lays head 1's map on the table's rows, from the token column to the canvas's side", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView scene = view(inks, kit);
    final int n = trace.peptides.first.inputs;
    for (final Size size in <Size>[const Size(440, 697), const Size(402, 619), const Size(375, 476)]) {
      final AttentionLayout layout = AttentionLayout(size, scene);
      final StreamTable table = layout.table;
      for (int i = 0; i < n; i++) {
        // Each row of the map is its place's row of the table, the tile at
        // its left naming it.
        for (final int j in <int>[0, n - 1]) {
          expect(layout.mapCell(i, j).top, table.row(i).top, reason: '$size row $i');
          expect(layout.mapCell(i, j).bottom, table.row(i).bottom, reason: '$size row $i');
        }
        // From where the narrowed rows started, right of their tiles, to the
        // canvas's side.
        expect(layout.mapCell(i, 0).left, closeTo(layout.mapLeft, 1e-9));
        expect(layout.mapCell(i, n - 1).right, closeTo(table.layout.right, 1e-9));
      }
      expect(layout.mapLeft, layout.stream(0, 1).left);
      expect(layout.mapLeft, greaterThan(table.layout.label(0).right + layout.slide(1)));
      // The places read: a tile under each column, under the last row, on the
      // canvas.
      for (int j = 0; j < n; j++) {
        final Rect tile = layout.mapTile(j);
        expect(tile.center.dx, closeTo(layout.mapCell(n - 1, j).center.dx, 1e-9));
        expect(tile.width, lessThan(layout.mapColumn));
        expect(tile.top, greaterThan(table.row(n - 1).bottom));
        expect(tile.bottom, lessThanOrEqualTo(size.height));
      }
      // The heads' answers, on the row in focus, end at the canvas's side and
      // are never shorter than a unit a number, the keys' own; where they are
      // longer, the arcs keep their least room.
      final double unit = (layout.kvRight - layout.kvLeft) / trace.headSize;
      expect(layout.slotCell, greaterThanOrEqualTo(unit - 1e-9), reason: '$size');
      expect(layout.answers.right, closeTo(table.layout.right - 2, 1e-9));
      expect(layout.answers.top, greaterThanOrEqualTo(table.row(scene.position).top));
      expect(layout.answers.bottom, lessThanOrEqualTo(table.row(scene.position).bottom));
      if (layout.slotCell > unit + 1e-9) {
        expect(layout.answers.left - layout.kvRight, greaterThanOrEqualTo(AttentionLayout.leastArcs - 1e-9), reason: '$size');
      }
      // The answers' box grows into the map: from the answers to the map's
      // rows and tiles, never over the rows as they go into their tiles.
      expect(layout.growing(0), layout.answers);
      expect(layout.growing(1), layout.mapBox);
      for (final double g in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(layout.growing(g).left, greaterThanOrEqualTo(layout.stream(0, 1, g).right - 1e-9), reason: '$size $g');
      }
      expect(layout.stream(0, 1, 1).width, 0);
      expect(layout.mapBox.bottom, greaterThan(layout.mapTile(0).bottom));
    }
    // The answers are longer than a unit a number where the canvas has room.
    final AttentionLayout wide = AttentionLayout(const Size(440, 697), scene);
    expect(wide.slotCell, greaterThan((wide.kvRight - wide.kvLeft) / trace.headSize));
    // Every row adds to one; the place in focus's row is the shares Scores
    // drew, number for number.
    final List<List<double>> rows = AttentionScene.allShares(scene, AttentionScene.mapHead);
    expect(rows.length, n);
    for (int i = 0; i < n; i++) {
      expect(rows[i].length, i + 1);
      expect(rows[i].reduce((double a, double b) => a + b), closeTo(1, 1e-9));
    }
    expect(rows[scene.position], AttentionScene.shares(scene, AttentionScene.mapHead));
    // The row in focus fills first, a cell at a time from <bos>; then every
    // other row, top to bottom; all of it before the table widens again.
    final int focus = scene.position;
    double first(bool Function(double beat) reached) {
      for (double beat = 0; beat <= LmStage.attention.beats; beat += 0.01) {
        if (reached(beat)) {
          return beat;
        }
      }
      return double.infinity;
    }

    double starts(int i, int j) => first((double b) => AttentionScene.mapFilled(i, j, focus, n, b) > 0);
    double ends(int i, int j) => first((double b) => AttentionScene.mapFilled(i, j, focus, n, b) >= 1);
    for (int j = 1; j <= focus; j++) {
      expect(starts(focus, j), greaterThan(starts(focus, j - 1)), reason: 'cell $j of the row in focus');
    }
    final double focusDone = ends(focus, focus);
    final List<int> others = <int>[for (int i = 0; i < n; i++) if (i != focus) i];
    for (int k = 0; k < others.length; k++) {
      final int i = others[k];
      expect(starts(i, 0), greaterThanOrEqualTo(focusDone), reason: 'row $i after the row in focus');
      if (k > 0) {
        expect(starts(i, 0), greaterThan(starts(others[k - 1], 0)), reason: 'row $i after the row above it');
      }
      expect(ends(i, i), lessThan(LmStage.attention.beats.toDouble()));
    }
    // Then head 2's map on the same rows, filled the same way: its row in
    // focus first, then every other row, top to bottom; each cell only once
    // every cell of head 1's has emptied to its slot; all of it while its
    // name is up, before the table widens; and the two maps' names never up
    // together.
    final int heads = trace.model.heads;
    expect(heads, 2);
    double filledIn(int h, int i, int j, double b) => AttentionScene.mapFilled(i, j, focus, n, b, head: h, heads: heads);
    double startsIn(int h, int i, int j) => first((double b) => filledIn(h, i, j, b) > 0);
    double endsIn(int h, int i, int j) => first((double b) => filledIn(h, i, j, b) >= 1);
    // Head 1's own fill is the same whether or not a head follows it.
    for (int i = 0; i < n; i++) {
      for (int j = 0; j <= i; j++) {
        expect(startsIn(0, i, j), starts(i, j), reason: 'head 1, cell $i, $j');
        expect(endsIn(0, i, j), ends(i, j), reason: 'head 1, cell $i, $j');
      }
    }
    double head1Gone = 0;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j <= i; j++) {
        final double full = endsIn(0, i, j);
        head1Gone = math.max(head1Gone, first((double b) => b > full && filledIn(0, i, j, b) <= 0));
      }
    }
    expect(head1Gone, lessThan(LmStage.attention.beats.toDouble()));
    for (int j = 1; j <= focus; j++) {
      expect(startsIn(1, focus, j), greaterThan(startsIn(1, focus, j - 1)), reason: 'head 2, cell $j of the row in focus');
    }
    final double head2FocusDone = endsIn(1, focus, focus);
    final double named = first((double b) => AttentionScene.mapTagShown(1, heads, b) >= 1);
    final double unnamed = first((double b) => b > named && AttentionScene.mapTagShown(1, heads, b) < 1);
    for (int k = 0; k < others.length; k++) {
      final int i = others[k];
      expect(startsIn(1, i, 0), greaterThanOrEqualTo(head2FocusDone), reason: 'head 2, row $i after the row in focus');
      if (k > 0) {
        expect(startsIn(1, i, 0), greaterThan(startsIn(1, others[k - 1], 0)), reason: 'head 2, row $i after the one above');
      }
      expect(endsIn(1, i, i), lessThan(unnamed), reason: 'head 2, row $i full while its name is up');
    }
    for (int i = 0; i < n; i++) {
      expect(startsIn(1, i, 0), greaterThanOrEqualTo(head1Gone), reason: "head 2, row $i after head 1's cells have emptied");
    }
    for (double b = 0; b <= LmStage.attention.beats; b += 0.01) {
      expect(AttentionScene.mapTagShown(0, heads, b) * AttentionScene.mapTagShown(1, heads, b), 0, reason: 'names at $b');
      if ((b - head1Gone).abs() > 0.02) {
        expect(AttentionScene.mapHeadAt(b, heads), b < head1Gone ? 0 : 1, reason: 'the map drawn at $b');
      }
    }
  });

  testWidgets("a block's shares are softmax of its own kept scores, block 2's as block 1's", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView scene = view(inks, kit, checkpoint: c);
      final TraceCheckpoint at = scene.checkpoint;
      for (int layer = 0; layer < trace.model.layers; layer++) {
        final List<List<double>> rows = AttentionScene.allShares(scene, AttentionScene.mapHead, layer: layer);
        for (int i = 0; i < scene.focus.inputs; i++) {
          expect(rows[i].reduce((double a, double b) => a + b), closeTo(1, 1e-9));
          for (int j = 0; j <= i; j++) {
            // Softmax of the block's kept scores is its kept map, to the
            // map's own step.
            expect(rows[i][j], closeTo(trace.attention(at, layer, AttentionScene.mapHead, 0, i, j), at.attentionScale / 2 + 1e-6));
          }
        }
        expect(rows[scene.position], AttentionScene.shares(scene, AttentionScene.mapHead, layer: layer));
      }
    }
  });

  testWidgets("Forward's ladder: a row a point of the stream, on the canvas, each landing in turn", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final int layers = trace.model.layers;
    for (int c = 0; c < trace.checkpoints.length; c++) {
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: trace.peptides[p].inputs - 1);
        for (final Size size in const <Size>[Size(375, 476), Size(393, 540), Size(440, 697)]) {
          final TowerLayout layout = TowerLayout(size, scene);
          // A slot a point: x0, each part's output, the final norm's.
          expect(layout.points, 2 * layers + 2);
          for (int k = 1; k < layout.points; k++) {
            expect(layout.slot(k).top, greaterThan(layout.slot(k - 1).bottom), reason: 'slot $k');
            // Each strip and name lies in the gap before its slot.
            expect(layout.labelAt(k).dy, greaterThanOrEqualTo(layout.slot(k - 1).bottom));
            expect(layout.strip(k).bottom, lessThanOrEqualTo(layout.slot(k).top));
          }
          expect(layout.labelAt(0).dy + layout.label, lessThanOrEqualTo(layout.slot(0).top));
          // The ladder keeps to the canvas, under its name, and its rows'
          // numbers are written.
          expect(layout.slot(layout.points - 1).bottom, lessThanOrEqualTo(size.height));
          expect(layout.tagAt(const Size(100, 20)).dy, greaterThanOrEqualTo(layout.table.layout.tagTop));
          expect(layout.numberStyle, isNotNull, reason: '$size p$p');
        }
      }
    }
    // Each copy lands after the one before, the final norm's last.
    for (int k = 2; k < 2 * layers + 2; k++) {
      double lands(int slot) {
        for (double beat = 0; beat <= LmStage.forward.beats; beat += 0.01) {
          if (ForwardScene.dropped(slot, layers, beat) >= 1) {
            return beat;
          }
        }
        return double.infinity;
      }

      expect(lands(k), greaterThan(lands(k - 1)), reason: 'slot $k');
      expect(lands(k), lessThan(LmStage.forward.beats - 1));
    }
  });

  testWidgets("Predict's shares are softmax of the run's whole logits, the top logit worked out first", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final int last = trace.points.length - 1;
    for (int c = 0; c < trace.checkpoints.length; c++) {
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: i);
          final TraceCheckpoint at = trace.checkpoints[c];
          final List<double> logits = PredictScene.logits(scene, i);
          final List<double> shares = PredictScene.shares(scene, i);
          // Each logit is what its strings carry, summed, plus its bias.
          for (int r = 0; r < trace.vocab.length; r++) {
            double made = trace.outputBias(at, r);
            for (int d = 0; d < trace.model.width; d++) {
              made += trace.stream(at, last, p, i, d) * trace.outputWeight(at, r, d);
            }
            expect(logits[r], closeTo(made, 1e-5));
          }
          // The shares add to one over what can come next, nothing to the
          // two that never do, and are the model's own probabilities.
          expect(shares.reduce((double a, double b) => a + b), closeTo(1, 1e-9));
          for (int r = 0; r < trace.vocab.length; r++) {
            final int column = trace.allowedIndex(r);
            if (column < 0) {
              expect(shares[r], 0);
            } else {
              expect(shares[r], closeTo(trace.probability(at, p, i, column), 0.5 / 255 + 1e-6));
            }
          }
          // The top logit is worked out first, alone, then the rest in id
          // order; the map's row is the shares in id order.
          final int best = PredictScene.top(scene, i);
          for (final int id in trace.allowed) {
            expect(logits[id], lessThanOrEqualTo(logits[best]));
          }
          final List<int> order = PredictScene.flowOrder(scene);
          expect(order.first, best);
          expect(order.toSet(), <int>{for (int r = 0; r < trace.vocab.length; r++) r});
          expect(PredictScene.allShares(scene)[i], <double>[for (final int id in trace.allowed) shares[id]]);
        }
      }
    }
  });

  testWidgets("Predict's bench and map keep to the canvas, the strings room to run, the bars room to grow", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: trace.peptides[p].inputs - 1);
        for (final Size size in const <Size>[Size(375, 476), Size(393, 540), Size(440, 697)]) {
          final PredictLayout layout = PredictLayout(size, scene);
          final String where = '$size c$c p$p';
          // The bench under the note and the tag's place, its plate on the
          // canvas under the columns.
          expect(layout.benchTop, greaterThanOrEqualTo(layout.table.layout.tableTop), reason: where);
          final Rect plate = layout.plateAt(tagSize(scene, PredictScene.plateText(scene)));
          expect(plate.top, greaterThanOrEqualTo(layout.benchBottom), reason: where);
          expect(plate.bottom + 14, lessThanOrEqualTo(size.height), reason: where);
          // The strings run at least as far as Scores' do; the tokens' tiles
          // end at the canvas's side; the bars have room to grow.
          expect(layout.logitX - layout.inputX - layout.column, greaterThanOrEqualTo(ScoresLayout.leastReach), reason: where);
          expect(layout.chip(0, 0).right, closeTo(layout.right, 1e-9), reason: where);
          expect(layout.barRoom, greaterThanOrEqualTo(100), reason: where);
          // Slid left, the logits keep their name on the canvas.
          final double named = kit.layout(PredictScene.logitsTitle, inked(kit.sans, 9, inks.quiet)).width;
          expect(layout.logitX + layout.slideBy - named / 2, greaterThanOrEqualTo(0), reason: where);
          // The shares' standing column is their tiles, one on top of the
          // other, so lying down it lands on the map's row cell for cell.
          final Rect column = layout.shareColumn;
          expect(column.top, layout.shareTile(layout.firstAllowed).top);
          expect(column.bottom, closeTo(layout.shareTile(layout.lastAllowed).bottom, 1e-9));
          expect(layout.lastAllowed - layout.firstAllowed + 1, trace.allowed.length);
          for (int i = 0; i < scene.focus.inputs; i++) {
            final Rect row = layout.mapRow(i);
            final double w = row.width / trace.allowed.length;
            for (int k = 0; k < trace.allowed.length; k++) {
              final Rect cell = layout.mapCell(i, k);
              expect(cell.left, closeTo(row.left + k * w, 1e-9));
              expect(cell.width, closeTo(w, 1e-9));
              expect(cell.top, row.top);
            }
          }
          // The map's tiles under its last row, on the canvas.
          expect(layout.mapTile(0).bottom, lessThanOrEqualTo(size.height), reason: where);
          // The answer key at the map's right: each row's next token on a
          // tile as large as the row's own and centred on the row, clear of
          // the map; the widest share given, 100%, between the tile and the
          // canvas's side, clear of the place in focus's outline.
          for (int i = 0; i < scene.focus.inputs; i++) {
            final Rect tile = layout.answerTile(i);
            expect(tile.left, greaterThanOrEqualTo(layout.mapRow(i).right + 4), reason: '$where row $i');
            expect(tile.center.dy, closeTo(layout.table.row(i).center.dy, 1e-9), reason: '$where row $i');
            expect(tile.width, closeTo(layout.table.layout.chipSide, 1e-9), reason: '$where row $i');
          }
          final TextStyle? given = layout.givenStyle;
          if (given != null) {
            expect(
              layout.answerTile(0).right + 3 + kit.layout('100%', given).width,
              lessThanOrEqualTo(layout.givenRight + 1e-9),
              reason: where,
            );
            // The two names over the key keep apart, whatever the font.
            final TextStyle named = PredictScene.titleStyle(scene);
            expect(
              layout.answerTile(0).center.dx + kit.layout(PredictScene.answerTitle, named).width / 2 + 4,
              lessThanOrEqualTo(layout.givenRight - kit.layout(PredictScene.givenTitle, named).width + 1e-9),
              reason: where,
            );
          }
          expect(layout.givenRight, lessThan(layout.right), reason: where);
        }
      }
    }
  });

  testWidgets("Predict's map draws a share as that share of its slot, a place's squares making one slot", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (final int c in <int>[0, trace.checkpoints.length - 1]) {
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: 0);
        final List<List<double>> rows = PredictScene.allShares(scene);
        for (final Size size in const <Size>[Size(375, 476), Size(440, 697)]) {
          final PredictLayout layout = PredictLayout(size, scene);
          for (int i = 0; i < scene.focus.inputs; i++) {
            final String where = '$size c$c p$p row $i';
            double area = 0;
            double slotArea = 0;
            for (int k = 0; k < trace.allowed.length; k++) {
              // The slot: a square inside its cell, at its centre.
              final Rect cell = layout.mapCell(i, k);
              final RRect slot = PredictScene.slotOf(cell);
              expect(slot.width, closeTo(slot.height, 1e-9), reason: where);
              expect(cell.contains(slot.outerRect.topLeft) && cell.contains(slot.outerRect.bottomRight), isTrue, reason: where);
              expect((slot.center - cell.center).distance, lessThan(1e-9), reason: where);
              // The share: the slot scaled about its centre, its area, and
              // so its corners' too, that share of the slot's.
              final double share = rows[i][k];
              final RRect fill = PredictScene.fillOf(slot, share);
              expect((fill.center - slot.center).distance, lessThan(1e-9), reason: where);
              expect(fill.width * fill.height, closeTo(share * slot.width * slot.height, 1e-9), reason: where);
              expect(fill.tlRadiusX, closeTo(slot.tlRadiusX * math.sqrt(share), 1e-9), reason: where);
              area += fill.width * fill.height;
              slotArea = slot.width * slot.height;
            }
            // A place's shares add to one, so its squares make one slot.
            expect(area, closeTo(slotArea, 1e-6), reason: where);
          }
        }
      }
    }
  });

  testWidgets("Loss scores each target by −ln of Predict's own p(y), and their mean is the step's loss", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView scene = view(inks, kit, checkpoint: c);
      final List<List<double>> costs = LossScene.surprises(scene);
      expect(costs.length, trace.peptides.length);
      double sum = 0;
      int count = 0;
      for (int p = 0; p < trace.peptides.length; p++) {
        expect(costs[p].length, trace.peptides[p].inputs);
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          final String where = 'step ${scene.step} p$p i$i';
          // Predict's own share of what came next...
          expect(LossScene.given(scene, p, i), PredictScene.shares(view(inks, kit, checkpoint: c, peptide: p), i)[trace.targetAt(p, i)]);
          expect(math.exp(-costs[p][i]), closeTo(LossScene.given(scene, p, i), 1e-12), reason: where);
          // ...whose −ln is the loss the run kept for that target, and never
          // over the scale the bars and the chart are drawn on.
          expect(costs[p][i], closeTo(trace.targetLoss(scene.step, p, i), 5e-4), reason: where);
          expect(costs[p][i], lessThanOrEqualTo(LossScene.ceiling(scene)), reason: where);
          sum += costs[p][i];
          count++;
        }
      }
      expect(count, trace.targetCount);
      expect(sum / count, closeTo(trace.loss(scene.step), 1e-4), reason: 'step ${scene.step}');
      expect(LossScene.bosShare(scene), inInclusiveRange(0, 1));
    }
    // One scale for every step: a whole number of nats, never under an even
    // guess's cost.
    final double ceiling = LossScene.ceiling(view(inks, kit));
    expect(ceiling, ceiling.roundToDouble());
    expect(ceiling, greaterThanOrEqualTo(trace.uniform));
  });

  testWidgets("Loss's chart keeps to its bench, its line alone and its batch to the canvas, the key swinging onto the one and shrinking into the other", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: trace.peptides[p].inputs - 1);
        for (final Size size in const <Size>[Size(375, 476), Size(393, 540), Size(440, 697)]) {
          final LossLayout layout = LossLayout(size, scene);
          final StreamTable table = layout.table;
          final int n = scene.focus.inputs;
          final String where = '$size c$c p$p';
          // The chart on the bench: right of the rows' tiles, left of the
          // gathered column, over the places' rows, and large enough to read.
          final Rect plot = layout.chart.area;
          expect(plot.left, greaterThan(layout.predict.mapLeft), reason: where);
          expect(plot.right, lessThan(layout.keySlot(0).left), reason: where);
          expect(plot.top, greaterThanOrEqualTo(table.row(0).top), reason: where);
          expect(plot.bottom, lessThanOrEqualTo(table.row(n - 1).bottom), reason: where);
          expect(plot.width, greaterThan(100), reason: where);
          expect(plot.height, greaterThan(60), reason: where);
          // Each row's lit slot starts where the map has it and gathers into
          // the map's last column, beside the key.
          for (int i = 0; i < n; i++) {
            expect(layout.answerCell(i, 0), layout.predict.mapCell(i, trace.allowedIndex(trace.targetAt(p, i))));
            expect(layout.answerCell(i, 1), layout.predict.mapCell(i, trace.allowed.length - 1));
          }
          // The batch under the tag's place, a line a peptide, apart, and its
          // legend on the canvas.
          expect(layout.lineTop(0), greaterThanOrEqualTo(table.layout.tableTop), reason: where);
          expect(layout.legendTop + layout.legendHeight, lessThanOrEqualTo(size.height), reason: where);
          expect(layout.card(p).right, lessThanOrEqualTo(size.width), reason: where);
          for (int q = 0; q + 1 < trace.peptides.length; q++) {
            expect(layout.card(q).bottom, lessThan(layout.lineTop(q + 1) - 3), reason: '$where line $q');
          }
          // The line alone: across the canvas, its tiles larger than the
          // batch's where it has fewer places, its bars' room taller, under
          // the tag's place and over the legend.
          expect(layout.soloLineTop, greaterThanOrEqualTo(table.layout.tableTop), reason: where);
          expect(layout.soloTile(0).left, greaterThan(layout.batchLeft), reason: where);
          expect(layout.soloTile(n - 1).right, lessThanOrEqualTo(size.width), reason: where);
          expect(layout.soloBase + layout.soloTileHeight, lessThanOrEqualTo(layout.legendTop), reason: where);
          expect(layout.soloStep, greaterThanOrEqualTo(layout.step - 1e-9), reason: where);
          expect(layout.soloBarRoom, greaterThanOrEqualTo(layout.barRoom), reason: where);
          // The key's tiles swing from where Predict left them onto the line
          // alone, which then shrinks into its place in the batch, its scale
          // and tiles' top with it.
          for (int i = 0; i < n; i++) {
            final Rect start = layout.swung(i, 0);
            final Rect end = layout.swung(i, 1);
            expect((start.center - layout.predict.answerTile(i).center).distance, lessThan(1e-6), reason: '$where tile $i');
            expect(start.width, closeTo(layout.predict.answerTile(i).width, 1e-9), reason: '$where tile $i');
            expect((end.center - layout.soloTile(i).center).distance, lessThan(1e-6), reason: '$where tile $i');
            expect(end.height, closeTo(layout.soloTile(i).height, 1e-9), reason: '$where tile $i');
            // Swinging, it never leaves the canvas.
            for (double s = 0; s <= 1; s += 0.05) {
              final Offset at = layout.swung(i, s).center;
              expect(at.dx, inInclusiveRange(0, size.width), reason: '$where tile $i at $s');
              expect(at.dy, inInclusiveRange(0, size.height), reason: '$where tile $i at $s');
            }
            expect(layout.focusTile(i, 0), layout.soloTile(i));
            expect(layout.focusTile(i, 1), layout.tile(p, i));
          }
          expect(layout.focusBase(1), closeTo(layout.base(p), 1e-9), reason: where);
          expect(layout.focusScale(1), closeTo(layout.batchScale, 1e-9), reason: where);
        }
      }
    }
  });

  testWidgets("Attention's arcs pass over the answers before their own and land on it from above", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    Offset along((Offset, Offset, Offset, Offset) c, double t) {
      final double u = 1 - t;
      return c.$1 * (u * u * u) + c.$2 * (3 * u * u * t) + c.$3 * (3 * u * t * t) + c.$4 * (t * t * t);
    }

    for (final int position in <int>[3, 7, trace.peptides.first.inputs - 1]) {
      final LmView scene = view(inks, kit, position: position);
      for (final Size size in <Size>[const Size(440, 697), const Size(402, 619), const Size(375, 476)]) {
        final AttentionLayout layout = AttentionLayout(size, scene);
        for (int h = 0; h < trace.model.heads; h++) {
          final Rect target = layout.slot(h);
          for (int j = 0; j <= position; j++) {
            final (Offset, Offset, Offset, Offset) curve = layout.arc(j, h);
            final String where = '$size, place $position, head ${h + 1}, row $j';
            // From the value's row, onto the middle of its answer's top,
            // coming straight down onto it.
            expect(curve.$1.dy, layout.table.row(j).center.dy, reason: where);
            expect(curve.$4, Offset(target.center.dx, target.top), reason: where);
            expect(curve.$3.dx, curve.$4.dx, reason: where);
            expect(curve.$3.dy, lessThan(curve.$4.dy), reason: where);
            // Over the answers before its own, and its own near side, it keeps
            // clear of their tops.
            for (int k = 1; k < 400; k++) {
              final Offset p = along(curve, k / 400);
              if (p.dx >= layout.slotsLeft && p.dx <= target.left + target.width * 0.3) {
                expect(p.dy, lessThanOrEqualTo(target.top - layout.clearance + 1), reason: where);
              }
            }
          }
        }
      }
    }
  });

  test('numbers are written as the page writes them', () {
    expect(nats(3.14482), '3.145');
    expect(percent(0.991), '99%');
    expect(percent(0.0423), '4.2%');
    // A share that rounds to ten is written whole, as ten.
    expect(percent(0.09996), '10%');
    // The map's cells: a percentage without its sign.
    expect(percentNumber(0.23), '23');
    expect(percentNumber(0.068), '6.8');
    expect(percentNumber(1), '100');
    expect(percentNumber(0.09996), '10');
    expect(scientific(1e-5), '1.0e−5');
    expect(scientific(0.00099996), '1.0e−3');
    expect(signed(-0.0123, 2), '−0.01');
    // A number written out: a true minus, no plus, no minus on a zero.
    expect(fixed(-1.234, 1), '−1.2');
    expect(fixed(2.06, 1), '2.1');
    expect(fixed(-0.04, 1), '0.0');
    expect(fixed(-0.004, 2), '0.00');
  });

  test('the lookup reads one place at a time, each a little quicker than the one before', () {
    for (final int n in <int>[12, 22, 40]) {
      double end = 0;
      double last = double.infinity;
      for (int i = 0; i < n; i++) {
        final (double from, double to) = EmbeddingScene.slot(i, n);
        expect(from, greaterThanOrEqualTo(end - 1e-9), reason: 'place $i of $n starts after the one before ends');
        if (i > 1) {
          expect(to - from, lessThan(last), reason: 'place $i of $n is quicker');
        }
        last = to - from;
        end = to;
      }
      expect(end, lessThanOrEqualTo(LmStage.embedding.beats.toDouble()));
    }
  });

  testWidgets('the embedding writes its numbers out where they fit, and draws colours alone where not', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView scene = view(inks, kit);
    final EmbeddingLayout phone = EmbeddingLayout(const Size(375, 450), scene);
    final TextStyle style = phone.numberStyle!;
    expect(style.fontSize, greaterThanOrEqualTo(EmbeddingLayout.leastNumber));
    // Every number, to two places, fits its cell.
    expect(EmbeddingLayout.digits, 2);
    expect(kit.layout(fixed(-8.88, EmbeddingLayout.digits), style).width, lessThan(phone.cell - 2 * EmbeddingLayout.gap));
    // The same rows, too narrow for a number: colours alone.
    expect(EmbeddingLayout(const Size(110, 450), scene).numberStyle, isNull);
    // The note sits over the tag, clear of it.
    expect(phone.tagTop, greaterThanOrEqualTo(phone.noteTop + EmbeddingScene.noteHeight(scene, phone.right - phone.noteLeft)));
    // The table spans the canvas, 4 points from either side.
    expect(phone.row(0).right, 375 - 4);
    expect(phone.left, 4);
  });

  test('Scores makes each query, key and value number only as its strings land, one part after another', () {
    for (final int width in <int>[trace.model.width, 16]) {
      double previous = 0;
      double landed = 0;
      for (int part = 0; part < 3; part++) {
        // A part's strings leave once the part before has made its last number.
        expect(ScoresScene.fanAt(part, 0, width).$1, greaterThan(landed), reason: 'part $part, width $width');
        for (int out = 0; out < width; out++) {
          final (double from, double to) = ScoresScene.fanAt(part, out, width);
          expect(from, greaterThanOrEqualTo(previous), reason: 'number $out of part $part, in order');
          expect(to, greaterThan(from));
          // The number fills only as its strings land.
          expect(ScoresScene.madeAt(part, out, width, to - 0.11), 0);
          expect(ScoresScene.madeAt(part, out, width, to + 0.11), 1);
          previous = from;
          landed = math.max(landed, to);
        }
      }
      // The query's first number is made on its own: no other number's
      // strings leave before it lands.
      final double alone = ScoresScene.fanAt(0, 0, width).$2;
      for (int part = 0; part < 3; part++) {
        for (int out = part == 0 ? 1 : 0; out < width; out++) {
          expect(ScoresScene.fanAt(part, out, width).$1, greaterThanOrEqualTo(alone));
        }
      }
      expect(landed, lessThan(LmStage.scores.beats.toDouble()));
    }
  });

  testWidgets('Scores stands the query nearer the evened row, room between the three, the plate under them', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (final Size size in <Size>[const Size(440, 697), const Size(375, 476)]) {
      final ScoresLayout layout = ScoresLayout(size, view(inks, kit));
      final double strings = layout.outputX[0] - layout.column / 2 - (layout.inputX + layout.column / 2);
      // The query no further from the row than it stood with the old 10
      // between columns, and nearer where there is room, its strings never
      // under the least they run unless the old ones already were.
      final double oldStep = layout.column + layout.numberWidth + 10;
      final double oldStrings = layout.outputX[2] - 2 * oldStep - layout.column / 2 - (layout.inputX + layout.column / 2);
      expect(strings, lessThanOrEqualTo(oldStrings + 1e-9), reason: '$size');
      expect(strings, greaterThanOrEqualTo(math.min(ScoresLayout.leastReach, oldStrings) - 1e-9), reason: '$size');
      for (int part = 0; part < 2; part++) {
        // From a column's numbers to the next column: never less than the old 10.
        final double between = layout.outputX[part + 1] - layout.column / 2 -
            (layout.outputX[part] + layout.column / 2 + layout.numberWidth);
        expect(between, greaterThanOrEqualTo(10 - 1e-9), reason: '$size');
        if (size.width >= 440) {
          expect(between, greaterThanOrEqualTo(14 - 1e-9), reason: '$size');
        }
      }
      // The value's numbers end at the bench's right.
      expect(layout.outputX[2] + layout.column / 2 + layout.numberWidth, closeTo(layout.right, 1e-6));
      // The plate stands under the columns, on the canvas, inside the bench.
      final Rect plate = layout.plateAt(const Size(120, 18));
      expect(plate.top, greaterThan(layout.columnAt(layout.inputX, 0).bottom));
      expect(plate.bottom + 14, lessThanOrEqualTo(size.height));
      expect(plate.left, greaterThanOrEqualTo(layout.benchLeft));
      expect(plate.right, lessThanOrEqualTo(layout.right));
    }
  });

  testWidgets("Backward's gradient is the run's: p − y back along the output layer, and the batch's mean its kept gradient", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final int last = trace.points.length - 1;
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final TraceCheckpoint at = trace.checkpoints[c];
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: i);
          final String where = 'step ${scene.step} p$p i$i';
          // p − y: each share less one at what came next, adding to nothing.
          final List<double> error = BackwardScene.errors(scene, i);
          final List<double> shares = PredictScene.shares(scene, i);
          expect(error[trace.targetAt(p, i)], closeTo(shares[trace.targetAt(p, i)] - 1, 1e-12), reason: where);
          expect(error.reduce((double a, double b) => a + b), closeTo(0, 1e-9), reason: where);
          // Back along the output layer's strings, the last row's gradient
          // is the run's own, times the targets the loss is the mean of.
          final List<double> row = BackwardScene.rowGradient(scene);
          final double norm = trace.pointGrad(at, last, p, i) * trace.targetCount;
          for (int d = 0; d < trace.model.width; d++) {
            expect(row[d], closeTo(trace.streamGrad(at, last, p, i, d) * trace.targetCount, 1e-4 * norm + 1e-7), reason: where);
          }
          // Every rung of the ladder is the run's, as long as its kept norm.
          final List<List<double>> rungs = BackwardScene.ladder(scene);
          for (int k = 0; k <= last; k++) {
            final double length = math.sqrt(rungs[k].fold<double>(0, (double sum, double v) => sum + v * v));
            final double kept = trace.pointGrad(at, k, p, i) * trace.targetCount;
            expect(length, closeTo(kept, 1e-5 * kept + 1e-9), reason: '$where point $k');
          }
        }
      }
      // Each place's p − y times its last row, averaged over every place, is
      // the output layer's gradient the run kept, clipped, to its int8 step:
      // what Update moves that layer by.
      final LmView scene = view(inks, kit, checkpoint: c);
      final List<List<double>> mean = <List<double>>[
        for (int r = 0; r < trace.vocab.length; r++) List<double>.filled(trace.model.width, 0),
      ];
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          final List<double> error = BackwardScene.errors(view(inks, kit, checkpoint: c, peptide: p, position: i), i);
          for (int r = 0; r < trace.vocab.length; r++) {
            for (int d = 0; d < trace.model.width; d++) {
              mean[r][d] += error[r] * trace.stream(at, last, p, i, d) / trace.targetCount;
            }
          }
        }
      }
      final double clip = trace.steps.clip[scene.step - 1];
      for (int r = 0; r < trace.vocab.length; r++) {
        for (int d = 0; d < trace.model.width; d++) {
          expect(mean[r][d] * clip, closeTo(trace.headGrad(at, r, d), 1e-6), reason: 'step ${scene.step} r$r d$d');
          if (trace.allowedIndex(r) < 0) {
            expect(mean[r][d], 0);
          }
        }
      }
    }
  });

  testWidgets("Backward's captions carry the run's numbers", (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const BackwardScene scene = BackwardScene();
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView v = view(inks, kit, checkpoint: c);
      String at(double beat) => scene.caption(v, timeline.frameIn(LmStage.backward, beat / LmStage.backward.beats));
      final List<double> shares = PredictScene.shares(v, v.position);
      expect(at(0.5), contains(nats(trace.loss(v.step))));
      expect(at(10.5), contains(BackwardScene.signedNumber(shares[v.target] - 1)));
      final int d = BackwardScene.firstMade(v);
      expect(at(20.0), contains('Number ${d + 1}'));
      expect(at(20.0), contains(fixed(BackwardScene.rowGradient(v)[d], 2)));
      expect(at(29.5), contains('final LayerNorm'));
      expect(at(LmStage.backward.beats.toDouble()), startsWith('Every place at once'));
      // Every caption of the stage is a sentence of the run's, never empty.
      for (double beat = 0; beat <= LmStage.backward.beats; beat += 0.25) {
        expect(at(beat), isNotEmpty);
      }
    }
  });

  testWidgets('a tap on Backward asks for the batch, the line, nothing on the bench and ladder, then a place', (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    const BackwardScene scene = BackwardScene();
    final LmView v = view(inks, kit);
    TrainingFrame at(double beat) => timeline.frameIn(LmStage.backward, beat / LmStage.backward.beats);
    final LossLayout loss = LossLayout(size, v);
    // The batch: another line puts its peptide in focus.
    final int other = v.peptide == 0 ? 1 : 0;
    final LmHit? line = scene.hitAt(size, v, loss.tile(other, 0).center, at(0.1));
    expect(line, isA<FocusPeptide>());
    expect((line! as FocusPeptide).peptide, other);
    // While the line goes back out of the batch, nothing.
    expect(scene.hitAt(size, v, loss.soloTile(1).center, at(1.0)), isNull);
    // The line alone: a target puts its place in focus.
    final LmHit? place = scene.hitAt(size, v, loss.soloTile(1).center, at(3.0));
    expect(place, isA<FocusPosition>());
    expect((place! as FocusPosition).position, 1);
    // The bench and the ladder ask for nothing.
    final StreamTable table = StreamTable(size, v);
    expect(scene.hitAt(size, v, table.row(2).center, at(20)), isNull);
    expect(scene.hitAt(size, v, table.row(2).center, at(33)), isNull);
    // The table: a row puts its place in focus.
    final LmHit? row = scene.hitAt(size, v, table.row(2).center, at(LmStage.backward.beats.toDouble()));
    expect(row, isA<FocusPosition>());
    expect((row! as FocusPosition).position, 2);
  });

  testWidgets("Backward's gradient column stands between the last row and the errors, its numbers clear of both", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (final Size size in <Size>[const Size(440, 697), const Size(375, 476)]) {
      final BackwardLayout layout = BackwardLayout(size, view(inks, kit));
      final PredictLayout bench = layout.predict;
      // Room for the gradient's numbers between the two columns...
      expect(layout.gradientColumn.left - bench.inputColumn.right, greaterThanOrEqualTo(bench.numberWidth), reason: '$size');
      // ...and for the strings between it and the errors.
      expect(bench.logitTile(0, 0).left - layout.gradientColumn.right, greaterThan(40), reason: '$size');
      for (int d = 0; d < trace.model.width; d++) {
        expect(layout.gradientTile(d).top, closeTo(bench.inputTile(d).top, 1e-9));
      }
    }
  });

  testWidgets("Update's gradient is every place's pull, averaged, and its step AdamW's", (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final TraceCheckpoint at = trace.checkpoints[c];
      for (int p = 0; p < trace.peptides.length; p++) {
        for (final int i in <int>[0, 3, trace.peptides[p].inputs - 1]) {
          final LmView scene = view(inks, kit, checkpoint: c, peptide: p, position: i);
          final String where = 'step ${scene.step} p$p i$i';
          // The worked string is the place's largest error × number.
          final (int r, int d) = UpdateScene.worked(scene);
          final List<double> error = BackwardScene.errors(scene, i);
          final List<double> row = UpdateScene.lastRow(scene, p, i);
          for (int k = 0; k < error.length; k++) {
            for (int e = 0; e < row.length; e++) {
              expect((error[k] * row[e]).abs(), lessThanOrEqualTo((error[r] * row[d]).abs() + 1e-15), reason: where);
            }
          }
          // Every place's pull on it, added and over the targets, times the
          // clip, is the gradient the optimiser read.
          double all = 0;
          for (int q = 0; q < trace.peptides.length; q++) {
            all += UpdateScene.peptideSum(scene, q);
          }
          final double clip = trace.steps.clip[scene.step - 1];
          expect(all / trace.targetCount * clip, closeTo(trace.headGrad(at, r, d), 1e-6), reason: where);
          expect(UpdateScene.pulls(scene)[p][i], closeTo(error[r] * row[d], 1e-12), reason: where);
          // The written mean reads right from the written total.
          final double total = double.parse(UpdateScene.totalWritten(scene).replaceAll('−', '-').replaceAll('+', ''));
          expect(
            double.parse(UpdateScene.meanWritten(scene).replaceAll('−', '-').replaceAll('+', '')),
            closeTo(total / trace.targetCount, 5e-5),
            reason: where,
          );
        }
      }
      // AdamW's rule from the running averages the step found makes the
      // update the run kept, for every weight; at step 1, with no past, each
      // ratio is the gradient's sign alone.
      final double rate = trace.steps.learningRate[at.step - 1];
      for (int r = 0; r < trace.vocab.length; r++) {
        for (int d = 0; d < trace.model.width; d++) {
          final (_, _, double ratio, double step) = UpdateScene.adamOf(trace, at, r, d);
          final double w = trace.outputWeight(at, r, d);
          expect(
            trace.headUpdate(at, r, d),
            closeTo(step, 4e-7 * w.abs() + 1e-5 * (rate * ratio).abs() + 1e-12),
            reason: 'step ${at.step} r$r d$d',
          );
          final double g = trace.headGrad(at, r, d);
          if (at.step == 1 && g != 0) {
            expect(ratio, closeTo(g.sign, 1e-4), reason: 'r$r d$d');
          }
          if (trace.allowedIndex(r) < 0) {
            expect(g, 0, reason: 'never next: r$r d$d');
          }
        }
      }
      final AdamRow row = UpdateScene.adam(view(inks, kit, checkpoint: c));
      for (int d = 0; d < trace.model.width; d++) {
        expect(row.after[d], closeTo(row.before[d] + row.step[d], 1e-12));
      }
    }
  });

  testWidgets("Update's captions carry the run's numbers", (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const UpdateScene scene = UpdateScene();
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView v = view(inks, kit, checkpoint: c);
      String at(double beat) => scene.caption(v, timeline.frameIn(LmStage.update, beat / LmStage.update.beats));
      final (String error, String number, String product) = UpdateScene.workedProduct(v);
      expect(at(1), startsWith('Back to the output layer'));
      expect(at(4.5), contains('$number to its p − y'));
      expect(at(4.5), endsWith(error));
      if (product != '0.00') {
        expect(at(6.5), endsWith(product));
      }
      expect(at(13), contains(UpdateScene.totalWritten(v)));
      expect(at(14.5), contains(UpdateScene.meanWritten(v)));
      expect(at(22), UpdateScene.total(v));
      expect(at(22), contains(nats(trace.steps.gradNorm[v.step - 1])));
      final AdamRow row = UpdateScene.adam(v);
      final int d = UpdateScene.worked(v).$2;
      expect(at(35), contains(fixed(row.before[d], UpdateScene.stepDigits(v))));
      expect(at(38.5), startsWith('The output layer after one update'));
      // Every caption of the stage is a sentence of the run's, never empty.
      for (double beat = 0; beat <= LmStage.update.beats; beat += 0.25) {
        expect(at(beat), isNotEmpty);
      }
    }
    // At step 1 AdamW has no past: the ratio is the sign.
    final LmView first = view(inks, kit);
    String at(double beat) => scene.caption(first, timeline.frameIn(LmStage.update, beat / LmStage.update.beats));
    expect(at(27), contains('with no past, the gradient itself'));
    expect(UpdateScene.signsAlone(first), isTrue);
    expect(at(31), contains('the sign alone'));
  });

  test("Update's opening rewrites Backward's table a row at a time, never leaving it empty", () {
    final int places = trace.peptides.first.inputs;
    for (int i = 0; i < places; i++) {
      // Every row starts as Backward left it, and ends as the output layer
      // read it, the two never on one row at once.
      expect(UpdateScene.rewritten(i, places, 0), (1.0, 0.0), reason: 'row $i');
      expect(UpdateScene.rewritten(i, places, 1.2).$2, 1.0, reason: 'row $i');
    }
    double previous = -1;
    for (double beat = 0; beat <= 1.3; beat += 0.01) {
      int between = 0;
      int first = -1;
      for (int i = 0; i < places; i++) {
        final (double gradient, double last) = UpdateScene.rewritten(i, places, beat);
        expect(gradient > 0 && last > 0, isFalse, reason: 'row $i at $beat');
        if (gradient < 0.5 && last < 0.5) {
          between += 1;
        }
        if (first < 0 && last < 1) {
          first = i;
        }
      }
      // A few rows at most are between the two as the wave passes, and the
      // wave only goes down.
      expect(between, lessThanOrEqualTo(3), reason: 'at $beat');
      expect(first >= previous || first < 0, isTrue, reason: 'at $beat');
      previous = first < 0 ? places.toDouble() : first.toDouble();
    }
  });

  testWidgets("Update's grid draws each weight as a square whose area is its size, never-next rows empty", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final RRect slot = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 16, 16), const Radius.circular(3));
    double area(RRect square) => square.width * square.height;
    // A weight at its scale takes the most a square takes; a quarter of it,
    // a quarter of that; nothing at zero; the sign changes only the colour.
    expect(area(UpdateScene.gridSquare(slot, 1)), closeTo(256 * UpdateScene.mostArea, 1e-9));
    expect(area(UpdateScene.gridSquare(slot, -0.25)), closeTo(256 * UpdateScene.mostArea / 4, 1e-9));
    expect(area(UpdateScene.gridSquare(slot, 0)), 0);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView v = view(inks, kit, checkpoint: c);
      expect(UpdateScene.squareColour(v, -0.3), inks.cell(-1));
      expect(UpdateScene.squareColour(v, 0.3), inks.cell(1));
      for (int k = 0; k < trace.vocab.length; k++) {
        for (int e = 0; e < trace.model.width; e++) {
          for (final double value in <double>[
            UpdateScene.gradientValue(v, k, e),
            UpdateScene.stepValue(v, k, e),
            UpdateScene.afterValue(v, k, e),
          ]) {
            expect(value.abs(), lessThanOrEqualTo(1), reason: 'step ${v.step}, token $k, number $e');
          }
          // A token that never comes next has no gradient, so no square.
          if (trace.allowedIndex(k) < 0) {
            expect(UpdateScene.gradientValue(v, k, e), 0, reason: 'step ${v.step}, token $k, number $e');
          }
        }
      }
    }
  });

  testWidgets('a tap on Update asks for a place on the tables, nothing elsewhere', (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    const Size size = Size(393, 540);
    const UpdateScene scene = UpdateScene();
    final LmView v = view(inks, kit);
    TrainingFrame at(double beat) => timeline.frameIn(LmStage.update, beat / LmStage.update.beats);
    final StreamTable table = StreamTable(size, v);
    // Backward's table, as the stage opens on it, and the same table as its
    // rows turn to every place's last row.
    for (final double beat in <double>[0, 0.6, 1.2]) {
      final LmHit? opening = scene.hitAt(size, v, table.row(2).center, at(beat));
      expect(opening, isA<FocusPosition>(), reason: 'beat $beat');
      expect((opening! as FocusPosition).position, 2);
    }
    // Once the place's row turns, and on the bench, a tap asks for nothing.
    for (final double beat in <double>[1.6, 5]) {
      expect(scene.hitAt(size, v, table.row(2).center, at(beat)), isNull, reason: 'beat $beat');
    }
    // Every place's last row: a row puts its place in focus, the box nothing.
    final LmHit? row = scene.hitAt(size, v, Offset(table.layout.cellsLeft + 4, table.row(2).center.dy), at(11));
    expect(row, isA<FocusPosition>());
    expect((row! as FocusPosition).position, 2);
    expect(scene.hitAt(size, v, UpdateLayout(size, v).box.center, at(13)), isNull);
    // The grid, the chart and AdamW's columns ask for nothing.
    for (final double beat in <double>[17, 21, 31, 38]) {
      expect(scene.hitAt(size, v, table.row(2).center, at(beat)), isNull, reason: 'beat $beat');
    }
  });

  testWidgets("Update's table, box, chart and AdamW's columns keep to the canvas, clear of each other", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (final Size size in <Size>[const Size(440, 697), const Size(375, 476)]) {
      for (int c = 0; c < trace.checkpoints.length; c++) {
        final LmView v = view(inks, kit, checkpoint: c);
        final UpdateLayout layout = UpdateLayout(size, v);
        final String where = '$size step ${v.step}';
        // The narrowed table's columns in order, the box right of them and on
        // the canvas.
        expect(layout.column(1).left, greaterThan(layout.column(0).right), reason: where);
        expect(layout.column(2).left, greaterThan(layout.column(1).right), reason: where);
        expect(layout.box.left, greaterThanOrEqualTo(layout.column(2).right + 10), reason: where);
        expect(layout.box.right, lessThanOrEqualTo(size.width), reason: where);
        // The grid on the bench's rows, each token's tile right beside its
        // row and on the canvas; the chart's bars from its names to its
        // numbers, the clip on it.
        expect(layout.grid.left, greaterThanOrEqualTo(0), reason: where);
        expect(layout.gridTile(0).left - layout.grid.right, inInclusiveRange(0, 6), reason: where);
        expect(layout.gridTile(0).right, lessThanOrEqualTo(size.width), reason: where);
        expect(layout.chartX(trace.config.gradClip), lessThan(layout.chartX(double.infinity)), reason: where);
        // AdamW: the weights, the gradients, the chart and after, in order,
        // on the canvas; the zero in the chart's middle.
        expect(layout.weightsX, lessThan(layout.gradientX), reason: where);
        expect(layout.gradientX, lessThan(layout.chartLeft), reason: where);
        expect(layout.chartLeft, lessThan(layout.chartZero), reason: where);
        expect(layout.chartZero, lessThan(layout.chartRight), reason: where);
        expect(layout.chartRight, lessThan(layout.afterX), reason: where);
        expect(layout.afterX, lessThan(size.width), reason: where);
      }
    }
  });

  testWidgets("every stage has a page of its own, in the sheet's font and the app's voice", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    // Greek but Δ and π, the double bar, the superscript minus and ⓘ: what
    // Space Grotesk, the sheet's face, cannot draw.
    final RegExp undrawable = RegExp('[\u0370-\u0393\u0395-\u03BF\u03C1-\u03FF\u2016\u207B\u24D8]');
    for (int c = 0; c < trace.checkpoints.length; c++) {
      for (final LmStage stage in LmStage.values) {
        final LmInfo info = sceneOf(stage).info(on(trace, inks, kit, checkpoint: c));
        final String where = '${stage.name} at step ${trace.checkpoints[c].step}';
        expect(info.title, stage.label, reason: where);
        expect(info.lead, isNotEmpty, reason: where);
        expect(info.sections, isNotEmpty, reason: where);
        for (final LmInfoSection section in info.sections) {
          expect(section.title, isNotEmpty, reason: where);
          expect(section.paragraphs.where((String p) => p.isEmpty), isEmpty, reason: '$where: ${section.title}');
        }
        final String page = <String>[info.title, words(info), ...info.sections.map((LmInfoSection s) => s.title)].join('\n');
        expect(page, isNot(contains(undrawable)), reason: where);
        expect(page, isNot(contains('!')), reason: where);
        expect(page, isNot(contains(RegExp(r'\b(simply|just)\b', caseSensitive: false))), reason: where);
      }
    }
  });

  testWidgets("Tokenise's info page keys the input's structure, and leaves training to the stages that train", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);

    final LmInfo info = const TokeniseScene().info(on(trace, inks, kit));
    expect(info.title, LmStage.tokenise.label);
    // A section a tag on the canvas, in the order they come.
    expect(info.sections.map((LmInfoSection s) => s.title), <String>[
      'Token ids',
      'Special tokens',
      'Batch 2D matrix',
      'Followed',
    ]);
    // What it takes and what it gives.
    final int peptides = trace.peptides.length;
    final int frame = trace.width + 1;
    expect(
      info.lead,
      '${spelledLeading(peptides)} peptides, ${grouped(trace.residues)} residues, become one $peptides × $frame '
      'matrix of token ids, all the model ever reads of them. Fixed: built once, before training.',
    );
    final String page = words(info);
    expect(page, contains('its row in the ${trace.vocab.length}-token vocabulary'));
    expect(page, contains('to the longest, $frame places, so the two stack'));
    expect(page, contains('the two go through the model together'));
    for (final String name in <String>['<bos>', '<eos>', '<pad>']) {
      expect(page, contains('$name (${glyph(trace, trace.vocab.indexOf(name))})'));
    }
    // Two ids side by side only because their letters are.
    final (int, int) pair = TokeniseScene.neighbours(trace)!;
    expect(pair.$2, pair.$1 + 1);
    expect(trace.token(pair.$2).codeUnitAt(0), trace.token(pair.$1).codeUnitAt(0) + 1);
    expect(
      page,
      contains(
        'a label, not an amount: ${trace.token(pair.$1)}, ${pair.$1}, and ${trace.token(pair.$2)}, ${pair.$2}, '
        'are neighbours only in the alphabet.',
      ),
    );
    // How to follow another peptide, and from where a place.
    expect(
      info.sections.last.paragraphs.single,
      'From ${LmStage.embedding.label} on, every stage works through one peptide, the followed one: tap another '
      'to follow it. From ${LmStage.scores.label} on, a tap on a row follows another of its places.',
    );
    // Training's consequences are the training stages' to say: no floor,
    // no level, no step, nothing held out.
    for (final String said in <String>['one in', 'nats', 'step', 'held out', 'generalis', 'trainable']) {
      expect(page, isNot(contains(said)), reason: said);
    }
  });

  testWidgets("Shift's info page says what x and y are, in the run's own numbers", (WidgetTester tester) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmInfo info = const ShiftScene().info(on(trace, inks, kit));
    expect(info.title, LmStage.shift.label);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>['Input x', 'Target y']);
    // What it takes and gives: Tokenise's matrix, and x and y, a place
    // shorter.
    final int peptides = trace.peptides.length;
    expect(
      info.lead,
      startsWith('The $peptides × ${trace.width + 1} matrix becomes two of $peptides × ${trace.width}: input x'),
    );
    final String page = words(info);
    expect(page, contains("hence Scores' struck keys and Attention's hatched cells"));
    expect(page, contains('its residues and <eos> (${glyph(trace, trace.vocab.indexOf('<eos>'))})'));
    // The places asked nothing are those whose answer in y is padding: one,
    // on the toy, whose peptides differ by a place.
    final int pad = trace.vocab.indexOf('<pad>');
    final int padded = trace.targets.fold<int>(0, (int n, List<int> row) => n + row.where((int id) => id == pad).length);
    expect(ShiftScene.unasked(trace), padded);
    expect(padded, 1);
    expect(page, endsWith('; the one place whose answer would be padding is dimmed, with nothing to score.'));
  });

  testWidgets("Embedding's info page says what its two tables are and what their sum carries", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView at = on(trace, inks, kit);
    final LmInfo info = const EmbeddingScene().info(at);
    expect(info.title, LmStage.embedding.label);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>[
      'Token embedding',
      'Position embedding',
      'x0 = token + position',
    ]);
    final int width = trace.model.width;
    final int context = trace.model.context;
    // The two tables, as the run counts its groups.
    final int tables = trace.groupSizes[trace.groups.indexOf('token_embedding')] +
        trace.groupSizes[trace.groups.indexOf('position_embedding')];
    expect(info.lead, startsWith('Each id of x becomes x0, a row of $width numbers'));
    expect(info.lead, endsWith('first trainable weights, ${grouped(tables)} of its ${grouped(trace.model.parameters)}.'));
    final String page = words(info);
    expect(page, contains('A ${trace.vocab.length} × $width table, a row a token'));
    // <pad>'s row is zero at every checkpoint the run kept.
    expect(page, contains("The rows start random (<pad>'s at zero)"));
    expect(page, contains('A $context × $width table, a row a place'));
    expect(page, contains('<bos> (${glyph(trace, trace.vocab.indexOf('<bos>'))}) and up to ${context - 1} residues'));
    expect(page, contains('so x0 stays $width wide'));
  });

  testWidgets("Scores' info page says what attention's first half makes, and why a score is divided", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView at = on(trace, inks, kit);
    final LmInfo info = const ScoresScene().info(at);
    expect(info.title, LmStage.scores.label);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>[
      'Evened row',
      'Query, key and value',
      'Head 1 and head 2',
      'Shares',
    ]);
    expect(info.lead, contains("${StreamTable.placeName(at, at.position)}'s query"));
    expect(info.lead, endsWith('the one part of the model where places exchange anything.'));
    final String page = words(info);
    final int width = trace.model.width;
    expect(page, contains('Three $width × $width weight tables make three rows of $width'));
    final int size = trace.headSize;
    expect(page, contains('cut into two slices of $size, a head each'));
    expect(page, contains('$size products summed, over √$size'));
  });

  testWidgets("Attention's info page says how a place gathers, and what is added to its row", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView at = on(trace, inks, kit);
    final LmInfo info = const AttentionScene().info(at);
    expect(info.title, LmStage.attention.label);
    // The last titled as its tag, less its size.
    final String sum = AttentionScene.sumTag(at);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>[
      'Values',
      'Output',
      'Shares in %',
      sum.substring(0, sum.indexOf(' · ')),
    ]);
    expect(info.lead, contains("added to its row: x0 + block 1's attention."));
    final String page = words(info);
    expect(page, contains('summed: ${trace.headSize} numbers'));
    expect(page, contains('a ${trace.model.width} × ${trace.model.width} table of output weights'));
    expect(page, contains('Each head has its own map.'));
  });

  testWidgets("Feed-forward's info page says how its network turns a row into what it adds", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmInfo info = const FeedForwardScene().info(on(trace, inks, kit));
    expect(info.title, LmStage.feedForward.label);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>[
      'Evened inputs',
      'GELU',
      "What block 1's feed-forward adds",
    ]);
    expect(info.lead, contains("block 1's output"));
    final String page = words(info);
    expect(page, contains('Each of ${trace.model.feedForward} neurons sums the ${trace.model.width} inputs'));
    expect(page, contains('Each neuron adds its ${trace.model.width} output weights'));
  });

  testWidgets("Forward's info page keys the ladder: the residual stream, and two blocks' two hops", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView at = on(trace, inks, kit);
    final LmInfo info = const ForwardScene().info(at);
    expect(info.title, LmStage.forward.label);
    // A section, titled as the ladder is tagged, less its size.
    final String title = info.sections.single.title;
    expect(title, "${StreamTable.placeName(at, at.position)}'s row, layer to layer");
    expect(ForwardScene.tag(at), startsWith('$title · '));
    expect(info.lead, contains("x0, block 1's attention and feed-forward, block 2's, then a last LayerNorm"));
    final String ladder = info.sections.single.paragraphs.single;
    expect(ladder, startsWith('Each part adds to the row and replaces nothing: the residual stream.'));
    expect(ladder, endsWith('so a place can take in what another had gathered: two blocks reach two hops back.'));
  });

  testWidgets("Predict's info page says how a row becomes a guess over the tokens that can come next", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmInfo info = const PredictScene().info(on(trace, inks, kit));
    expect(info.title, LmStage.predict.label);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>[
      'Output layer',
      'Logits',
      'Next-token probabilities',
    ]);
    final int vocab = trace.vocab.length;
    expect(info.lead, contains('into $vocab logits, one a token'));
    expect(info.lead, endsWith('probabilities over the ${trace.allowed.length} tokens that can come next.'));
    final String page = words(info);
    expect(page, contains('A $vocab × ${trace.model.width} table of weights and a bias a token'));
    // The tokens that never come next, as the run lists those that can.
    expect(trace.allowed, isNot(contains(trace.vocab.indexOf('<pad>'))));
    expect(trace.allowed, isNot(contains(trace.vocab.indexOf('<bos>'))));
    expect(page, contains('<pad> and <bos> never come next: struck to −∞, a share of 0.'));
  });

  testWidgets("Loss's info page says what a guess costs, the levels to beat, and what the mean means", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmInfo info = const LossScene().info(on(trace, inks, kit));
    expect(info.title, LmStage.loss.label);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>['p(y)', 'Even guess', 'Mean']);
    expect(info.lead, contains('their mean over the ${grouped(trace.targetCount)} targets'));
    final int count = trace.allowed.length;
    final String page = words(info);
    // The run's own levels, each of which it kept a step for passing.
    expect(
      page,
      contains(
        'Guessing all $count tokens evenly costs ln $count = ${nats(trace.uniform)} nats; by Tokenise\'s residue '
        "counts, ${nats(trace.unigram)}; by the residue before, ${nats(trace.bigram)}. Loop's curve passes all three.",
      ),
    );
    // e to the run's own losses: more unsure at first than an even guess.
    final double start = math.exp(trace.loss(1));
    expect(start, greaterThan(count));
    expect(
      page,
      endsWith(
        '${exponential(start)} at step 1, more than $count; '
        '${exponential(math.exp(trace.loss(trace.steps.count)))} at step ${trace.steps.count}.',
      ),
    );

    // A run never under an even guess says its curve passes the rest only.
    final TrainingTrace never = edited((Map<String, Object?> json) {
      for (final Object? checkpoint in json['checkpoints']! as List<Object?>) {
        final Map<String, Object?> kept = checkpoint! as Map<String, Object?>;
        kept['why'] = <Object?>[
          for (final Object? why in kept['why']! as List<Object?>)
            if (why != 'uniform') why,
        ];
      }
    });
    expect(
      words(const LossScene().info(on(never, inks, kit))),
      contains("Loop's curve passes residue counts and residue pairs."),
    );
  });

  testWidgets("Backward's info page says where the gradient starts, how it flows back, and why its colours fade", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmView at = on(trace, inks, kit);
    final LmInfo info = const BackwardScene().info(at);
    expect(info.title, LmStage.backward.label);
    final List<String> titles = info.sections.map((LmInfoSection s) => s.title).toList();
    expect(titles, <String>[
      'p − y',
      'Gradient',
      "${StreamTable.placeName(at, at.position)}'s gradient, layer to layer",
      'Gradient at x0',
    ]);
    // Titled as the canvas tags them, less their size.
    expect(BackwardScene.tag(at), startsWith('${titles[2]} · '));
    expect(BackwardScene.tableTag(at), startsWith('${titles[3].toLowerCase()} · '));
    expect(info.lead, endsWith('Backward only measures; Update moves the weights.'));
    final String page = words(info);
    expect(page, contains('so the first block learns as well as the last.'));
    expect(page, endsWith("on the whole batch's scale: a place with little left to learn is faint."));
  });

  testWidgets("Update's info page says how a weight's gradient is made, guarded and stepped", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmInfo info = const UpdateScene().info(on(trace, inks, kit));
    expect(info.title, LmStage.update.label);
    expect(info.sections.map((LmInfoSection s) => s.title), <String>['Pull', 'Clip', 'Step', 'Rate']);
    expect(info.lead, startsWith('The one stage that changes the model'));
    final String page = words(info);
    expect(page, contains('divided by the ${grouped(trace.targetCount)} targets'));
    final String clip = trace.config.gradClip.toStringAsFixed(1);
    expect(page, contains('all ${grouped(trace.model.parameters)} gradients together are longer than $clip'));
    expect(page, contains("${trace.optimizer.name} takes each weight's running mean"));
    expect(page, contains('decay also shrinks the weight matrices a little'));
    expect(page, contains('like the clip and the decay, not trained.'));
    // The run bears out that decay shrinks the matrices alone: the tokens
    // that never come next get no gradient, so their biases never move,
    // while decay alone shrinks their weights.
    final int width = trace.model.width;
    final TraceCheckpoint first = trace.checkpoints.first;
    final TraceCheckpoint last = trace.checkpoints.last;
    double size(TraceCheckpoint at, int row) {
      double sum = 0;
      for (int d = 0; d < width; d++) {
        sum += math.pow(trace.outputWeight(at, row, d), 2);
      }
      return sum;
    }

    for (final String name in <String>['<pad>', '<bos>']) {
      final int row = trace.vocab.indexOf(name);
      expect(trace.outputBias(last, row), trace.outputBias(first, row), reason: name);
      expect(size(last, row), lessThan(size(first, row)), reason: name);
    }

    // A run with no decay says nothing of it.
    final TrainingTrace plain = edited(
      (Map<String, Object?> json) => (json['config']! as Map<String, Object?>)['weight_decay'] = 0.0,
    );
    final String still = words(const UpdateScene().info(on(plain, inks, kit)));
    expect(still, isNot(contains('decay')));
    expect(still, contains('like the clip, not trained.'));
  });

  testWidgets("Loop's info page says what the run learns, where it must stop, which steps it kept, and what made it", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    final LmInfo info = const LoopScene().info(on(trace, inks, kit));
    expect(info.title, LmStage.loop.label);
    final int steps = trace.steps.count;
    expect(info.sections.map((LmInfoSection s) => s.title), <String>[
      'Next-token probabilities',
      'Floor',
      '${grouped(steps)} steps',
      'This run',
    ]);
    expect(info.lead, startsWith('The whole step, ${grouped(steps)} times, on the same batch'));
    final String page = words(info);
    expect(page, contains('the run shows a model learning these two, not generalising.'));
    // The toy's floor is <bos>'s alone: its two first residues differ.
    final int peptides = trace.peptides.length;
    expect(trace.floor, closeTo(peptides * math.log(peptides) / trace.targetCount, 1e-6));
    expect(
      info.sections[1].paragraphs.single,
      "From <bos> (${glyph(trace, trace.vocab.indexOf('<bos>'))}) alone, a peptide's first residue could be any of "
      'the two: one in two at best. That floor, ${nats(trace.floor)}, is a loss no model can pass here.',
    );
    // A run whose first residues coincide claims no one-in-N guess.
    final TrainingTrace alike = edited((Map<String, Object?> json) {
      final List<Object?> runs = json['peptides']! as List<Object?>;
      final Map<String, Object?> second = runs[1]! as Map<String, Object?>;
      final String first = (runs[0]! as Map<String, Object?>)['sequence']! as String;
      second['sequence'] = '${first[0]}${(second['sequence']! as String).substring(1)}';
    });
    expect(
      LoopScene.floorWhy(alike),
      'The floor, ${nats(alike.floor)}, is a loss no model can pass here.',
    );
    // The toy kept a step for every level but a tenth of a nat.
    expect(trace.checkpoints.any((TraceCheckpoint c) => c.why.contains('tenth_nat')), isFalse);
    expect(
      page,
      contains(
        'Its ticks are the ${spelled(trace.checkpoints.length)} steps the run kept whole, by rule: the first; '
        'the first under an even guess, residue counts, residue pairs and one nat; and the last. '
        'Embedding to Update show one of them, picked from the Step menu',
      ),
    );
    // The recording, as the run's own record has it.
    expect(
      page,
      contains(
        'HelixPeekLM, ${grouped(trace.model.parameters)} parameters: two blocks of two heads, '
        '${trace.model.width} numbers a place, trained for ${grouped(steps)} steps on a CPU, '
        "seed ${trace.config.seed}, PyTorch ${trace.provenance['torch']}, with dropout off, so the pass drawn is "
        'the one trained, and every number kept as it went. Recorded again, the run is the same, byte for byte.',
      ),
    );
    final TraceSource source = trace.peptides.first.source;
    expect(page, endsWith('The two peptides come from the curated records of ${source.slug} (${source.gene}).'));
  });
}
