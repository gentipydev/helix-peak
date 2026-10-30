import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'tokenise_scene.dart';

/// Shift: input x and next token y, one place apart, as `sequences.batches`
/// cuts the batch (`frame[:, :-1]` and `frame[:, 1:]`). It opens on
/// Tokenise's last frame: the vocabulary goes, and the matrix opens out into
/// its peptides again, each line of x with room under it for its line of y.
/// Then, every peptide at once, what a place has not read lies under a veil,
/// and the first token under it, the one after the place, lifts out and
/// drops into y under the place: the token it learns, which it cannot see.
/// The first places go one at a time, the rest in a wave; then every pair
/// lights at once, as one pass learns them all, and the pairs whose target is
/// padding dim.
final class ShiftScene extends LmScene {
  const ShiftScene();

  // The opening: Tokenise's vocabulary and tags fade where they stand, the
  // matrix's rows open out into the peptides, and x is named.
  static const (double, double) _retire = (0.0, 0.5);
  static const (double, double) _unfold = (0.3, 1.3);
  static const (double, double) _labels = (0.9, 1.3);
  static const (double, double) _xNamed = (1.0, 1.4);

  // The places: the veil comes down over all of x but <bos>; the first
  // places take a beat each, the rest go in a wave; y is named as its first
  // token lands.
  static const (double, double) _veilIn = (1.3, 1.55);
  static const double _placesFrom = 1.5;
  static const int _slowPlaces = 3;
  static const double _slowTurn = 1.0;
  static const (double, double) _yNamed = (2.0, 2.4);
  static const double _sweepTo = 6.4;
  static const double _quickTurn = 0.35;

  // The veil lifts, and the frame's last place, which x leaves out, with it.
  static const (double, double) _veilOut = (6.4, 6.7);

  // Every pair at once; then the pairs whose target is padding dim.
  static const (double, double) _pulse = (6.6, 7.3);
  static const (double, double) _dim = (7.0, 7.6);

  // A place's turn: the token after it lifts out of the veil and flies down
  // under the place, and the veil steps past it.
  static const (double, double) _lift = (0.1, 0.3);
  static const (double, double) _fly = (0.25, 0.65);
  static const (double, double) _step = (0.7, 0.9);

  /// How far a pair whose target is padding dims: none of the loss is
  /// counted there.
  static const double dimmed = 0.65;

  /// How far a tile under the veil fades.
  static const double _veiled = 0.65;

  static double _span(double at, (double, double) span) => through(at, span.$1, span.$2);

  static int _slow(TrainingTrace trace) => math.min(_slowPlaces, trace.width);

  /// Where place [i]'s turn starts, in beats, and how long it takes.
  static (double, double) _turn(TrainingTrace trace, int i) {
    final int slow = _slow(trace);
    if (i < slow) {
      return (_placesFrom + i * _slowTurn, _slowTurn);
    }
    final double from = _placesFrom + slow * _slowTurn;
    final int quick = trace.width - 1 - slow;
    return (
      from + (quick <= 0 ? 0 : (i - slow) / quick * (_sweepTo - _quickTurn - from)),
      _quickTurn,
    );
  }

  /// How far through its turn place [i] is at [beat], from 0 to 1.
  static double _into(TrainingTrace trace, int i, double beat) {
    final (double start, double length) = _turn(trace, i);
    return ((beat - start) / length).clamp(0.0, 1.0);
  }

  /// Whether place [i]'s target has landed in y.
  static bool _landed(TrainingTrace trace, int i, double beat) => _into(trace, i, beat) >= _fly.$2;

  /// How many places of x have been read, the veil's left edge: `<bos>` at
  /// first, then each place's next token once it has landed under it. The
  /// frame's last place is never read: x leaves it out.
  static double _edge(TrainingTrace trace, double beat) {
    double edge = 1;
    for (int i = 0; i < trace.width - 1; i++) {
      edge += _span(_into(trace, i, beat), _step);
    }
    return edge;
  }

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * LmStage.shift.beats, const ShiftFade());

  /// The stage's last frame, with [fade] leaving out or fading what the
  /// stage after it draws itself or retires: Forward opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view, ShiftFade fade) =>
      _paint(canvas, size, view, LmStage.shift.beats.toDouble(), fade);

  void _paint(Canvas canvas, Size size, LmView view, double beat, ShiftFade fade) {
    final TrainingTrace trace = view.trace;
    final ShiftLayout layout = ShiftLayout(size, view);
    final TokeniseEnd end = TokeniseEnd(size, view);
    final double unfold = _span(beat, _unfold);
    final double veil = _span(beat, _veilIn) * (1 - _span(beat, _veilOut));
    final double edge = _edge(trace, beat);
    final double dim = _span(beat, _dim);
    final double named = _span(beat, _labels);
    final Offset slide = Offset(fade.ySlide, 0);
    Rect xAt(int p, int k) => unfold >= 1 ? layout.x(p, k) : Rect.lerp(end.place(p, k), layout.x(p, k), unfold)!;

    for (int p = 0; p < trace.peptides.length; p++) {
      final bool focus = p == view.peptide;
      final double shown = focus ? 1 : fade.others;
      if (shown <= 0) {
        continue;
      }
      final TracePeptide peptide = trace.peptides[p];
      final List<int> ids = TokeniseScene.frameOf(trace, p);
      final int residues = peptide.sequence.length;
      if (focus && fade.card > 0) {
        final Rect card = unfold >= 1 ? layout.card(p) : Rect.lerp(end.card(p), layout.card(p), unfold)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(card, const Radius.circular(6)),
          Paint()..color = _ink(view.inks.card, fade.card),
        );
      }
      final double label = named * (focus ? fade.chrome : shown);
      if (label > 0) {
        view.kit.draw(
          canvas,
          '${peptide.source.label} · $residues aa',
          inked(view.kit.sans, 10, focus ? view.inks.ink : view.inks.quiet, alpha: label),
          Offset(layout.left, layout.rowTop(p)),
        );
      }
      _bands(canvas, view, layout, p, beat);
      if (!focus || fade.focusX) {
        for (int k = 0; k < ids.length; k++) {
          double alpha = shown * (1 - _veiled * veil * (k + 1 - edge).clamp(0.0, 1.0));
          if (k == ids.length - 1) {
            alpha *= 1 - _span(beat, _veilOut);
          } else if (k >= peptide.inputs) {
            alpha *= 1 - dimmed * dim;
          }
          _tile(canvas, view, xAt(p, k), ids, k, residues, alpha);
        }
      }
      if (veil > 0) {
        _veil(canvas, view, layout, p, edge, veil * shown);
      }
      for (int i = 0; i < ids.length - 1; i++) {
        if (!_landed(trace, i, beat)) {
          continue;
        }
        final double alpha = shown * fade.y * (i >= peptide.inputs ? 1 - dimmed * dim : 1);
        _tile(canvas, view, layout.y(p, i).shift(slide), ids, i + 1, residues, alpha);
      }
    }
    _flights(canvas, view, layout, beat);
    _boxes(canvas, view, layout, beat);
    _names(canvas, view, layout, beat, fade);

    // What Tokenise retires, fading where it stands, drawn as Tokenise drew
    // it, over its rows.
    final double retiring = 1 - _span(beat, _retire);
    if (retiring > 0) {
      _faded(
        canvas,
        size,
        view,
        retiring,
        () => const TokeniseScene().paintEnd(canvas, size, view, const TokeniseFade(rows: false)),
      );
    }
  }

  /// [color] at [alpha] of its own.
  static Color _ink(Color color, double alpha) => alpha >= 1 ? color : color.withValues(alpha: color.a * alpha);

  /// [draw], at [alpha] as a whole.
  static void _faded(Canvas canvas, Size size, LmView view, double alpha, VoidCallback draw) {
    if (alpha >= 1) {
      draw();
      return;
    }
    // A layer takes only its paint's alpha.
    canvas.saveLayer(Offset.zero & size, Paint()..color = view.inks.ground.withValues(alpha: alpha));
    draw();
    canvas.restore();
  }

  /// Place [k] of a frame as Tokenise draws it: an end or padding as a
  /// token, a residue as its id.
  static void _tile(Canvas canvas, LmView view, Rect rect, List<int> ids, int k, int residues, double alpha) {
    if (alpha <= 0) {
      return;
    }
    if (k == 0 || k > residues) {
      drawToken(canvas, view, rect, ids[k], alpha: alpha);
    } else {
      drawIdTile(canvas, view, rect, ids[k], alpha: alpha);
    }
  }

  /// A tile's outline, in [color].
  static void _box(Canvas canvas, Rect rect, Color color, double alpha, double width) {
    final Rect tile = rect.deflate(math.min(1.0, rect.width * 0.08));
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.18)).inflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: alpha),
    );
  }

  /// A soft band behind the place whose turn it is while the places go one
  /// at a time, round x's tile and the slot under it in y. The wave after
  /// them is its flights alone.
  void _bands(Canvas canvas, LmView view, ShiftLayout layout, int p, double beat) {
    final TrainingTrace trace = view.trace;
    for (int i = 0; i < _slow(trace); i++) {
      final double q = _into(trace, i, beat);
      if (q <= 0 || q >= 1) {
        continue;
      }
      final double strength = through(q, 0, 0.1) * (1 - through(q, 0.9, 1));
      final Rect x = layout.x(p, i);
      canvas.drawRect(
        Rect.fromLTRB(x.left, x.top - 2, x.right, layout.y(p, i).bottom + 2),
        Paint()..color = view.inks.signal.withValues(alpha: 0.12 * strength),
      );
    }
  }

  /// The veil over what [p]'s places have not read: x's tiles from [edge]
  /// on, hatched as Forward's head maps hatch what a position never reads;
  /// the tile it is stepping past, part way.
  void _veil(Canvas canvas, LmView view, ShiftLayout layout, int p, double edge, double alpha) {
    final int last = layout.frame - 1;
    final int full = edge.ceil();
    void hatch(Rect rect, double strength) {
      if (strength <= 0) {
        return;
      }
      final Path lines = Path();
      for (double d = 4; d < rect.width + rect.height; d += 5) {
        lines
          ..moveTo(rect.left + d, rect.top)
          ..lineTo(rect.left + d - rect.height, rect.bottom);
      }
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawPath(
        lines,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = view.inks.rule.withValues(alpha: view.inks.rule.a * strength),
      );
      canvas.restore();
    }

    // A run a line: the veil is one piece along each.
    for (final (int from, int to) in <(int, int)>[
      (0, math.min(layout.firstLine, layout.frame) - 1),
      if (layout.firstLine < layout.frame) (layout.firstLine, last),
    ]) {
      final int start = math.max(from, full);
      if (start <= to) {
        hatch(Rect.fromLTRB(layout.x(p, start).left, layout.x(p, start).top, layout.x(p, to).right, layout.x(p, to).bottom), alpha);
      }
    }
    final int partial = edge.floor();
    if (partial < full && partial <= last) {
      hatch(layout.x(p, partial), alpha * (partial + 1 - edge));
    }
  }

  /// Each place's next token in flight, every peptide's: lifted out of the
  /// veil, then down and to the left, into y under the place.
  void _flights(Canvas canvas, LmView view, ShiftLayout layout, double beat) {
    final TrainingTrace trace = view.trace;
    for (int i = 0; i < trace.width; i++) {
      final double q = _into(trace, i, beat);
      if (q <= _lift.$1 || q >= _fly.$2) {
        continue;
      }
      final double lift = _span(q, _lift);
      final double fly = _span(q, _fly);
      for (int p = 0; p < trace.peptides.length; p++) {
        final List<int> ids = TokeniseScene.frameOf(trace, p);
        final Rect from = layout.x(p, i + 1);
        final Rect to = layout.y(p, i);
        final Offset a = from.center - Offset(0, from.height * 0.15 * lift);
        final Offset b = to.center;
        // Bowed below the straight way: it drops, then slides in.
        final Offset c = Offset(a.dx + (b.dx - a.dx) * 0.2, a.dy + (b.dy - a.dy) * 0.8);
        final double s = fly;
        final Offset at = a * ((1 - s) * (1 - s)) + c * (2 * (1 - s) * s) + b * (s * s);
        final double grow = 1 + 0.15 * lift * (1 - fly);
        _tile(
          canvas,
          view,
          Rect.fromCenter(center: at, width: from.width * grow, height: from.height * grow),
          ids,
          i + 1,
          trace.peptides[p].sequence.length,
          through(q, _lift.$1, _lift.$1 + 0.05),
        );
      }
    }
  }

  /// The peptide in focus's pair while its place goes one at a time: x's
  /// tile in the accent, y's in the tracer once it has landed. Then every
  /// pair at once, every peptide's.
  void _boxes(Canvas canvas, LmView view, ShiftLayout layout, double beat) {
    final TrainingTrace trace = view.trace;
    final int p = view.peptide;
    for (int i = 0; i < _slow(trace); i++) {
      final double q = _into(trace, i, beat);
      if (q <= 0 || q >= 1) {
        continue;
      }
      final double shown = through(q, 0, 0.1) * (1 - through(q, 0.9, 1));
      _box(canvas, layout.x(p, i), view.inks.signal, shown, 1.4);
      if (q >= _fly.$2) {
        _box(canvas, layout.y(p, i), view.inks.truth, shown, 1.4);
      }
    }
    final double pulse = math.sin(math.pi * _span(beat, _pulse));
    if (pulse < 1e-3) {
      return;
    }
    for (int each = 0; each < trace.peptides.length; each++) {
      for (int i = 0; i < trace.peptides[each].inputs; i++) {
        _box(canvas, layout.x(each, i), view.inks.signal, 0.8 * pulse, 1);
        _box(canvas, layout.y(each, i), view.inks.truth, 0.8 * pulse, 1);
      }
    }
  }

  /// x and y named: on a tag over the peptides and one under them, and at
  /// the head of each of their lines.
  void _names(Canvas canvas, LmView view, ShiftLayout layout, double beat, ShiftFade fade) {
    final TrainingTrace trace = view.trace;
    final double x = _span(beat, _xNamed) * fade.chrome;
    final double y = _span(beat, _yNamed) * fade.chrome;
    if (x > 0) {
      drawTag(canvas, view, 'input x', Offset(layout.tagStart, layout.xTag), alpha: x);
    }
    if (y > 0) {
      drawTag(canvas, view, 'next token y', Offset(layout.tagStart, layout.yTag), alpha: y);
    }
    for (int p = 0; p < trace.peptides.length; p++) {
      final double shown = p == view.peptide ? 1 : fade.others;
      for (int line = 0; line < layout.lines; line++) {
        for (final (String name, int kind, double alpha) in <(String, int, double)>[('x', 0, x), ('y', 1, y)]) {
          if (alpha * shown <= 0) {
            continue;
          }
          view.kit.draw(
            canvas,
            name,
            inked(view.kit.mono, 9, view.inks.quiet, alpha: alpha * shown),
            layout.head(p, line, kind),
            anchor: const Offset(0.5, 0.5),
          );
        }
      }
    }
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) => _focusAt(size, view, at, 1);

  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) =>
      _focusAt(size, view, at, _span(frame.local * LmStage.shift.beats, _unfold).roundToDouble());

  /// The peptide whose card, or whose row of the matrix, lies under [at].
  LmHit? _focusAt(Size size, LmView view, Offset at, double unfold) {
    final ShiftLayout layout = ShiftLayout(size, view);
    final TokeniseEnd end = TokeniseEnd(size, view);
    for (int p = 0; p < view.trace.peptides.length; p++) {
      final Rect card = unfold >= 1 ? layout.card(p) : end.card(p);
      if (at.dy >= card.top && at.dy < card.bottom + 1) {
        return FocusPeptide(p);
      }
    }
    return null;
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * LmStage.shift.beats;
    final int p = view.peptide;
    String learns(int i) => 'After ${readSoFar(trace, p, i)}, place $i learns '
        '${trace.token(trace.targetAt(p, i))}, which it cannot see';
    if (beat < _placesFrom) {
      return 'Under each place of input x goes the token after it: next token y';
    }
    final int slow = _slow(trace);
    if (beat < _placesFrom + slow * _slowTurn) {
      return learns(math.min(slow - 1, ((beat - _placesFrom) / _slowTurn).floor()));
    }
    if (beat < _pulse.$1) {
      return learns(view.focus.inputs - 1);
    }
    final int padding = trace.peptides.length * trace.width - trace.targetCount;
    final String ignored = switch (padding) {
      0 => '',
      1 => ', one pad ignored',
      _ => ', ${grouped(padding)} pads ignored',
    };
    return 'Every place learns at once: ${grouped(trace.targetCount)} targets$ignored';
  }

  @override
  String describe(LmView view, TrainingFrame frame) {
    final TracePeptide focus = view.focus;
    return 'Shift. ${caption(view, frame)}. In focus, ${focus.source.label}, '
        '${focus.sequence.length} residues.';
  }
}

/// What Shift's last frame leaves out or fades, for the stage that opens on
/// it: the row of x in focus, which it draws itself, and what it retires. By
/// default, the frame as Shift draws it.
@immutable
final class ShiftFade {
  const ShiftFade({
    this.focusX = true,
    this.others = 1,
    this.y = 1,
    this.ySlide = 0,
    this.chrome = 1,
    this.card = 1,
  });

  /// Whether the peptide in focus's x is drawn.
  final bool focusX;

  /// The other peptides.
  final double others;

  /// y, and how far it has gone off to the right.
  final double y;
  final double ySlide;

  /// The tags, the lines' heads and the label of the peptide in focus.
  final double chrome;

  /// The card under the peptide in focus.
  final double card;
}

/// Top to bottom: the input x tag; each peptide's name and lines, a line of
/// x with its line of y under it, folded onto two pairs of lines where that
/// leaves its tiles room for their numbers, else on one; the next token y
/// tag. The tiles are as large as the width and the height both allow, and
/// the whole is centred. Each line's head, x or y, stands at its left inside
/// the card.
final class ShiftLayout {
  ShiftLayout(Size size, LmView view) : right = size.width - 16 {
    final TrainingTrace trace = view.trace;
    final int peptides = trace.peptides.length;
    frame = trace.width + 1;
    final double width = right - left;
    final double tag = tagSize(view, 'input x').height;
    final double fixed = 2 * (_edge + tag + _tagGap);
    final double room = math.max(0, size.height - fixed);
    // Folded once, the same place for every peptide, as Tokenise folds it:
    // a pair stays in its column.
    final double tallest = (room -
            peptides * (label + 2 * _pairGap + _lineGap) -
            (peptides - 1) * _leastGap) /
        (4 * peptides);
    final double folded = math.min(math.min(22, width / (frame - frame ~/ 2)), tallest);
    if (folded >= idNumbered) {
      firstLine = frame ~/ 2;
      tileWidth = folded;
      tileHeight = folded;
    } else {
      // Where two pairs of lines cannot number their tiles, one: every place
      // across the width, each as tall as a number needs once the tile is
      // drawn inset, and as the height allows.
      firstLine = frame;
      tileWidth = math.min(16, width / frame);
      final double numbered = idNumbered + 2 * math.min(1.0, tileWidth * 0.08) + 0.01;
      final double fits = (room - peptides * (label + _pairGap) - (peptides - 1) * _leastGap) / (2 * peptides);
      tileHeight = math.max(
        3,
        math.min(math.max(tileWidth, math.min(16, math.max(numbered, tileWidth * 1.5))), fits),
      );
    }
    lines = firstLine < frame ? 2 : 1;
    block = label + lines * (2 * tileHeight + _pairGap) + (lines - 1) * _lineGap;
    final double gap =
        peptides < 2 ? 0 : ((room - peptides * block) / (peptides - 1)).clamp(_leastGap, 22.0);
    rowPitch = block + gap;
    final double rows = peptides * block + (peptides - 1) * gap;
    final double top = math.max(0, (size.height - fixed - rows) / 2);
    xTag = top + _edge;
    firstRow = xTag + tag + _tagGap;
    yTag = firstRow + rows + _tagGap;
  }

  /// From the canvas's edge to a tag, and from a tag to the peptides.
  static const double _edge = 6;
  static const double _tagGap = 8;

  /// Between a line of x and its line of y, between a peptide's two pairs
  /// of lines, and the least between two peptides.
  static const double _pairGap = 3;
  static const double _lineGap = 7;
  static const double _leastGap = 5;

  /// A peptide's name.
  static const double label = 14;

  /// The card's left edge, where the tags start too, as Tokenise's; the
  /// lines' heads, and the tiles after them.
  final double cardLeft = 14;
  final double headCentre = 22;
  final double left = 30;
  final double right;

  /// A frame's places: `<bos>`, the residues, `<eos>` and padding.
  late final int frame;

  /// How many places the first line holds: all of them where it is not
  /// folded; and how many lines of x a peptide has.
  late final int firstLine;
  late final int lines;

  late final double tileWidth;
  late final double tileHeight;

  /// A peptide's name and lines, and from one peptide's name to the next.
  late final double block;
  late final double rowPitch;

  late final double xTag;
  late final double firstRow;
  late final double yTag;

  double get tagStart => cardLeft;

  double rowTop(int peptide) => firstRow + peptide * rowPitch;

  /// The top of [peptide]'s [line], of x ([kind] 0) or of y (1).
  double lineTop(int peptide, int line, int kind) =>
      rowTop(peptide) + label + line * (2 * tileHeight + _pairGap + _lineGap) + kind * (tileHeight + _pairGap);

  /// Place [k] of [peptide]'s frame, in x.
  Rect x(int peptide, int k) {
    final int line = k < firstLine ? 0 : 1;
    return Rect.fromLTWH(
      left + (k - line * firstLine) * tileWidth,
      lineTop(peptide, line, 0),
      tileWidth,
      tileHeight,
    );
  }

  /// Place [i]'s target in y, under its place in x.
  Rect y(int peptide, int i) => x(peptide, i).shift(Offset(0, tileHeight + _pairGap));

  /// The card under [peptide] in focus: round its name and its lines.
  Rect card(int peptide) =>
      Rect.fromLTRB(cardLeft, rowTop(peptide) - 4, right + 6, rowTop(peptide) + block + 5);

  /// Where the head of [peptide]'s [line] of x ([kind] 0) or y (1) stands.
  Offset head(int peptide, int line, int kind) =>
      Offset(headCentre, lineTop(peptide, line, kind) + tileHeight / 2);
}
