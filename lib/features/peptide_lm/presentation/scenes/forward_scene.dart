import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'attention_scene.dart';
import 'embedding_scene.dart';
import 'feed_forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';

/// Forward: the place in focus's row through the whole pass, layer to
/// layer, down the canvas ([TowerLayout]). It opens on Feed-forward's last
/// frame, block 1's output a row a place. The other rows go; the place's row
/// goes to its slot on a ladder of the stream's points and waits there,
/// faint, while the route comes in: a slot of empty tiles for each point,
/// each part named in the gap before its slot. x0 comes in at the top, as
/// Embedding made it; then, a part at a time, what it adds comes in as a
/// thin strip, and a copy of the row above drops through it into the next
/// slot, turning into the sum as it passes: block 1's two onto the row that
/// waited, then block 2's. The final LayerNorm takes the last drop: the row
/// Predict reads. Only the row last made writes its numbers.
///
/// Every number is the run's: each point of the stream, whole.
final class ForwardScene extends LmScene {
  const ForwardScene();

  static double get _beats => LmStage.forward.beats.toDouble();

  // The open: the table goes, the place's row to its slot, its tile to the
  // ladder's top; the route comes in, then x0.
  static const (double, double) _tagOut = (0.15, 0.4);
  static const (double, double) _tableOut = (0.2, 0.7);
  static const (double, double) _numbersOut = (0.2, 0.5);
  static const (double, double) _move = (0.3, 1.0);
  static const (double, double) _wait = (0.8, 1.1);
  static const (double, double) _routeIn = (0.7, 1.1);
  static const (double, double) _tagIn = (0.9, 1.1);
  static const (double, double) _x0In = (1.0, 1.4);

  // The climb, a part at a time, then the final LayerNorm and the row it
  // makes, outlined.
  static const double _climbFrom = 1.6;
  static const double _finalFrom = 8.4;
  static const double _plainFrom = 9.6;
  static const (double, double) _outlined = (10.2, 10.6);
  static const double _endFrom = 10.6;

  /// The longest a part takes.
  static const double _mostPart = 1.7;

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// The point Feed-forward leaves the stream at, block 1's output: where
  /// the place's row waits for the climb.
  static int get _waiting => 2 * FeedForwardScene.block + 2;

  /// The part that makes slot [k], 1 to the last, of a model of [layers]
  /// blocks: when it starts and how long it takes. Each block's attention
  /// and feed-forward in turn, then the final LayerNorm.
  static (double, double) _part(int k, int layers) {
    if (k > 2 * layers) {
      return (_finalFrom, _mostPart);
    }
    final double step = (_finalFrom - _climbFrom) / (2 * layers);
    return (_climbFrom + (k - 1) * step, math.min(_mostPart, step));
  }

  /// How far the copy dropping into slot [k] has come at [beat], of a model
  /// of [layers] blocks: through the strip of what its part adds.
  static double dropped(int k, int layers, double beat) {
    final (double t, double p) = _part(k, layers);
    return through(beat, t + 0.2 * p, t + 0.68 * p);
  }

  /// How strongly slot [k]'s strip shows at [beat]: in as its part starts.
  static double _stripShown(int k, int layers, double beat) {
    final (double t, double p) = _part(k, layers);
    return through(beat, t, t + 0.2 * p);
  }

  /// How strongly slot [k]'s row writes its numbers at [beat]: from when it
  /// lands until the copy of it starts to drop into the next.
  static double _written(int k, int layers, double beat) {
    double on;
    if (k == 0) {
      on = _span(beat, _x0In);
    } else {
      final (double t, double p) = _part(k, layers);
      on = through(beat, t + 0.68 * p, t + 0.82 * p);
    }
    if (k == 2 * layers + 1) {
      return on;
    }
    final (double t, double p) = _part(k + 1, layers);
    return on * (1 - through(beat, t + 0.18 * p, t + 0.26 * p));
  }

  /// How far slot [k] has its row at [beat]: x0 as it comes in, the others
  /// once their copy has landed.
  static double _landed(int k, int layers, double beat) =>
      k == 0 ? _span(beat, _x0In) : (dropped(k, layers, beat) >= 1 ? 1 : 0);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats, const ForwardFade());

  /// The stage's last frame, with [fade] leaving out or fading what the stage
  /// after it draws itself: Predict opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view, [ForwardFade fade = const ForwardFade()]) =>
      _paint(canvas, size, view, _beats, fade);

  void _paint(Canvas canvas, Size size, LmView view, double beat, ForwardFade fade) {
    if (beat <= 0) {
      const FeedForwardScene().paintEnd(canvas, size, view);
      return;
    }
    final TowerLayout layout = TowerLayout(size, view);
    final StreamTable table = layout.table;
    final int n = view.focus.inputs;
    final int width = view.trace.model.width;
    table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, FeedForwardScene.notes(view).last.$3), ...notes(view)],
      beat,
      alpha: fade.note,
    );
    drawFaded(canvas, size, view, fade.ladder, () {
      table.tag(canvas, "block 1's output · $n × $width", 1 - _span(beat, _tagOut));
      final String name = tag(view);
      drawTag(canvas, view, name, layout.tagAt(tagSize(view, name)), alpha: _span(beat, _tagIn));
      _table(canvas, size, view, layout, beat);
      _route(canvas, view, layout, beat);
      _rows(canvas, view, layout, beat, lastRow: fade.lastRow);
      // The place's tile, from its row to the ladder's top.
      drawToken(
        canvas,
        view,
        Rect.lerp(table.layout.label(view.position), layout.chip, _span(beat, _move))!,
        view.trace.inputAt(view.peptide, view.position),
      );
    });
    final double outlined = _span(beat, _outlined);
    if (outlined > 0 && fade.lastRow) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.slot(layout.points - 1).inflate(2), const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: 0.85 * outlined),
      );
    }
  }

  /// The ladder's name: the place in focus, a row a point of the stream.
  static String tag(LmView view) =>
      "${StreamTable.placeName(view, view.position)}'s row, layer to layer · "
      '${view.trace.points.length} × ${view.trace.model.width}';

  /// Feed-forward's table going: every row but the place in focus's, their
  /// tiles, and the place's outline.
  void _table(Canvas canvas, Size size, LmView view, TowerLayout layout, double beat) {
    final StreamTable table = layout.table;
    final int output = _waiting;
    drawFaded(canvas, size, view, 1 - _span(beat, _tableOut), () {
      for (int i = 0; i < table.places; i++) {
        if (i == view.position) {
          continue;
        }
        table.drawRow(canvas, table.row(i), table.values(output, i), scale: table.scale);
        drawToken(canvas, view, table.layout.label(i), view.trace.inputAt(view.peptide, i));
      }
      table.outline(canvas, view.position, table.row(view.position).right, 1);
    });
  }

  /// The route: each point's slot, empty tiles until its row lands; each
  /// part named in the gap before its slot; x0 named by the ladder's top.
  void _route(Canvas canvas, LmView view, TowerLayout layout, double beat) {
    final double shown = _span(beat, _routeIn);
    if (shown <= 0) {
      return;
    }
    final int layers = view.trace.model.layers;
    final TextStyle face = inked(view.kit.sans, 9, view.inks.quiet, alpha: shown);
    for (int k = 0; k < layout.points; k++) {
      final double landed = _landed(k, layers, beat);
      if (landed < 1) {
        layout.drawSlots(canvas, k, 0.6 * shown * (1 - landed));
      }
      view.kit.draw(canvas, partName(k, layers), face, layout.labelAt(k));
    }
  }

  /// Slot [k]'s name, over it: x0, then the part that makes each row.
  static String partName(int k, int layers) => switch (k) {
    0 => 'x0, as Embedding made it',
    _ when k > 2 * layers => 'final LayerNorm: what Predict reads',
    _ => "+ block ${(k - 1) ~/ 2 + 1}'s ${k.isOdd ? 'attention' : 'feed-forward'}",
  };

  /// The rows: each part's strip as its part starts; each row once landed,
  /// its numbers written until the next drop, the last unless [lastRow] is
  /// false; the place's row from the table, waiting faint in its slot until
  /// the climb reaches it; and each copy as it drops, turning into the sum as
  /// it passes the strip.
  void _rows(Canvas canvas, LmView view, TowerLayout layout, double beat, {bool lastRow = true}) {
    final StreamTable table = layout.table;
    final int layers = view.trace.model.layers;
    final int focus = view.position;
    final int last = layout.points - 1;
    final double finalScale = streamScales(view).$2;
    double scaleOf(int k) => k == last ? finalScale : table.scale;
    List<Color> colours(int k) => <Color>[
      for (final double v in table.values(k, focus)) view.inks.cell(v / scaleOf(k)),
    ];
    for (int k = 1; k < last; k++) {
      final double shown = _stripShown(k, layers, beat);
      if (shown > 0) {
        table.drawRow(canvas, layout.strip(k), table.gained(k - 1, k, focus), scale: layout.gainScale, text: 0, fill: shown);
      }
    }
    for (int k = 0; k <= last; k++) {
      final double landed = _landed(k, layers, beat);
      if (landed > 0 && (lastRow || k < last)) {
        final List<double> values = table.values(k, focus);
        table.drawRow(canvas, layout.slot(k), values, scale: scaleOf(k), fill: landed, text: 0);
        layout.write(canvas, layout.slot(k), values, _written(k, layers, beat));
      }
    }
    final int waiting = _waiting;
    if (dropped(waiting, layers, beat) < 1) {
      table.drawRow(
        canvas,
        Rect.lerp(table.row(focus), layout.slot(waiting), _span(beat, _move))!,
        table.values(waiting, focus),
        scale: table.scale,
        fill: 1 - 0.7 * _span(beat, _wait),
        text: 1 - _span(beat, _numbersOut),
      );
    }
    for (int k = 1; k <= last; k++) {
      final double drop = dropped(k, layers, beat);
      if (drop <= 0 || drop >= 1) {
        continue;
      }
      final List<Color> above = colours(k - 1);
      final List<Color> below = colours(k);
      final double turn = through(drop, 0.3, 0.75);
      table.drawRow(
        canvas,
        Rect.lerp(layout.slot(k - 1), layout.slot(k), drop)!,
        table.values(k, focus),
        scale: scaleOf(k),
        colors: <Color>[for (int d = 0; d < above.length; d++) Color.lerp(above[d], below[d], turn)!],
        text: 0,
      );
    }
  }

  // ------------------------------------------------------------------- taps

  /// While block 2's table still shows, a row puts its place in focus; the
  /// ladder is one place's, and asks for nothing.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) =>
      frame.local * _beats < _tableOut.$1 ? hit(size, view, at) : null;

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = StreamTable(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  // ---------------------------------------------------------------- caption

  /// The place in focus's row going into the final LayerNorm, block 2's
  /// output, and what the norm made of it, as the run kept it.
  static Evening evening(LmView view) => view.kit.memo<Evening>(
    ('final-evening', view.step, view.peptide, view.position),
    () {
      final int last = view.trace.points.length - 1;
      return Evening(
        <double>[
          for (int d = 0; d < view.trace.model.width; d++)
            view.trace.stream(view.checkpoint, last - 1, view.peptide, view.position, d),
        ],
        <double>[
          for (int d = 0; d < view.trace.model.width; d++)
            view.trace.stream(view.checkpoint, last, view.peptide, view.position, d),
        ],
      );
    },
  );

  /// Why each part happens, over the ladder, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int layers = trace.model.layers;
    return <(double, double, String)>[
      (
        0.25,
        layers > 1 ? _part(3, layers).$1 : _finalFrom,
        'each part reads the row as it stands and adds to it:\n'
            'the row is never replaced, only added to',
      ),
      if (layers > 1)
        (
          _part(3, layers).$1,
          _finalFrom,
          'each block after the first reads the row the one before\n'
              'left, and adds to it the same way, with weights of its own',
        ),
      (
        _finalFrom,
        _endFrom,
        'one last evening out, as before each part, with its own\n'
            'scale and shift: the output layer reads rows of one size',
      ),
      (
        _endFrom,
        double.infinity,
        'every place goes down the same pass at once: ${grouped(view.focus.inputs)} rows\n'
            "next: Predict turns ${StreamTable.placeName(view, view.position)}'s last row into a guess",
      ),
    ];
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * _beats;
    final int layers = trace.model.layers;
    final String focus = StreamTable.placeName(view, view.position);
    if (beat < _climbFrom) {
      final String blocks = switch (layers) {
        1 => 'its block',
        2 => 'both blocks',
        _ => 'all ${spelled(layers)} blocks',
      };
      return 'The whole pass for $focus: x0, $blocks, then what Predict reads';
    }
    if (beat < _finalFrom) {
      final double step = (_finalFrom - _climbFrom) / (2 * layers);
      final int k = 1 + math.min(2 * layers - 1, math.max(0, ((beat - _climbFrom) / step).floor()));
      final int b = (k - 1) ~/ 2 + 1;
      if (k.isOdd) {
        return b == 1
            ? "Block 1's attention adds what $focus gathered from the places up to it"
            : "Block $b's attention: $focus reads ${readsMost(view, b - 1)} "
                  '(block 1: ${readsMost(view, AttentionScene.block)})';
      }
      return k == _waiting
          ? "Block $b's feed-forward adds its own: $focus's row as block $b left it"
          : "Block $b's feed-forward adds its network's output: block $b's output";
    }
    final Evening even = evening(view);
    if (beat < _plainFrom) {
      return 'The final LayerNorm: mean ${fixed(even.mean, 2)}, standard deviation ${fixed(even.sd, 2)}';
    }
    if (beat < _endFrom) {
      return even.plain
          ? 'At step ${grouped(view.step)} every scale is 1 and every shift 0: evened = z-score'
          : 'Then its own learned scale and shift: the row Predict reads';
    }
    return "$focus's row as Predict reads it: x0 and ${spelled(2 * layers)} parts' additions, evened";
  }

  /// The place head 1 of [layer] reads most at the place in focus, and its
  /// share, as Attention's map draws it.
  static String readsMost(LmView view, int layer) {
    final List<double> shares = AttentionScene.shares(view, AttentionScene.mapHead, layer: layer);
    int best = 0;
    for (int j = 1; j < shares.length; j++) {
      if (shares[j] > shares[best]) {
        best = j;
      }
    }
    return '${StreamTable.placeName(view, best)} ${percent(shares[best])}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Forward pass, step ${view.step}. ${caption(view, frame)}.';
}

/// What Forward's last frame fades or leaves out, for the stage that opens on
/// it: the ladder, every part of it but its last row (its slots, strips,
/// names, tags and the place's tile); that last row and its outline, which
/// Predict stands up itself; and the note. By default, the frame as Forward
/// draws it.
@immutable
final class ForwardFade {
  const ForwardFade({this.ladder = 1, this.note = 1, this.lastRow = true});

  final double ladder;
  final double note;

  /// Whether the last row, what Predict reads, and its outline are drawn.
  final bool lastRow;
}

/// Forward's canvas, on Embedding's: a ladder of the stream's points for the
/// place in focus, a row a point with the table's own columns, as tall as
/// the room allows up to [_mostRow]; in the gap before each, the part that
/// makes it named over a thin strip of what it adds; the ladder centred in
/// the room Embedding gives the table and its foot, its name over it, the
/// place's tile by its top row.
final class TowerLayout {
  TowerLayout(Size size, LmView view)
    : table = StreamTable(size, view),
      points = view.trace.points.length,
      _view = view {
    final EmbeddingLayout e = table.layout;
    label = view.kit.layout('+ block 1', inked(view.kit.sans, 9, view.inks.quiet)).height;
    final double top = e.tableTop;
    final double room = math.max(0.0, e.footTop + e.footTile.height - top);
    final int gaps = points - 1;
    head = label + _air / 2;
    row = ((room - head - gaps * (label + _air)) / (points + gaps * _stripShare)).clamp(2.0, _mostRow);
    stripHeight = row * _stripShare;
    final double least = label + _air + stripHeight;
    gap = gaps == 0 ? 0.0 : ((room - head - points * row) / gaps).clamp(least, math.max(least, 2 * row));
    final double height = head + points * row + gaps * gap;
    first = top + head + math.max(0.0, (room - height) / 2);
  }

  final StreamTable table;
  final int points;
  final LmView _view;

  /// The tallest a row is drawn.
  static const double _mostRow = 30;

  /// A strip's height, of a row's.
  static const double _stripShare = 0.38;

  /// Over a part's name, between it and its strip, and under the strip.
  static const double _air = 9;

  /// A part's name's height, the room over the first row for x0's, a row's
  /// height, a strip's, a gap's, and the top of the first row.
  late final double label;
  late final double head;
  late final double row;
  late final double stripHeight;
  late final double gap;
  late final double first;

  EmbeddingLayout get _e => table.layout;

  /// Slot [k]'s row: point [k] of the stream.
  Rect slot(int k) {
    final double top = first + k * (row + gap);
    return Rect.fromLTRB(_e.cellsLeft, top, _e.right, top + row);
  }

  /// Where the gap before slot [k] starts its content: the part's name, then
  /// its strip, centred in the gap.
  double _contentTop(int k) => slot(k - 1).bottom + (gap - (label + 3 + stripHeight)) / 2;

  /// Slot [k]'s name, its top left: over its strip, or over the first row.
  Offset labelAt(int k) => Offset(_e.cellsLeft + 1, k == 0 ? first - head : _contentTop(k));

  /// The strip of what the part before slot [k] adds.
  Rect strip(int k) {
    final double top = _contentTop(k) + label + 3;
    return Rect.fromLTRB(_e.cellsLeft, top, _e.right, top + stripHeight);
  }

  /// The place's tile, by the top row, as a row's tile sits by it in the
  /// table: as large as the row and the gutter allow, up to the table's
  /// largest.
  Rect get chip {
    final double side = math.max(_e.chipSide, math.min(14.0, math.min(row - 3, _e.cellsLeft - 3 - _e.left)));
    return Rect.fromLTWH(_e.cellsLeft - 3 - side, slot(0).center.dy - side / 2, side, side);
  }

  /// Where a tag of [size] sits: over the ladder, at the table's left.
  Offset tagAt(Size size) => Offset(_e.left, math.max(_e.tagTop, first - head - size.height - 4));

  /// What the ladder's numbers are written in: as large, up to 9 points, as
  /// the widest of its rows' numbers fits a tile and a row; null where that
  /// is under the least a number is written.
  late final TextStyle? numberStyle = _numberStyle();

  TextStyle? _numberStyle() {
    double most = 0;
    for (int k = 0; k < points; k++) {
      for (final double v in table.values(k, _view.position)) {
        most = math.max(most, v.abs());
      }
    }
    final String widest = '−${'8' * '${most.floor()}'.length}.${'8' * EmbeddingLayout.digits}';
    TextStyle at(double size) => inked(_view.kit.mono, size, _view.inks.ink).copyWith(letterSpacing: 0);
    final double perPoint = _view.kit.layout(widest, at(10)).width / 10;
    final double cell = (_e.right - _e.cellsLeft) / _view.trace.model.width;
    // Held to the half point below, so a number is never wider than drawn.
    final double size =
        (math.min(9, math.min(row * 0.62, (cell - 2 * EmbeddingLayout.gap - 2) / perPoint)) * 2).floorToDouble() / 2;
    return size < EmbeddingLayout.leastNumber ? null : at(size);
  }

  /// [numbers] across [rect] in the ladder's face, [alpha] as strongly.
  void write(Canvas canvas, Rect rect, List<double> numbers, double alpha) {
    final TextStyle? style = numberStyle;
    if (style == null || alpha <= 0) {
      return;
    }
    _e.write(
      canvas,
      rect,
      <String>[for (final double v in numbers) fixed(v, EmbeddingLayout.digits)],
      alpha >= 1 ? style : style.copyWith(color: style.color!.withValues(alpha: (alpha * 8).round() / 8)),
    );
  }

  /// The colour scale of the strips: what every part adds to every place,
  /// one scale for them all, so strips can be set against each other.
  double get gainScale => _view.kit.memo<double>(
    ('forward-gain', _view.step, _view.peptide),
    () => percentileScale(<double>[
      for (int k = 1; k < points - 1; k++)
        for (int i = 0; i < table.places; i++) ...table.gained(k - 1, k, i),
    ]),
  );

  /// Slot [k]'s tiles, empty: an outline each, at [alpha].
  void drawSlots(Canvas canvas, int k, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final Rect rect = slot(k);
    final int count = _view.trace.model.width;
    final double w = rect.width / count;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _view.inks.quiet.withValues(alpha: alpha);
    for (int d = 0; d < count; d++) {
      final Rect tile = Rect.fromLTWH(rect.left + d * w, rect.top, w, rect.height).deflate(EmbeddingLayout.gap);
      canvas.drawRRect(RRect.fromRectAndRadius(tile, const Radius.circular(EmbeddingLayout.radius)), paint);
    }
  }
}
