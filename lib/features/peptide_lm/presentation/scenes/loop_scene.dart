import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/loop_pace.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'predict_scene.dart';

/// Loop: the same six steps, two hundred times. The loss falls past each
/// baseline toward the floor, each peptide's residues light up as the model
/// comes to give them its probability, all but each first one, and the
/// output layer's weights drift into shape.
final class LoopScene extends LmScene {
  const LoopScene();

  /// [values] at a step between two, read along the straight line between.
  static double between(double step, double Function(int step) at, int count) {
    final int below = step.floor().clamp(1, count);
    final int above = math.min(count, below + 1);
    final double t = (step - below).clamp(0.0, 1.0);
    return at(below) + (at(above) - at(below)) * t;
  }

  /// The last level the loss has passed by [step]: its name and the step.
  static (String, int)? passed(TrainingTrace trace, double step) {
    (String, int)? last;
    for (final TraceCheckpoint checkpoint in trace.checkpoints) {
      if (checkpoint.step > step) {
        break;
      }
      for (final String why in checkpoint.why) {
        final String? level = switch (why) {
          'uniform' => 'uniform',
          'unigram' => 'unigram',
          'bigram' => 'bigram',
          'one_nat' => '1 nat',
          'tenth_nat' => '0.1 nat',
          _ => null,
        };
        if (level != null) {
          last = (level, checkpoint.step);
        }
      }
    }
    return last;
  }

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final _Layout layout = _Layout(size, view);
    final double step = LoopPace.of(view.trace).at(frame.local).step;
    _chart(canvas, view, layout, step);
    _map(canvas, view, layout, step);
    if (layout.weights.height >= 24) {
      _weights(canvas, view, layout, step);
    }
  }

  void _chart(Canvas canvas, LmView view, _Layout layout, double step) {
    final TrainingTrace trace = view.trace;
    final Rect plot = layout.chart;
    final int count = trace.steps.count;
    final double ceiling = math.max(trace.loss(1), trace.uniform) * 1.06;
    double x(double s) => plot.left + plot.width * (count <= 1 ? 1 : (s - 1) / (count - 1));
    double y(double nats) => plot.bottom - plot.height * (nats / ceiling).clamp(0.0, 1.0);

    final Paint axis = Paint()
      ..strokeWidth = 1
      ..color = view.inks.rule;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axis);
    for (int n = 0; n <= ceiling.floor(); n++) {
      view.kit.draw(
        canvas,
        '$n',
        inked(view.kit.mono, 8.5, view.inks.quiet),
        Offset(plot.left - 5, y(n.toDouble())),
        anchor: const Offset(1, 0.5),
      );
    }
    // The axis's unit above its numbers, clear of the curve's first steps.
    view.kit.draw(
      canvas,
      'nats',
      inked(view.kit.sans, 8.5, view.inks.quiet),
      Offset(plot.left - 4, plot.top - 6),
      anchor: const Offset(1, 1),
    );

    // The levels to beat, and the floor no model can pass.
    final List<(String, double)> levels = <(String, double)>[
      ('uniform', trace.uniform),
      ('unigram', trace.unigram),
      ('bigram', trace.bigram),
      ('floor', trace.floor),
    ];
    double lastLabel = -100;
    for (final (String name, double value) in levels) {
      final double ly = y(value);
      final Paint line = Paint()
        ..strokeWidth = 1
        ..color = view.inks.quiet.withValues(alpha: 0.75);
      dashedLine(
        canvas,
        Offset(plot.left, ly),
        Offset(plot.right, ly),
        line,
        dash: name == 'floor' ? 1.5 : 4,
        gap: name == 'floor' ? 2.5 : 3,
      );
      final double labelY = math.max(ly - 2, lastLabel + 11);
      view.kit.draw(
        canvas,
        '$name ${nats(value)}',
        inked(view.kit.mono, 8.5, view.inks.quiet),
        Offset(plot.right, labelY),
        anchor: const Offset(1, 1),
      );
      lastLabel = labelY;
    }

    // Checkpoints, where every activation was kept.
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final double cx = x(trace.checkpoints[c].step.toDouble());
      final bool chosen = trace.checkpoints[c].step == view.step;
      canvas.drawLine(
        Offset(cx, plot.bottom),
        Offset(cx, plot.bottom + (chosen ? 8 : 5)),
        Paint()
          ..strokeWidth = chosen ? 2 : 1.2
          ..color = chosen ? view.inks.signal : view.inks.quiet,
      );
    }
    view.kit.draw(canvas, '1', inked(view.kit.mono, 8.5, view.inks.quiet), Offset(plot.left, plot.bottom + 9));
    view.kit.draw(
      canvas,
      '$count steps',
      inked(view.kit.mono, 8.5, view.inks.quiet),
      Offset(plot.right, plot.bottom + 9),
      anchor: const Offset(1, 0),
    );

    // The loss, as far as the run has got.
    final Path path = Path()..moveTo(x(1), y(trace.loss(1)));
    final int whole = step.floor().clamp(1, count);
    for (int s = 2; s <= whole; s++) {
      path.lineTo(x(s.toDouble()), y(trace.loss(s)));
    }
    final double now = between(step, trace.loss, count);
    path.lineTo(x(step), y(now));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = view.inks.ink,
    );
    final Offset head = Offset(x(step), y(now));
    canvas.drawCircle(head, 5.5, Paint()..color = view.inks.signal.withValues(alpha: 0.25));
    canvas.drawCircle(head, 3.2, Paint()..color = view.inks.signal);
    // Above the head, clear of the levels' names at the right, on a backing
    // of the ground where it crosses a level's line.
    final TextStyle value = inked(view.kit.mono, 10, view.inks.signal);
    final Size label = view.kit.layout(nats(now), value).size;
    final double ax = head.dx > plot.right - 40 ? 1 : 0.5;
    final Offset at = head + const Offset(0, -9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx - label.width * ax - 2, at.dy - label.height - 1, label.width + 4, label.height + 2),
        const Radius.circular(2),
      ),
      Paint()..color = view.inks.ground.withValues(alpha: 0.85),
    );
    view.kit.draw(canvas, nats(now), value, at, anchor: Offset(ax, 1));

    // The learning rate under it, warm-up then cosine.
    final Rect rate = layout.rate;
    double top = 0;
    for (int s = 0; s < count; s++) {
      top = math.max(top, trace.steps.learningRate[s]);
    }
    final Path lr = Path();
    for (int s = 1; s <= count; s++) {
      final Offset p = Offset(x(s.toDouble()), rate.bottom - rate.height * trace.steps.learningRate[s - 1] / top);
      if (s == 1) {
        lr.moveTo(p.dx, p.dy);
      } else {
        lr.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      lr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = view.inks.quiet.withValues(alpha: 0.7),
    );
    final double rateNow = between(step, (int s) => trace.steps.learningRate[s - 1], count);
    canvas.drawCircle(
      Offset(x(step), rate.bottom - rate.height * rateNow / top),
      2.6,
      Paint()..color = view.inks.signal,
    );
    view.kit.draw(
      canvas,
      'lr',
      inked(view.kit.mono, 8.5, view.inks.quiet),
      Offset(plot.left - 5, rate.center.dy),
      anchor: const Offset(1, 0.5),
    );
  }

  void _map(Canvas canvas, LmView view, _Layout layout, double step) {
    final TrainingTrace trace = view.trace;
    final int count = trace.steps.count;
    for (int p = 0; p < trace.peptides.length; p++) {
      final TracePeptide peptide = trace.peptides[p];
      final double top = layout.rowTop(p);
      final bool focus = p == view.peptide;
      view.kit.draw(
        canvas,
        peptide.source.label,
        inked(view.kit.sans, 9.5, focus ? view.inks.ink : view.inks.quiet),
        Offset(layout.left, top),
      );
      for (int i = 0; i < peptide.inputs; i++) {
        final int id = trace.targetAt(p, i);
        final double loss = between(step, (int s) => trace.targetLoss(s, p, i), count);
        final double given = math.exp(-loss);
        final Rect cell = Rect.fromLTWH(
          layout.left + i * layout.cell,
          top + 12,
          layout.cell,
          layout.cell,
        );
        final Color full = trace.isResidue(id) ? view.inks.residue(trace.token(id)) : view.inks.quiet;
        final Rect tile = cell.deflate(0.6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.18)),
          Paint()..color = Color.lerp(view.inks.zero, full, given)!,
        );
        if (tile.height >= 9) {
          view.kit.draw(
            canvas,
            glyph(trace, id),
            inked(
              view.kit.mono,
              (tile.height * 0.66).clamp(6.0, 11.0),
              given > 0.45 ? view.inks.ground : view.inks.quiet,
            ),
            tile.center,
            anchor: const Offset(0.5, 0.5),
          );
        }
      }
    }
  }

  void _weights(Canvas canvas, LmView view, _Layout layout, double step) {
    final TrainingTrace trace = view.trace;
    final int count = trace.steps.count;
    final double scale = headScale(view);
    final int rows = trace.vocab.length;
    final int width = trace.model.width;
    final GridMesh grid = GridMesh(layout.weights, width, rows);
    for (int r = 0; r < rows; r++) {
      for (int d = 0; d < width; d++) {
        final double w = between(step, (int s) => trace.headWeight(s, r, d), count);
        grid.cell(d, r, view.inks.signed(w / scale));
      }
    }
    grid.draw(canvas);
    view.kit.draw(
      canvas,
      'Output layer',
      inked(view.kit.sans, 9, view.inks.quiet),
      Offset(layout.weights.left, layout.weights.top - 3),
      anchor: const Offset(0, 1),
    );
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final _Layout layout = _Layout(size, view);
    final TrainingTrace trace = view.trace;
    final Rect plot = layout.chart;
    if (at.dy >= plot.top && at.dy <= plot.bottom + 24) {
      final int count = trace.steps.count;
      int? nearest;
      double best = 18;
      for (int c = 0; c < trace.checkpoints.length; c++) {
        final double cx = plot.left +
            plot.width * (count <= 1 ? 1 : (trace.checkpoints[c].step - 1) / (count - 1));
        if ((cx - at.dx).abs() < best) {
          best = (cx - at.dx).abs();
          nearest = c;
        }
      }
      if (nearest != null) {
        return PickCheckpoint(nearest);
      }
    }
    for (int p = 0; p < trace.peptides.length; p++) {
      final double top = layout.rowTop(p);
      if (at.dy >= top && at.dy < top + 12 + layout.cell + 2) {
        return FocusPeptide(p);
      }
    }
    return null;
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final int count = trace.steps.count;
    final double step = LoopPace.of(trace).at(frame.local).step;
    final int shown = step.round().clamp(1, count);
    final String line = 'Step $shown of $count · ${nats(between(step, trace.loss, count))} nats · '
        'lr ${scientific(trace.steps.learningRate[shown - 1])}';
    final (String, int)? level = passed(trace, step);
    return level == null ? line : '$line · under ${level.$1} since step ${level.$2}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) =>
      'Training loop. ${caption(view, frame)}. Floor ${nats(view.trace.floor)} nats.';
}

final class _Layout {
  _Layout(Size size, LmView view) : left = 16 {
    final double right = size.width - 16;
    final double width = right - left;
    final TrainingTrace trace = view.trace;
    final int longest = trace.peptides.map((TracePeptide p) => p.inputs).reduce(math.max);
    cell = math.min(14, width / longest);
    pitch = 12 + cell + 5;
    final double chartHeight = (size.height * 0.36).clamp(96.0, 230.0);
    final double map = pitch * trace.peptides.length;
    final double rows = trace.vocab.length.toDouble();
    final double room = size.height - 16 - (chartHeight + 24 + 12 + 16 + map + 18);
    final double weightsHeight = math.max(0, math.min(room, rows * 3.4));
    final double content = chartHeight + 24 + 12 + 16 + map + 18 + weightsHeight;
    final double top = math.max(12, (size.height - content) / 2 + 4);
    chart = Rect.fromLTWH(left + 22, top, width - 22, chartHeight);
    rate = Rect.fromLTWH(chart.left, chart.bottom + 24, chart.width, 12);
    mapTop = rate.bottom + 16;
    weights = Rect.fromLTWH(left, mapTop + map + 18, width, weightsHeight);
  }

  final double left;
  late final Rect chart;
  late final Rect rate;
  late final double cell;
  late final double mapTop;
  late final double pitch;
  late final Rect weights;

  double rowTop(int peptide) => mapTop + peptide * pitch;
}
