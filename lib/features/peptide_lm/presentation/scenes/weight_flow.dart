import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lm_format.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

/// When a row flows through a weight matrix, number by number, as the stages
/// draw a vector times the model's own weights (Scores' query, key and value):
/// the strings into each number made leave the row's numbers at the first of
/// [fanAt] and reach the number at the second, the number made only as they
/// land; then they settle, faint, a weight on each, until [webOut]. The first
/// numbers can go on their own, one after another ([alone]), the rest in one
/// [cascade].
@immutable
final class WeightFlow {
  const WeightFlow({
    this.alone = const <(double, double)>[],
    required this.cascade,
    required this.webOut,
    this.firstRelax = 0.2,
  });

  /// When the first numbers' strings run, each on its own.
  final List<(double, double)> alone;

  /// When the rest run: the first leaves at its start, the last lands at its
  /// end.
  final (double, double) cascade;

  /// When the strings left behind go.
  final (double, double) webOut;

  /// How long the first number's strings stay lit after they land; the
  /// others' stay [_relax].
  final double firstRelax;

  /// How long a fan takes in a cascade.
  static const double fanLong = 0.25;

  /// How strong the strings left behind are drawn once they have landed:
  /// faint, under the strings the row lights.
  static const double webStrength = 0.5;

  static const double _relax = 0.2;

  /// When the strings into number [out] of [width] run: they leave the row at
  /// the first and reach the number at the second.
  (double, double) fanAt(int out, int width) {
    final int alone = math.min(this.alone.length, width);
    if (out < alone) {
      return this.alone[out];
    }
    final (double from, double to) = cascade;
    final int rest = width - alone;
    final double stagger = rest < 2 ? 0 : (to - from - fanLong) / (rest - 1);
    final double start = from + (out - alone) * stagger;
    return (start, start + fanLong);
  }

  /// How far number [out] of [width] is made at [beat]: it fills as its
  /// strings land.
  double madeAt(int out, int width, double beat) {
    final double landed = fanAt(out, width).$2;
    return through(beat, landed - 0.1, landed + 0.1);
  }

  /// How far number [out] of [width] is written beside its tile: once it is
  /// made.
  double written(int out, int width, double beat) {
    final double landed = fanAt(out, width).$2;
    return through(beat, landed, landed + 0.15);
  }

  /// How long the strings into number [out] stay lit after they land,
  /// settling into the faint weights.
  double relax(int out) => out == 0 ? firstRelax : _relax;

  /// How far the strings into number [out] of [width] have settled at
  /// [beat]: left behind, faint, once the number is made.
  double settled(int out, int width, double beat) {
    final double landed = fanAt(out, width).$2;
    return through(beat, landed + 0.05, landed + relax(out));
  }

  /// How far the row is flowing through the weights at [beat], of [width]
  /// numbers: from just before the first fan to just after the last.
  double flowing(int width, double beat) {
    final double first = fanAt(0, width).$1;
    final double last = fanAt(width - 1, width).$2;
    return through(beat, first - 0.15, first) * (1 - through(beat, last + 0.1, last + 0.3));
  }

  /// How strongly the strings show at [beat], of [width] numbers: from the
  /// first fan until [webOut].
  double webShown(int width, double beat) {
    final double first = fanAt(0, width).$1;
    return through(beat, first - 0.05, first) * (1 - through(beat, webOut.$1, webOut.$2));
  }
}

/// The largest of [outputs] × [inputs] weights, never quite zero: the scale
/// the strings left behind are drawn on.
double weightReach(int outputs, int inputs, double Function(int out, int d) weight) {
  double most = 1e-9;
  for (int out = 0; out < outputs; out++) {
    for (int d = 0; d < inputs; d++) {
      most = math.max(most, weight(out, d).abs());
    }
  }
  return most;
}

/// The largest of what the strings carry from [input] into [outputs]
/// numbers, a number of it times a weight: the scale the lit strings are
/// drawn on.
double productReach(List<double> input, int outputs, double Function(int out, int d) weight) {
  double most = 1e-9;
  for (int out = 0; out < outputs; out++) {
    for (int d = 0; d < input.length; d++) {
      most = math.max(most, (weight(out, d) * input[d]).abs());
    }
  }
  return most;
}

/// The strings left behind, a weight on each, from each number of the row
/// ([from]) to each of [outputs] numbers made ([to]): in the colour of the
/// weight's sign, as strong as it against [most], quieter while the row
/// flows; each number's settling in as its lit strings go.
void drawWeights(
  Canvas canvas,
  LmView view,
  WeightFlow flow, {
  required int inputs,
  required int outputs,
  required double Function(int out, int d) weight,
  required Offset Function(int d) from,
  required Offset Function(int out) to,
  required double most,
  required double beat,
  required double alpha,
}) {
  drawEdges(
    canvas,
    view,
    <(int, int, double)>[
      for (int out = 0; out < outputs; out++)
        for (int d = 0; d < inputs; d++) (d, out, weight(out, d)),
    ],
    from,
    to,
    alpha * (1 - 0.35 * flow.flowing(outputs, beat)) * WeightFlow.webStrength,
    most: most,
    alphaOf: (int out) => flow.settled(out, outputs, beat),
  );
}

/// The row flowing through the weights: the strings into each of [outputs]
/// numbers being made, lit from the row's [input] numbers ([from]) out to it
/// ([to]), each carrying its number times its [weight], in that product's
/// colour and as strong as it against [most]; a dot at each tip until it
/// lands; lit while they run, then settling into the faint weights once the
/// number is made.
void drawFans(
  Canvas canvas,
  LmView view,
  WeightFlow flow, {
  required List<double> input,
  required int outputs,
  required double Function(int out, int d) weight,
  required Offset Function(int d) from,
  required Offset Function(int out) to,
  required double most,
  required double beat,
  required double alpha,
}) {
  final LineBatch batch = LineBatch();
  final Paint tip = Paint();
  final List<(Offset, double, Color)> tips = <(Offset, double, Color)>[];
  for (int out = 0; out < outputs; out++) {
    final (double leaves, double lands) = flow.fanAt(out, outputs);
    if (beat <= leaves) {
      continue;
    }
    final double glow = 1 - through(beat, lands + 0.05, lands + flow.relax(out));
    if (glow <= 0) {
      continue;
    }
    final double reached = through(beat, leaves, lands);
    final Offset end = to(out);
    for (int d = 0; d < input.length; d++) {
      final double carried = weight(out, d) * input[d];
      final double w = math.min(1.0, carried.abs() / most);
      final Offset start = from(d);
      final Offset at = Offset.lerp(start, end, reached)!;
      final Color color = carried >= 0 ? view.inks.positive : view.inks.negative;
      batch.line(start, at, color, 1.0 + 1.6 * w, (0.45 + 0.55 * math.pow(w, 1.2)) * glow * alpha);
      // Each number on its way, a dot at the string's tip until it lands.
      final double travelling = alpha * (1 - through(reached, 0.85, 1));
      if (travelling > 0) {
        tips.add((at, 1.3 + 1.2 * w, color.withValues(alpha: (0.55 + 0.45 * w) * travelling)));
      }
    }
  }
  batch.draw(canvas);
  for (final (Offset at, double radius, Color color) in tips) {
    canvas.drawCircle(at, radius, tip..color = color);
  }
}

/// The numbers not yet made, each an empty slot ([tile]) outlined in the
/// quiet ink, as [made] of the way as its number.
void drawSlots(Canvas canvas, LmView view, Rect Function(int out) tile, double alpha, List<double> made) {
  if (alpha <= 0) {
    return;
  }
  final Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  for (int out = 0; out < made.length; out++) {
    final double a = alpha * (1 - made[out]);
    if (a <= 0) {
      continue;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile(out).deflate(1), const Radius.circular(1.5)),
      paint..color = view.inks.quiet.withValues(alpha: 0.6 * a),
    );
  }
}

/// A standing column of [colors], a tile each ([tile]).
void drawColumn(Canvas canvas, Rect Function(int d) tile, List<Color> colors) {
  final Paint paint = Paint();
  for (int d = 0; d < colors.length; d++) {
    if (colors[d].a <= 0) {
      continue;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile(d).deflate(0.5), const Radius.circular(1.5)),
      paint..color = colors[d],
    );
  }
}

/// A column's [numbers], each beside its tile ([tile]), at its [left] or its
/// right, in [textSize] where the bench [writes] numbers.
void drawColumnNumbers(
  Canvas canvas,
  LmView view,
  Rect Function(int d) tile,
  List<double> numbers,
  double alpha, {
  required double textSize,
  required bool writes,
  bool left = false,
  double Function(int d)? alphaOf,
}) {
  if (alpha <= 0 || !writes) {
    return;
  }
  for (int d = 0; d < numbers.length; d++) {
    final double a = alpha * (alphaOf == null ? 1 : alphaOf(d));
    if (a <= 0) {
      continue;
    }
    final Rect at = tile(d);
    view.kit.draw(
      canvas,
      fixed(numbers[d], 2),
      inked(view.kit.mono, textSize, view.inks.ink, alpha: a),
      left ? Offset(at.left - 4, at.center.dy) : Offset(at.right + 4, at.center.dy),
      anchor: Offset(left ? 1 : 0, 0.5),
    );
  }
}

/// A column's name over it: centred on [x], over its [top].
void drawColumnTitle(Canvas canvas, LmView view, String text, double alpha, {required double x, required double top}) {
  if (alpha > 0) {
    view.kit.draw(
      canvas,
      text,
      inked(view.kit.sans, 9, view.inks.quiet, alpha: alpha),
      Offset(x, top - 4),
      anchor: const Offset(0.5, 1),
    );
  }
}

/// Where the weights stand, [text], under their [plate]: centred on it, kept
/// between [left] and [right].
void drawPlateStatus(
  Canvas canvas,
  LmView view,
  Rect plate,
  String text,
  double alpha, {
  required double left,
  required double right,
}) {
  final TextStyle words = inked(view.kit.sans, 8.5, view.inks.quiet, alpha: alpha);
  final double wide = view.kit.layout(text, words).width;
  final double x = (plate.center.dx - wide / 2).clamp(left, math.max(left, right - wide));
  view.kit.draw(canvas, text, words, Offset(x, plate.bottom + 3));
}
