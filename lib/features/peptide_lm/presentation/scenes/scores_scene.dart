import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'attention_scene.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'stream_table.dart';
import 'weight_flow.dart';

/// Scores, block 1's attention up to its shares, as the engine works it
/// (the block's first LayerNorm, then `nn.MultiheadAttention`'s own
/// projection, scores and softmax). It opens on Embedding's last frame, x0 a
/// row a place. The table narrows to a strip a place, and a copy of the row
/// in focus stands up beside it: its numbers less their mean, over their
/// spread, then the norm's learned scale and shift, the row attention reads.
/// The model's own weights make a query, a key and a value of the stream's
/// width from it: each part's column stands empty, then the row flows through
/// its weights, the strings into each number lit with what they carry, the
/// number made as they land and the strings left behind, faint, a weight on
/// each, until the next part comes. Each
/// is cut into equal slices, one a head. Every place makes its own, with the
/// same weights. Head 1's query is scored against one key number by number,
/// summed and divided by the root of a head's size, then against every key
/// up to its own place; softmax makes the scores shares; and the divisor
/// taken away and put back shows what it is for. Attention opens on the last
/// frame: head 1's keys, its scores and its shares.
///
/// Every number is the run's: the row, the norm's scale and shift, the
/// weights, the query, keys and scores, whole.
final class ScoresScene extends LmScene {
  const ScoresScene();

  /// The block this stage shows: the one Attention goes on with.
  static const int block = AttentionScene.block;

  static double get _beats => LmStage.scores.beats.toDouble();

  // The open: Embedding's note goes, and the row in focus is outlined.
  static const (double, double) _noteOut = (0.0, 0.25);
  static const (double, double) _outline = (0.5, 0.9);

  // A copy lifts off the row in focus and stands up on the bench, as the
  // table's numbers go, the table narrows and the other rows go quiet.
  static const (double, double) _lift = (0.9, 1.3);
  static const (double, double) _numbersOut = (0.9, 1.15);
  static const (double, double) _squeeze = (1.1, 1.9);
  static const (double, double) _quiet = (1.0, 1.6);
  static const (double, double) _stand = (1.3, 2.1);
  static const (double, double) _columnNumbers = (2.0, 2.3);

  // Evened out, on a chart beside it: less the mean, over the spread.
  static const (double, double) _chartIn = (2.1, 2.4);
  static const (double, double) _centre = (2.5, 3.1);
  static const (double, double) _spread = (3.2, 3.8);

  // Then the learned scale and shift, written out where the chart was, a
  // row a number, as the sum it is: z-score × scale + shift = evened. The
  // chart goes as the sum's heads come; each row's scale and shift, then its
  // result; then the evened numbers take the z-scores' place.
  static const (double, double) _formulaIn = (3.9, 4.2);
  static const (double, double) _terms = (4.2, 4.8);
  static const (double, double) _results = (4.8, 5.6);
  static const (double, double) _learned = (5.8, 6.2);
  static const (double, double) _formulaOut = (5.8, 6.1);

  // The query, the key and the value, each from the same row through its own
  // weights, one part after the other. A part's column stands as empty
  // slots, with no strings yet; then the row flows through its weights, each
  // number's strings lit out of the row into it, the number made as they
  // land, and the strings left behind, faint: the part's weights, a string
  // each, named on a plate under them. A part's strings go as the next
  // part's slots come.
  static const List<(double, double)> _slotsIn = <(double, double)>[(6.6, 6.9), (10.35, 10.55), (11.45, 11.65)];
  static const (double, double) _plateIn = (6.95, 7.25);
  static const (double, double) _plateOut = (12.5, 12.7);

  // The fans: the query's first three numbers on their own, the first
  // slowly, then the rest of the query in one cascade; the key's and the
  // value's each one cascade.
  static const List<WeightFlow> _flows = <WeightFlow>[
    WeightFlow(
      alone: <(double, double)>[(6.95, 7.55), (7.7, 8.0), (8.05, 8.3)],
      cascade: (8.35, 9.2),
      webOut: (10.35, 10.6),
      firstRelax: 0.3,
    ),
    WeightFlow(cascade: (10.6, 11.375), webOut: (11.45, 11.7)),
    WeightFlow(cascade: (11.7, 12.475), webOut: (12.5, 12.7)),
  ];

  // Each cut into a slice a head, the slices named.
  static const (double, double) _cut = (12.7, 13.1);
  static const (double, double) _headNames = (12.9, 13.2);
  static const (double, double) _otherHeads = (13.2, 13.5);

  // Every place: the bench clears, head 1's query and key lie down by the
  // row in focus, every place's key comes out of its row.
  static const (double, double) _networkOut = (13.5, 13.8);
  static const (double, double) _queryDown = (13.6, 14.3);
  static const (double, double) _keyDown = (13.7, 14.4);
  static const double _keysFrom = 14.0;
  static const (double, double) _loud = (13.8, 14.4);
  static const (double, double) _struck = (14.3, 14.7);
  static const (double, double) _named = (14.2, 14.5);

  // One score worked out, on the bench: the query and the top key fly to it,
  // their products come one after another, then the sum and the division,
  // and the score flies to its place.
  static const double _workFrom = 14.8;
  static const (double, double) _lifted = (14.9, 15.4);
  static const (double, double) _cardWords = (15.3, 15.6);
  static const (double, double) _products = (15.5, 16.2);
  static const (double, double) _sum = (16.3, 16.5);
  static const (double, double) _divided = (16.6, 16.8);
  static const (double, double) _scoreFlies = (16.9, 17.3);
  static const (double, double) _cardOut = (16.9, 17.2);

  // The rest: the query passes each key up to `<bos>`, then goes.
  static const (double, double) _scan = (17.3, 18.3);
  static const (double, double) _queryOut = (18.3, 18.6);

  // Softmax: a bar a share, its percentage at its end.
  static const (double, double) _bars = (18.5, 19.2);
  static const (double, double) _percents = (18.9, 19.3);

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats);

  /// The stage's last frame: Attention opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view) => _paint(canvas, size, view, _beats);

  void _paint(Canvas canvas, Size size, LmView view, double beat) {
    final ScoresLayout layout = ScoresLayout(size, view);
    final AttentionLayout attention = layout.attention;
    final StreamTable table = attention.table;
    // Embedding's note goes as this stage's come, and the marks on the two
    // places it names with it, drawn over the rows; its x0 tag stays.
    final double note = 1 - _span(beat, _noteOut);
    const EmbeddingScene().paintEnd(canvas, size, view, EmbeddingFade(rows: false, note: note, twins: 0));
    table.note(canvas, notes(view), beat);
    _stream(canvas, view, layout, beat);
    final double squeeze = _span(beat, _squeeze);
    table.drawTiles(canvas, dx: attention.slide(squeeze));
    EmbeddingScene.markTwins(canvas, view, table.layout, note);
    table.outline(
      canvas,
      view.position,
      attention.stream(view.position, squeeze).right,
      _span(beat, _outline),
      dx: attention.slide(squeeze),
    );
    _evened(canvas, view, layout, beat);
    _network(canvas, view, layout, beat);
    _lieDown(canvas, view, layout, beat);
    _head(canvas, view, layout, beat);
  }

  // ---------------------------------------------------------------- stream

  /// Each place's row of x0: its numbers going as the table narrows, the
  /// others quiet while the row in focus is worked on.
  void _stream(Canvas canvas, LmView view, ScoresLayout layout, double beat) {
    final StreamTable table = layout.attention.table;
    final double squeeze = _span(beat, _squeeze);
    final double text = 1 - _span(beat, _numbersOut);
    final double quiet = _span(beat, _quiet) * (1 - _span(beat, _loud));
    final double scale = table.scale;
    for (int i = 0; i < view.focus.inputs; i++) {
      final List<double> x0 = table.values(0, i);
      final double fade = i == view.position ? 0 : 0.65 * quiet;
      table.drawRow(
        canvas,
        layout.attention.stream(i, squeeze),
        x0,
        scale: scale,
        colors: fade > 0
            ? <Color>[for (final double v in x0) Color.lerp(view.inks.cell(v / scale), view.inks.ground, fade)!]
            : null,
        text: squeeze > 0.02 ? 0 : text,
      );
    }
  }

  // ------------------------------------------------------------ evened out

  /// The row in focus, evened out as the block's first LayerNorm does it.
  static RowEvening evening(LmView view) => view.kit.memo<RowEvening>(
    ('scores-evening', view.step, view.peptide, view.position),
    () => RowEvening(view),
  );

  /// The colour scale of the rows attention reads, over the places in focus.
  static double evenScale(LmView view) => view.kit.memo<double>(
    ('scores-even-scale', view.step, view.peptide),
    () => percentileScale(<double>[
      for (int i = 0; i < view.focus.inputs; i++)
        for (int d = 0; d < view.trace.model.width; d++)
          view.trace.attnInput(view.checkpoint, block, view.peptide, i, d),
    ]),
  );

  /// The row in focus as it is evened out at [beat], and its colours.
  static (List<double>, List<Color>) _evenedAt(LmView view, double beat) {
    final RowEvening even = evening(view);
    final double centre = _span(beat, _centre);
    final double spread = _span(beat, _spread);
    final double learned = _span(beat, _learned);
    final List<double> now = even.at(centre, spread, learned);
    final double toward = (centre + spread + learned) / 3;
    final double x0Scale = streamScales(view).$1;
    final double scale = x0Scale + (evenScale(view) - x0Scale) * toward;
    return (now, <Color>[for (final double v in now) view.inks.cell(v / scale)]);
  }

  /// A copy of the row in focus lifts off and stands up on the bench, its
  /// numbers at its left; a chart at its right shows each step of the
  /// evening out.
  void _evened(Canvas canvas, LmView view, ScoresLayout layout, double beat) {
    final double lift = _span(beat, _lift);
    final double gone = _span(beat, _networkOut);
    if (lift <= 0 || gone >= 1) {
      return;
    }
    final StreamTable table = layout.attention.table;
    final (List<double> now, List<Color> colors) = _evenedAt(view, beat);
    final double stand = _span(beat, _stand);
    final Rect column = layout.columnAt(layout.inputX, 0);
    if (stand < 1) {
      table.strip(
        canvas,
        from: table.row(view.position).shift(Offset(0, -table.layout.pitch * 0.55 * lift)),
        to: column,
        f: stand,
        colors: colors,
        numbers: stand > 0 ? null : now,
        alpha: 0.2 + 0.8 * lift,
        outlined: true,
      );
      return;
    }
    final double alpha = 1 - gone;
    drawColumn(
      canvas,
      (int d) => layout.tileAt(layout.inputX, d, 0),
      <Color>[for (final Color c in colors) c.withValues(alpha: c.a * alpha)],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(column.inflate(1), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.signal.withValues(alpha: 0.85 * alpha),
    );
    drawColumnNumbers(
      canvas,
      view,
      (int d) => layout.tileAt(layout.inputX, d, 0),
      now,
      _span(beat, _columnNumbers) * alpha,
      textSize: layout.textSize,
      writes: layout.writes,
      left: true,
    );
    drawColumnTitle(
      canvas,
      view,
      StreamTable.placeName(view, view.position),
      alpha,
      x: layout.inputX,
      top: layout.columnAt(layout.inputX, 0).top,
    );
    final double chart = _span(beat, _chartIn) * (1 - _span(beat, _formulaIn));
    if (chart > 0) {
      _chart(canvas, view, layout, now, beat, chart);
    }
    _formula(canvas, view, layout, beat, alpha);
  }

  /// The row's numbers as bars from zero, with its mean and a band of one
  /// standard deviation either side of it, bracketed under the chart: less
  /// the mean, the band centres on zero; over the standard deviation, it
  /// spans one either side; the learned scale and shift move each bar
  /// a little, and the band goes.
  void _chart(Canvas canvas, LmView view, ScoresLayout layout, List<double> now, double beat, double alpha) {
    final RowEvening even = evening(view);
    final double centre = _span(beat, _centre);
    final double spread = _span(beat, _spread);
    final double learned = _span(beat, _learned);
    final double half = (layout.chartRight - layout.chartLeft) / 2;
    final double zero = layout.chartLeft + half;
    double xOf(double v) => zero + v / even.reach * half;
    final Rect column = layout.columnAt(layout.inputX, 0);
    // The band and the mean, while they mean what they say.
    final double band = alpha * (1 - learned);
    final double mean = even.mean * (1 - centre);
    final double sd = even.sd / (1 + (even.sd - 1) * spread);
    if (band > 0) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(mean - sd), column.top, xOf(mean + sd), column.bottom),
        Paint()..color = view.inks.rule.withValues(alpha: 0.35 * band),
      );
    }
    dashedLine(
      canvas,
      Offset(zero, column.top - 2),
      Offset(zero, column.bottom + 2),
      Paint()
        ..strokeWidth = 1
        ..color = view.inks.quiet.withValues(alpha: alpha),
    );
    view.kit.draw(
      canvas,
      '0',
      inked(view.kit.mono, 8.5, view.inks.quiet, alpha: alpha),
      Offset(zero, column.bottom + 4),
      anchor: const Offset(0.5, 0),
    );
    final Paint paint = Paint();
    // x0's bars, outlined, while the bars move away from them.
    final double ghost = alpha * math.min(1, (centre + spread + learned) * 3) * (1 - learned * 0.5);
    final Paint was = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = view.inks.quiet.withValues(alpha: 0.8 * ghost);
    for (int d = 0; d < now.length; d++) {
      final Rect tile = layout.tileAt(layout.inputX, d, 0);
      final double thick = (tile.height * 0.5).clamp(1.0, 7.0);
      if (ghost > 0) {
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(zero, xOf(even.x[d])),
            tile.center.dy - thick / 2,
            math.max(zero, xOf(even.x[d])),
            tile.center.dy + thick / 2,
          ),
          was,
        );
      }
      canvas.drawRect(
        Rect.fromLTRB(
          math.min(zero, xOf(now[d])),
          tile.center.dy - thick / 2,
          math.max(zero, xOf(now[d])),
          tile.center.dy + thick / 2,
        ),
        paint..color = (now[d] >= 0 ? view.inks.positive : view.inks.negative).withValues(alpha: 0.85 * alpha),
      );
    }
    if (band > 0) {
      canvas.drawLine(
        Offset(xOf(mean), column.top - 1),
        Offset(xOf(mean), column.bottom + 1),
        Paint()
          ..strokeWidth = 1.4
          ..color = view.inks.signal.withValues(alpha: band),
      );
      final TextStyle words = inked(view.kit.sans, 8.5, view.inks.quiet, alpha: band);
      view.kit.draw(canvas, 'mean', words, Offset(xOf(mean), column.top - 3), anchor: const Offset(0.5, 1));
      // One standard deviation, bracketed from the mean under the chart,
      // under its 0, and named under the bracket.
      final double y = column.bottom + 17;
      final Paint bracket = Paint()
        ..strokeWidth = 1
        ..color = view.inks.quiet.withValues(alpha: band);
      canvas.drawLine(Offset(xOf(mean), y), Offset(xOf(mean + sd), y), bracket);
      for (final double x in <double>[xOf(mean), xOf(mean + sd)]) {
        canvas.drawLine(Offset(x, y - 3), Offset(x, y + 3), bracket);
      }
      view.kit.draw(
        canvas,
        '1 standard deviation',
        words,
        Offset((xOf(mean) + xOf(mean + sd)) / 2, y + 5),
        anchor: const Offset(0.5, 0),
      );
    }
  }

  /// The norm's last step written out where the chart was, a row a number:
  /// each z-score times its column's own scale, plus its own shift, the
  /// evened number. Headed so the row reads as the sum, z-score × scale +
  /// shift = evened; at step 1 every scale is 1 and every shift 0.
  void _formula(Canvas canvas, LmView view, ScoresLayout layout, double beat, double alpha) {
    final double shown = _span(beat, _formulaIn) * (1 - _span(beat, _formulaOut)) * alpha;
    if (shown <= 0 || !layout.writes) {
      return;
    }
    final RowEvening even = evening(view);
    final int width = view.trace.model.width;
    final TextStyle face = inked(view.kit.mono, layout.textSize, view.inks.ink);
    final double step = view.kit.layout('× −8.88', face).width + 10;
    final List<double> xs = <double>[layout.chartLeft, layout.chartLeft + step, layout.chartLeft + 2 * step];
    final Rect column = layout.columnAt(layout.inputX, 0);
    // The heads: the numbers left of the row are its z-scores, then each
    // column of terms.
    final TextStyle words = inked(view.kit.sans, 9, view.inks.quiet, alpha: shown);
    // Clear of the row's own name, over its tiles.
    final double name = view.kit
        .layout(StreamTable.placeName(view, view.position), inked(view.kit.sans, 9, view.inks.quiet))
        .width;
    view.kit.draw(
      canvas,
      'z-score',
      words,
      Offset(math.min(column.left, layout.inputX - name / 2) - 6, column.top - 4),
      anchor: const Offset(1, 1),
    );
    for (final (int k, String head) in <(int, String)>[(0, '× scale'), (1, '+ shift'), (2, '= evened')]) {
      view.kit.draw(canvas, head, words, Offset(xs[k], column.top - 4), anchor: const Offset(0, 1));
    }
    final double fade = 1 - _span(beat, _formulaOut);
    TextStyle at(double a) => face.copyWith(color: face.color!.withValues(alpha: ((a * fade * alpha) * 8).round() / 8));
    for (int d = 0; d < width; d++) {
      final double y = layout.tileAt(layout.inputX, d, 0).center.dy;
      final double lag = 0.45 * d / math.max(1, width - 1);
      final double terms = through(beat, _terms.$1 + lag * (_terms.$2 - _terms.$1), _terms.$1 + lag * (_terms.$2 - _terms.$1) + 0.2);
      final double result = through(beat, _results.$1 + lag * (_results.$2 - _results.$1), _results.$1 + lag * (_results.$2 - _results.$1) + 0.25);
      final double shift = even.shift[d];
      if (terms > 0) {
        view.kit.draw(canvas, '× ${fixed(even.scale[d], 2)}', at(terms), Offset(xs[0], y), anchor: const Offset(0, 0.5));
        view.kit.draw(
          canvas,
          '${shift < 0 && fixed(-shift, 2) != '0.00' ? '−' : '+'} ${fixed(shift.abs(), 2)}',
          at(terms),
          Offset(xs[1], y),
          anchor: const Offset(0, 0.5),
        );
      }
      if (result > 0) {
        view.kit.draw(canvas, '= ${fixed(even.evened[d], 2)}', at(result), Offset(xs[2], y), anchor: const Offset(0, 0.5));
      }
    }
  }

  // --------------------------------------------------------------- network

  static const List<String> _parts = <String>['query', 'key', 'value'];

  /// The evened row through each part's weights: the part's empty slots; the
  /// row flowing through its weights, a fan of strings lit into each number,
  /// the number made as they land and the strings left behind, faint; the
  /// plate naming the weights; then each column cut into a slice a head.
  void _network(Canvas canvas, LmView view, ScoresLayout layout, double beat) {
    final double shown = 1 - _span(beat, _networkOut);
    if (beat < _slotsIn.first.$1 || shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int size = trace.headSize;
    final double cut = _span(beat, _cut);
    final double others = 1 - 0.65 * _span(beat, _otherHeads);
    // Each part's strings first, under every column, one part's at a time:
    // those that have landed left faint, quieter while the row flows, and
    // those running lit.
    for (int part = 0; part < 3; part++) {
      final WeightFlow flow = _flows[part];
      final double web = flow.webShown(width, beat) * shown;
      if (web > 0) {
        Offset from(int d) => layout.tileAt(layout.inputX, d, 0).centerRight;
        Offset to(int out) => layout.tileAt(layout.outputX[part], out, cut).centerLeft;
        double weight(int out, int d) => _weight(view, part, out, d);
        drawWeights(
          canvas,
          view,
          flow,
          inputs: width,
          outputs: width,
          weight: weight,
          from: from,
          to: to,
          most: _weightReach(view, part),
          beat: beat,
          alpha: web,
        );
        drawFans(
          canvas,
          view,
          flow,
          input: evening(view).evened,
          outputs: width,
          weight: weight,
          from: from,
          to: to,
          most: _productReach(view, part),
          beat: beat,
          alpha: web,
        );
      }
    }
    // The columns already made are one card the later strings pass behind,
    // from the query's to the last made, their numbers clear of them.
    for (int part = 1; part < 3; part++) {
      _backing(canvas, view, layout, layout.outputX[0], layout.outputX[part - 1], cut, _flows[part].webShown(width, beat) * shown);
    }
    for (int part = 0; part < 3; part++) {
      final (double slotsFrom, double slotsTo) = _slotsIn[part];
      if (beat < slotsFrom) {
        continue;
      }
      final double standing = through(beat, slotsFrom, slotsTo) * shown;
      // Head 1's query and key lie down by the row in focus from here on.
      final bool lying = part < 2 && beat >= (part == 0 ? _queryDown : _keyDown).$1;
      final List<double> values = madeOf(view, part);
      final List<double> made = <double>[for (int out = 0; out < width; out++) madeAt(part, out, width, beat)];
      Rect tile(int out) => layout.tileAt(layout.outputX[part], out, cut);
      drawSlots(canvas, view, tile, standing, made);
      drawColumn(canvas, tile, <Color>[
        for (int out = 0; out < width; out++)
          view.inks.signed(values[out] / AttentionScene.qkvScale(view, out ~/ size)).withValues(
            alpha: made[out] *
                (out < size ? (part == 2 ? shown : 1) : others * shown) *
                (lying && out < size ? 0 : 1),
          ),
      ]);
      drawColumnNumbers(
        canvas,
        view,
        tile,
        values,
        shown,
        textSize: layout.textSize,
        writes: layout.writes,
        alphaOf: (int out) => _flows[part].written(out, width, beat) * (out < size ? (lying ? 0 : 1) : others),
      );
      drawColumnTitle(
        canvas,
        view,
        _parts[part],
        standing,
        x: layout.outputX[part],
        top: layout.columnAt(layout.outputX[part], 0).top,
      );
    }
    _plate(canvas, view, layout, beat, shown);
    // The slices named, left of the query's.
    final double names = _span(beat, _headNames) * shown;
    if (names > 0) {
      final TextStyle words = inked(view.kit.sans, 8.5, view.inks.quiet, alpha: names);
      for (int h = 0; h < trace.model.heads; h++) {
        final Rect slice = layout.sliceAt(layout.outputX[0], h);
        final double x = slice.left - 5;
        view.kit.draw(canvas, 'head ${h + 1}', words, Offset(x, slice.center.dy - 1), anchor: const Offset(1, 1));
        view.kit.draw(
          canvas,
          '${h * size + 1}–${(h + 1) * size}',
          words,
          Offset(x, slice.center.dy + 1),
          anchor: const Offset(1, 0),
        );
      }
    }
  }

  /// When the strings into number [out] of [part] run, of [width] numbers:
  /// they leave the evened row at the first and reach the number at the
  /// second. The query's first numbers on their own, the first slowly, then
  /// the rest of it in one cascade; the key's and the value's each one
  /// cascade.
  static (double, double) fanAt(int part, int out, int width) => _flows[part].fanAt(out, width);

  /// How far number [out] of [part] is made at [beat]: it fills as its
  /// strings land.
  static double madeAt(int part, int out, int width, double beat) => _flows[part].madeAt(out, width, beat);

  /// The weight from number [d] of the evened row to number [out] of [part]
  /// at the checkpoint in focus.
  static double _weight(LmView view, int part, int out, int d) =>
      view.trace.projection(view.checkpoint, block, part, out, d);

  /// The largest of [part]'s weights at the checkpoint in focus.
  static double _weightReach(LmView view, int part) => view.kit.memo<double>(
    ('scores-weight-reach', view.step, part),
    () => weightReach(
      view.trace.model.width,
      view.trace.model.width,
      (int out, int d) => _weight(view, part, out, d),
    ),
  );

  /// The largest of what [part]'s strings carry from the row in focus, a
  /// number of it times a weight.
  static double _productReach(LmView view, int part) => view.kit.memo<double>(
    ('scores-product-reach', view.step, view.peptide, view.position, part),
    () {
      final List<double> evened = evening(view).evened;
      return productReach(evened, evened.length, (int out, int d) => _weight(view, part, out, d));
    },
  );

  /// The columns from [first] to [last] and their numbers as one card in
  /// the ground's colour, [alpha] strong, so the strings of a part after
  /// them pass behind.
  static void _backing(Canvas canvas, LmView view, ScoresLayout layout, double first, double last, double cut, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final Rect from = layout.columnAt(first, cut);
    final Rect to = layout.columnAt(last, cut);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(from.left - 3, from.top - 2, to.right + layout.numberWidth + 3, to.bottom + 2),
        const Radius.circular(3),
      ),
      Paint()..color = view.inks.ground.withValues(alpha: alpha),
    );
  }

  /// Where the weights stand at the checkpoint in focus: the run's random
  /// start, and the updates since.
  static String weightsStatus(LmView view) {
    final TrainingTrace trace = view.trace;
    final String start = 'random start (seed ${trace.config.seed})';
    final int updates = view.step - trace.checkpoints.first.step;
    if (updates <= 0) {
      return '$start, no update yet';
    }
    return '$start, then ${grouped(updates)} training ${updates == 1 ? 'update' : 'updates'}';
  }

  /// How strongly [part]'s plate shows at [beat]: each comes once the one
  /// before has gone, never over it.
  static double _plateShown(int part, double beat) {
    final double into = part == 0
        ? _span(beat, _plateIn)
        : through(beat, _slotsIn[part].$1 + 0.1, _slotsIn[part].$1 + 0.2);
    final double out = part < 2
        ? through(beat, _slotsIn[part + 1].$1, _slotsIn[part + 1].$1 + 0.1)
        : _span(beat, _plateOut);
    return into * (1 - out);
  }

  /// The weights named under their strings, as x0's table is named over
  /// it: whose they are and how many, on a plate; under it, where they
  /// stand, the run's random start and the updates since.
  void _plate(Canvas canvas, LmView view, ScoresLayout layout, double beat, double shown) {
    final int width = view.trace.model.width;
    String named(int part) => '${_parts[part]} weights · $width × $width';
    for (int part = 0; part < 3; part++) {
      final double alpha = _plateShown(part, beat) * shown;
      if (alpha > 0) {
        drawTag(canvas, view, named(part), layout.plateAt(tagSize(view, named(part))).topLeft, alpha: alpha);
      }
    }
    final double status = _span(beat, _plateIn) * (1 - _span(beat, _plateOut)) * shown;
    if (status <= 0) {
      return;
    }
    drawPlateStatus(
      canvas,
      view,
      layout.plateAt(tagSize(view, named(0))),
      weightsStatus(view),
      status,
      left: layout.benchLeft,
      right: layout.right,
    );
  }

  /// The query ([part] 0), key (1) or value (2) of the place in focus, the
  /// heads' slices side by side: the stream's width.
  static List<double> madeOf(LmView view, int part) {
    final TrainingTrace trace = view.trace;
    final int size = trace.headSize;
    return <double>[
      for (int out = 0; out < trace.model.width; out++)
        switch (part) {
          0 => trace.query(view.checkpoint, block, out ~/ size, view.peptide, view.position, out % size),
          1 => trace.key(view.checkpoint, block, out ~/ size, view.peptide, view.position, out % size),
          _ => trace.value(view.checkpoint, block, out ~/ size, view.peptide, view.position, out % size),
        },
    ];
  }

  /// Head 1's slices of the query and key lying down by the row in focus:
  /// the query over its key, the key in its place.
  void _lieDown(Canvas canvas, LmView view, ScoresLayout layout, double beat) {
    final AttentionLayout attention = layout.attention;
    final int focus = view.position;
    final int size = view.trace.headSize;
    for (final (int part, (double, double) down) in <(int, (double, double))>[(0, _queryDown), (1, _keyDown)]) {
      final double f = _span(beat, down);
      if (beat < down.$1 || f >= 1) {
        continue;
      }
      final List<double> values = madeOf(view, part);
      final double scale = AttentionScene.qkvScale(view, 0);
      attention.table.strip(
        canvas,
        from: part == 0 ? AttentionScene.queryAt(attention, focus, focus.toDouble()) : attention.kv(focus),
        to: layout.sliceAt(layout.outputX[part], 0),
        f: 1 - f,
        colors: <Color>[for (int d = 0; d < size; d++) view.inks.signed(values[d] / scale)],
        outlined: part == 0,
        lyingGap: 0.5,
        lyingRadius: 1.5,
      );
    }
  }

  // ------------------------------------------------------------------ head

  /// The key of the place in focus's query scores highest, the one worked
  /// out in full: the first of the highest.
  static int topKey(LmView view) {
    int top = 0;
    for (int j = 1; j <= view.position; j++) {
      if (_score(view, j) > _score(view, top)) {
        top = j;
      }
    }
    return top;
  }

  static double _score(LmView view, int j) =>
      view.trace.score(view.checkpoint, block, 0, view.peptide, view.position, j);

  /// Head 1 at the place in focus: every place's key, the query, one score
  /// worked out, every score, the shares; as Attention opens on them.
  void _head(Canvas canvas, LmView view, ScoresLayout layout, double beat) {
    if (beat < _queryDown.$1) {
      return;
    }
    final AttentionLayout attention = layout.attention;
    final int focus = view.position;
    final int n = view.focus.inputs;
    final bool landed = beat >= _keyDown.$2;
    AttentionScene.drawStrips(
      canvas,
      view,
      attention,
      0,
      grow: (int j) => j == focus
          ? (landed ? 1 : 0)
          : through(beat, _keysFrom + 0.4 * j / math.max(1, n - 1), _keysFrom + 0.4 * j / math.max(1, n - 1) + 0.3),
    );
    AttentionScene.drawHatch(canvas, view, attention, _span(beat, _struck));
    _scores(canvas, view, layout, beat);
    _card(canvas, view, layout, beat);
    final double query = beat >= _queryDown.$2 ? 1 - _span(beat, _queryOut) : 0;
    AttentionScene.drawQuery(canvas, view, attention, 0, AttentionScene.scanRow(beat, _scan.$1, _scan.$2, focus), query);
    drawShares(canvas, view, attention, grow: _span(beat, _bars), labels: _span(beat, _percents));
    AttentionScene.drawHeadTag(canvas, view, attention, 0, 'query and keys', _span(beat, _named));
  }

  /// Each score beside its key: the one worked out first, landing, then each
  /// as the query passes it.
  void _scores(Canvas canvas, LmView view, ScoresLayout layout, double beat) {
    if (beat < _scoreFlies.$1) {
      return;
    }
    final AttentionLayout attention = layout.attention;
    final int focus = view.position;
    final int top = topKey(view);
    final double row = AttentionScene.scanRow(beat, _scan.$1, _scan.$2, focus);
    for (int j = 0; j <= focus; j++) {
      final double reached = j == top
          ? (beat >= _scoreFlies.$2 ? 1 : 0)
          : beat < _scan.$1
          ? 0
          : (j - row + 1).clamp(0.0, 1.0);
      AttentionScene.drawScore(canvas, view, attention, j, _score(view, j), reached);
    }
    // The score worked out, flying from the bench to its place.
    final double fly = _span(beat, _scoreFlies);
    if (fly < 1) {
      final Rect cell = attention.score(top);
      final Offset from = layout.resultAt(view, _score(view, top));
      view.kit.draw(
        canvas,
        fixed(_score(view, top), 2),
        inked(view.kit.mono, attention.textSize, view.inks.ink),
        Offset.lerp(from, Offset(cell.right, cell.center.dy), fly)!,
        anchor: const Offset(1, 0.5),
      );
    }
  }

  /// One score worked out on the bench: the query of the place in focus over
  /// the key it scores highest, their products number by number, the sum,
  /// and the sum over the root of a head's size.
  void _card(Canvas canvas, LmView view, ScoresLayout layout, double beat) {
    if (beat < _workFrom || beat >= _cardOut.$2) {
      return;
    }
    final AttentionLayout attention = layout.attention;
    final TrainingTrace trace = view.trace;
    final int focus = view.position;
    final int size = trace.headSize;
    final int top = topKey(view);
    final double alpha = 1 - _span(beat, _cardOut);
    final double scale = AttentionScene.qkvScale(view, 0);
    // The key it scores, outlined in its column.
    canvas.drawRRect(
      RRect.fromRectAndRadius(attention.kv(top).inflate(1), const Radius.circular(2.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.signal.withValues(alpha: through(beat, _workFrom, _workFrom + 0.2) * alpha),
    );
    final List<double> q = <double>[for (int d = 0; d < size; d++) trace.query(view.checkpoint, block, 0, view.peptide, focus, d)];
    final List<double> k = <double>[for (int d = 0; d < size; d++) trace.key(view.checkpoint, block, 0, view.peptide, top, d)];
    final List<double> products = <double>[for (int d = 0; d < size; d++) q[d] * k[d]];
    final double fly = _span(beat, _lifted);
    for (final (int r, Rect from, List<double> values) in <(int, Rect, List<double>)>[
      (0, AttentionScene.queryAt(attention, focus, focus.toDouble()), q),
      (1, attention.kv(top), k),
    ]) {
      final Rect at = Rect.lerp(from, layout.cardRow(r), fly)!;
      attention.table.layout.fill(
        canvas,
        at,
        <Color>[for (final double v in values) view.inks.signed(v / scale).withValues(alpha: alpha)],
        gap: 0.5,
        radius: 1.5,
      );
      _cardNumbers(canvas, view, layout, r, values, (fly >= 1 ? 1 : 0) * _span(beat, _cardWords) * alpha);
    }
    // The products, one after another.
    final double most = products.fold<double>(1e-9, (double m, double p) => math.max(m, p.abs()));
    final Rect productRow = layout.cardRow(2);
    final double cell = productRow.width / size;
    final double each = (_products.$2 - _products.$1) / size;
    for (int d = 0; d < size; d++) {
      final double shown = through(beat, _products.$1 + d * each, _products.$1 + d * each + 0.15) * alpha;
      if (shown <= 0) {
        continue;
      }
      attention.table.layout.fill(
        canvas,
        Rect.fromLTWH(productRow.left + d * cell, productRow.top, cell, productRow.height),
        <Color>[view.inks.signed(products[d] / most).withValues(alpha: shown)],
        gap: 0.5,
        radius: 1.5,
      );
      _cardNumber(canvas, view, layout, 2, d, products[d], shown);
    }
    // What each row is, over it.
    final double words = _span(beat, _cardWords) * alpha;
    if (words > 0) {
      final TextStyle style = inked(view.kit.sans, 8.5, view.inks.quiet, alpha: words);
      final String name = StreamTable.placeName(view, focus);
      final String key = top == focus ? 'its own key' : "${StreamTable.placeName(view, top)}'s key";
      for (final (int r, String text) in <(int, String)>[
        (0, "$name's query"),
        (1, key),
        (2, 'multiplied, number by number'),
      ]) {
        view.kit.draw(canvas, text, style, layout.cardRow(r).topLeft - const Offset(0, 2), anchor: const Offset(0, 1));
      }
    }
    // The sum, and the sum over the root.
    final double dot = products.reduce((double a, double b) => a + b);
    view.kit.draw(
      canvas,
      'Σ = ${fixed(dot, 2)}',
      inked(view.kit.mono, 9, view.inks.ink, alpha: _span(beat, _sum) * alpha),
      layout.sumAt,
    );
    final double divided = _span(beat, _divided) * alpha;
    if (divided > 0) {
      view.kit.draw(
        canvas,
        '${fixed(dot, 2)} ÷ √$size = ',
        inked(view.kit.mono, 9, view.inks.ink, alpha: divided),
        layout.dividedAt,
      );
      if (beat < _scoreFlies.$1) {
        view.kit.draw(
          canvas,
          fixed(_score(view, top), 2),
          inked(view.kit.mono, layout.attention.textSize, view.inks.ink, alpha: divided),
          layout.resultAt(view, _score(view, top)),
          anchor: const Offset(1, 0.5),
        );
      }
    }
  }

  void _cardNumbers(Canvas canvas, LmView view, ScoresLayout layout, int row, List<double> values, double alpha) {
    for (int d = 0; d < values.length; d++) {
      _cardNumber(canvas, view, layout, row, d, values[d], alpha);
    }
  }

  void _cardNumber(Canvas canvas, LmView view, ScoresLayout layout, int row, int d, double value, double alpha) {
    final TextStyle? style = layout.cardStyle;
    if (style == null || alpha <= 0) {
      return;
    }
    final Rect at = layout.cardRow(row);
    final double cell = at.width / view.trace.headSize;
    view.kit.draw(
      canvas,
      fixed(value, 2),
      style.copyWith(color: style.color!.withValues(alpha: (alpha * 8).round() / 8)),
      Offset(at.left + (d + 0.5) * cell, at.center.dy),
      anchor: const Offset(0.5, 0.5),
    );
  }

  /// Head 1's shares at the place in focus, a bar each across the bench
  /// [grow] of the way out, each with its percentage at its end.
  static void drawShares(
    Canvas canvas,
    LmView view,
    AttentionLayout layout, {
    double grow = 1,
    double labels = 1,
    double alpha = 1,
  }) {
    if (alpha <= 0 || grow <= 0) {
      return;
    }
    final List<double> shown = AttentionScene.shares(view, 0);
    final Paint fill = Paint()..color = view.inks.signal.withValues(alpha: 0.85 * alpha);
    final TextStyle words = inked(view.kit.mono, layout.textSize, view.inks.ink, alpha: labels * alpha);
    for (int j = 0; j <= view.position; j++) {
      final Rect bar = layout.bar(j, shown[j] * grow);
      if (bar.width > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(1)), fill);
      }
      if (labels > 0) {
        view.kit.draw(canvas, percent(shown[j]), words, Offset(bar.right + 3, bar.center.dy), anchor: const Offset(0, 0.5));
      }
    }
  }

  // ------------------------------------------------------------------- taps

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) => StreamTable(size, view).placeAt(at);

  // ---------------------------------------------------------------- caption

  /// Why each part happens, over the table, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int heads = trace.model.heads;
    final int size = trace.headSize;
    return <(double, double, String)>[
      (
        0.25,
        1.4,
        'A place still knows only itself: which residue, and where.\n'
            'Attention lets it read the places up to its own, never those after.',
      ),
      (
        1.4,
        _slotsIn.first.$1,
        "LayerNorm evens out each place's row: less its mean, over its\n"
            'standard deviation (a z-score); then a learned scale and shift\n'
            'for each column, so every row reaches attention on one scale',
      ),
      (
        _slotsIn.first.$1,
        _cut.$1,
        'query: what a place looks for; key: what it offers; value: what\n'
            "it hands over when read; each from the model's own weights,\n"
            'random at first and nudged by every training step',
      ),
      (
        _cut.$1,
        _workFrom,
        'one query, key and value of $width a place, cut in equal slices:\n'
            '$width ÷ $heads heads = $size numbers a head, so the model refuses\n'
            'a width its heads do not divide; that $size is the √$size of the score',
      ),
      (
        _workFrom,
        _scan.$2,
        'a score: the query and a key multiplied number by number,\n'
            'summed, over √$size: high where the two agree in sign and size;\n'
            '${StreamTable.placeName(view, view.position)} never reads the places after it, struck through',
      ),
      lastNote(view),
    ];
  }

  /// The stage's last note, which Attention opens with.
  static (double, double, String) lastNote(LmView view) => (
    _scan.$2,
    double.infinity,
    'softmax: e to each score, over their sum\n'
        'shares that add to 100%, the highest score taking most',
  );

  @override
  String caption(LmView view, TrainingFrame frame) => _caption(view, frame.local * _beats);

  String _caption(LmView view, double beat) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int size = trace.headSize;
    final int heads = trace.model.heads;
    final String focus = StreamTable.placeName(view, view.position);
    final RowEvening even = evening(view);
    final int top = topKey(view);
    final String topName = top == view.position ? 'its own' : "${StreamTable.placeName(view, top)}'s";
    if (beat < _lift.$1) {
      return 'Block 1 of ${trace.model.layers}, attention: first a query, key and value a place';
    }
    if (beat < _centre.$1) {
      return "$focus's row, evened out first: mean ${fixed(even.mean, 2)}, standard deviation ${fixed(even.sd, 2)}";
    }
    if (beat < _spread.$1) {
      return 'Less the mean, ${fixed(even.mean, 2)}: the row centres on zero';
    }
    if (beat < _formulaIn.$1) {
      return 'Over the standard deviation, ${fixed(even.sd, 2)}: each number a z-score';
    }
    if (beat < _results.$1) {
      return 'Then evened = z-score × scale + shift, each column its own';
    }
    if (beat < _slotsIn.first.$1) {
      return even.untrained
          ? 'At step 1 every scale is 1 and every shift 0: evened = z-score'
          : 'Scales and shifts after ${grouped(view.step - 1)} updates: the row attention reads';
    }
    if (beat < fanAt(0, 1, width).$1) {
      // Its bias, where training has given it one: every bias starts at 0.
      final bool biased = trace.projectionBias(view.checkpoint, block, 0, 0) != 0;
      return "Query number 1: $focus's numbers × weights, summed"
          '${biased ? ', + bias' : ''}: ${fixed(madeOf(view, 0).first, 2)}';
    }
    if (beat < fanAt(0, width - 1, width).$2 + 0.15) {
      return 'The other ${grouped(width - 1)} the same way, each through its own $width weights';
    }
    if (beat < _slotsIn[1].$1) {
      return "The query's ${grouped(width * width)} weights: a string each, $width into every number";
    }
    if (beat < _slotsIn[2].$1) {
      return "The key: the same row through the key's own $width × $width weights";
    }
    if (beat < _cut.$1) {
      return 'The value: the same row again, through a third $width × $width';
    }
    if (beat < _networkOut.$1) {
      final String rest = heads > 2 ? ', and so on' : '';
      return 'Cut in ${spelled(heads)}: head 1 takes numbers 1–$size of each, '
          'head 2 ${size + 1}–${2 * size}$rest';
    }
    if (beat < _workFrom) {
      return 'Every place does the same, with the same weights: ${grouped(view.focus.inputs)} keys of $size';
    }
    if (beat < _sum.$1) {
      return "$focus's query times $topName key, number by number: $size products";
    }
    if (beat < _scan.$1) {
      final double dot = _score(view, top) * math.sqrt(size);
      return 'Summed, ${fixed(dot, 2)}; over √$size, ${fixed(_score(view, top), 2)}: $topName score';
    }
    if (beat < _bars.$1) {
      return "$focus's query against each key up to its own: ${grouped(view.position + 1)} "
          '${view.position == 0 ? 'score' : 'scores'}';
    }
    return 'Softmax makes the scores shares of one: ${AttentionScene.readsMost(view, 0)}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Scores, step ${view.step}. ${caption(view, frame)}.';
}

/// A row evened out by a LayerNorm: its numbers [x], their mean and standard
/// deviation, the z-scores, and [evened], what the norm made of them, as the
/// run kept it.
class Evening {
  Evening(this.x, this.evened) {
    final int width = x.length;
    mean = x.reduce((double a, double b) => a + b) / width;
    double variance = 0;
    for (final double v in x) {
      variance += (v - mean) * (v - mean);
    }
    // The engine's epsilon, as its LayerNorm adds it.
    sd = math.sqrt(variance / width + 1e-5);
    z = <double>[for (final double v in x) (v - mean) / sd];
    double most = 1e-6;
    for (final List<double> row in <List<double>>[x, z, evened]) {
      for (final double v in row) {
        most = math.max(most, v.abs());
      }
    }
    reach = most * 1.08;
  }

  final List<double> x;
  late final double mean;
  late final double sd;
  late final List<double> z;
  final List<double> evened;

  /// How far from zero the chart reaches: past every number it draws.
  late final double reach;

  /// Whether the norm left the z-scores as they were, to float32's
  /// precision: its scale still 1 and its shift 0, read off the run's own
  /// numbers where it keeps no scale and shift.
  bool get plain {
    for (int d = 0; d < z.length; d++) {
      if ((evened[d] - z[d]).abs() > 1e-4 * math.max(1, z[d].abs())) {
        return false;
      }
    }
    return true;
  }

  /// The row [centre] of the way less its mean, [spread] of the way over its
  /// standard deviation, then [learned] of the way through the norm's scale
  /// and shift.
  List<double> at(double centre, double spread, double learned) {
    if (learned >= 1) {
      return evened;
    }
    return <double>[
      for (int d = 0; d < x.length; d++)
        learned > 0
            ? z[d] + (evened[d] - z[d]) * learned
            : (x[d] - mean * centre) / (1 + (sd - 1) * spread),
    ];
  }
}

/// The row in focus evened out as the block's first LayerNorm does it: x0's
/// numbers, their mean and standard deviation, the z-scores, and what the
/// norm's learned scale and shift make of them, the row attention reads, as
/// the run kept it.
final class RowEvening extends Evening {
  RowEvening(LmView view)
    : scale = <double>[
        for (int d = 0; d < view.trace.model.width; d++) view.trace.normScale(view.checkpoint, ScoresScene.block, d),
      ],
      shift = <double>[
        for (int d = 0; d < view.trace.model.width; d++) view.trace.normShift(view.checkpoint, ScoresScene.block, d),
      ],
      super(
        <double>[for (int d = 0; d < view.trace.model.width; d++) EmbeddingScene.value(view, view.position, d)],
        <double>[
          for (int d = 0; d < view.trace.model.width; d++)
            view.trace.attnInput(view.checkpoint, ScoresScene.block, view.peptide, view.position, d),
        ],
      );

  final List<double> scale;
  final List<double> shift;

  /// Whether the norm's scale is still all 1 and its shift all 0.
  bool get untrained => scale.every((double s) => s == 1) && shift.every((double s) => s == 0);
}

/// Scores' canvas, on Attention's: the table narrowed to a strip a place, and
/// right of it the bench. While the row in focus is worked on, the bench
/// starts where the scores will be: the evened row standing at its left, its
/// numbers left of it, the chart right of it; then the query, the key and
/// the value standing at the right, the query nearer the row, their numbers
/// right of them, the strings between and the weights' plate under them.
/// Once the keys are out, it starts right of them: one score worked out,
/// then a bar a share.
final class ScoresLayout {
  ScoresLayout(Size size, LmView view) : attention = AttentionLayout(size, view) {
    final TrainingTrace trace = view.trace;
    final StreamTable table = attention.table;
    final EmbeddingLayout e = table.layout;
    width = trace.model.width;
    headSize = trace.headSize;
    heads = trace.model.heads;
    top = table.row(0).top + 4;
    bottom = table.row(view.focus.inputs - 1).bottom - 4;
    tile = math.max(1.0, (bottom - top - (heads - 1) * cutGap) / width);
    textSize = math.min(9.0, tile * 0.72);
    writes = textSize >= EmbeddingLayout.leastNumber;
    final double number = writes
        ? view.kit.layout('−8.88', inked(view.kit.mono, textSize, view.inks.ink)).width + 4
        : 0;
    numberWidth = number;
    right = e.right;
    benchLeft = attention.scoreLeft;
    column = ((right - benchLeft) * 0.045).clamp(8.0, 13.0);
    inputX = benchLeft + number + column / 2;
    chartLeft = inputX + column / 2 + 12;
    chartRight = right - 2;
    // The value at the bench's right, its numbers to the edge, and the key
    // and the query each a step left of the one after: a column, its
    // numbers and a gap that grows with the bench, which brings the query
    // nearer the evened row; never so near that the query's strings have
    // under [leastReach] to run, nor the gap under the old 10.
    final double last = right - number - column / 2;
    final double gap = ((right - benchLeft) * 0.075).clamp(14.0, 26.0);
    final double nearest = (last - column / 2 - (inputX + column / 2) - leastReach) / 2;
    final double step = math.max(column + number + 10, math.min(column + number + gap, nearest));
    outputX = <double>[for (int p = 0; p < 3; p++) last - (2 - p) * step];
    // One score worked out: three rows of a head's numbers, each under its
    // words, then the sum and the sum over the root.
    cardLeft = attention.barLeft;
    final double cardWidth = math.max(1.0, right - cardLeft);
    cardRowHeight = e.pitch.clamp(11.0, 18.0);
    const double words = 12;
    cardPitch = words + cardRowHeight + 6;
    final double card = 3 * cardPitch + 2 * _mathLine;
    cardTop = (top + bottom) / 2 - card / 2;
    final double cell = cardWidth / headSize;
    TextStyle at(double points) => inked(view.kit.mono, points, view.inks.ink).copyWith(letterSpacing: 0);
    final double perPoint = view.kit.layout('−8.88', at(10)).width / 10;
    final double points = (math.min(9, (cell - 3) / perPoint) * 2).floorToDouble() / 2;
    cardStyle = points < EmbeddingLayout.leastNumber ? null : at(points);
    _kit = view.kit;
    _ink = view.inks.ink;
  }

  final AttentionLayout attention;

  late final int width;
  late final int headSize;
  late final int heads;

  /// The bench's columns: from their top to their bottom, through the
  /// rows' height, a tile a number.
  late final double top;
  late final double bottom;
  late final double tile;

  /// The gap between two heads' slices of a column, once cut.
  static const double cutGap = 10;

  /// The columns' numbers: their size, and whether they fit.
  late final double textSize;
  late final bool writes;

  /// How wide a column's numbers are, with their gap from it.
  late final double numberWidth;

  /// The bench's sides.
  late final double benchLeft;
  late final double right;

  /// How wide a standing column is.
  late final double column;

  /// The least room the query's strings have, from the evened row's column
  /// to the query's.
  static const double leastReach = 52;

  /// The evened row's column, and the chart beside it.
  late final double inputX;
  late final double chartLeft;
  late final double chartRight;

  /// The query's, the key's and the value's columns.
  late final List<double> outputX;

  late final double cardLeft;
  late final double cardTop;
  late final double cardPitch;
  late final double cardRowHeight;

  /// The card's numbers, or null where its cells are too small for them.
  late final TextStyle? cardStyle;

  late final LmKit _kit;
  late final Color _ink;

  static const double _mathLine = 14;

  /// Number [d]'s tile in a column at [x], [cut] of the way to its head's
  /// slice.
  Rect tileAt(double x, int d, double cut) {
    final double y = top + (heads - 1) * cutGap * (1 - cut) / 2 + d * tile + (d ~/ headSize) * cutGap * cut;
    return Rect.fromLTWH(x - column / 2, y, column, tile);
  }

  /// A column at [x], [cut] of the way to its slices: from its first tile
  /// to its last.
  Rect columnAt(double x, double cut) => Rect.fromLTRB(
    x - column / 2,
    tileAt(x, 0, cut).top,
    x + column / 2,
    tileAt(x, width - 1, cut).bottom,
  );

  /// The plate naming a part's weights, [plate] in size: centred under the
  /// strings from the evened row to the query, below the columns, inside
  /// the bench.
  Rect plateAt(Size plate) {
    final double centre = (inputX + outputX[0]) / 2;
    final double left = (centre - plate.width / 2).clamp(benchLeft, math.max(benchLeft, right - plate.width));
    return Offset(left, columnAt(inputX, 0).bottom + 10) & plate;
  }

  /// Head [h]'s slice of a column at [x], once cut.
  Rect sliceAt(double x, int h) =>
      Rect.fromLTRB(x - column / 2, tileAt(x, h * headSize, 1).top, x + column / 2, tileAt(x, (h + 1) * headSize - 1, 1).bottom);

  /// The card's row [r]: the query, the key, their products.
  Rect cardRow(int r) => Rect.fromLTWH(cardLeft, cardTop + r * cardPitch + 12, right - cardLeft, cardRowHeight);

  /// Where the sum is written, and the sum over the root.
  Offset get sumAt => Offset(cardLeft, cardTop + 3 * cardPitch + 2);

  Offset get dividedAt => sumAt + const Offset(0, _mathLine);

  /// Where the score worked out is written, at the end of the line that
  /// divides the sum: its right edge, its middle.
  Offset resultAt(LmView view, double score) {
    final int size = view.trace.headSize;
    final double dot = score * math.sqrt(size);
    final TextPainter line = _kit.layout('${fixed(dot, 2)} ÷ √$size = ', inked(_kit.mono, 9, _ink));
    final TextPainter result = _kit.layout(fixed(score, 2), inked(_kit.mono, attention.textSize, _ink));
    return Offset(dividedAt.dx + line.width + result.width, dividedAt.dy + line.height / 2);
  }
}
