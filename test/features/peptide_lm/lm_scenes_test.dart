import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_format.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_inks.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/attention_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/block_two_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/embedding_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/feed_forward_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/forward_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_drawing.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene_painter.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/scores_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/stream_table.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/worked_answer.dart';

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
    // Attention, after Scores: head 1's values, head 2, the heads' answers,
    // number 1 of head 1's worked out, the answers through the output
    // weights, head 1's map (the row in focus first, then every row), what
    // attention adds.
    double attention(double beat) => beat / LmStage.attention.beats;
    expect(caption(LmStage.attention, attention(0.5)), "Head 1 hands V3 its shares of each place's value: $size numbers");
    expect(caption(LmStage.attention, attention(2.5)), 'Head 2, its own query and keys: V3 reads ${head(1)}');
    expect(caption(LmStage.attention, attention(4.8)), "The heads' $size + $size numbers, side by side: $width");
    // Number 1 of head 1's answer worked out: V3's own value, as Scores made
    // it, then <bos>'s through the same weights, with their bias once
    // training has given them one; every place times its share; their sum,
    // the answer as the run kept it.
    double value1(int j) => trace.value(last3.checkpoint, 0, 0, 0, j, 0);
    final String valueBias = trace.projectionBias(last3.checkpoint, 0, 2, 0) != 0 ? ', + bias' : '';
    expect(valueBias, isNotEmpty);
    final double answer1 = trace.mixed(last3.checkpoint, 0, 0, 0, 3, 0);
    expect(caption(LmStage.attention, attention(5.5)), "Number 1 of head 1's answer, ${fixed(answer1, 2)}, worked out");
    expect(
      caption(LmStage.attention, attention(6.8)),
      "V3's value 1, as in Scores: its row × $width weights$valueBias: ${WorkedAnswer.term(value1(3), 2)}",
    );
    expect(
      caption(LmStage.attention, attention(8)),
      "<bos>'s value 1: its own row, the same $width weights$valueBias: ${WorkedAnswer.term(value1(0), 2)}",
    );
    expect(caption(LmStage.attention, attention(9)), 'Every place the same: its own row, the same weights');
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
    expect(caption(LmStage.attention, attention(10)), 'Each place adds its value 1 × its share: the last column');
    // Then one place at a time: the largest share, and what it adds; then the
    // place that adds most, and why.
    if (most == largest) {
      final String both = 'Largest share: ${name(most)}, ${share(most)}, of a value of '
          '${WorkedAnswer.term(value1(most), 2)}: it adds most, ${WorkedAnswer.term(brought[most], 3)}';
      expect(caption(LmStage.attention, attention(11)), both);
      expect(caption(LmStage.attention, attention(12)), both);
    } else {
      expect(
        caption(LmStage.attention, attention(11)),
        'Largest share: ${name(largest)}, ${share(largest)}, but its value is '
        '${WorkedAnswer.term(value1(largest), 2)}: it adds only ${WorkedAnswer.term(brought[largest], 3)}',
      );
      expect(
        caption(LmStage.attention, attention(12)),
        '${name(most)} adds most, ${WorkedAnswer.term(brought[most], 3)}: a smaller share, '
        '${share(most)}, but its value is ${WorkedAnswer.term(value1(most), 2)}',
      );
    }
    expect(caption(LmStage.attention, attention(13)), "Summed: ${fixed(answer1, 2)}, number 1 of head 1's answer");
    expect(caption(LmStage.attention, attention(13.8)), 'Numbers 2–$width the same way, each head with its own shares');
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
      attentionAt(first, 15),
      'Output number 1: all $width × their weights, summed: ${fixed(gained(first), 2)}',
    );
    expect(
      attentionAt(last3, 15),
      'Output number 1: all $width × their weights, summed, + bias: ${fixed(gained(last3), 2)}',
    );
    expect(
      caption(LmStage.attention, attention(16)),
      'The other ${width - 1} the same: ${width * width} output weights, $width into each',
    );
    expect(caption(LmStage.attention, attention(16.6)), 'What attention adds to V3');
    expect(caption(LmStage.attention, attention(17.6)), "Head 1's map: V3's row first, its shares from Scores");
    expect(
      caption(LmStage.attention, attention(19.2)),
      'Every place does what V3 did, its query on the keys up to it',
    );
    expect(
      caption(LmStage.attention, attention(21.6)),
      "Each row made as V3's was: its shares × the values, × output weights",
    );
    expect(caption(LmStage.attention, 0.99), 'Added: x0 + attention, 12 × $width');
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
    expect(caption(LmStage.feedForward, fed(17.6)), "Back to V3's row, to be added");
    expect(caption(LmStage.feedForward, fed(18.5)), 'What the feed-forward adds to each place: 12 rows of $width');
    expect(caption(LmStage.feedForward, 0.99), "Added: block 1's output, 12 × $width");
    // Block 2: block 1's two parts again, on block 1's output; head 1's map,
    // block 1's and then its own; what each part adds, alone, then added.
    double second(double beat) => beat / LmStage.blockTwo.beats;
    expect(caption(LmStage.blockTwo, second(0.5)), "Block 2: the same two parts again, on block 1's output, 12 × $width");
    expect(
      caption(LmStage.blockTwo, second(2)),
      "Block 1's head 1, as Attention drew it: V3 read ${AttentionScene.readsMost(last, 0, layer: 0)}",
    );
    expect(
      caption(LmStage.blockTwo, second(3)),
      "Block 2's head 1, its own weights: V3 reads ${AttentionScene.readsMost(last, 0, layer: 1)}",
    );
    expect(AttentionScene.readsMost(last, 0, layer: 1), isNot(AttentionScene.readsMost(last, 0, layer: 0)));
    expect(caption(LmStage.blockTwo, second(4.5)), "Every place reads anew with block 2's weights: 12 rows");
    expect(caption(LmStage.blockTwo, second(6.5)), "What block 2's attention adds to each place, made as in Attention");
    expect(caption(LmStage.blockTwo, second(8)), "Added: block 1's output + attention, 12 × $width");
    expect(caption(LmStage.blockTwo, second(9)), "Block 2's feed-forward, each place alone: its own $width → $ff → $width");
    expect(caption(LmStage.blockTwo, 0.99), "Added: block 2's output, 12 × $width");
    // Forward: V3's row through the whole pass, a part at a time, then the
    // final LayerNorm, worked as Feed-forward's on the run's own numbers.
    double forward(double beat) => beat / LmStage.forward.beats;
    expect(caption(LmStage.forward, forward(0.5)), "V3's row after both blocks: how it was built, part by part");
    expect(
      caption(LmStage.forward, forward(2)),
      "Block 1's attention adds what V3 gathered from the places up to it",
    );
    expect(
      caption(LmStage.forward, forward(4)),
      "Block 1's feed-forward adds its network's output: block 1's output",
    );
    expect(caption(LmStage.forward, forward(5.5)), "Block 2's attention reads that row anew and adds what it gathers");
    expect(caption(LmStage.forward, forward(7.5)), "Block 2's feed-forward adds its own: V3's row as block 2 left it");
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

    // Scores, Attention, Feed-forward, Block 2 and Forward: a row, or its row
    // of a map, puts its place in focus, every place reachable.
    for (final (LmStage stage, double local) in <(LmStage, double)>[
      (LmStage.scores, 0),
      (LmStage.scores, 0.3),
      (LmStage.scores, 1),
      (LmStage.attention, 0),
      (LmStage.attention, 1),
      (LmStage.feedForward, 0.01),
      (LmStage.feedForward, 1),
      (LmStage.blockTwo, 0),
      (LmStage.blockTwo, 0.3),
      (LmStage.blockTwo, 1),
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
    // While the network takes Feed-forward's canvas, a tap asks for nothing.
    expect(
      sceneOf(LmStage.feedForward).hitAt(size, scene, const Offset(30, 300), timeline.frameIn(LmStage.feedForward, 0.4)),
      isNull,
    );

    // Attention's map lies on the table's rows: a tap on a row of it, on a
    // share it reads or on a place it never reads, puts that row's place in
    // focus.
    final TrainingFrame map = timeline.frameIn(LmStage.attention, 20 / LmStage.attention.beats);
    final AttentionLayout attention = AttentionLayout(size, scene);
    final int places = trace.peptides.first.inputs;
    for (int i = 0; i < places; i++) {
      for (final int j in <int>[0, places - 1]) {
        final LmHit? hit = sceneOf(LmStage.attention).hitAt(size, scene, attention.mapCell(i, j).center, map);
        expect((hit! as FocusPosition).position, i, reason: 'row $i, column $j');
      }
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
        (LmStage.feedForward, LmStage.blockTwo),
        (LmStage.blockTwo, LmStage.forward),
      ]) {
        final List<int> last = await pixels(scene, timeline.frameIn(before, 1));
        final List<int> first = await pixels(scene, timeline.frameIn(after, 0));
        expect(last.any((int b) => b != last.first), isTrue);
        expect(first, last, reason: '${after.label} opens on ${before.label}');
      }
    }
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

  testWidgets('the worked answer opens and ends on the frame the answers stand in, pixel for pixel', (
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
      final List<int> opens = await pixels(scene, from);
      expect(opens.any((int b) => b != opens.first), isTrue);
      expect(await pixels(scene, to), opens, reason: 'peptide $p');
      // In between, the table: not the frame it opens on.
      expect(await pixels(scene, from + 4.8), isNot(opens), reason: 'peptide $p');
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
    expect(from, greaterThan(AttentionScene.times(trace.model.heads - 1, trace.model.heads).end));
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
  });

  testWidgets("Block 2's map is head 1's of block 2, turning from block 1's in Attention's order", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await _drawing(tester);
    addTearDown(kit.dispose);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final LmView scene = view(inks, kit, checkpoint: c);
      final TraceCheckpoint at = scene.checkpoint;
      final int n = scene.focus.inputs;
      final List<List<double>> rows = AttentionScene.allShares(scene, AttentionScene.mapHead, layer: BlockTwoScene.block);
      for (int i = 0; i < n; i++) {
        expect(rows[i].reduce((double a, double b) => a + b), closeTo(1, 1e-9));
        for (int j = 0; j <= i; j++) {
          // Softmax of block 2's kept scores is its kept map, to the map's
          // own step.
          expect(
            rows[i][j],
            closeTo(trace.attention(at, BlockTwoScene.block, AttentionScene.mapHead, 0, i, j), at.attentionScale / 2 + 1e-6),
          );
        }
      }
      expect(
        rows[scene.position],
        AttentionScene.shares(scene, AttentionScene.mapHead, layer: BlockTwoScene.block),
      );
    }
    // The row in focus turns first, a cell at a time from <bos>; then every
    // other row, top to bottom; all of it before the map goes.
    const int focus = 3;
    const int n = 12;
    double first(bool Function(double beat) reached) {
      for (double beat = 0; beat <= LmStage.blockTwo.beats; beat += 0.01) {
        if (reached(beat)) {
          return beat;
        }
      }
      return double.infinity;
    }

    double starts(int i, int j) => first((double b) => BlockTwoScene.turnedAt(i, j, focus, n, b) > 0);
    double ends(int i, int j) => first((double b) => BlockTwoScene.turnedAt(i, j, focus, n, b) >= 1);
    for (int j = 1; j <= focus; j++) {
      expect(starts(focus, j), greaterThan(starts(focus, j - 1)));
    }
    expect(starts(0, 0), greaterThanOrEqualTo(ends(focus, focus)));
    for (int i = 1; i < n; i++) {
      if (i != focus && i - 1 != focus) {
        expect(starts(i, 0), greaterThan(starts(i - 1, 0)));
      }
    }
    expect(ends(n - 1, n - 1), lessThan(5.6));
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
}
