import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'attention_scene.dart';
import 'embedding_scene.dart';
import 'forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';
import 'weight_flow.dart';

/// The tokens that can come next in the order the bars stand: the residues,
/// then `<eos>`.
List<int> barOrder(TrainingTrace trace) => <int>[
  for (final int id in trace.allowed)
    if (trace.isResidue(id)) id,
  for (final int id in trace.allowed)
    if (!trace.isResidue(id)) id,
];

/// The biggest the output layer's weights get in the whole run, so a heatmap
/// of them is on one scale at every step.
double headScale(LmView view) => view.kit.memo<double>(('head-scale', view.trace.name), () {
  double most = 1e-6;
  final TraceSteps steps = view.trace.steps;
  for (int s = 0; s < steps.count; s++) {
    double top = 0;
    for (int k = 0; k < view.trace.vocab.length * view.trace.model.width; k++) {
      top = math.max(top, steps.headWeight[s * view.trace.vocab.length * view.trace.model.width + k].abs().toDouble());
    }
    most = math.max(most, top * steps.headWeightScales[s]);
  }
  return most;
});

/// The probability each token that can come next is given at [position] of
/// the peptide in focus, in [barOrder].
List<double> probabilities(LmView view, int position) {
  final TrainingTrace trace = view.trace;
  return <double>[
    for (final int id in barOrder(trace))
      trace.probability(view.checkpoint, view.peptide, position, trace.allowedIndex(id)),
  ];
}

/// Predict: the last row Forward made for the place in focus goes through the
/// output layer, as the engine's `lm_head` takes it, and softmax makes its
/// logits shares. It opens on Forward's last frame, the ladder with its last
/// row outlined. The ladder goes, and the row turns off its slot and stands
/// up at the bench's left. A slot for each token of the vocabulary stands at
/// the right, the token's tile beside it, in id order. The row flows through
/// the output layer's weights, a string each: the top logit first and alone,
/// the rest in one cascade, each made as its strings land, and the strings
/// stay, faint, a weight on each. `<pad>` and `<bos>` never come next: their
/// logits are struck to −∞. The bench clears and the logits slide left; a bar
/// on each token's row grows to e to its logit, and every bar shrinks by
/// their sum into its share; what came next is lit. Then every place at
/// once: each bar goes into a square in a slot, the square's area that share
/// of the slot's, so a place's squares together make one slot, and the slot
/// of what came next takes its row's light; the slots lie down onto the
/// place's row of a map, a row a place and a column a token that can come
/// next. Every other place's squares grow in, and the slot of what came next
/// at each lights, Shift's y, written again at the map's right with the
/// share it was given, which Loss scores: a right and certain guess is one
/// square filling its lit slot.
///
/// Every number is the run's: the last row, the output layer's weights and
/// biases as the step found them, and the logits, whole; the shares are
/// softmax of the logits, as the engine takes it.
final class PredictScene extends LmScene {
  const PredictScene();

  static double get _beats => LmStage.predict.beats.toDouble();

  // The open: Forward's ladder goes and its note gives way; the last row's
  // numbers go, and it turns off its slot into a standing column at the
  // bench's left, its numbers coming back at its left.
  static const (double, double) _ladderOut = (0.1, 0.6);
  static const (double, double) _rowNumbersOut = (0.15, 0.3);
  static const (double, double) _stand = (0.3, 1.1);
  static const (double, double) _columnNumbers = (1.0, 1.3);

  // A slot a token at the right, their tiles top to bottom, and the plate
  // naming the weights under the strings.
  static const (double, double) _slotsIn = (1.3, 1.9);
  static const double _tileIn = 0.25;
  static const (double, double) _plateIn = (1.6, 1.9);

  // The row through the output layer: the top logit alone and slowly, then
  // the rest in one cascade; the strings left behind until the bench clears.
  static const WeightFlow _flow = WeightFlow(
    alone: <(double, double)>[(2.4, 3.1)],
    cascade: (3.5, 4.6),
    webOut: (5.6, 5.8),
    firstRelax: 0.3,
  );

  // The two that can never come next, struck to −∞; then the bench clears
  // and the logits slide left, leaving the room to the bars.
  static const (double, double) _struck = (5.8, 6.2);
  static const (double, double) _benchOut = (6.2, 6.5);
  static const (double, double) _slide = (6.4, 7.0);

  // Softmax: each bar grows to e to its logit, then every bar shrinks by the
  // sum into its share; then what came next is lit.
  static const (double, double) _exp = (7.0, 7.7);
  static const (double, double) _share = (8.2, 8.8);
  static const (double, double) _percents = (8.6, 8.9);
  static const (double, double) _answer = (9.4, 9.7);

  // Every place: the bars go into their squares as the logits go; the map's
  // slots come in and the place's slots lie down onto its row; every other
  // row's squares grow in, top to bottom; what came next at each lights, and
  // the answer key comes in at the right.
  static const (double, double) _tiles = (10.6, 10.9);
  static const (double, double) _logitsOut = (10.6, 10.9);
  static const (double, double) _mapIn = (10.9, 11.2);
  static const (double, double) _lieDown = (10.95, 11.55);
  static const (double, double) _focusOutline = (11.5, 11.7);
  static const (double, double) _rows = (11.7, 12.6);
  static const (double, double) _answers = (12.8, 13.2);

  /// How long a row of the map takes to fill.
  static const double _rowFill = 0.2;

  /// How far a share's square goes from the slot's colour to the accent at
  /// the least, so a small share still reads; a certainty is the accent.
  static const double _fillFloor = 0.5;

  /// How far toward the tracer the slot of what came next is lit: a soft
  /// fill, well under the squares, so the answer never outshouts the guess.
  static const double answerLight = 0.13;

  /// The smallest side a square is drawn with: less is a speck.
  static const double _leastFill = 0.4;

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats, const PredictFade());

  /// The stage's last frame, with [fade] leaving out or fading what the stage
  /// after it draws itself or retires: Loss opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view, [PredictFade fade = const PredictFade()]) =>
      _paint(canvas, size, view, _beats, fade);

  void _paint(Canvas canvas, Size size, LmView view, double beat, PredictFade fade) {
    if (beat <= 0) {
      const ForwardScene().paintEnd(canvas, size, view);
      return;
    }
    final PredictLayout layout = PredictLayout(size, view);
    if (beat < _ladderOut.$2) {
      const ForwardScene().paintEnd(
        canvas,
        size,
        view,
        ForwardFade(ladder: 1 - _span(beat, _ladderOut), note: 0, lastRow: false),
      );
    }
    layout.table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, ForwardScene.notes(view).last.$3), ...notes(view)],
      beat,
      alpha: fade.note,
    );
    _lastRow(canvas, view, layout, beat);
    _bench(canvas, view, layout, beat);
    _bars(canvas, view, layout, beat);
    _map(canvas, view, layout, beat, fade);
  }

  // ------------------------------------------------------------------ data

  /// Every logit the output layer made at place [i] of the peptide in focus,
  /// a token each, in id order, whole.
  static List<double> logits(LmView view, int i) => view.kit.memo<List<double>>(
    ('predict-logits', view.step, view.peptide, i),
    () => <double>[
      for (int r = 0; r < view.trace.vocab.length; r++) view.trace.logit(view.checkpoint, view.peptide, i, r),
    ],
  );

  /// Place [i]'s shares, a token each in id order: softmax of its logits over
  /// the tokens that can come next, worked out from the logits as kept,
  /// whole; 0 for the two that never come next.
  static List<double> shares(LmView view, int i) => view.kit.memo<List<double>>(
    ('predict-shares', view.step, view.peptide, i),
    () {
      final TrainingTrace trace = view.trace;
      final List<double> made = logits(view, i);
      double top = double.negativeInfinity;
      for (final int id in trace.allowed) {
        top = math.max(top, made[id]);
      }
      double total = 0;
      for (final int id in trace.allowed) {
        total += math.exp(made[id] - top);
      }
      return <double>[
        for (int r = 0; r < trace.vocab.length; r++)
          trace.allowedIndex(r) < 0 ? 0 : math.exp(made[r] - top) / total,
      ];
    },
  );

  /// Every place's shares of the tokens that can come next, a row a place, a
  /// column each of them in id order: what the map draws.
  static List<List<double>> allShares(LmView view) => view.kit.memo<List<List<double>>>(
    ('predict-all-shares', view.step, view.peptide),
    () => <List<double>>[
      for (int i = 0; i < view.focus.inputs; i++)
        <double>[for (final int id in view.trace.allowed) shares(view, i)[id]],
    ],
  );

  /// The token place [i] gives most, of those that can come next: the first
  /// of the highest.
  static int top(LmView view, int i) {
    final List<double> made = logits(view, i);
    int best = view.trace.allowed.first;
    for (final int id in view.trace.allowed) {
      if (made[id] > made[best]) {
        best = id;
      }
    }
    return best;
  }

  /// How many of the peptide's places give what came next most.
  static int right(LmView view) {
    int count = 0;
    for (int i = 0; i < view.focus.inputs; i++) {
      if (top(view, i) == view.trace.targetAt(view.peptide, i)) {
        count++;
      }
    }
    return count;
  }

  /// The order the logits are made in: the top one first, alone, then the
  /// rest in id order.
  static List<int> flowOrder(LmView view) {
    final int first = top(view, view.position);
    return <int>[first, for (int r = 0; r < view.trace.vocab.length; r++) if (r != first) r];
  }

  /// The two that never come next, named as the captions name them, with
  /// the glyph each is drawn as: `<pad> (·) and <bos> (<)`.
  static String _blocked(TrainingTrace trace) => <String>[
    for (int r = 0; r < trace.vocab.length; r++)
      if (trace.allowedIndex(r) < 0) '${trace.token(r)} (${glyph(trace, r)})',
  ].join(' and ');

  /// The colour scale of the logits: every place's, of the tokens that can
  /// come next, at this checkpoint.
  static double _logitScale(LmView view) => view.kit.memo<double>(
    ('predict-logit-scale', view.step, view.peptide),
    () => percentileScale(<double>[
      for (int i = 0; i < view.focus.inputs; i++)
        for (final int id in view.trace.allowed) logits(view, i)[id],
    ]),
  );

  /// The largest of the output layer's weights at this checkpoint.
  static double _weightReach(LmView view) => view.kit.memo<double>(
    ('predict-weight-reach', view.step),
    () => weightReach(
      view.trace.vocab.length,
      view.trace.model.width,
      (int out, int d) => view.trace.outputWeight(view.checkpoint, out, d),
    ),
  );

  /// The largest of what the strings carry from the last row, a number of it
  /// times a weight.
  static double _productReach(LmView view, List<double> row) => view.kit.memo<double>(
    ('predict-product-reach', view.step, view.peptide, view.position),
    () => productReach(row, view.trace.vocab.length, (int out, int d) => view.trace.outputWeight(view.checkpoint, out, d)),
  );

  /// A map's cell's slot: the largest square its cell holds, inset as the
  /// tables' tiles are and centred in it, its corners theirs, less on a small
  /// cell; square, so a share's square in it is square too.
  static RRect slotOf(Rect cell) {
    final double side = math.max(0.0, cell.shortestSide - 2 * EmbeddingLayout.gap);
    return RRect.fromRectAndRadius(
      Rect.fromCenter(center: cell.center, width: side, height: side),
      Radius.circular(math.min(EmbeddingLayout.radius, side * 0.2)),
    );
  }

  /// A share's square in [slot]: the slot's own shape, corners and all,
  /// scaled about its centre by the share's square root, so its area is that
  /// share of the slot's and a place's squares together make one slot;
  /// [grown] of the way from nothing.
  static RRect fillOf(RRect slot, double share, {double grown = 1}) {
    final double scale = math.sqrt(share.clamp(0.0, 1.0)) * grown;
    return RRect.fromRectAndRadius(
      Rect.fromCenter(center: slot.center, width: slot.width * scale, height: slot.height * scale),
      Radius.circular(slot.tlRadiusX * scale),
    );
  }

  /// A share's square's colour: the accent, muted for the least of them so
  /// a small share still reads, the accent itself for a certainty.
  static Color fillColour(LmView view, double share) => Color.lerp(
    view.inks.zero,
    view.inks.signal,
    _fillFloor + (1 - _fillFloor) * math.sqrt(share.clamp(0.0, 1.0)),
  )!;

  /// A slot, [shown] as strongly as the map, [lit] of the way to the soft
  /// light that marks what came next.
  static void drawSlot(Canvas canvas, LmView view, RRect slot, {double shown = 1, double lit = 0}) {
    if (shown <= 0) {
      return;
    }
    final Color light = Color.lerp(view.inks.zero, view.inks.truth, answerLight)!;
    canvas.drawRRect(slot, Paint()..color = Color.lerp(view.inks.zero, light, lit)!.withValues(alpha: shown));
  }

  /// A cell of the map at [cell]: its slot, lit [lit] of the way where it is
  /// what came next, and in it [share]'s square, grown [grown] of the way,
  /// all [shown] as strongly as the map.
  static void drawShare(
    Canvas canvas,
    LmView view,
    Rect cell, {
    required double share,
    double grown = 1,
    double shown = 1,
    double lit = 0,
  }) {
    if (shown <= 0) {
      return;
    }
    final RRect slot = slotOf(cell);
    drawSlot(canvas, view, slot, shown: shown, lit: lit);
    final RRect fill = fillOf(slot, share, grown: grown);
    if (math.min(fill.width, fill.height) < _leastFill) {
      return;
    }
    canvas.drawRRect(fill, Paint()..color = fillColour(view, share).withValues(alpha: shown));
  }

  /// The answer key's names over it: what came next, and the share given it,
  /// in a column's name's face.
  static const String answerTitle = 'y';
  static const String givenTitle = 'p(y)';

  static TextStyle titleStyle(LmView view, {double alpha = 1}) =>
      inked(view.kit.sans, 9, view.inks.quiet, alpha: alpha);

  /// The logits' column's name.
  static const String logitsTitle = 'logits';

  /// The plate under the strings: whose weights, and how many.
  static String plateText(LmView view) => 'output layer · ${view.trace.vocab.length} × ${view.trace.model.width}';

  // --------------------------------------------------------------- the row

  /// The place's last row, what Forward made: in its slot of the ladder, its
  /// numbers going; turning off it into a standing column at the bench's
  /// left, outlined; standing, its numbers left of it and its name over it,
  /// until the bench clears.
  void _lastRow(Canvas canvas, LmView view, PredictLayout layout, double beat) {
    final double gone = _span(beat, _benchOut);
    if (gone >= 1) {
      return;
    }
    final StreamTable table = layout.table;
    final TowerLayout tower = layout.tower;
    final Rect slot = tower.slot(tower.points - 1);
    final List<double> row = layout.lastRow;
    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    if (beat < _stand.$1) {
      // As Forward drew it, its numbers going.
      table.drawRow(canvas, slot, row, scale: layout.lastScale, text: 0);
      tower.write(canvas, slot, row, 1 - _span(beat, _rowNumbersOut));
      canvas.drawRRect(
        RRect.fromRectAndRadius(slot.inflate(2), const Radius.circular(3)),
        outline..color = view.inks.signal.withValues(alpha: 0.85),
      );
      return;
    }
    final List<Color> colours = <Color>[for (final double v in row) view.inks.cell(v / layout.lastScale)];
    final double stand = _span(beat, _stand);
    if (stand < 1) {
      table.strip(canvas, from: slot, to: layout.inputColumn, f: stand, colors: colours, outlined: true);
      return;
    }
    final double alpha = 1 - gone;
    drawColumn(canvas, layout.inputTile, <Color>[for (final Color c in colours) c.withValues(alpha: c.a * alpha)]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(layout.inputColumn.inflate(1), const Radius.circular(3)),
      outline..color = view.inks.signal.withValues(alpha: 0.85 * alpha),
    );
    drawColumnNumbers(
      canvas,
      view,
      layout.inputTile,
      row,
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
      top: layout.inputColumn.top,
    );
  }

  // ------------------------------------------------------------- the bench

  /// The output layer at work: a slot a token, its tile beside it; the row's
  /// strings into each, lit as they run, then faint, a weight on each; each
  /// logit made as its strings land and written beside it; the two that never
  /// come next struck; the plate naming the weights. Once the bench clears,
  /// the logits, their numbers and tiles slide left as one, and go as the map
  /// comes.
  void _bench(Canvas canvas, LmView view, PredictLayout layout, double beat) {
    final double out = _span(beat, _logitsOut);
    if (beat < _slotsIn.$1 || out >= 1) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int count = trace.vocab.length;
    final int width = trace.model.width;
    final double cleared = _span(beat, _benchOut);
    final double dx = layout.slideBy * _span(beat, _slide);
    final List<int> order = flowOrder(view);
    final List<int> rank = List<int>.filled(count, 0);
    for (int k = 0; k < count; k++) {
      rank[order[k]] = k;
    }
    final List<double> made = logits(view, view.position);
    final List<double> row = layout.lastRow;
    // The strings, under the columns: those landed faint, those running lit.
    final double web = _flow.webShown(count, beat) * (1 - cleared);
    if (web > 0) {
      Offset from(int d) => layout.inputTile(d).centerRight;
      Offset to(int k) => layout.logitTile(order[k], 0).centerLeft;
      double weight(int k, int d) => trace.outputWeight(view.checkpoint, order[k], d);
      drawWeights(
        canvas,
        view,
        _flow,
        inputs: width,
        outputs: count,
        weight: weight,
        from: from,
        to: to,
        most: _weightReach(view),
        beat: beat,
        alpha: web,
      );
      drawFans(
        canvas,
        view,
        _flow,
        input: row,
        outputs: count,
        weight: weight,
        from: from,
        to: to,
        most: _productReach(view, row),
        beat: beat,
        alpha: web,
      );
    }
    final double shown = 1 - out;
    final double struck = _span(beat, _struck);
    // The two's numbers go before −∞ comes, never printed over each other.
    final double middle = (_struck.$1 + _struck.$2) / 2;
    final double unwritten = through(beat, _struck.$1, middle);
    final double infinite = through(beat, middle, _struck.$2);
    final List<double> landed = <double>[for (int k = 0; k < count; k++) _flow.madeAt(k, count, beat)];
    double dimmed(int r) => trace.allowedIndex(r) < 0 ? 1 - 0.6 * struck : 1;
    drawSlots(canvas, view, (int k) => layout.logitTile(order[k], dx), through(beat, _slotsIn.$1, _slotsIn.$1 + 0.3) * shown, landed);
    final double scale = _logitScale(view);
    drawColumn(canvas, (int k) => layout.logitTile(order[k], dx), <Color>[
      for (int k = 0; k < count; k++)
        view.inks.signed(made[order[k]] / scale).withValues(alpha: landed[k] * shown * dimmed(order[k])),
    ]);
    drawColumnNumbers(
      canvas,
      view,
      (int r) => layout.logitTile(r, dx),
      made,
      shown,
      textSize: layout.textSize,
      writes: layout.writes,
      alphaOf: (int r) => _flow.written(rank[r], count, beat) * (trace.allowedIndex(r) < 0 ? 1 - unwritten : 1),
    );
    for (int r = 0; r < count; r++) {
      final Rect tile = layout.logitTile(r, dx);
      if (trace.allowedIndex(r) < 0 && struck > 0) {
        AttentionScene.hatch(
          canvas,
          view,
          Rect.fromLTRB(tile.left - 2, tile.top + 0.5, layout.chip(r, dx).right + 2, tile.bottom - 0.5),
          struck * shown,
        );
        if (layout.writes && infinite > 0) {
          view.kit.draw(
            canvas,
            '−∞',
            inked(view.kit.mono, layout.textSize, view.inks.quiet, alpha: infinite * shown),
            Offset(tile.right + 4, tile.center.dy),
            anchor: const Offset(0, 0.5),
          );
        }
      }
      final double from = _slotsIn.$1 + (count < 2 ? 0 : r / (count - 1)) * (_slotsIn.$2 - _slotsIn.$1 - _tileIn);
      drawToken(canvas, view, layout.chip(r, dx), r, alpha: through(beat, from, from + _tileIn) * shown);
    }
    drawColumnTitle(
      canvas,
      view,
      logitsTitle,
      through(beat, _slotsIn.$1, _slotsIn.$1 + 0.3) * shown,
      x: layout.logitX + dx,
      top: layout.benchTop,
    );
    final double plate = _span(beat, _plateIn) * (1 - cleared);
    if (plate > 0) {
      final String named = plateText(view);
      final Rect at = layout.plateAt(tagSize(view, named));
      drawTag(canvas, view, named, at.topLeft, alpha: plate);
      drawPlateStatus(canvas, view, at, ScoresScene.weightsStatus(view), plate, left: layout.left, right: layout.right);
    }
  }

  // -------------------------------------------------------------- the bars

  /// Softmax on the logits' rows: a bar each of the tokens that can come
  /// next, growing to e to its logit, the largest across the room; then
  /// every bar shrinking by their sum into its share, written at its end;
  /// what came next lit. As the map comes, each bar goes into its
  /// share's square, in a slot of a standing column the map's row is made
  /// of; the light on what came next gathers into its slot.
  void _bars(Canvas canvas, LmView view, PredictLayout layout, double beat) {
    final double grow = _span(beat, _exp);
    if (grow <= 0 || beat >= _lieDown.$1) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final List<double> made = logits(view, view.position);
    final List<double> p = shares(view, view.position);
    double most = double.negativeInfinity;
    for (final int id in trace.allowed) {
      most = math.max(most, made[id]);
    }
    final double settle = _span(beat, _share);
    final double tiles = _span(beat, _tiles);
    final double labels = _span(beat, _percents) * (1 - tiles);
    final Color bar = barColour(view);
    final TextStyle words = inked(view.kit.mono, layout.textSize, view.inks.ink, alpha: labels);
    final Paint paint = Paint();
    double reach(int id) {
      final double e = math.exp(made[id] - most);
      return grow * (e + (p[id] - e) * settle);
    }

    // What came next: its row lit softly, as the map lights its slot, from
    // its tile to the dashed 100%, the room its bar would fill were the
    // guess right and certain. As the map comes, the light gathers into its
    // slot in the standing column.
    final double answer = _span(beat, _answer);
    final int target = view.target;
    if (answer > 0 && tiles < 1 && trace.allowedIndex(target) >= 0) {
      final Rect drawn = layout.bar(target, reach(target));
      final Rect lit = litBand(layout, target, drawn, view.kit.layout(percent(p[target]), words).width);
      final RRect slot = slotOf(layout.shareTile(target));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.lerp(lit, slot.outerRect, tiles)!, Radius.circular(3 + (slot.tlRadiusX - 3) * tiles)),
        Paint()..color = view.inks.truth.withValues(alpha: answerLight * answer * (1 - tiles)),
      );
    }

    for (final int id in trace.allowed) {
      final Rect drawn = layout.bar(id, reach(id));
      if (tiles > 0) {
        final RRect slot = slotOf(layout.shareTile(id));
        drawSlot(canvas, view, slot, shown: tiles, lit: id == view.target ? tiles : 0);
        final RRect square = fillOf(slot, p[id]);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.lerp(drawn, square.outerRect, tiles)!,
            Radius.circular(1 + (square.tlRadiusX - 1) * tiles),
          ),
          paint..color = Color.lerp(bar, fillColour(view, p[id]), tiles)!,
        );
      } else if (drawn.width > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(drawn, const Radius.circular(1)), paint..color = bar);
      }
      if (labels > 0 && percentNumber(p[id]) != '0.0') {
        view.kit.draw(canvas, percent(p[id]), words, Offset(drawn.right + 3, drawn.center.dy), anchor: const Offset(0, 0.5));
      }
    }
    // The room a bar of 100% would take, its end dashed and named, while the
    // bars are shares.
    drawWhole(canvas, view, layout, settle * (1 - tiles));
  }

  /// A share's bar's colour on the bench: the accent, a little under full.
  static Color barColour(LmView view) => view.inks.signal.withValues(alpha: 0.85);

  /// What came next's row of the bench, lit: from its tile, slid left with
  /// the logits, to the dashed 100%, or past its bar [drawn] and its
  /// percentage, [label] wide, where those reach further.
  static Rect litBand(PredictLayout layout, int target, Rect drawn, double label) {
    final Rect tile = layout.chip(target, layout.slideBy);
    final Rect row = layout.row(target);
    return Rect.fromLTRB(
      tile.left - 3,
      row.top + 1,
      math.min(layout.right, math.max(layout.barLeft + layout.barRoom, drawn.right + label + 6)),
      row.bottom - 1,
    );
  }

  /// The room a bar of 100% would take: its end dashed down the bars and
  /// named over them, [alpha] as strongly.
  static void drawWhole(Canvas canvas, LmView view, PredictLayout layout, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final Rect column = layout.shareColumn;
    final double x = layout.barLeft + layout.barRoom;
    dashedLine(
      canvas,
      Offset(x, column.top),
      Offset(x, column.bottom),
      Paint()
        ..strokeWidth = 0.8
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
    view.kit.draw(
      canvas,
      percent(1),
      inked(view.kit.mono, 8.5, view.inks.quiet, alpha: alpha),
      Offset(x, column.top - 3),
      anchor: const Offset(0.5, 1),
    );
  }

  // --------------------------------------------------------------- the map

  /// How far place [i]'s row of the map has filled at [beat], of [n] places,
  /// [focus] in focus: the place in focus's once its tiles have lain down;
  /// every other, top to bottom, a row at a time.
  static double _filled(int i, int focus, int n, double beat) {
    if (i == focus) {
      return beat >= _lieDown.$2 ? 1 : 0;
    }
    final int rank = i < focus ? i : i - 1;
    final double start = _rows.$1 + (n < 3 ? 0 : (_rows.$2 - _rows.$1 - _rowFill) * rank / (n - 2));
    return through(beat, start, start + _rowFill);
  }

  /// Every place's guess at once, on the table's rows as head 1's map lies:
  /// a row a place, the tile at its left naming it; a column a token that
  /// can come next, named by a tile under it; each share a square in its
  /// slot, its area that share of the slot's, no number on it. The slots come
  /// in empty; the place in focus's lie down onto its row, squares and the
  /// lit slot of what came next with them; every other row's squares grow
  /// in; then the slot of what came next at each place lights, and the
  /// answer key comes in at the map's right.
  void _map(Canvas canvas, LmView view, PredictLayout layout, double beat, PredictFade fade) {
    final double shown = _span(beat, _mapIn);
    if (shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final StreamTable table = layout.table;
    final int n = view.focus.inputs;
    final int focus = view.position;
    final List<int> allowed = trace.allowed;
    final List<List<double>> rows = allShares(view);
    final double answers = _span(beat, _answers);
    table.tag(canvas, mapTag(view), shown * fade.tag);
    table.drawTiles(canvas, alpha: shown * fade.rows, dx: -table.gutter);
    for (int k = 0; k < allowed.length; k++) {
      drawToken(canvas, view, layout.mapTile(k), allowed[k], alpha: shown * fade.others);
    }
    for (int i = 0; i < n; i++) {
      final double filled = _filled(i, focus, n, beat);
      final int answer = trace.allowedIndex(trace.targetAt(view.peptide, i));
      // The place in focus's slot came lit off the bench; every other
      // place's lights with the answer key.
      final double lit = i == focus && beat >= _lieDown.$2 ? 1 : answers;
      for (int k = 0; k < allowed.length; k++) {
        drawShare(
          canvas,
          view,
          layout.mapCell(i, k),
          share: rows[i][k],
          grown: filled,
          shown: shown * (k == answer ? fade.answers : fade.others),
          lit: k == answer ? lit : 0,
        );
      }
    }
    // The place in focus's slots, its squares in them, lying down from the
    // bench onto its row.
    final double lie = _span(beat, _lieDown);
    if (beat >= _lieDown.$1 && lie < 1) {
      final int answer = trace.allowedIndex(view.target);
      StreamTable.turn(
        canvas,
        from: layout.mapRow(focus),
        to: layout.shareColumn,
        f: 1 - lie,
        draw: (Rect strip) {
          final double w = strip.width / allowed.length;
          for (int k = 0; k < allowed.length; k++) {
            drawShare(
              canvas,
              view,
              Rect.fromLTWH(strip.left + k * w, strip.top, w, strip.height),
              share: rows[focus][k],
              lit: k == answer ? 1 : 0,
            );
          }
        },
      );
    }
    table.outline(canvas, focus, layout.right, _span(beat, _focusOutline) * fade.outline, dx: -table.gutter);
    _answerKey(canvas, view, layout, answers, fade);
  }

  /// The answer key at the map's right, as Shift's y: each place's next
  /// token on a tile at its row's end, and the share its guess gave it, the
  /// number Loss scores; their names over them. [fade] takes the tiles and
  /// the shares given, with the names, apart.
  void _answerKey(Canvas canvas, LmView view, PredictLayout layout, double alpha, PredictFade fade) {
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final double tiles = alpha * fade.key;
    final double numbers = alpha * fade.given;
    final TextStyle? given = layout.givenStyle;
    final TextStyle? written = given?.copyWith(color: given.color!.withValues(alpha: (numbers * 8).round() / 8));
    for (int i = 0; i < view.focus.inputs; i++) {
      final int next = trace.targetAt(view.peptide, i);
      drawToken(canvas, view, layout.answerTile(i), next, alpha: tiles);
      if (written != null && numbers > 0) {
        view.kit.draw(
          canvas,
          percent(shares(view, i)[next]),
          written,
          Offset(layout.givenRight, layout.table.row(i).center.dy),
          anchor: const Offset(1, 0.5),
        );
      }
    }
    // Named as a column is (`drawColumnTitle`), the shares' name flush with
    // their right edge.
    if (numbers <= 0) {
      return;
    }
    final double top = layout.table.layout.tableTop - 4;
    final TextStyle named = titleStyle(view, alpha: numbers);
    view.kit.draw(canvas, answerTitle, named, Offset(layout.answerTile(0).center.dx, top), anchor: const Offset(0.5, 1));
    if (written != null) {
      view.kit.draw(canvas, givenTitle, named, Offset(layout.givenRight, top), anchor: const Offset(1, 1));
    }
  }

  /// The map's name: every place's next-token probabilities, a row a place,
  /// a column a token that can come next.
  static String mapTag(LmView view) =>
      'next-token probabilities · ${view.focus.inputs} × ${view.trace.allowed.length}';

  // ------------------------------------------------------------------- taps

  /// Once the map has come, a row of it puts its place in focus; before, the
  /// bench is one place's, and a tap asks for nothing.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) =>
      frame.local * _beats < _mapIn.$1 ? null : hit(size, view, at);

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  // ---------------------------------------------------------------- caption

  /// The likeliest next tokens at the place in focus: up to three, each
  /// given at least one in a hundred.
  static String likeliest(LmView view) {
    final TrainingTrace trace = view.trace;
    final List<double> p = shares(view, view.position);
    final List<int> ranked = <int>[...trace.allowed]
      ..sort((int a, int b) => p[b] != p[a] ? p[b].compareTo(p[a]) : a.compareTo(b));
    return ranked
        .take(3)
        .where((int id) => p[id] >= 0.01 || id == ranked.first)
        .map((int id) => '${trace.token(id)} ${percent(p[id])}')
        .join(', ');
  }

  /// Why each part happens, over the bench, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int count = trace.vocab.length;
    final int width = trace.model.width;
    final double flowing = _flow.fanAt(0, count).$1;
    return <(double, double, String)>[
      (
        0.25,
        flowing,
        'Only this last row is read: everything the pass made of ${StreamTable.placeName(view, view.position)}.\n'
            'Each of the $count tokens has its own row of $width weights, and a bias.\n'
            'A logit is high where row and weights agree in sign and size.',
      ),
      (
        flowing,
        _struck.$1,
        'A logit is a raw score for one token: any size, either sign.\n'
            'The ${grouped(count * width)} weights start random; every training step moves them.',
      ),
      (
        _struck.$1,
        _exp.$1,
        '${_blocked(trace)} are never what comes next.\n'
            'Set to −∞, e to the logit is 0: softmax gives them nothing.',
      ),
      (
        _exp.$1,
        _tiles.$1,
        'Softmax, as in Scores: e to each logit, then each over their sum.\n'
            'e makes each score positive and stretches the gaps.\n'
            "The shares add to 100%: the model's guess, a probability a token.",
      ),
      (
        _tiles.$1,
        _answers.$1,
        'Every place goes through the same output layer: ${grouped(view.focus.inputs)} guesses.\n'
            "A square's area is its share; a row's add up to one slot: 100%.",
      ),
      (
        _answers.$1,
        double.infinity,
        "At the right, Shift's y and p(y), the share each guess gave it.\n"
            'Certain and right, a row is one square filling its lit slot.\n'
            'Next, Loss scores each place by p(y) alone.',
      ),
    ];
  }

  @override
  String caption(LmView view, TrainingFrame frame) => _caption(view, frame.local * _beats);

  String _caption(LmView view, double beat) {
    final TrainingTrace trace = view.trace;
    final int count = trace.vocab.length;
    final int width = trace.model.width;
    final int n = view.focus.inputs;
    final String focus = StreamTable.placeName(view, view.position);
    final int best = top(view, view.position);
    final String name = trace.token(best);
    final List<double> made = logits(view, view.position);
    final List<double> p = shares(view, view.position);
    if (beat < _slotsIn.$1) {
      return "$focus's last row, as Forward left it: what the output layer reads";
    }
    if (beat < _flow.fanAt(0, count).$1) {
      return 'A logit per token: ${grouped(count)} slots, the vocabulary in id order';
    }
    if (beat < _flow.fanAt(1, count).$1) {
      // Its bias, where there is one, as the engine's output layer has.
      final bool biased = trace.outputBias(view.checkpoint, best) != 0;
      return "$name's logit: $focus's row × $name's $width weights, summed"
          '${biased ? ', + bias' : ''}: ${fixed(made[best], 2)}';
    }
    if (beat < _flow.fanAt(count - 1, count).$2 + 0.15) {
      return 'The other ${grouped(count - 1)} the same way, each through its own $width weights';
    }
    if (beat < _struck.$1) {
      return "The output layer's ${grouped(count * width)} weights: a string each, $width into every logit";
    }
    if (beat < _exp.$1) {
      return '${_blocked(trace)} can never come next: their logits, −∞';
    }
    double sum = 0;
    for (final int id in trace.allowed) {
      sum += math.exp(made[id]);
    }
    if (beat < _share.$1) {
      return "e to each logit: all positive, the largest pulls ahead: $name's ${exponential(math.exp(made[best]))}";
    }
    if (beat < _answer.$1) {
      return 'Over their sum, ${exponential(sum)}: shares of 100%, ${likeliest(view)}';
    }
    if (beat < _tiles.$1) {
      final String after = readSoFar(trace, view.peptide, view.position);
      final String next = trace.token(view.target);
      // What came next named as what it is: <eos> ends the frame, no residue.
      final String kind = trace.isResidue(view.target) ? 'residue' : 'token';
      return best == view.target
          ? 'Top bet after $after: $next, ${percent(p[best])}, the true next $kind'
          : 'Top bet after $after: $name, ${percent(p[best])}. '
                'True next $kind, $next, got ${percent(p[view.target])}';
    }
    if (beat < _answers.$1) {
      return 'Every place guesses at once, with the same weights: ${grouped(n)} rows of ${grouped(trace.allowed.length)}';
    }
    return 'Lit, what came next (y): the top guess at ${grouped(right(view))} of ${grouped(n)} places';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Predict, step ${view.step}. ${caption(view, frame)}.';
}

/// What Predict's last frame fades or leaves out, for the stage that opens on
/// it: the note; the map's tag; the tiles naming its rows; every cell of it
/// but what came next, with the tiles naming its columns; the cells of what
/// came next, which Loss moves itself; the outline of the place in focus;
/// and the answer key, its tiles apart from the shares given and their
/// names. By default, the frame as Predict draws it.
@immutable
final class PredictFade {
  const PredictFade({
    this.note = 1,
    this.tag = 1,
    this.rows = 1,
    this.others = 1,
    this.answers = 1,
    this.outline = 1,
    this.key = 1,
    this.given = 1,
  });

  final double note;
  final double tag;
  final double rows;
  final double others;
  final double answers;
  final double outline;
  final double key;
  final double given;
}

/// Predict's canvas, on Embedding's, as the stream's stages are: the note
/// over it, then the room Forward's ladder took. While the output layer
/// works, the bench: a row a token, as tall as the room allows with the
/// weights' plate under it; the last row standing at the left, its numbers
/// left of it, its tiles through the rows' height; the logits at the right,
/// their numbers right of them and each token's tile at the canvas's side.
/// Once the logits slide left, the bars take the room right of their tiles.
/// Then the map, on the table's own rows, as head 1's map lies, and at its
/// right the answer key: each row's next token on a tile as large as the
/// tiles naming the rows, and the share it was given, written up to the
/// canvas's side.
final class PredictLayout {
  PredictLayout(Size size, LmView view)
    : table = StreamTable(size, view),
      tower = TowerLayout(size, view),
      tokens = view.trace.vocab.length,
      width = view.trace.model.width,
      _view = view {
    final EmbeddingLayout e = table.layout;
    final TrainingTrace trace = view.trace;
    left = e.left;
    right = e.right;
    final double top = e.tableTop;
    final double bottom = e.footTop + e.footTile.height;
    final double status = view.kit
        .layout(ScoresScene.weightsStatus(view), inked(view.kit.sans, 8.5, view.inks.quiet))
        .height;
    final double band = _plateGap + tagSize(view, PredictScene.plateText(view)).height + 3 + status;
    pitch = ((bottom - top - band) / tokens).clamp(1.0, _mostPitch);
    benchTop = top + math.max(0.0, (bottom - top - band - tokens * pitch) / 2);
    benchBottom = benchTop + tokens * pitch;
    textSize = math.min(9.0, pitch * 0.72);
    writes = textSize >= EmbeddingLayout.leastNumber;
    final TextStyle face = inked(view.kit.mono, textSize, view.inks.ink);
    String widest(double most) => '−${'8' * '${most.floor()}'.length}.88';
    numberWidth = writes ? view.kit.layout(widest(_largest(lastRow)), face).width + 4 : 0;
    double logitMost = 0;
    for (int i = 0; i < view.focus.inputs; i++) {
      logitMost = math.max(logitMost, _largest(PredictScene.logits(view, i)));
    }
    logitWidth = writes ? view.kit.layout(widest(logitMost), face).width + 4 : 0;
    percentWidth = view.kit.layout('100%', face).width + 3;
    column = ((right - left) * 0.045).clamp(8.0, 13.0);
    chipSide = (pitch - 3).clamp(3.0, 14.0);
    inputX = left + numberWidth + column / 2;
    logitX = right - chipSide - _chipGap - logitWidth - column / 2;
    // Slid as far left as the logits' name over them keeps on the canvas.
    final double named = view.kit.layout(PredictScene.logitsTitle, inked(view.kit.sans, 9, view.inks.quiet)).width;
    final double softX = left + math.max(column / 2, named / 2 + 1);
    slideBy = math.min(0.0, softX - logitX);
    barLeft = softX + column / 2 + logitWidth + _chipGap + chipSide + 6;
    barRoom = math.max(10.0, right - percentWidth - barLeft);
    final List<int> allowed = trace.allowed;
    firstAllowed = allowed.reduce(math.min);
    lastAllowed = allowed.reduce(math.max);
    mapLeft = e.cellsLeft - table.gutter;
    // The answer key, from the canvas's side in: the shares given, clear of
    // the place in focus's outline; then the tiles; then the map.
    final TextStyle? given = _givenStyle(view, e.pitch);
    givenStyle = given;
    givenRight = right - _outlineRoom;
    if (given == null) {
      answerLeft = givenRight - e.chipSide;
    } else {
      // Room for the widest share, 100%, right of the tiles; and for the
      // shares' name over them, clear of the tiles' own, which can be the
      // wider where the rows, and so the numbers, are small.
      final TextStyle named = PredictScene.titleStyle(view);
      final double numbers = view.kit.layout('100%', given).width + _givenGap + e.chipSide;
      final double names = view.kit.layout(PredictScene.givenTitle, named).width +
          _titleGap +
          view.kit.layout(PredictScene.answerTitle, named).width / 2 +
          e.chipSide / 2;
      answerLeft = givenRight - math.max(numbers, names);
    }
    mapRight = answerLeft - _answerGap;
    mapColumn = (mapRight - mapLeft) / allowed.length;
  }

  final StreamTable table;

  /// Forward's ladder, whose last row the stage opens on.
  final TowerLayout tower;
  final int tokens;
  final int width;
  final LmView _view;

  /// The tallest a token's row is drawn.
  static const double _mostPitch = 22;

  /// From the columns to the weights' plate, and from a logit's number to its
  /// token's tile.
  static const double _plateGap = 10;
  static const double _chipGap = 4;

  /// From the map to the answer key's tiles, from a tile to its share, and
  /// from the shares to the canvas's side, where the outline of the place in
  /// focus runs.
  static const double _answerGap = 6;
  static const double _givenGap = 3;
  static const double _outlineRoom = 2;

  /// Between the answer key's two names.
  static const double _titleGap = 4;

  late final double left;
  late final double right;

  /// A token's row, and where the rows start and end.
  late final double pitch;
  late final double benchTop;
  late final double benchBottom;

  /// The numbers' size, and whether they fit; how wide the last row's and
  /// the logits' numbers are, with their gap from their tiles; and a share's.
  late final double textSize;
  late final bool writes;
  late final double numberWidth;
  late final double logitWidth;
  late final double percentWidth;

  /// How wide a standing column is, and a token's tile.
  late final double column;
  late final double chipSide;

  /// The last row's column, the logits', and how far the logits slide left
  /// for the bars; where the bars start and how long one of all is.
  late final double inputX;
  late final double logitX;
  late final double slideBy;
  late final double barLeft;
  late final double barRoom;

  /// The rows of the tokens that can come next: the first and the last.
  late final int firstAllowed;
  late final int lastAllowed;

  /// Where the map starts and ends, and how wide its columns are.
  late final double mapLeft;
  late final double mapRight;
  late final double mapColumn;

  /// The answer key: where its tiles start, where the shares given end, and
  /// what those are written in, or null where the rows are too small for a
  /// number.
  late final double answerLeft;
  late final double givenRight;
  late final TextStyle? givenStyle;

  /// The shares given to what came next are written as the table's rows
  /// write their numbers: at most 9 points, and not below the least a number
  /// is written.
  static TextStyle? _givenStyle(LmView view, double pitch) {
    final double points = (math.min(9, pitch * 0.62) * 2).floorToDouble() / 2;
    return points < EmbeddingLayout.leastNumber
        ? null
        : inked(view.kit.mono, points, view.inks.ink).copyWith(letterSpacing: 0);
  }

  static double _largest(List<double> values) {
    double most = 0;
    for (final double v in values) {
      most = math.max(most, v.abs());
    }
    return most;
  }

  /// The last row Forward made for the place in focus, and its colour scale,
  /// the final norm's, as the ladder draws it.
  List<double> get lastRow => table.values(tower.points - 1, _view.position);

  double get lastScale => streamScales(_view).$2;

  /// Token [r]'s row, across the canvas.
  Rect row(int r) => Rect.fromLTRB(left, benchTop + r * pitch, right, benchTop + (r + 1) * pitch);

  /// The last row standing: its column, and number [d]'s tile in it, through
  /// the rows' height.
  Rect get inputColumn => Rect.fromLTRB(inputX - column / 2, benchTop, inputX + column / 2, benchBottom);

  Rect inputTile(int d) {
    final double h = (benchBottom - benchTop) / width;
    return Rect.fromLTWH(inputX - column / 2, benchTop + d * h, column, h);
  }

  /// Token [r]'s logit, [dx] along from where it is made.
  Rect logitTile(int r, double dx) => Rect.fromLTWH(logitX + dx - column / 2, benchTop + r * pitch, column, pitch);

  /// Token [r]'s tile, right of its logit's number, [dx] along.
  Rect chip(int r, double dx) {
    final Rect logit = logitTile(r, dx);
    return Rect.fromLTWH(logit.right + logitWidth + _chipGap, logit.center.dy - chipSide / 2, chipSide, chipSide);
  }

  /// Token [r]'s bar, [value] of the room long.
  Rect bar(int r, double value) {
    final Rect band = row(r);
    final double thick = (pitch * 0.5).clamp(2.0, 8.0);
    return Rect.fromLTWH(barLeft, band.center.dy - thick / 2, barRoom * value.clamp(0.0, 1.0), thick);
  }

  /// Token [r]'s share as a tile, where its bar starts: one of the standing
  /// column the place's row of the map is made of.
  Rect shareTile(int r) => Rect.fromLTWH(barLeft, benchTop + r * pitch, column, pitch);

  /// That column, from the first token that can come next to the last.
  Rect get shareColumn => Rect.fromLTRB(
    barLeft,
    benchTop + firstAllowed * pitch,
    barLeft + column,
    benchTop + (lastAllowed + 1) * pitch,
  );

  /// The weights' plate, [plate] in size: centred under the strings, below
  /// the columns.
  Rect plateAt(Size plate) {
    final double centre = (inputX + logitX) / 2;
    final double x = (centre - plate.width / 2).clamp(left, math.max(left, right - plate.width));
    return Offset(x, benchBottom + _plateGap) & plate;
  }

  /// The map's cell at row [i], column [k]: what place [i] gives the [k]th
  /// token that can come next, on the table's row [i].
  Rect mapCell(int i, int k) {
    final Rect r = table.row(i);
    final double x = mapLeft + k * mapColumn;
    return Rect.fromLTRB(x, r.top, x + mapColumn, r.bottom);
  }

  /// Place [i]'s row of the map, every column of it.
  Rect mapRow(int i) => Rect.fromLTRB(mapLeft, table.row(i).top, mapRight, table.row(i).bottom);

  /// The tile of what came next after place [i], at its row's end: as large
  /// as the tile naming the row, centred on it.
  Rect answerTile(int i) {
    final Rect row = table.row(i);
    final double side = table.layout.chipSide;
    return Rect.fromLTWH(answerLeft, row.center.dy - side / 2, side, side);
  }

  /// The tile naming the map's column [k], under its last row, as Attention
  /// names the places read.
  Rect mapTile(int k) {
    final Rect cell = mapCell(_view.focus.inputs - 1, k);
    final double side = table.layout.chipSide;
    final double wide = math.max(1.0, math.min(side, cell.width - 1));
    return Rect.fromLTWH(cell.center.dx - wide / 2, cell.bottom + 4, wide, side);
  }
}
