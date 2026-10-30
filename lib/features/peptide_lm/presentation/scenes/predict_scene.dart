import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

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

/// The axis a set of probabilities is drawn on: the least of a tenth, a
/// quarter, a half and one that holds the largest.
double probabilityAxis(List<double> p) {
  final double top = p.reduce(math.max);
  for (final double axis in const <double>[0.1, 0.25, 0.5]) {
    if (top <= axis) {
      return axis;
    }
  }
  return 1;
}

/// Draws the bars of [values] (0 to [axis]) in [rect], each in its token's
/// colour, [target] outlined.
void drawProbabilityBars(
  Canvas canvas,
  LmView view,
  Rect rect,
  List<double> values, {
  required double axis,
  required int target,
  double alpha = 1,
  double outline = 1,
  int labelled = 0,
}) {
  final TrainingTrace trace = view.trace;
  final List<int> order = barOrder(trace);
  final double slot = rect.width / order.length;
  final double plot = rect.height - 14;
  canvas.drawLine(
    Offset(rect.left, rect.top + plot),
    Offset(rect.right, rect.top + plot),
    Paint()
      ..strokeWidth = 1
      ..color = view.inks.rule,
  );
  dashedLine(
    canvas,
    Offset(rect.left, rect.top),
    Offset(rect.right, rect.top),
    Paint()
      ..strokeWidth = 0.8
      ..color = view.inks.rule,
  );
  view.kit.draw(
    canvas,
    percent(axis),
    inked(view.kit.mono, 8.5, view.inks.quiet),
    Offset(rect.right, rect.top - 2),
    anchor: const Offset(1, 1),
  );
  final List<int> ranked = List<int>.generate(order.length, (int i) => i)
    ..sort((int a, int b) => values[b].compareTo(values[a]));
  for (int k = 0; k < order.length; k++) {
    final int id = order[k];
    final double h = plot * (values[k] / axis).clamp(0.0, 1.0);
    final Rect bar = Rect.fromLTWH(rect.left + k * slot + slot * 0.15, rect.top + plot - h, slot * 0.7, h);
    final Color color = trace.isResidue(id) ? view.inks.residue(trace.token(id)) : view.inks.quiet;
    canvas.drawRect(bar, Paint()..color = color.withValues(alpha: alpha));
    if (id == target && outline > 0) {
      canvas.drawRect(
        Rect.fromLTRB(bar.left - 1.5, math.min(bar.top, rect.top + plot - 3) - 1.5, bar.right + 1.5, rect.top + plot + 1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = view.inks.truth.withValues(alpha: outline),
      );
    }
    view.kit.draw(
      canvas,
      glyph(trace, id),
      inked(view.kit.mono, 9, id == target ? view.inks.truth : view.inks.quiet, alpha: alpha),
      Offset(rect.left + (k + 0.5) * slot, rect.top + plot + 3),
      anchor: const Offset(0.5, 0),
    );
  }
  for (int r = 0; r < math.min(labelled, ranked.length); r++) {
    final int k = ranked[r];
    // A share under one in a hundred is not worth a number.
    if (values[k] < 0.01) {
      break;
    }
    final double h = plot * (values[k] / axis).clamp(0.0, 1.0);
    view.kit.draw(
      canvas,
      percent(values[k]),
      inked(view.kit.mono, 8.5, view.inks.ink, alpha: alpha),
      Offset(rect.left + (k + 0.5) * slot, rect.top + plot - h - 2),
      anchor: const Offset(0.5, 1),
    );
  }
}

/// Predict: the stream at the position in focus, after the final norm, meets
/// each row of the output layer, a dot product a token. `<pad>` and `<bos>`
/// are struck out, since neither can ever come next; softmax turns the other
/// scores into a probability each.
final class PredictScene extends LmScene {
  const PredictScene();

  static const double _lift = 0.12;
  static const double _scanTo = 0.5;
  static const double _struck = 0.6;
  static const double _exponent = 0.72;
  static const double _normalised = 0.85;

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final _Layout layout = _Layout(size, view);
    final double u = frame.local;
    final int position = view.position;
    final int finalPoint = 2 * trace.model.layers + 1;
    final (_, double finalScale) = streamScales(view);
    final double weights = headScale(view);
    final int rows = trace.vocab.length;
    final int width = trace.model.width;

    // The output layer, as the step found it.
    final GridMesh matrix = GridMesh(layout.matrix, width, rows, rowGap: 0.6);
    for (int r = 0; r < rows; r++) {
      for (int d = 0; d < width; d++) {
        matrix.cell(d, r, view.inks.signed(trace.headWeight(view.step, r, d) / weights));
      }
    }
    matrix.draw(canvas);
    final double rowHeight = layout.matrix.height / rows;
    for (int r = 0; r < rows; r++) {
      view.kit.draw(
        canvas,
        glyph(trace, r),
        inked(
          view.kit.mono,
          math.min(9, rowHeight + 2),
          trace.isResidue(r) ? view.inks.residue(trace.token(r)) : view.inks.quiet,
        ),
        Offset(layout.matrix.left - 4, layout.matrix.top + (r + 0.5) * rowHeight),
        anchor: const Offset(1, 0.5),
      );
    }

    // The stream's column, lifted out of the forward pass, run down the rows,
    // and gone once every row has its score.
    final double lift = through(u, 0, _lift) * (1 - through(u, _scanTo, _struck));
    final double scan = through(u, _lift, _scanTo);
    final double stripY = layout.matrix.top - 8 + scan * layout.matrix.height;
    if (lift > 0) {
      final GridMesh strip = GridMesh(
        Rect.fromLTWH(layout.matrix.left, stripY, layout.matrix.width, 5),
        width,
        1,
      );
      for (int d = 0; d < width; d++) {
        final Color c = view.inks.signed(trace.stream(view.checkpoint, finalPoint, view.peptide, position, d) / finalScale);
        strip.cell(d, 0, Color.lerp(view.inks.ground, c, lift)!);
      }
      strip.draw(canvas);
    }
    if (lift > 0) {
      canvas.drawRect(
        Rect.fromLTWH(layout.matrix.left - 1, stripY - 1, layout.matrix.width + 2, 7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = view.inks.signal.withValues(alpha: lift),
      );
    }

    // Each row's logit, as the column passes it.
    double largest = 1e-6;
    for (int r = 0; r < rows; r++) {
      largest = math.max(largest, trace.logit(view.checkpoint, view.peptide, position, r).abs());
    }
    final Rect logits = layout.logits;
    canvas.drawLine(
      Offset(logits.center.dx, logits.top),
      Offset(logits.center.dx, logits.bottom),
      Paint()
        ..strokeWidth = 0.8
        ..color = view.inks.rule,
    );
    final double struck = through(u, _scanTo, _struck);
    for (int r = 0; r < rows; r++) {
      final double reached = ((scan * rows) - r).clamp(0.0, 1.0);
      if (reached <= 0) {
        continue;
      }
      final double y = logits.top + (r + 0.5) * rowHeight;
      final bool blocked = trace.allowedIndex(r) < 0;
      if (blocked && struck > 0) {
        view.kit.draw(
          canvas,
          '${'−'}∞',
          inked(view.kit.mono, math.min(9, rowHeight + 2), view.inks.quiet, alpha: struck),
          Offset(logits.left + 2, y),
          anchor: const Offset(0, 0.5),
        );
        canvas.drawLine(
          Offset(layout.matrix.left, y),
          Offset(layout.matrix.right, y),
          Paint()
            ..strokeWidth = 1
            ..color = view.inks.quiet.withValues(alpha: 0.7 * struck),
        );
        continue;
      }
      final double value = trace.logit(view.checkpoint, view.peptide, position, r);
      final double length = logits.width / 2 * (value / largest) * reached;
      canvas.drawRect(
        Rect.fromLTRB(
          math.min(logits.center.dx, logits.center.dx + length),
          y - rowHeight * 0.32,
          math.max(logits.center.dx, logits.center.dx + length),
          y + rowHeight * 0.32,
        ),
        Paint()..color = view.inks.ink.withValues(alpha: 0.75),
      );
    }

    // Softmax: first each score's exponential, then each share of their sum.
    final double grow = through(u, _struck, _exponent);
    if (grow > 0) {
      final List<int> order = barOrder(trace);
      double top = -double.infinity;
      for (final int id in order) {
        top = math.max(top, trace.logit(view.checkpoint, view.peptide, position, id));
      }
      final List<double> p = probabilities(view, position);
      final double axis = probabilityAxis(p);
      final double settle = through(u, _exponent, _normalised);
      final List<double> shown = <double>[
        for (int k = 0; k < order.length; k++)
          grow *
              ((1 - settle) *
                      axis *
                      math.exp(trace.logit(view.checkpoint, view.peptide, position, order[k]) - top) +
                  settle * p[k]),
      ];
      drawProbabilityBars(
        canvas,
        view,
        layout.bars,
        shown,
        axis: axis,
        target: view.target,
        outline: through(u, _normalised, 0.92),
        labelled: u >= _normalised ? 3 : 0,
      );
    }

    for (int i = 0; i < view.focus.inputs; i++) {
      drawToken(
        canvas,
        view,
        layout.tokens.at(i),
        trace.inputAt(view.peptide, i),
        alpha: i <= position ? 1 : 0.35,
        outline: i == position ? view.inks.signal : null,
      );
    }
    drawCaret(
      canvas,
      Offset(layout.tokens.centre(position), layout.tokens.bounds.bottom + 2),
      4,
      view.inks.signal,
    );
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = _Layout(size, view).tokens.indexAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) =>
      _Layout(size, view).tokens.indexAt(at, slack: 40);

  /// The likeliest next tokens at the position in focus, as a line: up to
  /// three, each given at least one in a hundred.
  static String likeliest(LmView view) {
    final TrainingTrace trace = view.trace;
    final List<int> order = barOrder(trace);
    final List<double> p = probabilities(view, view.position);
    final List<int> ranked = List<int>.generate(order.length, (int i) => i)
      ..sort((int a, int b) => p[b].compareTo(p[a]));
    return ranked
        .take(3)
        .where((int k) => p[k] >= 0.01 || k == ranked.first)
        .map((int k) => '${trace.token(order[k])} ${percent(p[k])}')
        .join(' · ');
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final String after = readSoFar(trace, view.peptide, view.position);
    if (frame.local < _scanTo) {
      return '${trace.vocab.length} logits: the stream after $after against each row '
          'of the output layer';
    }
    if (frame.local < _struck) {
      return '<pad> and <bos> can never come next: −∞, so softmax gives them nothing';
    }
    return 'After $after: ${likeliest(view)} · next is ${trace.token(view.target)}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) =>
      'Predict, step ${view.step}. ${caption(view, frame)}.';
}

final class _Layout {
  _Layout(Size size, LmView view) {
    const double left = 16;
    final double right = size.width - 16;
    final double width = right - left;
    final int inputs = view.focus.inputs;
    final double cell = math.min(22, width / inputs);
    final int rows = view.trace.vocab.length;
    final double barsHeight = (size.height * 0.3).clamp(70.0, 170.0);
    final double rowHeight =
        ((size.height - 24 - barsHeight - 24 - 22 - cell - 12) / rows).clamp(3.0, 9.0);
    final double content = barsHeight + 24 + rowHeight * rows + 22 + cell + 12;
    final double top = math.max(16, (size.height - content) / 2 + 8);
    bars = Rect.fromLTWH(left, top, width, barsHeight);
    const double labels = 14;
    const double logitWidth = 60;
    matrix = Rect.fromLTWH(
      left + labels,
      bars.bottom + 24,
      width - labels - logitWidth - 8,
      rowHeight * rows,
    );
    logits = Rect.fromLTWH(matrix.right + 8, matrix.top, logitWidth, matrix.height);
    tokens = TokenLayout(Rect.fromLTWH(left, matrix.bottom + 22, width, cell), inputs, most: 22);
  }

  late final TokenLayout tokens;
  late final Rect bars;
  late final Rect matrix;
  late final Rect logits;
}
