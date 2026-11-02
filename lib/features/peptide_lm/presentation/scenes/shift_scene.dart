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
/// its peptides again, input x, what the model reads. Then two moves: a copy
/// of x lifts off it as a shadow and falls, whole, to its place under x,
/// target y, the same peptides and tokens; and every line of the copy
/// moves one place to the left, so that each place of y holds the token after
/// the same place of x. `<bos>` leaves at the left, never a target, and the
/// token that leaves a second line's start comes in at the first line's end,
/// as text reflows. Then the pairs whose target is padding dim.
final class ShiftScene extends LmScene {
  const ShiftScene();

  // The opening: Tokenise's vocabulary and tags fade where they stand, the
  // matrix's rows open out into the peptides, and x is named, letting go of
  // the frame's last place, which nothing reads.
  static const (double, double) _retire = (0.0, 0.5);
  static const (double, double) _unfold = (0.3, 1.3);
  static const (double, double) _labels = (0.9, 1.3);
  static const (double, double) _xNamed = (1.0, 1.4);
  static const (double, double) _lastOut = (0.9, 1.4);

  // The copy of the peptides lifts off x as its shadow, falls to its place
  // under x, solid as it settles, and y is named as it lands; then it moves
  // one place left; then the padding dims.
  static const (double, double) _lift = (1.5, 1.85);
  static const (double, double) _fall = (1.85, 2.75);
  static const (double, double) _land = (2.4, 2.75);
  static const (double, double) _yNamed = (2.45, 2.85);
  static const (double, double) _slide = (2.9, 3.9);
  static const (double, double) _dim = (4.1, 4.7);

  /// Where the caption turns: to the copy, the move, and what it makes.
  static const double _copyCaption = 1.5;
  static const double _slideCaption = 2.9;
  static const double _madeCaption = 4.0;

  /// How far a pair whose target is padding dims: none of the loss is
  /// counted there.
  static const double dimmed = 0.65;

  /// How far under x the shadow lifts, how strong it is over x, and how
  /// strong once it has come out under x, until it lands.
  static const double _shadowDrop = 5;
  static const double _shadow = 0.2;
  static const double _ghost = 0.6;

  /// How large an id is drawn in its tile, of the tile's height: larger
  /// than Tokenise draws it, the room the stage has being its tiles'.
  static const double numberScale = 0.62;

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
      final double label = named * (focus ? fade.chrome * fade.focusLabel : shown);
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
    }
    // The copy, over every line of x as it falls past them, faded as one
    // picture until it lands: a faint shadow over x, stronger once it has
    // come out under x's last line.
    final double lift = _span(beat, _lift);
    if (lift > 0) {
      void copies() {
        for (int p = 0; p < trace.peptides.length; p++) {
          final double shown = p == view.peptide ? 1 : fade.others;
          if (shown > 0) {
            _y(canvas, view, layout, p, beat, lift, shown * fade.y, Offset(fade.ySlide, 0), dim, fade);
          }
        }
      }

      final double out = lift * (_ghost + (1 - _ghost) * _span(beat, _land));
      if (_span(beat, _fall) >= 1) {
        _faded(canvas, size, view, out, copies);
      } else {
        final double under = layout.card(trace.peptides.length - 1).bottom;
        for (final (Rect part, double alpha) in <(Rect, double)>[
          (Rect.fromLTRB(0, 0, size.width, under), lift * _shadow),
          (Rect.fromLTRB(0, under, size.width, size.height), out),
        ]) {
          canvas.save();
          canvas.clipRect(part);
          _faded(canvas, size, view, alpha, copies);
          canvas.restore();
        }
      }
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

  /// [p]'s y: a copy of its peptide in x, lifting off x as its shadow
  /// ([lift] of the way) and falling to its place under x, then each line
  /// moving one place left, a place's own token leaving it for the one after
  /// it; `<bos>` going off at the left, and the token that leaves the second
  /// line's start coming in at the first line's end. Moved, each slot under
  /// the place of x whose target it is.
  void _y(
    Canvas canvas,
    LmView view,
    ShiftLayout layout,
    int p,
    double beat,
    double lift,
    double shown,
    Offset away,
    double dim,
    ShiftFade fade,
  ) {
    final TrainingTrace trace = view.trace;
    final TracePeptide peptide = trace.peptides[p];
    final bool focus = p == view.peptide;
    final List<int> ids = TokeniseScene.frameOf(trace, p);
    final int residues = peptide.sequence.length;
    // From x's place, a little way down as it lifts, then the rest of the
    // way to y's.
    final double fall = _span(beat, _fall);
    final double down = _shadowDrop * lift + (layout.drop - _shadowDrop) * fall;
    final Offset come = Offset(0, down - layout.drop) + away;
    if (focus && fade.card > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.yCard(p).shift(come), const Radius.circular(6)),
        Paint()..color = _ink(view.inks.card, fade.card * shown),
      );
    }
    view.kit.draw(
      canvas,
      '${peptide.source.label} · $residues aa',
      inked(view.kit.sans, 10, focus ? view.inks.ink : view.inks.quiet, alpha: shown * (focus ? fade.chrome : 1)),
      Offset(layout.left, layout.yRowTop(p)) + come,
    );
    final double slide = _span(beat, _slide);
    if (slide >= 1) {
      for (int i = 0; i < ids.length - 1; i++) {
        final double padded = i >= peptide.inputs ? 1 - dimmed * dim : 1;
        _tile(canvas, view, layout.y(p, i).shift(come), ids, i + 1, residues, shown * padded);
      }
      return;
    }
    final Offset left = Offset(-layout.step * slide, 0);
    canvas.save();
    if (slide > 0) {
      // Moving, a line keeps to its columns: what leaves it goes off its
      // edge.
      canvas.clipRect(Rect.fromLTRB(layout.left, -1e4, layout.columnsRight, 1e4));
    }
    for (int k = 0; k < ids.length; k++) {
      final Rect at = layout.y(p, k).shift(left + come);
      // A line's first token goes off its left end; the frame's last place,
      // which x let go of, comes back as the copy falls.
      final bool first = k == 0 || k == layout.firstLine;
      final double back = k == ids.length - 1 ? fall : 1;
      _tile(canvas, view, at, ids, k, residues, shown * back * (first ? 1 - slide : 1));
      if (k == layout.firstLine && slide > 0) {
        // And comes in at the end of the line before, as text reflows.
        final Rect end = layout.y(p, k - 1).shift(Offset(layout.step, 0) + left + come);
        _tile(canvas, view, end, ids, k, residues, shown * slide);
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
      drawIdTile(canvas, view, rect, ids[k], alpha: alpha, numberScale: numberScale);
    }
  }

  /// x and y named, each on a tag over its peptides, and what each is for
  /// beside it: the model reads x; y is the answer key its guesses are
  /// graded against, which never goes in.
  void _names(Canvas canvas, LmView view, ShiftLayout layout, double beat, ShiftFade fade) {
    final double x = _span(beat, _xNamed) * fade.chrome;
    final double y = _span(beat, _yNamed) * fade.chrome;
    for (final (String name, List<String> role, double top, double alpha) in <(String, List<String>, double, double)>[
      ('input x', <String>['what the model reads'], layout.xTag, x),
      ('target y', <String>['the answer key: what each place should predict', 'the answer key'], layout.yTag, y),
    ]) {
      if (alpha <= 0) {
        continue;
      }
      final Rect plate = drawTag(canvas, view, name, Offset(layout.tagStart, top), alpha: alpha);
      drawRole(canvas, view, role, plate, layout.right + 6, alpha);
    }
  }

  /// What a tag's group is for, beside its [plate]: the first of [texts]
  /// that fits, as far as [end], in the quiet ink: in the plate's face, else
  /// a size smaller; the shorter ones for a narrow phone.
  static void drawRole(Canvas canvas, LmView view, List<String> texts, Rect plate, double end, double alpha) {
    final double room = end - plate.right - 8;
    final double size = view.kit.label.fontSize ?? 11;
    for (final String text in texts) {
      for (final double points in <double>[size, size - 1]) {
        final TextStyle style = inked(view.kit.label, points, view.inks.quiet, alpha: alpha);
        if (view.kit.layout(text, style).width <= room) {
          view.kit.draw(canvas, text, style, Offset(plate.right + 8, plate.center.dy), anchor: const Offset(0, 0.5));
          return;
        }
      }
    }
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) => _focusAt(size, view, at, 1);

  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) =>
      _focusAt(size, view, at, _span(frame.local * LmStage.shift.beats, _unfold).roundToDouble());

  /// The peptide whose row of the matrix, or whose card in x or y, lies
  /// under [at].
  LmHit? _focusAt(Size size, LmView view, Offset at, double unfold) {
    final ShiftLayout layout = ShiftLayout(size, view);
    final TokeniseEnd end = TokeniseEnd(size, view);
    for (int p = 0; p < view.trace.peptides.length; p++) {
      for (final Rect card in unfold >= 1 ? <Rect>[layout.card(p), layout.yCard(p)] : <Rect>[end.card(p)]) {
        if (at.dy >= card.top && at.dy < card.bottom + 1) {
          return FocusPeptide(p);
        }
      }
    }
    return null;
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * LmStage.shift.beats;
    if (beat < _copyCaption) {
      return 'Input x: each frame less its last place, '
          '${trace.peptides.length} × ${trace.width} tokens';
    }
    if (beat < _slideCaption) {
      return 'Target y starts as a copy of the same peptides';
    }
    if (beat < _madeCaption) {
      return "One place to the left: each place's answer is the token after it";
    }
    return 'Only x goes in; Loss grades each guess against y: ${grouped(trace.targetCount)} targets';
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
    this.focusLabel = 1,
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

  /// The name of the peptide in focus, apart from [chrome]: a stage that
  /// carries it on draws it itself.
  final double focusLabel;
}

/// Top to bottom: the input x tag and the peptides, each its name and its
/// lines, folded onto two where that leaves its tiles room for their
/// numbers, else on one; then, set well apart, the next token y tag and the
/// peptides again, in the same columns. The tiles are as large as the width
/// and the height both allow, their columns spread across the width, and
/// the whole is centred.
final class ShiftLayout {
  ShiftLayout(Size size, LmView view) : right = size.width - 16 {
    final TrainingTrace trace = view.trace;
    final int peptides = trace.peptides.length;
    final int blocks = 2 * peptides;
    frame = trace.width + 1;
    final double width = right - left;
    final double tag = tagSize(view, 'input x').height;
    final double fixed = 2 * _edge + 2 * (tag + _tagGap) + _groupGap;
    final double room = math.max(0, size.height - fixed);
    // Folded once, the same place for every peptide, as Tokenise folds it: a
    // place keeps its column in x and in y.
    final double tallest =
        (room - blocks * (label + _lineGap) - (blocks - 2) * _leastGap) / (2 * blocks);
    // A tile as wide as its column and as tall as the height allows, never
    // taller than wide: next to no room between tiles.
    final double column = math.min(22, width / (frame - frame ~/ 2));
    final double folded = math.min(column, tallest);
    if (folded - 2 * _inset(column) >= idNumbered) {
      firstLine = frame ~/ 2;
      tileWidth = math.min(column, folded * 1.6);
      tileHeight = folded;
    } else {
      // Where two lines cannot number their tiles, one: every place across
      // the width, each as tall as a number needs once the tile is drawn
      // inset, and as the height allows.
      firstLine = frame;
      tileWidth = math.min(16, width / frame);
      final double numbered = idNumbered + 2 * _inset(tileWidth) + 0.01;
      final double fits = (room - blocks * label - (blocks - 2) * _leastGap) / blocks;
      tileHeight = math.max(
        3,
        math.min(math.max(tileWidth, math.min(16, math.max(numbered, tileWidth * 1.5))), fits),
      );
    }
    lines = firstLine < frame ? 2 : 1;
    // The columns spread from the left edge to the right, the tiles with room
    // between them where the height keeps them small; a little room at most.
    final int columns = frame - (lines == 2 ? firstLine : 0);
    step = columns < 2 ? tileWidth : math.min((width - tileWidth) / (columns - 1), tileWidth * 1.6);
    columnsRight = left + (columns - 1) * step + tileWidth;
    block = label + lines * tileHeight + (lines - 1) * _lineGap;
    final double gap =
        peptides < 2 ? 0 : ((room - blocks * block) / (blocks - 2)).clamp(_leastGap, 22.0);
    rowPitch = block + gap;
    final double group = peptides * block + (peptides - 1) * gap;
    final double top = math.max(0, (size.height - fixed - 2 * group) / 2);
    xTag = top + _edge;
    firstRow = xTag + tag + _tagGap;
    yTag = firstRow + group + _groupGap;
    drop = yTag + tag + _tagGap - firstRow;
  }

  /// How far a tile is drawn inside its place (`drawIdTile`).
  static double _inset(double side) => math.min(1.0, side * 0.08);

  /// From the canvas's edge to a tag, from a tag to its peptides, and from
  /// x's last peptide to y's tag, enough to keep the groups apart.
  static const double _edge = 6;
  static const double _tagGap = 8;
  static const double _groupGap = 28;

  /// Between a peptide's two lines (the tiles' own inset parts them), and
  /// the least between two peptides.
  static const double _lineGap = 0;
  static const double _leastGap = 3;

  /// A peptide's name.
  static const double label = 13;

  /// The tiles' columns, as Tokenise's, and the card's left edge, where the
  /// tags start too.
  final double left = 20;
  final double right;
  double get cardLeft => left - 6;

  /// A frame's places: `<bos>`, the residues, `<eos>` and padding.
  late final int frame;

  /// How many places the first line holds: all of them where it is not
  /// folded; and how many lines a peptide has.
  late final int firstLine;
  late final int lines;

  late final double tileWidth;
  late final double tileHeight;

  /// From one column to the next, and the right edge of a line's last
  /// column.
  late final double step;
  late final double columnsRight;

  /// A peptide's name and lines, and from one peptide's name to the next.
  late final double block;
  late final double rowPitch;

  late final double xTag;
  late final double firstRow;
  late final double yTag;

  /// How far y lies under x.
  late final double drop;

  double get tagStart => cardLeft;

  double rowTop(int peptide) => firstRow + peptide * rowPitch;

  double yRowTop(int peptide) => rowTop(peptide) + drop;

  /// Place [k] of [peptide]'s frame, in x.
  Rect x(int peptide, int k) {
    final int line = k < firstLine ? 0 : 1;
    return Rect.fromLTWH(
      left + (k - line * firstLine) * step,
      rowTop(peptide) + label + line * (tileHeight + _lineGap),
      tileWidth,
      tileHeight,
    );
  }

  /// Place [i] of [peptide] in y, in the same column as in x.
  Rect y(int peptide, int i) => x(peptide, i).shift(Offset(0, drop));

  /// The card under [peptide] in focus, in x, round its name and its lines,
  /// clear of the peptides beside it.
  Rect card(int peptide) =>
      Rect.fromLTRB(cardLeft, rowTop(peptide) - 3, right + 6, rowTop(peptide) + block + 2);

  /// The card under [peptide] in focus, in y.
  Rect yCard(int peptide) => card(peptide).shift(Offset(0, drop));
}
