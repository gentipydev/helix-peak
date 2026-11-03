import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'predict_scene.dart';

/// Update: AdamW turns the clipped gradient into a step for every weight,
/// about the learning rate in size whatever the gradient's, and the weights
/// move by it. Shown on the output layer, whose rows are the tokens the
/// prediction's bars stand for.
final class UpdateScene extends LmScene {
  const UpdateScene();

  static const double _gradientFrom = 0.15;
  static const double _gradientTo = 0.4;
  static const double _updateTo = 0.6;
  static const double _movedTo = 0.85;

  /// How many times the update is drawn larger than the weights' own scale.
  static double magnification(LmView view) {
    final double update = _largest(view.checkpoint.headUpdate);
    return update <= 0 ? 1 : headScale(view) / update;
  }

  static double _largest(List<double> values) =>
      values.fold<double>(0, (double most, double v) => math.max(most, v.abs()));

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final _Layout layout = _Layout(size, view);
    final double u = frame.local;
    final int rows = trace.vocab.length;
    final int width = trace.model.width;
    final double weights = headScale(view);
    final double gradientScale = math.max(1e-12, _largest(view.checkpoint.headGrad));
    final double updateScale = math.max(1e-12, _largest(view.checkpoint.headUpdate));

    // Which picture the matrix shows, and how far into the next it has turned.
    final double toGradient = through(u, _gradientFrom, _gradientTo);
    final double toUpdate = through(u, _gradientTo, _updateTo);
    final double toMoved = through(u, _updateTo, _movedTo);
    final GridMesh matrix = GridMesh(layout.matrix, width, rows, rowGap: 0.6);
    for (int r = 0; r < rows; r++) {
      for (int d = 0; d < width; d++) {
        final double w = trace.headWeight(view.step, r, d);
        final double g = trace.headGrad(view.checkpoint, r, d);
        final double delta = trace.headUpdate(view.checkpoint, r, d);
        final Color before = view.inks.signed(w / weights);
        final Color gradient = view.inks.signed(g / gradientScale);
        final Color update = view.inks.signed(delta / updateScale);
        final Color after = view.inks.signed((w + delta) / weights);
        final Color shown;
        if (toUpdate <= 0) {
          shown = Color.lerp(before, gradient, toGradient)!;
        } else if (toMoved <= 0) {
          shown = Color.lerp(gradient, update, toUpdate)!;
        } else {
          shown = Color.lerp(update, after, toMoved)!;
        }
        matrix.cell(d, r, shown);
      }
    }
    matrix.draw(canvas);
    final double rowHeight = layout.matrix.height / rows;
    for (int r = 0; r < rows; r++) {
      final double y = layout.matrix.top + (r + 0.5) * rowHeight;
      view.kit.draw(
        canvas,
        glyph(trace, r),
        inked(
          view.kit.mono,
          math.min(9, rowHeight + 2),
          trace.isResidue(r) ? view.inks.residue(trace.token(r)) : view.inks.quiet,
        ),
        Offset(layout.matrix.left - 4, y),
        anchor: const Offset(1, 0.5),
      );
      if (trace.allowedIndex(r) < 0) {
        // Never a target, so its row learns nothing: only the decay moves it.
        dashedLine(
          canvas,
          Offset(layout.matrix.left, y),
          Offset(layout.matrix.right, y),
          Paint()
            ..strokeWidth = 0.8
            ..color = view.inks.quiet,
          dash: 2,
          gap: 3,
        );
      }
    }
    // The row of the token the position in focus was trained to predict.
    final double targetY = layout.matrix.top + view.target * rowHeight;
    canvas.drawRect(
      Rect.fromLTWH(layout.matrix.left - 1, targetY - 0.5, layout.matrix.width + 2, rowHeight + 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.truth,
    );
    final String title = toUpdate <= 0 && toGradient < 0.5
        ? 'Output layer, $rows × $width'
        : toMoved <= 0 && toUpdate < 0.5
        ? 'Gradient, clipped'
        : toMoved < 0.5
        ? 'AdamW update, drawn × ${grouped(magnification(view).round())}'
        : 'Output layer after the step';
    view.kit.draw(
      canvas,
      title,
      inked(view.kit.sans, 10, view.inks.ink),
      Offset(layout.matrix.left, layout.matrix.top - 4),
      anchor: const Offset(0, 1),
    );

    _groups(canvas, view, layout, through(u, _movedTo, 1));
    _schedule(canvas, view, layout);
  }

  /// For each module, its typical weight's gradient against its typical
  /// weight's step (each the root mean square): the gradients differ between
  /// modules many times over, Adam's steps far less.
  void _groups(Canvas canvas, LmView view, _Layout layout, double emphasis) {
    final TrainingTrace trace = view.trace;
    final List<double> gradients = perWeight(trace, view.step, trace.groupGrad);
    final List<double> steps = perWeight(trace, view.step, trace.groupUpdate);
    final double gradientTop = gradients.reduce(math.max);
    final double stepTop = steps.reduce(math.max);
    final ModuleRail rail = ModuleRail(Rect.zero, trace.model.layers);
    final Rect area = layout.groups;
    final double slot = area.width / rail.count;
    final double plot = area.height - 14;
    final double alpha = 0.55 + 0.45 * emphasis;
    for (int i = 0; i < rail.count; i++) {
      final double x = area.left + i * slot;
      final double g = gradientTop <= 0 ? 0 : gradients[i] / gradientTop;
      final double m = stepTop <= 0 ? 0 : steps[i] / stepTop;
      canvas.drawRect(
        Rect.fromLTWH(x + slot * 0.18, area.top + plot * (1 - g), slot * 0.3, plot * g),
        Paint()..color = view.inks.error.withValues(alpha: alpha),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + slot * 0.52, area.top + plot * (1 - m), slot * 0.3, plot * m),
        Paint()..color = view.inks.signal.withValues(alpha: alpha),
      );
      view.kit.draw(
        canvas,
        rail.label(i).replaceFirst('Block ', 'B'),
        inked(view.kit.sans, 8.5, view.inks.quiet),
        Offset(x + slot / 2, area.top + plot + 3),
        anchor: const Offset(0.5, 0),
      );
    }
    final Size gradient = view.kit.draw(
      canvas,
      'gradient',
      inked(view.kit.sans, 9.5, view.inks.error),
      Offset(area.left, area.top - 4),
      anchor: const Offset(0, 1),
    );
    final Size step = view.kit.draw(
      canvas,
      'step',
      inked(view.kit.sans, 9.5, view.inks.signal),
      Offset(area.left + gradient.width + 10, area.top - 4),
      anchor: const Offset(0, 1),
    );
    view.kit.draw(
      canvas,
      'per weight, each against its largest',
      inked(view.kit.sans, 9.5, view.inks.quiet),
      Offset(area.left + gradient.width + step.width + 20, area.top - 4),
      anchor: const Offset(0, 1),
    );
  }

  /// Each rail box's typical weight's [values] at [step]: the box's norm
  /// over the root of how many weights it holds.
  static List<double> perWeight(
    TrainingTrace trace,
    int step,
    double Function(int step, int group) values,
  ) {
    final ModuleRail rail = ModuleRail(Rect.zero, trace.model.layers);
    final List<double> squares = List<double>.filled(rail.count, 0);
    final List<int> sizes = List<int>.filled(rail.count, 0);
    for (int g = 0; g < trace.groups.length; g++) {
      final int box = rail.boxOf(trace.groups[g]);
      final double value = values(step, g);
      squares[box] += value * value;
      sizes[box] += trace.groupSizes[g];
    }
    return <double>[
      for (int i = 0; i < rail.count; i++) sizes[i] == 0 ? 0 : math.sqrt(squares[i] / sizes[i]),
    ];
  }

  /// The learning rate at every step, warm-up then cosine, and this one.
  void _schedule(Canvas canvas, LmView view, _Layout layout) {
    final TrainingTrace trace = view.trace;
    final Rect area = layout.schedule;
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
        ..color = view.inks.quiet,
    );
    final Offset here = at(view.step);
    canvas.drawCircle(here, 4, Paint()..color = view.inks.signal);
    view.kit.draw(
      canvas,
      'lr ${scientific(trace.steps.learningRate[view.step - 1])}',
      inked(view.kit.mono, 9, view.inks.signal),
      Offset(area.left, area.top - 3),
      anchor: const Offset(0, 1),
    );
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double lr = trace.steps.learningRate[view.step - 1];
    final int warmup = trace.config.warmupSteps;
    if (frame.local < _gradientTo) {
      final double clip = trace.steps.clip[view.step - 1];
      return clip < 1
          ? 'The gradient, clipped × ${clip.toStringAsFixed(2)}, lands on the weights'
          : 'The gradient, not clipped, lands on the weights';
    }
    if (frame.local < _updateTo) {
      final String phase = view.step <= warmup
          ? 'warm-up step ${view.step} of $warmup'
          : 'cosine, step ${view.step} of ${trace.steps.count}';
      return 'AdamW: lr ${scientific(lr)}, $phase';
    }
    double moved = 0;
    for (int r = 0; r < trace.vocab.length; r++) {
      for (int d = 0; d < trace.model.width; d++) {
        moved = math.max(moved, trace.headUpdate(view.checkpoint, r, d).abs());
      }
    }
    return 'The output layer moved ${scientific(moved)} at most this step';
  }

  @override
  String describe(LmView view, TrainingFrame frame) =>
      'Update, step ${view.step}. ${caption(view, frame)}.';
}

final class _Layout {
  _Layout(Size size, LmView view) {
    const double left = 16;
    final double right = size.width - 16;
    final double width = right - left;
    const double labels = 14;
    final int rows = view.trace.vocab.length;
    final double rowHeight = ((size.height * 0.42) / rows).clamp(3.5, 9.0);
    final double groupsHeight = (size.height * 0.18).clamp(50.0, 96.0);
    const double scheduleHeight = 40;
    final double content = 22 + rowHeight * rows + 34 + groupsHeight + 30 + scheduleHeight;
    final double top = math.max(8, (size.height - content) / 2);
    matrix = Rect.fromLTWH(left + labels, top + 22, width - labels, rowHeight * rows);
    groups = Rect.fromLTWH(left, matrix.bottom + 34, width, groupsHeight);
    schedule = Rect.fromLTWH(left, groups.bottom + 30, width, scheduleHeight);
  }

  late final Rect matrix;
  late final Rect groups;
  late final Rect schedule;
}
