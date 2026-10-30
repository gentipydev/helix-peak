import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'embedding_scene.dart';
import 'feed_forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'stream_table.dart';

/// Forward: the whole pass, layer to layer. It opens on Feed-forward's last
/// frame, block 1's output a row a place, whose rows condense into a column
/// of a network: a row a place, a column a point of the stream (x0, and the
/// stream after each block's attention and feed-forward), flowing left to
/// right. Between the columns: in an attention, a line from every place to
/// each place after it, as strong as its share; in a feed-forward, each
/// place's own line. Each node is the place read out early: the token the
/// output layer would give it if the model stopped there, faded by how sure
/// it is, outlined when it is the token that comes next.
///
/// The signal runs through block 1 again, then through block 2 and the
/// final LayerNorm; last, each column counts the places it gets right.
final class ForwardScene extends LmScene {
  const ForwardScene();

  static double get _beats => LmStage.forward.beats.toDouble();

  // The open: block 1's output condenses into its column; the columns before
  // it come in, with their lines.
  static const (double, double) _numbersOut = (0.0, 0.25);
  static const (double, double) _condense = (0.2, 1.0);
  static const (double, double) _becomeNodes = (0.7, 1.0);
  static const (double, double) _restIn = (0.6, 1.2);

  // Block 1 run again, quickly; the blocks after it each in their turn; the
  // final norm; the counts.
  static const double _replayFrom = 1.2;
  static const double _replayTo = 2.6;
  static const double _blocksFrom = 2.8;
  static const double _blocksTo = 7.0;
  static const (double, double) _norm = (7.0, 8.0);
  static const (double, double) _counted = (8.0, 9.0);

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// When the signal crosses each gap between columns: from, to.
  static (double, double) crossing(int gap, int layers) {
    final int block = gap ~/ 2;
    final bool attention = gap.isEven;
    if (block == 0) {
      const double half = (_replayTo - _replayFrom) * 0.55;
      return attention ? (_replayFrom, _replayFrom + half) : (_replayFrom + half, _replayTo);
    }
    final double span = (_blocksTo - _blocksFrom) / math.max(1, layers - 1);
    final double start = _blocksFrom + (block - 1) * span;
    return attention ? (start, start + span * 0.58) : (start + span * 0.62, start + span);
  }

  /// When column [c]'s nodes come: the first three with the open, the rest
  /// as the signal reaches them.
  static double _column(int c, double beat, int layers) {
    if (c <= 2) {
      return c == 2 ? 1 : _span(beat, _restIn);
    }
    final (double from, double to) = crossing(c - 1, layers);
    return through(beat, from + (to - from) * 0.6, to);
  }

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats);

  void _paint(Canvas canvas, Size size, LmView view, double beat) {
    if (beat <= 0) {
      const FeedForwardScene().paintEnd(canvas, size, view);
      return;
    }
    final NetworkLayout layout = NetworkLayout(size, view);
    final StreamTable table = layout.table;
    final TrainingTrace trace = view.trace;
    final int n = view.focus.inputs;
    final int width = trace.model.width;
    table.note(canvas, _feedForwardNote(view), beat);
    table.note(canvas, notes(view), beat);
    table.tag(canvas, "block 1's output · $n × $width", 1 - through(beat, 0.2, 0.5));
    _header(canvas, view, layout, beat);
    _edges(canvas, view, layout, beat);
    _condensing(canvas, view, layout, beat);
    _nodes(canvas, view, layout, beat);
    table.drawTiles(canvas);
    table.outline(canvas, view.position, layout.columnX(layout.columns - 1) + layout.node / 2 + 3, 1);
    _counts(canvas, view, layout, beat);
  }

  /// Feed-forward's last note, going as this stage's come.
  static List<(double, double, String)> _feedForwardNote(LmView view) => <(double, double, String)>[
    (
      double.negativeInfinity,
      0.25,
      'nothing is overwritten: the output is added to the row\n'
          'next: block 2 does both again, with its own weights',
    ),
  ];

  // ---------------------------------------------------------------- reading

  /// What place [i] reads out at column [c]: the token the output layer
  /// would give it, and how sure.
  static (int, double) readout(LmView view, int c, int i) {
    final TrainingTrace trace = view.trace;
    int best = 0;
    double most = -1;
    for (int k = 0; k < trace.allowed.length; k++) {
      final double p = trace.readout(view.checkpoint, c, view.peptide, i, k);
      if (p > most) {
        most = p;
        best = k;
      }
    }
    return (trace.allowed[best], most);
  }

  /// How many places column [c] reads out right.
  static int right(LmView view, int c) {
    int count = 0;
    for (int i = 0; i < view.focus.inputs; i++) {
      if (readout(view, c, i).$1 == view.trace.targetAt(view.peptide, i)) {
        count++;
      }
    }
    return count;
  }

  /// Place [key]'s share of what place [query] reads in [block]: the heads'
  /// mean, or the head in focus.
  static double share(LmView view, int block, int query, int key) => view.head == null
      ? view.trace.meanAttention(view.checkpoint, block, view.peptide, query, key)
      : view.trace.attention(view.checkpoint, block, view.head!, view.peptide, query, key);

  // ------------------------------------------------------------------ paint

  /// The columns named: x0, and each block over its two columns; the final
  /// norm at the right.
  void _header(Canvas canvas, LmView view, NetworkLayout layout, double beat) {
    final double shown = _span(beat, _restIn);
    if (shown <= 0) {
      return;
    }
    final double y = layout.headerY;
    final TextStyle face = inked(view.kit.sans, 9, view.inks.quiet, alpha: shown);
    view.kit.draw(canvas, 'x0', face, Offset(layout.columnX(0), y), anchor: const Offset(0.5, 1));
    for (int b = 0; b < layout.layers; b++) {
      final double left = layout.columnX(2 * b + 1) - layout.node / 2;
      final double right = layout.columnX(2 * b + 2) + layout.node / 2;
      final Paint line = Paint()
        ..strokeWidth = 0.8
        ..color = view.inks.rule.withValues(alpha: shown);
      canvas.drawLine(Offset(left, y + 2), Offset(right, y + 2), line);
      view.kit.draw(canvas, 'block ${b + 1}', face, Offset((left + right) / 2, y), anchor: const Offset(0.5, 1));
    }
    final double norm = _span(beat, _norm);
    final double x = layout.normX;
    canvas.drawLine(
      Offset(x, layout.table.row(0).top),
      Offset(x, layout.table.row(view.focus.inputs - 1).bottom),
      Paint()
        ..strokeWidth = norm > 0 ? 1.4 : 0.8
        ..color = Color.lerp(view.inks.rule, view.inks.signal, math.sin(math.pi * norm))!.withValues(alpha: shown),
    );
    view.kit.draw(canvas, 'norm', face, Offset(layout.table.layout.right, y), anchor: const Offset(1, 1));
  }

  /// Every line: each place's own, straight through; and in each attention,
  /// one from every place to each place after it, as strong as its share,
  /// the place in focus's in the accent. The signal rides them as it crosses.
  void _edges(Canvas canvas, LmView view, NetworkLayout layout, double beat) {
    final int n = view.focus.inputs;
    final int focus = view.position;
    final double rest = _span(beat, _restIn);
    final LineBatch batch = LineBatch();
    final List<(Offset, Offset, double, bool)> riders = <(Offset, Offset, double, bool)>[];
    for (int gap = 0; gap < layout.columns - 1; gap++) {
      final (double from, double to) = crossing(gap, layout.layers);
      // Block 1's lines come with the open; the rest as the signal reaches
      // them.
      final double shown = gap < 2 ? rest : through(beat, from, from + 0.4);
      if (shown <= 0) {
        continue;
      }
      final double left = layout.columnX(gap) + layout.node / 2 + 1;
      final double right = layout.columnX(gap + 1) - layout.node / 2 - 1;
      final double riding = beat >= from && beat < to ? (beat - from) / (to - from) : -1;
      for (int i = 0; i < n; i++) {
        final double y = layout.table.row(i).center.dy;
        batch.line(Offset(left, y), Offset(right, y), view.inks.quiet, 0.8, 0.45 * shown);
      }
      if (gap.isEven) {
        final int block = gap ~/ 2;
        for (int i = 0; i < n; i++) {
          double most = 1e-9;
          for (int j = 0; j <= i; j++) {
            most = math.max(most, share(view, block, i, j));
          }
          for (int j = 0; j < i; j++) {
            final double w = share(view, block, i, j);
            final Offset a = Offset(left, layout.table.row(j).center.dy);
            final Offset b = Offset(right, layout.table.row(i).center.dy);
            if (i == focus) {
              final double r = w / most;
              batch.line(a, b, view.inks.signal, 0.6 + 2.4 * r, (0.15 + 0.85 * r) * shown);
              if (riding >= 0 && r >= 0.05) {
                riders.add((a, b, r, true));
              }
            } else {
              batch.line(a, b, view.inks.signal, 0.6, (0.03 + 0.35 * w) * shown);
              if (riding >= 0 && w >= 0.25) {
                riders.add((a, b, w, false));
              }
            }
          }
        }
      }
      if (riding >= 0) {
        for (int i = 0; i < n; i++) {
          final double y = layout.table.row(i).center.dy;
          riders.add((Offset(left, y), Offset(right, y), i == focus ? 1 : 0.5, i == focus));
        }
      }
    }
    batch.draw(canvas);
    // The signal: a pulse a line, crossing as the gap is crossed.
    for (int gap = 0; gap < layout.columns - 1; gap++) {
      final (double from, double to) = crossing(gap, layout.layers);
      if (beat < from || beat >= to) {
        continue;
      }
      final double s = ((beat - from) / (to - from)).clamp(0.0, 1.0);
      final double fade = through(beat, from, from + 0.15) * (1 - through(beat, to - 0.15, to));
      final double left = layout.columnX(gap) + layout.node / 2 + 1;
      final double right = layout.columnX(gap + 1) - layout.node / 2 - 1;
      for (final (Offset a, Offset b, double w, bool bright) in riders) {
        if (a.dx < left - 0.5 || b.dx > right + 0.5) {
          continue;
        }
        canvas.drawCircle(
          Offset.lerp(a, b, s)!,
          bright ? 1 + 2.2 * math.sqrt(w) : 1.1,
          Paint()..color = view.inks.signal.withValues(alpha: (bright ? 0.95 : 0.45) * fade),
        );
      }
    }
  }

  /// Block 1's output condensing from its rows into its column.
  void _condensing(Canvas canvas, LmView view, NetworkLayout layout, double beat) {
    final double condense = _span(beat, _condense);
    final double gone = _span(beat, _becomeNodes);
    if (gone >= 1) {
      return;
    }
    final StreamTable table = layout.table;
    const int after = 2 * FeedForwardScene.block + 2;
    final double text = 1 - _span(beat, _numbersOut);
    for (int i = 0; i < view.focus.inputs; i++) {
      final Rect full = table.row(i);
      final Rect node = layout.nodeRect(2, i);
      final Rect rect = Rect.lerp(full, Rect.fromLTRB(node.left - 4, full.top, node.right + 4, full.bottom), condense)!;
      final List<double> values = table.values(after, i);
      table.drawRow(
        canvas,
        rect,
        values,
        scale: table.scale,
        fill: 1 - gone,
        text: condense > 0.02 ? 0 : text,
      );
    }
  }

  /// Each node: the place read out early, faded by how sure, outlined in the
  /// tracer once the counts come where it is right.
  void _nodes(Canvas canvas, LmView view, NetworkLayout layout, double beat) {
    final TrainingTrace trace = view.trace;
    final double counted = _span(beat, _counted);
    for (int c = 0; c < layout.columns; c++) {
      final double shown = c == 2 ? _span(beat, _becomeNodes) : _column(c, beat, layout.layers);
      if (shown <= 0) {
        continue;
      }
      for (int i = 0; i < view.focus.inputs; i++) {
        final (int id, double p) = readout(view, c, i);
        final Rect rect = layout.nodeRect(c, i);
        drawToken(canvas, view, rect, id, alpha: shown * (0.25 + 0.75 * p));
        if (counted > 0 && id == trace.targetAt(view.peptide, i)) {
          // As drawToken shapes its tile, outlined in the tracer.
          final Rect tile = rect.deflate(math.min(1.0, rect.width * 0.08));
          canvas.drawRRect(
            RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.18)).inflate(0.8),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = view.inks.truth.withValues(alpha: counted * shown),
          );
        }
      }
    }
  }

  /// Under each column, how many places it reads out right.
  void _counts(Canvas canvas, LmView view, NetworkLayout layout, double beat) {
    final double shown = _span(beat, _counted);
    if (shown <= 0) {
      return;
    }
    final double y = layout.table.row(view.focus.inputs - 1).bottom + 4;
    for (int c = 0; c < layout.columns; c++) {
      view.kit.draw(
        canvas,
        grouped(right(view, c)),
        inked(view.kit.mono, 10, view.inks.truth, alpha: shown),
        Offset(layout.columnX(c), y),
        anchor: const Offset(0.5, 0),
      );
    }
    view.kit.draw(
      canvas,
      'places read out right, of ${grouped(view.focus.inputs)}',
      inked(view.kit.sans, 9, view.inks.quiet, alpha: shown),
      Offset(layout.table.layout.label(0).left, y + 15),
    );
  }

  // ------------------------------------------------------------------- taps

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) => StreamTable(size, view).placeAt(at);

  // ---------------------------------------------------------------- caption

  static List<(double, double, String)> notes(LmView view) => <(double, double, String)>[
    (
      0.25,
      _replayFrom,
      'each node: what the output layer would say if the model stopped there,\n'
          'read out early; faded by how sure, outlined where it is right',
    ),
    (
      _replayFrom,
      _blocksFrom,
'slanting lines: attention, a place reading those before it\n'
          'straight lines: each place going on, its stream added to',
    ),
    (
      _blocksFrom,
      _norm.$1,
      'block 2 does the same two things with its own weights,\n'
          'reading what block 1 added',
    ),
    (
      _norm.$1,
      double.infinity,
      // Only where the run bears it out: untrained, nothing sharpens.
      '${right(view, view.trace.readouts - 1) > right(view, 0) ? 'layer by layer the guesses sharpen: that is the forward pass' : 'at step ${view.step} no layer gets more places right than x0 does yet'}\n'
          'next: Predict reads the last column whole',
    ),
  ];

  /// Place [i]'s readout at column [c] as the caption says it: `T 64%`.
  static String said(LmView view, int c, int i) {
    final (int id, double p) = readout(view, c, i);
    return '${view.trace.token(id)} ${percent(p)}';
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * _beats;
    final int layers = trace.model.layers;
    final int last = 2 * layers;
    final String focus = StreamTable.placeName(view, view.position);
    if (beat < _replayFrom) {
      return 'The whole pass, layer to layer: a row a place, a column a layer';
    }
    if (beat < _blocksFrom) {
      return 'Block 1, as seen: $focus reads out ${said(view, 0, view.position)} at x0, '
          '${said(view, 2, view.position)} after it';
    }
    if (beat < _norm.$1) {
      final double span = (_blocksTo - _blocksFrom) / math.max(1, layers - 1);
      final int block = math.min(layers - 1, 1 + ((beat - _blocksFrom) / span).floor());
      if (beat < _blocksFrom + (block - 1 + 0.6) * span) {
        final List<String> reads = <String>[
          for (int h = 0; h < trace.model.heads; h++)
            '${_strongest(view, block, h)} (head ${h + 1})',
        ];
        return "Block ${block + 1}'s heads: $focus reads ${reads.join(', ')}";
      }
      return "Block ${block + 1}'s feed-forward: $focus now reads out ${said(view, 2 * block + 2, view.position)}"
          '${block == layers - 1 ? '; next is ${trace.token(view.target)}' : ''}';
    }
    if (beat < _counted.$1) {
      return 'The final LayerNorm: each row as the output layer reads it, in Predict';
    }
    final List<String> counts = <String>[for (int c = 0; c <= last; c++) grouped(right(view, c))];
    return 'Right after x0 and each part: ${counts.join(', ')} of ${grouped(view.focus.inputs)} places';
  }

  /// The place head [h] of [block] reads most at the place in focus, and its
  /// share.
  static String _strongest(LmView view, int block, int h) {
    int best = 0;
    double most = -1;
    for (int key = 0; key <= view.position; key++) {
      final double w = view.trace.attention(view.checkpoint, block, h, view.peptide, view.position, key);
      if (w > most) {
        most = w;
        best = key;
      }
    }
    return '${StreamTable.placeName(view, best)} ${percent(most)}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Forward pass, step ${view.step}. ${caption(view, frame)}.';
}

/// Forward's canvas, on Embedding's: the rows where they were, the tiles
/// naming them at the left as the network's inputs; a column a point of the
/// stream, attentions wider than feed-forwards; the final norm at the right;
/// the blocks named over the columns, the counts under them.
final class NetworkLayout {
  NetworkLayout(Size size, LmView view)
    : table = StreamTable(size, view),
      layers = view.trace.model.layers {
    final EmbeddingLayout e = table.layout;
    columns = 2 * layers + 1;
    node = math.min(18.0, math.max(5.0, e.pitch - 3));
    const double normRoom = 16;
    final double first = e.cellsLeft + 4 + node / 2;
    final double last = e.right - normRoom - node / 2;
    // An attention takes twice a feed-forward's room.
    final List<double> weights = <double>[for (int gap = 0; gap < columns - 1; gap++) gap.isEven ? 2 : 1];
    final double total = weights.fold<double>(0, (double a, double b) => a + b);
    _x = <double>[first];
    for (final double w in weights) {
      _x.add(_x.last + (last - first) * w / total);
    }
    normX = last + node / 2 + normRoom / 2;
    headerY = table.row(0).top - 4;
  }

  final StreamTable table;
  final int layers;
  late final int columns;
  late final double node;
  late final List<double> _x;
  late final double normX;
  late final double headerY;

  double columnX(int c) => _x[c];

  /// Place [i]'s node in column [c].
  Rect nodeRect(int c, int i) => Rect.fromCenter(center: Offset(_x[c], table.row(i).center.dy), width: node, height: node);
}
