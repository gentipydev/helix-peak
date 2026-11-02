import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'attention_scene.dart';
import 'forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'loss_scene.dart';
import 'predict_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';
import 'weight_flow.dart';

/// Backward: the forward pass played back, along the same strings and the
/// same ladder, carrying how the loss would change instead of numbers. It
/// opens on Loss's last frame, the batch's bars under their mean. The line in
/// focus goes back out of the batch to stand alone, then the place in focus's
/// target flies up to its row of the shares Predict made. There the gradient
/// begins: p − y, each token's share less one at what came next, so the
/// target's row fills to 100% in the negative ink and every other bar turns
/// positive. Those 23 numbers stand where the logits were made, and run back
/// along the output layer's strings into the place's last row: each of its
/// numbers made from every token's error times its weight. Each string's own
/// gradient is the error at its end times the number at its start, and every
/// place adds its own: their mean is what Update moves the output layer by.
/// Then the place's gradient lies down into Forward's ladder and climbs it,
/// through the final LayerNorm, then each part from the last: every + passes
/// it up whole, and each part adds what it sends back, on a strip between the
/// rungs. At x0 it goes on to the two embedding rows that made x0, and every
/// place's x0 gradient comes in, a row a place, on the table.
///
/// Every number is the run's: the shares are Predict's, softmax of the whole
/// logits; the gradient at each point is the one the run kept, whole, at
/// every place. The loss is the mean over the targets, so the run's numbers
/// are drawn times their count: what each place's own cost sends back, the
/// sum of the costs' gradients; the mean, divided again, is said where the
/// output layer's gradient is.
final class BackwardScene extends LmScene {
  const BackwardScene();

  static double get _beats => LmStage.backward.beats.toDouble();

  // Back to the place in focus: the batch's other lines, its card, the
  // mean's line and the legend go; the line in focus goes back out of the
  // batch to stand alone; then it goes, and its target flies to its row of
  // the shares, which come in.
  static const (double, double) _othersOut = (0.2, 0.7);
  static const (double, double) _back = (0.3, 1.3);
  static const (double, double) _lineOut = (1.4, 1.8);
  static const (double, double) _fly = (1.4, 2.1);
  static const (double, double) _barsIn = (1.6, 2.2);

  // The guess read: the second caption, and what came next named on its row.
  static const double _guess = 2.4;

  // p − y: what the target lacks of 100%, then every other share; then the
  // bars condense into a column where the logits were made, which slides
  // back to where Predict made them.
  static const (double, double) _lack = (3.5, 4.2);
  static const (double, double) _excess = (4.3, 5.0);
  static const (double, double) _condense = (5.1, 5.8);

  // Back through the output layer: the place's last row stands at the left
  // with empty slots for its gradient beside it; the errors run back along
  // the strings, the largest number of the gradient alone and slowly, the
  // rest in one cascade.
  static const (double, double) _columnsIn = (5.8, 6.4);
  static const WeightFlow _flow = WeightFlow(
    alone: <(double, double)>[(6.6, 7.4)],
    cascade: (7.8, 8.8),
    webOut: (12.0, 12.4),
    firstRelax: 0.3,
  );

  // The weights' own gradients: each string relit by its error times the
  // number at its start, the strongest named; then every place's, averaged.
  static const (double, double) _own = (9.6, 10.2);
  static const (double, double) _strongest = (10.2, 10.6);
  static const (double, double) _mean = (10.9, 11.6);

  // The climb: the bench clears, the gradient lies down into the ladder's
  // last slot as the route comes in; then a part at a time from the last.
  static const (double, double) _benchOut = (12.0, 12.4);
  static const (double, double) _lieDown = (12.1, 12.8);
  static const (double, double) _routeIn = (12.3, 12.8);
  static const double _climbFrom = 13.0;
  static const double _climbTo = 18.5;

  // Every place: the ladder goes, the place's x0 gradient goes home to its
  // row of the table, and every other place's comes in; last, all the
  // gradients' length against the clip.
  static const (double, double) _ladderOut = (19.3, 19.8);
  static const (double, double) _home = (19.3, 20.1);
  static const (double, double) _othersIn = (19.6, 20.2);
  static const double _totalFrom = 20.4;

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats, const BackwardFade());

  /// The stage's last frame, with [fade] leaving out or fading what the stage
  /// after it draws itself.
  void paintEnd(Canvas canvas, Size size, LmView view, [BackwardFade fade = const BackwardFade()]) =>
      _paint(canvas, size, view, _beats, fade);

  void _paint(Canvas canvas, Size size, LmView view, double beat, BackwardFade fade) {
    if (beat <= 0) {
      const LossScene().paintEnd(canvas, size, view);
      return;
    }
    final BackwardLayout layout = BackwardLayout(size, view);
    final double lineGone = _span(beat, _lineOut);
    if (lineGone < 1) {
      final double others = 1 - _span(beat, _othersOut);
      const LossScene().paintEnd(
        canvas,
        size,
        view,
        LossFade(
          note: 0,
          tag: 1 - lineGone,
          others: others,
          card: others,
          mean: others,
          legend: others,
          line: 1 - lineGone,
          place: beat < _fly.$1 ? 1 : 0,
          zoom: 1 - _span(beat, _back),
        ),
      );
    }
    layout.table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, LossScene.notes(view).last.$3), ...notes(view)],
      beat,
      alpha: fade.note,
    );
    _bench(canvas, view, layout, beat);
    _target(canvas, view, layout, beat);
    _ladder(canvas, size, view, layout, beat);
    _table(canvas, view, layout, beat, fade);
  }

  // ------------------------------------------------------------------ data

  /// Place [i]'s error at each token, in id order: its share, Predict's own,
  /// less one at what came next; 0 at the two that never come next.
  static List<double> errors(LmView view, int i) => view.kit.memo<List<double>>(
    ('backward-errors', view.step, view.peptide, i),
    () {
      final List<double> shares = PredictScene.shares(view, i);
      final int next = view.trace.targetAt(view.peptide, i);
      return <double>[for (int r = 0; r < shares.length; r++) shares[r] - (r == next ? 1 : 0)];
    },
  );

  /// The place in focus's last row's gradient, number by number: every
  /// token's error times its weight to the number, summed, as its own cost
  /// sends it back.
  static List<double> rowGradient(LmView view) => view.kit.memo<List<double>>(
    ('backward-row', view.step, view.peptide, view.position),
    () {
      final TrainingTrace trace = view.trace;
      final List<double> error = errors(view, view.position);
      return <double>[
        for (int d = 0; d < trace.model.width; d++)
          <double>[
            for (int r = 0; r < trace.vocab.length; r++) trace.outputWeight(view.checkpoint, r, d) * error[r],
          ].fold<double>(0, (double sum, double v) => sum + v),
      ];
    },
  );

  /// The place in focus's last row, as Forward left it: what the output
  /// layer read.
  static List<double> lastRow(LmView view) => <double>[
    for (int d = 0; d < view.trace.model.width; d++)
      view.trace.stream(view.checkpoint, view.trace.points.length - 1, view.peptide, view.position, d),
  ];

  /// The number of the gradient made first: the largest.
  static int firstMade(LmView view) {
    final List<double> g = rowGradient(view);
    int best = 0;
    for (int d = 1; d < g.length; d++) {
      if (g[d].abs() > g[best].abs()) {
        best = d;
      }
    }
    return best;
  }

  /// The order the gradient's numbers are made in: the largest first, then
  /// the rest in order.
  static List<int> flowOrder(LmView view) {
    final int first = firstMade(view);
    return <int>[first, for (int d = 0; d < view.trace.model.width; d++) if (d != first) d];
  }

  /// The output layer's gradient over the whole batch, a row a token, a
  /// number a column of the last row: each place's error at the token times
  /// its last row's number, summed over every place and divided by their
  /// count, as the loss is their mean.
  static List<List<double>> meanGradient(LmView view) => view.kit.memo<List<List<double>>>(
    ('backward-mean', view.step),
    () {
      final TrainingTrace trace = view.trace;
      final int width = trace.model.width;
      final int last = trace.points.length - 1;
      final List<List<double>> sum = <List<double>>[
        for (int r = 0; r < trace.vocab.length; r++) List<double>.filled(width, 0),
      ];
      for (int p = 0; p < trace.peptides.length; p++) {
        final LmView there = _on(view, p);
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          final List<double> error = errors(there, i);
          for (int r = 0; r < trace.vocab.length; r++) {
            if (error[r] == 0) {
              continue;
            }
            for (int d = 0; d < width; d++) {
              sum[r][d] += error[r] * trace.stream(view.checkpoint, last, p, i, d);
            }
          }
        }
      }
      return <List<double>>[
        for (final List<double> row in sum) <double>[for (final double v in row) v / trace.targetCount],
      ];
    },
  );

  /// [view] with [peptide] in focus, at its first place.
  static LmView _on(LmView view, int peptide) => peptide == view.peptide
      ? view
      : LmView(
          trace: view.trace,
          checkpoint: view.checkpoint,
          peptide: peptide,
          position: 0,
          head: view.head,
          inks: view.inks,
          kit: view.kit,
        );

  /// Place [i]'s gradient at stream [point], as the run kept it, times the
  /// targets the loss is the mean of: what the sum of their costs sends
  /// back.
  static List<double> gradient(LmView view, int point, int i) => <double>[
    for (int d = 0; d < view.trace.model.width; d++)
      view.trace.streamGrad(view.checkpoint, point, view.peptide, i, d) * view.trace.targetCount,
  ];

  /// The place in focus's gradient at every point of the stream, a row a
  /// point.
  static List<List<double>> ladder(LmView view) => view.kit.memo<List<List<double>>>(
    ('backward-ladder', view.step, view.peptide, view.position),
    () => <List<double>>[for (int k = 0; k < view.trace.points.length; k++) gradient(view, k, view.position)],
  );

  /// The largest error any place of the batch sends back at this step: the
  /// scale the strings are drawn on, so a place with nothing to learn sends
  /// back strings as faint as its errors are small.
  static double errorReach(LmView view) => view.kit.memo<double>(
    ('backward-error-reach', view.step),
    () {
      double most = 1e-9;
      for (int p = 0; p < view.trace.peptides.length; p++) {
        final LmView there = _on(view, p);
        for (int i = 0; i < view.trace.peptides[p].inputs; i++) {
          for (final double e in errors(there, i)) {
            most = math.max(most, e.abs());
          }
        }
      }
      return most;
    },
  );

  /// Every place of the batch's gradient at [point]s, times the targets, as
  /// [gradient] draws each: what the batch's scales are taken over.
  static Iterable<double> _batchGradients(LmView view, Iterable<int> points) sync* {
    final TrainingTrace trace = view.trace;
    for (final int k in points) {
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          for (int d = 0; d < trace.model.width; d++) {
            yield trace.streamGrad(view.checkpoint, k, p, i, d) * trace.targetCount;
          }
        }
      }
    }
  }

  /// The colour scale of the gradient on the ladder: the whole batch's at
  /// every point at this step, so a place with little left to learn is drawn
  /// as faint as it is beside the others.
  static double ladderScale(LmView view) => view.kit.memo<double>(
    ('backward-ladder-scale', view.step),
    () => percentileScale(_batchGradients(view, <int>[for (int k = 0; k < view.trace.points.length; k++) k])),
  );

  /// What the part between points [k] and [k] + 1 sends back to the place in
  /// focus: the gradient above it less the one below.
  static List<double> sentBack(LmView view, int k) {
    final List<List<double>> rungs = ladder(view);
    return <double>[for (int d = 0; d < rungs[k].length; d++) rungs[k][d] - rungs[k + 1][d]];
  }

  /// The colour scale of what the parts send back, one for them all: what
  /// every part sends back to every place of the batch at this step.
  static double sentScale(LmView view) => view.kit.memo<double>(
    ('backward-sent-scale', view.step),
    () {
      final TrainingTrace trace = view.trace;
      final List<double> sent = <double>[];
      for (int k = 0; k < trace.points.length - 2; k++) {
        for (int p = 0; p < trace.peptides.length; p++) {
          for (int i = 0; i < trace.peptides[p].inputs; i++) {
            for (int d = 0; d < trace.model.width; d++) {
              sent.add(
                (trace.streamGrad(view.checkpoint, k, p, i, d) - trace.streamGrad(view.checkpoint, k + 1, p, i, d)) *
                    trace.targetCount,
              );
            }
          }
        }
      }
      return percentileScale(sent);
    },
  );

  /// The colour scale of every place's gradient at x0: the whole batch's.
  static double tableScale(LmView view) => view.kit.memo<double>(
    ('backward-table-scale', view.step),
    () => percentileScale(_batchGradients(view, const <int>[0])),
  );

  /// How much of the peptide's gradient at x0 is at `<bos>`'s row, by its
  /// square.
  static double bosShare(LmView view) {
    double first = 0;
    double all = 0;
    for (int i = 0; i < view.focus.inputs; i++) {
      final double squares = math.pow(view.trace.pointGrad(view.checkpoint, 0, view.peptide, i), 2).toDouble();
      all += squares;
      if (i == 0) {
        first = squares;
      }
    }
    return all <= 0 ? 0 : first / all;
  }

  /// A gradient's number with its sign, to two places; 0.00 where it rounds
  /// to nothing.
  static String signedNumber(double value) =>
      double.parse(value.abs().toStringAsFixed(2)) == 0 ? '0.00' : signed(value, 2);

  // ------------------------------------------------------- the target flies

  /// The place in focus's target, from its tile on the line alone up to its
  /// row of the shares, its ring going as it flies.
  void _target(Canvas canvas, LmView view, BackwardLayout layout, double beat) {
    if (beat < _fly.$1 || beat >= _fly.$2) {
      return;
    }
    final double fly = _span(beat, _fly);
    final Rect from = layout.loss.focusTile(view.position, 0);
    final Rect to = layout.predict.chip(view.target, layout.predict.slideBy);
    final Rect at = Rect.lerp(from, to, fly)!;
    drawToken(canvas, view, at, view.target);
    outlineToken(canvas, at, view.inks.signal, alpha: 1 - fly);
  }

  // ------------------------------------------------------------- the bench

  /// The output layer, played back: the shares as Predict left them, what the
  /// target lacks of 100% and what every other token took, condensing into a
  /// column of errors where the logits were made; the place's last row and
  /// the slots of its gradient at the left; the errors running back along the
  /// strings into them; then each string's own gradient, and the batch's.
  void _bench(Canvas canvas, LmView view, BackwardLayout layout, double beat) {
    final double gone = _span(beat, _benchOut);
    if (beat < _barsIn.$1 || gone >= 1) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final PredictLayout bench = layout.predict;
    final double shown = _span(beat, _barsIn) * (1 - gone);
    final double condense = _span(beat, _condense);
    final double dx = bench.slideBy * (1 - condense);
    final List<double> p = PredictScene.shares(view, view.position);
    final List<double> error = errors(view, view.position);
    final int target = view.target;
    final bool landed = beat >= _fly.$2;

    // The shares' bars, as Predict left them: the target's lit row, the
    // dashed 100%; what the target lacks, filling to it; every other bar
    // turning to what it took; then all of them going as the column comes.
    final double bars = shown * (1 - condense);
    if (bars > 0) {
      final double lack = _span(beat, _lack);
      final double excess = _span(beat, _excess);
      final TextStyle words = inked(view.kit.mono, bench.textSize, view.inks.ink);
      if (trace.allowedIndex(target) >= 0) {
        final Rect drawn = bench.bar(target, p[target]);
        final Rect band = PredictScene.litBand(bench, target, drawn, view.kit.layout(percent(p[target]), words).width);
        canvas.drawRRect(
          RRect.fromRectAndRadius(band, const Radius.circular(3)),
          Paint()..color = view.inks.truth.withValues(alpha: PredictScene.answerLight * bars),
        );
        if (lack > 0) {
          final double whole = bench.barLeft + bench.barRoom;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(drawn.right, drawn.top, drawn.right + (whole - drawn.right) * lack, drawn.bottom),
              const Radius.circular(1),
            ),
            Paint()..color = view.inks.negative.withValues(alpha: 0.9 * bars),
          );
        }
      }
      PredictScene.drawWhole(canvas, view, bench, bars);
      for (final int id in trace.allowed) {
        final Rect drawn = bench.bar(id, p[id]);
        final double turned = id == target ? 0 : excess;
        if (drawn.width > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(drawn, const Radius.circular(1)),
            Paint()
              ..color = Color.lerp(
                PredictScene.barColour(view),
                view.inks.positive.withValues(alpha: 0.9),
                turned,
              )!.withValues(alpha: (0.85 + 0.05 * turned) * bars),
          );
        }
        final double named = bars * (id == target ? 1 - lack : 1 - excess);
        if (named > 0 && percentNumber(p[id]) != '0.0') {
          final Size written = view.kit.draw(
            canvas,
            percent(p[id]),
            words.copyWith(color: words.color!.withValues(alpha: named)),
            Offset(drawn.right + 3, drawn.center.dy),
            anchor: const Offset(0, 0.5),
          );
          // What came next, named on its row while the guess is read.
          final double told = named * through(beat, _guess, _guess + 0.3);
          if (id == target && told > 0) {
            view.kit.draw(
              canvas,
              targetLabel,
              inked(view.kit.sans, 9, view.inks.truth, alpha: told),
              Offset(drawn.right + 3 + written.width + 8, drawn.center.dy),
              anchor: const Offset(0, 0.5),
            );
          }
        }
      }
    }

    // The column of errors, where the logits were made: each token's tile,
    // its number beside it, its chip; the two that never come next struck.
    final double column = shown * condense;
    drawColumn(canvas, (int r) => bench.logitTile(r, dx), <Color>[
      for (int r = 0; r < trace.vocab.length; r++)
        trace.allowedIndex(r) < 0 ? Colors.transparent : view.inks.signed(error[r]).withValues(alpha: column),
    ]);
    final double lackWritten = through(beat, _lack.$2 - 0.2, _lack.$2);
    final double excessWritten = through(beat, _excess.$2 - 0.2, _excess.$2);
    drawColumnNumbers(
      canvas,
      view,
      (int r) => bench.logitTile(r, dx),
      error,
      shown,
      textSize: bench.textSize,
      writes: bench.writes,
      alphaOf: (int r) => trace.allowedIndex(r) < 0
          ? 0
          : r == target
          ? lackWritten
          : excessWritten,
      format: signedNumber,
    );
    for (int r = 0; r < trace.vocab.length; r++) {
      final Rect tile = bench.logitTile(r, dx);
      if (trace.allowedIndex(r) < 0 && column > 0) {
        AttentionScene.hatch(
          canvas,
          view,
          Rect.fromLTRB(tile.left - 2, tile.top + 0.5, bench.chip(r, dx).right + 2, tile.bottom - 0.5),
          column,
        );
      }
      if (r != target || landed) {
        drawToken(canvas, view, bench.chip(r, dx), r, alpha: shown);
      }
    }
    drawColumnTitle(canvas, view, errorTitle, column, x: bench.logitX + dx, top: bench.benchTop);

    _columns(canvas, view, layout, beat, gone);
    _strings(canvas, view, layout, beat, gone);
  }

  /// What the target's row is called while the guess is read.
  static const String targetLabel = 'what truly came next';

  /// The error column's name.
  static const String errorTitle = 'p − y';

  /// The gradient column's name.
  static const String gradientTitle = 'gradient';

  /// The place's last row standing at the left, as Predict stood it, and
  /// beside it its gradient's slots, each number made as its strings land;
  /// the plate naming the weights under the strings, where they stand.
  void _columns(Canvas canvas, LmView view, BackwardLayout layout, double beat, double gone) {
    final double shown = _span(beat, _columnsIn) * (1 - gone);
    if (shown <= 0) {
      return;
    }
    final PredictLayout bench = layout.predict;
    final int width = view.trace.model.width;
    final List<double> row = bench.lastRow;
    drawColumn(canvas, bench.inputTile, <Color>[
      for (final double v in row) view.inks.cell(v / bench.lastScale).withValues(alpha: shown),
    ]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bench.inputColumn.inflate(1), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.signal.withValues(alpha: 0.85 * shown),
    );
    drawColumnNumbers(
      canvas,
      view,
      bench.inputTile,
      row,
      shown,
      textSize: bench.textSize,
      writes: bench.writes,
      left: true,
    );
    drawColumnTitle(
      canvas,
      view,
      StreamTable.placeName(view, view.position),
      shown,
      x: bench.inputX,
      top: bench.inputColumn.top,
    );

    // The gradient: empty slots, each made as its strings land.
    final List<double> g = rowGradient(view);
    final List<int> order = flowOrder(view);
    final List<int> rank = List<int>.filled(width, 0);
    for (int k = 0; k < width; k++) {
      rank[order[k]] = k;
    }
    final List<double> made = <double>[for (int d = 0; d < width; d++) _flow.madeAt(rank[d], width, beat)];
    // The column's tiles until it starts to lie down into the ladder, which
    // then draws them turning.
    final double kept = beat < _lieDown.$1 ? 1 : 0;
    drawSlots(canvas, view, layout.gradientTile, shown, made);
    if (kept > 0) {
      drawColumn(canvas, layout.gradientTile, <Color>[
        for (int d = 0; d < width; d++)
          view.inks.cell(g[d] / ladderScale(view)).withValues(alpha: made[d] * shown),
      ]);
    }
    layout.frame(canvas, view, layout.gradientColumn, shown * kept);
    drawColumnNumbers(
      canvas,
      view,
      layout.gradientTile,
      g,
      shown,
      textSize: bench.textSize,
      writes: bench.writes,
      left: true,
      alphaOf: (int d) => _flow.written(rank[d], width, beat),
    );
    drawColumnTitle(canvas, view, gradientTitle, shown, x: layout.gradientX, top: bench.benchTop);

    // The weights' plate, under the strings: where they stand, then, once
    // every place has added its own, what their gradient is.
    final String named = PredictScene.plateText(view);
    final Rect plate = bench.plateAt(tagSize(view, named));
    drawTag(canvas, view, named, plate.topLeft, alpha: shown);
    final double mean = _span(beat, _mean);
    if (mean < 1) {
      drawPlateStatus(canvas, view, plate, ScoresScene.weightsStatus(view), shown * (1 - mean), left: bench.left, right: bench.right);
    }
    if (mean > 0) {
      drawPlateStatus(canvas, view, plate, meanStatus(view), shown * mean, left: bench.left, right: bench.right);
    }
  }

  /// What the plate says once every place has added its own.
  static String meanStatus(LmView view) => 'gradient: the mean over ${grouped(view.trace.targetCount)} places';

  /// The strings, played back: the errors running from the column where the
  /// logits were made into each number of the gradient, a dot at each tip in
  /// the loss's honey; left faint, a weight on each; then each relit by its
  /// own gradient for the place in focus, the strongest named, and last by
  /// the batch's.
  void _strings(Canvas canvas, LmView view, BackwardLayout layout, double beat, double gone) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final List<int> allowed = trace.allowed;
    final List<double> error = errors(view, view.position);
    final List<double> input = <double>[for (final int id in allowed) error[id]];
    final List<int> order = flowOrder(view);
    Offset from(int j) => layout.predict.logitTile(allowed[j], 0).centerLeft;
    Offset toRank(int k) => layout.gradientTile(order[k]).centerRight;
    double weight(int k, int j) => trace.outputWeight(view.checkpoint, allowed[j], order[k]);
    final double own = _span(beat, _own);
    final double mean = _span(beat, _mean);
    final double web = _flow.webShown(width, beat) * (1 - gone);
    if (web > 0) {
      drawWeights(
        canvas,
        view,
        _flow,
        inputs: allowed.length,
        outputs: width,
        weight: weight,
        from: from,
        to: toRank,
        most: weightReach(width, allowed.length, weight),
        beat: beat,
        alpha: web * (1 - own),
      );
      drawFans(
        canvas,
        view,
        _flow,
        input: input,
        outputs: width,
        weight: weight,
        from: from,
        to: toRank,
        most: weightReach(width, allowed.length, weight) * errorReach(view),
        beat: beat,
        alpha: web,
        tip: view.inks.error,
      );
    }
    if (own <= 0 || gone >= 1) {
      return;
    }
    // Each string's own gradient for the place in focus: its error times the
    // number of the last row at its start.
    final List<double> row = layout.predict.lastRow;
    Offset to(int d) => layout.gradientTile(d).centerRight;
    final double ownShown = own * (1 - mean) * (1 - gone);
    if (ownShown > 0) {
      drawEdges(
        canvas,
        view,
        <(int, int, double)>[
          for (int j = 0; j < allowed.length; j++)
            for (int d = 0; d < width; d++) (j, d, input[j] * row[d]),
        ],
        from,
        to,
        ownShown,
        most: errorReach(view) * row.fold<double>(1e-9, (double most, double v) => math.max(most, v.abs())),
      );
    }
    final List<List<double>> batch = meanGradient(view);
    final double meanShown = mean * (1 - gone);
    if (meanShown > 0) {
      drawEdges(
        canvas,
        view,
        <(int, int, double)>[
          for (int j = 0; j < allowed.length; j++)
            for (int d = 0; d < width; d++) (j, d, batch[allowed[j]][d]),
        ],
        from,
        to,
        meanShown,
      );
    }
    // The strongest string of the place's own, lit in the loss's honey, its
    // two ends ringed: the error and the number it multiplies.
    final double strongest = _span(beat, _strongest) * (1 - mean) * (1 - gone);
    if (strongest > 0 && hasStrongest(view)) {
      final (int j, int d) = strongestString(view);
      final Paint honey = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = view.inks.error.withValues(alpha: strongest);
      canvas.drawLine(from(j), to(d), honey);
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.error.withValues(alpha: strongest);
      canvas.drawRRect(RRect.fromRectAndRadius(layout.predict.logitTile(allowed[j], 0).inflate(1.5), const Radius.circular(2.5)), ring);
      canvas.drawRRect(RRect.fromRectAndRadius(layout.predict.inputTile(d).inflate(1.5), const Radius.circular(2.5)), ring);
    }
  }

  /// The place in focus's strongest string: which of the tokens that can
  /// come next ([TrainingTrace.allowed]'s index) and which number of the last
  /// row it joins.
  static (int, int) strongestString(LmView view) {
    final TrainingTrace trace = view.trace;
    final List<double> error = errors(view, view.position);
    final List<double> row = lastRow(view);
    int bestJ = 0;
    int bestD = 0;
    double most = -1;
    for (int j = 0; j < trace.allowed.length; j++) {
      for (int d = 0; d < row.length; d++) {
        final double v = (error[trace.allowed[j]] * row[d]).abs();
        if (v > most) {
          most = v;
          bestJ = j;
          bestD = d;
        }
      }
    }
    return (bestJ, bestD);
  }

  /// Whether the place in focus's strongest string writes as anything at two
  /// places: a place with nothing left to learn has none to name.
  static bool hasStrongest(LmView view) {
    final (int j, int d) = strongestString(view);
    return signedNumber(errors(view, view.position)[view.trace.allowed[j]] * lastRow(view)[d]) != '0.00';
  }

  /// The largest of the batch's gradient on the output layer: which token,
  /// which number of the last row, and the gradient.
  static (int, int, double) largestMean(LmView view) {
    final List<List<double>> batch = meanGradient(view);
    int bestR = view.trace.allowed.first;
    int bestD = 0;
    for (final int r in view.trace.allowed) {
      for (int d = 0; d < batch[r].length; d++) {
        if (batch[r][d].abs() > batch[bestR][bestD].abs()) {
          bestR = r;
          bestD = d;
        }
      }
    }
    return (bestR, bestD, batch[bestR][bestD]);
  }

  // ------------------------------------------------------------ the ladder

  /// The climb into slot [k] of [points], from the slot under it: when it
  /// starts and how long it takes. The final LayerNorm's first, from the
  /// last slot up, then each part from the last.
  static (double, double) _rise(int k, int points) {
    final double step = (_climbTo - _climbFrom) / math.max(1, points - 1);
    return (_climbFrom + (points - 2 - k) * step, step);
  }

  /// How far the copy rising into slot [k] has come at [beat].
  static double risen(int k, int points, double beat) {
    final (double t, double p) = _rise(k, points);
    return through(beat, t + 0.2 * p, t + 0.68 * p);
  }

  /// How strongly the strip the copy into slot [k] rises through shows.
  static double _stripShown(int k, int points, double beat) {
    final (double t, double p) = _rise(k, points);
    return through(beat, t, t + 0.2 * p);
  }

  /// How strongly slot [k]'s row writes its numbers: from when it lands.
  static double _written(int k, int points, double beat) {
    if (k == points - 1) {
      return through(beat, _lieDown.$2 - 0.1, _lieDown.$2 + 0.1);
    }
    final (double t, double p) = _rise(k, points);
    return through(beat, t + 0.68 * p, t + 0.82 * p);
  }

  /// How far slot [k] has its row: the last once the column has lain down,
  /// the others once their copy has landed.
  static double _landed(int k, int points, double beat) =>
      k == points - 1 ? (beat >= _lieDown.$2 ? 1 : 0) : (risen(k, points, beat) >= 1 ? 1 : 0);

  /// Slot [k]'s name, over the gap the gradient climbs through to reach the
  /// slot above it: the final LayerNorm's, then each part's; and x0's.
  static String partName(int k, int layers) => switch (k) {
    0 => 'x0: on to its token row and its position row',
    _ when k > 2 * layers => 'back through the final LayerNorm',
    _ => "+ what block ${(k - 1) ~/ 2 + 1}'s ${k.isOdd ? 'attention' : 'feed-forward'} sends back",
  };

  /// The ladder's name: the place in focus's gradient, a row a point.
  static String tag(LmView view) =>
      "${StreamTable.placeName(view, view.position)}'s gradient, layer to layer · "
      '${view.trace.points.length} × ${view.trace.model.width}';

  /// The ladder, climbed back: the gradient's column lying down into the
  /// last slot as the route comes in, as Forward drew it; then a part at a
  /// time from the last, its strip of what it sends back coming in, and a
  /// copy of the gradient under it rising through it into the slot above,
  /// turning into the sum; each row framed in the loss's honey, its numbers
  /// written from when it lands. It goes as the table comes back.
  void _ladder(Canvas canvas, Size size, LmView view, BackwardLayout layout, double beat) {
    if (beat < _lieDown.$1) {
      return;
    }
    final double out = _span(beat, _ladderOut);
    if (out >= 1 && beat >= _home.$2) {
      return;
    }
    final StreamTable table = layout.table;
    final TowerLayout tower = layout.tower;
    final int points = tower.points;
    final int last = points - 1;
    final int layers = view.trace.model.layers;
    final List<List<double>> rungs = ladder(view);
    final double scale = ladderScale(view);
    List<Color> colours(int k) => <Color>[for (final double v in rungs[k]) view.inks.cell(v / scale)];
    final TextStyle? style = layout.ladderStyle;

    // The column lying down into the last slot.
    final double lie = _span(beat, _lieDown);
    if (lie < 1) {
      table.strip(canvas, from: tower.slot(last), to: layout.gradientColumn, f: 1 - lie, colors: colours(last));
    }

    drawFaded(canvas, size, view, 1 - out, () {
      final double route = _span(beat, _routeIn);
      final String name = tag(view);
      drawTag(canvas, view, name, tower.tagAt(tagSize(view, name)), alpha: route);
      drawToken(canvas, view, tower.chip, view.trace.inputAt(view.peptide, view.position), alpha: route);
      final TextStyle face = inked(view.kit.sans, 9, view.inks.quiet, alpha: route);
      for (int k = 0; k < points; k++) {
        if (_landed(k, points, beat) < 1) {
          tower.drawSlots(canvas, k, 0.6 * route);
        }
        view.kit.draw(canvas, partName(k, layers), face, tower.labelAt(k));
      }
      // What each part sends back, on its strip, as its climb starts.
      for (int k = 0; k < last - 1; k++) {
        final double strip = _stripShown(k, points, beat);
        if (strip > 0) {
          table.drawRow(canvas, tower.strip(k + 1), sentBack(view, k), scale: sentScale(view), text: 0, fill: strip);
        }
      }
      // The copies on their way up, out from under the row they copy.
      for (int k = 0; k < last; k++) {
        final double rise = risen(k, points, beat);
        if (rise <= 0 || rise >= 1) {
          continue;
        }
        final List<Color> under = colours(k + 1);
        final List<Color> over = colours(k);
        final double turn = through(rise, 0.3, 0.75);
        final Rect at = Rect.lerp(tower.slot(k + 1), tower.slot(k), rise)!;
        table.drawRow(
          canvas,
          at,
          rungs[k],
          scale: scale,
          colors: <Color>[for (int d = 0; d < under.length; d++) Color.lerp(under[d], over[d], turn)!],
          text: 0,
        );
        layout.frame(canvas, view, at, 1);
      }
      // Each row once landed, its numbers written; x0's goes home with the
      // table, so it is drawn there.
      for (int k = 0; k <= last; k++) {
        final double landed = _landed(k, points, beat);
        if (landed <= 0 || (k == 0 && beat >= _home.$1)) {
          continue;
        }
        table.drawRow(canvas, tower.slot(k), rungs[k], scale: scale, fill: landed, text: 0);
        tower.writeIn(canvas, tower.slot(k), rungs[k], _written(k, points, beat), style);
        layout.frame(canvas, view, tower.slot(k), landed);
      }
    });
  }

  // ------------------------------------------------------------- the table

  /// Every place at once: the place's x0 gradient going home from the
  /// ladder's top to its row of the table, every other place's coming in,
  /// the tiles naming them, the tag; the place in focus outlined.
  void _table(Canvas canvas, LmView view, BackwardLayout layout, double beat, BackwardFade fade) {
    if (beat < _home.$1) {
      return;
    }
    final StreamTable table = layout.table;
    final double home = _span(beat, _home);
    final double others = _span(beat, _othersIn) * fade.table;
    final double scale = tableScale(view);
    table.tag(canvas, tableTag(view), others);
    table.drawTiles(canvas, alpha: others, dx: -table.gutter);
    for (int i = 0; i < table.places; i++) {
      if (i == view.position) {
        continue;
      }
      table.drawRow(canvas, table.row(i), gradient(view, 0, i), scale: scale, fill: others, text: others);
    }
    // The place's own, from the ladder's top.
    final List<double> own = gradient(view, 0, view.position);
    final double ladderScaleNow = ladderScale(view);
    final Rect at = Rect.lerp(layout.tower.slot(0), table.row(view.position), home)!;
    table.drawRow(
      canvas,
      at,
      own,
      scale: scale,
      colors: <Color>[
        for (final double v in own) Color.lerp(view.inks.cell(v / ladderScaleNow), view.inks.cell(v / scale), home)!,
      ],
      text: 0,
      fill: fade.table,
    );
    if (home >= 1) {
      table.drawRow(canvas, at, own, scale: scale, fill: 0, text: others);
    } else {
      layout.tower.writeIn(canvas, at, own, (1 - home) * fade.table, layout.ladderStyle);
    }
    layout.frame(canvas, view, at, (1 - home) * fade.table);
    table.outline(canvas, view.position, table.row(view.position).right, others, dx: -table.gutter);
  }

  /// The table's name: every place's gradient at x0.
  static String tableTag(LmView view) => 'gradient at x0 · ${view.focus.inputs} × ${view.trace.model.width}';

  // ------------------------------------------------------------------- taps

  /// While the batch shows, a line puts its peptide in focus, and a target of
  /// the line in focus its place; on the line alone, a target its place;
  /// while the line moves, on the bench and on the ladder a tap asks for
  /// nothing; once the table has come, a row puts its place in focus.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final double beat = frame.local * _beats;
    if (beat < _back.$1) {
      return LossLayout(size, view).hitAt(at);
    }
    if (beat < _back.$2) {
      return null;
    }
    if (beat < _lineOut.$1) {
      return LossLayout(size, view).soloHitAt(at);
    }
    return beat < _othersIn.$2 ? null : hit(size, view, at);
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  // ---------------------------------------------------------------- caption

  /// Why each part happens, over the canvas, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final String focus = StreamTable.placeName(view, view.position);
    final int width = trace.model.width;
    return <(double, double, String)>[
      (
        0.25,
        _lack.$1,
        "A weight's gradient: how fast the loss rises as it rises.\n"
            'Update moves each weight a little against its own.\n'
            'Backward finds all ${grouped(trace.model.parameters)} in one pass, from the loss back.',
      ),
      (
        _lack.$1,
        _columnsIn.$1,
        "The gradient at each logit is its share less the target's 100%.\n"
            'A sure, right guess sends nothing back: p − y is 0.',
      ),
      (
        _columnsIn.$1,
        _own.$1,
        "Each logit was made along $width strings from $focus's row.\n"
            'Backward sends its error back along them, × each weight.',
      ),
      (
        _own.$1,
        _benchOut.$1,
        'A string that carried a large number into a large error moves most.\n'
            'The loss is the mean of ${grouped(trace.targetCount)} costs, so each gradient is ÷ ${grouped(trace.targetCount)}.',
      ),
      (
        _benchOut.$1,
        _home.$1,
        'Every + passes the gradient back up unchanged;\n'
            'each part adds what its own weights send back,\n'
            'and those weights get their gradients the same way.',
      ),
      (
        _home.$1,
        double.infinity,
        "A token row gets the sum of x0's gradients wherever it was read,\n"
            'a position row the sum at its place across the ${spelled(trace.peptides.length)} peptides.\n'
            'Over the clip, ${trace.config.gradClip.toStringAsFixed(1)}, every gradient would shrink by one factor.\n'
            'Next, Update moves every weight a step against its gradient.',
      ),
    ];
  }

  @override
  String caption(LmView view, TrainingFrame frame) => _caption(view, frame.local * _beats);

  String _caption(LmView view, double beat) {
    final TrainingTrace trace = view.trace;
    final String focus = StreamTable.placeName(view, view.position);
    final String next = trace.token(view.target);
    final List<double> p = PredictScene.shares(view, view.position);
    final int width = trace.model.width;
    if (beat < _back.$2) {
      return 'To lower the loss, ${nats(trace.loss(view.step))}, which way should each weight move?';
    }
    if (beat < _guess) {
      final double cost = LossScene.surprises(view)[view.peptide][view.position];
      return 'Start at one place, $focus: its cost, ${LossScene.cost(cost)} nats, '
          "is −ln of $next's ${percent(p[view.target])}";
    }
    if (beat < _lack.$1) {
      final int best = PredictScene.top(view, view.position);
      return best == view.target
          ? "$focus's guess: $next on top at ${percent(p[best])}, what truly came next"
          : "$focus's guess: ${trace.token(best)} on top at ${percent(p[best])}; "
                'the true next, $next, got ${percent(p[view.target])}';
    }
    if (beat < _excess.$1) {
      final String lack = signedNumber(p[view.target] - 1);
      return 'At $next, the target: p − y = ${percent(p[view.target])} − 100% = $lack'
          '${lack == '0.00' ? ': nothing to raise' : ': raise its logit'}';
    }
    if (beat < _condense.$1) {
      return _largestOthers(view) == null
          ? 'Every other token: its own share, all 0.00 here: nothing to lower'
          : 'Every other token: its own share, ${_largestOthers(view)}: lower each';
    }
    if (beat < _columnsIn.$1) {
      return 'p − y at all ${grouped(trace.vocab.length)} logits: what the others took is what $next lacked';
    }
    if (beat < _flow.fanAt(0, width).$1) {
      return "$focus's last row as Predict read it, and $width slots for its gradient";
    }
    if (beat < _flow.fanAt(1, width).$1) {
      final int d = firstMade(view);
      return "Number ${d + 1} of $focus's gradient: errors × weights, summed: ${fixed(rowGradient(view)[d], 2)}";
    }
    if (beat < _own.$1) {
      return 'The other ${grouped(width - 1)} the same way: back along the strings Predict used';
    }
    if (beat < _mean.$1) {
      if (!hasStrongest(view)) {
        return "A string's gradient: its error × $focus's number; all 0.00 here";
      }
      final (int j, int d) = strongestString(view);
      final int id = trace.allowed[j];
      final double v = errors(view, view.position)[id] * lastRow(view)[d];
      return "A string's gradient: its error × $focus's number; ${trace.token(id)}'s from ${d + 1}: "
          '${signedNumber(v)}';
    }
    if (beat < _benchOut.$1) {
      return 'Every place adds its own; their mean, ÷ ${grouped(trace.targetCount)}, is what Update will use';
    }
    if (beat < _climbFrom) {
      return "$focus's gradient climbs back up the ladder Forward came down";
    }
    final int points = trace.points.length;
    if (beat < _climbTo) {
      final double step = (_climbTo - _climbFrom) / math.max(1, points - 1);
      final int j = math.min(points - 2, math.max(0, ((beat - _climbFrom) / step).floor()));
      return climb(view, points - 2 - j);
    }
    if (beat < _home.$1) {
      final String token = trace.token(trace.inputAt(view.peptide, view.position));
      return "x0 = $token's token row + place ${view.position}'s row: both get its gradient";
    }
    if (beat < _totalFrom) {
      final double first = bosShare(view);
      return first > 0.5
          ? "Every place at once: ${percent(first)} of x0's gradient is at <bos>"
          : "Every place at once: each row's gradient at x0";
    }
    return total(view);
  }

  /// The climb into slot [k], through the part that made the slot under it.
  static String climb(LmView view, int k) {
    final TrainingTrace trace = view.trace;
    final int part = k + 1;
    final String focus = StreamTable.placeName(view, view.position);
    if (part > 2 * trace.model.layers) {
      return 'Back through the final LayerNorm, which divided $focus\'s row by '
          '${fixed(ForwardScene.evening(view).sd, 2)}';
    }
    final int block = (part - 1) ~/ 2 + 1;
    if (part.isEven) {
      return "Block $block's feed-forward: whole through the +, plus what it adds";
    }
    final int later = view.focus.inputs - 1 - view.position;
    return later == 0
        ? "Block $block's attention: no later place reads $focus, only its own cost"
        : "Block $block's attention: plus blame from ${grouped(later)} later places that read it";
  }

  /// The step's gradients' length against the clip.
  static String total(LmView view) {
    final TrainingTrace trace = view.trace;
    final double norm = trace.steps.gradNorm[view.step - 1];
    final double limit = trace.config.gradClip;
    final double clip = trace.steps.clip[view.step - 1];
    final String all = 'All ${grouped(trace.model.parameters)} gradients: length ${nats(norm)}';
    return clip < 1
        ? '$all, over the clip, ${limit.toStringAsFixed(1)}: each × ${fixed(clip, 2)}'
        : '$all, under the clip, ${limit.toStringAsFixed(1)}: none is scaled';
  }

  /// The two largest shares of the tokens but what came next, with their
  /// errors, those that write as anything; null where none does.
  static String? _largestOthers(LmView view) {
    final TrainingTrace trace = view.trace;
    final List<double> error = errors(view, view.position);
    final List<int> ranked = <int>[
      for (final int id in trace.allowed)
        if (id != view.target) id,
    ]..sort((int a, int b) => error[b] != error[a] ? error[b].compareTo(error[a]) : a.compareTo(b));
    final List<String> named = <String>[
      for (final int id in ranked.take(2))
        if (signedNumber(error[id]) != '0.00') '${trace.token(id)} ${signedNumber(error[id])}',
    ];
    return named.isEmpty ? null : named.join(', ');
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Backward pass, step ${view.step}. ${caption(view, frame)}.';
}

/// What Backward's last frame fades or leaves out, for the stage that opens
/// on it: the note, and the table of every place's gradient at x0. By
/// default, the frame as Backward draws it.
@immutable
final class BackwardFade {
  const BackwardFade({this.note = 1, this.table = 1});

  final double note;
  final double table;
}

/// Backward's canvas, on Loss's, which is on Predict's: the line alone and
/// the batch as Loss left them; the bench as Predict's, with the place's
/// last row standing at the left and its gradient's column beside it, the
/// errors where the logits were made; Forward's ladder; and the table, as
/// every stage of the stream has it.
final class BackwardLayout {
  BackwardLayout(this.size, LmView view) : loss = LossLayout(size, view) {
    final PredictLayout bench = loss.predict;
    gradientX = bench.inputX + bench.column + _columnGap + bench.numberWidth;
    double most = 0;
    for (final List<double> row in BackwardScene.ladder(view)) {
      for (final double v in row) {
        most = math.max(most, v.abs());
      }
    }
    ladderStyle = tower.styleFor(most);
  }

  final Size size;

  /// Loss's layout, which the stage opens on, and through it Predict's,
  /// Forward's ladder and the table.
  final LossLayout loss;

  PredictLayout get predict => loss.predict;

  TowerLayout get tower => loss.predict.tower;

  StreamTable get table => loss.table;

  /// From the last row's column to the gradient's numbers.
  static const double _columnGap = 3;

  /// The gradient's column: its middle.
  late final double gradientX;

  /// What the ladder's gradient numbers are written in, or null where they
  /// would be too small.
  late final TextStyle? ladderStyle;

  /// The gradient's column, through the bench's rows, and number [d]'s tile
  /// in it.
  Rect get gradientColumn => Rect.fromLTRB(
    gradientX - predict.column / 2,
    predict.benchTop,
    gradientX + predict.column / 2,
    predict.benchBottom,
  );

  Rect gradientTile(int d) {
    final int width = predict.width;
    final double h = (predict.benchBottom - predict.benchTop) / width;
    return Rect.fromLTWH(gradientX - predict.column / 2, predict.benchTop + d * h, predict.column, h);
  }

  /// A gradient's frame, in the loss's honey: what flows back.
  void frame(Canvas canvas, LmView view, Rect rect, double alpha) {
    if (alpha <= 0) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(1.5), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = view.inks.error.withValues(alpha: 0.8 * alpha),
    );
  }
}
