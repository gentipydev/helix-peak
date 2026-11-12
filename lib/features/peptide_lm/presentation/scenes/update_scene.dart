import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import '../lm_info_sheet.dart';
import 'backward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'predict_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';
import 'weight_flow.dart';

/// Update: Backward found how the cost changes with every row, but training
/// changes weights. A weight's gradient comes from the two ends of its
/// string: the error that came back to its end times the number that went in
/// at its start, at every place that used it, averaged.
///
/// The stage opens on Backward's last frame, every place's gradient at x0,
/// and goes back to the output layer's strings, from the place in focus's
/// last row to its p − y. One string is worked (insulin A's C11 at step 1:
/// S's from number 6, −0.99 × 1.94 = −1.92). Then the same weight at every
/// place, on the table, each place's pull on it, added over the batch and
/// ÷ 180; then every weight at once, the output layer's gradient, a cell a
/// weight; then every layer's gradients' length, and all of them together
/// against the clip. Then AdamW on the worked token's weights: their
/// gradients, AdamW's running mean of each and running size, their ratio,
/// times the rate, against the gradient, the weights before and after; then
/// every weight's step on the grid, and the layer after.
///
/// Every number is the run's: each place's p − y is Predict's shares less
/// what came next, its last row the stream's; the gradient and AdamW's
/// running averages are those the step's optimiser read, and the update the
/// one it made.
final class UpdateScene extends LmScene {
  const UpdateScene();

  static double get _beats => LmStage.update.beats.toDouble();

  // Every mini-step holds long enough for its caption and its note to be
  // read: a beat is two seconds.

  // A. Back to the output layer, the way Predict came to it: a wave runs
  // down Backward's table, each row's gradient dimming as its last row, what
  // the output layer read, comes in where it was, under the table's new tag;
  // the place in focus's row puts its numbers away and turns off the table
  // into the bench's left column, as Predict stood it, while the rest of the
  // table goes and its p − y comes in at the right with the plate; then the
  // column's numbers and its name, and the output layer's strings between
  // them, faint.
  static const (double, double) _rewrite = (0.15, 1.05);
  static const double _rowRewrite = 0.2;
  static const (double, double) _gradientsTagOut = (0.1, 0.35);
  static const (double, double) _rowsTagIn = (0.5, 0.75);
  static const (double, double) _rowNumbersOut = (1.15, 1.3);
  static const (double, double) _stand = (1.3, 2.0);
  static const (double, double) _tableOut = (1.3, 1.7);
  static const (double, double) _benchErrorsIn = (1.7, 2.3);
  static const (double, double) _benchIn = (2.0, 2.6);

  // B. One weight: the other strings dim, the worked one lights from its
  // start to its end, the numbers at its two ends written in its honey;
  // then its product written on it.
  static const double _oneFrom = 3.6;
  static const (double, double) _dim = (3.6, 4.0);
  static const (double, double) _lit = (3.7, 4.3);
  static const (double, double) _endsLit = (4.1, 4.4);
  static const double _productFrom = 5.8;
  static const (double, double) _productIn = (5.8, 6.2);

  // C. The same weight at every place: the bench goes the way it came, the
  // place's column lying back down into its row and every other place's
  // last row coming back round it; the other numbers dim, leaving the worked
  // number's column; the table narrows to that column; each place's p − y
  // at the worked token comes beside it, then the pulls, top to bottom; the
  // peptide's sum, then the six peptides' in a box; the mean.
  static const double _placesFrom = 8.0;
  static const (double, double) _benchOut = (8.0, 8.3);
  static const (double, double) _lieBack = (8.3, 8.9);
  static const (double, double) _outlineWiden = (8.9, 9.1);
  static const (double, double) _rowsIn = (8.8, 9.3);
  static const (double, double) _columnPicked = (9.3, 9.6);
  static const double _pullsFrom = 9.8;
  static const (double, double) _othersOut = (9.8, 10.1);
  static const (double, double) _narrow = (10.0, 10.4);
  static const (double, double) _errorsIn = (10.3, 10.7);
  static const (double, double) _pulls = (10.7, 11.5);
  static const double _sumsFrom = 11.8;
  static const (double, double) _peptideSum = (11.8, 12.1);
  static const (double, double) _boxIn = (12.0, 12.3);
  static const (double, double) _boxLines = (12.2, 13.2);
  static const double _meanFrom = 13.6;
  static const (double, double) _mean = (13.6, 13.9);

  // D. Every weight: the table goes and the grid comes on the bench's rows
  // as empty slots; the worked mean flies into its cell; the rest fill.
  static const double _gridFrom = 15.4;
  static const (double, double) _placesOut = (15.4, 15.8);
  static const (double, double) _gridIn = (15.6, 16.0);
  static const (double, double) _fly = (15.8, 16.3);
  static const (double, double) _cells = (16.3, 17.3);

  // E. Every layer: the grid shrinks into the output layer's row of a chart
  // of the run's groups, and the others come in; then their length all
  // together, against the clip.
  static const double _layersFrom = 18.4;
  static const (double, double) _shrink = (18.4, 19.1);
  static const (double, double) _groupsIn = (18.9, 20.0);
  static const double _clipFrom = 21.0;
  static const (double, double) _totalIn = (21.0, 21.8);
  static const (double, double) _clipLine = (21.4, 21.8);

  // F. AdamW on the worked token's weights: the chart goes, its output
  // layer's bar growing back into the grid, faint (E's shrink played back);
  // the token's row of it stands up as a column, the weights
  // beside it, a bar each; the bars move to the running mean, take a mark at
  // the running size, go to their ratio, then flip and scale to the step;
  // they condense into a column, and the weights go through it to after.
  static const double _adamFrom = 24.0;
  static const (double, double) _chartOut = (24.0, 24.4);
  static const (double, double) _gridBack = (24.0, 24.6);
  static const (double, double) _standUp = (24.6, 25.3);
  static const (double, double) _gridAway = (25.0, 25.4);
  static const (double, double) _weightsIn = (25.1, 25.5);
  static const (double, double) _barsIn = (25.3, 25.8);
  static const double _runningFrom = 26.0;
  static const (double, double) _toMean = (26.2, 27.0);
  static const double _sizeFrom = 28.0;
  static const (double, double) _marks = (28.2, 28.8);
  static const double _ratioFrom = 30.0;
  static const (double, double) _toRatio = (30.2, 31.0);
  static const double _rateFrom = 32.0;
  static const (double, double) _toStep = (32.2, 33.0);
  static const (double, double) _scheduleIn = (32.3, 32.8);
  static const double _afterFrom = 34.0;
  static const (double, double) _condense = (34.2, 34.8);
  static const (double, double) _slide = (34.8, 35.6);

  // G. Every weight: the columns go, the step lies down into its row of the
  // grid, and the grid shows every weight's step; then the weights after.
  static const double _stepsFrom = 36.0;
  static const (double, double) _adamOut = (36.0, 36.4);
  static const (double, double) _lieDown = (36.2, 36.9);
  static const (double, double) _gridSteps = (36.5, 37.0);
  static const double _layerFrom = 37.5;
  static const (double, double) _toAfter = (37.6, 38.2);

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// [a] to [b], [t] of the way.
  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats, const UpdateFade());

  /// The stage's last frame, with [fade] leaving out or fading what the stage
  /// after it draws itself.
  void paintEnd(Canvas canvas, Size size, LmView view, [UpdateFade fade = const UpdateFade()]) =>
      _paint(canvas, size, view, _beats, fade);

  void _paint(Canvas canvas, Size size, LmView view, double beat, UpdateFade fade) {
    if (beat <= 0) {
      const BackwardScene().paintEnd(canvas, size, view);
      return;
    }
    final UpdateLayout layout = UpdateLayout(size, view);
    layout.table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, BackwardScene.notes(view).last.$3), ...notes(view)],
      beat,
      alpha: fade.note,
    );
    _opening(canvas, view, layout, beat);
    _bench(canvas, view, layout, beat);
    _places(canvas, view, layout, beat);
    _grid(canvas, view, layout, beat, fade);
    _layers(canvas, view, layout, beat);
    _adam(canvas, view, layout, beat);
  }

  // ------------------------------------------------------------------ data

  /// [view] with [peptide] in focus, at its first place.
  static LmView _on(LmView view, int peptide) => peptide == view.peptide
      ? view
      : LmView(
          trace: view.trace,
          checkpoint: view.checkpoint,
          peptide: peptide,
          position: 0,
          inks: view.inks,
          kit: view.kit,
        );

  /// Place [i] of [peptide]'s last row, as Forward left it: what the output
  /// layer read there, number by number.
  static List<double> lastRow(LmView view, int peptide, int i) => <double>[
    for (int d = 0; d < view.trace.model.width; d++)
      view.trace.stream(view.checkpoint, view.trace.points.length - 1, peptide, i, d),
  ];

  /// The weight worked out: of the place in focus's strings, the one whose
  /// error at its end times the number at its start is the largest; its
  /// token and its number.
  static (int, int) worked(LmView view) => view.kit.memo<(int, int)>(
    ('update-worked', view.step, view.peptide, view.position),
    () {
      final List<double> error = BackwardScene.errors(view, view.position);
      final List<double> row = lastRow(view, view.peptide, view.position);
      (int, int) best = (view.target, 0);
      double most = -1;
      for (int r = 0; r < error.length; r++) {
        for (int d = 0; d < row.length; d++) {
          final double pull = (error[r] * row[d]).abs();
          if (pull > most) {
            most = pull;
            best = (r, d);
          }
        }
      }
      return best;
    },
  );

  /// The worked string's error, its number and their product, as written:
  /// the product from the written factors, so it reads right.
  static (String, String, String) workedProduct(LmView view) {
    final (int r, int d) = worked(view);
    final String error = BackwardScene.signedNumber(BackwardScene.errors(view, view.position)[r]);
    final String number = fixed(lastRow(view, view.peptide, view.position)[d], 2);
    return (error, number, BackwardScene.signedNumber(_parse(error) * _parse(number)));
  }

  /// Every place's pull on the worked weight, a list a peptide: its error at
  /// the weight's end times its last row's number at the weight's start,
  /// what that place's own cost asks of the weight.
  static List<List<double>> pulls(LmView view) => view.kit.memo<List<List<double>>>(
    ('update-pulls', view.step, view.peptide, view.position),
    () {
      final TrainingTrace trace = view.trace;
      final (int r, int d) = worked(view);
      final int last = trace.points.length - 1;
      return <List<double>>[
        for (int p = 0; p < trace.peptides.length; p++)
          <double>[
            for (int i = 0; i < trace.peptides[p].inputs; i++)
              BackwardScene.errors(_on(view, p), i)[r] * trace.stream(view.checkpoint, last, p, i, d),
          ],
      ];
    },
  );

  /// Place [i] of the peptide in focus's pull as its row writes it: its
  /// written error times its written number, so each row reads right.
  static String writtenPull(LmView view, int i) {
    final (int r, int d) = worked(view);
    final String error = BackwardScene.signedNumber(BackwardScene.errors(view, i)[r]);
    final String number = fixed(lastRow(view, view.peptide, i)[d], 2);
    return BackwardScene.signedNumber(_parse(error) * _parse(number));
  }

  /// A peptide's pulls added.
  static double peptideSum(LmView view, int peptide) =>
      pulls(view)[peptide].fold<double>(0, (double sum, double v) => sum + v);

  /// Every place's pull added, as written: to three places.
  static String totalWritten(LmView view) {
    double all = 0;
    for (int p = 0; p < view.trace.peptides.length; p++) {
      all += peptideSum(view, p);
    }
    return signed(all, 3);
  }

  /// The worked weight's gradient as written: the written total over the
  /// targets, so the division reads right; to four places.
  static String meanWritten(LmView view) => signed(_parse(totalWritten(view)) / view.trace.targetCount, 4);

  /// The largest pull of the batch on the worked weight: the scale its pulls
  /// are drawn on.
  static double pullScale(LmView view) {
    double most = 1e-9;
    for (final List<double> line in pulls(view)) {
      for (final double v in line) {
        most = math.max(most, v.abs());
      }
    }
    return most;
  }

  /// The places of the peptide in focus whose next token is the worked one.
  static List<int> nextAt(LmView view) {
    final (int r, _) = worked(view);
    return <int>[
      for (int i = 0; i < view.focus.inputs; i++)
        if (view.trace.targetAt(view.peptide, i) == r) i,
    ];
  }

  /// How many places of the whole batch had the worked token next.
  static int nextInBatch(LmView view) {
    final (int r, _) = worked(view);
    int count = 0;
    for (int p = 0; p < view.trace.peptides.length; p++) {
      for (int i = 0; i < view.trace.peptides[p].inputs; i++) {
        if (view.trace.targetAt(p, i) == r) {
          count += 1;
        }
      }
    }
    return count;
  }

  /// The colour scale of the output layer's gradient: the 99th percentile
  /// of its sizes.
  static double gradientScale(LmView view) => view.kit.memo<double>(
    ('update-gradient-scale', view.step),
    () => percentileScale(<double>[
      for (int r = 0; r < view.trace.vocab.length; r++)
        for (int d = 0; d < view.trace.model.width; d++) view.trace.headGrad(view.checkpoint, r, d),
    ]),
  );

  /// The output layer's largest gradient: its token, its number, its value.
  static (int, int, double) largestGradient(LmView view) {
    final TrainingTrace trace = view.trace;
    (int, int, double) best = (0, 0, 0);
    for (int r = 0; r < trace.vocab.length; r++) {
      for (int d = 0; d < trace.model.width; d++) {
        final double g = trace.headGrad(view.checkpoint, r, d);
        if (g.abs() > best.$3.abs()) {
          best = (r, d, g);
        }
      }
    }
    return best;
  }

  /// The smallest and largest gradient sizes of the weights into the tokens
  /// that can come next.
  static (double, double) gradientRange(LmView view) {
    final TrainingTrace trace = view.trace;
    double least = double.infinity;
    double most = 0;
    for (final int r in trace.allowed) {
      for (int d = 0; d < trace.model.width; d++) {
        final double g = trace.headGrad(view.checkpoint, r, d).abs();
        least = math.min(least, g);
        most = math.max(most, g);
      }
    }
    return (least, most);
  }

  /// The smallest and largest steps of the weights into the tokens that can
  /// come next.
  static (double, double) stepRange(LmView view) {
    final TrainingTrace trace = view.trace;
    double least = double.infinity;
    double most = 0;
    for (final int r in trace.allowed) {
      for (int d = 0; d < trace.model.width; d++) {
        final double s = trace.headUpdate(view.checkpoint, r, d).abs();
        least = math.min(least, s);
        most = math.max(most, s);
      }
    }
    return (least, most);
  }

  /// What AdamW makes of the weight from number [d] into token [r]: its
  /// running mean of the gradient and its running size, each brought up to
  /// date with this step's gradient and corrected for starting at zero;
  /// their ratio; and the step the rule makes of it, with the decay.
  static (double, double, double, double) adamOf(TrainingTrace trace, TraceCheckpoint at, int r, int d) {
    final TraceOptimizer adam = trace.optimizer;
    final int t = at.step;
    final double g = trace.headGrad(at, r, d);
    final double mean = (adam.beta1 * trace.headAdamMean(at, r, d) + (1 - adam.beta1) * g) /
        (1 - math.pow(adam.beta1, t));
    final double square = (adam.beta2 * trace.headAdamSquare(at, r, d) + (1 - adam.beta2) * g * g) /
        (1 - math.pow(adam.beta2, t));
    final double size = math.sqrt(square);
    final double ratio = mean / (size + adam.eps);
    final double rate = trace.steps.learningRate[t - 1];
    return (mean, size, ratio, -rate * (adam.weightDecay * trace.outputWeight(at, r, d) + ratio));
  }

  /// The worked token's row through AdamW.
  static AdamRow adam(LmView view) => view.kit.memo<AdamRow>(
    ('update-adam', view.step, view.peptide, view.position),
    () {
      final TrainingTrace trace = view.trace;
      final (int r, _) = worked(view);
      final List<double> gradient = <double>[];
      final List<double> mean = <double>[];
      final List<double> size = <double>[];
      final List<double> ratio = <double>[];
      final List<double> step = <double>[];
      final List<double> before = <double>[];
      final List<double> after = <double>[];
      for (int d = 0; d < trace.model.width; d++) {
        final (double m, double s, double q, _) = adamOf(trace, view.checkpoint, r, d);
        final double w = trace.outputWeight(view.checkpoint, r, d);
        final double moved = trace.headUpdate(view.checkpoint, r, d);
        gradient.add(trace.headGrad(view.checkpoint, r, d));
        mean.add(m);
        size.add(s);
        ratio.add(q);
        step.add(moved);
        before.add(w);
        after.add(w + moved);
      }
      return AdamRow(
        token: r,
        gradient: gradient,
        mean: mean,
        size: size,
        ratio: ratio,
        step: step,
        before: before,
        after: after,
      );
    },
  );

  /// Whether every ratio of the worked row is −1 or +1, the gradient's sign
  /// alone: AdamW with no past, as at step 1.
  static bool signsAlone(LmView view) {
    final AdamRow row = adam(view);
    for (int d = 0; d < row.ratio.length; d++) {
      if (row.gradient[d] != 0 && (row.ratio[d].abs() - 1).abs() >= 1e-3) {
        return false;
      }
    }
    return true;
  }

  /// The places a weight, its step and what it becomes are written to: the
  /// first figure of the row's largest step, and never fewer than four.
  static int stepDigits(LmView view) {
    final double most = adam(view).step.fold<double>(0, (double m, double v) => math.max(m, v.abs()));
    return most <= 0 ? 4 : math.max(4, -(math.log(most) / math.ln10).floor());
  }

  /// The places a gradient, its running mean and its running size are
  /// written to: three figures of the row's largest, and never fewer than
  /// four.
  static int gradientDigits(LmView view) {
    final AdamRow row = adam(view);
    double most = 0;
    for (int d = 0; d < row.gradient.length; d++) {
      most = math.max(most, math.max(row.gradient[d].abs(), math.max(row.mean[d].abs(), row.size[d])));
    }
    return most <= 0 ? 4 : math.max(4, 2 - (math.log(most) / math.ln10).floor());
  }

  /// A learning rate written plainly, to its first two figures: 0.0001,
  /// 0.0013, 0.000012.
  static String rate(double value) {
    if (value <= 0) {
      return '0';
    }
    final int digits = 1 - (math.log(value * (1 + 1e-6)) / math.ln10).floor();
    final String text = value.toStringAsFixed(math.max(0, digits));
    return text.contains('.') ? text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : text;
  }

  /// A group of the run's parameters as the page names it.
  static String groupName(String group) {
    if (group == 'token_embedding') {
      return 'token embedding';
    }
    if (group == 'position_embedding') {
      return 'position embedding';
    }
    if (group == 'final_norm') {
      return 'final LayerNorm';
    }
    if (group == 'head') {
      return 'output layer';
    }
    final int dot = group.indexOf('.');
    final String block = group.substring('block'.length, dot);
    final String part = switch (group.substring(dot + 1)) {
      'attention' => 'attention',
      'feed_forward' => 'feed-forward',
      'norms' => 'LayerNorms',
      final String other => other,
    };
    return "block $block's $part";
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

  /// A number as written, its true minus read back.
  static double _parse(String written) => double.parse(written.replaceAll('−', '-').replaceAll('+', ''));

  // ----------------------------------------------------------- the opening

  /// Backward's table, as it ends, turned to what the output layer read: a
  /// wave down it, each row's gradient dimming as its last row comes in
  /// where it was, the tag turning with it; then the place in focus's row
  /// turning off the table into the bench's left column, as Predict stood
  /// it, while the rest goes.
  void _opening(Canvas canvas, LmView view, UpdateLayout layout, double beat) {
    if (beat >= _stand.$2) {
      return;
    }
    final StreamTable table = layout.table;
    final PredictLayout bench = layout.bench;
    final int places = table.places;
    final double rest = 1 - _span(beat, _tableOut);
    final double numbersOut = _span(beat, _rowNumbersOut);
    final double gradientScale = BackwardScene.tableScale(view);
    table.drawTiles(canvas, alpha: rest, dx: -table.gutter);
    table.tag(canvas, BackwardScene.tableTag(view), 1 - _span(beat, _gradientsTagOut));
    table.tag(canvas, rowsTag(view), _span(beat, _rowsTagIn) * rest);
    for (int i = 0; i < places; i++) {
      final bool focus = i == view.position;
      if (focus && beat >= _stand.$1) {
        continue;
      }
      final (double gradient, double last) = rewritten(i, places, beat);
      // The gradient, as Backward wrote it, until the wave dims it.
      if (gradient > 0 && last <= 0) {
        table.drawRow(canvas, table.row(i), BackwardScene.gradient(view, 0, i), scale: gradientScale, fill: gradient, text: gradient);
      }
      final double filled = last * (focus ? 1 : rest);
      if (filled <= 0) {
        continue;
      }
      table.drawRow(
        canvas,
        table.row(i),
        lastRow(view, view.peptide, i),
        scale: bench.lastScale,
        fill: filled,
        text: filled * (focus ? 1 - numbersOut : 1),
      );
    }
    if (beat < _stand.$1) {
      // The place in focus's outline, as the table draws it, drawing in to
      // the row's own numbers while they go, where the turn takes it up.
      final Rect row = table.row(view.position);
      final Rect around = Rect.fromLTRB(
        table.layout.label(view.position).left - table.gutter - 3,
        row.top,
        row.right + 1,
        row.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.lerp(around, row.inflate(1), numbersOut)!, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: 0.85),
      );
      return;
    }
    table.strip(
      canvas,
      from: table.row(view.position),
      to: bench.inputColumn,
      f: _span(beat, _stand),
      colors: <Color>[for (final double v in bench.lastRow) view.inks.cell(v / bench.lastScale)],
      outlined: true,
    );
  }

  /// Place [i] of [places] as the wave down the table passes it at [beat]:
  /// how much of its gradient is left, and how far its last row has come,
  /// the one after the other, so a row never holds both.
  @visibleForTesting
  static (double, double) rewritten(int i, int places, double beat) {
    final double from = _rewrite.$1 + (_rewrite.$2 - _rewrite.$1 - _rowRewrite) * (places <= 1 ? 0 : i / (places - 1));
    final double turn = from + 0.4 * _rowRewrite;
    return (1 - through(beat, from, turn), through(beat, turn, from + _rowRewrite));
  }

  // ------------------------------------------------------------- the bench

  /// The output layer, as Backward left it before the climb: the place's last
  /// row standing at the left, its p − y where the logits were made, the
  /// strings between them, faint; the worked string lit and worked out.
  void _bench(Canvas canvas, LmView view, UpdateLayout layout, double beat) {
    if (beat < _benchErrorsIn.$1 || beat >= _lieBack.$1) {
      return;
    }
    final PredictLayout bench = layout.bench;
    final double shown = 1 - _span(beat, _benchOut);
    final double errors = _span(beat, _benchErrorsIn) * shown;
    // p − y and the plate come in while the place's row is still landing;
    // the strings, and the row's numbers and name, once it stands; all go
    // but the row's tiles, which lie back down into the table.
    final bool standing = beat >= _stand.$2;
    final double words = standing ? _span(beat, _benchIn) * shown : 0;
    // The worked string's two numbers, its start's and its end's, in its
    // honey once it has lit.
    final (int r, int d) = worked(view);
    final Color honey = Color.lerp(view.inks.ink, view.inks.error, _span(beat, _endsLit))!;
    _strings(canvas, view, layout, beat, words);
    if (standing) {
      BackwardScene.drawLastRow(canvas, view, bench, 1, words: words, inkOf: (int e) => e == d ? honey : null);
    }
    BackwardScene.drawErrors(
      canvas,
      view,
      bench,
      dx: 0,
      tiles: errors,
      shown: errors,
      written: (int k) => 1,
      inkOf: (int k) => k == r ? honey : null,
    );
    PredictScene.drawPlate(canvas, view, bench, errors);
    _product(canvas, view, layout, beat, words);
  }

  /// The output layer's strings, a weight each, faint in its weight's colour;
  /// dimmed while the worked one lights, in the loss's honey, from its start
  /// to its end.
  void _strings(Canvas canvas, LmView view, UpdateLayout layout, double beat, double alpha) {
    final TrainingTrace trace = view.trace;
    final PredictLayout bench = layout.bench;
    final int width = trace.model.width;
    final int count = trace.vocab.length;
    double weight(int token, int d) => trace.outputWeight(view.checkpoint, token, d);
    drawEdges(
      canvas,
      view,
      <(int, int, double)>[
        for (int token = 0; token < count; token++)
          for (int d = 0; d < width; d++) (d, token, weight(token, d)),
      ],
      (int d) => bench.inputTile(d).centerRight,
      (int token) => bench.logitTile(token, 0).centerLeft,
      alpha * WeightFlow.webStrength * (1 - 0.6 * _span(beat, _dim)),
      most: weightReach(count, width, weight),
    );
    final double lit = _span(beat, _lit);
    if (lit > 0) {
      final (int r, int d) = worked(view);
      final Offset from = bench.inputTile(d).centerRight;
      final Offset to = bench.logitTile(r, 0).centerLeft;
      canvas.drawLine(
        from,
        Offset.lerp(from, to, lit)!,
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = view.inks.error.withValues(alpha: alpha),
      );
    }
  }

  /// The worked string's product written on it, on a card.
  void _product(Canvas canvas, LmView view, UpdateLayout layout, double beat, double alpha) {
    final PredictLayout bench = layout.bench;
    final (int r, int d) = worked(view);
    final double written = _span(beat, _productIn) * alpha;
    if (written <= 0) {
      return;
    }
    final (String error, String number, String product) = workedProduct(view);
    final TextStyle mono = inked(view.kit.mono, 9, view.inks.ink, alpha: written);
    final TextStyle honey = inked(view.kit.mono, 9, view.inks.error, alpha: written);
    final String factors = '$error × $number = ';
    final double first = view.kit.layout(factors, mono).width;
    final double wide = first + view.kit.layout(product, honey).width;
    final double tall = view.kit.layout(factors, mono).height;
    final Offset from = bench.inputTile(d).centerRight;
    final Offset to = bench.logitTile(r, 0).centerLeft;
    final Offset middle = Offset.lerp(from, to, 0.5)!;
    final double left = (middle.dx - wide / 2 - 6).clamp(from.dx + 4, math.max(from.dx + 4, to.dx - wide - 16));
    final Rect card = Rect.fromLTWH(left, middle.dy - tall / 2 - 16, wide + 12, tall + 8);
    drawCard(canvas, view, card, written);
    view.kit.draw(canvas, factors, mono, Offset(card.left + 6, card.center.dy), anchor: const Offset(0, 0.5));
    view.kit.draw(canvas, product, honey, Offset(card.left + 6 + first, card.center.dy), anchor: const Offset(0, 0.5));
  }

  // ------------------------------------------------------------ the places

  /// The same weight at every place: the place's column lying back down
  /// into its row of the table, every other place's last row coming back
  /// round it; the other numbers dimming, leaving the worked number's
  /// column; the table narrowed to it, each place's p − y at the worked
  /// token beside it, and each place's pull; the peptide's sum under them;
  /// the six peptides' sums in a box, and the mean.
  void _places(Canvas canvas, LmView view, UpdateLayout layout, double beat) {
    if (beat < _lieBack.$1) {
      return;
    }
    final double alpha = 1 - _span(beat, _placesOut);
    if (alpha <= 0) {
      return;
    }
    final StreamTable table = layout.table;
    final PredictLayout bench = layout.bench;
    final int places = table.places;
    final (int r, int d) = worked(view);
    final double scale = bench.lastScale;
    final double lie = _span(beat, _lieBack);
    if (lie < 1) {
      table.strip(
        canvas,
        from: table.row(view.position),
        to: bench.inputColumn,
        f: 1 - lie,
        colors: <Color>[for (final double v in bench.lastRow) view.inks.cell(v / scale)],
        outlined: true,
      );
    }
    final double rows = _span(beat, _rowsIn) * alpha;
    final double landed = (lie >= 1 ? 1.0 : 0.0) * alpha;
    double rowShown(int i) => i == view.position ? landed : rows;
    final double others = 1 - _span(beat, _othersOut);
    final double kept = 1 - 0.65 * _span(beat, _columnPicked);
    final double narrow = _span(beat, _narrow);
    final double errorsShown = _span(beat, _errorsIn) * alpha;
    final TextStyle? style = table.layout.numberStyle;
    final double widen = _span(beat, _outlineWiden);

    table.tag(canvas, rowsTag(view), rows * others);
    for (int i = 0; i < places; i++) {
      drawToken(
        canvas,
        view,
        table.layout.label(i).shift(Offset(-table.gutter, 0)),
        view.trace.inputAt(view.peptide, i),
        alpha: i == view.position ? widen * alpha : rows,
      );
    }

    // Where the worked token came next, the row lit softly, as Predict lights
    // what came next.
    for (final int i in nextAt(view)) {
      final Rect row = table.row(i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(table.layout.label(i).left - table.gutter - 2, row.top, layout.column(2).right + 2, row.bottom),
          const Radius.circular(3),
        ),
        Paint()..color = view.inks.truth.withValues(alpha: PredictScene.answerLight * errorsShown),
      );
    }

    final List<double> line = pulls(view)[view.peptide];
    final double pullMost = pullScale(view);
    for (int i = 0; i < places; i++) {
      final List<double> h = lastRow(view, view.peptide, i);
      final double rowTop = table.row(i).top;
      final double shown = rowShown(i);
      // The place's own row writes its numbers again once it has landed.
      final double written = i == view.position ? shown * widen : shown;
      // Every other number of the row, dimming to leave the worked number's
      // column, until the table narrows.
      if (others > 0) {
        for (int k = 0; k < h.length; k++) {
          if (k != d) {
            final double a = shown * others * kept;
            layout.cellAt(canvas, view, layout.tableCell(i, k), view.inks.cell(h[k] / scale), fixed(h[k], 2), a, text: math.min(a, written));
          }
        }
      }
      // The worked number, sliding beside the tiles as the table narrows.
      final Rect from = layout.tableCell(i, d);
      final Rect to = layout.column(0).shift(Offset(0, rowTop - layout.column(0).top));
      layout.cellAt(canvas, view, Rect.lerp(from, to, narrow)!, view.inks.cell(h[d] / scale), fixed(h[d], 2), shown, text: written);
      // Its p − y at the worked token.
      if (errorsShown > 0) {
        final double e = BackwardScene.errors(view, i)[r];
        layout.cellAt(
          canvas,
          view,
          layout.column(1).shift(Offset(0, rowTop - layout.column(1).top)),
          view.inks.cell(e),
          BackwardScene.signedNumber(e),
          errorsShown,
        );
      }
      // Its pull, made top to bottom.
      final double made = _pullMade(i, places, beat) * alpha;
      if (made > 0) {
        final Rect cell = layout.column(2).shift(Offset(0, rowTop - layout.column(2).top));
        layout.cellAt(
          canvas,
          view,
          cell,
          view.inks.cell(line[i] / pullMost),
          writtenPull(view, i),
          made,
          ink: i == view.position ? view.inks.error : null,
        );
      }
    }
    // The place in focus's row, outlined from its tile to the columns' end,
    // once it has landed: from the row's own numbers, where the turn left
    // it, out to its tile.
    if (landed > 0) {
      final Rect row = table.row(view.position);
      final Rect around = Rect.fromLTRB(
        table.layout.label(view.position).left - table.gutter - 3,
        row.top,
        _lerp(row.right, layout.column(2).right, narrow) + 1,
        row.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.lerp(row.inflate(1), around, widen)!, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: 0.85 * landed),
      );
    }

    // The columns' names, once the table has narrowed, where the tag was.
    final double named = through(beat, _narrow.$2 - 0.1, _narrow.$2 + 0.2) * alpha;
    if (named > 0) {
      for (int k = 0; k < 3; k++) {
        final double shown = k == 0
            ? named
            : k == 1
            ? math.min(named, errorsShown)
            : math.min(named, _pullMade(0, places, beat));
        drawColumnTitle(canvas, view, layout.columnTitles[k], shown, x: layout.column(k).center.dx, top: table.layout.tableTop);
      }
    }

    // The peptide's pulls added, under its column.
    final double summed = _span(beat, _peptideSum) * alpha;
    if (summed > 0) {
      final Rect cell = layout.column(2).shift(Offset(0, table.row(places - 1).bottom + 3 - layout.column(2).top));
      canvas.drawLine(
        Offset(cell.left, cell.top - 1.5),
        Offset(cell.right, cell.top - 1.5),
        Paint()
          ..strokeWidth = 0.8
          ..color = view.inks.rule.withValues(alpha: summed),
      );
      view.kit.draw(
        canvas,
        signed(peptideSum(view, view.peptide), 2),
        inked(view.kit.mono, style?.fontSize ?? 8, view.inks.error, alpha: summed),
        Offset(cell.center.dx, cell.top + 1),
        anchor: const Offset(0.5, 0),
      );
      view.kit.draw(
        canvas,
        '${grouped(places)} places',
        inked(view.kit.sans, 8.5, view.inks.quiet, alpha: summed),
        Offset(cell.left - 6, cell.top + 1),
        anchor: const Offset(1, 0),
      );
    }

    _box(canvas, view, layout, beat, alpha);
  }

  /// How far place [i] of [places] has its pull made at [beat]: top to
  /// bottom over the pulls' turn.
  static double _pullMade(int i, int places, double beat) {
    final double from = _pulls.$1 + (_pulls.$2 - _pulls.$1 - 0.15) * (places <= 1 ? 0 : i / (places - 1));
    return through(beat, from, from + 0.15);
  }

  /// The batch's sums on a card at the right: each peptide's pulls added, a
  /// line each, the one in focus inked; all of them; the mean.
  void _box(Canvas canvas, LmView view, UpdateLayout layout, double beat, double alpha) {
    final double shown = _span(beat, _boxIn) * alpha;
    if (shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final Rect card = layout.box;
    drawCard(canvas, view, card, shown);
    final int peptides = trace.peptides.length;
    final double line = layout.boxLine;
    final double text = layout.boxText;
    final double left = card.left + 8;
    final double right = card.right - 8;
    double y = card.top + 5 + line / 2;
    final double each = (_boxLines.$2 - _boxLines.$1) / (peptides + 1);
    for (int p = 0; p < peptides; p++) {
      final double a = through(beat, _boxLines.$1 + each * p, _boxLines.$1 + each * (p + 1)) * shown;
      if (a > 0) {
        final Color ink = p == view.peptide ? view.inks.ink : view.inks.quiet;
        view.kit.draw(canvas, trace.peptides[p].source.label, inked(view.kit.sans, text, ink, alpha: a), Offset(left, y), anchor: const Offset(0, 0.5));
        view.kit.draw(canvas, signed(peptideSum(view, p), 2), inked(view.kit.mono, text, ink, alpha: a), Offset(right, y), anchor: const Offset(1, 0.5));
      }
      y += line;
    }
    final double all = through(beat, _boxLines.$2 - each, _boxLines.$2) * shown;
    if (all > 0) {
      canvas.drawLine(
        Offset(left, y - line / 2 + 1),
        Offset(right, y - line / 2 + 1),
        Paint()
          ..strokeWidth = 0.8
          ..color = view.inks.rule.withValues(alpha: all),
      );
      view.kit.draw(
        canvas,
        'all ${grouped(trace.targetCount)} places',
        inked(view.kit.sans, text, view.inks.ink, alpha: all),
        Offset(left, y),
        anchor: const Offset(0, 0.5),
      );
      view.kit.draw(canvas, totalWritten(view), inked(view.kit.mono, text, view.inks.ink, alpha: all), Offset(right, y), anchor: const Offset(1, 0.5));
    }
    y += line;
    final double mean = _span(beat, _mean) * shown;
    if (mean > 0) {
      view.kit.draw(
        canvas,
        '÷ ${grouped(trace.targetCount)}',
        inked(view.kit.sans, text, view.inks.ink, alpha: mean),
        Offset(left, y),
        anchor: const Offset(0, 0.5),
      );
      view.kit.draw(
        canvas,
        meanWritten(view),
        inked(view.kit.mono, text, view.inks.error, alpha: mean),
        Offset(right, y),
        anchor: const Offset(1, 0.5),
      );
    }
  }

  /// The table's tag while every place's last row shows.
  static String rowsTag(LmView view) => 'last rows · ${view.focus.inputs} × ${view.trace.model.width}';

  // -------------------------------------------------------------- the grid

  /// The output layer as a grid on the bench's rows, a slot a weight and in
  /// it a square, as Predict's map draws a share: its gradient, the worked
  /// mean flying into its cell and the rest growing in; shrinking into its
  /// row of the chart; grown back out of it, faint, while the worked row
  /// stands up; then every weight's step, and the weights after. The worked
  /// token's row is lit from when its mean lands, as Predict lights what
  /// came next.
  void _grid(Canvas canvas, LmView view, UpdateLayout layout, double beat, UpdateFade fade) {
    final int groups = view.trace.groups.length;
    final (int r, int d) = worked(view);
    final double lit = through(beat, _fly.$2 - 0.1, _fly.$2 + 0.2);
    if (beat >= _adamOut.$1) {
      // Gliding into the stage after's frame, the grid's tokens, numbers and
      // plate go first, then its squares shrink away, and last its slots.
      final Rect? to = fade.gridTo;
      final double glide = to == null ? 0 : fade.glide;
      final double shown = _span(beat, _gridSteps) * fade.grid * (1 - through(glide, 0.8, 1));
      final double after = _span(beat, _toAfter);
      // The worked row comes back as its step lands, lying down into it.
      final double landed = through(_span(beat, _lieDown), 0.65, 1);
      _drawGrid(
        canvas,
        view,
        layout,
        to == null ? layout.grid : Rect.lerp(layout.grid, to, glide)!,
        shown,
        value: (int k, int e) => _lerp(stepValue(view, k, e), afterValue(view, k, e), after),
        rowShown: (int k) => k == r ? landed : 1,
        lit: lit,
        grown: 1 - through(glide, 0, 0.6),
        status: after >= 0.5 ? ScoresScene.weightsStatus(view, after: true) : null,
        chrome: shown * (1 - through(glide, 0, 0.35)),
      );
      return;
    }
    if (beat >= _gridBack.$1) {
      // The output layer's bar grows back into the grid, faint, D's shrink
      // played back; the worked row's squares give way to it standing up.
      final double back = _span(beat, _gridBack);
      final double shown = 0.5 * back * (1 - _span(beat, _gridAway));
      final double stand = _span(beat, _standUp);
      _drawGrid(
        canvas,
        view,
        layout,
        Rect.lerp(layout.chartBar(groups - 1), layout.grid, back)!,
        shown,
        value: (int k, int e) => gradientValue(view, k, e),
        rowShown: (int k) => k == r ? 1 - through(stand, 0, 0.35) : 1,
        lit: lit,
        chrome: shown * through(back, 0.7, 1),
      );
      return;
    }
    if (beat < _gridIn.$1 || beat >= _shrink.$2) {
      return;
    }
    final double shrink = _span(beat, _shrink);
    _drawGrid(
      canvas,
      view,
      layout,
      Rect.lerp(layout.grid, layout.chartBar(groups - 1), shrink)!,
      _span(beat, _gridIn) * (1 - shrink),
      value: (int k, int e) => gradientValue(view, k, e),
      made: (int k, int e) => _cellMade(k, e, r, d, view.trace.vocab.length, beat),
      lit: lit,
      chrome: _span(beat, _gridIn) * (1 - through(beat, _shrink.$1, _shrink.$1 + 0.3)),
    );
    // The worked mean, flying from the box into its cell.
    final double fly = _span(beat, _fly);
    if (fly > 0 && fly < 1) {
      final Rect target = layout.gridCell(r, d);
      view.kit.draw(
        canvas,
        meanWritten(view),
        inked(view.kit.mono, 9, view.inks.error, alpha: 1 - 0.6 * fly),
        Offset.lerp(layout.meanAt, target.center, fly)!,
        anchor: const Offset(0.5, 0.5),
      );
    }
  }

  /// The grid in [rect] at [alpha]: a dark slot a weight, and in it a square
  /// whose area is the weight's [value] against its scale, −1 to 1, as a
  /// share's is in Predict's map, in its sign's colour ([squareColour]);
  /// each square [made] of the way, and every one [grown] of the way, as
  /// the grid goes into Loop's map; token rows as strong as [rowShown] says,
  /// where a row is drawn standing or lying elsewhere; the worked token's
  /// row [lit] of the way; the rows' tokens, the numbers' names, and the
  /// plate with its [status], at [chrome].
  void _drawGrid(
    Canvas canvas,
    LmView view,
    UpdateLayout layout,
    Rect rect,
    double alpha, {
    required double Function(int k, int e) value,
    double Function(int k, int e)? made,
    double Function(int k)? rowShown,
    double lit = 0,
    double grown = 1,
    String? status,
    double? chrome,
  }) {
    if (alpha <= 0) {
      return;
    }
    final double around = chrome ?? alpha;
    final TrainingTrace trace = view.trace;
    final PredictLayout bench = layout.bench;
    final int count = trace.vocab.length;
    final int width = trace.model.width;
    final int token = worked(view).$1;
    final double w = rect.width / width;
    final double h = rect.height / count;
    final Paint paint = Paint();
    for (int k = 0; k < count; k++) {
      final double row = alpha * (rowShown == null ? 1 : rowShown(k));
      if (row <= 0) {
        continue;
      }
      for (int e = 0; e < width; e++) {
        final RRect slot = PredictScene.slotOf(Rect.fromLTWH(rect.left + e * w, rect.top + k * h, w, h));
        PredictScene.drawSlot(canvas, view, slot, shown: row, lit: k == token ? lit : 0);
        final double v = value(k, e);
        final RRect square = gridSquare(slot, v, grown: grown * (made == null ? 1 : made(k, e)));
        if (math.min(square.width, square.height) < _leastSquare) {
          continue;
        }
        canvas.drawRRect(square, paint..color = squareColour(view, v).withValues(alpha: row));
      }
    }
    // The rows' tokens, the numbers' names and the plate stay where they
    // are, fading, while the cells move.
    if (around > 0) {
      for (int k = 0; k < count; k++) {
        drawToken(canvas, view, layout.gridTile(k), k, alpha: around);
      }
      final TextStyle face = inked(view.kit.mono, math.min(8, layout.gridCell(0, 0).width * 0.45), view.inks.quiet, alpha: around);
      for (int e = 0; e < width; e++) {
        view.kit.draw(canvas, '${e + 1}', face, Offset(layout.gridCell(0, e).center.dx, bench.benchTop - 3), anchor: const Offset(0.5, 1));
      }
      PredictScene.drawPlate(canvas, view, bench, around, status: status);
    }
  }

  /// The least a square is drawn, as Predict's map draws its least.
  static const double _leastSquare = 0.4;

  /// A weight's square in [slot]: its area in proportion to [value]'s size,
  /// −1 to 1, as a share's is in Predict's map, a weight at its scale taking
  /// [mostArea] of the slot and one at 0 none, so a grid of squares one size
  /// (Adam's steps at step 1) is still a field of squares, not a wall;
  /// [grown] of the way from nothing.
  static RRect gridSquare(RRect slot, double value, {double grown = 1}) =>
      PredictScene.fillOf(slot, value.abs() * mostArea, grown: grown);

  /// The most of its slot a weight's square takes.
  static const double mostArea = 0.5;

  /// A weight's square's colour: its sign's, the helix's denim below zero and
  /// its clay above, as soft as a table's tiles, so a grid of squares one
  /// size, Adam's steps at step 1, stays quiet.
  static Color squareColour(LmView view, double value) => view.inks.cell(value < 0 ? -1 : 1);

  /// Cell ([k], [e]) of the grid, against its scale, −1 to 1: the output
  /// layer's gradient; its step; the weight after it.
  static double gradientValue(LmView view, int k, int e) =>
      (view.trace.headGrad(view.checkpoint, k, e) / gradientScale(view)).clamp(-1.0, 1.0);

  static double stepValue(LmView view, int k, int e) =>
      (view.trace.headUpdate(view.checkpoint, k, e) / math.max(1e-12, stepRange(view).$2)).clamp(-1.0, 1.0);

  static double afterValue(LmView view, int k, int e) => ((view.trace.outputWeight(view.checkpoint, k, e) +
              view.trace.headUpdate(view.checkpoint, k, e)) /
          headScale(view))
      .clamp(-1.0, 1.0);

  /// How far cell ([k], [e]) has filled at [beat]: the worked cell as its
  /// mean lands, the others a row at a time, top to bottom.
  static double _cellMade(int k, int e, int r, int d, int count, double beat) {
    if (k == r && e == d) {
      return through(beat, _fly.$2 - 0.1, _fly.$2);
    }
    final double from = _cells.$1 + (_cells.$2 - _cells.$1 - 0.2) * (count <= 1 ? 0 : k / (count - 1));
    return through(beat, from, from + 0.2);
  }

  // ------------------------------------------------------------ the layers

  /// Every group of the run's weights, a row each in the model's order, with
  /// a bar of its gradients' length; then all of them together, against the
  /// clip.
  void _layers(Canvas canvas, LmView view, UpdateLayout layout, double beat) {
    if (beat < _shrink.$1) {
      return;
    }
    final double alpha = 1 - _span(beat, _chartOut);
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int groups = trace.groups.length;
    final double clip = trace.config.gradClip;
    final double norm = trace.steps.gradNorm[view.step - 1];
    for (int g = 0; g < groups; g++) {
      final bool output = g == groups - 1;
      // The output layer's row comes as the grid shrinks into its bar, and
      // goes as the grid grows back out of it.
      final double come = output
          ? through(beat, _shrink.$2 - 0.2, _shrink.$2) * (1 - through(beat, _gridBack.$1, _gridBack.$1 + 0.2))
          : _groupShown(g, groups, beat);
      final double shown = come * (output ? 1 : alpha);
      if (shown <= 0) {
        continue;
      }
      final double length = trace.groupGrad(view.step, g);
      _chartRow(
        canvas,
        view,
        layout,
        g,
        groupName(trace.groups[g]),
        trace.groupSizes[g],
        output ? length : length * come,
        nats(length),
        shown,
        ink: view.inks.error.withValues(alpha: 0.85),
      );
    }
    // All of them together, under a rule.
    final double all = _span(beat, _totalIn) * alpha;
    if (all > 0) {
      final Rect row = layout.chartRow(groups + 1);
      canvas.drawLine(
        Offset(layout.bench.left, row.top - 2),
        Offset(layout.bench.right, row.top - 2),
        Paint()
          ..strokeWidth = 0.8
          ..color = view.inks.rule.withValues(alpha: all),
      );
      _chartRow(canvas, view, layout, groups + 1, 'all', trace.model.parameters, norm * _span(beat, _totalIn), nats(norm), all, ink: view.inks.error, thick: 1.4, numberInk: view.inks.error);
    }
    // The clip, a dashed line across every row at its length.
    final double line = _span(beat, _clipLine) * alpha;
    if (line > 0) {
      final double x = layout.chartX(clip);
      final Rect first = layout.chartRow(0);
      final Rect last = layout.chartRow(groups + 1);
      dashedLine(
        canvas,
        Offset(x, first.top),
        Offset(x, last.bottom),
        Paint()
          ..strokeWidth = 1
          ..color = view.inks.ink.withValues(alpha: 0.7 * line),
      );
      view.kit.draw(
        canvas,
        'clip ${clip.toStringAsFixed(1)}',
        inked(view.kit.sans, 9, view.inks.ink, alpha: line),
        Offset(x, first.top - 3),
        anchor: const Offset(0.5, 1),
      );
    }
  }

  /// A row of the chart: its name and how many weights it holds, a bar
  /// [length] long in [ink], its [number] at the bar's end.
  void _chartRow(
    Canvas canvas,
    LmView view,
    UpdateLayout layout,
    int g,
    String name,
    int weights,
    double length,
    String number,
    double alpha, {
    required Color ink,
    double thick = 1,
    Color? numberInk,
  }) {
    final Rect row = layout.chartRow(g);
    final Size named = view.kit.draw(
      canvas,
      name,
      inked(view.kit.sans, 9, view.inks.ink, alpha: alpha),
      Offset(layout.bench.left, row.center.dy),
      anchor: const Offset(0, 0.5),
    );
    view.kit.draw(
      canvas,
      ' · ${grouped(weights)}',
      inked(view.kit.sans, 9, view.inks.quiet, alpha: alpha),
      Offset(layout.bench.left + named.width, row.center.dy),
      anchor: const Offset(0, 0.5),
    );
    final Rect bar = layout.chartBarOf(g, length, thick: thick);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(1.5)), Paint()..color = ink.withValues(alpha: ink.a * alpha));
    view.kit.draw(
      canvas,
      number,
      inked(view.kit.mono, 8.5, numberInk ?? view.inks.ink, alpha: alpha),
      Offset(bar.right + 4, row.center.dy),
      anchor: const Offset(0, 0.5),
    );
  }

  /// How far group [g] of [groups] has come in: one after another, the
  /// output layer's own from the grid.
  static double _groupShown(int g, int groups, double beat) {
    final double from = _groupsIn.$1 + (_groupsIn.$2 - _groupsIn.$1 - 0.25) * (groups <= 2 ? 0 : g / (groups - 2));
    return through(beat, from, from + 0.25);
  }

  // -------------------------------------------------------------- AdamW

  /// AdamW on the worked token's row of weights: the row standing up out of
  /// the grid as its gradients, the weights beside it, a bar each; the bars
  /// through the running mean, the running size and their ratio to the step;
  /// condensed into a column, the weights going through it to after; then
  /// the step lying back down into the grid.
  void _adam(Canvas canvas, LmView view, UpdateLayout layout, double beat) {
    if (beat < _standUp.$1 || beat >= _lieDown.$2) {
      return;
    }
    final StreamTable table = layout.table;
    final AdamRow row = adam(view);
    final int width = view.trace.model.width;
    final int d = worked(view).$2;
    final double alpha = 1 - _span(beat, _adamOut);
    final double gradientMost = layout.adamScale;
    final double stepMost = math.max(1e-12, row.step.fold<double>(0, (double m, double v) => math.max(m, v.abs())));
    final int stepPlaces = stepDigits(view);
    List<Color> cells(List<double> values, double scale) => <Color>[for (final double v in values) view.inks.cell(v / scale)];

    // The gradients, standing up out of the grid's row, taking over from its
    // squares as they lift; gone as the bars condense.
    final double stand = _span(beat, _standUp);
    final double gone = _span(beat, _condense);
    if (stand < 1) {
      table.strip(
        canvas,
        from: layout.gridRow(row.token),
        to: layout.adamColumn(layout.gradientX),
        f: stand,
        alpha: through(stand, 0, 0.35),
        colors: <Color>[
          for (int e = 0; e < width; e++)
            Color.lerp(
              squareColour(view, gradientValue(view, row.token, e)),
              view.inks.cell(row.gradient[e] / gradientMost),
              stand,
            )!,
        ],
      );
    } else {
      _column(
        canvas,
        view,
        layout,
        layout.gradientX,
        cells(row.gradient, gradientMost),
        row.gradient,
        gradientDigits(view),
        alpha * (1 - gone),
        title: 'gradient',
        worked: d,
      );
    }

    // The weights as the step found them, at the left.
    final double weights = _span(beat, _weightsIn) * alpha;
    _column(
      canvas,
      view,
      layout,
      layout.weightsX,
      cells(row.before, layout.weightScale),
      row.before,
      stepPlaces,
      weights,
      left: true,
      title: "${view.trace.token(row.token)}'s weights",
      worked: d,
    );

    // The chart: a bar a weight, through AdamW's rule.
    final double bars = _span(beat, _barsIn) * (1 - gone) * alpha;
    if (bars > 0) {
      _chart(canvas, view, layout, beat, bars);
    }

    // The steps, condensed into a column where the bars' zero was; lying back
    // down into the grid at the end.
    final double lying = _span(beat, _lieDown);
    final List<Color> steps = <Color>[for (final double v in row.step) view.inks.cell(v / stepMost)];
    if (gone > 0 && beat < _lieDown.$1) {
      _column(canvas, view, layout, layout.stepX, steps, row.step, stepPlaces, gone * alpha, title: 'step', signedNumbers: true, worked: d);
    } else if (beat >= _lieDown.$1) {
      // Lying back down, giving way to the row's squares as it lands.
      table.strip(
        canvas,
        from: layout.gridRow(row.token),
        to: layout.adamColumn(layout.stepX),
        f: 1 - lying,
        alpha: 1 - through(lying, 0.65, 1),
        colors: <Color>[
          for (int e = 0; e < width; e++) Color.lerp(steps[e], squareColour(view, stepValue(view, row.token, e)), lying)!,
        ],
      );
    }

    // A copy of the weights going through the steps to after.
    final double slide = _span(beat, _slide);
    if (slide > 0 && beat < _lieDown.$1) {
      final double turn = through(slide, 0.45, 0.6);
      final List<Color> moving = <Color>[
        for (int e = 0; e < width; e++)
          Color.lerp(view.inks.cell(row.before[e] / layout.weightScale), view.inks.cell(row.after[e] / layout.weightScale), turn)!,
      ];
      if (slide < 1) {
        final double x = _lerp(layout.weightsX, layout.afterX, slide);
        drawColumn(canvas, (int e) => layout.adamTile(x, e), <Color>[for (final Color c in moving) c.withValues(alpha: c.a * alpha)]);
      } else {
        _column(canvas, view, layout, layout.afterX, moving, row.after, stepPlaces, alpha, title: 'after', worked: d);
      }
    }

    drawSchedule(canvas, view, layout.schedule, _span(beat, _scheduleIn) * (1 - gone) * alpha, step: view.step.toDouble());
  }

  /// A standing column at [x], a tile a number in [colours], [numbers]
  /// written to [digits] places at its right, or its [left], the [worked]
  /// number's in honey; its [title] over it.
  void _column(
    Canvas canvas,
    LmView view,
    UpdateLayout layout,
    double x,
    List<Color> colours,
    List<double> numbers,
    int digits,
    double alpha, {
    bool left = false,
    String? title,
    bool signedNumbers = false,
    int? worked,
  }) {
    if (alpha <= 0) {
      return;
    }
    drawColumn(canvas, (int e) => layout.adamTile(x, e), <Color>[for (final Color c in colours) c.withValues(alpha: c.a * alpha)]);
    drawColumnNumbers(
      canvas,
      view,
      (int e) => layout.adamTile(x, e),
      numbers,
      alpha,
      textSize: layout.adamText,
      writes: layout.adamWrites,
      left: left,
      format: (double v) => signedNumbers && double.parse(v.abs().toStringAsFixed(digits)) != 0 ? signed(v, digits) : fixed(v, digits),
      inkOf: (int e) => e == worked ? view.inks.error : null,
    );
    if (title != null) {
      drawColumnTitle(canvas, view, title, alpha, x: x, top: layout.bench.benchTop);
    }
  }

  /// The bars, a weight each, from a dashed zero: its gradient; moving to
  /// its running mean; marked at its running size; each over its own size,
  /// its ratio; then times the rate against it, its step. Behind each, faint,
  /// where it stood before the move under way; the worked number's value at
  /// its bar's end.
  void _chart(Canvas canvas, LmView view, UpdateLayout layout, double beat, double alpha) {
    final AdamRow row = adam(view);
    final int width = row.gradient.length;
    final int d = worked(view).$2;
    final double zero = layout.chartZero;
    final double half = layout.chartHalf;
    final double gs = layout.adamScale;
    final double mean = _span(beat, _toMean);
    final double marks = _span(beat, _marks) * (1 - _span(beat, _toStep));
    final double ratio = _span(beat, _toRatio);
    final double step = _span(beat, _toStep);
    final double stepMost = math.max(1e-12, row.step.fold<double>(0, (double m, double v) => math.max(m, v.abs())));
    final double ratioMost = math.max(1, row.ratio.fold<double>(0, (double m, double v) => math.max(m, v.abs())));

    // The scale a number of the row is drawn on at the moment: the
    // gradients', each going over to its own size as the ratio comes.
    double scaleOf(int e) => gs + (math.max(1e-12, row.size[e]) * ratioMost - gs) * ratio;

    // Where a number of the row lies, as a share of the half width.
    double shareOf(int e) {
      final double before = (row.gradient[e] + (row.mean[e] - row.gradient[e]) * mean) / scaleOf(e);
      return before + (row.step[e] / stepMost - before) * step;
    }

    double tailOf(int e) => step > 0
        ? row.ratio[e] / ratioMost
        : ratio > 0
        ? row.mean[e] / gs
        : row.gradient[e] / gs;

    dashedLine(
      canvas,
      Offset(zero, layout.bench.benchTop - 2),
      Offset(zero, layout.bench.benchBottom + 2),
      Paint()
        ..strokeWidth = 1
        ..color = view.inks.quiet.withValues(alpha: alpha),
    );
    final bool moving = (mean > 0 && mean < 1) || (ratio > 0 && ratio < 1) || (step > 0 && step < 1);
    final Paint paint = Paint();
    for (int e = 0; e < width; e++) {
      final Rect tile = layout.adamTile(zero, e);
      final double thick = (tile.height * 0.5).clamp(1.0, 7.0);
      Rect bar(double share) => Rect.fromLTRB(
        math.min(zero, zero + share * half),
        tile.center.dy - thick / 2,
        math.max(zero, zero + share * half),
        tile.center.dy + thick / 2,
      );
      if (moving) {
        final double tail = tailOf(e);
        canvas.drawRect(bar(tail), paint..color = (tail >= 0 ? view.inks.positive : view.inks.negative).withValues(alpha: 0.22 * alpha));
      }
      final double share = shareOf(e);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar(share), const Radius.circular(1)),
        paint..color = (share >= 0 ? view.inks.positive : view.inks.negative).withValues(alpha: 0.9 * alpha),
      );
      // The running size: a tick as far as the bar would reach were this
      // step's mean as large as the weight's gradients have lately been.
      if (marks > 0) {
        final double x = zero + (row.mean[e] >= 0 ? 1 : -1) * row.size[e] / scaleOf(e) * half;
        canvas.drawLine(
          Offset(x, tile.center.dy - thick / 2 - 3),
          Offset(x, tile.center.dy + thick / 2 + 3),
          Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = view.inks.ink.withValues(alpha: 0.75 * marks * alpha),
        );
      }
    }

    // The worked number's value at its bar's end, as the move under way
    // leaves it.
    final int digits = gradientDigits(view);
    final String? value = step >= 1
        ? signed(row.step[d], stepDigits(view))
        : step > 0
        ? null
        : ratio >= 1
        ? signed(row.ratio[d], 2)
        : ratio > 0
        ? null
        : marks >= 1
        ? 'size ${fixed(row.size[d], digits)}'
        : mean >= 1
        ? signed(row.mean[d], digits)
        : mean > 0
        ? null
        : signed(row.gradient[d], digits);
    if (value != null) {
      final Rect tile = layout.adamTile(zero, d);
      final double share = shareOf(d);
      final double end = zero + share * half;
      final TextStyle honey = inked(view.kit.mono, math.min(8.5, layout.adamText + 0.5), view.inks.error, alpha: alpha);
      final double wide = view.kit.layout(value, honey).width;
      final double x = share >= 0 ? math.min(end + 4, layout.chartRight - wide) : math.max(end - 4 - wide, layout.chartLeft);
      drawCard(canvas, view, Rect.fromLTWH(x - 3, tile.top + 1, wide + 6, tile.height - 2), alpha);
      view.kit.draw(canvas, value, honey, Offset(x, tile.center.dy), anchor: const Offset(0, 0.5));
    }

    // The scale's ends, under the chart: the gradients', then the ratio's,
    // then the step's.
    final TextStyle face = inked(view.kit.mono, 8, view.inks.quiet, alpha: alpha);
    final String end = step >= 0.5 ? fixed(stepMost, stepDigits(view)) : ratio >= 0.5 ? fixed(ratioMost, 2) : fixed(gs, digits);
    final double y = layout.bench.benchBottom + 4;
    view.kit.draw(canvas, '0', face, Offset(zero, y), anchor: const Offset(0.5, 0));
    view.kit.draw(canvas, '−$end', face, Offset(zero - half, y), anchor: const Offset(0, 0));
    view.kit.draw(canvas, '+$end', face, Offset(zero + half, y), anchor: const Offset(1, 0));
  }

  /// The learning rate at every step, warm-up then cosine, in [area], small;
  /// [step] marked on it, on the line between two steps while it moves; named
  /// with its rate at the area's left where [named].
  static void drawSchedule(Canvas canvas, LmView view, Rect area, double alpha, {required double step, bool named = true}) {
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int count = trace.steps.count;
    double top = 0;
    for (int s = 0; s < count; s++) {
      top = math.max(top, trace.steps.learningRate[s]);
    }
    Offset at(int step) => Offset(
      area.left + area.width * (count <= 1 ? 0 : (step - 1) / (count - 1)),
      area.bottom - area.height * (trace.steps.learningRate[step - 1] / top),
    );
    final Path path = Path();
    for (int s = 1; s <= count; s++) {
      final Offset p = at(s);
      if (s == 1) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.quiet.withValues(alpha: alpha),
    );
    final int whole = step.round().clamp(1, count);
    final Offset mark = step == whole
        ? at(whole)
        : Offset.lerp(at(step.floor().clamp(1, count)), at(step.ceil().clamp(1, count)), step - step.floor())!;
    canvas.drawCircle(mark, 3.5, Paint()..color = view.inks.signal.withValues(alpha: alpha));
    if (!named) {
      return;
    }
    view.kit.draw(
      canvas,
      'rate ${rate(trace.steps.learningRate[whole - 1])}',
      inked(view.kit.mono, 8.5, view.inks.signal, alpha: alpha),
      Offset(area.left - 6, area.center.dy),
      anchor: const Offset(1, 0.5),
    );
  }

  // ------------------------------------------------------------------- taps

  /// While the table is up, Backward's and then every place's last row, a
  /// row of it puts its place in focus; so it does on the table of every
  /// place's last row later; once the row turns, and on the bench, the box,
  /// the grid, the chart and AdamW's columns, a tap asks for nothing.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final double beat = frame.local * _beats;
    if (beat < _stand.$1) {
      return hit(size, view, at);
    }
    if (beat >= _rowsIn.$2 && beat < _placesOut.$1) {
      if (beat >= _boxIn.$1 && UpdateLayout(size, view).box.inflate(4).contains(at)) {
        return null;
      }
      return hit(size, view, at);
    }
    return null;
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  // ---------------------------------------------------------------- caption

  /// Why each mini-step happens, over the canvas, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final String focus = StreamTable.placeName(view, view.position);
    final (int r, int d) = worked(view);
    final String token = trace.token(r);
    final (String error, String number, String product) = workedProduct(view);
    final int targets = trace.targetCount;
    final int width = trace.model.width;
    final double made = _parse(product);
    final List<int> next = nextAt(view);
    final TraceOptimizer stepper = trace.optimizer;
    final AdamRow row = adam(view);
    final (int largeToken, int largeNumber, double large) = largestGradient(view);
    final int biases = trace.vocab.length;
    int clipped = 0;
    int firstClipped = 0;
    int lastClipped = 0;
    for (int s = 0; s < trace.steps.count; s++) {
      if (trace.steps.clip[s] < 1) {
        clipped += 1;
        firstClipped = firstClipped == 0 ? s + 1 : firstClipped;
        lastClipped = s + 1;
      }
    }
    final (double least, double most) = gradientRange(view);
    final (double stepLeast, double stepMost) = stepRange(view);
    final int places = stepDigits(view);
    final int digits = gradientDigits(view);
    double rms = 0;
    for (final double w in row.before) {
      rms += w * w;
    }
    rms = math.sqrt(rms / row.before.length);
    final double rowLeast = row.gradient.fold<double>(double.infinity, (double m, double v) => math.min(m, v.abs()));
    final double rowMost = row.gradient.fold<double>(0, (double m, double v) => math.max(m, v.abs()));
    final double ratioLeast = row.ratio.fold<double>(double.infinity, math.min);
    final double ratioMost = row.ratio.fold<double>(-double.infinity, math.max);
    final double rowStep = row.step.fold<double>(0, (double m, double v) => math.max(m, v.abs()));
    final String nextWords = next.isEmpty
        ? '$token came next nowhere here: every p − y is its share.'
        : 'Where $token came next, p − y is its share less 1: '
              '${<String>[for (final int i in next.take(3)) BackwardScene.signedNumber(BackwardScene.errors(view, i)[r])].join(', ')}.';
    final int batchNext = nextInBatch(view);
    return <(double, double, String)>[
      (
        0.25,
        _oneFrom,
        'Backward found how the cost changes with every row.\n'
            'Training changes weights, not rows: each string here is one.\n'
            "A weight's gradient comes from the two ends of its string.",
      ),
      (
        _oneFrom,
        _productFrom,
        "The weight multiplies number ${d + 1} on its way into $token's logit.\n"
            "Nudge it up: $token's logit rises $number × the nudge,\n"
            "and $focus's cost $error × that.",
      ),
      (
        _productFrom,
        _placesFrom,
        '${made < 0 ? "Negative: raising this weight lowers $focus's cost." : made > 0 ? "Positive: lowering this weight lowers $focus's cost." : "About 0: $focus's cost asks nothing of it now."}\n'
            'But all ${grouped(targets)} places used this weight, each with its two ends.',
      ),
      (
        _placesFrom,
        _pullsFrom,
        "Every place's last row went through the same weights.\n"
            'This one multiplied number ${d + 1} of each of them.',
      ),
      (
        _pullsFrom,
        _sumsFrom,
        '$nextWords\n'
            "Elsewhere it is $token's own share, small: a light push.\n"
            "Each place's pull: its p − y × its number ${d + 1}.",
      ),
      (
        _sumsFrom,
        _meanFrom,
        'Every place of every peptide used this weight: all ${grouped(targets)} pull.\n'
            '${batchNext == 0 ? '$token came next nowhere: each pull is a light push.' : '${spelledLeading(batchNext)} of them had $token next: theirs are the big pulls.'}',
      ),
      (
        _meanFrom,
        _gridFrom,
        "The loss is the mean of the ${grouped(targets)} costs, so a weight's gradient\n"
            'is the mean of its ${grouped(targets)} pulls.',
      ),
      (
        _gridFrom,
        _layersFrom,
        "A row a token, a column one of the last rows' ${spelled(width)} numbers.\n"
            "Largest: ${trace.token(largeToken)}'s from number ${largeNumber + 1}, ${fixed(large, 3)}. Never-next rows: 0.\n"
            'With its ${grouped(biases)} biases, weights whose start is always 1: '
            '${grouped(trace.vocab.length * width + biases)}.',
      ),
      (
        _layersFrom,
        _clipFrom,
        'Each: the error reaching its end × the number at its start,\n'
            "averaged over the ${grouped(targets)} places. A bar is one group's length:\n"
            'the root of its gradients squared and summed.',
      ),
      (
        _clipFrom,
        _adamFrom,
        'Lengths add as squares: the total is the root of their squares.\n'
            'Over ${trace.config.gradClip.toStringAsFixed(1)}, every gradient would shrink by one factor: a guard.\n'
            '${clipped == 0 ? 'No step of the run went over it.' : "${spelledLeading(clipped)} of the run's ${grouped(trace.steps.count)} steps went over, between steps $firstClipped and $lastClipped."}',
      ),
      (
        _adamFrom,
        _runningFrom,
        'AdamW keeps two running averages for every weight:\n'
            'of its gradient, and of its gradient squared.\n'
            'Its step comes from the two, not from this gradient alone.',
      ),
      (
        _runningFrom,
        _sizeFrom,
        'The running mean: ${_share(stepper.beta1)} of the last one and ${_share(1 - stepper.beta1)} of this gradient,\n'
            'corrected for starting at zero: it smooths a jittery gradient.\n'
            '${view.step == 1 ? 'At step 1 there is no past: it is the gradient itself.' : 'After ${grouped(view.step - 1)} steps it holds every one, the latest most.'}',
      ),
      (
        _sizeFrom,
        _ratioFrom,
        'The running size: the root of the running mean of its square,\n'
            '${_share(stepper.beta2)} of the last and ${_share(1 - stepper.beta2)} of this one, corrected the same way.\n'
            "It says how large this weight's gradients have lately been.",
      ),
      (
        _ratioFrom,
        _rateFrom,
        'Over its own size, every weight steps about as far as the rest.\n'
            '${signsAlone(view) ? 'Here ${fixed(rowLeast, digits)} to ${fixed(rowMost, digits)}: every one ±1.' : 'Here ratios from ${signed(ratioLeast, 2)} to ${signed(ratioMost, 2)}: a sign that holds nears ±1.'}',
      ),
      (
        _rateFrom,
        _afterFrom,
        'The minus: each weight moves against its gradient, downhill.\n'
            'The rate climbs to ${rate(trace.config.learningRate)} over ${grouped(trace.config.warmupSteps)} steps, then falls on a cosine;\n'
            'decay also takes ${_share(stepper.weightDecay)} × the rate of each weight itself.',
      ),
      (
        _afterFrom,
        _stepsFrom,
        'One step moves a weight by a hair: ${fixed(rowStep, places)} at most.\n'
            'Weights are near ${fixed(rms, 2)}: it takes many steps to change a guess.',
      ),
      (
        _stepsFrom,
        _layerFrom,
        '${least > 0 ? 'The gradients ranged ${grouped((most / least).round())}×' : 'The gradients ranged widely'}'
            '${stepLeast >= 0.9 * stepMost ? "; Adam's steps hardly differ.\n" : ',\nAdam\'s steps from ${fixed(stepLeast, places)} to ${fixed(stepMost, places)}.\n'}'
            'Never-next rows have no gradient: decay alone moves them.',
      ),
      (
        _layerFrom,
        double.infinity,
        "Every layer's weights took the same kind of step at once.\n"
            'Next, Loop: this whole step, ${grouped(trace.steps.count)} times.',
      ),
    ];
  }

  /// A share as the notes write it: 0.9, 0.1, 0.999, 0.001.
  static String _share(double value) =>
      value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  @override
  String caption(LmView view, TrainingFrame frame) => _caption(view, frame.local * _beats);

  String _caption(LmView view, double beat) {
    final TrainingTrace trace = view.trace;
    final String focus = StreamTable.placeName(view, view.position);
    final (int r, int d) = worked(view);
    final String token = trace.token(r);
    final (String error, String number, String product) = workedProduct(view);
    final int targets = trace.targetCount;
    if (beat < _oneFrom) {
      return "Back to the output layer: $focus's row, its p − y and the "
          '${grouped(trace.vocab.length * trace.model.width)} weights';
    }
    if (beat < _productFrom) {
      return "One weight: $token's from number ${d + 1}, $focus's $number to its p − y, $error";
    }
    if (beat < _placesFrom) {
      return product == '0.00'
          ? 'Its gradient for $focus: $error × $number = 0.00: nothing left to learn'
          : 'Its gradient for $focus: $error at its end × $number at its start = $product';
    }
    if (beat < _pullsFrom) {
      return "The same weight at every place: number ${d + 1} of each place's last row";
    }
    if (beat < _sumsFrom) {
      final List<int> next = nextAt(view);
      if (next.isEmpty) {
        return "× each place's p − y at $token, its share: $token never came next here";
      }
      if (next.length > 2) {
        return "× each place's p − y at $token, near −1 at the ${grouped(next.length)} where $token came next";
      }
      final String named = <String>[
        for (final int i in next) '${BackwardScene.signedNumber(BackwardScene.errors(view, i)[r])} at ${StreamTable.placeName(view, i)}',
      ].join(', ');
      return '× each p − y at $token: $named, where $token came next';
    }
    if (beat < _meanFrom) {
      return "${_capital(view.focus.source.label)}'s ${grouped(view.focus.inputs)} pulls add to "
          '${signed(peptideSum(view, view.peptide), 2)}; all ${grouped(targets)}, to ${totalWritten(view)}';
    }
    if (beat < _gridFrom) {
      return "÷ ${grouped(targets)}, as the loss is their mean: ${meanWritten(view)}, this weight's gradient";
    }
    if (beat < _layersFrom) {
      return "Every weight the same way: the output layer's gradient, ${trace.vocab.length} × ${trace.model.width}";
    }
    if (beat < _clipFrom) {
      return "Every layer's weights get theirs the same way: ${grouped(trace.model.parameters)} gradients";
    }
    if (beat < _adamFrom) {
      return total(view);
    }
    final AdamRow row = adam(view);
    final int digits = gradientDigits(view);
    if (beat < _runningFrom) {
      return "AdamW turns each gradient into a step: $token's ${spelled(trace.model.width)} weights first";
    }
    if (beat < _sizeFrom) {
      return view.step == 1
          ? "Adam's running mean: at step 1, with no past, the gradient itself"
          : "Adam's running mean, past and present: ${signed(row.mean[d], digits)} at number ${d + 1}";
    }
    if (beat < _ratioFrom) {
      return view.step == 1
          ? 'Its running size, the root of its mean square: at step 1, its size'
          : 'Its running size, the root of its mean square: ${fixed(row.size[d], digits)} at number ${d + 1}';
    }
    if (beat < _rateFrom) {
      return signsAlone(view)
          ? '÷ its own size: at step ${grouped(view.step)}, every one −1 or +1, the sign alone'
          : '÷ its running size: their ratio, ${signed(row.ratio[d], 2)} at number ${d + 1}';
    }
    if (beat < _afterFrom) {
      final int warmup = trace.config.warmupSteps;
      final String phase = view.step <= warmup
          ? 'warm-up step ${grouped(view.step)} of ${grouped(warmup)}'
          : 'cosine step ${grouped(view.step)} of ${grouped(trace.steps.count)}';
      return '× −${rate(trace.steps.learningRate[view.step - 1])}, the rate at $phase: the step';
    }
    final int places = stepDigits(view);
    if (beat < _stepsFrom) {
      final String before = fixed(row.before[d], places);
      final String step = signed(row.step[d], places);
      final String after = fixed(_parse(before) + _parse(step), places);
      final String added = step.startsWith('−') ? '− ${step.substring(1)}' : '+ ${step.substring(1)}';
      return places <= 5
          ? "$token's weight from ${d + 1} + its step: $before $added = $after"
          : 'Number ${d + 1}: $before $added = $after';
    }
    if (beat < _layerFrom) {
      final (double least, double most) = stepRange(view);
      return least >= 0.9 * most
          ? "Every weight's step: ${fixed(most, places)} each at step ${grouped(view.step)}, whatever its gradient"
          : "Every weight's step: ${fixed(least, places)} to ${fixed(most, places)}, against its gradient";
    }
    return 'The output layer after one update; every layer moved the same way';
  }

  /// [text] with its first letter a capital, as a caption starts.
  static String _capital(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  @override
  String describe(LmView view, TrainingFrame frame) => 'Update, step ${view.step}. ${caption(view, frame)}.';

  /// Update's own page: what it takes and gives, which of its numbers the
  /// run was given, and which weights its decay shrinks, in the run's
  /// numbers.
  @override
  LmInfo info(LmView view) {
    final TrainingTrace trace = view.trace;
    final int parameters = trace.model.parameters;
    final bool decays = trace.config.weightDecay > 0;
    return LmInfo(
      title: LmStage.update.label,
      lead: 'Every weight gets its gradient and moves a step against it: the one stage that changes the model. '
          'The stages before it only used the weights; the next step starts from these.',
      sections: <LmInfoSection>[
        LmInfoSection('Rate', <String>[
          'The rate, its warm-up and its cosine, like the clip${decays ? ' and the decay' : ''}, are settings '
              "the run was given: only the model's ${grouped(parameters)} numbers are trainable.",
        ]),
        if (decays)
          LmInfoSection('Step', <String>[
            'Decay shrinks only the weight matrices, ${grouped(decayed(trace))} of the ${grouped(parameters)} '
                'numbers: never the embeddings, the biases or the LayerNorms.',
          ]),
      ],
    );
  }

  /// How many of the model's numbers AdamW's decay shrinks: the weight
  /// matrices alone, as the engine's `param_groups` sorts them: in every
  /// block the query, key and value's, the output's and the feed-forward's
  /// two, and the output layer's.
  static int decayed(TrainingTrace trace) {
    final TraceModel model = trace.model;
    final int width = model.width;
    return model.layers * (4 * width * width + 2 * model.feedForward * width) + trace.vocab.length * width;
  }
}

/// What the worked token's row of weights is through AdamW: each number's
/// gradient, its running mean and running size as the step brought them up
/// to date, corrected for starting at zero, their ratio, the step the run
/// took, and the weight before and after it.
@immutable
final class AdamRow {
  const AdamRow({
    required this.token,
    required this.gradient,
    required this.mean,
    required this.size,
    required this.ratio,
    required this.step,
    required this.before,
    required this.after,
  });

  final int token;
  final List<double> gradient;
  final List<double> mean;
  final List<double> size;
  final List<double> ratio;
  final List<double> step;
  final List<double> before;
  final List<double> after;
}

/// What Update's last frame fades, for the stage that opens on it: the note,
/// and the grid of the weights after, which can [glide] into [gridTo], its
/// squares going as it goes. By default, the frame as Update draws it.
@immutable
final class UpdateFade {
  const UpdateFade({this.note = 1, this.grid = 1, this.glide = 0, this.gridTo});

  final double note;
  final double grid;
  final double glide;
  final Rect? gridTo;
}

/// Update's canvas, on Backward's, which is on Predict's and the table's:
/// the bench; the table narrowed to three columns, and the batch's box at
/// its right; the grid on the bench's rows; the chart of the run's groups;
/// AdamW's columns and its chart.
final class UpdateLayout {
  UpdateLayout(this.size, LmView view) : backward = BackwardLayout(size, view), _view = view {
    final TrainingTrace trace = view.trace;
    final PredictLayout predict = backward.predict;
    _cellsLeft = backward.table.layout.cellsLeft;
    _cell = backward.table.layout.cell;
    // The narrowed table's three columns, as far apart as their names need.
    final (int r, int d) = UpdateScene.worked(view);
    columnTitles = <String>['number ${d + 1}', '× p − y at ${trace.token(r)}', '= pull'];
    final TextStyle titleStyle = inked(view.kit.sans, 9, view.inks.quiet);
    final List<double> titles = <double>[for (final String t in columnTitles) view.kit.layout(t, titleStyle).width];
    double step = _cell + 8;
    for (int k = 0; k < 2; k++) {
      step = math.max(step, titles[k] / 2 + titles[k + 1] / 2 + 8);
    }
    _columnStep = step;
    // The box at the table's right, its words as large as the room left
    // allows, up to 9 points.
    final TextStyle label = inked(view.kit.sans, 9, view.inks.quiet);
    final TextStyle mono = inked(view.kit.mono, 9, view.inks.ink);
    double names = view.kit.layout('all ${grouped(trace.targetCount)} places', label).width;
    for (final TracePeptide p in trace.peptides) {
      names = math.max(names, view.kit.layout(p.source.label, label).width);
    }
    final double numbers = view.kit.layout('−8.8888', mono).width;
    final double room = predict.right - column(2).right - 14;
    final double shrink = ((room - 30) / (names + numbers)).clamp(0.6, 1.0);
    boxText = (9 * shrink * 2).floorToDouble() / 2;
    boxLine = math.max(11.0, 15 * shrink);
    final double wide = math.min(room, (names + numbers) * boxText / 9 + 30);
    box = Rect.fromLTWH(
      predict.right - wide,
      backward.table.layout.tableTop,
      wide,
      boxLine * (trace.peptides.length + 2) + 10,
    );
    meanAt = Offset(
      box.right - 8 - numbers * boxText / 9 / 2,
      box.top + 5 + boxLine * (trace.peptides.length + 1) + boxLine / 2,
    );

    // The grid on the bench's rows, a row a token: square cells as tall as
    // a row where the width allows, each token's tile right beside its row,
    // the whole centred on the bench.
    final int columns = trace.model.width;
    final double side = math.min(predict.pitch, (predict.right - predict.left - _tileGap - predict.chipSide) / columns);
    final double block = side * columns + _tileGap + predict.chipSide;
    grid = Rect.fromLTWH(
      (predict.left + predict.right) / 2 - block / 2,
      predict.benchTop,
      side * columns,
      predict.benchBottom - predict.benchTop,
    );

    // The chart: a row a group, a gap, and all of them.
    final int groups = trace.groups.length;
    _chartPitch = math.min(22.0, (predict.benchBottom - predict.benchTop) / (groups + 2));
    _chartTop = predict.benchTop + (predict.benchBottom - predict.benchTop - _chartPitch * (groups + 2)) / 2;
    final TextStyle name = inked(view.kit.sans, 9, view.inks.ink);
    double widest = view.kit.layout('all · ${grouped(trace.model.parameters)}', name).width;
    for (int g = 0; g < groups; g++) {
      widest = math.max(
        widest,
        view.kit.layout('${UpdateScene.groupName(trace.groups[g])} · ${grouped(trace.groupSizes[g])}', name).width,
      );
    }
    _barsLeft = predict.left + widest + 10;
    _barsRight = predict.right - view.kit.layout('8.888', inked(view.kit.mono, 8.5, view.inks.ink)).width - 8;
    double top = trace.config.gradClip * 1.15;
    for (int g = 0; g < groups; g++) {
      top = math.max(top, trace.groupGrad(view.step, g) * 1.05);
    }
    _chartReach = math.max(top, trace.steps.gradNorm[view.step - 1] * 1.05);

    // AdamW's columns: the weights at the left, their numbers left of them;
    // the gradients, their numbers right of them; the chart; after at the
    // right.
    adamText = math.min(9.0, (predict.benchBottom - predict.benchTop) / trace.model.width * 0.62);
    adamWrites = adamText >= 5.5;
    final TextStyle face = inked(view.kit.mono, adamText, view.inks.ink);
    final int steps = UpdateScene.stepDigits(view);
    final int grads = UpdateScene.gradientDigits(view);
    final AdamRow row = UpdateScene.adam(view);
    double widestOf(List<double> values, int digits) {
      double most = 0;
      for (final double v in values) {
        most = math.max(most, view.kit.layout(signed(v, digits), face).width);
      }
      return adamWrites ? most + 4 : 0;
    }

    final double standing = predict.column;
    final TextStyle titled = inked(view.kit.sans, 9, view.inks.quiet);
    final double named = view.kit.layout("${trace.token(r)}'s weights", titled).width / 2 +
        view.kit.layout('gradient', titled).width / 2 +
        8;
    weightsX = math.max(predict.left + widestOf(row.before, steps) + standing / 2, predict.left + view.kit.layout("${trace.token(r)}'s weights", titled).width / 2);
    gradientX = weightsX + math.max(standing + 10, named);
    chartLeft = gradientX + standing / 2 + widestOf(<double>[...row.gradient, ...row.mean], grads) + 10;
    afterX = predict.right - widestOf(row.after, steps) - standing / 2;
    chartRight = afterX - standing / 2 - 10;
    chartZero = (chartLeft + chartRight) / 2;
    chartHalf = (chartRight - chartLeft) / 2;
    stepX = chartZero;
    double gs = 1e-12;
    for (int e = 0; e < row.gradient.length; e++) {
      gs = math.max(gs, math.max(row.gradient[e].abs(), math.max(row.mean[e].abs(), row.size[e])));
    }
    adamScale = gs;
    double ws = 1e-9;
    for (int e = 0; e < row.before.length; e++) {
      ws = math.max(ws, math.max(row.before[e].abs(), row.after[e].abs()));
    }
    weightScale = ws;
    schedule = Rect.fromLTWH(chartLeft + 64, predict.benchBottom + 16, math.max(20, chartRight - chartLeft - 64), 16);
  }

  final Size size;
  final BackwardLayout backward;
  final LmView _view;

  PredictLayout get bench => backward.predict;

  StreamTable get table => backward.table;

  late final double _cellsLeft;
  late final double _cell;
  late final double _columnStep;

  /// The narrowed table's columns' names.
  late final List<String> columnTitles;

  /// The batch's box, and where its mean is written.
  late final Rect box;
  late final Offset meanAt;

  /// The box's words' size, and a line of it.
  late final double boxText;
  late final double boxLine;

  /// The output layer as a grid on the bench's rows.
  late final Rect grid;

  /// From the grid's last column to the tiles naming its rows.
  static const double _tileGap = 4;

  late final double _chartPitch;
  late final double _chartTop;
  late final double _barsLeft;
  late final double _barsRight;
  late final double _chartReach;

  /// AdamW's numbers' size, and whether they are written; its columns, the
  /// chart between them, its zero and half width; and the scales its bars
  /// and tiles are drawn on.
  late final double adamText;
  late final bool adamWrites;
  late final double weightsX;
  late final double gradientX;
  late final double stepX;
  late final double afterX;
  late final double chartLeft;
  late final double chartRight;
  late final double chartZero;
  late final double chartHalf;
  late final double adamScale;
  late final double weightScale;

  /// The rate's schedule, small, under the chart.
  late final Rect schedule;

  /// Place [i]'s number [k] on the table.
  Rect tableCell(int i, int k) {
    final Rect row = table.row(i);
    return Rect.fromLTWH(_cellsLeft + k * _cell, row.top, _cell, row.height);
  }

  /// The narrowed table's column [k], at its first row.
  Rect column(int k) {
    final Rect row = table.row(0);
    return Rect.fromLTWH(_cellsLeft + k * _columnStep, row.top, _cell, row.height);
  }

  /// A number on a soft tile, written in the table's face where it fits,
  /// at [text] where it comes or goes apart from its tile, in [ink] where
  /// it is the worked weight's.
  void cellAt(Canvas canvas, LmView view, Rect cell, Color colour, String number, double alpha, {double? text, Color? ink}) {
    if (alpha <= 0) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(cell.deflate(1), const Radius.circular(3)),
      Paint()..color = Color.lerp(view.inks.ground, colour, alpha)!,
    );
    final TextStyle? style = table.layout.numberStyle;
    final double written = text ?? alpha;
    if (style != null && written > 0) {
      view.kit.draw(
        canvas,
        number,
        style.copyWith(color: (ink ?? style.color!).withValues(alpha: (written * 8).round() / 8)),
        cell.center,
        anchor: const Offset(0.5, 0.5),
      );
    }
  }

  /// The grid's cell for token [k]'s weight from number [e], and token [k]'s
  /// row of it.
  Rect gridCell(int k, int e) {
    final double w = grid.width / _view.trace.model.width;
    final double h = grid.height / _view.trace.vocab.length;
    return Rect.fromLTWH(grid.left + e * w, grid.top + k * h, w, h);
  }

  Rect gridRow(int k) {
    final double h = grid.height / _view.trace.vocab.length;
    return Rect.fromLTWH(grid.left, grid.top + k * h, grid.width, h);
  }

  /// The tile naming token [k]'s row of the grid, right beside it.
  Rect gridTile(int k) {
    final Rect row = gridRow(k);
    final double side = bench.chipSide;
    return Rect.fromLTWH(grid.right + _tileGap, row.center.dy - side / 2, side, side);
  }

  /// The chart's row [g]: a group's, the gap after the last, then all.
  Rect chartRow(int g) => Rect.fromLTWH(bench.left, _chartTop + g * _chartPitch, bench.right - bench.left, _chartPitch);

  /// Where [value] lies along the chart's bars.
  double chartX(double value) => _barsLeft + (_barsRight - _barsLeft) * (value / _chartReach).clamp(0.0, 1.0);

  /// Group [g]'s bar, [value] long; [thick] times a bar's own thickness.
  Rect chartBarOf(int g, double value, {double thick = 1}) {
    final Rect row = chartRow(g);
    final double h = (row.height * 0.42 * thick).clamp(2.0, 10.0);
    return Rect.fromLTRB(_barsLeft, row.center.dy - h / 2, math.max(_barsLeft + 1, chartX(value)), row.center.dy + h / 2);
  }

  /// Group [g]'s bar, as long as its gradients' length.
  Rect chartBar(int g) => chartBarOf(g, _view.trace.groupGrad(_view.step, g));

  /// A standing column of AdamW's at [x], and its tile [e].
  Rect adamColumn(double x) => Rect.fromLTRB(x - bench.column / 2, bench.benchTop, x + bench.column / 2, bench.benchBottom);

  Rect adamTile(double x, int e) {
    final double h = (bench.benchBottom - bench.benchTop) / _view.trace.model.width;
    return Rect.fromLTWH(x - bench.column / 2, bench.benchTop + e * h, bench.column, h);
  }
}
