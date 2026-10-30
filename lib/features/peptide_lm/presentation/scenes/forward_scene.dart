import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'forward_opening.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

enum _Part { opening, block, norm }

/// Where the forward pass is: its opening ([ForwardOpening]), a block
/// (counted from 1), or the final norm, and how far through that part.
@immutable
final class ForwardMoment {
  const ForwardMoment._(this._part, this.block, this.progress);

  final _Part _part;
  final int block;
  final double progress;

  bool get opening => _part == _Part.opening;

  bool get norming => _part == _Part.norm;

  // Within a block: normalise, attend, add, feed forward, add.
  static const double attendFrom = 0.12;
  static const double attendTo = 0.55;
  static const double addedAttention = 0.65;
  static const double fedForward = 0.85;

  bool get attending => _part == _Part.block && progress >= attendFrom && progress < attendTo;

  bool get feedingForward =>
      _part == _Part.block && progress >= addedAttention && progress < fedForward;

  /// The forward pass's parts in proportion: six beats to open on the batch
  /// and embed it, four a block, one for the final norm.
  static ForwardMoment at(int layers, double local) {
    const double open = ForwardOpening.beats;
    final double total = open + 4.0 * layers + 1;
    final double at = local.clamp(0.0, 1.0) * total;
    if (at < open) {
      return ForwardMoment._(_Part.opening, 0, at / open);
    }
    if (at < open + 4 * layers) {
      final double b = (at - open) / 4;
      final int block = b.floor();
      return ForwardMoment._(_Part.block, block + 1, b - block);
    }
    return ForwardMoment._(_Part.norm, layers, (at - open - 4 * layers).clamp(0.0, 1.0));
  }
}

/// Forward: it opens on Tokenise's last frame and embeds the batch
/// ([ForwardOpening]); then the residual stream, one column of numbers a
/// position, rises through the blocks. In each, every position reads the ones
/// before it (attention, the arcs) and what it reads is added to its column;
/// then each column goes through the feed-forward layer and that is added too.
final class ForwardScene extends LmScene {
  const ForwardScene();

  /// The stream's points at the start and end of where [moment] is, and how
  /// far between them it has got.
  static (int, int, double) blend(TrainingTrace trace, ForwardMoment moment) {
    if (moment.opening) {
      return (0, 0, 0);
    }
    if (moment.norming) {
      final int last = 2 * trace.model.layers;
      return (last, last + 1, through(moment.progress, 0, 1));
    }
    final int before = 2 * (moment.block - 1);
    final int middle = before + 1;
    final int after = before + 2;
    final double p = moment.progress;
    if (p < ForwardMoment.attendTo) {
      return (before, before, 0);
    }
    if (p < ForwardMoment.addedAttention) {
      return (before, middle, through(p, ForwardMoment.attendTo, ForwardMoment.addedAttention));
    }
    if (p < ForwardMoment.fedForward) {
      return (middle, middle, 0);
    }
    return (middle, after, through(p, ForwardMoment.fedForward, 1));
  }

  /// How strong a value has to be to fill its colour: the stream's 99th
  /// percentile at this checkpoint, and the final norm's own.
  static (double, double) scales(LmView view) => view.kit.memo<(double, double)>(
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

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final ForwardLayout layout = ForwardLayout(size, view);
    final ForwardMoment moment = ForwardMoment.at(trace.model.layers, frame.local);
    if (moment.opening) {
      _open(canvas, size, view, layout, moment);
      return;
    }
    final int layer = math.max(1, moment.block);

    _rail(canvas, view, layout, moment);
    _heads(canvas, view, layout, layer - 1, _query(view, moment), 1);
    _stream(canvas, view, layout, moment);
    _arcs(canvas, view, layout, layer - 1, moment, frame.local);
    for (int i = 0; i < view.focus.inputs; i++) {
      drawToken(
        canvas,
        view,
        layout.tokens.at(i),
        trace.inputAt(view.peptide, i),
        outline: i == view.position ? view.inks.signal : null,
      );
    }
    drawCaret(
      canvas,
      Offset(layout.tokens.centre(view.position), layout.tokens.bounds.bottom + 2),
      4,
      view.inks.signal,
    );
  }

  /// The opening, and round it what it hands over to: the rail, lit at the
  /// embedding once the list has left its column, and as it settles the head
  /// maps, faint as they are before any block has run, and the place in
  /// focus.
  void _open(Canvas canvas, Size size, LmView view, ForwardLayout layout, ForwardMoment moment) {
    final ForwardOpening opening = ForwardOpening(size, view, layout);
    final double beat = moment.progress * ForwardOpening.beats;
    opening.paint(canvas, beat);
    _faded(canvas, size, view, ForwardOpening.railShown(beat), () => _rail(canvas, view, layout, moment));
    final double settled = ForwardOpening.settled(beat);
    _faded(canvas, size, view, settled, () {
      _heads(canvas, view, layout, 0, _query(view, moment), 0.35);
      drawToken(
        canvas,
        view,
        layout.tokens.at(view.position),
        view.trace.inputAt(view.peptide, view.position),
        outline: view.inks.signal,
      );
      drawCaret(
        canvas,
        Offset(layout.tokens.centre(view.position), layout.tokens.bounds.bottom + 2),
        4,
        view.inks.signal,
      );
    });
  }

  /// [draw], at [alpha] as a whole.
  static void _faded(Canvas canvas, Size size, LmView view, double alpha, VoidCallback draw) {
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

  /// The position whose reading the arcs show: the one in focus. The head
  /// maps above show every position's at once.
  static int _query(LmView view, ForwardMoment moment) => view.position;

  void _rail(Canvas canvas, LmView view, ForwardLayout layout, ForwardMoment moment) {
    final ModuleRail rail = layout.rail;
    final List<double> lit = List<double>.filled(rail.count, 0);
    if (moment.opening) {
      lit[ModuleRail.embed] = 1;
    } else if (moment.norming) {
      lit[rail.norm] = 1;
    } else {
      lit[rail.block(moment.block)] = 1;
    }
    // Where the stream has been is lit a little.
    final int reached = moment.opening
        ? 0
        : moment.norming
        ? rail.norm
        : rail.block(moment.block);
    for (int i = 0; i < reached; i++) {
      lit[i] = math.max(lit[i], 0.25);
    }
    rail.paint(canvas, view, lit: lit);
    if (!moment.opening && !moment.norming) {
      final Rect box = rail.box(rail.block(moment.block));
      final double p = moment.progress;
      final String part = p < ForwardMoment.attendFrom
          ? 'LayerNorm'
          : p < ForwardMoment.addedAttention
          ? 'attention'
          : 'feed-forward';
      view.kit.draw(
        canvas,
        part,
        inked(view.kit.sans, 8.5, view.inks.signal),
        Offset(box.center.dx, box.bottom - 4),
        anchor: const Offset(0.5, 1),
      );
    }
  }

  void _stream(Canvas canvas, LmView view, ForwardLayout layout, ForwardMoment moment) {
    final TrainingTrace trace = view.trace;
    final int inputs = view.focus.inputs;
    final int width = trace.model.width;
    final (double streamScale, double finalScale) = scales(view);
    final (int from, int to, double t) = blend(trace, moment);
    final double scaleFrom = from == 2 * trace.model.layers + 1 ? finalScale : streamScale;
    final double scaleTo = to == 2 * trace.model.layers + 1 ? finalScale : streamScale;
    final double scale = scaleFrom + (scaleTo - scaleFrom) * t;
    final GridMesh grid = GridMesh(layout.grid, inputs, width, columnGap: 1);
    for (int i = 0; i < inputs; i++) {
      for (int d = 0; d < width; d++) {
        final double a = trace.stream(view.checkpoint, from, view.peptide, i, d);
        final double b = from == to ? a : trace.stream(view.checkpoint, to, view.peptide, i, d);
        grid.cell(i, d, view.inks.signed((a + (b - a) * t) / scale));
      }
    }
    grid.draw(canvas);

    final Rect bounds = layout.grid;
    if (!moment.norming && moment.progress < ForwardMoment.attendFrom) {
      // LayerNorm: a band passing down every column at once.
      final double y = bounds.top + bounds.height * (moment.progress / ForwardMoment.attendFrom);
      canvas.drawRect(
        Rect.fromLTRB(bounds.left, math.max(bounds.top, y - 10), bounds.right, math.min(bounds.bottom, y + 2)),
        Paint()..color = view.inks.signal.withValues(alpha: 0.18),
      );
    }
    if (moment.feedingForward) {
      // Each column breathes out to the feed-forward's width and back.
      final double wave = through(moment.progress, ForwardMoment.addedAttention, ForwardMoment.fedForward) *
          (inputs + 3);
      final double cell = layout.tokens.cell;
      final double widen = trace.model.feedForward / width;
      for (int i = 0; i < inputs; i++) {
        final double breath = math.sin(math.pi * (wave - i).clamp(0.0, 1.0));
        if (breath <= 0) {
          continue;
        }
        final Rect ghost = Rect.fromCenter(
          center: Offset(layout.tokens.centre(i), bounds.center.dy),
          width: cell * (1 + (widen - 1) * breath),
          height: bounds.height + 6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(ghost, const Radius.circular(3)),
          Paint()..color = view.inks.signal.withValues(alpha: 0.10 * breath),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(ghost, const Radius.circular(3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = view.inks.signal.withValues(alpha: 0.5 * breath),
        );
      }
    }
    if (moment.norming) {
      // The final norm's scale replaces the stream's.
      canvas.drawRect(
        bounds.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = view.inks.signal.withValues(alpha: 0.6 * math.sin(math.pi * moment.progress)),
      );
    }
  }

  void _arcs(
    Canvas canvas,
    LmView view,
    ForwardLayout layout,
    int layer,
    ForwardMoment moment,
    double local,
  ) {
    if (!moment.norming && moment.progress < ForwardMoment.attendFrom) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int query = _query(view, moment);
    final double base = layout.grid.top - 3;
    final double height = layout.arcs.height;
    // The arcs bloom as attention starts, and stay, quieter, once it is added.
    final double strength = moment.attending
        ? through(moment.progress, ForwardMoment.attendFrom, ForwardMoment.attendFrom + 0.15)
        : moment.norming
        ? 0.35
        : 0.55;
    // Particles ride the arcs while attention is read, about once a second.
    final double phase =
        moment.attending ? (local * LmStage.forward.beats * 1.1) % 1 : -1;
    final double xi = layout.tokens.centre(query);
    double weight(int key) => view.head == null
        ? trace.meanAttention(view.checkpoint, layer, view.peptide, query, key)
        : trace.attention(view.checkpoint, layer, view.head!, view.peptide, query, key);
    // Each arc against the strongest: the caption gives the shares.
    double strongest = 1e-9;
    for (int key = 0; key <= query; key++) {
      strongest = math.max(strongest, weight(key));
    }
    for (int key = 0; key <= query; key++) {
      final double w = weight(key) / strongest;
      if (w < 0.04) {
        continue;
      }
      final double xj = layout.tokens.centre(key);
      final Paint stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.8 + 3.2 * w
        ..color = view.inks.signal.withValues(alpha: (0.2 + 0.8 * w) * strength);
      if (key == query) {
        canvas.drawCircle(Offset(xi, base - 5), 4, stroke);
        continue;
      }
      final double rise = math.min(height, 10 + height * (query - key) / math.max(1, view.focus.inputs - 1));
      final Offset start = Offset(xj, base);
      final Offset control = Offset((xi + xj) / 2, base - rise * 2);
      final Offset end = Offset(xi, base);
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
        stroke,
      );
      if (phase >= 0) {
        for (final double offset in const <double>[0, 0.5]) {
          final double s = (phase + offset) % 1;
          final Offset dot = Offset(
            (1 - s) * (1 - s) * start.dx + 2 * (1 - s) * s * control.dx + s * s * end.dx,
            (1 - s) * (1 - s) * start.dy + 2 * (1 - s) * s * control.dy + s * s * end.dy,
          );
          canvas.drawCircle(dot, 1 + 2 * math.sqrt(w), Paint()..color = view.inks.signal.withValues(alpha: 0.9 * strength));
        }
      }
    }
  }

  /// Each head's map in [layer], its colours at [alpha]: faint before any
  /// block has run.
  void _heads(
    Canvas canvas,
    LmView view,
    ForwardLayout layout,
    int layer,
    int query,
    double alpha,
  ) {
    final TrainingTrace trace = view.trace;
    final int inputs = view.focus.inputs;
    for (int h = 0; h < trace.model.heads; h++) {
      final Rect square = layout.head(h);
      canvas.drawRect(square, Paint()..color = view.inks.card.withValues(alpha: alpha));
      final GridMesh map = GridMesh(square, inputs, inputs);
      for (int i = 0; i < inputs; i++) {
        for (int j = 0; j < inputs; j++) {
          if (j > i) {
            map.cell(j, i, view.inks.ground);
            continue;
          }
          final double w = trace.attention(view.checkpoint, layer, h, view.peptide, i, j);
          map.cell(j, i, Color.lerp(view.inks.zero, view.inks.signal, math.sqrt(w) * alpha)!);
        }
      }
      map.draw(canvas);
      // Above the diagonal nothing is read: a position never reads ahead.
      final Path hatch = Path();
      for (double d = 4; d < square.width * 2; d += 5) {
        hatch
          ..moveTo(square.left + d, square.top)
          ..lineTo(square.left + d - square.width, square.top + square.width);
      }
      canvas.save();
      canvas.clipPath(Path()
        ..moveTo(square.left, square.top)
        ..lineTo(square.right, square.top)
        ..lineTo(square.right, square.bottom)
        ..close());
      canvas.drawPath(
        hatch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = view.inks.rule,
      );
      canvas.restore();
      final double rowHeight = square.height / inputs;
      canvas.drawRect(
        Rect.fromLTWH(square.left, square.top + query * rowHeight, (query + 1) * square.width / inputs, rowHeight),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = view.inks.truth.withValues(alpha: 0.8 * alpha),
      );
      final bool chosen = view.head == h;
      canvas.drawRect(
        square.inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = chosen ? 1.6 : 0.8
          ..color = chosen ? view.inks.signal : view.inks.rule,
      );
      view.kit.draw(
        canvas,
        'head ${h + 1}',
        inked(view.kit.sans, 9, chosen ? view.inks.signal : view.inks.quiet),
        Offset(square.center.dx, square.bottom + 3),
        anchor: const Offset(0.5, 0),
      );
    }
  }

  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final ForwardMoment moment = ForwardMoment.at(view.trace.model.layers, frame.local);
    return moment.opening
        ? ForwardOpening(size, view, ForwardLayout(size, view))
            .hit(at, moment.progress * ForwardOpening.beats)
        : hit(size, view, at);
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final ForwardLayout layout = ForwardLayout(size, view);
    for (int h = 0; h < view.trace.model.heads; h++) {
      if (layout.head(h).inflate(6).contains(at)) {
        return FocusHead(view.head == h ? null : h);
      }
    }
    final int? i = layout.tokens.indexAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) =>
      ForwardLayout(size, view).tokens.indexAt(at, slack: 40);

  /// Which earlier position [query] reads most in [layer], and how much.
  static (int, double) strongest(LmView view, int layer, int query) {
    int best = 0;
    double most = -1;
    for (int key = 0; key <= query; key++) {
      final double w = view.head == null
          ? view.trace.meanAttention(view.checkpoint, layer, view.peptide, query, key)
          : view.trace.attention(view.checkpoint, layer, view.head!, view.peptide, query, key);
      if (w > most) {
        most = w;
        best = key;
      }
    }
    return (best, most);
  }

  static String position(LmView view, int i) =>
      i == 0 ? '<bos>' : '${view.focus.sequence[i - 1]}$i';

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final ForwardMoment moment = ForwardMoment.at(trace.model.layers, frame.local);
    final int layers = trace.model.layers;
    final int width = trace.model.width;
    if (moment.opening) {
      return ForwardOpening.caption(view, moment.progress * ForwardOpening.beats);
    }
    if (moment.norming) {
      return 'Final LayerNorm: the stream the output layer reads';
    }
    final String block = 'Block ${moment.block} of $layers';
    final double p = moment.progress;
    if (p < ForwardMoment.attendFrom) {
      return '$block · LayerNorm: each position to mean 0, variance 1';
    }
    if (p < ForwardMoment.addedAttention) {
      final int query = _query(view, moment);
      final (int key, double w) = strongest(view, moment.block - 1, query);
      final String heads = view.head == null ? '' : ', head ${view.head! + 1}';
      return '$block · attention$heads: ${position(view, query)} reads '
          '${position(view, key)} most, ${percent(w)}';
    }
    return '$block · feed-forward: $width → ${trace.model.feedForward} → $width, GELU';
  }

  @override
  String describe(LmView view, TrainingFrame frame) =>
      'Forward pass, step ${view.step}. ${caption(view, frame)}.';
}

/// Forward's canvas: the rail at the left; over the stream, the head maps
/// and the arcs' room; the stream, a column a position; and the tokens under
/// it.
final class ForwardLayout {
  ForwardLayout(Size size, LmView view) {
    final TrainingTrace trace = view.trace;
    const double railWidth = 62;
    const double left = 10 + railWidth + 12;
    final double right = size.width - 12;
    final double width = right - left;
    final int inputs = view.focus.inputs;
    final double cell = math.min(22, width / inputs);
    final double heads = trace.model.heads.toDouble();
    headSize = math.min(52, (width - (heads - 1) * 10) / heads);
    headsLeft = left + (width - (heads * headSize + (heads - 1) * 10)) / 2;
    final double arcsHeight = (size.height * 0.16).clamp(36.0, 96.0);
    final double above = headSize + 22 + arcsHeight + 4;
    final double below = 8 + cell + 12;
    // A row of the stream a number: as tall as the canvas allows, within reason.
    final double rowHeight =
        ((size.height - 16 - above - below) / trace.model.width).clamp(1.0, 2.6);
    final double content = above + rowHeight * trace.model.width + below;
    final double top = math.max(8, (size.height - content) / 2);
    headsTop = top;
    arcs = Rect.fromLTWH(left, top + headSize + 22, width, arcsHeight);
    final double gridTop = arcs.bottom + 4;
    final double gridBottom = gridTop + rowHeight * trace.model.width;
    tokens = TokenLayout(Rect.fromLTWH(left, gridBottom + 8, width, cell), inputs, most: 22);
    grid = Rect.fromLTRB(tokens.bounds.left, gridTop, tokens.bounds.right, gridBottom);
    rail = ModuleRail(Rect.fromLTWH(10, top, railWidth, content), trace.model.layers);
  }

  late final ModuleRail rail;
  late final TokenLayout tokens;
  late final double headSize;
  late final double headsLeft;
  late final double headsTop;
  late final Rect arcs;
  late final Rect grid;

  Rect head(int h) => Rect.fromLTWH(headsLeft + h * (headSize + 10), headsTop, headSize, headSize);
}
