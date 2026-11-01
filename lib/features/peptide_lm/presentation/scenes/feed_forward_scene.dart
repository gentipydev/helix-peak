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
import 'scores_scene.dart';
import 'stream_table.dart';

/// Feed-forward, block 1's second part, as the engine runs it (the block's
/// second LayerNorm, then `linear1`, GELU and `linear2`). It opens on
/// Attention's last frame, x0 + attention a row a place. A copy lifts off the
/// row in focus, evened out by the LayerNorm, and stands up as the network's
/// inputs; its weights reach every one of the neurons, which light by what
/// GELU lets through; theirs reach the outputs; and the outputs lie down onto
/// the row in focus. Every place goes through the same network, alone: what
/// it adds to each, alone on its own scale, and then added, block 1's output.
///
/// Every number is the run's: the inputs, the neurons, the weights as the
/// step found them, and each point of the stream, whole.
final class FeedForwardScene extends LmScene {
  const FeedForwardScene();

  /// The block this stage shows: the one Attention showed.
  static const int block = AttentionScene.block;

  static double get _beats => LmStage.feedForward.beats.toDouble();

  // The copy lifts off the row in focus as the other rows go quiet, its
  // numbers x0 + attention's, and stands up as the inputs, the table fading
  // under the network.
  static const (double, double) _quiet = (0.0, 0.6);
  static const (double, double) _lift = (0.4, 1.0);
  static const (double, double) _stand = (1.2, 2.0);
  static const (double, double) _tableOut = (1.2, 1.7);
  static const (double, double) _nodes = (1.9, 2.2);

  // The block's second LayerNorm evens the inputs out on Scores' chart,
  // beside them where the network will be: less their mean, over their
  // standard deviation, then the norm's own scale and shift. The row they
  // came from keeps its numbers.
  static const (double, double) _chartIn = (2.2, 2.5);
  static const (double, double) _centre = (2.7, 3.3);
  static const (double, double) _spread = (3.6, 4.2);
  static const (double, double) _learned = (4.5, 4.8);
  static const (double, double) _chartOut = (5.4, 5.7);

  // The neurons: the edges in, the signal along them, and each neuron lit.
  static const (double, double) _hiddenIn = (5.8, 6.3);
  static const double _fireFrom = 6.3;
  static const (double, double) _lit = (7.0, 8.0);
  static const double _outFrom = 8.4;

  // The outputs: the edges out, the signal along them, and each output.
  static const (double, double) _outIn = (8.4, 8.8);
  static const (double, double) _outputs = (9.2, 10.0);
  static const (double, double) _outputNumbers = (9.8, 10.3);

  // The outputs lie down on the row in focus; the network goes and the table
  // comes back.
  static const (double, double) _networkOut = (10.4, 10.8);
  static const (double, double) _layDown = (10.5, 11.3);
  static const (double, double) _tableIn = (10.8, 11.4);

  // What the feed-forward added, alone on its own scale, then the sums.
  static const (double, double) _alone = (11.4, 11.8);
  static const (double, double) _numbersOut = (11.4, 11.6);
  static const (double, double) _gainWritten = (11.6, 11.8);
  static const (double, double) _gainUnwritten = (12.2, 12.4);
  static const (double, double) _add = (12.3, 12.7);
  static const (double, double) _sumsWritten = (12.5, 12.7);

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// The points of the stream before and after this block's feed-forward.
  static int get _before => 2 * block + 1;
  static int get _after => 2 * block + 2;

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats);

  /// The stage's last frame: Forward opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view) => _paint(canvas, size, view, _beats);

  void _paint(Canvas canvas, Size size, LmView view, double beat) {
    if (beat <= 0) {
      const AttentionScene().paintEnd(canvas, size, view);
      return;
    }
    final FeedForwardLayout layout = FeedForwardLayout(size, view);
    final StreamTable table = layout.table;
    final int n = view.focus.inputs;
    final int width = view.trace.model.width;
    table.note(canvas, _attentionNote(view), beat);
    table.note(canvas, notes(view), beat);
    final double shown = 1 - _span(beat, _tableOut) + _span(beat, _tableIn);
    // The table's name goes with it while the network takes the canvas.
    table.tag(canvas, 'x0 + attention · $n × $width', (1 - _span(beat, _numbersOut)) * shown);
    table.tag(
      canvas,
      'what the feed-forward adds · $n × $width',
      through(beat, _numbersOut.$2, _numbersOut.$2 + 0.2) * (1 - _span(beat, _gainUnwritten)),
    );
    table.tag(canvas, "block 1's output · $n × $width", through(beat, _gainUnwritten.$2, _gainUnwritten.$2 + 0.2));
    drawFaded(canvas, size, view, shown, () {
      _stream(canvas, view, layout, beat);
      table.drawTiles(canvas);
      table.outline(canvas, view.position, table.row(view.position).right, 1);
    });
    _network(canvas, size, view, layout, beat);
    _chart(canvas, view, layout, beat);
    _copy(canvas, view, layout, beat);
  }

  /// The inputs at [beat], as the norm evens them out, and their colour
  /// scale, from the stream's toward the inputs' own as they are evened.
  static (List<double>, double) _inputsAt(LmView view, FeedForwardLayout layout, double beat) {
    final double centre = _span(beat, _centre);
    final double spread = _span(beat, _spread);
    final double learned = _span(beat, _learned);
    final double toward = (centre + spread + learned) / 3;
    final double scale = layout.table.scale + (layout.inputScale - layout.table.scale) * toward;
    return (evening(view).at(centre, spread, learned), scale);
  }

  /// Scores' chart of the evening out, beside the inputs, a bar a number.
  void _chart(Canvas canvas, LmView view, FeedForwardLayout layout, double beat) {
    final double alpha = _span(beat, _chartIn) * (1 - _span(beat, _chartOut));
    if (alpha <= 0) {
      return;
    }
    final double pitch = (layout.bottom - layout.top) / view.trace.model.width;
    ScoresScene.eveningChart(
      canvas,
      view,
      evening(view),
      _inputsAt(view, layout, beat).$1,
      tileAt: (int d) => Rect.fromCenter(center: layout.inputAt(d), width: 2 * layout.ioRadius, height: pitch),
      left: layout.chartLeft,
      right: layout.chartRight,
      centre: _span(beat, _centre),
      spread: _span(beat, _spread),
      learned: _span(beat, _learned),
      alpha: alpha,
    );
  }

  /// Attention's last note, going as this stage's come.
  static List<(double, double, String)> _attentionNote(LmView view) => <(double, double, String)>[
    (
      double.negativeInfinity,
      0.25,
      'nothing is overwritten: what attention found is added to the row\n'
          'next: the feed-forward, each place on its own',
    ),
  ];

  // ---------------------------------------------------------------- stream

  /// Each place's row: x0 + attention, the others quiet while the place in
  /// focus is worked on; then what the feed-forward adds, alone, and the sum.
  void _stream(Canvas canvas, LmView view, FeedForwardLayout layout, double beat) {
    final StreamTable table = layout.table;
    final int n = view.focus.inputs;
    final double scale = table.scale;
    final double gainScale = table.gainScale(_before, _after);
    final double quiet = _span(beat, _quiet) * (1 - _span(beat, _tableIn));
    final double alone = _span(beat, _alone);
    final double add = _span(beat, _add);
    final double beforeText = 1 - _span(beat, _numbersOut);
    final double gainText = _span(beat, _gainWritten) * (1 - _span(beat, _gainUnwritten));
    final double sumText = _span(beat, _sumsWritten);
    for (int i = 0; i < n; i++) {
      final Rect rect = table.row(i);
      final List<double> before = table.values(_before, i);
      final List<double> gain = table.gained(_before, _after, i);
      final List<double> after = table.values(_after, i);
      final double fade = i == view.position ? 1 : 1 - 0.7 * quiet;
      final List<Color> colors = <Color>[
        for (int d = 0; d < before.length; d++)
          Color.lerp(
            view.inks.ground,
            Color.lerp(
              Color.lerp(view.inks.cell(before[d] / scale), view.inks.cell(gain[d] / gainScale), alone)!,
              view.inks.cell(after[d] / scale),
              add,
            )!,
            fade,
          )!,
      ];
      table.drawRow(canvas, rect, before, scale: scale, colors: colors, text: beforeText * fade);
      if (gainText > 0) {
        table.drawRow(canvas, rect, gain, scale: gainScale, fill: 0, text: gainText);
      }
      if (sumText > 0) {
        table.drawRow(canvas, rect, after, scale: scale, fill: 0, text: sumText);
      }
    }
  }

  // ---------------------------------------------------------------- the copy

  /// The row in focus evened out as the block's second LayerNorm does it:
  /// x0 + attention's numbers, and the row the network reads. The run keeps
  /// no scale and shift of this norm, only what it made.
  static Evening evening(LmView view) => view.kit.memo<Evening>(
    ('ff-evening', view.step, view.peptide, view.position),
    () => Evening(
      <double>[
        for (int d = 0; d < view.trace.model.width; d++)
          view.trace.stream(view.checkpoint, _before, view.peptide, view.position, d),
      ],
      <double>[
        for (int d = 0; d < view.trace.model.width; d++)
          view.trace.ffInput(view.checkpoint, block, view.peptide, view.position, d),
      ],
    ),
  );

  /// The row in focus, as the network reads it: a copy lifting off its row,
  /// evened out, and standing up as the inputs; then the outputs, lying down
  /// onto the row.
  void _copy(Canvas canvas, LmView view, FeedForwardLayout layout, double beat) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int focus = view.position;
    final StreamTable table = layout.table;
    final Rect row = table.row(focus);
    // Up and standing.
    final double lift = _span(beat, _lift);
    final double stand = _span(beat, _stand);
    final double nodes = _span(beat, _nodes);
    if (lift > 0 && nodes < 1) {
      final (List<double> now, double scale) = _inputsAt(view, layout, beat);
      final Rect lifted = row.shift(Offset(0, -layout.table.layout.pitch * 0.55 * lift));
      table.strip(
        canvas,
        from: lifted,
        to: layout.inputColumn,
        f: stand,
        colors: <Color>[for (int d = 0; d < width; d++) view.inks.cell(now[d] / scale)],
        numbers: stand > 0 ? null : now,
        alpha: (0.2 + 0.8 * lift) * (1 - nodes),
        outlined: true,
      );
    }
    // Down and added.
    final double down = _span(beat, _layDown);
    if (down > 0 && beat < _alone.$1 + 0.05) {
      final List<double> gain = table.gained(_before, _after, focus);
      final double gainScale = table.gainScale(_before, _after);
      table.strip(
        canvas,
        from: row,
        to: layout.outputColumn,
        f: 1 - down,
        colors: <Color>[for (int d = 0; d < width; d++) view.inks.cell(gain[d] / gainScale)],
        alpha: 1 - through(beat, _alone.$1 - 0.1, _alone.$1 + 0.05),
        outlined: true,
      );
    }
  }

  // ---------------------------------------------------------------- network

  /// The network: the inputs, every weight to every neuron, the neurons lit by
  /// what GELU lets through, their weights to the outputs, and the outputs;
  /// the signal riding the strongest edges.
  void _network(Canvas canvas, Size size, LmView view, FeedForwardLayout layout, double beat) {
    final double gone = 1 - _span(beat, _networkOut);
    final double nodes = _span(beat, _nodes);
    if (nodes <= 0 || gone <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int ff = trace.model.feedForward;
    final int focus = view.position;
    final (List<double> input, double inputScale) = _inputsAt(view, layout, beat);
    final List<double> neurons = <double>[
      for (int u = 0; u < ff; u++) trace.hidden(view.checkpoint, block, view.peptide, focus, u),
    ];
    final List<double> output = layout.table.gained(_before, _after, focus);
    final double hiddenIn = _span(beat, _hiddenIn) * gone;
    final double outIn = _span(beat, _outIn) * gone;
    final double lit = _span(beat, _lit);
    final double outputs = _span(beat, _outputs);
    // The edges: each weight times what it carries, the sign its colour.
    final List<(int, int, double)> inEdges = <(int, int, double)>[
      for (int u = 0; u < ff; u++)
        for (int d = 0; d < width; d++) (d, u, input[d] * trace.ffIn(view.checkpoint, block, u, d)),
    ];
    final List<(int, int, double)> outEdges = <(int, int, double)>[
      for (int d = 0; d < width; d++)
        for (int u = 0; u < ff; u++) (u, d, neurons[u] * trace.ffOut(view.checkpoint, block, d, u)),
    ];
    if (hiddenIn > 0) {
      drawEdges(canvas, view, inEdges, layout.inputAt, layout.hiddenAt, hiddenIn);
    }
    if (outIn > 0) {
      drawEdges(canvas, view, outEdges, layout.hiddenAt, layout.outputAt, outIn);
    }
    _pulses(canvas, view, inEdges, layout.inputAt, layout.hiddenAt, beat, _fireFrom, _outFrom, gone);
    _pulses(canvas, view, outEdges, layout.hiddenAt, layout.outputAt, beat, _outIn.$2, _networkOut.$1, gone);
    // The inputs, numbers to their left.
    final TextStyle face = inked(view.kit.mono, layout.textSize, view.inks.ink);
    final double inputAlpha = nodes * gone;
    for (int d = 0; d < width; d++) {
      final Offset at = layout.inputAt(d);
      _node(canvas, view, at, layout.ioRadius, view.inks.signed(input[d] / inputScale), inputAlpha);
      view.kit.draw(
        canvas,
        fixed(input[d], EmbeddingLayout.digits),
        face.copyWith(color: face.color!.withValues(alpha: (inputAlpha * 8).round() / 8)),
        Offset(at.dx - layout.ioRadius - 4, at.dy),
        anchor: const Offset(1, 0.5),
      );
    }
    // The neurons, lit by what each lets through.
    if (hiddenIn > 0) {
      final double most = neurons.fold<double>(1e-6, math.max);
      for (int u = 0; u < ff; u++) {
        final double on = (neurons[u] / most).clamp(0.0, 1.0) * lit;
        _node(
          canvas,
          view,
          layout.hiddenAt(u),
          layout.hiddenRadius,
          Color.lerp(view.inks.zero, view.inks.signal, on)!,
          hiddenIn,
        );
      }
    }
    // The outputs, numbers to their right.
    if (outIn > 0) {
      final double outScale = layout.table.gainScale(_before, _after);
      final double written = _span(beat, _outputNumbers) * outIn;
      for (int d = 0; d < width; d++) {
        final Offset at = layout.outputAt(d);
        _node(
          canvas,
          view,
          at,
          layout.ioRadius,
          Color.lerp(view.inks.zero, view.inks.signed(output[d] / outScale), outputs)!,
          // The column lying down takes the outputs' place.
          outIn * (1 - _span(beat, (_layDown.$1, _layDown.$1 + 0.05))),
        );
        if (written > 0) {
          view.kit.draw(
            canvas,
            fixed(output[d], EmbeddingLayout.digits),
            face.copyWith(color: face.color!.withValues(alpha: (written * 8).round() / 8)),
            Offset(at.dx + layout.ioRadius + 4, at.dy),
            anchor: const Offset(0, 0.5),
          );
        }
      }
    }
    // The three layers named, over them.
    for (final (String text, double x, double alpha) in <(String, double, double)>[
      ('$width in', layout.inputX, inputAlpha),
      ('$ff neurons', layout.hiddenX, hiddenIn),
      ('$width out', layout.outputX, outIn),
    ]) {
      if (alpha > 0) {
        view.kit.draw(
          canvas,
          text,
          inked(view.kit.sans, 9, view.inks.quiet, alpha: alpha),
          Offset(x, layout.top - 6),
          anchor: const Offset(0.5, 1),
        );
      }
    }
  }

  /// A node: a disc in [color], a ring round it.
  static void _node(Canvas canvas, LmView view, Offset at, double radius, Color color, double alpha) {
    if (alpha <= 0) {
      return;
    }
    canvas.drawCircle(at, radius, Paint()..color = color.withValues(alpha: color.a * alpha));
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
  }

  /// How many edges carry the signal's pulses: the strongest of each layer.
  static const int _riders = 40;

  /// The signal riding the strongest edges from [start] to [end], about once
  /// a beat, each pulse as large as what its edge carries.
  static void _pulses(
    Canvas canvas,
    LmView view,
    List<(int, int, double)> edges,
    Offset Function(int) from,
    Offset Function(int) to,
    double beat,
    double start,
    double end,
    double alpha,
  ) {
    if (beat < start || beat >= end || alpha <= 0) {
      return;
    }
    final List<(int, int, double)> strongest = List<(int, int, double)>.of(edges)
      ..sort(((int, int, double) a, (int, int, double) b) => b.$3.abs().compareTo(a.$3.abs()));
    final double most = math.max(1e-9, strongest.first.$3.abs());
    final double fade = through(beat, start, start + 0.2) * (1 - through(beat, end - 0.2, end)) * alpha;
    final double phase = (beat - start) % 1;
    final Paint paint = Paint();
    for (final (int a, int b, double c) in strongest.take(_riders)) {
      final double w = c.abs() / most;
      final Offset p = Offset.lerp(from(a), to(b), phase)!;
      canvas.drawCircle(p, 0.8 + 1.8 * math.sqrt(w), paint..color = view.inks.signal.withValues(alpha: 0.9 * fade));
    }
  }

  // ------------------------------------------------------------------- taps

  /// While the table shows, a row puts its place in focus.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final double beat = frame.local * _beats;
    if (beat > _tableOut.$1 && beat < _tableIn.$2) {
      return null;
    }
    return hit(size, view, at);
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) => StreamTable(size, view).placeAt(at);

  // ---------------------------------------------------------------- caption

  /// How many of the place in focus's neurons light up: a tenth or more of
  /// the brightest, as drawn.
  static int litNeurons(LmView view) {
    final TrainingTrace trace = view.trace;
    final List<double> neurons = <double>[
      for (int u = 0; u < trace.model.feedForward; u++) trace.hidden(view.checkpoint, block, view.peptide, view.position, u),
    ];
    final double most = neurons.fold<double>(0, math.max);
    return most <= 0 ? 0 : neurons.where((double a) => a >= 0.1 * most).length;
  }

  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int ff = trace.model.feedForward;
    return <(double, double, String)>[
      (
        0.25,
        _chartIn.$1,
        'Attention moved numbers between places. The feed-forward works\n'
            'on each place alone: the same network at all ${grouped(view.focus.inputs)}',
      ),
      (
        _chartIn.$1,
        _hiddenIn.$1,
        "LayerNorm again, the block's second, with its own scale and shift:\n"
            'the row itself keeps its numbers; the network reads an evened\n'
            'copy, as attention did',
      ),
      (
        _hiddenIn.$1,
        _outIn.$1,
        'a neuron: a weighted sum of the $width inputs, plus a bias, then GELU\n'
            'GELU passes what is positive and nearly silences the rest',
      ),
      (
        _outIn.$1,
        _networkOut.$1,
        '$width → $ff → $width: wide in the middle, to hold many patterns,\n'
            'narrow again, to be added to the row',
      ),
      (
        _networkOut.$1,
        double.infinity,
        'nothing is overwritten: the output is added to the row\n'
            'next: block 2 does both again, with its own weights',
      ),
    ];
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * _beats;
    final int width = trace.model.width;
    final int ff = trace.model.feedForward;
    final int n = view.focus.inputs;
    final String focus = StreamTable.placeName(view, view.position);
    final Evening even = evening(view);
    if (beat < _lift.$2) {
      return 'Block 1, feed-forward: one small network, each place on its own';
    }
    if (beat < _centre.$1) {
      return "LayerNorm first evens out $focus's row: mean ${fixed(even.mean, 2)}, "
          'standard deviation ${fixed(even.sd, 2)}';
    }
    if (beat < _spread.$1) {
      return 'Less the mean, ${fixed(even.mean, 2)}: the row centres on zero';
    }
    if (beat < _learned.$1) {
      return 'Over the standard deviation, ${fixed(even.sd, 2)}: each number a z-score';
    }
    if (beat < _chartOut.$1) {
      return even.plain
          ? 'At step ${grouped(view.step)} every scale is 1 and every shift 0: evened = z-score'
          : "Then this norm's own learned scale and shift: the row the network reads";
    }
    if (beat < _hiddenIn.$1) {
      return "$focus's evened row: its $width numbers go in";
    }
    if (beat < _outIn.$1) {
      return '$ff neurons, each a weighted sum of the $width through GELU: '
          '${grouped(litNeurons(view))} light up';
    }
    if (beat < _networkOut.$1) {
      return '$width out, each a weighted sum of the $ff neurons';
    }
    if (beat < _alone.$1) {
      return "Back to $focus's row, to be added";
    }
    if (beat < _gainUnwritten.$1) {
      return 'What the feed-forward adds to each place: ${grouped(n)} rows of $width';
    }
    return "Added: block 1's output, ${grouped(n)} × $width";
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Feed-forward, step ${view.step}. ${caption(view, frame)}.';
}

/// Feed-forward's canvas, on Embedding's: the table where it was, and over
/// it, through the rows' height, the network: the inputs at the left, their
/// numbers left of them; the neurons down the middle; the outputs at the
/// right, their numbers right of them.
final class FeedForwardLayout {
  FeedForwardLayout(Size size, LmView view)
    : table = StreamTable(size, view),
      _view = view {
    final EmbeddingLayout e = table.layout;
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int ff = trace.model.feedForward;
    top = table.row(0).top + 4;
    bottom = table.row(view.focus.inputs - 1).bottom - 4;
    final double height = bottom - top;
    ioRadius = math.min(7.0, height / width * 0.32);
    hiddenRadius = math.max(1.5, math.min(4.0, height / ff * 0.36));
    final double number = view.kit.layout('−8.88', inked(view.kit.mono, textSize, view.inks.ink)).width;
    inputX = e.left + number + 4 + ioRadius + 2;
    outputX = e.right - number - 4 - ioRadius - 2;
    hiddenX = (inputX + outputX) / 2;
    chartLeft = inputX + ioRadius + 12;
    chartRight = e.right - 2;
  }

  final StreamTable table;
  final LmView _view;

  late final double top;
  late final double bottom;
  late final double ioRadius;
  late final double hiddenRadius;
  late final double inputX;
  late final double hiddenX;
  late final double outputX;

  /// Where the chart of the evening out stands, right of the inputs, before
  /// the network takes the room.
  late final double chartLeft;
  late final double chartRight;

  int get _width => _view.trace.model.width;
  int get _ff => _view.trace.model.feedForward;

  /// The size the inputs' and outputs' numbers are written at.
  double get textSize => (table.layout.pitch * 0.62).clamp(6.5, 9.0);

  Offset inputAt(int d) => Offset(inputX, top + (d + 0.5) * (bottom - top) / _width);

  Offset hiddenAt(int u) => Offset(hiddenX, top + (u + 0.5) * (bottom - top) / _ff);

  Offset outputAt(int d) => Offset(outputX, top + (d + 0.5) * (bottom - top) / _width);

  /// Where the inputs stand and the outputs lie down from: a strip of their
  /// nodes' width.
  Rect get inputColumn => Rect.fromLTRB(inputX - ioRadius, top, inputX + ioRadius, bottom);

  Rect get outputColumn => Rect.fromLTRB(outputX - ioRadius, top, outputX + ioRadius, bottom);

  /// The network's inputs at place [i]: its row after the block's second
  /// LayerNorm.
  List<double> inputs(int i) => <double>[
    for (int d = 0; d < _width; d++)
      _view.trace.ffInput(_view.checkpoint, FeedForwardScene.block, _view.peptide, i, d),
  ];

  /// The inputs' colour scale, over the places in focus.
  double get inputScale => _view.kit.memo<double>(
    ('ff-input', _view.step, _view.peptide, FeedForwardScene.block),
    () => percentileScale(<double>[for (int i = 0; i < _view.focus.inputs; i++) ...inputs(i)]),
  );
}
