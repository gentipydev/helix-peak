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
import 'package:helixpeek/features/peptide_lm/presentation/scenes/embedding_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/feed_forward_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/forward_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_drawing.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene_painter.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/scores_scene.dart';

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
    expect(caption(LmStage.embedding, embedding(8)), "Each row is one place: <bos>, then toy A's 11 residues");
    expect(
      caption(LmStage.embedding, embedding(12.2)),
      'The position embedding: one learned row per place, here rows 0–11 of ${trace.model.context}',
    );
    expect(caption(LmStage.embedding, embedding(14)), startsWith("Each place's row is added to its residue's"));
    expect(caption(LmStage.embedding, embedding(15.5)), 'x0, 12 × $width: the start of the residual stream');
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
    // Attention, after Scores: head 1's values, head 2, the join, the maps,
    // what attention adds.
    double attention(double beat) => beat / LmStage.attention.beats;
    expect(caption(LmStage.attention, attention(0.5)), "Head 1 hands V3 its shares of each place's value: $size numbers");
    expect(caption(LmStage.attention, attention(2.5)), 'Head 2, its own query and keys: V3 reads ${head(1)}');
    expect(
      caption(LmStage.attention, attention(4.8)),
      "The two heads' $size + $size numbers, mixed back to $width: what V3 read",
    );
    expect(
      caption(LmStage.attention, attention(5.6)),
      'Every place at once: a map row each, nothing above the diagonal',
    );
    expect(caption(LmStage.attention, attention(7.6)), 'What attention adds to each place: 12 rows of $width');
    expect(caption(LmStage.attention, 0.99), 'Added: x0 + attention, 12 × $width');
    // Feed-forward, block 1's, at V3.
    double fed(double beat) => beat / LmStage.feedForward.beats;
    final int ff = trace.model.feedForward;
    expect(
      caption(LmStage.feedForward, fed(0.5)),
      'Block 1, feed-forward: one small network, each place on its own',
    );
    expect(caption(LmStage.feedForward, fed(1.2)), "V3's row, evened out (LayerNorm): its $width numbers go in");
    expect(
      caption(LmStage.feedForward, fed(3)),
      '$ff neurons, each a weighted sum of the $width through GELU: '
      '${FeedForwardScene.litNeurons(last)} light up',
    );
    expect(caption(LmStage.feedForward, fed(5)), '$width out, each a weighted sum of the $ff neurons');
    expect(caption(LmStage.feedForward, fed(7)), "Back to V3's row, to be added");
    expect(caption(LmStage.feedForward, fed(8)), 'What the feed-forward adds to each place: 12 rows of $width');
    expect(caption(LmStage.feedForward, 0.99), "Added: block 1's output, 12 × $width");
    // Forward: the pass layer to layer, each place read out early.
    double forward(double beat) => beat / LmStage.forward.beats;
    expect(
      caption(LmStage.forward, forward(0.5)),
      'The whole pass, layer to layer: a row a place, a column a layer',
    );
    expect(
      caption(LmStage.forward, forward(2)),
      'Block 1, as seen: V3 reads out ${ForwardScene.said(last, 0, 3)} at x0, ${ForwardScene.said(last, 2, 3)} after it',
    );
    expect(caption(LmStage.forward, forward(3.5)), allOf(startsWith("Block 2's heads: V3 reads "), contains('(head 2)')));
    expect(
      caption(LmStage.forward, forward(6.5)),
      "Block 2's feed-forward: V3 now reads out ${ForwardScene.said(last, 4, 3)}; next is ${trace.token(last.target)}",
    );
    expect(
      caption(LmStage.forward, forward(7.5)),
      'The final LayerNorm: each row as the output layer reads it, in Predict',
    );
    expect(
      caption(LmStage.forward, 0.99),
      'Right after x0 and each part: '
      '${<String>[for (int c = 0; c < trace.readouts; c++) '${ForwardScene.right(last, c)}'].join(', ')} of 12 places',
    );
    // The last column read out is the model's own: what Predict draws.
    final int lastPoint = trace.readouts - 1;
    int predicted = 0;
    for (int i = 0; i < trace.peptides.first.inputs; i++) {
      int best = 0;
      for (int k = 0; k < trace.allowed.length; k++) {
        if (trace.probability(last.checkpoint, 0, i, k) > trace.probability(last.checkpoint, 0, i, best)) {
          best = k;
        }
      }
      if (trace.allowed[best] == trace.targetAt(0, i)) {
        predicted++;
      }
    }
    expect(ForwardScene.right(last, lastPoint), predicted);
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

    // Scores, Attention, Feed-forward and Forward: a row puts its place in focus,
    // every place reachable.
    for (final (LmStage stage, double local) in <(LmStage, double)>[
      (LmStage.scores, 0),
      (LmStage.scores, 0.3),
      (LmStage.scores, 1),
      (LmStage.attention, 0),
      (LmStage.attention, 1),
      (LmStage.feedForward, 0.02),
      (LmStage.feedForward, 1),
      (LmStage.forward, 1),
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
    // While the network takes Feed-forward's canvas, a tap asks for nothing.
    expect(
      sceneOf(LmStage.feedForward).hitAt(size, scene, const Offset(30, 300), timeline.frameIn(LmStage.feedForward, 0.4)),
      isNull,
    );

    // Attention's maps: a head's map shows it alone in Forward; again, both.
    final TrainingFrame maps = timeline.frameIn(LmStage.attention, 6 / LmStage.attention.beats);
    final AttentionLayout attention = AttentionLayout(size, scene);
    expect(
      (sceneOf(LmStage.attention).hitAt(size, scene, attention.map(1).center, maps)! as FocusHead).head,
      1,
    );
    final LmView alone = view(inks, kit, head: 1);
    expect(
      (sceneOf(LmStage.attention).hitAt(size, alone, attention.map(1).center, maps)! as FocusHead).head,
      isNull,
    );
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

  test('numbers are written as the page writes them', () {
    expect(nats(3.14482), '3.145');
    expect(percent(0.991), '99%');
    expect(percent(0.0423), '4.2%');
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
