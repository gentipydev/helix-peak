import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import '../lm_info_sheet.dart';
import 'attention_scene.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';

/// Feed-forward, block 1's second part, as the engine runs it (the block's
/// second LayerNorm, then `linear1`, GELU and `linear2`). It opens on
/// Attention's last frame, x0 + block 1's attention a row a place. A copy of
/// the row in focus stands up off it as the network's inputs, and the
/// LayerNorm evens them out on Scores' chart; their weights reach every one
/// of the neurons.
/// One neuron's sum is worked out and goes through GELU, drawn as its curve
/// beside the neurons; then the neuron GELU silences most; then every neuron
/// at once, each lit by what GELU lets through. Their weights reach the
/// outputs, and the outputs lie down onto the row in focus. Every place goes through the same network, alone: what
/// it adds to each, alone on its own scale, and then added, block 1's output.
///
/// Every number is the run's: the inputs, the neurons, the weights as the
/// step found them, and each point of the stream, whole.
final class FeedForwardScene extends LmScene {
  const FeedForwardScene();

  /// The block this stage shows: the one Attention showed.
  static const int block = AttentionScene.block;

  static double get _beats => LmStage.feedForward.beats.toDouble();

  // A copy of the row in focus, x0 + attention's numbers, stands up off it
  // as the inputs as the other rows go quiet, the table fading under the
  // network.
  static const (double, double) _quiet = (0.0, 0.6);
  static const (double, double) _stand = (0.3, 1.1);
  static const (double, double) _tableOut = (0.3, 0.8);
  static const (double, double) _nodes = (1.0, 1.3);

  // The block's second LayerNorm evens the inputs out on Scores' chart,
  // beside them where the network will be: less their mean, over their
  // standard deviation, then the norm's own scale and shift. The row they
  // came from keeps its numbers.
  static const (double, double) _chartIn = (1.3, 1.6);
  static const (double, double) _centre = (2.2, 2.8);
  static const (double, double) _spread = (3.1, 3.7);
  static const (double, double) _learned = (4.0, 4.3);
  static const (double, double) _chartOut = (4.9, 5.2);

  // The neurons: the edges in. Then the brightest neuron alone, its 16
  // edges standing out and its 16 terms running in once, GELU's curve
  // beside the neurons from then on, and its sum through the curve; then
  // the neuron GELU silences most; then every neuron at once, each lit by
  // what it passes on, the curve alone.
  static const (double, double) _hiddenIn = (5.3, 5.8);
  static const (double, double) _first = (7.0, 7.4);
  static const (double, double) _geluIn = (7.0, 7.4);
  static const double _firstRuns = 7.2;
  static const double _geluSaid = 8.4;
  static const (double, double) _firstThrough = (8.6, 9.2);
  static const (double, double) _second = (10.0, 10.4);
  static const double _secondRuns = 10.2;
  static const (double, double) _secondThrough = (11.0, 11.6);
  static const (double, double) _all = (12.2, 12.6);
  static const (double, double) _lit = (12.4, 13.4);
  static const (double, double) _geluOut = (14.2, 14.5);
  static const double _outFrom = 14.6;

  // The outputs: the edges out, the signal along them, and each output.
  static const (double, double) _outIn = (14.6, 15.0);
  static const (double, double) _outputs = (15.4, 16.2);
  static const (double, double) _outputNumbers = (16.0, 16.5);

  // The outputs lie down on the row in focus; the network goes and the table
  // comes back.
  static const (double, double) _networkOut = (16.6, 17.0);
  static const (double, double) _layDown = (16.7, 17.5);
  static const (double, double) _tableIn = (17.0, 17.6);

  // What the feed-forward added, alone on its own scale, then the sums.
  static const (double, double) _alone = (17.6, 18.0);
  static const (double, double) _numbersOut = (17.6, 17.8);
  static const (double, double) _gainWritten = (17.8, 18.0);
  static const (double, double) _gainUnwritten = (18.4, 18.6);
  static const (double, double) _add = (18.5, 18.9);
  static const (double, double) _sumsWritten = (18.7, 18.9);

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
    table.tag(canvas, AttentionScene.sumTag(view), (1 - _span(beat, _numbersOut)) * shown);
    table.tag(
      canvas,
      "what block 1's feed-forward adds · $n × $width",
      through(beat, _numbersOut.$2, _numbersOut.$2 + 0.2) * (1 - _span(beat, _gainUnwritten)),
    );
    table.tag(canvas, "block 1's output · $n × $width", through(beat, _gainUnwritten.$2, _gainUnwritten.$2 + 0.2));
    drawFaded(canvas, size, view, shown, () {
      _stream(canvas, view, layout, beat);
      table.drawTiles(canvas);
      table.outline(canvas, view.position, table.row(view.position).right, 1);
    });
    _network(canvas, size, view, layout, beat);
    _geluChart(canvas, view, layout, beat);
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

  /// The row in focus, as the network reads it: a copy standing up off its
  /// row as the inputs; then the outputs, lying down onto the row.
  void _copy(Canvas canvas, LmView view, FeedForwardLayout layout, double beat) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int focus = view.position;
    final StreamTable table = layout.table;
    final Rect row = table.row(focus);
    // Standing: the copy comes in as it turns, over the row's own numbers.
    final double stand = _span(beat, _stand);
    final double nodes = _span(beat, _nodes);
    if (stand > 0 && nodes < 1) {
      final (List<double> now, double scale) = _inputsAt(view, layout, beat);
      table.strip(
        canvas,
        from: row,
        to: layout.inputColumn,
        f: stand,
        colors: <Color>[for (int d = 0; d < width; d++) view.inks.cell(now[d] / scale)],
        alpha: through(beat, _stand.$1, _stand.$1 + 0.15) * (1 - nodes),
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
    // While one neuron is worked out, its 16 edges stand out of the rest.
    final (int first, int second) = worked(view);
    final double one = _span(beat, _first) * (1 - _span(beat, _second));
    final double two = _span(beat, _second) * (1 - _span(beat, _all));
    double picked(int u) => u == first ? one : (u == second ? two : 0);
    if (hiddenIn > 0) {
      drawEdges(
        canvas,
        view,
        inEdges,
        layout.inputAt,
        layout.hiddenAt,
        hiddenIn,
        alphaOf: (int u) => 1 - 0.85 * (one + two) + 0.85 * picked(u),
      );
    }
    if (outIn > 0) {
      drawEdges(canvas, view, outEdges, layout.hiddenAt, layout.outputAt, outIn);
    }
    // Into a neuron worked out, a dot along each of its 16 edges. Then into
    // every neuron, a dot for each that lights up, along the input that
    // pushes it hardest: the largest input × weight it receives. Into the
    // outputs, a dot for each output, along the neuron that pushes it
    // hardest.
    final double brightest = neurons.fold<double>(0, math.max);
    for (final (int u, double start, double end) in <(int, double, double)>[
      (first, _firstRuns, _firstRuns + 1),
      (second, _secondRuns, _secondRuns + 1),
    ]) {
      _pulses(
        canvas,
        view,
        <(int, int, double)>[...inEdges.where(((int, int, double) e) => e.$2 == u)],
        layout.inputAt,
        layout.hiddenAt,
        beat,
        start,
        end,
        gone,
      );
    }
    _pulses(
      canvas,
      view,
      <(int, int, double)>[
        for (int u = 0; u < ff; u++)
          if (brightest > 0 && neurons[u] >= 0.1 * brightest) _hardest(inEdges, u),
      ],
      layout.inputAt,
      layout.hiddenAt,
      beat,
      _all.$2,
      _outFrom,
      gone,
    );
    _pulses(
      canvas,
      view,
      <(int, int, double)>[for (int d = 0; d < width; d++) _hardest(outEdges, d)],
      layout.hiddenAt,
      layout.outputAt,
      beat,
      _outIn.$2,
      _networkOut.$1,
      gone,
    );
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
    // The neurons, lit by what each lets through: a neuron worked out as it
    // goes through GELU, the rest all at once. A neuron worked out is ringed
    // and numbered while it is.
    if (hiddenIn > 0) {
      for (int u = 0; u < ff; u++) {
        final double through = u == first
            ? _span(beat, _firstThrough)
            : (u == second ? _span(beat, _secondThrough) : lit);
        _node(canvas, view, layout.hiddenAt(u), layout.hiddenRadius, _lightOf(view, neurons, u, through), hiddenIn);
      }
      for (final (int u, double ring) in <(int, double)>[(first, one), (second, two)]) {
        if (ring <= 0) {
          continue;
        }
        final Offset at = layout.hiddenAt(u);
        canvas.drawCircle(
          at,
          layout.hiddenRadius + 2.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = view.inks.signal.withValues(alpha: ring * hiddenIn),
        );
        view.kit.draw(
          canvas,
          '${u + 1}',
          inked(view.kit.mono, 8.5, view.inks.signal, alpha: ring * hiddenIn),
          Offset(at.dx + layout.hiddenRadius + 5, at.dy),
          anchor: const Offset(0, 0.5),
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

  /// Neuron [u]'s colour, [through] of the way lit: the accent as strong as
  /// what it passes on against the brightest, dark for what GELU silences.
  static Color _lightOf(LmView view, List<double> neurons, int u, double through) {
    final double most = neurons.fold<double>(1e-6, math.max);
    return Color.lerp(view.inks.zero, view.inks.signal, (neurons[u] / most).clamp(0.0, 1.0) * through)!;
  }

  // ------------------------------------------------------------------- GELU

  /// GELU, as the engine's `nn.GELU` has it: [x] times the chance that a
  /// standard normal number falls below [x], x · Φ(x).
  static double gelu(double x) => 0.5 * x * (1 + _erf(x / math.sqrt2));

  /// The error function, to 1.5 × 10⁻⁷ (Abramowitz and Stegun, 7.1.26).
  static double _erf(double x) {
    final double t = 1 / (1 + 0.3275911 * x.abs());
    final double y = 1 -
        t *
            (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429)))) *
            math.exp(-x * x);
    return x < 0 ? -y : y;
  }

  /// What each neuron of the place in focus adds up to before GELU: its 16
  /// inputs, the evened row, times its weights, plus its bias. GELU of each
  /// is the neuron the run kept.
  static List<double> sums(LmView view) => view.kit.memo<List<double>>(
    ('ff-sums', view.step, view.peptide, view.position),
    () {
      final TrainingTrace trace = view.trace;
      final int width = trace.model.width;
      return <double>[
        for (int u = 0; u < trace.model.feedForward; u++)
          List<double>.generate(
                width,
                (int d) =>
                    trace.ffInput(view.checkpoint, block, view.peptide, view.position, d) *
                    trace.ffIn(view.checkpoint, block, u, d),
              ).fold<double>(0, (double a, double b) => a + b) +
              trace.ffInBias(view.checkpoint, block, u),
      ];
    },
  );

  /// The two neurons worked out: the brightest, and the one whose sum is
  /// the most negative, the one GELU silences most.
  static (int, int) worked(LmView view) {
    final List<double> z = sums(view);
    int top = 0;
    int low = 0;
    for (int u = 1; u < z.length; u++) {
      if (z[u] > z[top]) {
        top = u;
      }
      if (z[u] < z[low]) {
        low = u;
      }
    }
    return (top, low);
  }

  /// A sum as the captions write it, and GELU of it as written, so the
  /// caption's sum reads right.
  static (String, String) _through(double z) {
    final String sum = fixed(z, 2);
    return (sum, fixed(gelu(double.parse(sum.replaceAll('−', '-'))), 2));
  }

  /// GELU's curve beside the neurons, where the outputs will be: the sum
  /// along, what is passed on up. The neurons worked out go through it, a
  /// guide from the sum up to the curve and across to what it passes on;
  /// while every neuron lights at once, the curve alone.
  void _geluChart(Canvas canvas, LmView view, FeedForwardLayout layout, double beat) {
    final double alpha = _span(beat, _geluIn) * (1 - _span(beat, _geluOut));
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final List<double> z = sums(view);
    final List<double> neurons = <double>[
      for (int u = 0; u < trace.model.feedForward; u++) trace.hidden(view.checkpoint, block, view.peptide, view.position, u),
    ];
    final GeluChart chart = layout.gelu(z.fold<double>(0, (double m, double v) => math.max(m, v.abs())));
    final Paint axis = Paint()
      ..strokeWidth = 1
      ..color = view.inks.quiet.withValues(alpha: alpha);
    canvas.drawLine(chart.at(-chart.reach, 0), chart.at(chart.reach, 0), axis);
    canvas.drawLine(chart.at(0, chart.low), chart.at(0, chart.reach), axis);
    for (int k = -chart.reach.floor(); k <= chart.reach.floor(); k++) {
      if (k != 0) {
        canvas.drawLine(chart.at(k.toDouble(), 0), chart.at(k.toDouble(), 0) + const Offset(0, 3), axis);
      }
    }
    final TextStyle words = inked(view.kit.sans, 8.5, view.inks.quiet, alpha: alpha);
    view.kit.draw(canvas, 'sum', words, chart.at(chart.reach, 0) + const Offset(0, -4), anchor: const Offset(1, 1));
    view.kit.draw(canvas, 'GELU(sum)', words, chart.at(0, chart.reach) + const Offset(0, -3), anchor: const Offset(0.5, 1));
    final Path curve = Path();
    for (int i = 0; i <= 96; i++) {
      final double x = -chart.reach + 2 * chart.reach * i / 96;
      final Offset p = chart.at(x, gelu(x));
      i == 0 ? curve.moveTo(p.dx, p.dy) : curve.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      curve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = view.inks.signal.withValues(alpha: 0.9 * alpha),
    );
    // The neurons worked out, each through the curve, its numbers and
    // guides until the next is.
    final (int first, int second) = worked(view);
    for (final (int u, (double, double) span, double named) in <(int, (double, double), double)>[
      (first, _firstThrough, 1 - _span(beat, _second)),
      (second, _secondThrough, 1 - _span(beat, _all)),
    ]) {
      final double f = _span(beat, span);
      // Every neuron at once: the curve alone.
      final double kept = alpha * (1 - _span(beat, _all));
      if (f <= 0 || kept <= 0) {
        continue;
      }
      final TextStyle numbers = inked(view.kit.mono, 8.5, view.inks.ink, alpha: alpha * named);
      final double g = gelu(z[u]);
      final Offset foot = chart.at(z[u], 0);
      final Offset onCurve = chart.at(z[u], g);
      final Offset across = chart.at(0, g);
      final Paint guide = Paint()
        ..strokeWidth = 1
        ..color = view.inks.ink.withValues(alpha: 0.7 * alpha * named);
      final double up = (f * 2).clamp(0.0, 1.0);
      final double over = (f * 2 - 1).clamp(0.0, 1.0);
      dashedLine(canvas, foot, Offset.lerp(foot, onCurve, up)!, guide);
      if (over > 0) {
        dashedLine(canvas, onCurve, Offset.lerp(onCurve, across, over)!, guide);
      }
      final (String sum, String passed) = _through(z[u]);
      view.kit.draw(canvas, sum, numbers, foot + Offset(0, g >= 0 ? 5 : -5), anchor: Offset(0.5, g >= 0 ? 0 : 1));
      if (over >= 1) {
        view.kit.draw(
          canvas,
          passed,
          numbers,
          across + Offset(z[u] >= 0 ? -5 : 5, 0),
          anchor: Offset(z[u] >= 0 ? 1 : 0, g >= 0 ? 0.5 : 0),
        );
      }
      canvas.drawCircle(
        onCurve,
        3,
        Paint()..color = _lightOf(view, neurons, u, 1).withValues(alpha: kept * up),
      );
      canvas.drawCircle(
        onCurve,
        3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = view.inks.signal.withValues(alpha: kept * up),
      );
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

  /// Of [edges] into node [to], the one that carries most, either way.
  static (int, int, double) _hardest(List<(int, int, double)> edges, int to) => edges
      .where(((int, int, double) e) => e.$2 == to)
      .reduce(((int, int, double) a, (int, int, double) b) => b.$3.abs() > a.$3.abs() ? b : a);

  /// The signal riding [riders] from [start] to [end], about once a beat,
  /// each pulse as large as what its edge carries.
  static void _pulses(
    Canvas canvas,
    LmView view,
    List<(int, int, double)> riders,
    Offset Function(int) from,
    Offset Function(int) to,
    double beat,
    double start,
    double end,
    double alpha,
  ) {
    if (beat < start || beat >= end || alpha <= 0 || riders.isEmpty) {
      return;
    }
    final double most = riders.fold<double>(1e-9, (double m, (int, int, double) e) => math.max(m, e.$3.abs()));
    final double fade = through(beat, start, start + 0.2) * (1 - through(beat, end - 0.2, end)) * alpha;
    final double phase = (beat - start) % 1;
    final Paint paint = Paint();
    for (final (int a, int b, double c) in riders) {
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
        _first.$1,
        'every line is one weight: $width × $ff = ${grouped(width * ff)} of them,\n'
            '${ScoresScene.weightsStatus(view)}\n'
            'a line shows input × weight: red pushes its neuron up,\n'
            'blue pushes it down, and the brighter, the harder',
      ),
      (
        _first.$1,
        _geluSaid,
        'a weighted sum: each input times its weight, the $width added up,\n'
            "plus the neuron's own bias, a number trained like the weights",
      ),
      (
        _geluSaid,
        _all.$1,
        'GELU, the Gaussian error linear unit: GELU(x) = x × the chance\n'
            'that a standard normal number falls below x. A large positive\n'
            'sum passes almost whole; a large negative one, nearly 0',
      ),
      (
        _all.$1,
        _outIn.$1,
        'why the bend: without it, both layers would add up to a single\n'
            'weighted sum; with it, a neuron fires only for its own pattern\n'
            "lit: a tenth of the brightest or more; each lit one's dot comes\n"
            'from the input that pushes it hardest',
      ),
      (
        _outIn.$1,
        _networkOut.$1,
        '$width → $ff → $width: wide in the middle, to hold many patterns,\n'
            'then back to $width, with no GELU, so each output can be up or\n'
            'down, to be added to the row',
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
    if (beat < _nodes.$1) {
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
    if (beat < _first.$1) {
      return 'Each of the $ff neurons gets all $width inputs, each × its own weight';
    }
    final (int first, int second) = worked(view);
    final List<double> z = sums(view);
    if (beat < _geluSaid) {
      return 'Neuron ${first + 1} adds up its $width inputs × weights, plus its bias: ${_through(z[first]).$1}';
    }
    if (beat < _second.$1) {
      final (String sum, String passed) = _through(z[first]);
      return 'GELU decides what it passes on: GELU($sum) = $passed';
    }
    if (beat < _all.$1) {
      final (String sum, String passed) = _through(z[second]);
      return 'Neuron ${second + 1} adds up to $sum: GELU($sum) = $passed, nearly nothing';
    }
    if (beat < _outIn.$1) {
      return 'All $ff the same way: ${grouped(litNeurons(view))} light up';
    }
    if (beat < _networkOut.$1) {
      return '$width out, each a weighted sum of the $ff neurons, plus a bias';
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

  /// Feed-forward's own page: what it takes and gives, how much of the model
  /// it is, and how its neurons make its outputs, in the run's numbers.
  @override
  LmInfo info(LmView view) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int neurons = trace.model.feedForward;
    final int layers = trace.model.layers;
    final int parameters = trace.model.parameters;
    // A block's network: its weights in and out, and a bias a neuron and an
    // output.
    final int each = 2 * neurons * width + neurons + width;
    final String share = percent(layers * each / parameters);
    final String weights = switch (layers) {
      1 => "Its weights, ${grouped(each)}, are $share of the model's ${grouped(parameters)} numbers.",
      2 => "Its weights, ${grouped(each)} a block, with block 2's make $share of the model's "
          '${grouped(parameters)} numbers.',
      _ => "Its weights, ${grouped(each)} a block, with the other blocks' make $share of the model's "
          '${grouped(parameters)} numbers.',
    };
    return LmInfo(
      title: LmStage.feedForward.label,
      lead: "Each place's row, x0 + block 1's attention, goes alone through one small network, and what it "
          "makes is added: block 1's output. $weights",
      sections: <LmInfoSection>[
        LmInfoSection("What block 1's feed-forward adds", <String>[
          'Each neuron adds its own $width output weights to the row, times what GELU let it pass on, so a '
              'dark neuron adds next to nothing; the $width outputs are those additions, summed, plus a bias. '
              'Which pattern a neuron answers to is whatever training made useful: none is set to a residue or '
              'a property.',
        ]),
      ],
    );
  }
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

  /// GELU's chart for sums as far as [most] either way, right of the
  /// neurons where the outputs will be, its axes through 0, centred on the
  /// network's height.
  GeluChart gelu(double most) {
    final double reach = math.max(1.5, most * 1.1);
    final double left = hiddenX + hiddenRadius + 30;
    final double right = table.layout.right - 8;
    final double height = math.min((right - left) * 0.9, bottom - top);
    const double low = -0.4;
    final double centre = (top + bottom) / 2;
    return GeluChart(
      reach: reach,
      low: low,
      area: Rect.fromLTRB(left, centre - height / 2, right, centre + height / 2),
    );
  }

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

/// GELU's chart: sums from −[reach] to [reach] across [area], what is
/// passed on from [low] to [reach] up it.
@immutable
final class GeluChart {
  const GeluChart({required this.reach, required this.low, required this.area});

  final double reach;
  final double low;
  final Rect area;

  /// Where (sum [x], passed on [y]) is drawn.
  Offset at(double x, double y) => Offset(
    area.left + (x + reach) / (2 * reach) * area.width,
    area.bottom - (y - low) / (reach - low) * area.height,
  );
}
