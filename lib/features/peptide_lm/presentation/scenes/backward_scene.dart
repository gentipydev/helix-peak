import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'predict_scene.dart';

/// Backward: the loss's gradient, first at the output, p − y, then carried
/// back down through every layer to the embeddings. Each module's gradient
/// norm fills its bar on the way, each position's own glows at every level,
/// and where the gradients' total norm is over the clip, all of them are
/// scaled down to it.
final class BackwardScene extends LmScene {
  const BackwardScene();

  static const double _flipTo = 0.18;
  static const double _waveTo = 0.78;

  /// Each rail box's gradient norm at [step], before clipping: the embedding
  /// (tokens and positions), each block (attention, feed-forward, norms), the
  /// final norm and the output layer.
  static List<double> moduleNorms(TrainingTrace trace, int step) {
    final ModuleRail rail = ModuleRail(Rect.zero, trace.model.layers);
    final List<double> squares = List<double>.filled(rail.count, 0);
    for (int g = 0; g < trace.groups.length; g++) {
      final double value = trace.groupGrad(step, g);
      squares[rail.boxOf(trace.groups[g])] += value * value;
    }
    return <double>[for (final double s in squares) math.sqrt(s)];
  }

  /// The run's smallest and largest module norms, as powers of ten, so a bar
  /// is on one scale at every step.
  static (double, double) normRange(LmView view) => view.kit.memo<(double, double)>(
    ('module-norms', view.trace.name),
    () {
      double low = double.infinity;
      double high = -double.infinity;
      for (int s = 1; s <= view.trace.steps.count; s++) {
        for (final double v in moduleNorms(view.trace, s)) {
          if (v > 0) {
            low = math.min(low, math.log(v) / math.ln10);
            high = math.max(high, math.log(v) / math.ln10);
          }
        }
      }
      return (low, math.max(high, low + 1e-6));
    },
  );

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final _Layout layout = _Layout(size, view);
    final double u = frame.local;
    final ModuleRail rail = layout.rail;
    final int points = trace.points.length;

    // The wave comes down from the output layer: head, norm, the blocks from
    // the top, the embedding last.
    final double wave = through(u, _flipTo, _waveTo) * (rail.count + 0.5);
    final List<double> lit = <double>[
      for (int i = 0; i < rail.count; i++) (wave - (rail.count - 1 - i)).clamp(0.0, 1.0),
    ];
    final List<double> norms = moduleNorms(trace, view.step);
    final (double low, double high) = normRange(view);
    final double clip = trace.steps.clip[view.step - 1];
    final double clipped = through(u, _waveTo + 0.08, 1);
    final List<double> bars = <double>[
      for (int i = 0; i < rail.count; i++)
        lit[i] *
            (norms[i] <= 0
                ? 0
                : ((math.log(norms[i] * (1 - clipped * (1 - clip))) / math.ln10 - low) / (high - low))
                      .clamp(0.0, 1.0)),
    ];
    rail.paint(canvas, view, lit: lit, litColor: view.inks.error, bars: bars, barColor: view.inks.error);

    // The gradient at the output: p − y.
    final List<int> order = barOrder(trace);
    final List<double> p = probabilities(view, view.position);
    final double flip = through(u, 0, _flipTo);
    final Rect errors = layout.errors;
    final double slot = errors.width / order.length;
    final double zero = errors.center.dy;
    canvas.drawLine(
      Offset(errors.left, zero),
      Offset(errors.right, zero),
      Paint()
        ..strokeWidth = 1
        ..color = view.inks.rule,
    );
    for (int k = 0; k < order.length; k++) {
      final int id = order[k];
      final double value = id == view.target ? p[k] - flip : p[k];
      final double h = errors.height / 2 * value.clamp(-1.0, 1.0);
      final Color color = trace.isResidue(id) ? view.inks.residue(trace.token(id)) : view.inks.quiet;
      canvas.drawRect(
        Rect.fromLTRB(
          errors.left + k * slot + slot * 0.18,
          math.min(zero, zero - h),
          errors.left + (k + 1) * slot - slot * 0.18,
          math.max(zero, zero - h),
        ),
        Paint()..color = id == view.target ? view.inks.error : color.withValues(alpha: 0.85),
      );
      if (id == view.target && flip > 0) {
        // The target's own error, which may be all but nothing once learned.
        view.kit.draw(
          canvas,
          '${trace.token(id)} ${signed(value, 2)}',
          inked(view.kit.mono, 9, view.inks.error, alpha: flip),
          Offset(errors.left + (k + 0.5) * slot, math.max(zero, zero - h) + 3),
          anchor: const Offset(0.5, 0),
        );
      }
    }
    view.kit.draw(
      canvas,
      'p − y',
      inked(view.kit.mono, 9, view.inks.quiet),
      errors.topLeft,
    );

    // The clip: the gradients' total norm against its limit.
    final double norm = trace.steps.gradNorm[view.step - 1];
    final double limit = trace.config.gradClip;
    final Rect gauge = layout.gauge;
    final double span = math.max(norm, limit) * 1.25;
    final double gaugeAlpha = through(u, _waveTo, _waveTo + 0.08);
    if (gaugeAlpha > 0) {
      final Paint line = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = view.inks.rule.withValues(alpha: gaugeAlpha);
      canvas.drawLine(Offset(gauge.left, gauge.center.dy), Offset(gauge.right, gauge.center.dy), line);
      final double limitX = gauge.left + gauge.width * limit / span;
      canvas.drawLine(
        Offset(limitX, gauge.top),
        Offset(limitX, gauge.bottom),
        Paint()
          ..strokeWidth = 1.2
          ..color = view.inks.ink.withValues(alpha: gaugeAlpha),
      );
      final double shown = norm * (1 - clipped * (1 - clip));
      final double needle = gauge.left + gauge.width * shown / span;
      canvas.drawLine(
        Offset(gauge.left, gauge.center.dy),
        Offset(needle, gauge.center.dy),
        line..color = view.inks.error.withValues(alpha: gaugeAlpha),
      );
      canvas.drawCircle(Offset(needle, gauge.center.dy), 4, Paint()..color = view.inks.error.withValues(alpha: gaugeAlpha));
      view.kit.draw(
        canvas,
        clip < 1 ? '‖g‖ ${norm.toStringAsFixed(2)} × ${clip.toStringAsFixed(2)}' : '‖g‖ ${norm.toStringAsFixed(2)}',
        inked(view.kit.mono, 9, view.inks.error, alpha: gaugeAlpha),
        Offset(gauge.left, gauge.top - 2),
        anchor: const Offset(0, 1),
      );
      view.kit.draw(
        canvas,
        'clip ${limit.toStringAsFixed(1)}',
        inked(view.kit.mono, 9, view.inks.quiet, alpha: gaugeAlpha),
        Offset(limitX, gauge.bottom + 2),
        anchor: const Offset(0.5, 0),
      );
    }

    // Each position's share at every point of the stream, top down.
    final Rect map = layout.map;
    final int inputs = view.focus.inputs;
    double lowest = double.infinity;
    double highest = -double.infinity;
    for (int k = 0; k < points; k++) {
      for (int i = 0; i < inputs; i++) {
        final double g = trace.pointGrad(view.checkpoint, k, view.peptide, i);
        if (g > 0) {
          lowest = math.min(lowest, math.log(g));
          highest = math.max(highest, math.log(g));
        }
      }
    }
    final double rowHeight = map.height / points;
    final double streamWave = through(u, _flipTo, _waveTo) * (points + 1);
    for (int k = 0; k < points; k++) {
      final double reached = (streamWave - (points - 1 - k)).clamp(0.0, 1.0);
      final double y = map.bottom - (k + 0.5) * rowHeight;
      view.kit.draw(
        canvas,
        trace.points[k],
        inked(view.kit.mono, 8, view.inks.quiet),
        Offset(map.left - 4, y),
        anchor: const Offset(1, 0.5),
      );
      if (reached <= 0) {
        continue;
      }
      for (int i = 0; i < inputs; i++) {
        final double g = trace.pointGrad(view.checkpoint, k, view.peptide, i);
        final double share = g <= 0 || highest <= lowest
            ? 0
            : (math.log(g) - lowest) / (highest - lowest);
        final double radius = (0.8 + share * math.min(rowHeight, layout.tokens.cell) * 0.42) * reached;
        canvas.drawCircle(
          Offset(layout.tokens.centre(i), y),
          radius,
          Paint()..color = view.inks.error.withValues(alpha: (0.25 + 0.75 * share) * reached),
        );
      }
    }
    for (int i = 0; i < inputs; i++) {
      drawToken(
        canvas,
        view,
        layout.tokens.at(i),
        trace.inputAt(view.peptide, i),
        outline: i == view.position ? view.inks.signal : null,
      );
    }
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = _Layout(size, view).tokens.indexAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) =>
      _Layout(size, view).tokens.indexAt(at, slack: 40);

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    if (frame.local < _flipTo) {
      final List<int> order = barOrder(trace);
      final double p = probabilities(view, view.position)[order.indexOf(view.target)];
      return 'At the output the gradient is p − y: ${trace.token(view.target)} '
          '${signed(p - 1, 2)}, every other token +p';
    }
    final double norm = trace.steps.gradNorm[view.step - 1];
    final double clip = trace.steps.clip[view.step - 1];
    if (frame.local < _waveTo) {
      final List<double> norms = moduleNorms(trace, view.step);
      final ModuleRail rail = ModuleRail(Rect.zero, trace.model.layers);
      int top = 0;
      for (int i = 1; i < norms.length; i++) {
        if (norms[i] > norms[top]) {
          top = i;
        }
      }
      return 'Backpropagation, layer by layer: the largest gradient at '
          '${rail.label(top)}, norm ${norms[top].toStringAsFixed(3)}';
    }
    return clip < 1
        ? 'All the gradients\' norm, ${norm.toStringAsFixed(2)}, is over '
            '${trace.config.gradClip}: each is scaled × ${clip.toStringAsFixed(2)}'
        : 'All the gradients\' norm, ${norm.toStringAsFixed(3)}, is under '
            '${trace.config.gradClip}: nothing is clipped';
  }

  @override
  String describe(LmView view, TrainingFrame frame) =>
      'Backward pass, step ${view.step}. ${caption(view, frame)}.';
}

final class _Layout {
  _Layout(Size size, LmView view) {
    const double railWidth = 62;
    const double left = 10 + railWidth + 30;
    final double right = size.width - 14;
    final double width = right - left;
    final int inputs = view.focus.inputs;
    final double cell = math.min(22, width / inputs);
    final double errorsHeight = (size.height * 0.18).clamp(46.0, 96.0);
    final int points = view.trace.points.length;
    final double above = 14 + errorsHeight + 22 + 12 + 22;
    final double below = 6 + cell + 12;
    final double rowHeight = ((size.height - 16 - above - below) / points).clamp(10.0, 30.0);
    final double content = above + rowHeight * points + below;
    final double top = math.max(8, (size.height - content) / 2);
    errors = Rect.fromLTWH(left, top + 14, width, errorsHeight);
    gauge = Rect.fromLTWH(left + 4, errors.bottom + 22, width - 8, 12);
    final double mapTop = gauge.bottom + 22;
    final double mapBottom = mapTop + rowHeight * points;
    tokens = TokenLayout(Rect.fromLTWH(left, mapBottom + 6, width, cell), inputs, most: 22);
    map = Rect.fromLTRB(tokens.bounds.left, mapTop, tokens.bounds.right, mapBottom);
    rail = ModuleRail(Rect.fromLTWH(10, top, railWidth, content), view.trace.model.layers);
  }

  late final ModuleRail rail;
  late final TokenLayout tokens;
  late final Rect errors;
  late final Rect gauge;
  late final Rect map;
}
