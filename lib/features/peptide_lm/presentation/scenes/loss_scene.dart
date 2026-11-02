import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'predict_scene.dart';
import 'shift_scene.dart';
import 'stream_table.dart';

/// Loss: how far each guess fell short of what came next, and the one number
/// the step lowers. It opens on Predict's last frame, the map of squares with
/// the answer key at its right. Loss reads one share a place, p(y), the share
/// the guess gave what came next: every other cell goes, and each row's lit
/// slot slides along its row to the key, beside its y. On the bench that
/// leaves, −ln p(y) is worked out on its curve: an even guess, 1/21 a token,
/// scores ln 21, on a dashed line across it; the place in focus's square
/// flies down to the p(y) axis, and a guide runs up to the curve and across
/// to its cost in nats. Then every target at once: the key's y tiles swing
/// down into the peptide's line of target y, as Shift drew it, the other
/// peptides' lines come in, their padding dimmed and never scored, and a bar
/// in the loss's honey rises on each target to its −ln p(y), the even guess
/// dashed across each line. Last, the bars level out into their mean, each
/// leaving a faint ghost where it stood above it: the step's loss.
///
/// Every number is the run's: each p(y) is Predict's own share, softmax of
/// the whole logits, and −ln of it is the loss the run kept for that target;
/// their mean is the step's loss as the run kept it.
final class LossScene extends LmScene {
  const LossScene();

  static double get _beats => LmStage.loss.beats.toDouble();

  // p(y) alone: Predict's note gives way; every cell but what came next goes,
  // the tiles under the map with them; the map's tag gives way to p(y)'s;
  // then each row's lit slot slides along its row to the key.
  static const (double, double) _othersOut = (0.15, 0.85);
  static const (double, double) _mapTagOut = (0.3, 0.55);
  static const (double, double) _tagIn = (0.55, 0.8);
  static const (double, double) _gather = (0.95, 1.85);

  // −ln p(y) on its curve: the chart comes onto the bench; the curve draws
  // itself up from 100%; the even guess's line; then the place in focus: its
  // square flies down to the p(y) axis, a guide runs up to the curve and
  // across to its cost.
  static const (double, double) _chartIn = (2.0, 2.4);
  static const (double, double) _curve = (2.3, 3.0);
  static const (double, double) _even = (3.0, 3.5);
  static const (double, double) _fly = (3.8, 4.4);
  static const (double, double) _up = (4.4, 4.8);
  static const (double, double) _across = (4.8, 5.2);

  // Every target: the bench and the table clear; the key's y tiles swing
  // down into the focus peptide's line; the other lines come in; every bar
  // rises.
  static const (double, double) _benchOut = (6.4, 6.8);
  static const (double, double) _swing = (6.6, 7.6);
  static const (double, double) _batchIn = (7.4, 8.0);
  static const (double, double) _rise = (8.2, 9.2);

  // The mean: the bars level out; the loss joins the legend.
  static const (double, double) _level = (10.2, 11.4);
  static const (double, double) _lossIn = (11.2, 11.6);

  /// How strong the ghost of a bar's old height is, once levelled.
  static const double _ghost = 0.28;

  /// A bar's width, of its column's.
  static const double _barWidth = 0.7;

  /// What the batch's tag says its bars are, beside it: the longer where it
  /// fits.
  static const List<String> _batchRole = <String>['−ln p(y), a bar each', '−ln p(y)'];

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) => _paint(canvas, size, view, frame.local * _beats);

  void _paint(Canvas canvas, Size size, LmView view, double beat) {
    if (beat <= 0) {
      const PredictScene().paintEnd(canvas, size, view);
      return;
    }
    final LossLayout layout = LossLayout(size, view);
    final double out = _span(beat, _benchOut);
    if (out < 1) {
      const PredictScene().paintEnd(
        canvas,
        size,
        view,
        PredictFade(
          note: 0,
          tag: 1 - _span(beat, _mapTagOut),
          rows: 1 - out,
          others: 1 - _span(beat, _othersOut),
          answers: 0,
          outline: 0,
          key: beat < _swing.$1 ? 1 : 0,
          given: 1 - out,
        ),
      );
    }
    layout.table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, PredictScene.notes(view).last.$3), ...notes(view)],
      beat,
    );
    if (out < 1) {
      _key(canvas, view, layout, beat, 1 - out);
      _chart(canvas, view, layout, beat, 1 - out);
    }
    _batch(canvas, view, layout, beat);
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
          head: view.head,
          inks: view.inks,
          kit: view.kit,
        );

  /// The share place [i] of [peptide] gave what came next, p(y): Predict's
  /// own, softmax of the whole logits.
  static double given(LmView view, int peptide, int i) =>
      PredictScene.shares(_on(view, peptide), i)[view.trace.targetAt(peptide, i)];

  /// Every target's cost, −ln p(y): a list a peptide, a place each.
  static List<List<double>> surprises(LmView view) => view.kit.memo<List<List<double>>>(
    ('loss-surprises', view.step),
    () => <List<double>>[
      for (int p = 0; p < view.trace.peptides.length; p++)
        <double>[for (int i = 0; i < view.trace.peptides[p].inputs; i++) -math.log(given(view, p, i))],
    ],
  );

  /// The largest cost any target has at any checkpoint, up to a whole nat,
  /// and never under an even guess's: one scale for the chart's height and
  /// the bars at every step, so a step can be set against another.
  static double ceiling(LmView view) => view.kit.memo<double>(('loss-ceiling', view.trace.name), () {
    double most = view.trace.uniform;
    for (final TraceCheckpoint at in view.trace.checkpoints) {
      final LmView there = LmView(
        trace: view.trace,
        checkpoint: at,
        peptide: view.peptide,
        position: view.position,
        head: view.head,
        inks: view.inks,
        kit: view.kit,
      );
      for (final List<double> costs in surprises(there)) {
        for (final double cost in costs) {
          most = math.max(most, cost);
        }
      }
    }
    return most.ceilToDouble();
  });

  /// How much of the step's loss is at the `<bos>` places, each peptide's
  /// first target.
  static double bosShare(LmView view) {
    double first = 0;
    double all = 0;
    for (final List<double> costs in surprises(view)) {
      first += costs.first;
      for (final double cost in costs) {
        all += cost;
      }
    }
    return all <= 0 ? 0 : first / all;
  }

  /// A cost as the captions and the chart write it: to two places, and to
  /// three where two would say nothing.
  static String cost(double nats) => nats < 0.01 ? nats.toStringAsFixed(3) : fixed(nats, 2);

  /// The place in focus's p(y), as the worked example writes it, a share to
  /// three figures and a percentage, and its cost worked out from the share
  /// as written, so the sum reads right.
  static (String, String, String) worked(LmView view) {
    final double p = given(view, view.peptide, view.position);
    final String share = p.toStringAsPrecision(3);
    final String percentage = (p * 100).toStringAsPrecision(3);
    return (share, '$percentage%', cost(-math.log(double.parse(share))));
  }

  /// The tag over the table once only p(y) is read.
  static String tag(LmView view) => 'p(y) · probability of the target · ${grouped(view.focus.inputs)}';

  /// The tag over the batch: Shift's.
  static const String batchTag = 'target y';

  // --------------------------------------------------------------- the key

  /// The table's part: p(y)'s tag; each row's lit slot, where the map had it,
  /// then sliding along its row to the key; the place in focus's outline, as
  /// Predict drew it, narrowing to its key as its slot slides there, clear of
  /// the chart to come, its tile ringed instead.
  void _key(Canvas canvas, LmView view, LossLayout layout, double beat, double kept) {
    final StreamTable table = layout.table;
    table.tag(canvas, tag(view), _span(beat, _tagIn) * kept);
    final double gather = _span(beat, _gather);
    for (int i = 0; i < view.focus.inputs; i++) {
      PredictScene.drawShare(
        canvas,
        view,
        layout.answerCell(i, gather),
        share: given(view, view.peptide, i),
        shown: kept,
        lit: 1,
      );
    }
    final int focus = view.position;
    final double narrow = gather;
    final double wide = -table.gutter;
    final double key = layout.keySlot(focus).left - table.layout.label(focus).left;
    table.outline(canvas, focus, layout.predict.right, kept, dx: wide + (key - wide) * narrow);
    outlineToken(canvas, table.layout.label(focus).shift(Offset(wide, 0)), view.inks.signal, alpha: narrow * kept);
  }

  // ------------------------------------------------------------- the chart

  /// −ln p(y) on its curve, on the bench the gather left: the axes, the
  /// curve drawing itself up from 100%, the even guess's dashed line across
  /// it; then the place in focus, its square flying down to the p(y) axis, a
  /// guide up to the curve and across to its cost, each written where it
  /// meets its axis, over the axis's own numbers there.
  void _chart(Canvas canvas, LmView view, LossLayout layout, double beat, double kept) {
    final double alpha = _span(beat, _chartIn) * kept;
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final LossChart chart = layout.chart;
    final Rect plot = chart.area;
    final double top = chart.ceiling;
    final double p = given(view, view.peptide, view.position);
    final double spent = -math.log(p);
    final (_, String percentage, String written) = worked(view);
    final double fly = _span(beat, _fly);
    final double landed = through(beat, _fly.$2 - 0.15, _fly.$2) * alpha;
    final double up = _span(beat, _up);
    final double across = _span(beat, _across);
    final double reached = across * alpha;
    final Offset foot = chart.at(p, 0);
    final Offset onCurve = chart.at(p, spent);
    final Offset onAxis = chart.at(0, spent);

    // The worked place's numbers where they meet their axes, and the axes'
    // own numbers they cover, which give way to them.
    final TextStyle numbers = inked(view.kit.mono, 8.5, view.inks.quiet);
    final TextStyle footStyle = inked(view.kit.mono, 9, view.inks.ink, alpha: landed);
    final TextStyle costStyle = inked(view.kit.mono, 9, view.inks.error, alpha: reached);
    final Size footSize = view.kit.layout(percentage, footStyle).size;
    final Size costSize = view.kit.layout(written, costStyle).size;
    final double footLeast = plot.left - 2 + footSize.width / 2;
    final double footX = math.min(math.max(foot.dx, footLeast), math.max(footLeast, plot.right + 2 - footSize.width / 2));
    final Rect footLabel = Rect.fromLTWH(footX - footSize.width / 2, plot.bottom + 4, footSize.width, footSize.height);
    final Rect costLabel = Rect.fromLTWH(plot.left - 5 - costSize.width, onAxis.dy - costSize.height / 2, costSize.width, costSize.height);

    final Paint axis = Paint()
      ..strokeWidth = 1
      ..color = view.inks.quiet.withValues(alpha: alpha);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axis);
    for (int n = 0; n <= top.round(); n++) {
      final Offset at = chart.at(0, n.toDouble());
      canvas.drawLine(at, at - const Offset(3, 0), axis);
      final String text = '$n';
      final Size size = view.kit.layout(text, numbers).size;
      final Rect label = Rect.fromLTWH(at.dx - 5 - size.width, at.dy - size.height / 2, size.width, size.height);
      final double hidden = label.overlaps(costLabel.inflate(2)) ? reached : 0;
      view.kit.draw(canvas, text, inked(view.kit.mono, 8.5, view.inks.quiet, alpha: alpha * (1 - hidden)), label.topLeft);
    }
    for (final (double share, String text) in <(double, String)>[(0, '0'), (0.5, percent(0.5)), (1, percent(1))]) {
      final Offset at = chart.at(share, 0);
      canvas.drawLine(at, at + const Offset(0, 3), axis);
      final Size size = view.kit.layout(text, numbers).size;
      final Rect label = Rect.fromLTWH(at.dx - size.width / 2, at.dy + 4, size.width, size.height);
      final double hidden = label.overlaps(footLabel.inflate(2)) ? landed : 0;
      view.kit.draw(canvas, text, inked(view.kit.mono, 8.5, view.inks.quiet, alpha: alpha * (1 - hidden)), label.topLeft);
    }
    final TextStyle words = inked(view.kit.sans, 8.5, view.inks.quiet, alpha: alpha);
    view.kit.draw(canvas, 'p(y)', words, Offset(plot.center.dx, plot.bottom + 15), anchor: const Offset(0.5, 0));
    view.kit.draw(canvas, '−ln p(y), nats', words, Offset(plot.left - 4, plot.top - 6), anchor: const Offset(0, 1));

    // An even guess: 1/21 to every token, so ln 21 at every place, a dashed
    // line across, where the curve meets it at 1/21.
    final double even = _span(beat, _even) * alpha;
    final double evenCost = trace.uniform;
    if (even > 0) {
      dashedLine(
        canvas,
        chart.at(0, evenCost),
        chart.at(1, evenCost),
        Paint()
          ..strokeWidth = 1
          ..color = view.inks.quiet.withValues(alpha: 0.8 * even),
        dash: 3,
        gap: 2,
      );
      view.kit.draw(
        canvas,
        'even guess, 1/${trace.allowed.length}: ${nats(evenCost)}',
        inked(view.kit.mono, 8.5, view.inks.quiet, alpha: even),
        chart.at(1, evenCost) + const Offset(0, -3),
        anchor: const Offset(1, 1),
      );
    }

    // The curve, drawn from a sure, right guess up.
    final double drawn = _span(beat, _curve);
    if (drawn > 0) {
      const int steps = 192;
      final Path curve = Path();
      for (int k = 0; k <= steps; k++) {
        final double cost = top * drawn * k / steps;
        final Offset at = chart.at(math.exp(-cost), cost);
        k == 0 ? curve.moveTo(at.dx, at.dy) : curve.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(
        curve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = view.inks.error.withValues(alpha: 0.95 * alpha),
      );
    }
    if (even > 0) {
      canvas.drawCircle(
        chart.at(1 / trace.allowed.length, evenCost),
        2.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = view.inks.quiet.withValues(alpha: even),
      );
    }

    // The place in focus: its square's copy flies from its slot down to the
    // p(y) axis, a dot as it lands; then a guide up to the curve, and across
    // to the cost.
    if (fly > 0) {
      final RRect square = PredictScene.fillOf(PredictScene.slotOf(layout.answerCell(view.position, 1)), p);
      final double side = square.width + (_dot * 2 - square.width) * fly;
      final Offset centre = Offset.lerp(square.center, foot, fly)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: side, height: side),
          Radius.circular(square.tlRadiusX + (side / 2 - square.tlRadiusX) * fly),
        ),
        Paint()..color = Color.lerp(PredictScene.fillColour(view, p), view.inks.signal, fly)!.withValues(alpha: alpha),
      );
    }
    final Paint guide = Paint()
      ..strokeWidth = 1
      ..color = view.inks.ink.withValues(alpha: 0.7 * alpha);
    if (up > 0) {
      dashedLine(canvas, foot, Offset.lerp(foot, onCurve, up)!, guide);
    }
    if (across > 0) {
      dashedLine(canvas, onCurve, Offset.lerp(onCurve, onAxis, across)!, guide);
    }
    if (up > 0) {
      canvas.drawCircle(onCurve, _dot + 0.8, Paint()..color = view.inks.error.withValues(alpha: up * alpha));
    }
    if (landed > 0) {
      view.kit.draw(canvas, percentage, footStyle, footLabel.topLeft);
    }
    if (reached > 0) {
      view.kit.draw(canvas, written, costStyle, costLabel.topLeft);
    }
  }

  /// The radius of the worked place's dot on the p(y) axis.
  static const double _dot = 2.5;

  // ------------------------------------------------------------- the batch

  /// Every target at once, as Shift drew target y: the key's tiles swinging
  /// down into the peptide in focus's line, the other lines coming in, their
  /// padding dimmed; a bar on each target rising to its −ln p(y), the even
  /// guess dashed across each line; then the bars levelling out into their
  /// mean, each old height left as a faint ghost above the level; the
  /// legend under it all.
  void _batch(Canvas canvas, LmView view, LossLayout layout, double beat) {
    if (beat < _swing.$1) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final double swing = _span(beat, _swing);
    final double shown = _span(beat, _batchIn);
    final double rise = _span(beat, _rise);
    final double level = _span(beat, _level);
    final int focus = view.peptide;
    final int n = view.focus.inputs;
    if (shown > 0) {
      final Rect plate = drawTag(canvas, view, batchTag, Offset(layout.table.layout.left, layout.table.layout.tagTop), alpha: shown);
      ShiftScene.drawRole(canvas, view, _batchRole, plate, layout.size.width - 10, shown);
    }
    for (int p = 0; p < trace.peptides.length; p++) {
      final TracePeptide peptide = trace.peptides[p];
      final bool focused = p == focus;
      if (shown <= 0) {
        continue;
      }
      if (focused) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(layout.card(p), const Radius.circular(6)),
          Paint()..color = view.inks.card.withValues(alpha: view.inks.card.a * shown),
        );
      }
      view.kit.draw(
        canvas,
        '${peptide.source.label} · ${peptide.sequence.length} aa',
        inked(view.kit.sans, 10, focused ? view.inks.ink : view.inks.quiet, alpha: shown),
        Offset(layout.batchLeft, layout.lineTop(p)),
      );
      for (int i = focused ? n : 0; i < layout.columns; i++) {
        final double padded = i < peptide.inputs ? 1 : 1 - ShiftScene.dimmed;
        drawToken(canvas, view, layout.tile(p, i), trace.targets[p][i], alpha: shown * padded);
      }
    }
    for (int i = 0; i < n; i++) {
      drawToken(canvas, view, layout.swung(i, swing), trace.targetAt(focus, i));
    }
    outlineToken(canvas, layout.tile(focus, view.position), view.inks.signal, alpha: shown);
    if (rise > 0) {
      _bars(canvas, view, layout, rise, level);
    }
    _legend(canvas, view, layout, rise, _span(beat, _lossIn));
  }

  /// Each target's bar, [rise] of the way up to its −ln p(y), and [level] of
  /// the way from there to their mean; the even guess dashed across each
  /// line over them.
  void _bars(Canvas canvas, LmView view, LossLayout layout, double rise, double level) {
    final TrainingTrace trace = view.trace;
    final List<List<double>> costs = surprises(view);
    final double mean = trace.loss(view.step);
    final double scale = layout.barRoom / layout.chart.ceiling;
    final Paint bar = Paint()..color = view.inks.error.withValues(alpha: 0.92 * rise);
    final Paint ghost = Paint()..color = view.inks.error.withValues(alpha: _ghost * level * rise);
    for (int p = 0; p < trace.peptides.length; p++) {
      final double base = layout.base(p) - 1;
      for (int i = 0; i < costs[p].length; i++) {
        final Rect tile = layout.tile(p, i);
        final double was = costs[p][i];
        final double height = (was + (mean - was) * level) * rise * scale;
        final double width = layout.step * _barWidth;
        final Rect drawn = Rect.fromLTWH(tile.center.dx - width / 2, base - height, width, height);
        if (level > 0 && was > mean) {
          canvas.drawRect(Rect.fromLTRB(drawn.left, base - was * rise * scale, drawn.right, drawn.top), ghost);
        }
        if (height > 0) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(drawn, topLeft: const Radius.circular(1), topRight: const Radius.circular(1)),
            bar,
          );
        }
      }
      final double y = base - trace.uniform * scale;
      dashedLine(
        canvas,
        Offset(layout.tile(p, 0).left, y),
        Offset(layout.tile(p, costs[p].length - 1).right, y),
        Paint()
          ..strokeWidth = 1
          ..color = view.inks.quiet.withValues(alpha: 0.85 * rise),
        dash: 3,
        gap: 2,
      );
    }
  }

  /// Under the lines: the loss, a honey swatch and its number, once the bars
  /// have levelled; and the even guess, a dashed swatch and its number, with
  /// the bars.
  void _legend(Canvas canvas, LmView view, LossLayout layout, double even, double loss) {
    final TrainingTrace trace = view.trace;
    final double y = layout.legendTop + layout.legendHeight / 2;
    double x = layout.batchLeft;
    if (loss > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y - 2, _swatch, 4), const Radius.circular(1)),
        Paint()..color = view.inks.error.withValues(alpha: 0.92 * loss),
      );
      view.kit.draw(
        canvas,
        lossText(view),
        inked(view.kit.mono, 9, view.inks.error, alpha: loss),
        Offset(x + _swatch + 5, y),
        anchor: const Offset(0, 0.5),
      );
    }
    x += layout.lossItem;
    if (even > 0) {
      dashedLine(
        canvas,
        Offset(x, y),
        Offset(x + _swatch, y),
        Paint()
          ..strokeWidth = 1
          ..color = view.inks.quiet.withValues(alpha: even),
        dash: 3,
        gap: 2,
      );
      view.kit.draw(
        canvas,
        'even guess ${nats(trace.uniform)}',
        inked(view.kit.mono, 9, view.inks.quiet, alpha: even),
        Offset(x + _swatch + 5, y),
        anchor: const Offset(0, 0.5),
      );
    }
  }

  /// A legend's swatch.
  static const double _swatch = 14;

  /// The loss as the legend writes it.
  static String lossText(LmView view) => 'loss ${nats(view.trace.loss(view.step))}';

  // ------------------------------------------------------------------- taps

  /// While the table shows, a row puts its place in focus; once the batch
  /// has come, a line puts its peptide in focus, and a target of the focus
  /// line its place; while the key swings, a tap asks for nothing.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final double beat = frame.local * _beats;
    if (beat < _benchOut.$1) {
      final int? i = StreamTable(size, view).placeAt(at);
      return i == null ? null : FocusPosition(i);
    }
    return beat < _batchIn.$1 ? null : LossLayout(size, view).hitAt(at);
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) => LossLayout(size, view).hitAt(at);

  // ---------------------------------------------------------------- caption

  /// Why each part happens, over the table and the batch, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int peptides = trace.peptides.length;
    final double first = bosShare(view);
    return <(double, double, String)>[
      (
        0.25,
        _chartIn.$1,
        'Why p(y) alone: the other ${grouped(trace.allowed.length - 1)} shares still count, through it.\n'
            'All ${grouped(trace.allowed.length)} add to 100%, so p(y) can rise only as the others fall.',
      ),
      (
        _chartIn.$1,
        _benchOut.$1,
        'The cost is 0 for a sure, right guess and grows as p(y) falls.\n'
            'Each halving of p(y) adds ln 2 = 0.69 nats: a sure miss costs most.',
      ),
      (
        _benchOut.$1,
        _level.$1,
        'Every place of every peptide is scored the same way.\n'
            'Padding is no data: its ${grouped(trace.pads)} places are never scored.',
      ),
      (
        _level.$1,
        double.infinity,
        'This is cross-entropy, the loss language models train on.\n'
            'Next, Backward finds how each weight should move to lower it.'
            '${first > 0.5 ? '\n${percent(first)} is at <bos>: no model can know which of '
                      '${spelled(peptides)} peptides comes.' : ''}',
      ),
    ];
  }

  @override
  String caption(LmView view, TrainingFrame frame) => _caption(view, frame.local * _beats);

  String _caption(LmView view, double beat) {
    final TrainingTrace trace = view.trace;
    if (beat < _chartIn.$1) {
      double least = 1;
      double most = 0;
      for (int i = 0; i < view.focus.inputs; i++) {
        least = math.min(least, given(view, view.peptide, i));
        most = math.max(most, given(view, view.peptide, i));
      }
      return 'Loss reads one share a place, p(y): here from ${percent(least)} to ${percent(most)}';
    }
    final int count = trace.allowed.length;
    if (beat < _fly.$1) {
      return '−ln p(y), in nats: an even guess, 1/$count a token, scores ln $count = ${nats(trace.uniform)}';
    }
    if (beat < _benchOut.$1) {
      final (String share, String percentage, String written) = worked(view);
      final double spent = -math.log(double.parse(share));
      final String than = spent < 0.01
          ? 'next to nothing'
          : spent > trace.uniform
          ? 'over an even guess'
          : 'under an even guess';
      return '${StreamTable.placeName(view, view.position)} gave ${trace.token(view.target)} $percentage: '
          '−ln $share = $written nats, $than';
    }
    if (beat < _rise.$1) {
      return 'Target y, as Shift made it: ${grouped(trace.targetCount)} targets across '
          '${spelled(trace.peptides.length)} peptides';
    }
    if (beat < _level.$1) {
      double least = double.infinity;
      double most = 0;
      for (final List<double> costs in surprises(view)) {
        for (final double cost in costs) {
          least = math.min(least, cost);
          most = math.max(most, cost);
        }
      }
      return "Every target's −ln p(y), as ${StreamTable.placeName(view, view.position)}'s: "
          'from ${cost(least)} to ${cost(most)} nats';
    }
    return mean(view);
  }

  /// The step's loss, set against what the checkpoint was kept for passing,
  /// or else against an even guess.
  static String mean(LmView view) {
    final TrainingTrace trace = view.trace;
    final double loss = trace.loss(view.step);
    final String head = 'The loss, their mean: ${nats(loss)} nats';
    final List<String> why = view.checkpoint.why;
    if (why.contains('uniform')) {
      return '$head, first under an even guess, ${nats(trace.uniform)}';
    }
    if (why.contains('unigram')) {
      return '$head, first under residue counts, ${nats(trace.unigram)}';
    }
    if (why.contains('bigram')) {
      return '$head, first under residue pairs, ${nats(trace.bigram)}';
    }
    if (why.contains('one_nat')) {
      return '$head, the first step under one nat';
    }
    if (why.contains('tenth_nat')) {
      return '$head, the first step under a tenth of one';
    }
    if (why.contains('last')) {
      return '$head; the floor here is ${nats(trace.floor)}';
    }
    return loss > trace.uniform
        ? '$head, worse than an even guess, ${nats(trace.uniform)}'
        : '$head, under an even guess, ${nats(trace.uniform)}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Loss, step ${view.step}. ${caption(view, frame)}.';
}

/// −ln p(y)'s chart on the bench: p(y) from 0 to 100% along, its cost in
/// nats from 0 to [ceiling] up.
@immutable
final class LossChart {
  const LossChart({required this.area, required this.ceiling});

  final Rect area;
  final double ceiling;

  /// Where (share [p], cost [nats]) is drawn.
  Offset at(double p, double nats) => Offset(
    area.left + area.width * p.clamp(0.0, 1.0),
    area.bottom - area.height * (nats / ceiling).clamp(0.0, 1.0),
  );
}

/// Loss's canvas, on Predict's, which is on Embedding's: the note over it and
/// the tag at its top left, where they were. While the table shows, the map's
/// cells and the key as Predict left them, each row's lit slot gathering into
/// the map's last column, beside its y; the bench, between the rows' tiles
/// and that column, over the places' rows, holds −ln p(y)'s chart. Then the
/// batch, as Shift drew target y, in Shift's columns: a line a peptide, its
/// name over a room for its targets' bars over its tiles, padding and all;
/// the lines centred in the room the table had, and the legend under them.
final class LossLayout {
  LossLayout(this.size, LmView view)
    : predict = PredictLayout(size, view),
      _view = view {
    final TrainingTrace trace = view.trace;
    final StreamTable table = predict.table;
    final EmbeddingLayout e = table.layout;
    final int n = view.focus.inputs;
    lastColumn = trace.allowed.length - 1;
    final double ceiling = LossScene.ceiling(view);

    // The bench, and the chart in it: room left of the plot for its numbers,
    // above it for its name, under it for its own.
    final Rect bench = Rect.fromLTRB(
      predict.mapLeft + 2,
      table.row(0).top,
      keySlot(0).left - _benchGap,
      table.row(n - 1).bottom,
    );
    final double numbers = view.kit.layout('8.888', inked(view.kit.mono, 9, view.inks.ink)).width + 8;
    final double left = bench.left + numbers;
    final double width = math.max(0.0, bench.right - _plotRight - left);
    final double room = math.max(0.0, bench.height - _plotTop - _plotBottom);
    final double height = math.min(width * _aspect, room);
    final double middle = bench.top + _plotTop + room / 2;
    chart = LossChart(area: Rect.fromLTWH(left, middle - height / 2, width, height), ceiling: ceiling);

    // The batch: Shift's columns, a target each.
    columns = trace.width;
    batchLeft = _batchLeft;
    final double right = size.width - _batchRight;
    step = math.min(_mostStep, (right - batchLeft) / columns);
    tileHeight = math.max(step, math.min(step * _tallTile, _mostTile));
    final TextStyle legendStyle = inked(view.kit.mono, 9, view.inks.ink);
    legendHeight = view.kit.layout(LossScene.lossText(view), legendStyle).height;
    lossItem = LossScene._swatch + 5 + view.kit.layout(LossScene.lossText(view), legendStyle).width + _legendItemGap;
    final double top = e.tableTop;
    final double bottom = size.height - _edge - legendHeight - _legendGap;
    final int lines = trace.peptides.length;
    final double fixed = lines * (ShiftLayout.label + tileHeight) + (lines - 1) * _lineGap;
    barRoom = ((bottom - top - fixed) / lines).clamp(_leastBars, _mostBars);
    pitch = ShiftLayout.label + barRoom + tileHeight + _lineGap;
    final double block = lines * pitch - _lineGap;
    firstLine = top + math.max(0.0, (bottom - top - block) / 2);
    legendTop = firstLine + block + _legendGap;
  }

  final Size size;

  /// Predict's layout, which the stage opens on.
  final PredictLayout predict;
  final LmView _view;

  StreamTable get table => predict.table;

  /// From the bench to the gathered column; the room right of the plot, over
  /// it and under it; and how tall the plot is, of its width, at most.
  static const double _benchGap = 8;
  static const double _plotRight = 6;
  static const double _plotTop = 18;
  static const double _plotBottom = 28;
  static const double _aspect = 0.95;

  /// The batch's columns, Shift's: their left edge, and the room at the
  /// right; how wide a column is at most, and how tall a tile is, of its
  /// width, and at most.
  static const double _batchLeft = 20;
  static const double _batchRight = 16;
  static const double _mostStep = 22;
  static const double _tallTile = 1.25;
  static const double _mostTile = 14;

  /// Between two lines, the bars' room at the least and at the most, from
  /// the canvas's foot, from the lines to the legend, and between its items.
  static const double _lineGap = 8;
  static const double _leastBars = 18;
  static const double _mostBars = 60;
  static const double _edge = 6;
  static const double _legendGap = 10;
  static const double _legendItemGap = 16;

  /// The map's last column, where each row's lit slot gathers.
  late final int lastColumn;

  late final LossChart chart;

  /// The batch's columns: how many, where they start, how wide each is, and
  /// how tall its tiles.
  late final int columns;
  late final double batchLeft;
  late final double step;
  late final double tileHeight;

  /// A line's room for its bars, from one line's top to the next, and where
  /// the first starts.
  late final double barRoom;
  late final double pitch;
  late final double firstLine;

  /// The legend: its top, its height, and how far its first item reaches.
  late final double legendTop;
  late final double legendHeight;
  late final double lossItem;

  /// Row [i]'s lit cell, [gather] of the way from the map's column of what
  /// came next to the last.
  Rect answerCell(int i, double gather) {
    final TrainingTrace trace = _view.trace;
    final Rect from = predict.mapCell(i, trace.allowedIndex(trace.targetAt(_view.peptide, i)));
    if (gather <= 0) {
      return from;
    }
    return Rect.lerp(from, predict.mapCell(i, lastColumn), gather)!;
  }

  /// Row [i]'s slot once gathered, beside the key.
  RRect keySlot(int i) => PredictScene.slotOf(predict.mapCell(i, lastColumn));

  /// Where line [p] starts, its name; and its tiles' top, which its bars
  /// stand on.
  double lineTop(int p) => firstLine + p * pitch;

  double base(int p) => lineTop(p) + ShiftLayout.label + barRoom;

  /// Line [p]'s tile at place [i].
  Rect tile(int p, int i) => Rect.fromLTWH(batchLeft + i * step, base(p), step, tileHeight);

  /// The card under the line in focus, round its name, bars and tiles.
  Rect card(int p) => Rect.fromLTRB(batchLeft - 6, lineTop(p) - 3, batchLeft + columns * step + 6, base(p) + tileHeight + 3);

  /// The peptide in focus's target at place [i], [s] of the way from its
  /// tile in the key, standing, to its tile on its line, lying, turned as a
  /// strip turns and kept upright.
  Rect swung(int i, double s) {
    final int n = _view.focus.inputs;
    final Rect lying = Rect.fromLTWH(batchLeft, base(_view.peptide), n * step, tileHeight);
    final Rect key = predict.answerTile(0);
    final Rect standing = Rect.fromLTRB(key.left, table.row(0).top, key.right, table.row(n - 1).bottom);
    final Offset centre = StreamTable.turnedAt(from: lying, to: standing, f: 1 - s, along: (i + 0.5) / n);
    final double chip = key.width;
    return Rect.fromCenter(center: centre, width: chip + (step - chip) * s, height: chip + (tileHeight - chip) * s);
  }

  /// What a tap on the batch asks for: a line puts its peptide in focus, a
  /// target of the focus line its place.
  LmHit? hitAt(Offset at) {
    for (int p = 0; p < _view.trace.peptides.length; p++) {
      if (at.dy < lineTop(p) - 3 || at.dy >= base(p) + tileHeight + 3) {
        continue;
      }
      if (p != _view.peptide) {
        return FocusPeptide(p);
      }
      final int i = ((at.dx - batchLeft) / step).floor();
      return i >= 0 && i < _view.focus.inputs ? FocusPosition(i) : null;
    }
    return null;
  }
}
