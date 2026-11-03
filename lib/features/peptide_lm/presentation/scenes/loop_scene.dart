import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/loop_pace.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'loss_scene.dart';
import 'predict_scene.dart';
import 'share_map.dart';
import 'stream_table.dart';
import 'update_scene.dart';

/// Loop: the step the stages showed, again and again, on the batch made once.
///
/// The stage opens on Update's last frame, every weight moved once, and puts
/// step 1 back together: its guesses, as Predict's map, and their cost, the
/// first point of a curve. Then it runs: steps 2 to 4 one at a time, each a
/// hair lower, then on to each step the run kept whole, held there for what
/// the loss has passed (an even guess, residue counts, residue pairs, one
/// nat, a tenth of one) and what the map now shows; and last, what no model
/// can learn here, and the run whole.
///
/// The map is Predict's at every step, from the probabilities each step
/// kept; every number written is a kept step's own, whole.
final class LoopScene extends LmScene {
  const LoopScene();

  // Within the opening, from the start of step 1's guesses: Update's grid
  // goes; the map's tag, tiles and empty slots come; each row's squares grow
  // in, top to bottom; the slots of what came next light, with the answer
  // key, and its shares.
  static const (double, double) _gridOut = (0, 0.4);
  static const (double, double) _mapIn = (0.3, 0.7);
  static const (double, double) _rowsGrow = (0.7, 1.7);
  static const double _rowGrow = 0.25;
  static const (double, double) _keyIn = (1.7, 2.0);
  static const (double, double) _givenIn = (1.9, 2.2);

  // From the start of step 1's cost: the axes and the levels; the kept
  // steps' ticks; step 1's point.
  static const (double, double) _axesIn = (0, 0.5);
  static const (double, double) _ticksIn = (0.2, 0.6);
  static const (double, double) _pointIn = (0.6, 0.9);

  // At a stop, how long its numbers take to come and to go.
  static const double _writeIn = 0.2;
  static const double _writeOut = 0.15;

  // At the end, how far the rows but the first dim, and how fast.
  static const double _dim = 0.55;
  static const double _dimTurn = 0.3;

  static double _span(double beat, double from, (double, double) span) =>
      through(beat, from + span.$1, from + span.$2);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final LoopPace pace = LoopPace.of(view.trace);
    final LoopMoment now = pace.at(frame.local);
    if (now.beat <= 0) {
      const UpdateScene().paintEnd(canvas, size, view);
      return;
    }
    final double g0 = pace.span(LoopPart.guesses).from;
    final double gridLeft = 1 - _span(now.beat, g0, _gridOut);
    if (gridLeft > 0) {
      const UpdateScene().paintEnd(canvas, size, view, UpdateFade(note: 0, grid: gridLeft));
    }
    final LoopLayout layout = LoopLayout(size, view);
    layout.table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, UpdateScene.notes(view).last.$3), ...notes(view)],
      now.beat,
    );
    _curve(canvas, view, layout, pace, now);
    _rate(canvas, view, layout, pace, now);
    _map(canvas, view, layout, pace, now);
  }

  // ------------------------------------------------------------------ data

  /// [view] at checkpoint [index], with [peptide] in focus (at its first
  /// place, where it is another).
  static LmView at(LmView view, int index, {int? peptide}) => LmView(
    trace: view.trace,
    checkpoint: view.trace.checkpoints[index],
    peptide: peptide ?? view.peptide,
    position: peptide == null || peptide == view.peptide ? view.position : 0,
    head: view.head,
    inks: view.inks,
    kit: view.kit,
  );

  /// The checkpoint a moment shows whole: step 1's before the run moves, a
  /// kept step's while it holds, the last's at the end; none on the way.
  static int? shownWhole(LoopPace pace, LoopMoment now, TrainingTrace trace) => switch (now.part) {
    LoopPart.done || LoopPart.guesses || LoopPart.cost => 0,
    LoopPart.hold => pace.stops[now.stop].checkpoint,
    LoopPart.left || LoopPart.heart => trace.checkpoints.length - 1,
    LoopPart.move || LoopPart.single => null,
  };

  /// What every place of the peptide in focus gives each token that can come
  /// next at [step], as the step kept it; between two steps, on the straight
  /// line between.
  static List<List<double>> shares(LmView view, double step) {
    final TrainingTrace trace = view.trace;
    final int count = trace.steps.count;
    final int a = step.floor().clamp(1, count);
    final int b = math.min(count, a + 1);
    final double t = (step - a).clamp(0.0, 1.0);
    final int columns = trace.allowed.length;
    double share(int s, int i, int k) => trace.stepProbability(s, view.peptide, i, k);
    return <List<double>>[
      for (int i = 0; i < view.focus.inputs; i++)
        <double>[
          for (int k = 0; k < columns; k++)
            t == 0 ? share(a, i, k) : share(a, i, k) + (share(b, i, k) - share(a, i, k)) * t,
        ],
    ];
  }

  /// The loss at [step]; between two steps, on the straight line between.
  static double lossAt(TrainingTrace trace, double step) {
    final int count = trace.steps.count;
    final int a = step.floor().clamp(1, count);
    final int b = math.min(count, a + 1);
    final double t = (step - a).clamp(0.0, 1.0);
    return trace.loss(a) + (trace.loss(b) - trace.loss(a)) * t;
  }

  /// How many of the batch's places give what came next most, at checkpoint
  /// [index]: Predict's top guess, from the whole logits.
  static int right(LmView view, int index) => view.kit.memo<int>(('loop-right', view.trace.name, index), () {
    int count = 0;
    for (int p = 0; p < view.trace.peptides.length; p++) {
      count += PredictScene.right(at(view, index, peptide: p));
    }
    return count;
  });

  /// How many of the batch's places give what came next over half, at
  /// checkpoint [index].
  static int sure(LmView view, int index) => view.kit.memo<int>(('loop-sure', view.trace.name, index), () {
    final LmView there = at(view, index);
    int count = 0;
    for (int p = 0; p < view.trace.peptides.length; p++) {
      for (int i = 0; i < view.trace.peptides[p].inputs; i++) {
        if (LossScene.given(there, p, i) > 0.5) {
          count += 1;
        }
      }
    }
    return count;
  });

  /// The token most places give most at checkpoint [index], and at how many.
  static (int, int) commonestGuess(LmView view, int index) =>
      view.kit.memo<(int, int)>(('loop-commonest-guess', view.trace.name, index), () {
        final Map<int, int> counts = <int, int>{};
        for (int p = 0; p < view.trace.peptides.length; p++) {
          final LmView there = at(view, index, peptide: p);
          for (int i = 0; i < view.trace.peptides[p].inputs; i++) {
            final int top = PredictScene.top(there, i);
            counts[top] = (counts[top] ?? 0) + 1;
          }
        }
        return _most(counts);
      });

  /// The token that comes next at the most places of the batch, and at how
  /// many.
  static (int, int) commonestTarget(TrainingTrace trace) {
    final Map<int, int> counts = <int, int>{};
    for (int p = 0; p < trace.peptides.length; p++) {
      for (int i = 0; i < trace.peptides[p].inputs; i++) {
        final int y = trace.targetAt(p, i);
        counts[y] = (counts[y] ?? 0) + 1;
      }
    }
    return _most(counts);
  }

  /// The most counted, the lowest id of a tie.
  static (int, int) _most(Map<int, int> counts) {
    (int, int) best = (-1, 0);
    for (final MapEntry<int, int> entry in counts.entries) {
      if (entry.value > best.$2 || (entry.value == best.$2 && entry.key < best.$1)) {
        best = (entry.key, entry.value);
      }
    }
    return best;
  }

  /// The steps after [a], up to [b], whose gradients went over the clip.
  static List<int> clipped(TrainingTrace trace, int a, int b) => <int>[
    for (int s = a + 1; s <= b; s++)
      if (trace.steps.clip[s - 1] < 1) s,
  ];

  /// What checkpoint [index] was kept for: the deepest level it passed.
  static String why(TrainingTrace trace, int index) {
    const List<String> order = <String>['first', 'uniform', 'unigram', 'bigram', 'one_nat', 'tenth_nat', 'last'];
    String deepest = 'first';
    for (final String w in trace.checkpoints[index].why) {
      if (order.indexOf(w) > order.indexOf(deepest)) {
        deepest = w;
      }
    }
    return deepest;
  }

  /// Whether the loss ever rose from one step to the next.
  static bool everRose(TrainingTrace trace) {
    for (int s = 2; s <= trace.steps.count; s++) {
      if (trace.loss(s) > trace.loss(s - 1)) {
        return true;
      }
    }
    return false;
  }

  /// The run of stops on the way that [stop] is one of, one step after
  /// another with no hold between: its first and its last.
  static (int, int) singles(LoopPace pace, int stop) {
    int first = stop;
    while (first > 0 && !pace.stops[first - 1].held && pace.stops[first - 1].step == pace.stops[first].step - 1) {
      first -= 1;
    }
    int last = stop;
    while (last + 1 < pace.stops.length &&
        !pace.stops[last + 1].held &&
        pace.stops[last + 1].step == pace.stops[last].step + 1) {
      last += 1;
    }
    return (first, last);
  }

  /// The step a stop's move starts from.
  static int from(LoopPace pace, int stop) => stop == 0 ? 1 : pace.stops[stop - 1].step;

  /// One of [n], as the end writes it: "a sixth" for one of six.
  static String fraction(int n) => switch (n) {
    2 => 'a half',
    3 => 'a third',
    4 => 'a quarter',
    5 => 'a fifth',
    6 => 'a sixth',
    7 => 'a seventh',
    8 => 'an eighth',
    _ => '1/$n',
  };

  // ------------------------------------------------------------- the curve

  /// The loss at every step so far, against the levels to beat and the floor
  /// no model can pass, the steps kept whole ticked under it.
  void _curve(Canvas canvas, LmView view, LoopLayout layout, LoopPace pace, LoopMoment now) {
    final double c0 = pace.span(LoopPart.cost).from;
    final double axes = _span(now.beat, c0, _axesIn);
    if (axes <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final Rect plot = layout.plot;
    final int? kept = shownWhole(pace, now, trace);
    final String? held = now.part == LoopPart.hold && kept != null ? why(trace, kept) : null;
    final double written = _written(pace, now);
    final double ending = now.part == LoopPart.left || now.part == LoopPart.heart ? 1 : 0;

    final Paint axis = Paint()
      ..strokeWidth = 1
      ..color = view.inks.rule.withValues(alpha: axes);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axis);
    for (int n = 0; n <= layout.ceiling.floor(); n++) {
      final double lit = held == 'one_nat' && n == 1 ? written : 0;
      view.kit.draw(
        canvas,
        '$n',
        inked(view.kit.mono, 8.5, Color.lerp(view.inks.quiet, view.inks.ink, lit)!, alpha: axes),
        Offset(plot.left - 5, layout.y(n.toDouble())),
        anchor: const Offset(1, 0.5),
      );
    }
    view.kit.draw(
      canvas,
      'nats',
      inked(view.kit.sans, 8.5, view.inks.quiet, alpha: axes),
      Offset(plot.left - 4, plot.top - 6),
      anchor: const Offset(1, 1),
    );

    // The levels to beat, named at their right ends, where the curve has
    // gone by before it gets there; the floor at its left end, which the
    // curve never comes near. The level a kept step was kept for brightens
    // while it holds.
    final List<(String, String, double)> levels = <(String, String, double)>[
      ('uniform', 'even guess', trace.uniform),
      ('unigram', 'residue counts', trace.unigram),
      ('bigram', 'residue pairs', trace.bigram),
    ];
    final double floorBright = math.max(held == 'last' ? written : 0, ending);
    final double fy = layout.y(trace.floor);
    for (final (String key, _, double value) in levels) {
      _level(canvas, view, plot, layout.y(value), held == key ? written : 0, axes);
    }
    _level(canvas, view, plot, fy, floorBright, axes, dotted: true);
    // Their names over the lines, each on the ground, so a line pushed under
    // the name above it never runs through a name.
    double lastLabel = -100;
    for (final (String key, String name, double value) in levels) {
      final double bright = held == key ? written : 0;
      final double labelY = math.max(layout.y(value) - 2, lastLabel + 11);
      _label(
        canvas,
        view,
        '$name ${nats(value)}',
        inked(view.kit.mono, 8.5, Color.lerp(view.inks.quiet, view.inks.ink, bright)!, alpha: axes),
        Offset(plot.right, labelY),
        const Offset(1, 1),
        axes,
      );
      lastLabel = labelY;
    }
    _label(
      canvas,
      view,
      'floor ${nats(trace.floor)}',
      inked(view.kit.mono, 8.5, Color.lerp(view.inks.quiet, view.inks.ink, floorBright)!, alpha: axes),
      Offset(plot.left + 4, fy - 2),
      const Offset(0, 1),
      axes,
    );

    // The steps kept whole, the one the other stages show in the accent; the
    // one held named under its tick.
    final double ticks = _span(now.beat, c0, _ticksIn);
    for (int c = 0; c < trace.checkpoints.length; c++) {
      final double cx = layout.x(trace.checkpoints[c].step.toDouble());
      final bool chosen = trace.checkpoints[c].step == view.step;
      canvas.drawLine(
        Offset(cx, plot.bottom),
        Offset(cx, plot.bottom + (chosen ? 8 : 5)),
        Paint()
          ..strokeWidth = chosen ? 2 : 1.2
          ..color = (chosen ? view.inks.signal : view.inks.quiet).withValues(alpha: ticks),
      );
    }
    final TextStyle steps = inked(view.kit.mono, 8.5, view.inks.quiet, alpha: ticks);
    view.kit.draw(canvas, '1', steps, Offset(plot.left, plot.bottom + 9));
    view.kit.draw(
      canvas,
      '${grouped(trace.steps.count)} steps',
      steps,
      Offset(plot.right, plot.bottom + 9),
      anchor: const Offset(1, 0),
    );
    if (now.part == LoopPart.hold && written > 0) {
      final int step = pace.stops[now.stop].step;
      if (step != trace.steps.count) {
        view.kit.draw(
          canvas,
          '$step',
          inked(view.kit.mono, 8.5, view.inks.ink, alpha: written),
          Offset(layout.x(step.toDouble()), plot.bottom + 9),
          anchor: const Offset(0.5, 0),
        );
      }
    }

    // The loss, as far as the run has got, in the loss's honey.
    final double point = _span(now.beat, c0, _pointIn);
    if (point <= 0) {
      return;
    }
    final int count = trace.steps.count;
    final double step = now.step.clamp(1.0, count.toDouble());
    final double loss = lossAt(trace, step);
    final Path path = Path()..moveTo(layout.x(1), layout.y(trace.loss(1)));
    for (int s = 2; s <= step.floor(); s++) {
      path.lineTo(layout.x(s.toDouble()), layout.y(trace.loss(s)));
    }
    path.lineTo(layout.x(step), layout.y(loss));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = view.inks.error.withValues(alpha: point),
    );
    final Offset head = Offset(layout.x(step), layout.y(loss));
    canvas.drawCircle(head, 5.5, Paint()..color = view.inks.error.withValues(alpha: 0.25 * point));
    canvas.drawCircle(head, 3.2, Paint()..color = view.inks.error.withValues(alpha: point));

    // The loss written over the head while the run stands at a step, on a
    // backing of the ground where it crosses a level's line.
    final double label = math.min(point, written);
    if (label <= 0) {
      return;
    }
    // Clear of the axis's numbers at the left, and of the canvas's side at
    // the right.
    final double ax = head.dx < plot.left + 24
        ? 0
        : head.dx > plot.right - 40
        ? 1
        : 0.5;
    _label(
      canvas,
      view,
      nats(loss),
      inked(view.kit.mono, 10, view.inks.error, alpha: label),
      head + Offset(ax == 0 ? -3 : 0, -9),
      Offset(ax, 1),
      label,
    );
  }

  /// [text] at [at], [anchor] of its size there, on a backing of the ground,
  /// so a line it sits on never runs through it.
  static void _label(Canvas canvas, LmView view, String text, TextStyle style, Offset at, Offset anchor, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final Size wide = view.kit.layout(text, style).size;
    final Offset corner = at - Offset(wide.width * anchor.dx, wide.height * anchor.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius((corner & wide).inflate(1.5), const Radius.circular(2)),
      Paint()..color = view.inks.ground.withValues(alpha: 0.85 * alpha),
    );
    view.kit.draw(canvas, text, style, at, anchor: anchor);
  }

  /// A level's line across the plot at [y], dashed (the floor's dotted),
  /// [bright] of the way from the quiet ink to the ink.
  static void _level(Canvas canvas, LmView view, Rect plot, double y, double bright, double alpha, {bool dotted = false}) {
    final Color ink = Color.lerp(view.inks.quiet, view.inks.ink, bright)!;
    dashedLine(
      canvas,
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: (0.75 + 0.25 * bright) * alpha),
      dash: dotted ? 1.5 : 4,
      gap: dotted ? 2.5 : 3,
    );
  }

  /// How strongly a stop's numbers are written at [now]: in as the run comes
  /// to a stop, out before it moves on; step 1's once its point is drawn;
  /// the end's throughout.
  static double _written(LoopPace pace, LoopMoment now) {
    final LoopSpan span = now.span;
    final double out = _movesNext(pace, span) ? 1 - through(now.beat, span.to - _writeOut, span.to) : 1;
    return switch (now.part) {
      LoopPart.done || LoopPart.guesses || LoopPart.move => 0,
      LoopPart.cost => _span(now.beat, span.from, _pointIn) * out,
      LoopPart.single || LoopPart.hold => through(now.beat, span.from, span.from + _writeIn) * out,
      LoopPart.left || LoopPart.heart => 1,
    };
  }

  /// Whether the run moves on after [span].
  static bool _movesNext(LoopPace pace, LoopSpan span) {
    final int index = pace.spans.indexOf(span);
    return index + 1 < pace.spans.length && pace.spans[index + 1].part == LoopPart.move;
  }

  // -------------------------------------------------------------- the rate

  /// The learning rate at every step, under the curve on its steps, the step
  /// the run has reached marked; its value written while the run stands.
  void _rate(Canvas canvas, LmView view, LoopLayout layout, LoopPace pace, LoopMoment now) {
    final int first = pace.spans.indexWhere((LoopSpan s) => s.part == LoopPart.move);
    if (first < 0) {
      return;
    }
    final double shown = through(now.beat, pace.spans[first].from, pace.spans[first].from + 0.4);
    if (shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final Rect area = layout.rate;
    UpdateScene.drawSchedule(canvas, view, area, shown, step: now.step, named: false);
    view.kit.draw(
      canvas,
      'rate',
      inked(view.kit.mono, 8.5, view.inks.quiet, alpha: shown),
      Offset(area.left - 5, area.center.dy),
      anchor: const Offset(1, 0.5),
    );
    final double written = math.min(shown, _written(pace, now));
    if (written <= 0) {
      return;
    }
    final int step = now.step.round().clamp(1, trace.steps.count);
    double top = 0;
    for (int s = 0; s < trace.steps.count; s++) {
      top = math.max(top, trace.steps.learningRate[s]);
    }
    final double x = layout.x(step.toDouble());
    final double y = area.bottom - area.height * trace.steps.learningRate[step - 1] / top;
    final String text = UpdateScene.rate(trace.steps.learningRate[step - 1]);
    final TextStyle face = inked(view.kit.mono, 8.5, view.inks.signal, alpha: written);
    final double wide = view.kit.layout(text, face).width;
    final bool before = x + 7 + wide > area.right;
    final Offset to = Offset(before ? x - 7 : x + 7, y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(before ? to.dx - wide - 2 : to.dx - 2, y - 6, wide + 4, 12),
        const Radius.circular(2),
      ),
      Paint()..color = view.inks.ground.withValues(alpha: 0.85 * written),
    );
    view.kit.draw(canvas, text, face, to, anchor: Offset(before ? 1 : 0, 0.5));
  }

  // --------------------------------------------------------------- the map

  /// Predict's map of the peptide in focus, at the step the run has reached:
  /// it comes in as Predict made it at step 1, then changes with every step;
  /// at the end, the rows but the first dim.
  void _map(Canvas canvas, LmView view, LoopLayout layout, LoopPace pace, LoopMoment now) {
    final double g0 = pace.span(LoopPart.guesses).from;
    final double shown = _span(now.beat, g0, _mapIn);
    if (shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final ShareMapLayout map = layout.map;
    final int n = view.focus.inputs;
    final double lit = _span(now.beat, g0, _keyIn);
    final double left = pace.span(LoopPart.left).from;
    final double heart = pace.span(LoopPart.heart).from;
    final double dim = _dim * through(now.beat, left, left + _dimTurn) * (1 - through(now.beat, heart, heart + _dimTurn));

    drawTag(canvas, view, PredictScene.mapTag(view), Offset(layout.left, layout.tagTop), alpha: shown);
    ShareMap.drawRowTiles(canvas, view, map, alpha: shown);
    ShareMap.drawColumnTiles(canvas, view, map, alpha: shown);
    ShareMap.drawCells(
      canvas,
      view,
      map,
      shares(view, now.step),
      grown: (int i) {
        final double start = g0 + _rowsGrow.$1 + (n <= 1 ? 0 : (_rowsGrow.$2 - _rowsGrow.$1 - _rowGrow) * i / (n - 1));
        return through(now.beat, start, start + _rowGrow);
      },
      shown: (int i, int k, bool answer) => shown * (i == 0 ? 1 : 1 - dim),
      lit: (int i) => lit,
    );
    ShareMap.drawOutline(canvas, view, map, view.position, shown * (1 - dim));

    // The answer key: each row's next token, and the share a kept step's
    // whole logits gave it, written while the run stands at that step.
    final int? kept = shownWhole(pace, now, trace);
    final double given = kept == null ? 0 : math.min(_span(now.beat, g0, _givenIn), _givenShown(pace, now));
    final LmView? there = kept == null ? null : at(view, kept);
    ShareMap.drawAnswerKey(
      canvas,
      view,
      map,
      tiles: lit,
      numbers: given,
      given: (int i) => there == null ? 0 : PredictScene.shares(there, i)[trace.targetAt(view.peptide, i)],
    );
  }

  /// How strongly the answer key's shares are written: step 1's from the
  /// map's arrival until the run first moves; then as a stop's numbers are.
  static double _givenShown(LoopPace pace, LoopMoment now) => switch (now.part) {
    LoopPart.done || LoopPart.guesses => 1,
    LoopPart.cost => _movesNext(pace, now.span) ? 1 - through(now.beat, now.span.to - _writeOut, now.span.to) : 1,
    _ => _written(pace, now),
  };

  // ------------------------------------------------------------------ taps

  /// While Update's frame shows, and while the map comes in, a tap asks for
  /// nothing; then a kept step's tick picks it, and a row of the map puts
  /// its place in focus.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final LoopMoment now = LoopPace.of(view.trace).at(frame.local);
    if (now.part == LoopPart.done || now.part == LoopPart.guesses) {
      return null;
    }
    return hit(size, view, at);
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final LoopLayout layout = LoopLayout(size, view);
    final Rect plot = layout.plot;
    final TrainingTrace trace = view.trace;
    if (at.dy >= plot.top && at.dy <= plot.bottom + 24 && at.dx >= plot.left - 18 && at.dx <= plot.right + 18) {
      int? nearest;
      double best = 18;
      for (int c = 0; c < trace.checkpoints.length; c++) {
        final double cx = layout.x(trace.checkpoints[c].step.toDouble());
        if ((cx - at.dx).abs() < best) {
          best = (cx - at.dx).abs();
          nearest = c;
        }
      }
      if (nearest != null) {
        return PickCheckpoint(nearest);
      }
    }
    final int? i = layout.map.placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  // --------------------------------------------------------------- caption

  /// Why each part happens, over the canvas, a line a thought. The moves
  /// have none, so the eye is on the map and the curve while the run moves.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final LoopPace pace = LoopPace.of(trace);
    final int peptides = trace.peptides.length;
    final List<(double, double, String)> parts = <(double, double, String)>[];
    final LoopSpan done = pace.span(LoopPart.done);
    final LoopSpan guesses = pace.span(LoopPart.guesses);
    final LoopSpan cost = pace.span(LoopPart.cost);
    parts.add((
      0.25,
      done.to,
      'Training is that step again and again, on the batch made once:\n'
          'Embedding to Update, from the weights the last step left.\n'
          'Only the weights change; the ${spelled(peptides)} peptides never do.',
    ));
    parts.add((
      guesses.from,
      guesses.to,
      "The map is one peptide's; the loss, all ${spelled(peptides)} peptides'.\n"
          'Every step remakes it from the weights that step starts with.',
    ));
    parts.add((
      cost.from,
      cost.to,
      'Dashed, what simpler guesses score on these peptides:\n'
          'an even guess, residue counts, residue pairs.\n'
          'Dotted, the floor, which no model can pass here.',
    ));
    for (int j = 0; j < pace.stops.length; j++) {
      final LoopStop stop = pace.stops[j];
      if (!stop.held) {
        final (int first, int last) = singles(pace, j);
        if (j != first) {
          continue;
        }
        final LoopSpan start = pace.spans.firstWhere((LoopSpan s) => s.part == LoopPart.move && s.stop == first);
        final LoopSpan end = pace.spans.firstWhere((LoopSpan s) => s.part == LoopPart.single && s.stop == last);
        final int a = pace.stops[first].step;
        final int b = pace.stops[last].step;
        parts.add((
          start.from,
          end.to,
          'One update moves each guess by a hair, so the loss by a hair.\n'
              'The drops grow with the rate, which climbs a step at a time:\n'
              '${UpdateScene.rate(trace.steps.learningRate[a - 2])} at step ${a - 1}, '
              '${UpdateScene.rate(trace.steps.learningRate[b - 1])} at step $b.',
        ));
        continue;
      }
      final LoopSpan hold = pace.holdOf(stop.checkpoint!)!;
      parts.add((hold.from, hold.to, _holdNote(view, pace, j)));
    }
    final LoopSpan left = pace.span(LoopPart.left);
    final LoopSpan heart = pace.span(LoopPart.heart);
    final LmView end = at(view, trace.checkpoints.length - 1);
    final bool firstsDiffer = trace.peptides.map((TracePeptide p) => p.sequence[0]).toSet().length == peptides;
    parts.add((
      left.from,
      left.to,
      firstsDiffer
          ? 'No model can tell from <bos> which of ${spelled(peptides)} peptides comes:\n'
                'ln $peptides = ${fixed(math.log(peptides), 2)} nats at $peptides of '
                '${grouped(trace.targetCount)} places, ${percent(LossScene.bosShare(end))} of the loss.\n'
                'That is the floor, ${nats(trace.floor)}.'
          : 'No model can tell from <bos> which peptide comes:\n'
                '${percent(LossScene.bosShare(end))} of the loss is at the first places.\n'
                'That is the floor, ${nats(trace.floor)}.',
    ));
    parts.add((heart.from, double.infinity, _heartNote(view)));
    return parts;
  }

  /// A kept step's note: what the level it passed means, and what the map
  /// and the run show there.
  static String _holdNote(LmView view, LoopPace pace, int stop) {
    final TrainingTrace trace = view.trace;
    final int index = pace.stops[stop].checkpoint!;
    final List<int> clips = clipped(trace, from(pace, stop), pace.stops[stop].step);
    final String clip = clips.isEmpty
        ? ''
        : clips.length == 1
        ? 'Step ${clips.first} went over the clip.'
        : '${spelledLeading(clips.length)} steps from ${clips.first} to ${clips.last} went over the clip.';
    final int count = trace.steps.count;
    final List<String> lines = switch (why(trace, index)) {
      'uniform' => <String>[
        'An even guess gives each of ${trace.allowed.length} tokens 1/${trace.allowed.length}: '
            'ln ${trace.allowed.length} nats.',
        if (trace.loss(1) > trace.uniform) "Step 1's random weights favoured some tokens for no reason.",
        if (sure(view, index) == 0)
          'No place yet gives its answer as much as half.'
        else
          '${spelledLeading(sure(view, index))} places give their answer over half.',
      ],
      'unigram' => <String>[
        'Residue counts: each residue guessed by its share of the data,',
        'whatever came before. ${trace.token(commonestTarget(trace).$1)} is the commonest here, '
            '${commonestTarget(trace).$2} of ${grouped(trace.targetCount)}.',
      ],
      'bigram' => <String>[
        'Residue pairs: each guessed from the residue before alone.',
        'The rows now differ by what each place reads,',
        'through attention, from the places before it.',
      ],
      'one_nat' => <String>[
        'Here the guesses turn sure, one place after another:',
        'each square grows into its lit slot.',
      ],
      'tenth_nat' => <String>[
        '${grouped(sure(view, index))} of ${grouped(trace.targetCount)} places give their answer over half;',
        'the others are first places, read from <bos> alone.',
      ],
      'last' => <String>[
        'The rate peaked at ${UpdateScene.rate(trace.config.learningRate)}, then fell on a cosine '
            'to ${UpdateScene.rate(trace.steps.learningRate[count - 1])}.',
        'The last ${grouped(count ~/ 2)} steps took the loss from '
            '${nats(trace.loss(count - count ~/ 2))} to ${nats(trace.loss(count))}.',
        if (!everRose(trace)) 'No step of the ${grouped(count)} raised it.',
      ],
      _ => <String>[],
    };
    return <String>[...lines, if (clip.isNotEmpty) clip].join('\n');
  }

  /// The last note: what the run changed, and what it is.
  static String _heartNote(LmView view) {
    final TrainingTrace trace = view.trace;
    final (int r, int d) = UpdateScene.worked(view);
    final TraceCheckpoint first = trace.checkpoints.first;
    final TraceCheckpoint last = trace.checkpoints.last;
    final double start = trace.outputWeight(first, r, d);
    final double end = trace.outputWeight(last, r, d) + trace.headUpdate(last, r, d);
    return "Only the weights changed: ${trace.token(r)}'s from ${d + 1}, worked in Update,\n"
        'went from ${fixed(start, 4)} to ${fixed(end, 4)} in ${grouped(trace.steps.count)} steps.\n'
        'None of the ${spelled(trace.peptides.length)} was held out: the model has them by heart.';
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final LoopPace pace = LoopPace.of(view.trace);
    return _caption(view, pace, pace.at(frame.local));
  }

  String _caption(LmView view, LoopPace pace, LoopMoment now) {
    final TrainingTrace trace = view.trace;
    final int count = trace.steps.count;
    final bool fromStart = view.step != 1;
    switch (now.part) {
      case LoopPart.done:
        return view.step == 1
            ? 'Step 1 of ${grouped(count)} done: its guesses, its cost, one update of every weight'
            : 'Step ${view.step} of ${grouped(count)} done: every weight has now moved ${grouped(view.step)} times';
      case LoopPart.guesses:
        return fromStart
            ? "From the start: step 1's guesses, as Predict made them"
            : "Its guesses, as Predict made them: ${view.focus.source.label}'s ${grouped(view.focus.inputs)} places";
      case LoopPart.cost:
        return 'Its cost, the mean over ${grouped(trace.targetCount)} targets: '
            "${nats(trace.loss(1))}, the curve's first point";
      case LoopPart.move:
        final LoopStop stop = pace.stops[now.stop];
        if (!stop.held) {
          return _singles(trace, pace, now.stop);
        }
        final int a = from(pace, now.stop);
        final int b = stop.step;
        return b - a == 1
            ? 'Step $b: the loss falls from ${nats(trace.loss(a))} to ${nats(trace.loss(b))}'
            : 'Steps ${a + 1} to $b: the loss falls from ${nats(trace.loss(a))} to ${nats(trace.loss(b))}';
      case LoopPart.single:
        return _singles(trace, pace, now.stop);
      case LoopPart.hold:
        return _hold(view, pace, now.stop);
      case LoopPart.left:
        final int y = trace.targetAt(view.peptide, 0);
        final double share = PredictScene.shares(at(view, trace.checkpoints.length - 1), 0)[y];
        return 'What is left: <bos> gives each first residue about ${fraction(trace.peptides.length)}: '
            '${trace.token(y)} ${percent(share)}';
      case LoopPart.heart:
        final LmView end = at(view, trace.checkpoints.length - 1);
        return 'Step ${grouped(count)} of ${grouped(count)}: ${view.focus.source.label} right at '
            '${grouped(PredictScene.right(end))} of its ${grouped(view.focus.inputs)} places';
    }
  }

  /// Steps on the way, one at a time: how far each moved the loss.
  static String _singles(TrainingTrace trace, LoopPace pace, int stop) {
    final (int first, int last) = singles(pace, stop);
    final int a = pace.stops[first].step;
    final int b = pace.stops[last].step;
    final List<String> falls = <String>[
      for (int s = a; s <= b; s++) signed(trace.loss(s) - trace.loss(s - 1), 3),
    ];
    if (a == b) {
      return 'Step $a, from the weights step ${a - 1} left: the loss moves ${falls.single}';
    }
    final String listed = falls.length == 2
        ? '${falls[0]} then ${falls[1]}'
        : '${falls.sublist(0, falls.length - 1).join(', ')}, then ${falls.last}';
    return 'Steps $a to $b, each a hair lower: $listed';
  }

  /// A kept step held: the level it passed, its loss, and the run's own
  /// count of right guesses there.
  static String _hold(LmView view, LoopPace pace, int stop) {
    final TrainingTrace trace = view.trace;
    final int index = pace.stops[stop].checkpoint!;
    final int step = pace.stops[stop].step;
    final String loss = nats(trace.loss(step));
    final String places = grouped(trace.targetCount);
    final String right = 'right at ${grouped(LoopScene.right(view, index))} of $places';
    switch (why(trace, index)) {
      case 'uniform':
        return 'Step $step: $loss, first under an even guess; $right';
      case 'unigram':
        final (int guess, int times) = commonestGuess(view, index);
        return 'Step $step: $loss, under residue counts; ${trace.token(guess)} tops $times of $places places';
      case 'bigram':
        return 'Step $step: $loss, under residue pairs; $right';
      case 'one_nat':
        return 'Step $step: $loss, under one nat; $right';
      case 'tenth_nat':
        return 'Step $step: $loss, under a tenth of one; $right';
      case 'last':
        return 'Step $step: $loss; the floor here is ${nats(trace.floor)}; $right';
    }
    return 'Step $step: $loss; $right';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Training loop. ${caption(view, frame)}.';
}

/// Loop's canvas: the note where every stage has it; under it the curve,
/// the kept steps ticked under its axis, the rate's strip on the same steps;
/// then the map's tag and Predict's map on rows of its own, as large as the
/// room left allows, the curve giving way where the map would be too small
/// for its tiles' letters.
final class LoopLayout {
  LoopLayout(Size size, LmView view) : table = StreamTable(size, view) {
    final EmbeddingLayout e = table.layout;
    final TrainingTrace trace = view.trace;
    left = e.left;
    right = e.right;
    final double top = e.tagTop;
    final double tag = tagSize(view, PredictScene.mapTag(view)).height;
    final int places = view.focus.inputs;
    final double around = _over + _under + _rateGap + _rateHeight + _tagGap + tag + _mapGap;
    final double room = math.max(0.0, size.height - _edge - top - around);
    double curve = (size.height * _curveShare).clamp(_leastCurve, _mostCurve);
    final double wanted = (places + 1) * _wantedPitch + _columnGap;
    if (room - curve < wanted) {
      curve = math.max(_leastCurve, room - wanted);
    }
    plot = Rect.fromLTRB(left + _gutter, top + _over, right - 2, top + _over + curve);
    rate = Rect.fromLTRB(plot.left, plot.bottom + _under + _rateGap, plot.right, plot.bottom + _under + _rateGap + _rateHeight);
    tagTop = rate.bottom + _tagGap;
    final double mapTop = tagTop + tag + _mapGap;
    final double pitch = math.max(1.0, math.min(_mostPitch, (size.height - _edge - mapTop - _columnGap) / (places + 1)));
    final double chip = (pitch - 3).clamp(3.0, 14.0);
    map = ShareMapLayout(
      view: view,
      top: mapTop,
      pitch: pitch,
      chipSide: chip,
      labelLeft: left,
      dx: 0,
      mapLeft: left + chip + _chipGap,
      right: right,
    );
    ceiling = math.max(trace.loss(1), trace.uniform) * 1.06;
    _count = trace.steps.count;
  }

  final StreamTable table;

  /// From the canvas's foot; over the plot, for its unit's name; under it,
  /// for the ticks and the steps' numbers; the rate's strip; the tag's gaps
  /// from the strip and from the map.
  static const double _edge = 6;
  static const double _over = 14;
  static const double _under = 16;
  static const double _rateGap = 6;
  static const double _rateHeight = 12;
  static const double _tagGap = 12;
  static const double _mapGap = 6;

  /// The axis's numbers' gutter; the room under the map's last row for the
  /// tiles naming its columns; and from a row's tile to its cells.
  static const double _gutter = 22;
  static const double _columnGap = 4;
  static const double _chipGap = 3;

  /// The curve's height: a share of the canvas, held between these.
  static const double _curveShare = 0.22;
  static const double _leastCurve = 64;
  static const double _mostCurve = 160;

  /// The map's rows: tall enough for their tiles to carry letters where the
  /// curve can give the room; never taller than the table's.
  static const double _wantedPitch = 11.5;
  static const double _mostPitch = 22;

  late final double left;
  late final double right;

  /// The curve's plot, and the rate's strip under it.
  late final Rect plot;
  late final Rect rate;

  /// The map's tag, and the map.
  late final double tagTop;
  late final ShareMapLayout map;

  /// How many nats the plot is tall.
  late final double ceiling;
  late final int _count;

  /// Where [step] lies across the plot.
  double x(double step) => plot.left + plot.width * (_count <= 1 ? 1 : (step - 1) / (_count - 1));

  /// Where [nats] lies up the plot.
  double y(double nats) => plot.bottom - plot.height * (nats / ceiling).clamp(0.0, 1.0);
}
