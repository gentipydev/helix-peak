import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_trace.dart';
import 'forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'shift_scene.dart';
import 'tokenise_scene.dart';

/// Forward's first four beats, from Shift's last frame to `x0`, as the
/// engine takes them (`HelixPeekLM.forward`): the token embedding, a row of
/// numbers a token; each id of the peptide in focus picking its row, which
/// stands up as that place's column of the stream; and each place's own row
/// of the position embedding added.
///
/// Its first frame is Shift's last. Every number is the run's: the tables
/// are those the step read its ids through, so the columns they make are the
/// stream's first point, which the blocks then read.
final class ForwardOpening {
  ForwardOpening(this.size, this.view, this.layout) : shift = ShiftLayout(size, view);

  /// The opening's share of Forward, in beats.
  static const double beats = 4;

  // The table: y goes off to the right and the other peptides fade; the
  // peptide in focus spreads to the token row's places and comes down to
  // it, its ids turning back into residues; the token embedding's tokens
  // come in, top to bottom, and its rows grow out from them.
  static const (double, double) _away = (0.0, 0.4);
  static const (double, double) _widen = (0.0, 0.4);
  static const (double, double) _descend = (0.3, 0.8);
  static const (double, double) _unflip = (0.45, 0.85);
  static const (double, double) _tableIn = (0.3, 0.8);
  static const double _entryIn = 0.2;
  static const (double, double) _grow = (0.7, 1.05);
  static const (double, double) _rail = (0.95, 1.4);

  // The lookup: a row lifted for each place, left to right, the first ones
  // far enough apart to be followed one at a time and the rest closer.
  static const double _lookFrom = 1.05;
  static const double _lookTo = 3.0;
  static const double _flight = 0.55;
  static const double _quickening = 0.7;

  // The position embedding: drawn on its own over the columns, then added;
  // the table leaves; the stream is `x0`, and the head maps come up.
  static const (double, double) _tableOut = (3.0, 3.3);
  static const (double, double) _placesIn = (3.0, 3.35);
  static const (double, double) _placesTag = (3.25, 3.45);
  static const (double, double) _placesOut = (3.45, 3.8);
  static const (double, double) _add = (3.4, 3.8);
  static const (double, double) _toStream = (3.8, 4.0);
  static const (double, double) _settle = (3.6, 4.0);

  /// Where the caption turns from the table to the lookup.
  static const double _lookupCaption = 1.0;

  /// Where the caption turns from the position embedding to the stream.
  static const double _streamCaption = 3.8;

  final Size size;
  final LmView view;
  final ForwardLayout layout;
  final ShiftLayout shift;

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// How much of the rail shows: once the table has grown.
  static double railShown(double beat) => _span(beat, _rail);

  /// How far the stage has settled into the blocks' first frame: the head
  /// maps and the place in focus.
  static double settled(double beat) => _span(beat, _settle);

  TrainingTrace get _trace => view.trace;

  // ---------------------------------------------------------------- layout

  double get _tagHeight => tagSize(view, 'token embedding').height;

  /// The table's band: its tag over it at the top of the canvas, its foot
  /// clear of the stream.
  Rect get _table {
    final double top = 4 + _tagHeight + 6;
    final double bottom = math.max(top + 3.0 * _trace.vocab.length, layout.grid.top - 8);
    return Rect.fromLTRB(layout.grid.left, top, layout.grid.right, bottom);
  }

  double get _pitch => _table.height / _trace.vocab.length;

  double get _chipSide => (_pitch - 1.5).clamp(3.0, 16.0);

  // As large as the vocabulary's ids were in its list, at the most.
  double get _idSize => (_pitch * 0.8).clamp(6.0, 9.5);

  double get _idWidth =>
      view.kit
          .layout('8' * '${_trace.vocab.length - 1}'.length, inked(view.kit.mono, _idSize, view.inks.quiet))
          .width +
      6;

  /// Token [id]'s tile beside its row of the table.
  Rect _tableChip(int id) => Rect.fromLTWH(
    _table.left + _idWidth,
    _table.top + id * _pitch + (_pitch - _chipSide) / 2,
    _chipSide,
    _chipSide,
  );

  /// Token [id]'s row of numbers in the table.
  Rect _tableRow(int id) {
    final double left = _table.left + _idWidth + _chipSide + 6;
    return Rect.fromLTRB(left, _table.top + id * _pitch, _table.right, _table.top + (id + 1) * _pitch);
  }

  /// Place [i]'s column of the stream, as Forward's grid lays it.
  Rect _column(int i) {
    final double w = layout.grid.width / view.focus.inputs;
    return Rect.fromLTWH(layout.grid.left + i * w, layout.grid.top, math.max(0.5, w - 1), layout.grid.height);
  }

  /// How far place [i]'s row has flown from the table to its column.
  double _flightOf(int i, double beat) {
    final int n = view.focus.inputs;
    final double start = _lookFrom +
        (n < 2 ? 0 : math.pow(i / (n - 1), _quickening) * (_lookTo - _flight - _lookFrom));
    return through(beat, start, start + _flight);
  }

  // --------------------------------------------------------------- numbers

  /// The stream's scale, which the table and the columns are drawn on, so a
  /// row keeps its colours from the table to its column.
  double get _scale => ForwardScene.scales(view).$1;

  /// How many times smaller the position embedding's rows are than the
  /// token rows they are added to, over the places in focus: the factor its
  /// rows are drawn larger by while they show alone.
  static int smaller(LmView view) => view.kit.memo<int>(('forward-places', view.step, view.peptide), () {
    final TrainingTrace trace = view.trace;
    double token = 0;
    double place = 0;
    for (int i = 0; i < view.focus.inputs; i++) {
      final int id = trace.inputAt(view.peptide, i);
      for (int d = 0; d < trace.model.width; d++) {
        token += math.pow(trace.tokenEmbedding(view.checkpoint, id, d), 2);
        place += math.pow(trace.positionEmbedding(view.checkpoint, i, d), 2);
      }
    }
    return place <= 0 ? 1 : math.max(1, math.sqrt(token / place).round());
  });

  // ---------------------------------------------------------------- paint

  void paint(Canvas canvas, double beat) {
    if (beat < _away.$2 + 0.01) {
      // Shift's last frame, but for the row in focus, which is drawn here:
      // y goes off to the right, the rest fades.
      final double away = _span(beat, _away);
      const ShiftScene().paintEnd(
        canvas,
        size,
        view,
        ShiftFade(
          focusX: false,
          others: 1 - away,
          y: 1 - away,
          ySlide: away * (shift.right + 6 - shift.cardLeft),
          chrome: 1 - away,
          card: 1 - away,
        ),
      );
    }
    _entries(canvas, beat);
    _tags(canvas, beat);
    _tableRows(canvas, beat);
    _stream(canvas, beat);
    _flights(canvas, beat);
    _focusRow(canvas, beat);
  }

  /// A place of Shift's x, as it draws it: an end or padding as a token, a
  /// residue as its id.
  void _tile(Canvas canvas, Rect rect, List<int> ids, int k, int residues, double alpha) {
    if (alpha <= 0) {
      return;
    }
    if (k == 0 || k > residues) {
      drawToken(canvas, view, rect, ids[k], alpha: alpha);
    } else {
      drawIdTile(canvas, view, rect, ids[k], alpha: alpha);
    }
  }

  /// The token embedding's tokens and ids beside its rows, coming in one
  /// after another from the top; gone with the table.
  void _entries(Canvas canvas, double beat) {
    final double leaving = 1 - _span(beat, _tableOut);
    if (leaving <= 0 || beat < _tableIn.$1) {
      return;
    }
    final int count = _trace.vocab.length;
    for (int id = 0; id < count; id++) {
      final double start = _tableIn.$1 +
          (count < 2 ? 0 : id / (count - 1)) * (_tableIn.$2 - _tableIn.$1 - _entryIn);
      final double shown = through(beat, start, start + _entryIn) * leaving;
      if (shown > 0) {
        TokeniseScene.drawEntry(canvas, view, _tableChip(id), id, 1, _idSize, alpha: shown);
      }
    }
  }

  /// The tables' names, each over its own.
  void _tags(Canvas canvas, double beat) {
    final double table = through(beat, _tableIn.$1, _grow.$2) * (1 - _span(beat, _tableOut));
    if (table > 0) {
      drawTag(canvas, view, 'token embedding', Offset(layout.grid.left - 6, 4), alpha: table);
    }
    final double places = _span(beat, _placesTag) * (1 - through(beat, _settle.$1, _settle.$1 + 0.3));
    if (places > 0) {
      drawTag(
        canvas,
        view,
        'position embedding, drawn × ${grouped(smaller(view))}',
        Offset(layout.grid.left - 6, layout.grid.top - _tagHeight - 6),
        alpha: places,
      );
    }
  }

  /// The token embedding: a row of numbers a token, on the stream's scale,
  /// growing out from its token beside it; the row each place reads lit as
  /// it is lifted.
  void _tableRows(Canvas canvas, double beat) {
    final double grow = _span(beat, _grow);
    final double leaving = 1 - _span(beat, _tableOut);
    if (grow <= 0 || leaving <= 0) {
      return;
    }
    final int width = _trace.model.width;
    final int vocab = _trace.vocab.length;
    final Rect rows = Rect.fromLTRB(_tableRow(0).left, _table.top, _table.right, _table.bottom);
    final GridMesh mesh = GridMesh(rows, width, vocab, rowGap: math.min(1, _pitch * 0.15));
    // Each row grows from its token outwards, a soft front a few numbers wide.
    const double front = 8;
    final double reach = grow * (width + front);
    final double scale = _scale;
    for (int id = 0; id < vocab; id++) {
      for (int d = 0; d < width; d++) {
        final Color value = view.inks.signed(_trace.tokenEmbedding(view.checkpoint, id, d) / scale);
        final double shown = ((reach - d) / front).clamp(0.0, 1.0) * leaving;
        mesh.cell(d, id, Color.lerp(view.inks.ground, value, shown)!);
      }
    }
    mesh.draw(canvas);
    for (int i = 0; i < view.focus.inputs; i++) {
      final double f = _flightOf(i, beat);
      if (f <= 0 || f >= 1) {
        continue;
      }
      final int id = _trace.inputAt(view.peptide, i);
      final Rect row = _tableRow(id);
      canvas.drawRect(
        Rect.fromLTRB(_tableChip(id).left - 2, row.top - 0.5, row.right + 1, row.bottom + 0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: math.sin(math.pi * f) * leaving),
      );
    }
  }

  /// The stream as the columns land: each its token's row; then the
  /// position embedding's rows alone, drawn larger by [smaller]; then the
  /// two added; and at the last, `x0` as the run kept it, which the sum is
  /// to within its rounding.
  void _stream(Canvas canvas, double beat) {
    if (beat < _lookFrom) {
      return;
    }
    final int inputs = view.focus.inputs;
    final int width = _trace.model.width;
    final double scale = _scale;
    final double alone = _span(beat, _placesIn) * (1 - _span(beat, _placesOut));
    final double add = _span(beat, _add);
    final double kept = _span(beat, _toStream);
    final double larger = smaller(view).toDouble();
    final GridMesh grid = GridMesh(layout.grid, inputs, width, columnGap: 1);
    for (int i = 0; i < inputs; i++) {
      final bool landed = _flightOf(i, beat) >= 1;
      final int id = _trace.inputAt(view.peptide, i);
      for (int d = 0; d < width; d++) {
        if (!landed) {
          grid.cell(i, d, view.inks.ground);
          continue;
        }
        final double token = _trace.tokenEmbedding(view.checkpoint, id, d);
        final double place = _trace.positionEmbedding(view.checkpoint, i, d);
        Color color = view.inks.signed((token + add * place) / scale);
        if (alone > 0) {
          color = Color.lerp(color, view.inks.signed(place * larger / scale), alone)!;
        }
        if (kept > 0) {
          color = Color.lerp(
            color,
            view.inks.signed(_trace.stream(view.checkpoint, 0, view.peptide, i, d) / scale),
            kept,
          )!;
        }
        grid.cell(i, d, color);
      }
    }
    grid.draw(canvas);
  }

  /// Each place's row, lifted from the table and stood up as its column:
  /// its first number at the top, as the stream draws it.
  void _flights(Canvas canvas, double beat) {
    final int width = _trace.model.width;
    final double scale = _scale;
    for (int i = 0; i < view.focus.inputs; i++) {
      final double f = _flightOf(i, beat);
      if (f <= 0 || f >= 1) {
        continue;
      }
      final int id = _trace.inputAt(view.peptide, i);
      final Rect from = _tableRow(id);
      final Rect to = _column(i);
      final Offset centre = Offset.lerp(from.center, to.center, f)!;
      final double length = from.width + (to.height - from.width) * f;
      final double thick = from.height + (to.width - from.height) * f;
      final GridMesh strip = GridMesh(
        Rect.fromCenter(center: Offset.zero, width: length, height: thick),
        width,
        1,
      );
      for (int d = 0; d < width; d++) {
        strip.cell(d, 0, view.inks.signed(_trace.tokenEmbedding(view.checkpoint, id, d) / scale));
      }
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(math.pi / 2 * f);
      strip.draw(canvas);
      canvas.restore();
    }
  }

  /// The peptide in focus, x's row of it: its places with a target spread to
  /// the token row's and come down to it, its ids turning back into
  /// residues; the rest, whose targets are padding, gone.
  void _focusRow(Canvas canvas, double beat) {
    final int p = view.peptide;
    final List<int> ids = TokeniseScene.frameOf(_trace, p);
    final int residues = view.focus.sequence.length;
    final int inputs = view.focus.inputs;
    final double widen = _span(beat, _widen);
    final double descend = _span(beat, _descend);
    final double flip = 1 - _span(beat, _unflip);
    for (int k = 0; k < ids.length - 1; k++) {
      final Rect from = shift.x(p, k);
      if (k >= inputs) {
        _tile(canvas, from, ids, k, residues, (1 - ShiftScene.dimmed) * (1 - widen));
        continue;
      }
      final Rect token = layout.tokens.at(k);
      final Rect rect = Rect.fromLTWH(
        from.left + (token.left - from.left) * widen,
        from.top + (token.top - from.top) * descend,
        from.width + (token.width - from.width) * widen,
        from.height + (token.height - from.height) * descend,
      );
      if (k == 0 || flip <= 0) {
        drawToken(canvas, view, rect, ids[k]);
      } else {
        TokeniseScene.drawFlip(canvas, view, rect, ids[k], flip);
      }
    }
  }

  // ------------------------------------------------------------------ taps

  /// Once the token row has landed, a token puts its place in focus.
  LmHit? hit(Offset at, double beat) {
    if (beat >= _descend.$2) {
      final int? i = layout.tokens.indexAt(at);
      return i == null ? null : FocusPosition(i);
    }
    return null;
  }

  // -------------------------------------------------------------- caption

  /// What the opening shows at [beat], in the run's numbers.
  static String caption(LmView view, double beat) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int inputs = view.focus.inputs;
    if (beat < _lookupCaption) {
      final int peptides = trace.peptides.length;
      final String all = switch (peptides) {
        1 => 'The one peptide is read',
        2 => 'Both are read at once',
        _ => 'All ${spelled(peptides)} are read at once',
      };
      return '$all; ${view.focus.source.label} is drawn. The token embedding holds a row a token';
    }
    if (beat < _lookTo) {
      final Map<int, int> uses = <int, int>{};
      for (int i = 0; i < inputs; i++) {
        uses.update(trace.inputAt(view.peptide, i), (int n) => n + 1, ifAbsent: () => 1);
      }
      int most = uses.keys.first;
      for (final int id in uses.keys) {
        if (uses[id]! > uses[most]!) {
          most = id;
        }
      }
      final int times = uses[most]!;
      final String again = times < 2
          ? ''
          : ', ${trace.token(most)}\'s ${times == 2 ? 'twice' : '${spelled(times)} times'}';
      return 'Each id picks its row of $width: ${grouped(inputs)} places from '
          '${grouped(uses.length)} rows$again';
    }
    if (beat < _streamCaption) {
      final int times = smaller(view);
      return times < 2
          ? 'Plus each place\'s own row of the position embedding'
          : 'Plus each place\'s own row of the position embedding, '
                '${grouped(times)}× smaller than its token\'s';
    }
    return 'x0: ${grouped(inputs)} × $width numbers, the residual stream the blocks read';
  }
}
