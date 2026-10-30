import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'shift_scene.dart';
import 'tokenise_scene.dart';

/// Embedding: x's ids become numbers, as the engine makes them
/// (`HelixPeekLM.forward`: the token embedding of the ids, plus the position
/// embedding). It opens on Shift's last frame: y goes off to the right, the
/// other peptides fade, and the peptide in focus comes down to the foot of
/// the canvas under its name, its ids kept. Over it comes the token
/// embedding, a row of numbers a token, each number written out on a soft
/// tile of its colour.
/// Each id lights the row it reads; the rows read gather in place order, x
/// embedded, a row a place, each labelled by the tile that read it; each
/// place's own row of the position embedding is added; and the sum is
/// `x0`, which Forward stands up as its stream.
///
/// Every number is the run's: the tables the step read its ids through, kept
/// whole, and their sum, x0 as the engine makes it, every number written to
/// two places.
final class EmbeddingScene extends LmScene {
  const EmbeddingScene();

  // The opening: y goes off to the right and the other peptides fade; the
  // peptide in focus comes down to the foot; the table's tokens come in, top
  // to bottom, and its rows grow out from them, their numbers after.
  static const (double, double) _away = (0.0, 0.5);
  static const (double, double) _descend = (0.2, 0.9);
  static const (double, double) _tableIn = (0.4, 1.1);
  static const double _entryIn = 0.25;
  static const (double, double) _grow = (0.7, 1.3);
  static const (double, double) _written = (1.1, 1.5);

  // The lookup, one place at a time: `<bos>` alone, long enough to be
  // followed, then the rest left to right, each lit on its own and each a
  // little quicker than the one before, the last at [_lastShare] of the
  // first's time.
  static const (double, double) _first = (2.4, 3.6);
  static const double _restFrom = 3.7;
  static const double _restTo = 10.4;
  static const double _lastShare = 0.4;

  // The gather: the table goes, and each place's copy of the row it read
  // moves to the place's own row, the tile that read it going up to label
  // it and turning back into its residue.
  static const (double, double) _tableOut = (10.5, 11.1);
  static const double _gatherFrom = 10.5;
  static const double _gatherStagger = 0.5;
  static const double _gatherFlight = 1.0;

  /// The part of a copy's flight it moves in: its numbers go before, and
  /// come back after.
  static const double _moveFrom = 0.15;
  static const double _moveTo = 0.85;

  // The position embedding: each place's row alone, on its own scale, then
  // added: the sum is x0.
  static const (double, double) _placesIn = (12.1, 12.5);
  static const (double, double) _placesOut = (12.8, 13.2);
  static const (double, double) _tokensUnwritten = (12.1, 12.3);
  static const (double, double) _placesWritten = (12.3, 12.5);
  static const (double, double) _placesUnwritten = (12.8, 13.0);
  static const (double, double) _sumsWritten = (13.0, 13.2);
  static const (double, double) _add = (12.9, 13.3);

  /// Where the caption turns: to what the numbers are, the lookup, the
  /// gather, the position embedding and x0. The note over the table turns
  /// with it, but for the still beat, which keeps the table's.
  static const double _numbersCaption = 1.4;
  static const double _lookupCaption = 2.4;
  static const double _gatherCaption = 10.5;
  static const double _placesCaption = 12.1;
  static const double _x0Caption = 13.5;

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * LmStage.embedding.beats, const EmbeddingFade());

  /// The stage's last frame, with [fade] leaving out what the stage after
  /// it draws itself: Forward opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view, EmbeddingFade fade) =>
      _paint(canvas, size, view, LmStage.embedding.beats.toDouble(), fade);

  void _paint(Canvas canvas, Size size, LmView view, double beat, EmbeddingFade fade) {
    final EmbeddingLayout layout = EmbeddingLayout(size, view);
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
          ySlide: away * (layout.shift.right + 6 - layout.shift.cardLeft),
          chrome: 1 - away,
          card: 1 - away,
          focusLabel: 0,
        ),
      );
    }
    _note(canvas, view, layout, beat, fade);
    _tags(canvas, view, layout, beat, fade);
    _table(canvas, size, view, layout, beat);
    if (fade.rows) {
      _rows(canvas, size, view, layout, beat);
    }
    _focusRow(canvas, view, layout, beat, fade);
  }

  // --------------------------------------------------------------- numbers

  /// When place [i] of [n] is read: `<bos>` on its own, then each of the
  /// rest in turn, their times falling in a line to [_lastShare] of the
  /// first's, together filling the lookup.
  static (double, double) slot(int i, int n) {
    if (i == 0) {
      return _first;
    }
    double share(int j) => n < 3 ? 1 : 1 - (1 - _lastShare) * (j - 1) / (n - 2);
    double total = 0;
    double before = 0;
    for (int j = 1; j < n; j++) {
      total += share(j);
      if (j < i) {
        before += share(j);
      }
    }
    const double span = _restTo - _restFrom;
    final double start = _restFrom + span * before / total;
    return (start, start + span * share(i) / total);
  }

  /// How far place [i]'s lookup has got, of [n] places.
  static double _lookup(int i, int n, double beat) {
    final (double from, double to) = slot(i, n);
    return ((beat - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// How strongly a place and the row it reads are lit, [f] of the way
  /// through its lookup: up quickly, held, and down, so only one is lit at
  /// a time.
  static double _lit(double f) => through(f, 0, 0.2) * (1 - through(f, 0.8, 1));

  /// The place being read at [beat], or the last read; null before any.
  static int? _reading(int n, double beat) {
    int? at;
    for (int i = 0; i < n; i++) {
      if (slot(i, n).$1 <= beat) {
        at = i;
      }
    }
    return beat < _first.$1 || beat >= _gatherFrom ? null : at;
  }

  /// How far place [i]'s copy of its row has moved to the place's own row.
  static double _gather(int i, int n, double beat) {
    final double start = _gatherFrom + (n < 2 ? 0 : i / (n - 1)) * _gatherStagger;
    return through(beat, start, start + _gatherFlight);
  }

  /// How many times smaller the position embedding's rows are than the
  /// token rows they are added to, over the places in focus.
  static int smaller(LmView view) => view.kit.memo<int>(('embedding-places', view.step, view.peptide), () {
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

  /// The position embedding's own colour scale over the places in focus:
  /// its 99th percentile, as the stream's is.
  static double _placeScale(LmView view) => view.kit.memo<double>(('embedding-place-scale', view.step, view.peptide), () {
    final List<double> values = <double>[
      for (int i = 0; i < view.focus.inputs; i++)
        for (int d = 0; d < view.trace.model.width; d++) view.trace.positionEmbedding(view.checkpoint, i, d).abs(),
    ]..sort();
    return math.max(1e-6, values[(values.length * 0.99).floor().clamp(0, values.length - 1)]);
  });

  /// Whether `<pad>`'s row is zero at every checkpoint the run kept.
  static bool _padStill(TrainingTrace trace) {
    final int pad = trace.vocab.indexOf('<pad>');
    if (pad < 0) {
      return false;
    }
    for (final TraceCheckpoint at in trace.checkpoints) {
      for (int d = 0; d < trace.model.width; d++) {
        if (trace.tokenEmbedding(at, pad, d) != 0) {
          return false;
        }
      }
    }
    return true;
  }

  // ----------------------------------------------------------------- note

  /// Why each part happens, a line or two over the table, one part at a
  /// time, beside the caption under the canvas, which says what happens:
  /// when it holds, from and to, and what it says.
  static List<(double, double, String)> _notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    return <(double, double, String)>[
      (_tableIn.$1, _lookupCaption, 'A model computes with numbers, not letters: each token gets $width of its own.'),
      (_lookupCaption, _gatherCaption, 'The lookup is only this: the id picks its row, no arithmetic.'),
      (_gatherCaption, _placesCaption, _sameRow(view)),
      (_placesCaption, _x0Caption, "Attention alone ignores order: each place's own row says where it sits."),
      (_x0Caption, double.infinity, 'Each place is now $width numbers, which every block reads and adds to.'),
    ];
  }

  /// That x embedded cannot tell a token's places apart: the first token
  /// the peptide in focus has at two places, the same row at both.
  static String _sameRow(LmView view) {
    final TrainingTrace trace = view.trace;
    final Map<int, int> first = <int, int>{};
    for (int i = 0; i < view.focus.inputs; i++) {
      final int id = trace.inputAt(view.peptide, i);
      final int? before = first[id];
      if (before != null) {
        return 'The two ${trace.token(id)}s at places $before and $i are the same row: '
            'nothing yet says where each is.';
      }
      first[id] = i;
    }
    return "Each place holds its token's row: nothing yet says where it is.";
  }

  /// The place being read, named with its token, its id and the row it reads.
  static String _readout(LmView view, int i) {
    final int id = view.trace.inputAt(view.peptide, i);
    return '${view.trace.token(id)} · place $i · id $id → row $id';
  }

  static TextStyle _whyStyle(LmView view) =>
      inked(view.kit.sans, _noteSize, view.inks.quiet).copyWith(height: 1.3);

  static TextStyle _readoutStyle(LmView view) => inked(view.kit.sans, _noteSize, view.inks.signal);

  static const double _noteSize = 10.5;

  /// How tall the note is at [width]: a line for the place being read, and
  /// the most lines any of its parts takes.
  static double noteHeight(LmView view, double width) => view.kit.memo<double>(
    ('embedding-note', view.peptide, view.kit.scaler, width),
    () {
      double why = 0;
      for (final (_, _, String text) in _notes(view)) {
        why = math.max(why, view.kit.paragraph(text, _whyStyle(view), width).height);
      }
      return view.kit.layout(_readout(view, 0), _readoutStyle(view)).height + _readoutGap + why;
    },
  );

  static const double _readoutGap = 4;

  /// The note over the table, its parts fading out and in at their turns:
  /// during the lookup, the place being read over why.
  void _note(Canvas canvas, LmView view, EmbeddingLayout layout, double beat, EmbeddingFade fade) {
    const double turn = 0.25;
    final double width = layout.right - layout.noteLeft;
    final double readout = view.kit.layout(_readout(view, 0), _readoutStyle(view)).height + _readoutGap;
    for (final (double from, double to, String text) in _notes(view)) {
      final double alpha = through(beat, from, from + turn) * (1 - through(beat, to - turn, to)) * fade.chrome;
      if (alpha <= 0) {
        continue;
      }
      view.kit
          .paragraph(text, inked(view.kit.sans, _noteSize, view.inks.quiet, alpha: alpha).copyWith(height: 1.3), width)
          .paint(canvas, Offset(layout.noteLeft, layout.noteTop + readout));
      if (from == _lookupCaption) {
        final int? i = _reading(view.focus.inputs, beat);
        if (i != null) {
          view.kit.draw(
            canvas,
            _readout(view, i),
            inked(view.kit.sans, _noteSize, view.inks.signal, alpha: alpha),
            Offset(layout.noteLeft, layout.noteTop),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------- paint

  /// The matrix's name, each in turn at the top left: the token embedding,
  /// x embedded, the position embedding's rows, and x0.
  void _tags(Canvas canvas, LmView view, EmbeddingLayout layout, double beat, EmbeddingFade fade) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int inputs = view.focus.inputs;
    final Offset at = Offset(layout.left, layout.tagTop);
    for (final (String text, double alpha) in <(String, double)>[
      (
        'token embedding · ${trace.vocab.length} × $width',
        _span(beat, _tableIn) * (1 - through(beat, _tableOut.$1, _tableOut.$1 + 0.3)),
      ),
      (
        'x embedded · $inputs × $width',
        through(beat, 11.1, 11.5) * (1 - through(beat, 11.9, 12.1)),
      ),
      (
        'position embedding · first $inputs of ${trace.model.context} rows',
        through(beat, 12.1, 12.35) * (1 - through(beat, 13.0, 13.25)),
      ),
      ('x0 · $inputs × $width', through(beat, 13.25, 13.5) * fade.chrome),
    ]) {
      if (alpha > 0) {
        drawTag(canvas, view, text, at, alpha: alpha);
      }
    }
  }

  /// The token embedding: its tokens and ids, coming in from the top; its
  /// rows growing out from them on the stream's scale, then written out;
  /// the row each place reads lit while it reads, and a row read kept
  /// marked; all of it gone in the gather.
  void _table(Canvas canvas, Size size, LmView view, EmbeddingLayout layout, double beat) {
    final double leaving = 1 - _span(beat, _tableOut);
    if (beat < _tableIn.$1 || leaving <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int count = trace.vocab.length;
    final int width = trace.model.width;
    for (int id = 0; id < count; id++) {
      final double start = _tableIn.$1 + (count < 2 ? 0 : id / (count - 1)) * (_tableIn.$2 - _tableIn.$1 - _entryIn);
      final double shown = through(beat, start, start + _entryIn) * leaving;
      if (shown > 0) {
        TokeniseScene.drawEntry(canvas, view, layout.chip(id), id, 1, layout.idSize, alpha: shown);
      }
    }
    final double grow = _span(beat, _grow);
    if (grow <= 0) {
      return;
    }
    // Each row grows from its token outwards, a soft front a few numbers wide.
    final double front = math.max(2, width / 5);
    final double reach = grow * (width + front);
    final double scale = ForwardScene.scales(view).$1;
    // From the gather on, a row read is drawn by the places' copies of it.
    final Set<int> copied = beat < _gatherFrom
        ? <int>{}
        : <int>{for (int i = 0; i < view.focus.inputs; i++) trace.inputAt(view.peptide, i)};
    for (int id = 0; id < count; id++) {
      if (copied.contains(id)) {
        continue;
      }
      layout.fill(canvas, layout.row(id), <Color>[
        for (int d = 0; d < width; d++)
          Color.lerp(
            view.inks.ground,
            view.inks.cell(trace.tokenEmbedding(view.checkpoint, id, d) / scale),
            ((reach - d) / front).clamp(0.0, 1.0) * leaving,
          )!,
      ]);
    }
    final TextStyle? style = layout.numberStyle;
    if (style != null) {
      _faded(canvas, size, view, _span(beat, _written) * leaving, () {
        for (int id = 0; id < count; id++) {
          if (copied.contains(id)) {
            continue;
          }
          layout.write(canvas, layout.row(id), <String>[
            for (int d = 0; d < width; d++) fixed(trace.tokenEmbedding(view.checkpoint, id, d), EmbeddingLayout.digits),
          ], style);
        }
      });
    }
    // The rows read: lit while read, then marked.
    final int n = view.focus.inputs;
    final List<double> lit = List<double>.filled(count, 0);
    final List<bool> read = List<bool>.filled(count, false);
    for (int i = 0; i < n; i++) {
      final int id = trace.inputAt(view.peptide, i);
      final double f = _lookup(i, n, beat);
      lit[id] = math.max(lit[id], _lit(f));
      read[id] = read[id] || f >= 0.5;
    }
    for (int id = 0; id < count; id++) {
      final double on = math.max(lit[id], read[id] ? _marked : 0) * leaving;
      if (on <= 0) {
        continue;
      }
      final Rect row = layout.row(id);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(layout.chip(id).left - 3, row.top, row.right + 1, row.bottom),
          const Radius.circular(3),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: on),
      );
    }
  }

  /// How strongly a row already read stays marked.
  static const double _marked = 0.3;

  /// x's rows: each place's copy of the row it read, its numbers going,
  /// moving to its own row, and its numbers back; then each place's own row
  /// of the position embedding, alone on its own scale, then added: the
  /// sum, x0.
  void _rows(Canvas canvas, Size size, LmView view, EmbeddingLayout layout, double beat) {
    if (beat < _gatherFrom) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int n = view.focus.inputs;
    final int width = trace.model.width;
    final double scale = ForwardScene.scales(view).$1;
    final double placeScale = _placeScale(view);
    final double alone = _span(beat, _placesIn) * (1 - _span(beat, _placesOut));
    // One set of numbers in a cell at a time: the token's go before the
    // position's come, and those go before the sums come.
    final double sumsShown = 1 - _span(beat, _tokensUnwritten) + _span(beat, _sumsWritten);
    final double placesShown = _span(beat, _placesWritten) * (1 - _span(beat, _placesUnwritten));
    final double add = _span(beat, _add);
    final List<double> gathered = <double>[for (int i = 0; i < n; i++) _gather(i, n, beat)];
    // A copy's numbers go before it moves and come back once it has.
    final List<double> moved = <double>[for (final double g in gathered) through(g, _moveFrom, _moveTo)];
    final List<double> still = <double>[
      for (final double g in gathered) 1 - through(g, 0, _moveFrom) + through(g, _moveTo, 1),
    ];
    final List<Rect> rows = <Rect>[
      for (int i = 0; i < n; i++) Rect.lerp(layout.row(trace.inputAt(view.peptide, i)), layout.row(i), moved[i])!,
    ];
    // A row read by several places lies under all their copies until they
    // leave it: drawn once.
    final Set<int> waiting = <int>{};
    final List<bool> drawn = <bool>[
      for (int i = 0; i < n; i++) gathered[i] > 0 || waiting.add(trace.inputAt(view.peptide, i)),
    ];
    final List<List<double>> values = <List<double>>[
      for (int i = 0; i < n; i++) <double>[for (int d = 0; d < width; d++) _value(view, i, d, add)],
    ];
    void fill(int i) => layout.fill(canvas, rows[i], <Color>[
      for (int d = 0; d < width; d++)
        alone <= 0
            ? view.inks.cell(values[i][d] / scale)
            : Color.lerp(
                view.inks.cell(values[i][d] / scale),
                view.inks.cell(trace.positionEmbedding(view.checkpoint, i, d) / placeScale),
                alone,
              )!,
    ]);
    // The rows at rest first, numbers and all, then those moving over them.
    bool resting(int i) => moved[i] <= 0 || moved[i] >= 1;
    for (int i = 0; i < n; i++) {
      if (drawn[i] && resting(i)) {
        fill(i);
      }
    }
    final TextStyle? sums = layout.numberStyle;
    if (sums != null) {
      _faded(canvas, size, view, sumsShown, () {
        for (int i = 0; i < n; i++) {
          if (!drawn[i] || still[i] <= 0) {
            continue;
          }
          layout.write(
            canvas,
            rows[i],
            <String>[for (int d = 0; d < width; d++) fixed(values[i][d], EmbeddingLayout.digits)],
            still[i] >= 1 ? sums : sums.copyWith(color: sums.color!.withValues(alpha: (still[i] * 8).round() / 8)),
          );
        }
      });
    }
    final TextStyle? positions = layout.numberStyle;
    if (positions != null) {
      _faded(canvas, size, view, placesShown, () {
        for (int i = 0; i < n; i++) {
          layout.write(canvas, rows[i], <String>[
            for (int d = 0; d < width; d++) fixed(trace.positionEmbedding(view.checkpoint, i, d), EmbeddingLayout.digits),
          ], positions);
        }
      });
    }
    for (int i = 0; i < n; i++) {
      if (drawn[i] && !resting(i)) {
        fill(i);
      }
    }
  }

  /// Place [i]'s number [d]: its token's, with [add] of its place's added;
  /// all of it, x0.
  static double _value(LmView view, int i, int d, double add) {
    final TrainingTrace trace = view.trace;
    final double token = trace.tokenEmbedding(view.checkpoint, trace.inputAt(view.peptide, i), d);
    final double place = trace.positionEmbedding(view.checkpoint, i, d);
    return add >= 1 ? token + place : token + add * place;
  }

  /// x0's row [i] as the stage leaves it, across [rect], its numbers at
  /// [textAlpha] and its tiles unless [fills] is false: what Forward stands
  /// up.
  static void drawX0Row(
    Canvas canvas,
    LmView view,
    EmbeddingLayout layout,
    Rect rect,
    int i, {
    double textAlpha = 1,
    bool fills = true,
  }) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final double scale = ForwardScene.scales(view).$1;
    final List<double> values = <double>[for (int d = 0; d < width; d++) _value(view, i, d, 1)];
    if (fills) {
      layout.fill(canvas, rect, <Color>[for (final double v in values) view.inks.cell(v / scale)]);
    }
    final TextStyle? style = layout.numberStyle;
    if (style != null && textAlpha > 0) {
      layout.write(
        canvas,
        rect,
        <String>[for (final double v in values) fixed(v, EmbeddingLayout.digits)],
        textAlpha >= 1 ? style : style.copyWith(color: style.color!.withValues(alpha: (textAlpha * 8).round() / 8)),
      );
    }
  }

  /// The peptide in focus, x's row of it: its places come down from Shift's
  /// to the foot, its ids kept, the rest, whose targets are padding, gone;
  /// each lit while it reads; then each goes up to label its row, turning
  /// back into its residue.
  void _focusRow(Canvas canvas, LmView view, EmbeddingLayout layout, double beat, EmbeddingFade fade) {
    final TrainingTrace trace = view.trace;
    final int p = view.peptide;
    final List<int> ids = TokeniseScene.frameOf(trace, p);
    final int residues = view.focus.sequence.length;
    final int n = view.focus.inputs;
    final double descend = _span(beat, _descend);
    // Its name, as Shift writes it over its lines, comes down with it and
    // stays over it until its tiles go up to the rows.
    final double named = 1 - through(beat, _gatherFrom, _gatherFrom + _gatherStagger);
    if (named > 0) {
      view.kit.draw(
        canvas,
        '${view.focus.source.label} · $residues aa',
        inked(view.kit.sans, 10, view.inks.ink, alpha: named),
        Offset.lerp(
          Offset(layout.shift.left, layout.shift.rowTop(p)),
          Offset(layout.foot(0).left, layout.footTop - ShiftLayout.label),
          descend,
        )!,
      );
    }
    for (int k = 0; k < ids.length - 1; k++) {
      final Rect from = layout.shift.x(p, k);
      if (k >= n) {
        _tile(canvas, view, from, ids, k, residues, (1 - ShiftScene.dimmed) * (1 - descend));
        continue;
      }
      final double gather = _gather(k, n, beat);
      if (gather >= 1) {
        if (fade.rows) {
          drawToken(canvas, view, layout.label(k), ids[k]);
        }
        continue;
      }
      final Rect foot = Rect.lerp(from, layout.foot(k), descend)!;
      if (gather <= 0) {
        _tile(canvas, view, foot, ids, k, residues, 1);
        final double lit = _lit(_lookup(k, n, beat));
        if (lit > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(foot.inflate(1), Radius.circular(foot.width * 0.2)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = view.inks.signal.withValues(alpha: lit),
          );
        }
        continue;
      }
      final Rect rect = Rect.lerp(foot, layout.label(k), through(gather, _moveFrom, _moveTo))!;
      final double flip = 1 - through(gather, 0.3, 0.7);
      if (k == 0 || flip <= 0) {
        drawToken(canvas, view, rect, ids[k]);
      } else {
        TokeniseScene.drawFlip(canvas, view, rect, ids[k], flip, numberScale: ShiftScene.numberScale);
      }
    }
  }

  /// A place of Shift's x, as it draws it: an end or padding as a token, a
  /// residue as its id.
  static void _tile(Canvas canvas, LmView view, Rect rect, List<int> ids, int k, int residues, double alpha) {
    if (alpha <= 0) {
      return;
    }
    if (k == 0 || k > residues) {
      drawToken(canvas, view, rect, ids[k], alpha: alpha);
    } else {
      drawIdTile(canvas, view, rect, ids[k], alpha: alpha, numberScale: ShiftScene.numberScale);
    }
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

  // ------------------------------------------------------------------ taps

  /// Once the row has come down, a tile puts its place in focus; once the
  /// rows have gathered, a row does.
  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final double beat = frame.local * LmStage.embedding.beats;
    if (beat < _descend.$2) {
      return null;
    }
    final EmbeddingLayout layout = EmbeddingLayout(size, view);
    final int? i = beat < _gatherFrom ? layout.footAt(at) : layout.placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = EmbeddingLayout(size, view).placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) => EmbeddingLayout(size, view).placeAt(at);

  // -------------------------------------------------------------- caption

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * LmStage.embedding.beats;
    final int width = trace.model.width;
    final int inputs = view.focus.inputs;
    if (beat < _numbersCaption) {
      return 'The token embedding, ${grouped(trace.vocab.length)} × $width, learned with the rest of the model';
    }
    if (beat < _lookupCaption) {
      final String moved = view.step == 1
          ? 'At step 1 no update has moved them yet'
          : 'At step ${view.step} they have had ${grouped(view.step - 1)} updates';
      return _padStill(trace) ? "$moved; <pad>'s row is zero at every checkpoint" : moved;
    }
    if (beat < _gatherCaption) {
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
      return '${grouped(inputs)} places read ${grouped(uses.length)} rows of the table$again';
    }
    if (beat < _placesCaption) {
      return 'In place order, the rows read are x embedded: ${grouped(inputs)} × $width, a row a place';
    }
    if (beat < _x0Caption) {
      final int times = smaller(view);
      final String rows = 'Adding the position embedding, rows 0–${inputs - 1}';
      return times < 2 ? rows : '$rows, ${grouped(times)}× smaller than the token rows';
    }
    return 'x0, ${grouped(inputs)} × $width: the start of the residual stream';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Embedding, step ${view.step}. ${caption(view, frame)}.';
}

/// What Embedding's last frame leaves out or fades, for the stage that opens
/// on it: x0's rows and their tiles, which Forward stands up itself, and the
/// tag. By default, the frame as Embedding draws it.
@immutable
final class EmbeddingFade {
  const EmbeddingFade({this.rows = true, this.chrome = 1});

  /// Whether x's rows and the tiles that label them are drawn.
  final bool rows;

  /// The tag.
  final double chrome;
}

/// Top to bottom: the note, why; the tag; the matrix, a row a token and then a row a
/// place, its numbers across the width, 4 pt from either side, after a
/// gutter for the row's id or tile, every row as tall as the canvas allows
/// for the longer of the two; and at the foot, the peptide in focus under
/// its name, a tile a place, on one line.
final class EmbeddingLayout {
  EmbeddingLayout(Size size, LmView view)
    : shift = ShiftLayout(size, view),
      right = size.width - _side,
      kit = view.kit,
      places = view.focus.inputs {
    final TrainingTrace trace = view.trace;
    final int inputs = places;
    final int width = trace.model.width;
    rows = math.max(trace.vocab.length, inputs);
    final double span = right - left;
    footStep = math.min(_mostFoot, span / inputs);
    footTile = Size(footStep, math.min(_mostFoot, math.max(footStep, idNumbered + 2)));
    footLeft = left + (span - (inputs - 1) * footStep - footTile.width) / 2;
    final double tag = tagSize(view, 'token embedding').height;
    noteLeft = left + tagPadding;
    final double note = EmbeddingScene.noteHeight(view, right - noteLeft) + _noteGap;
    final double room =
        size.height - 2 * _edge - note - tag - _tagGap - _footGap - ShiftLayout.label - footTile.height;
    pitch = math.min(_mostPitch, room / rows);
    final double content = note + tag + _tagGap + rows * pitch + _footGap + ShiftLayout.label + footTile.height;
    noteTop = math.max(_edge, (size.height - content) / 2);
    tagTop = noteTop + note;
    tableTop = tagTop + tag + _tagGap;
    footTop = tableTop + rows * pitch + _footGap + ShiftLayout.label;
    chipSide = (pitch - 3).clamp(3.0, 14.0);
    idSize = (pitch * 0.62).clamp(6.0, 9.5);
    idWidth = view.kit
            .layout('8' * '${trace.vocab.length - 1}'.length, inked(view.kit.mono, idSize, view.inks.quiet))
            .width +
        _idGap;
    cellsLeft = left + idWidth + chipSide + _chipGap;
    cell = (right - cellsLeft) / width;
    numberStyle = _style(view, _largest(view));
  }

  /// From the canvas's sides, as little as keeps the matrix off the
  /// screen's edge, so its numbers have the width.
  static const double _side = 4;

  /// From an id to its token's tile (`TokeniseScene.drawEntry` sets it
  /// there), and from the tile to the row's numbers.
  static const double _idGap = 5;
  static const double _chipGap = 3;

  /// From the canvas's edge, from the tag to the matrix, and from the matrix
  /// to the foot.
  static const double _edge = 6;
  static const double _tagGap = 6;

  /// From the note to the tag.
  static const double _noteGap = 8;
  static const double _footGap = 14;

  /// The tallest a row is drawn, however much room the canvas has.
  static const double _mostPitch = 22;

  /// The largest a tile at the foot is drawn.
  static const double _mostFoot = 22;

  /// Between two numbers' tiles, and their corners.
  static const double gap = 1;
  static const double radius = 3;

  /// The smallest a number is written; a row too small for it is drawn in
  /// its colours alone.
  static const double leastNumber = 5.5;

  /// Shift's layout, which the stage opens on.
  final ShiftLayout shift;

  final LmKit kit;

  /// The peptide in focus's places.
  final int places;

  final double left = _side;
  final double right;

  /// The note over the tag: its top, and its left edge, under the tag's
  /// words.
  late final double noteTop;
  late final double noteLeft;

  /// As many rows as the longer of the vocabulary and the peptide in focus.
  late final int rows;
  late final double pitch;
  late final double tagTop;
  late final double tableTop;

  /// The foot's tiles: their size, from one to the next, and the first's left
  /// edge.
  late final Size footTile;
  late final double footStep;
  late final double footLeft;
  late final double footTop;

  /// A token's tile beside its row, and its id's size and room left of it.
  late final double chipSide;
  late final double idSize;
  late final double idWidth;

  /// Where the numbers start, and how wide each one's cell is.
  late final double cellsLeft;
  late final double cell;

  /// How many places every number is written to: the tables are kept whole,
  /// so a position row's hundredths show, and so does their adding.
  static const int digits = 2;

  /// What every number is written in, the token rows', the position rows'
  /// and their sums'; null where the cells are too small for numbers.
  late final TextStyle? numberStyle;

  /// The largest number written: of the table, or of a place in focus's
  /// position row or sum.
  static double _largest(LmView view) => view.kit.memo<double>(
    ('embedding-largest', view.step, view.peptide),
    () {
      final TrainingTrace trace = view.trace;
      double most = 0;
      for (int id = 0; id < trace.vocab.length; id++) {
        for (int d = 0; d < trace.model.width; d++) {
          most = math.max(most, trace.tokenEmbedding(view.checkpoint, id, d).abs());
        }
      }
      for (int i = 0; i < view.focus.inputs; i++) {
        final int id = trace.inputAt(view.peptide, i);
        for (int d = 0; d < trace.model.width; d++) {
          final double place = trace.positionEmbedding(view.checkpoint, i, d);
          most = math.max(most, math.max(place.abs(), (trace.tokenEmbedding(view.checkpoint, id, d) + place).abs()));
        }
      }
      return most;
    },
  );

  /// The numbers' face at the largest size up to 9 points at which the
  /// widest of them fits its cell and its row, or null below [leastNumber].
  TextStyle? _style(LmView view, double largest) {
    final int whole = '${largest.floor()}'.length;
    final String widest = '−${'8' * whole}.${'8' * digits}';
    TextStyle at(double points) => inked(view.kit.mono, points, view.inks.ink).copyWith(letterSpacing: 0);
    final double perPoint = view.kit.layout(widest, at(10)).width / 10;
    // Held to the half point below, so a number is never wider than drawn.
    final double points = (math.min(9, math.min(pitch * 0.62, (cell - 2 * gap - 2) / perPoint)) * 2).floorToDouble() / 2;
    return points < leastNumber ? null : at(points);
  }

  /// Token [id]'s tile beside its row.
  Rect chip(int id) => Rect.fromLTWH(
    left + idWidth,
    tableTop + id * pitch + (pitch - chipSide) / 2,
    chipSide,
    chipSide,
  );

  /// The tile that labels place [i]'s row once gathered: where a token's
  /// tile sits beside its row.
  Rect label(int i) => chip(i);

  /// Row [r]'s numbers.
  Rect row(int r) => Rect.fromLTRB(cellsLeft, tableTop + r * pitch, right, tableTop + (r + 1) * pitch);

  /// Place [i]'s tile at the foot.
  Rect foot(int i) => Rect.fromLTWH(footLeft + i * footStep, footTop, footTile.width, footTile.height);

  /// The place whose tile at the foot lies under [at].
  int? footAt(Offset at, {double slack = 12}) {
    if (at.dy < footTop - slack || at.dy > footTop + footTile.height + slack) {
      return null;
    }
    final int i = ((at.dx - footLeft) / footStep).floor();
    return i < 0 || i >= places ? null : i;
  }

  /// The place whose row lies under [at], once the rows have gathered.
  int? placeAt(Offset at) {
    if (at.dx < left || at.dx > right || at.dy < tableTop) {
      return null;
    }
    final int i = ((at.dy - tableTop) / pitch).floor();
    return i < 0 || i >= places ? null : i;
  }

  /// [fills] across [rect], a soft-cornered tile each, inset by [gap].
  void fill(Canvas canvas, Rect rect, List<Color> fills, {double gap = EmbeddingLayout.gap, double radius = EmbeddingLayout.radius}) {
    final double w = rect.width / fills.length;
    final Paint paint = Paint();
    for (int d = 0; d < fills.length; d++) {
      final Rect tile = Rect.fromLTWH(rect.left + d * w, rect.top, w, rect.height).deflate(gap);
      canvas.drawRRect(RRect.fromRectAndRadius(tile, Radius.circular(radius)), paint..color = fills[d]);
    }
  }

  /// [texts] across [rect], each centred in its cell.
  void write(Canvas canvas, Rect rect, List<String> texts, TextStyle style) {
    final double w = rect.width / texts.length;
    for (int d = 0; d < texts.length; d++) {
      kit.draw(canvas, texts[d], style, Offset(rect.left + (d + 0.5) * w, rect.center.dy), anchor: const Offset(0.5, 0.5));
    }
  }
}
