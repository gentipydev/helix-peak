import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import '../lm_info_sheet.dart';
import 'attention_scene.dart';
import 'forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'loss_scene.dart';
import 'predict_scene.dart';
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
/// numbers made from every token's error times its weight. Then the place's
/// gradient lies down into Forward's ladder and climbs it,
/// through the final LayerNorm, then each part from the last: every + passes
/// it up whole, and each part adds what it sends back, on a strip between the
/// rungs. At x0 it goes on to the two embedding rows that made x0, and every
/// place's x0 gradient comes in, a row a place, on the table.
///
/// Every number is the run's: the shares are Predict's, softmax of the whole
/// logits; the gradient at each point is the one the run kept, whole, at
/// every place. The loss is the mean over the targets, so the run's numbers
/// are drawn times their count: what each place's own cost sends back, the
/// sum of the costs' gradients; the mean, divided again, is said once every
/// place has climbed.
final class BackwardScene extends LmScene {
  const BackwardScene();

  static double get _beats => LmStage.backward.beats.toDouble();

  // Every mini-step holds long enough for its caption and its note to be
  // read: a beat is two seconds.

  // A. Back to the place in focus: the batch's other lines, its card, the
  // mean's line and the legend go as the line in focus goes back out of the
  // batch to stand alone, its cost over its bar; then it goes, and its
  // target flies to its row of the shares, which come in.
  static const (double, double) _othersOut = (0.2, 0.7);
  static const (double, double) _back = (0.5, 1.7);
  static const double _alone = 2.5;
  static const (double, double) _lineOut = (5.0, 5.4);
  static const (double, double) _fly = (5.0, 5.7);
  static const (double, double) _barsIn = (5.2, 5.8);
  static const double _guess = 5.8;

  // B. p − y, a reading at a time: the answer key y, outlined on the
  // target's row; what the target lacks of it; what every other token took;
  // the two adding to nothing. Then the bars condense into a column where the
  // logits were made, which slides back to where Predict made them.
  static const double _keyFrom = 8.0;
  static const (double, double) _keyIn = (8.1, 8.6);
  static const double _lackFrom = 10.0;
  static const (double, double) _lack = (10.2, 10.9);
  static const double _excessFrom = 12.5;
  static const (double, double) _excess = (12.7, 13.4);
  static const double _sumFrom = 14.5;
  static const (double, double) _condense = (16.5, 17.2);

  // C. Back through the output layer: the place's last row stands at the
  // left with empty slots for its gradient beside it; the errors run back
  // along the strings, the largest number of the gradient alone and slowly,
  // worked out beside its strings, then the rest in one cascade; then the
  // gradient read, its most negative and most positive numbers ringed.
  static const (double, double) _columnsIn = (17.2, 17.8);
  static const double _firstFrom = 19.0;
  static const WeightFlow _flow = WeightFlow(
    alone: <(double, double)>[(19.2, 20.4)],
    cascade: (22.2, 23.6),
    webOut: (26.5, 26.9),
    firstRelax: 0.6,
  );
  static const (double, double) _worked = (20.2, 20.6);
  static const double _othersFrom = 22.0;
  static const double _readFrom = 24.5;

  // D. The climb: the bench clears, the gradient lies down into the ladder's
  // last slot as the route comes in; then a part at a time from the last,
  // one number of it worked out at each +.
  static const (double, double) _benchOut = (26.5, 26.9);
  static const (double, double) _lieDown = (26.6, 27.3);
  static const (double, double) _routeIn = (26.8, 27.3);
  static const double _climbFrom = 28.5;
  static const double _climbTo = 39.0;

  /// The longest a part's motion takes on the climb; the rest of its turn
  /// holds for its caption and note.
  static const double _mostRise = 1.1;

  // E. Every place: the ladder goes, the place's x0 gradient goes home to its
  // row of the table, and every other place's comes in, to the stage's end:
  // all the gradients' length against the clip is Update's, once every
  // weight has its gradient.
  static const (double, double) _ladderOut = (41.0, 41.5);
  static const (double, double) _home = (41.0, 41.8);
  static const (double, double) _othersIn = (41.3, 41.9);

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
  /// strings into them.
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
        // The lit row is the answer key, y: the room the target's bar would
        // fill were the guess right and sure. It brightens while y is read,
        // and settles as what the target lacks fills it.
        final double key = _span(beat, _keyIn) * (1 - lack);
        canvas.drawRRect(
          RRect.fromRectAndRadius(band, const Radius.circular(3)),
          Paint()..color = view.inks.truth.withValues(alpha: PredictScene.answerLight * (1 + _keyLight * key) * bars),
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

    _legend(canvas, view, bench, beat, bars);

    // The column of errors, where the logits were made.
    final double lackWritten = through(beat, _lack.$2 - 0.2, _lack.$2);
    final double excessWritten = through(beat, _excess.$2 - 0.2, _excess.$2);
    drawErrors(
      canvas,
      view,
      bench,
      dx: dx,
      tiles: shown * condense,
      shown: shown,
      written: (int r) => r == target ? lackWritten : excessWritten,
      chipShown: (int r) => r != target || landed,
    );

    _columns(canvas, view, layout, beat, gone);
    _strings(canvas, view, layout, beat, gone);
  }

  /// The column of errors where the logits were made, [dx] along: each
  /// token's tile, its p − y written beside it (each [written] of the way,
  /// never at the two that never come next, in the ink or as [inkOf] names
  /// another), its chip where [chipShown] says; the two that never come next
  /// struck. The tiles and the column's name at [tiles], the numbers and
  /// chips at [shown].
  static void drawErrors(
    Canvas canvas,
    LmView view,
    PredictLayout bench, {
    required double dx,
    required double tiles,
    required double shown,
    required double Function(int r) written,
    bool Function(int r)? chipShown,
    Color? Function(int r)? inkOf,
  }) {
    final TrainingTrace trace = view.trace;
    final List<double> error = errors(view, view.position);
    drawColumn(canvas, (int r) => bench.logitTile(r, dx), <Color>[
      for (int r = 0; r < trace.vocab.length; r++)
        trace.allowedIndex(r) < 0 ? Colors.transparent : view.inks.signed(error[r]).withValues(alpha: tiles),
    ]);
    drawColumnNumbers(
      canvas,
      view,
      (int r) => bench.logitTile(r, dx),
      error,
      shown,
      textSize: bench.textSize,
      writes: bench.writes,
      alphaOf: (int r) => trace.allowedIndex(r) < 0 ? 0 : written(r),
      format: signedNumber,
      inkOf: inkOf,
    );
    for (int r = 0; r < trace.vocab.length; r++) {
      final Rect tile = bench.logitTile(r, dx);
      if (trace.allowedIndex(r) < 0 && tiles > 0) {
        AttentionScene.hatch(
          canvas,
          view,
          Rect.fromLTRB(tile.left - 2, tile.top + 0.5, bench.chip(r, dx).right + 2, tile.bottom - 0.5),
          tiles,
        );
      }
      if (chipShown == null || chipShown(r)) {
        drawToken(canvas, view, bench.chip(r, dx), r, alpha: shown);
      }
    }
    drawColumnTitle(canvas, view, errorTitle, tiles, x: bench.logitX + dx, top: bench.benchTop);
  }

  /// What each mark of p − y is, as it comes, a line each with its ink: the
  /// key's outline, what the target lacks, what the others took, their sum.
  static List<(double, double, String, Color)> legend(LmView view) {
    final String next = view.trace.token(view.target);
    final double given = PredictScene.shares(view, view.position)[view.target];
    return <(double, double, String, Color)>[
      (_keyFrom, _lackFrom, 'lit: y, the answer key, 100% at $next', view.inks.truth),
      (_lackFrom, _excessFrom, 'blue: what $next lacks of it, p − y = ${signedNumber(given - 1)}', view.inks.negative),
      (_excessFrom, _sumFrom, 'clay: what each other token took, its share', view.inks.positive),
      (
        _sumFrom,
        _condense.$1,
        '${signedNumber(given - 1)} + ${fixed(1 - given, 2)} = 0: the two cancel',
        view.inks.ink,
      ),
    ];
  }

  /// The legend's line over the bars, in the rows of the two tokens that
  /// never come next, which have none.
  void _legend(Canvas canvas, LmView view, PredictLayout bench, double beat, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final double y = (bench.row(0).top + bench.row(1).bottom) / 2;
    for (final (double from, double to, String text, Color ink) in legend(view)) {
      final double shown = through(beat, from, from + 0.3) * (1 - through(beat, to - 0.3, to)) * alpha;
      if (shown > 0) {
        view.kit.draw(canvas, text, inked(view.kit.sans, 9.5, ink, alpha: shown), Offset(bench.barLeft, y), anchor: const Offset(0, 0.5));
      }
    }
  }

  /// How much brighter the lit row is while it is read as y.
  static const double _keyLight = 0.9;

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
    drawLastRow(canvas, view, bench, shown);

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
    // Read: the number that should rise most and the one that should fall
    // most, ringed in the loss's honey.
    final double read = through(beat, _readFrom, _readFrom + 0.3) * shown;
    if (read > 0) {
      final (int low, int high) = extremes(view);
      for (final int d in <int>{low, high}) {
        if (signedNumber(g[d]) != '0.00') {
          layout.ring(canvas, view, layout.gradientTile(d), read);
        }
      }
    }
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

    // The weights' plate, under the strings: where they stand.
    PredictScene.drawPlate(canvas, view, bench, shown);
  }

  /// The place's last row standing at the bench's left, as Predict stood
  /// it: its tiles, outlined in the accent, its numbers at its left (in the
  /// ink, or as [inkOf] names another) and its name over it, those at
  /// [words] where they come or go apart from the tiles.
  static void drawLastRow(
    Canvas canvas,
    LmView view,
    PredictLayout bench,
    double alpha, {
    double? words,
    Color? Function(int d)? inkOf,
  }) {
    final List<double> row = bench.lastRow;
    drawColumn(canvas, bench.inputTile, <Color>[
      for (final double v in row) view.inks.cell(v / bench.lastScale).withValues(alpha: alpha),
    ]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bench.inputColumn.inflate(1), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.signal.withValues(alpha: 0.85 * alpha),
    );
    drawColumnNumbers(
      canvas,
      view,
      bench.inputTile,
      row,
      words ?? alpha,
      textSize: bench.textSize,
      writes: bench.writes,
      left: true,
      inkOf: inkOf,
    );
    drawColumnTitle(
      canvas,
      view,
      StreamTable.placeName(view, view.position),
      words ?? alpha,
      x: bench.inputX,
      top: bench.inputColumn.top,
    );
  }

  /// The strings, played back: the errors running from the column where the
  /// logits were made into each number of the gradient, a dot at each tip in
  /// the loss's honey; left faint, a weight on each, until the bench clears.
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
        alpha: web,
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
    _workedBox(canvas, view, layout, beat, gone);
  }

  /// The first number of the gradient worked out beside its strings while
  /// they run: the three tokens bringing most, each error × weight, then the
  /// rest together and the sum, on a backing of the ground.
  void _workedBox(Canvas canvas, LmView view, BackwardLayout layout, double beat, double gone) {
    final double alpha = _span(beat, _worked) * (1 - through(beat, _othersFrom - 0.3, _othersFrom)) * (1 - gone);
    if (alpha <= 0) {
      return;
    }
    final PredictLayout bench = layout.predict;
    final int d = firstMade(view);
    final (List<(int, String, String, String)> terms, int rest, String brought, String sum) = workedNumber(view, d);
    final TextStyle mono = inked(view.kit.mono, 9, view.inks.ink, alpha: alpha);
    final TextStyle quiet = inked(view.kit.sans, 9, view.inks.quiet, alpha: alpha);
    const double chip = 11;
    const double line = 15;
    final List<String> rows = <String>[for (final (_, String e, String w, String product) in terms) '$e × $w = $product'];
    final String others = 'the other ${grouped(rest)}';
    double wide = view.kit.layout('number ${d + 1}', quiet).width;
    for (final String row in rows) {
      wide = math.max(wide, chip + 6 + view.kit.layout(row, mono).width);
    }
    final double tail = view.kit.layout(brought, mono).width;
    wide = math.max(wide, view.kit.layout(others, quiet).width + 10 + tail);
    final double left = layout.gradientColumn.right + 14;
    final double right = bench.logitTile(0, 0).left - 14;
    if (left + wide + 16 > right) {
      return;
    }
    final Rect box = Rect.fromLTWH(left, bench.benchTop, wide + 16, line * (rows.length + 3) + 10);
    drawCard(canvas, view, box, alpha);
    final double x = box.left + 8;
    double y = box.top + 5 + line / 2;
    view.kit.draw(canvas, 'number ${d + 1}', quiet, Offset(x, y), anchor: const Offset(0, 0.5));
    for (int k = 0; k < terms.length; k++) {
      y += line;
      drawToken(canvas, view, Rect.fromCenter(center: Offset(x + chip / 2, y), width: chip, height: chip), terms[k].$1, alpha: alpha);
      view.kit.draw(canvas, rows[k], mono, Offset(x + chip + 6, y), anchor: const Offset(0, 0.5));
    }
    y += line;
    view.kit.draw(canvas, others, quiet, Offset(x, y), anchor: const Offset(0, 0.5));
    view.kit.draw(canvas, brought, mono, Offset(box.right - 8, y), anchor: const Offset(1, 0.5));
    y += line;
    canvas.drawLine(
      Offset(x, y - line / 2 + 1),
      Offset(box.right - 8, y - line / 2 + 1),
      Paint()
        ..strokeWidth = 0.8
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
    view.kit.draw(canvas, 'sum', quiet, Offset(x, y), anchor: const Offset(0, 0.5));
    view.kit.draw(canvas, sum, mono.copyWith(color: view.inks.error.withValues(alpha: alpha)), Offset(box.right - 8, y), anchor: const Offset(1, 0.5));
  }

  // ------------------------------------------------------------ the ladder

  /// The climb into slot [k] of [points], from the slot under it: when it
  /// starts and how long it takes. The final LayerNorm's first, from the
  /// last slot up, then each part from the last.
  static (double, double) _rise(int k, int points) {
    final double step = (_climbTo - _climbFrom) / math.max(1, points - 1);
    return (_climbFrom + (points - 2 - k) * step, math.min(step, _mostRise));
  }

  /// When the climb into slot [k] holds the stage, its caption and note:
  /// from its start to the next part's.
  static (double, double) _turnOf(int k, int points) {
    final double step = (_climbTo - _climbFrom) / math.max(1, points - 1);
    final double from = _climbFrom + (points - 2 - k) * step;
    return (from, from + step);
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
      // At each +, one number worked out while the part holds: the row under
      // it plus what the part sends back makes the row above, its three
      // tiles ringed; through the final LayerNorm, what the norm divides by.
      final int d = firstMade(view);
      for (int k = 0; k < last; k++) {
        final (double t, double p) = _rise(k, points);
        final (_, double end) = _turnOf(k, points);
        final double sum = through(beat, t + 0.68 * p, t + 0.68 * p + 0.25) * (1 - through(beat, end - 0.25, end));
        if (sum <= 0) {
          continue;
        }
        final double right = tower.slot(0).right;
        final double labelY = tower.labelAt(k + 1).dy;
        final TextStyle face = inked(view.kit.mono, 9, view.inks.error, alpha: sum);
        if (k + 1 == last) {
          view.kit.draw(
            canvas,
            '÷ ${fixed(ForwardScene.evening(view).sd, 2)}, less shift and stretch',
            inked(view.kit.sans, 9, view.inks.error, alpha: sum),
            Offset(right, labelY),
            anchor: const Offset(1, 0),
          );
          continue;
        }
        final String below = fixed(rungs[k + 1][d], 2);
        final String above = fixed(rungs[k][d], 2);
        final double sent = _parse(above) - _parse(below);
        final String added = sent < 0 ? '− ${fixed(-sent, 2)}' : '+ ${fixed(sent, 2)}';
        // Beside the part's name where it fits; without "number" where only
        // that fits, the ringed tiles saying which; else not at all.
        final double named = tower.labelAt(k + 1).dx +
            view.kit.layout(partName(k + 1, layers), inked(view.kit.sans, 9, view.inks.quiet)).width +
            12;
        final String worked = '$below $added = $above';
        final String text = <String>['number ${d + 1}: $worked', worked].firstWhere(
          (String t) => right - view.kit.layout(t, face).width >= named,
          orElse: () => '',
        );
        if (text.isNotEmpty) {
          view.kit.draw(canvas, text, face, Offset(right, labelY), anchor: const Offset(1, 0));
        }
        for (final Rect row in <Rect>[tower.slot(k + 1), tower.strip(k + 1), tower.slot(k)]) {
          final double w = row.width / view.trace.model.width;
          layout.ring(canvas, view, Rect.fromLTWH(row.left + d * w, row.top, w, row.height), sum);
        }
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

  /// Why each mini-step happens, over the canvas, a line a thought: each
  /// mini-step its own note, read while it holds.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final String focus = StreamTable.placeName(view, view.position);
    final String next = trace.token(view.target);
    final int width = trace.model.width;
    final int targets = trace.targetCount;
    final double given = PredictScene.shares(view, view.position)[view.target];
    final int others = trace.allowed.length - 1;
    final int d = firstMade(view) + 1;
    final String token = trace.token(trace.inputAt(view.peptide, view.position));
    final int points = trace.points.length;
    final int later = view.focus.inputs - 1 - view.position;
    return <(double, double, String)>[
      (
        0.25,
        _alone,
        'The loss is one number; lowering it means moving the weights.\n'
            "A weight's gradient: how fast the loss rises as it rises.\n"
            'Backward carries the error back, row by row, from the loss;\n'
            "each weight's gradient comes from it, as Update will show.",
      ),
      (
        _alone,
        _guess,
        "The loss is the mean of the ${grouped(targets)} places' costs, one a guess.\n"
            "Each cost can be followed back on its own: $focus's first.\n"
            '${given < 0.5 ? 'Its cost is high: the guess gave what came next only ${percent(given)}.' : 'Its cost is low: the guess gave what came next ${percent(given)}.'}',
      ),
      (
        _guess,
        _keyFrom,
        "Predict's shares for $focus: a bar a token, all adding to 100%.\n"
            "The dashed line is 100%, where $next's bar reaches if sure.\n"
            '${given < 0.95 ? 'To lower the cost, $next\'s bar must grow, so the rest shrink.' : '$next\'s bar is near 100% already: little is left to gain.'}',
      ),
      (
        _keyFrom,
        _lackFrom,
        "y is the answer key: Shift's target y, at this one place.\n"
            'A sure, right guess would match it: $next at 100%, the rest 0.\n'
            "The lit row is y for $next, 100%; every other token's y is 0.",
      ),
      (
        _lackFrom,
        _excessFrom,
        "p − y, each share less the key, is the slope of $focus's cost\n"
            "at each logit, the token's score before softmax.\n"
            "Negative: raising $next's logit lowers the cost; at most −1.",
      ),
      (
        _excessFrom,
        _sumFrom,
        'For the other ${grouped(others)}, y is 0: p − y is the share each took.\n'
            "Positive: lowering that token's logit lowers the cost.\n"
            'The larger its share, the harder that token is pushed down.',
      ),
      (
        _sumFrom,
        _condense.$1,
        "The others' shares add to ${percent(1 - given)}, all that $next lacks of 100%.\n"
            'So the ${grouped(trace.vocab.length)} add to 0: raising $next means lowering the rest.\n'
            '${PredictScene.blocked(trace)} never come next: their p − y is 0.',
      ),
      (
        _condense.$1,
        _firstFrom,
        "Each logit was made from $focus's row: $width numbers, a string each.\n"
            "Now the reverse: how $focus's cost changes with each of the $width.\n"
            "That is the row's gradient, one number for each of its own.",
      ),
      (
        _firstFrom,
        _othersFrom,
        "Every token's error runs back along its string to number $d,\n"
            "times that string's weight: the same weights Predict used.\n"
            "Their sum is number $d's gradient; big errors weigh most.",
      ),
      (
        _othersFrom,
        _readFrom,
        'Each number of the row gets its own ${grouped(trace.vocab.length)} strings and sum.\n'
            'This is the chain rule: the error at the output × the weights.',
      ),
      (
        _readFrom,
        _benchOut.$1,
        "A number's sign says which way it should go to lower the cost.\n"
            "But $focus's row is not a weight: nothing updates it directly.\n"
            'Its gradient goes on down, to the layers that made the row.',
      ),
      (
        _benchOut.$1,
        _climbFrom,
        "Forward built $focus's last row a part at a time, from x0 down.\n"
            'Backward visits the same rows in reverse, from the last up.\n'
            "A row's gradient: how the costs change with each of its numbers.",
      ),
      for (int k = points - 2; k >= 0; k--) (_turnOf(k, points).$1, _turnOf(k, points).$2, climbNote(view, k, later)),
      (
        _climbTo,
        _home.$1,
        "Embedding made x0: $token's token row + place ${view.position}'s row.\n"
            "Back through that +, both rows get x0's gradient whole.\n"
            "$token's row is shared: every $token in the batch adds to it.",
      ),
      (
        _home.$1,
        double.infinity,
        'Every place climbs the same ladder at once, a row each.\n'
            'A token row gets the sum over every place that read it,\n'
            'a position row the sum at its place across the ${spelled(trace.peptides.length)} peptides.\n'
            'The loss is the mean of the ${grouped(targets)} costs: each sum is ÷ ${grouped(targets)}.\n'
            'Next, Update gives every weight its gradient, then its step.',
      ),
    ];
  }

  /// The note while the gradient climbs into slot [k], through the part that
  /// made the slot under it; [later] places come after the one in focus.
  static String climbNote(LmView view, int k, int later) {
    final TrainingTrace trace = view.trace;
    final int part = k + 1;
    final String focus = StreamTable.placeName(view, view.position);
    if (part > 2 * trace.model.layers) {
      return 'The final LayerNorm made the row: less its mean, over its spread.\n'
          'Back through it, the gradient is divided by that spread too,\n'
          'less any part that would only shift or stretch the row.';
    }
    final int block = (part - 1) ~/ 2 + 1;
    final bool last = block == trace.model.layers;
    if (part.isEven) {
      return last
          ? "Forward added the feed-forward's output to the row: row + FF.\n"
                'Back through a +, the gradient goes both ways unchanged:\n'
                'up the stream, and into the network, which sends its share.\n'
                'The row above gets both, added: the sum at the right.'
          : 'Block $block works as block ${block + 1}: each + passes the gradient up whole,\n'
                'and each part adds what it sends back through its own weights.';
    }
    if (later == 0) {
      return 'Attention lets later places read a row, but none follows $focus:\n'
          'its gradient still carries only its own cost.';
    }
    return last
        ? "Attention let later places read $focus's row, as its map showed.\n"
              "Their costs depend on $focus's row too, and send blame back:\n"
              "from here up, $focus's gradient carries their costs as well."
        : "Block $block's attention sends back blame from every place that\n"
              "read $focus's row in block $block, so x0's gradient carries them too.";
  }

  @override
  String caption(LmView view, TrainingFrame frame) => _caption(view, frame.local * _beats);

  String _caption(LmView view, double beat) {
    final TrainingTrace trace = view.trace;
    final String focus = StreamTable.placeName(view, view.position);
    final String next = trace.token(view.target);
    final List<double> p = PredictScene.shares(view, view.position);
    final int width = trace.model.width;
    if (beat < _alone) {
      return 'To lower the loss, ${nats(trace.loss(view.step))}, which way should each weight move?';
    }
    if (beat < _guess) {
      final double cost = LossScene.surprises(view)[view.peptide][view.position];
      return 'Start at one place, $focus: its cost, ${LossScene.cost(cost)} nats, '
          "is −ln of $next's ${percent(p[view.target])}";
    }
    if (beat < _keyFrom) {
      final int best = PredictScene.top(view, view.position);
      return best == view.target
          ? "$focus's guess: $next on top at ${percent(p[best])}, what truly came next"
          : "$focus's guess: ${trace.token(best)} on top at ${percent(p[best])}; "
                'the true next, $next, got ${percent(p[view.target])}';
    }
    if (beat < _lackFrom) {
      return 'y, the answer key: 1 for $next, the true next; 0 for the other ${grouped(trace.allowed.length - 1)}';
    }
    if (beat < _excessFrom) {
      final String lack = signedNumber(p[view.target] - 1);
      return lack == '0.00'
          ? 'At $next: p − y = ${p[view.target].toStringAsFixed(3)} − 1 = 0.00: nothing to raise'
          : 'At $next: p − y = ${p[view.target].toStringAsFixed(3)} − 1 = $lack, the gap: raise its logit';
    }
    if (beat < _sumFrom) {
      return _largestOthers(view) == null
          ? 'The others: y is 0, so p − y is their share, all 0.00 here'
          : 'The others: y is 0, so p − y is the share: ${_largestOthers(view)}';
    }
    if (beat < _condense.$1) {
      return 'All ${grouped(trace.vocab.length)} add to 0: the others took ${percent(1 - p[view.target])}, '
          'what $next lacked';
    }
    if (beat < _firstFrom) {
      return "$focus's last row, as Predict read it, and $width slots for its gradient";
    }
    if (beat < _othersFrom) {
      final int d = firstMade(view);
      return "Number ${d + 1} of $focus's gradient: errors × weights, summed: ${fixed(rowGradient(view)[d], 2)}";
    }
    if (beat < _readFrom) {
      return 'The other ${grouped(width - 1)} the same way, back along the strings Predict used';
    }
    if (beat < _benchOut.$1) {
      final (int low, int high) = extremes(view);
      final List<double> g = rowGradient(view);
      return signedNumber(g[low]) == '0.00' && signedNumber(g[high]) == '0.00'
          ? 'Read it: every number is about 0.00; little goes on down'
          : 'Read it: number ${low + 1}, ${fixed(g[low], 2)}, should rise; '
                'number ${high + 1}, ${signedNumber(g[high])}, should fall';
    }
    if (beat < _climbFrom) {
      return "$focus's gradient climbs back up the ladder Forward came down";
    }
    final int points = trace.points.length;
    if (beat < _climbTo) {
      for (int k = 0; k <= points - 2; k++) {
        final (double from, double to) = _turnOf(k, points);
        if (beat >= from && beat < to) {
          return climb(view, k);
        }
      }
    }
    if (beat < _home.$1) {
      final String token = trace.token(trace.inputAt(view.peptide, view.position));
      return "x0 = $token's token row + place ${view.position}'s row: both get its gradient";
    }
    final double first = bosShare(view);
    return first > 0.5
        ? "Every place at once: ${percent(first)} of x0's gradient is at <bos>"
        : "Every place at once: each row's gradient at x0";
  }

  /// The numbers of the place's gradient that should rise most and fall
  /// most: its most negative and its most positive.
  static (int, int) extremes(LmView view) {
    final List<double> g = rowGradient(view);
    int low = 0;
    int high = 0;
    for (int d = 1; d < g.length; d++) {
      if (g[d] < g[low]) {
        low = d;
      }
      if (g[d] > g[high]) {
        high = d;
      }
    }
    return (low, high);
  }

  /// A number as written, its true minus read back.
  static double _parse(String written) => double.parse(written.replaceAll('−', '-').replaceAll('+', ''));

  /// Number [d] of the place's gradient worked out as written: the three
  /// tokens whose error × weight bring most, each (token, error, weight,
  /// product); then what the rest bring, and the sum, as the column writes
  /// it, the rest found from the two so the whole adds up.
  static (List<(int, String, String, String)>, int, String, String) workedNumber(LmView view, int d) {
    final TrainingTrace trace = view.trace;
    final List<double> error = errors(view, view.position);
    final List<int> ranked = <int>[...trace.allowed]
      ..sort((int a, int b) {
        final double x = (error[a] * trace.outputWeight(view.checkpoint, a, d)).abs();
        final double y = (error[b] * trace.outputWeight(view.checkpoint, b, d)).abs();
        return x != y ? y.compareTo(x) : a.compareTo(b);
      });
    final List<(int, String, String, String)> terms = <(int, String, String, String)>[];
    double brought = 0;
    for (final int id in ranked.take(3)) {
      final String e = signedNumber(error[id]);
      final String w = fixed(trace.outputWeight(view.checkpoint, id, d), 2);
      final String product = signedNumber(_parse(e) * _parse(w));
      brought += _parse(product);
      terms.add((id, e, w, product));
    }
    final String sum = fixed(rowGradient(view)[d], 2);
    return (terms, trace.allowed.length - terms.length, signedNumber(_parse(sum) - brought), sum);
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

  /// Backward's own page: what it takes and gives, what the stream's +s are
  /// for, and why its colours fade as the run goes on.
  @override
  LmInfo info(LmView view) => LmInfo(
    title: LmStage.backward.label,
    lead: 'From the loss back to x0, every number of every row gets its gradient: how fast the loss would '
        'rise as that number rose. Backward changes nothing: it measures, and Update moves the weights.',
    sections: <LmInfoSection>[
      // Each titled as its tag, less its size.
      LmInfoSection("${StreamTable.placeName(view, view.position)}'s gradient, layer to layer", const <String>[
        'Each + of the stream hands the gradient back whole, whatever the part beside it adds: that is what '
            'the +s are for. However many blocks are stacked, each still gets the gradient whole, the first as '
            'the last.',
      ]),
      const LmInfoSection('Gradient at x0', <String>[
        "Its colours, as every gradient's in this stage, are on the whole batch's scale at that step: a place "
            'with little left to learn is drawn as faint as it is.',
      ]),
    ],
  );
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

  /// A tile ringed in the loss's honey: one number followed.
  void ring(Canvas canvas, LmView view, Rect tile, double alpha) {
    if (alpha <= 0) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile.inflate(1), const Radius.circular(2.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = view.inks.error.withValues(alpha: alpha),
    );
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
