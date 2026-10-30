import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'tokenise_scene.dart';

/// Shift: input x and next token y, one place apart, as `sequences.batches`
/// cuts the batch (`frame[:, :-1]` and `frame[:, 1:]`). It opens on
/// Tokenise's last frame: the vocabulary goes, and the matrix opens out into
/// its peptides again, each line of x with room under it. Then two moves of
/// whole lines, every peptide's at once: each line of x drops a copy into the
/// room under it, the same tokens; and the copy moves one place to the left,
/// so that under each place lies the token after it. `<bos>` leaves at the
/// left, never a target, and the token that leaves a second line's start
/// comes in at the first line's end, as text reflows. x lets go of the
/// frame's last place, which nothing reads; then the pairs whose target is
/// padding dim.
final class ShiftScene extends LmScene {
  const ShiftScene();

  // The opening: Tokenise's vocabulary and tags fade where they stand, the
  // matrix's rows open out into the peptides, and x is named.
  static const (double, double) _retire = (0.0, 0.5);
  static const (double, double) _unfold = (0.3, 1.3);
  static const (double, double) _labels = (0.9, 1.3);
  static const (double, double) _xNamed = (1.0, 1.4);

  // The copy comes down, y named as it lands; then it moves one place left,
  // and x's last place goes; then the padding dims.
  static const (double, double) _copy = (1.6, 2.3);
  static const (double, double) _yNamed = (1.9, 2.4);
  static const (double, double) _slide = (2.6, 3.6);
  static const (double, double) _lastOut = (2.9, 3.6);
  static const (double, double) _dim = (3.9, 4.5);

  /// Where the caption turns: to the copy, the move, and what it makes.
  static const double _copyCaption = 1.6;
  static const double _slideCaption = 2.6;
  static const double _madeCaption = 3.7;

  /// How far a pair whose target is padding dims: none of the loss is
  /// counted there.
  static const double dimmed = 0.65;

  static double _span(double at, (double, double) span) => through(at, span.$1, span.$2);

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
    final double dim = _span(beat, _dim);
    final double named = _span(beat, _labels);
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
      if (!focus || fade.focusX) {
        for (int k = 0; k < ids.length; k++) {
          double alpha = shown;
          if (k == ids.length - 1) {
            alpha *= 1 - _span(beat, _lastOut);
          } else if (k >= peptide.inputs) {
            alpha *= 1 - dimmed * dim;
          }
          _tile(canvas, view, xAt(p, k), ids, k, residues, alpha);
        }
      }
      _y(canvas, view, layout, p, beat, shown * fade.y, Offset(fade.ySlide, 0), dim);
    }
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

  /// [p]'s y: a copy of its frame coming down from x into the room under
  /// it, then moving one place left, a place's own token leaving it for the
  /// one after it; `<bos>` going off at the left, and the token that leaves
  /// the second line's start coming in at the first line's end. Moved, each
  /// slot under the place whose target it is.
  void _y(
    Canvas canvas,
    LmView view,
    ShiftLayout layout,
    int p,
    double beat,
    double alpha,
    Offset away,
    double dim,
  ) {
    final double copy = _span(beat, _copy);
    if (copy <= 0 || alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final List<int> ids = TokeniseScene.frameOf(trace, p);
    final int residues = trace.peptides[p].sequence.length;
    final double slide = _span(beat, _slide);
    if (slide >= 1) {
      for (int i = 0; i < ids.length - 1; i++) {
        final double shown = alpha * (i >= trace.peptides[p].inputs ? 1 - dimmed * dim : 1);
        _tile(canvas, view, layout.y(p, i).shift(away), ids, i + 1, residues, shown);
      }
      return;
    }
    final Offset down = Offset(0, (layout.tileHeight + ShiftLayout.pairGap) * copy);
    final Offset left = Offset(-layout.tileWidth * slide, 0);
    canvas.save();
    if (slide > 0) {
      // Moving, a line keeps to its columns: what leaves it goes off its
      // edge, clear of the heads.
      canvas.clipRect(Rect.fromLTRB(layout.left, -1e4, layout.columnsRight, 1e4));
    }
    for (int k = 0; k < ids.length; k++) {
      final Rect at = layout.x(p, k).shift(down + left + away);
      // A line's first token goes off its left end.
      final bool first = k == 0 || k == layout.firstLine;
      _tile(canvas, view, at, ids, k, residues, alpha * (first ? 1 - slide : 1));
      if (k == layout.firstLine && slide > 0) {
        // And comes in at the end of the line before, as text reflows.
        final Rect end = layout.x(p, k - 1).shift(Offset(layout.tileWidth, 0) + down + left + away);
        _tile(canvas, view, end, ids, k, residues, alpha * slide);
      }
    }
    canvas.restore();
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
    if (beat < _copyCaption) {
      return 'Input x: the batch the model reads';
    }
    if (beat < _slideCaption) {
      return 'Next token y starts as a copy of x';
    }
    if (beat < _madeCaption) {
      return 'One place to the left: under each place, the token after it';
    }
    final int padding = trace.peptides.length * trace.width - trace.targetCount;
    final String ignored = switch (padding) {
      0 => '',
      1 => ', one pad ignored',
      _ => ', ${grouped(padding)} pads ignored',
    };
    return 'Each place learns the token after it: ${grouped(trace.targetCount)} targets$ignored';
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
            peptides * (label + 2 * pairGap + _lineGap) -
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
      final double fits = (room - peptides * (label + pairGap) - (peptides - 1) * _leastGap) / (2 * peptides);
      tileHeight = math.max(
        3,
        math.min(math.max(tileWidth, math.min(16, math.max(numbered, tileWidth * 1.5))), fits),
      );
    }
    lines = firstLine < frame ? 2 : 1;
    block = label + lines * (2 * tileHeight + pairGap) + (lines - 1) * _lineGap;
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
  static const double pairGap = 3;
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

  /// The right edge of a line's last column.
  double get columnsRight => left + (frame - (firstLine < frame ? firstLine : 0)) * tileWidth;

  double rowTop(int peptide) => firstRow + peptide * rowPitch;

  /// The top of [peptide]'s [line], of x ([kind] 0) or of y (1).
  double lineTop(int peptide, int line, int kind) =>
      rowTop(peptide) + label + line * (2 * tileHeight + pairGap + _lineGap) + kind * (tileHeight + pairGap);

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
  Rect y(int peptide, int i) => x(peptide, i).shift(Offset(0, tileHeight + pairGap));

  /// The card under [peptide] in focus: round its name and its lines.
  Rect card(int peptide) =>
      Rect.fromLTRB(cardLeft, rowTop(peptide) - 4, right + 6, rowTop(peptide) + block + 5);

  /// Where the head of [peptide]'s [line] of x ([kind] 0) or y (1) stands.
  Offset head(int peptide, int line, int kind) =>
      Offset(headCentre, lineTop(peptide, line, kind) + tileHeight / 2);
}
