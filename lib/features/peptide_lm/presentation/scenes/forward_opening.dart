import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_trace.dart';
import 'forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'tokenise_scene.dart';

/// Forward's first six beats, from Tokenise's last frame to `x0`, as the
/// engine takes them: the batch cut into input x and target y one place
/// apart (`sequences.batches`); the vocabulary become the token embedding,
/// a row of numbers a token; each id of the peptide in focus picking its
/// row, which stands up as that place's column of the stream; and each
/// place's own row of the position embedding added (`HelixPeekLM.forward`).
///
/// Its first frame is Tokenise's last. Every number is the run's: the tables
/// are those the step read its ids through, so the columns they make are the
/// stream's first point, which the blocks then read.
final class ForwardOpening {
  ForwardOpening(this.size, this.view, this.layout) : end = TokeniseEnd(size, view);

  /// The opening's share of Forward, in beats.
  static const double beats = 6;

  // The cut: Tokenise's tags, bars and counts leave; the list closes up
  // under where y will lie; y leaves x, a place to the left; and the places
  // whose target is padding dim.
  static const double _retiredBy = 0.5;
  static const (double, double) _closeUp = (0.2, 1.0);
  static const (double, double) _appear = (0.5, 0.7);
  static const (double, double) _dropping = (0.5, 1.3);
  static const (double, double) _slide = (1.0, 1.6);
  static const (double, double) _dim = (1.4, 1.9);

  // The table: y goes and the other peptides fade; the peptide in focus
  // spreads to the token row's places and comes down to it, its ids turning
  // back into residues; the list goes up its column and in, beside the
  // table, whose rows grow out from it.
  static const (double, double) _away = (2.0, 2.4);
  static const (double, double) _widen = (2.0, 2.4);
  static const (double, double) _descend = (2.3, 2.8);
  static const (double, double) _unflip = (2.45, 2.85);
  static const (double, double) _rise = (2.4, 2.8);
  static const (double, double) _across = (2.7, 2.95);
  static const (double, double) _grow = (2.7, 3.05);
  static const (double, double) _rail = (2.95, 3.4);

  // The lookup: a row lifted for each place, left to right, the first ones
  // far enough apart to be followed one at a time and the rest closer.
  static const double _lookFrom = 3.05;
  static const double _lookTo = 5.0;
  static const double _flight = 0.55;
  static const double _quickening = 0.7;

  // The position embedding: drawn on its own over the columns, then added;
  // the table leaves; the stream is `x0`, and the head maps come up.
  static const (double, double) _tableOut = (5.0, 5.3);
  static const (double, double) _placesIn = (5.0, 5.35);
  static const (double, double) _placesTag = (5.25, 5.45);
  static const (double, double) _placesOut = (5.45, 5.8);
  static const (double, double) _add = (5.4, 5.8);
  static const (double, double) _toStream = (5.8, 6.0);
  static const (double, double) _settle = (5.6, 6.0);

  /// Where the caption turns from the position embedding to the stream.
  static const double _streamCaption = 5.8;

  /// How far a place whose target is padding dims: none of the loss is
  /// counted there.
  static const double _dimmed = 0.65;

  final Size size;
  final LmView view;
  final ForwardLayout layout;
  final TokeniseEnd end;

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// How much of the rail shows: once the list has left its column.
  static double railShown(double beat) => _span(beat, _rail);

  /// How far the stage has settled into the blocks' first frame: the head
  /// maps and the place in focus.
  static double settled(double beat) => _span(beat, _settle);

  TrainingTrace get _trace => view.trace;

  // ---------------------------------------------------------------- layout

  double get _tagHeight => tagSize(view, 'target y').height;

  /// One place of the matrix, across.
  double get _place => end.place(0, 1).left - end.place(0, 0).left;

  double get _matrixBottom => end.place(_trace.peptides.length - 1, 0).bottom;

  /// How far y lies under x: past x, its tag between them.
  double get _below =>
      _matrixBottom - end.place(0, 0).top + 8 + _tagHeight + 8;

  /// Where y's tag stands.
  double get _yTag => _matrixBottom + 8;

  /// The list closed up under y, one column at the left, in the room
  /// between y's foot and the canvas's (its tags under it have gone): clear
  /// of the token row's way down, and the column the list goes up to the
  /// table by. A row's height.
  double get _closedPitch =>
      math.max(4, (size.height - 6 - (_matrixBottom + _below + 10)) / _trace.vocab.length);

  /// Token [id]'s tile in the closed list.
  Rect _closed(int id) {
    final Rect first = end.chip(0);
    final double pitch = _closedPitch;
    final double side = math.min(first.width, math.max(3, pitch - 2));
    return Rect.fromLTWH(
      first.left,
      _matrixBottom + _below + 10 + id * pitch + (pitch - side) / 2,
      side,
      side,
    );
  }

  /// The table's band: its tag over it at the top of the canvas, its foot
  /// clear of the stream.
  Rect get _table {
    final double top = 4 + _tagHeight + 6;
    final double bottom = math.max(top + 3.0 * _trace.vocab.length, layout.grid.top - 8);
    return Rect.fromLTRB(layout.grid.left, top, layout.grid.right, bottom);
  }

  double get _pitch => _table.height / _trace.vocab.length;

  double get _chipSide => (_pitch - 1.5).clamp(3.0, 16.0);

  double get _idSize => (_pitch * 0.8).clamp(6.0, end.idSize);

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
      _matrix(canvas, beat);
    }
    if (beat < _retiredBy + 0.01) {
      // What Tokenise retires, fading where it stands: the bars and counts
      // under the entries, its tags over them, as it drew them.
      final double retiring = 1 - through(beat, 0, _retiredBy);
      const TokeniseScene().paintEnd(
        canvas,
        size,
        view,
        TokeniseFade(rows: false, entries: false, bars: retiring, counts: retiring, tags: 0),
      );
      _entries(canvas, beat);
      const TokeniseScene().paintEnd(
        canvas,
        size,
        view,
        TokeniseFade(rows: false, entries: false, bars: 0, counts: 0, tags: retiring),
      );
    } else {
      _entries(canvas, beat);
    }
    _cutTags(canvas, beat);
    _tableRows(canvas, beat);
    _stream(canvas, beat);
    _flights(canvas, beat);
    if (beat >= _widen.$1) {
      _focusRow(canvas, beat);
    }
  }

  /// The batch's places as Tokenise draws them: an end or padding as a
  /// token, a residue as its id.
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

  /// x, the batch less its last place, and under it y, the batch less its
  /// first, a place to the left: each place over the one it learns. A place
  /// whose target is padding dims in both. Then y goes off to the right and
  /// the other peptides fade.
  void _matrix(Canvas canvas, double beat) {
    final double appear = _span(beat, _appear);
    final double drop = _span(beat, _dropping) * _below;
    final double slide = _span(beat, _slide);
    final double dim = _span(beat, _dim);
    final double away = _span(beat, _away);
    final double off = away * (end.tagEnd - end.tagStart);
    for (int p = 0; p < _trace.peptides.length; p++) {
      final bool focus = p == view.peptide;
      final List<int> ids = TokeniseScene.frameOf(_trace, p);
      final int residues = _trace.peptides[p].sequence.length;
      final double shown = 1 - away;
      // y, drawn first: it leaves from under x.
      final double y = appear * (1 - away);
      if (y > 0) {
        final Offset shift = Offset(off - _place * slide, drop);
        if (focus) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(end.card(p).shift(shift), const Radius.circular(6)),
            Paint()..color = view.inks.card.withValues(alpha: y),
          );
        }
        for (int k = 0; k < ids.length; k++) {
          final double alpha = k == 0
              ? 1 - slide
              : _trace.token(ids[k]) == '<pad>'
              ? 1 - _dimmed * dim
              : 1;
          _tile(canvas, end.place(p, k).shift(shift), ids, k, residues, alpha * y);
        }
      }
      // x.
      if (focus && shown > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(end.card(p), const Radius.circular(6)),
          Paint()..color = view.inks.card.withValues(alpha: shown),
        );
      }
      if (focus && beat >= _widen.$1) {
        continue;
      }
      for (int k = 0; k < ids.length; k++) {
        final double alpha = k == ids.length - 1
            ? 1 - slide
            : _trace.token(ids[k + 1]) == '<pad>'
            ? 1 - _dimmed * dim
            : 1;
        _tile(canvas, end.place(p, k), ids, k, residues, alpha * shown);
      }
    }
  }

  /// The vocabulary's tiles and ids: closing up under y, then up their
  /// column and in beside the table, whose rows they name; gone with it.
  void _entries(Canvas canvas, double beat) {
    final double leaving = 1 - _span(beat, _tableOut);
    if (leaving <= 0) {
      return;
    }
    final double closing = _span(beat, _closeUp);
    final double up = _span(beat, _rise);
    final double across = _span(beat, _across);
    final double closedSize = (_closedPitch * 0.8).clamp(6.0, end.idSize);
    final double listed = end.idSize + (closedSize - end.idSize) * closing;
    final double idSize = listed + (_idSize - listed) * up;
    _fade(canvas, leaving, () {
      for (int id = 0; id < _trace.vocab.length; id++) {
        Rect chip = closing <= 0 ? end.chip(id) : Rect.lerp(end.chip(id), _closed(id), closing)!;
        if (up > 0) {
          final Rect target = _tableChip(id);
          final double side = chip.width + (target.width - chip.width) * up;
          chip = Rect.fromLTWH(
            chip.left + (target.left - chip.left) * across,
            chip.top + (target.top - chip.top) * up,
            side,
            side,
          );
        }
        TokeniseScene.drawEntry(canvas, view, chip, id, 1, idSize);
      }
    });
  }

  /// [draw], at [alpha] as a whole.
  void _fade(Canvas canvas, double alpha, VoidCallback draw) {
    if (alpha >= 1) {
      draw();
      return;
    }
    // A layer takes only its paint's alpha.
    canvas.saveLayer(Offset.zero & size, Paint()..color = view.inks.ground.withValues(alpha: alpha));
    draw();
    canvas.restore();
  }

  /// The cut's names, as Tokenise names its parts: input x where the batch's
  /// tag stood, and target y over y; and the tables', each over its own.
  void _cutTags(Canvas canvas, double beat) {
    final double away = _span(beat, _away);
    final double x = through(beat, 0.3, 0.8) * (1 - away);
    if (x > 0) {
      drawTag(canvas, view, 'input x', Offset(end.tagStart, end.tagBand), alpha: x);
    }
    final double y = through(beat, 0.9, 1.4) * (1 - away);
    if (y > 0) {
      drawTag(
        canvas,
        view,
        'target y',
        Offset(end.tagStart + away * (end.tagEnd - end.tagStart), _yTag),
        alpha: y,
      );
    }
    final double table = through(beat, _across.$1, _grow.$2) * (1 - _span(beat, _tableOut));
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
  /// growing out from the list beside it; the row each place reads lit as
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
      final Rect from = end.place(p, k);
      if (k >= inputs) {
        _tile(canvas, from, ids, k, residues, (1 - _dimmed) * (1 - widen));
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

  /// A row of the batch puts its peptide in focus while the batch is on
  /// screen; once the token row has landed, a token its place.
  LmHit? hit(Offset at, double beat) {
    if (beat < _away.$1) {
      for (int p = 0; p < _trace.peptides.length; p++) {
        final Rect card = end.card(p);
        if (at.dy >= card.top && at.dy < card.bottom + 1) {
          return FocusPeptide(p);
        }
      }
      return null;
    }
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
    if (beat < 2) {
      return 'Input x and target y, one place apart: each place learns the token '
          'after it · ${grouped(trace.targetCount)} targets';
    }
    if (beat < 3) {
      final int peptides = trace.peptides.length;
      final String all = switch (peptides) {
        1 => 'The one peptide is read',
        2 => 'Both are read at once',
        _ => 'All ${spelled(peptides)} are read at once',
      };
      return '$all; ${view.focus.source.label} is drawn. The vocabulary is the token embedding';
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
