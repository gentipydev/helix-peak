import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../shared/motion/animation_timeline.dart';
import '../../domain/training_trace.dart';
import 'lm_scene.dart';

/// What the scenes draw text with, laid out once and kept, and what they work
/// out once a checkpoint ([memo]): a scene paints sixty times a second, and
/// neither a label's layout nor a layer's colour scale changes between frames.
final class LmKit {
  LmKit({required this.mono, required this.sans, required this.scaler, TextStyle? label})
    : label = label ?? sans;

  /// Ids, numbers and letters.
  final TextStyle mono;

  /// Labels.
  final TextStyle sans;
  final TextScaler scaler;

  /// A part's name on its plate ([drawTag]), as the zoom names its parts.
  final TextStyle label;

  final Map<(String, TextStyle), TextPainter> _laid =
      <(String, TextStyle), TextPainter>{};
  final Map<(String, TextStyle, double), TextPainter> _wrapped =
      <(String, TextStyle, double), TextPainter>{};
  final Map<Object, Object> _memo = <Object, Object>{};

  // Enough for every label of every stage; past it the cache starts again.
  static const int _most = 1500;

  T memo<T extends Object>(Object key, T Function() make) =>
      _memo.putIfAbsent(key, make) as T;

  TextPainter layout(String text, TextStyle style) {
    if (_laid.length > _most) {
      _clear();
    }
    return _laid.putIfAbsent(
      (text, style),
      () => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout(),
    );
  }

  /// [text] broken into lines no wider than [width], laid out once and kept.
  TextPainter paragraph(String text, TextStyle style, double width) {
    if (_wrapped.length > _most) {
      _clear();
    }
    return _wrapped.putIfAbsent(
      (text, style, width),
      () => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width),
    );
  }

  /// Draws [text] with its [anchor] at [at]: (0, 0) its top left, (0.5, 0.5)
  /// its centre, (1, 1) its bottom right.
  Size draw(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    Offset anchor = Offset.zero,
  }) {
    final TextPainter painter = layout(text, style);
    painter.paint(
      canvas,
      at - Offset(painter.width * anchor.dx, painter.height * anchor.dy),
    );
    return painter.size;
  }

  void _clear() {
    for (final TextPainter painter in <TextPainter>[..._laid.values, ..._wrapped.values]) {
      painter.dispose();
    }
    _laid.clear();
    _wrapped.clear();
  }

  void dispose() {
    _clear();
    _memo.clear();
  }
}

/// [style] at [size] points in [color], with the alpha held to eighths, so a
/// fading label is one of a few styles rather than a new one every frame.
TextStyle inked(TextStyle style, double size, Color color, {double alpha = 1}) =>
    style.copyWith(
      fontSize: (size * 2).round() / 2,
      height: 1,
      color: color.withValues(alpha: color.a * ((alpha.clamp(0.0, 1.0) * 8).round() / 8)),
    );

/// How far [local] is through `start`..`end`, eased as the app eases.
double through(double local, double start, double end) =>
    AnimationTimeline.slice(local, start, end);

/// How strong a value has to be to fill its colour: the stream's 99th
/// percentile at this checkpoint over the peptide in focus, every point but
/// the last, and the final norm's own.
(double, double) streamScales(LmView view) => view.kit.memo<(double, double)>(
  ('forward-scales', view.step, view.peptide),
  () {
    final TrainingTrace trace = view.trace;
    final int last = 2 * trace.model.layers;
    double percentile(Iterable<int> points) {
      final List<double> values = <double>[
        for (final int point in points)
          for (int i = 0; i < view.focus.inputs; i++)
            for (int d = 0; d < trace.model.width; d++)
              trace.stream(view.checkpoint, point, view.peptide, i, d).abs(),
      ]..sort();
      return math.max(1e-6, values[(values.length * 0.99).floor().clamp(0, values.length - 1)]);
    }

    return (
      percentile(<int>[for (int k = 0; k <= last; k++) k]),
      percentile(<int>[last + 1]),
    );
  },
);

/// The 99th percentile of [values]' sizes, never quite zero: a colour scale
/// for a set of numbers drawn on their own.
double percentileScale(Iterable<double> values) {
  final List<double> sizes = <double>[for (final double v in values) v.abs()]..sort();
  if (sizes.isEmpty) {
    return 1e-6;
  }
  return math.max(1e-6, sizes[(sizes.length * 0.99).floor().clamp(0, sizes.length - 1)]);
}

/// [draw], at [alpha] as a whole.
void drawFaded(Canvas canvas, Size size, LmView view, double alpha, VoidCallback draw) {
  if (alpha <= 0) {
    return;
  }
  if (alpha >= 1) {
    draw();
    return;
  }
  // A layer takes only its paint's alpha.
  canvas.saveLayer(Offset.zero & size, Paint()..color = view.inks.ground.withValues(alpha: alpha));
  draw();
  canvas.restore();
}

/// Many straight lines drawn in a few calls: each line goes into a bucket by
/// its colour, its alpha held to sixteenths and its width to quarter points,
/// and each bucket is one call. A network's edges.
final class LineBatch {
  final Map<(int, int, int), List<double>> _buckets = <(int, int, int), List<double>>{};

  void line(Offset a, Offset b, Color color, double width, double alpha) {
    final int level = (alpha.clamp(0.0, 1.0) * 16).round();
    if (level <= 0 || width <= 0) {
      return;
    }
    final int quarter = math.max(1, (width * 4).round());
    _buckets.putIfAbsent((color.toARGB32(), level, quarter), () => <double>[])
      ..add(a.dx)
      ..add(a.dy)
      ..add(b.dx)
      ..add(b.dy);
  }

  void draw(Canvas canvas) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final MapEntry<(int, int, int), List<double>> bucket in _buckets.entries) {
      final (int argb, int level, int quarter) = bucket.key;
      paint
        ..color = Color(argb).withValues(alpha: Color(argb).a * level / 16)
        ..strokeWidth = quarter / 4;
      canvas.drawRawPoints(ui.PointMode.lines, Float32List.fromList(bucket.value), paint);
    }
  }
}

/// Every edge of a network's layer, (from, to, what it carries), faint, as
/// strong as what it carries against the strongest, in the colour of its sign;
/// or against [most], where the edges must keep one scale while what they
/// carry changes. [alphaOf] gives the edges into one end their own share of
/// [alpha], where they come one end at a time.
void drawEdges(
  Canvas canvas,
  LmView view,
  List<(int, int, double)> edges,
  Offset Function(int) from,
  Offset Function(int) to,
  double alpha, {
  double? most,
  double Function(int to)? alphaOf,
}) {
  double strongest = 1e-9;
  if (most == null) {
    for (final (_, _, double c) in edges) {
      strongest = math.max(strongest, c.abs());
    }
  }
  final double reach = most ?? strongest;
  final LineBatch batch = LineBatch();
  for (final (int a, int b, double c) in edges) {
    final double share = alphaOf == null ? 1 : alphaOf(b);
    if (share <= 0) {
      continue;
    }
    final double w = math.min(1.0, c.abs() / reach);
    batch.line(
      from(a),
      to(b),
      c >= 0 ? view.inks.positive : view.inks.negative,
      0.5 + 1.3 * w,
      (0.05 + 0.75 * math.pow(w, 1.4)) * alpha * share,
    );
  }
  batch.draw(canvas);
}

/// A card on the ground for words worked out over a busy canvas: [box]
/// backed by the ground, nearly opaque, and outlined in the rule.
void drawCard(Canvas canvas, LmView view, Rect box, double alpha) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, const Radius.circular(6)),
    Paint()..color = view.inks.ground.withValues(alpha: 0.92 * alpha),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, const Radius.circular(6)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = view.inks.rule.withValues(alpha: alpha),
  );
}

/// A grid of flat cells drawn in one call: a residual stream, a weight matrix.
final class GridMesh {
  GridMesh(
    Rect rect,
    this.columns,
    this.rows, {
    double columnGap = 0,
    double rowGap = 0,
  }) : assert(columns * rows * 4 <= 65535, 'too many cells for one draw'),
       _positions = Float32List(columns * rows * 8),
       _indices = Uint16List(columns * rows * 6),
       _colors = Int32List(columns * rows * 4) {
    final double w = rect.width / columns;
    final double h = rect.height / rows;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final int cell = r * columns + c;
        final double x0 = rect.left + c * w;
        final double y0 = rect.top + r * h;
        final double x1 = x0 + math.max(0.5, w - columnGap);
        final double y1 = y0 + math.max(0.5, h - rowGap);
        _positions.setAll(cell * 8, <double>[x0, y0, x1, y0, x1, y1, x0, y1]);
        final int v = cell * 4;
        _indices.setAll(cell * 6, <int>[v, v + 1, v + 2, v, v + 2, v + 3]);
      }
    }
  }

  final int columns;
  final int rows;
  final Float32List _positions;
  final Uint16List _indices;
  final Int32List _colors;

  void cell(int column, int row, Color color) {
    final int v = (row * columns + column) * 4;
    final int argb = color.toARGB32();
    _colors[v] = argb;
    _colors[v + 1] = argb;
    _colors[v + 2] = argb;
    _colors[v + 3] = argb;
  }

  void draw(Canvas canvas) {
    final ui.Vertices vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      _positions,
      colors: _colors,
      indices: _indices,
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }
}

/// A row of square tiles, one a token, centred in [bounds] and no larger than
/// [most].
final class TokenLayout {
  TokenLayout(Rect bounds, this.count, {double most = 24})
    : cell = math.min(most, bounds.width / count),
      top = bounds.top,
      left = bounds.center.dx - math.min(most, bounds.width / count) * count / 2;

  final int count;
  final double cell;
  final double top;
  final double left;

  Rect at(int i) => Rect.fromLTWH(left + i * cell, top, cell, cell);

  double centre(int i) => left + (i + 0.5) * cell;

  Rect get bounds => Rect.fromLTWH(left, top, cell * count, cell);

  int? indexAt(Offset point, {double slack = 12}) {
    if (point.dy < top - slack || point.dy > top + cell + slack) {
      return null;
    }
    final int i = ((point.dx - left) / cell).floor();
    return i < 0 || i >= count ? null : i;
  }
}

/// The letter a token is drawn with: its residue, or a bracket for the
/// frame's two ends, a dot for padding.
String glyph(TrainingTrace trace, int id) {
  final String name = trace.token(id);
  if (name.length == 1) {
    return name;
  }
  return switch (name) {
    '<bos>' => '<',
    '<eos>' => '>',
    _ => '·',
  };
}

/// One token's tile: a residue in its colour with its letter knocked out, an
/// end of the frame on the tile in the quiet ink, padding as an outline. Its
/// letter or mark at [mark] of [alpha].
void drawToken(
  Canvas canvas,
  LmView view,
  Rect rect,
  int id, {
  double alpha = 1,
  Color? outline,
  double mark = 1,
}) {
  if (alpha <= 0) {
    return;
  }
  final TrainingTrace trace = view.trace;
  final bool residue = trace.isResidue(id);
  final bool pad = trace.token(id) == '<pad>';
  final Rect tile = rect.deflate(math.min(1.0, rect.width * 0.08));
  final RRect shape = RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.18));
  final Color fill = residue ? view.inks.residue(trace.token(id)) : view.inks.zero;
  if (pad) {
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
  } else {
    canvas.drawRRect(shape, Paint()..color = fill.withValues(alpha: alpha));
  }
  if (outline != null) {
    outlineToken(canvas, rect, outline, alpha: alpha);
  }
  if (tile.height >= 8.5 && mark > 0) {
    view.kit.draw(
      canvas,
      glyph(trace, id),
      inked(
        view.kit.mono,
        (tile.height * 0.68).clamp(6.0, 14.0),
        residue ? view.inks.ground : view.inks.quiet,
        alpha: alpha * mark,
      ),
      tile.center,
      anchor: const Offset(0.5, 0.5),
    );
  }
}

/// A token's tile ringed in [color], as [drawToken] rings one, round the tile
/// [rect] holds: for a tile drawn already, or one that moves while its ring
/// comes and goes.
void outlineToken(Canvas canvas, Rect rect, Color color, {double alpha = 1}) {
  if (alpha <= 0) {
    return;
  }
  final Rect tile = rect.deflate(math.min(1.0, rect.width * 0.08));
  final RRect shape = RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.18));
  canvas.drawRRect(
    shape.inflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: alpha),
  );
}

/// How tall a tile must be to carry its id's number.
const double idNumbered = 11;

/// A token as its id: a plain tile under a stripe of its residue's colour,
/// the id in the accent, or in [number] where given; an end of the frame or
/// padding in the quiet ink. The number is [numberScale] of the tile's
/// height, where its width lets it.
void drawIdTile(
  Canvas canvas,
  LmView view,
  Rect rect,
  int id, {
  double alpha = 1,
  double numberScale = 0.52,
  Color? number,
}) {
  if (alpha <= 0) {
    return;
  }
  final TrainingTrace trace = view.trace;
  final Rect tile = rect.deflate(math.min(1.0, rect.width * 0.08));
  final bool residue = trace.isResidue(id);
  final bool pad = trace.token(id) == '<pad>';
  final RRect shape = RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.18));
  if (pad) {
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
  } else {
    canvas.drawRRect(shape, Paint()..color = view.inks.zero.withValues(alpha: alpha));
    final Color stripe = residue ? view.inks.residue(trace.token(id)) : view.inks.quiet;
    final double band = tile.height < 11 ? tile.height * 0.4 : math.max(1.5, tile.height * 0.14);
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRect(
      Rect.fromLTWH(tile.left, tile.top, tile.width, band),
      Paint()..color = stripe.withValues(alpha: alpha),
    );
    canvas.restore();
  }
  // The number as large as the tile's height allows, and narrow enough
  // that the vocabulary's longest id fits across it.
  final String widest = '8' * '${trace.vocab.length - 1}'.length;
  final double perPoint = view.kit.layout(widest, inked(view.kit.mono, 10, view.inks.quiet)).width / 10;
  // Held to the half point below, so the drawn number is never wider.
  final double size =
      (math.min(math.min(tile.height * numberScale, tile.width / perPoint), 14) * 2).floorToDouble() / 2;
  if (tile.height >= idNumbered && size >= 5) {
    view.kit.draw(
      canvas,
      '$id',
      inked(
        view.kit.mono,
        size,
        residue ? number ?? view.inks.signal : view.inks.quiet,
        alpha: alpha,
      ),
      tile.center + Offset(0, tile.height * 0.06),
      anchor: const Offset(0.5, 0.5),
    );
  }
}

/// How far a tag's words sit inside its plate: the zoom's.
const double tagPadding = 6;

/// The size of [text]'s plate ([drawTag]).
Size tagSize(LmView view, String text) {
  final TextPainter words = view.kit.layout(text, _tagWords(view, 1));
  return Size(words.width + 2 * tagPadding, words.height + tagPadding);
}

TextStyle _tagWords(LmView view, double alpha) => view.kit.label.copyWith(
  color: view.inks.ink.withValues(alpha: (alpha.clamp(0.0, 1.0) * 8).round() / 8),
);

/// A part's name on a plate with its top left at [at], as the zoom names its
/// parts: the label face on the raised surface. A tag set away from what it
/// names has a line in the quiet ink that lands on [target] with a dot, or
/// with none where the scene marks the place itself ([dot] false, a bracket
/// over a span). Returns the plate.
Rect drawTag(
  Canvas canvas,
  LmView view,
  String text,
  Offset at, {
  Offset? target,
  bool dot = true,
  double alpha = 1,
}) {
  final Rect plate = at & tagSize(view, text);
  if (alpha <= 0) {
    return plate;
  }
  if (target != null) {
    final Paint line = Paint()
      ..strokeWidth = 1.2
      ..color = view.inks.quiet.withValues(alpha: alpha);
    canvas.drawLine(_leaderFrom(plate, target), target, line);
    if (dot) {
      canvas.drawCircle(target, 2.6, line);
    }
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(plate, const Radius.circular(6)),
    Paint()..color = view.inks.raised.withValues(alpha: 0.88 * alpha),
  );
  view.kit.draw(
    canvas,
    text,
    _tagWords(view, alpha),
    plate.topLeft + const Offset(tagPadding, tagPadding / 2),
  );
  return plate;
}

/// The word on the mark of what the reader follows ([drawFollowed]).
const String followedTag = 'followed';

/// From the name of what is followed to its mark.
const double followedAfter = 8;

/// The mark of what the reader follows, on a line whose middle is
/// [centre].dy, from [centre].dx: a small plate in the accent naming it
/// followed, and beside it, in the quiet ink, the first of [hints] that fits
/// before [end], none where none does. A line's own size, so it sits on a
/// name's line and never on what is under it. Returns the plate.
Rect drawFollowed(
  Canvas canvas,
  LmView view,
  Offset centre,
  double end,
  List<String> hints,
  double alpha, {
  double size = 9,
}) {
  final TextStyle words = inked(view.kit.label, size, view.inks.signal, alpha: alpha);
  final Rect plate = followedPlate(view, centre, size: size);
  if (alpha <= 0) {
    return plate;
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(plate, const Radius.circular(4)),
    Paint()..color = view.inks.signal.withValues(alpha: _followedPlate * alpha),
  );
  view.kit.draw(canvas, followedTag, words, plate.center, anchor: const Offset(0.5, 0.5));
  drawFollowHint(canvas, view, Offset(plate.right + _followedGap, plate.center.dy), end, hints, alpha, size: size);
  return plate;
}

/// The plate [drawFollowed] draws from [centre].
Rect followedPlate(LmView view, Offset centre, {double size = 9}) {
  final TextPainter word = view.kit.layout(followedTag, inked(view.kit.label, size, view.inks.signal));
  return Rect.fromLTWH(
    centre.dx,
    centre.dy - word.height / 2 - _followedPad.dy,
    word.width + 2 * _followedPad.dx,
    word.height + 2 * _followedPad.dy,
  );
}

/// How to follow another, the first of [hints] that fits between
/// [start].dx and [end], on a line whose middle is [start].dy, in the quiet
/// ink; none where none fits. Returns the line drawn, or null.
Rect? drawFollowHint(
  Canvas canvas,
  LmView view,
  Offset start,
  double end,
  List<String> hints,
  double alpha, {
  double size = 9,
}) {
  final TextStyle hint = inked(view.kit.sans, size, view.inks.quiet, alpha: alpha);
  for (final String text in hints) {
    final TextPainter line = view.kit.layout(text, hint);
    if (start.dx + line.width <= end) {
      if (alpha > 0) {
        view.kit.draw(canvas, text, hint, start, anchor: const Offset(0, 0.5));
      }
      return Rect.fromLTWH(start.dx, start.dy - line.height / 2, line.width, line.height);
    }
  }
  return null;
}

/// The followed plate's words from its edges, its strength in the accent,
/// and the room from it to its hint.
const Offset _followedPad = Offset(5, 2);
const double _followedPlate = 0.18;
const double _followedGap = 6;

/// Where a tag's line leaves its plate: straight down or up where what it
/// names lies under or over the plate, else from the nearer side.
Offset _leaderFrom(Rect plate, Offset target) {
  final double x = math.min(math.max(target.dx, plate.left + tagPadding), plate.right - tagPadding);
  if (target.dy >= plate.bottom) {
    return Offset(x, plate.bottom);
  }
  if (target.dy <= plate.top) {
    return Offset(x, plate.top);
  }
  return Offset(target.dx < plate.left ? plate.left : plate.right, plate.center.dy);
}

/// A small triangle pointing up, its tip at [tip].
void drawCaret(Canvas canvas, Offset tip, double size, Color color) {
  canvas.drawPath(
    Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - size, tip.dy + size * 1.2)
      ..lineTo(tip.dx + size, tip.dy + size * 1.2)
      ..close(),
    Paint()..color = color,
  );
}

void dashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  double dash = 4,
  double gap = 3,
}) {
  final double length = (b - a).distance;
  if (length <= 0) {
    return;
  }
  final Offset step = (b - a) / length;
  for (double at = 0; at < length; at += dash + gap) {
    canvas.drawLine(a + step * at, a + step * math.min(length, at + dash), paint);
  }
}
