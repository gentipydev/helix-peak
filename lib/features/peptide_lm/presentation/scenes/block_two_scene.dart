import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import 'attention_scene.dart';
import 'feed_forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';

/// Block 2: the second block on the first one's output, told in the earlier
/// stages' own words. It opens on Feed-forward's last frame, block 1's
/// output a row a place. The rows go into their tiles and head 1's map lies
/// on them as Attention drew it, block 1's; then each cell turns to block
/// 2's own share, the row in focus first. The map goes and the rows come
/// back out as what block 2's attention adds, alone, then added; then what
/// its feed-forward adds, alone, then added: block 2's output. Its
/// LayerNorms and its network are named, not drawn a third time.
///
/// Every number is the run's: each share from the block's kept scores, and
/// each point of the stream, whole.
final class BlockTwoScene extends LmScene {
  const BlockTwoScene();

  /// The block this stage shows: the second.
  static const int block = 1;

  /// The block whose map it shows first, as Attention drew it.
  static const int _before = AttentionScene.block;

  static double get _beats => LmStage.blockTwo.beats.toDouble();

  // Block 1's output, its numbers going; the rows into their tiles; head 1's
  // map, block 1's, as Attention left it.
  static const (double, double) _numbersOut = (0.3, 0.6);
  static const (double, double) _intoTiles = (0.6, 1.4);
  static const (double, double) _mapIn = (1.3, 1.7);

  // Each cell turns to block 2's share: the row in focus a cell at a time,
  // then every other row.
  static const double _turnFrom = 2.6;
  static const (double, double) _focusRow = (2.6, 3.4);
  static const (double, double) _rows = (3.6, 4.8);

  // The map goes; the rows come out of their tiles as what block 2's
  // attention adds, alone; then added.
  static const double _widenFrom = 5.6;
  static const (double, double) _outOfTiles = (5.6, 6.4);
  static const (double, double) _mapOut = (5.6, 5.85);
  static const (double, double) _attentionAlone = (5.6, 6.2);
  static const (double, double) _attentionWritten = (6.4, 6.6);
  static const (double, double) _attentionUnwritten = (7.0, 7.2);
  static const (double, double) _attentionAdded = (7.1, 7.5);
  static const (double, double) _middleWritten = (7.3, 7.5);

  // What block 2's feed-forward adds, alone; then added.
  static const double _feedForwardFrom = 8.4;
  static const (double, double) _middleUnwritten = (8.4, 8.6);
  static const (double, double) _feedForwardAlone = (8.5, 8.9);
  static const (double, double) _feedForwardWritten = (8.9, 9.1);
  static const (double, double) _feedForwardUnwritten = (9.9, 10.1);
  static const (double, double) _feedForwardAdded = (10.0, 10.4);
  static const (double, double) _outputWritten = (10.2, 10.4);

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// The points of the stream: before block 2, after its attention, and
  /// after its feed-forward.
  static int get _input => 2 * block;
  static int get _middle => 2 * block + 1;
  static int get _output => 2 * block + 2;

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats);

  /// The stage's last frame: Forward opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view) => _paint(canvas, size, view, _beats);

  void _paint(Canvas canvas, Size size, LmView view, double beat) {
    if (beat <= 0) {
      const FeedForwardScene().paintEnd(canvas, size, view);
      return;
    }
    final AttentionLayout layout = AttentionLayout(size, view);
    final StreamTable table = layout.table;
    final int n = view.focus.inputs;
    final int width = view.trace.model.width;
    table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, FeedForwardScene.notes(view).last.$3), ...notes(view)],
      beat,
    );
    for (final (String text, double alpha) in <(String, double)>[
      ("block 1's output · $n × $width", 1 - through(beat, 0.5, 0.7)),
      ('block 1 · head 1 · shares in % · $n × $n', through(beat, 1.5, 1.7) * (1 - through(beat, 2.45, _turnFrom))),
      ('block 2 · head 1 · shares in % · $n × $n', through(beat, _turnFrom, 2.75) * (1 - through(beat, 5.45, _widenFrom))),
      ('what attention adds · $n × $width', through(beat, 5.7, 5.9) * (1 - _span(beat, _attentionUnwritten))),
      ("block 1's output + attention · $n × $width", through(beat, 7.2, 7.4) * (1 - _span(beat, _middleUnwritten))),
      ('what the feed-forward adds · $n × $width', through(beat, 8.6, 8.8) * (1 - _span(beat, _feedForwardUnwritten))),
      ("block 2's output · $n × $width", through(beat, 10.2, 10.4)),
    ]) {
      table.tag(canvas, text, alpha);
    }
    final double squeeze = _squeezeAt(beat);
    _stream(canvas, view, layout, beat, squeeze);
    table.drawTiles(canvas, dx: layout.slide(squeeze));
    _map(canvas, view, layout, beat);
    table.outline(canvas, view.position, _outlineRight(layout, view.position, beat, squeeze), 1, dx: layout.slide(squeeze));
  }

  /// How far the rows have gone into their tiles: 0 written out, 1 gone.
  static double _squeezeAt(double beat) => _span(beat, _intoTiles) * (1 - _span(beat, _outOfTiles));

  /// How strongly the map shows at [beat].
  static double _mapShown(double beat) => _span(beat, _mapIn) * (1 - _span(beat, _mapOut));

  /// Where the outline of the row in focus ends: at its row's end; while
  /// the map shows, at the place it reads last, itself.
  static double _outlineRight(AttentionLayout layout, int focus, double beat, double squeeze) {
    final double row = layout.stream(focus, squeeze, 1).right;
    final double reads = layout.mapCell(focus, focus).right;
    return math.max(row, layout.mapLeft + (reads - layout.mapLeft) * _mapShown(beat));
  }

  // ---------------------------------------------------------------- stream

  /// Each place's row: block 1's output, going into its tile; out of it
  /// again as what block 2's attention adds, alone on its own scale, then
  /// the sum; then what its feed-forward adds, alone, then the sum.
  void _stream(Canvas canvas, LmView view, AttentionLayout layout, double beat, double squeeze) {
    final StreamTable table = layout.table;
    final double scale = table.scale;
    final double attentionScale = table.gainScale(_input, _middle);
    final double feedForwardScale = table.gainScale(_middle, _output);
    final double attentionAlone = _span(beat, _attentionAlone);
    final double attentionAdded = _span(beat, _attentionAdded);
    final double feedForwardAlone = _span(beat, _feedForwardAlone);
    final double feedForwardAdded = _span(beat, _feedForwardAdded);
    // Each layer of numbers, and how strongly it is written.
    final double inputText = 1 - _span(beat, _numbersOut);
    final double attentionText = _span(beat, _attentionWritten) * (1 - _span(beat, _attentionUnwritten));
    final double middleText = _span(beat, _middleWritten) * (1 - _span(beat, _middleUnwritten));
    final double feedForwardText = _span(beat, _feedForwardWritten) * (1 - _span(beat, _feedForwardUnwritten));
    final double outputText = _span(beat, _outputWritten);
    for (int i = 0; i < view.focus.inputs; i++) {
      final Rect rect = layout.stream(i, squeeze, 1);
      if (rect.width < 1) {
        continue;
      }
      final List<double> input = table.values(_input, i);
      final List<double> attention = table.gained(_input, _middle, i);
      final List<double> middle = table.values(_middle, i);
      final List<double> feedForward = table.gained(_middle, _output, i);
      final List<double> output = table.values(_output, i);
      final List<Color> colors = <Color>[
        for (int d = 0; d < input.length; d++)
          Color.lerp(
            Color.lerp(
              Color.lerp(
                Color.lerp(view.inks.cell(input[d] / scale), view.inks.cell(attention[d] / attentionScale), attentionAlone)!,
                view.inks.cell(middle[d] / scale),
                attentionAdded,
              )!,
              view.inks.cell(feedForward[d] / feedForwardScale),
              feedForwardAlone,
            )!,
            view.inks.cell(output[d] / scale),
            feedForwardAdded,
          )!,
      ];
      table.drawRow(canvas, rect, input, scale: scale, colors: colors, text: squeeze <= 0.02 ? inputText : 0);
      if (squeeze > 0.02) {
        continue;
      }
      for (final (List<double> numbers, double written) in <(List<double>, double)>[
        (attention, attentionText),
        (middle, middleText),
        (feedForward, feedForwardText),
        (output, outputText),
      ]) {
        if (written > 0) {
          table.drawRow(canvas, rect, numbers, scale: scale, fill: 0, text: written);
        }
      }
    }
  }

  // -------------------------------------------------------------------- map

  /// Head 1's map on the table's rows, as Attention drew it: block 1's
  /// shares, each cell turning to block 2's own, its colour along the
  /// shares' ramp and its number swapped half way, never written between
  /// the two.
  void _map(Canvas canvas, LmView view, AttentionLayout layout, double beat) {
    final double shown = _mapShown(beat);
    if (shown <= 0) {
      return;
    }
    final int n = view.focus.inputs;
    final int focus = view.position;
    final List<List<double>> before = AttentionScene.allShares(view, AttentionScene.mapHead, layer: _before);
    final List<List<double>> after = AttentionScene.allShares(view, AttentionScene.mapHead, layer: block);
    AttentionScene.drawMapHatch(canvas, view, layout, shown);
    for (int i = 0; i < n; i++) {
      for (int j = 0; j <= i; j++) {
        final double turned = turnedAt(i, j, focus, n, beat);
        final double from = before[i][j];
        final double to = after[i][j];
        AttentionScene.drawMapCell(
          canvas,
          view,
          layout,
          i,
          j,
          share: from + (to - from) * turned,
          filled: 1,
          shown: shown,
          written: turned < 0.5 ? from : to,
          writing: shown * (1 - 2 * turned).abs(),
        );
      }
    }
    AttentionScene.drawMapTiles(canvas, view, layout, shown);
  }

  /// How far the map's cell at row [i], column [j] has turned from block
  /// 1's share to block 2's at [beat], in the order Attention filled it.
  static double turnedAt(int i, int j, int focus, int n, double beat) =>
      AttentionScene.fillAt(i, j, focus, n, beat, focusRow: _focusRow, rows: _rows);

  // ------------------------------------------------------------------- taps

  /// A row, or its row of the map, puts its place in focus.
  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) => StreamTable(size, view).placeAt(at);

  // ---------------------------------------------------------------- caption

  /// How many weights and biases a block's feed-forward holds.
  static int feedForwardParameters(TraceModel model) =>
      model.width * model.feedForward + model.feedForward + model.feedForward * model.width + model.width;

  /// Why each part happens, over the table, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int heads = trace.model.heads;
    return <(double, double, String)>[
      (
        0.25,
        _turnFrom,
        'block 2 repeats block 1: LayerNorm, attention, add; then\n'
            'LayerNorm, feed-forward, add. Its weights are its own:\n'
            '${ScoresScene.weightsStatus(view)}',
      ),
      (
        _turnFrom,
        _widenFrom,
        "it reads block 1's output: rows that already carry what\n"
            "block 1's attention gathered and its network added"
            '${switch (heads) {
              1 => '',
              2 => '\nhead 2 reads with a map of its own',
              _ => '\nthe other ${spelled(heads - 1)} heads read with maps of their own',
            }}',
      ),
      (
        _widenFrom,
        _feedForwardFrom,
        "nothing is overwritten: what block 2's attention finds\n"
            "is added to the row, as block 1's was",
      ),
      (
        _feedForwardFrom,
        double.infinity,
        'the same network shape as Feed-forward drew, with '
            '${grouped(feedForwardParameters(trace.model))}\n'
            'weights and biases of its own\n'
            "next: one place's row through the whole pass",
      ),
    ];
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * _beats;
    final int n = view.focus.inputs;
    final int width = trace.model.width;
    final String focus = StreamTable.placeName(view, view.position);
    if (beat < _mapIn.$1) {
      return "Block 2: the same two parts again, on block 1's output, ${grouped(n)} × $width";
    }
    if (beat < _turnFrom) {
      return "Block 1's head 1, as Attention drew it: $focus read "
          '${AttentionScene.readsMost(view, AttentionScene.mapHead, layer: _before)}';
    }
    if (beat < _rows.$1) {
      return "Block 2's head 1, its own weights: $focus reads "
          '${AttentionScene.readsMost(view, AttentionScene.mapHead, layer: block)}';
    }
    if (beat < _widenFrom) {
      return "Every place reads anew with block 2's weights: ${grouped(n)} rows";
    }
    if (beat < _attentionAdded.$1) {
      return "What block 2's attention adds to each place, made as in Attention";
    }
    if (beat < _feedForwardFrom) {
      return "Added: block 1's output + attention, ${grouped(n)} × $width";
    }
    if (beat < _feedForwardAdded.$1) {
      return "Block 2's feed-forward, each place alone: its own $width → ${trace.model.feedForward} → $width";
    }
    return "Added: block 2's output, ${grouped(n)} × $width";
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Block 2, step ${view.step}. ${caption(view, frame)}.';
}
