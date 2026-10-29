import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'predict_scene.dart';

/// Loss: what came next was certain, a probability of one; the model gave it
/// p. The gap is scored as −ln p, the surprise, and every target's surprise
/// in the batch is averaged into the one number the step minimises.
final class LossScene extends LmScene {
  const LossScene();

  static const double _truthTo = 0.22;
  static const double _curveTo = 0.48;
  static const double _stripsTo = 0.8;

  /// The surprise most worth a full colour: a little over evenly guessing.
  static double strongest(TrainingTrace trace) => trace.uniform * 1.5;

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final _Layout layout = _Layout(size, view);
    final double u = frame.local;
    final double loss = trace.targetLoss(view.step, view.peptide, view.position);
    final double p = math.exp(-loss);

    // The prediction, on an axis that reaches certainty, and the truth's bar.
    final List<int> order = barOrder(trace);
    final int column = order.indexOf(view.target);
    final Rect bars = layout.bars;
    drawProbabilityBars(
      canvas,
      view,
      bars,
      probabilities(view, view.position),
      axis: 1,
      target: view.target,
    );
    final double truth = through(u, 0, _truthTo);
    final double slot = bars.width / order.length;
    final double plot = bars.height - 14;
    final double x = bars.left + (column + 0.5) * slot;
    if (truth > 0) {
      final Rect ghost = Rect.fromLTRB(
        x - slot * 0.42,
        bars.top + plot * (1 - truth),
        x + slot * 0.42,
        bars.top + plot,
      );
      dashedLine(canvas, ghost.topLeft, ghost.topRight, Paint()..color = view.inks.truth..strokeWidth = 1.2, dash: 3, gap: 2);
      dashedLine(canvas, ghost.topLeft, ghost.bottomLeft, Paint()..color = view.inks.truth..strokeWidth = 1, dash: 3, gap: 2);
      dashedLine(canvas, ghost.topRight, ghost.bottomRight, Paint()..color = view.inks.truth..strokeWidth = 1, dash: 3, gap: 2);
      // The gap between what was given and certainty.
      final double gapTop = bars.top + plot * (1 - truth);
      final double gapBottom = bars.top + plot * (1 - p.clamp(0.0, 1.0));
      if (gapBottom > gapTop) {
        final double bx = x + slot * 0.62;
        final Paint bracket = Paint()
          ..color = view.inks.error
          ..strokeWidth = 1.6;
        canvas.drawLine(Offset(bx, gapTop), Offset(bx, gapBottom), bracket);
        canvas.drawLine(Offset(bx - 3, gapTop), Offset(bx + 3, gapTop), bracket);
        canvas.drawLine(Offset(bx - 3, gapBottom), Offset(bx + 3, gapBottom), bracket);
      }
    }

    // The surprise: −ln p, from nothing at certainty to more and more below it.
    final Rect curve = layout.curve;
    final double ceiling = math.max(strongest(trace), loss * 1.1);
    Offset point(double q) => Offset(
      curve.left + curve.width * q,
      curve.bottom - curve.height * (-math.log(math.max(q, 1e-9)) / ceiling).clamp(0.0, 1.0),
    );
    final Paint axes = Paint()
      ..strokeWidth = 1
      ..color = view.inks.rule;
    canvas.drawLine(curve.bottomLeft, curve.bottomRight, axes);
    canvas.drawLine(curve.bottomLeft, curve.topLeft, axes);
    final Path path = Path();
    for (int k = 0; k <= 60; k++) {
      final double q = math.exp(-ceiling * (1 - k / 60));
      final Offset at = point(q);
      if (k == 0) {
        path.moveTo(at.dx, at.dy);
      } else {
        path.lineTo(at.dx, at.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = view.inks.quiet,
    );
    view.kit.draw(canvas, '−ln p', inked(view.kit.mono, 9, view.inks.quiet), curve.topLeft + const Offset(4, 0));
    view.kit.draw(canvas, 'p', inked(view.kit.mono, 9, view.inks.quiet), curve.bottomRight + const Offset(0, 3), anchor: const Offset(1, 0));
    final double travel = through(u, _truthTo, _curveTo);
    if (travel > 0) {
      final double q = 1 - (1 - p) * travel;
      final Offset dot = point(q);
      dashedLine(canvas, Offset(dot.dx, curve.bottom), dot, Paint()..color = view.inks.error..strokeWidth = 0.8);
      dashedLine(canvas, Offset(curve.left, dot.dy), dot, Paint()..color = view.inks.error..strokeWidth = 0.8);
      canvas.drawCircle(dot, 4, Paint()..color = view.inks.error);
      view.kit.draw(
        canvas,
        '−ln ${q.toStringAsFixed(2)} = ${nats(-math.log(q))}',
        inked(view.kit.mono, 10, view.inks.error),
        Offset(curve.right, curve.top + 14),
        anchor: const Offset(1, 0),
      );
    }

    // Every target's surprise, and their mean.
    final double fill = through(u, _curveTo, _stripsTo);
    final int peptides = trace.peptides.length;
    final double strong = strongest(trace);
    for (int pep = 0; pep < peptides; pep++) {
      final TracePeptide peptide = trace.peptides[pep];
      final double top = layout.rowTop(pep);
      final bool focus = pep == view.peptide;
      view.kit.draw(
        canvas,
        peptide.source.label,
        inked(view.kit.sans, 9.5, focus ? view.inks.ink : view.inks.quiet),
        Offset(layout.left, top),
      );
      final double reached = (fill * (peptides + 2) - pep) * peptide.inputs;
      for (int i = 0; i < peptide.inputs; i++) {
        final Rect cell = Rect.fromLTWH(
          layout.left + i * layout.cell,
          top + 12,
          layout.cell - 1,
          layout.cell - 1,
        );
        canvas.drawRect(cell, Paint()..color = view.inks.zero);
        if (i < reached) {
          final double surprise = trace.targetLoss(view.step, pep, i) / strong;
          canvas.drawRect(
            cell,
            Paint()..color = view.inks.error.withValues(alpha: math.sqrt(surprise.clamp(0.0, 1.0))),
          );
        }
        if (focus && i == view.position) {
          canvas.drawRect(
            cell.inflate(1),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = view.inks.truth,
          );
        }
      }
    }
    final double pooled = through(u, _stripsTo, 1);
    if (pooled > 0) {
      _mean(canvas, view, layout, pooled);
    }
  }

  void _mean(Canvas canvas, LmView view, _Layout layout, double alpha) {
    final TrainingTrace trace = view.trace;
    final double mean = trace.loss(view.step);
    final Rect scale = layout.scale;
    final double most = math.max(trace.uniform, mean) * 1.08;
    double x(double v) => scale.left + scale.width * (v / most);
    canvas.drawLine(
      Offset(scale.left, scale.center.dy),
      Offset(scale.right, scale.center.dy),
      Paint()
        ..strokeWidth = 1
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
    dashedLine(
      canvas,
      Offset(x(trace.uniform), scale.top),
      Offset(x(trace.uniform), scale.bottom),
      Paint()
        ..strokeWidth = 1
        ..color = view.inks.quiet.withValues(alpha: alpha),
      dash: 2,
      gap: 2,
    );
    view.kit.draw(
      canvas,
      'uniform ${nats(trace.uniform)}',
      inked(view.kit.mono, 8.5, view.inks.quiet, alpha: alpha),
      Offset(x(trace.uniform), scale.top - 1),
      anchor: const Offset(0.5, 1),
    );
    canvas.drawCircle(Offset(x(mean), scale.center.dy), 4.5, Paint()..color = view.inks.error.withValues(alpha: alpha));
    view.kit.draw(
      canvas,
      'loss ${nats(mean)}',
      inked(view.kit.mono, 10, view.inks.error, alpha: alpha),
      Offset(x(mean), scale.bottom + 1),
      anchor: const Offset(0.5, 0),
    );
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final _Layout layout = _Layout(size, view);
    for (int pep = 0; pep < view.trace.peptides.length; pep++) {
      final double top = layout.rowTop(pep);
      if (at.dy >= top && at.dy < top + 12 + layout.cell + 2) {
        if (pep != view.peptide) {
          return FocusPeptide(pep);
        }
        final int i = ((at.dx - layout.left) / layout.cell).floor();
        return i >= 0 && i < view.focus.inputs ? FocusPosition(i) : null;
      }
    }
    return null;
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double loss = trace.targetLoss(view.step, view.peptide, view.position);
    final String after = readSoFar(trace, view.peptide, view.position);
    if (frame.local < _curveTo) {
      return '${trace.token(view.target)} after $after was given '
          '${percent(math.exp(-loss))}: −ln p = ${nats(loss)} nats';
    }
    return 'Mean of ${trace.targetCount} targets: ${nats(trace.loss(view.step))} nats '
        '(residues ${nats(trace.steps.residueLoss[view.step - 1])}, '
        '<eos> ${nats(trace.steps.eosLoss[view.step - 1])}); uniform ${nats(trace.uniform)}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) =>
      'Loss, step ${view.step}. ${caption(view, frame)}.';
}

final class _Layout {
  _Layout(Size size, LmView view) : left = 16 {
    final double right = size.width - 16;
    final double width = right - left;
    final int peptides = view.trace.peptides.length;
    final double chart = (size.height * 0.34).clamp(84.0, 180.0);
    final int longest = view.trace.peptides.map((TracePeptide p) => p.inputs).reduce(math.max);
    cell = math.min(12, width / longest);
    const double scaleBlock = 14 + 14 + 26;
    pitch = ((size.height - 32 - chart - 22 - scaleBlock) / peptides)
        .clamp(12 + cell + 2, 12 + cell + 10);
    final double content = chart + 22 + pitch * peptides + scaleBlock;
    final double top = math.max(16, (size.height - content) / 2 + 8);
    bars = Rect.fromLTWH(left, top, width * 0.56, chart);
    curve = Rect.fromLTWH(left + width * 0.64, top + 6, width * 0.36, chart - 6);
    stripsTop = bars.bottom + 22;
    scale = Rect.fromLTWH(left + 8, stripsTop + pitch * peptides + 14, width - 16, 14);
  }

  final double left;
  late final Rect bars;
  late final Rect curve;
  late final double cell;
  late final double stripsTop;
  late final double pitch;
  late final Rect scale;

  double rowTop(int peptide) => stripsTop + peptide * pitch;
}
