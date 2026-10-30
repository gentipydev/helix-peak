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
/// the canvas, its ids kept. Over it comes the token embedding, a row of
/// numbers a token, each number written out on a soft tile of its colour.
/// Each id lights the row it reads; the rows read gather in place order, x
/// embedded, a row a place, each labelled by the tile that read it; each
/// place's own row of the position embedding is added; and the matrix is
/// `x0` as the run kept it, which Forward stands up as its stream.
///
/// Every number is the run's: the tables the step read its ids through, and
/// the stream's first point, which the sum is to within its rounding.
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

  // The lookup: the first place alone, long enough to be followed, then the
  // rest left to right, closer and closer.
  static const (double, double) _first = (2.4, 3.3);
  static const double _restFrom = 3.4;
  static const double _restTo = 5.4;
  static const double _dwell = 0.5;
  static const double _quickening = 0.7;

  // The gather: the table goes, and each place's copy of the row it read
  // moves to the place's own row, the tile that read it going up to label
  // it and turning back into its residue.
  static const (double, double) _tableOut = (5.4, 6.0);
  static const double _gatherFrom = 5.4;
  static const double _gatherStagger = 0.5;
  static const double _gatherFlight = 1.0;

  /// The part of a copy's flight it moves in: its numbers go before, and
  /// come back after.
  static const double _moveFrom = 0.15;
  static const double _moveTo = 0.85;

  // The position embedding: each place's row alone, on its own scale, then
  // added; then x0 as the run kept it.
  static const (double, double) _placesIn = (7.0, 7.4);
  static const (double, double) _placesOut = (7.7, 8.1);
  static const (double, double) _tokensUnwritten = (7.0, 7.2);
  static const (double, double) _placesWritten = (7.2, 7.4);
  static const (double, double) _placesUnwritten = (7.7, 7.9);
  static const (double, double) _sumsWritten = (7.9, 8.1);
  static const (double, double) _add = (7.8, 8.2);
  static const (double, double) _kept = (8.4, 8.9);

  /// Where the caption turns: to what the numbers are, the first lookup, the
  /// rest, the gather, the position embedding and x0.
  static const double _numbersCaption = 1.4;
  static const double _firstCaption = 2.4;
  static const double _restCaption = 3.4;
  static const double _gatherCaption = 5.4;
  static const double _placesCaption = 7.0;
  static const double _x0Caption = 8.4;

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
        ),
      );
    }
    _tags(canvas, view, layout, beat, fade);
    _table(canvas, size, view, layout, beat);
    if (fade.rows) {
      _rows(canvas, size, view, layout, beat);
    }
    _focusRow(canvas, view, layout, beat, fade);
  }

  // --------------------------------------------------------------- numbers

  /// How far place [i]'s lookup has got, of [n] places: its tile and its row
  /// lit while it reads.
  static double _lookup(int i, int n, double beat) {
    if (i == 0) {
      return _span(beat, _first);
    }
    final double start =
        _restFrom + (n < 3 ? 0 : math.pow((i - 1) / (n - 2), _quickening) * (_restTo - _dwell - _restFrom));
    return through(beat, start, start + _dwell);
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

  // ---------------------------------------------------------------- paint

  /// The matrix's name, each in turn at the top left: the token embedding,
  /// x embedded, the position embedding's rows, and x0.
  void _tags(Canvas canvas, LmView view, EmbeddingLayout layout, double beat, EmbeddingFade fade) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int inputs = view.focus.inputs;
    final Offset at = Offset(layout.left - 2, layout.tagTop);
    for (final (String text, double alpha) in <(String, double)>[
      (
        'token embedding · ${trace.vocab.length} × $width',
        _span(beat, _tableIn) * (1 - through(beat, _tableOut.$1, _tableOut.$1 + 0.3)),
      ),
      (
        'x embedded · $inputs × $width',
        through(beat, 6.0, 6.4) * (1 - through(beat, 6.8, 7.0)),
      ),
      (
        'position embedding · first $inputs of ${trace.model.context} rows',
        through(beat, 7.0, 7.25) * (1 - through(beat, 7.9, 8.15)),
      ),
      ('x0 · $inputs × $width', through(beat, 8.15, 8.4) * fade.chrome),
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
    final TextStyle? style = layout.tokenStyle;
    if (style != null) {
      _faded(canvas, size, view, _span(beat, _written) * leaving, () {
        for (int id = 0; id < count; id++) {
          if (copied.contains(id)) {
            continue;
          }
          layout.write(canvas, layout.row(id), <String>[
            for (int d = 0; d < width; d++) fixed(trace.tokenEmbedding(view.checkpoint, id, d), layout.tokenPlaces),
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
      lit[id] = math.max(lit[id], math.sin(math.pi * f));
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
  /// of the position embedding, alone on its own scale, then added; and at
  /// the last, x0 as the run kept it.
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
    final double kept = _span(beat, _kept);
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
      for (int i = 0; i < n; i++) <double>[for (int d = 0; d < width; d++) _value(view, i, d, add, kept)],
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
    final TextStyle? sums = layout.tokenStyle;
    if (sums != null) {
      final int places = kept >= 0.5 ? layout.streamPlaces : layout.tokenPlaces;
      _faded(canvas, size, view, sumsShown, () {
        for (int i = 0; i < n; i++) {
          if (!drawn[i] || still[i] <= 0) {
            continue;
          }
          layout.write(
            canvas,
            rows[i],
            <String>[for (int d = 0; d < width; d++) fixed(values[i][d], places)],
            still[i] >= 1 ? sums : sums.copyWith(color: sums.color!.withValues(alpha: (still[i] * 8).round() / 8)),
          );
        }
      });
    }
    final TextStyle? positions = layout.placeStyle;
    if (positions != null) {
      _faded(canvas, size, view, placesShown, () {
        for (int i = 0; i < n; i++) {
          layout.write(canvas, rows[i], <String>[
            for (int d = 0; d < width; d++) fixed(trace.positionEmbedding(view.checkpoint, i, d), layout.placePlaces),
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

  /// Place [i]'s number [d]: its token's, with [add] of its place's added,
  /// and [kept] of the way to x0 as the run kept it.
  static double _value(LmView view, int i, int d, double add, double kept) {
    final TrainingTrace trace = view.trace;
    final double token = trace.tokenEmbedding(view.checkpoint, trace.inputAt(view.peptide, i), d);
    final double sum = token + add * trace.positionEmbedding(view.checkpoint, i, d);
    if (kept <= 0) {
      return sum;
    }
    // At the last, x0 itself, number for number, as Forward stands it up.
    final double x0 = trace.stream(view.checkpoint, 0, view.peptide, i, d);
    return kept >= 1 ? x0 : sum + (x0 - sum) * kept;
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
    final List<double> values = <double>[
      for (int d = 0; d < width; d++) trace.stream(view.checkpoint, 0, view.peptide, i, d),
    ];
    if (fills) {
      layout.fill(canvas, rect, <Color>[for (final double v in values) view.inks.cell(v / scale)]);
    }
    final TextStyle? style = layout.tokenStyle;
    if (style != null && textAlpha > 0) {
      layout.write(
        canvas,
        rect,
        <String>[for (final double v in values) fixed(v, layout.streamPlaces)],
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
        final double lit = math.sin(math.pi * _lookup(k, n, beat));
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
      return 'The token embedding: $width learned numbers for each of the ${grouped(trace.vocab.length)} tokens';
    }
    if (beat < _firstCaption) {
      final String moved = view.step == 1
          ? 'At step 1 no update has moved them yet'
          : 'At step ${view.step} they have had ${grouped(view.step - 1)} updates';
      return _padStill(trace) ? "$moved; <pad>'s row is zero at every checkpoint" : moved;
    }
    if (beat < _restCaption) {
      final int id = trace.inputAt(view.peptide, 0);
      return '${trace.token(id)} is id $id, so it reads row $id of the table';
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
      return 'Each id picks its row of $width: ${grouped(inputs)} places read '
          '${grouped(uses.length)} rows$again';
    }
    if (beat < _placesCaption) {
      return 'In place order, the rows read are x embedded: ${grouped(inputs)} × $width, a row a place';
    }
    if (beat < _x0Caption) {
      final int times = smaller(view);
      return times < 2
          ? 'Plus each place\'s own row of the position embedding'
          : 'Plus each place\'s own row of the position embedding, '
                '${grouped(times)}× smaller than its token\'s';
    }
    return 'x0: ${grouped(inputs)} × $width numbers, what the blocks read';
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

/// Top to bottom: the tag; the matrix, a row a token and then a row a
/// place, its numbers across the width after a gutter for the row's id or
/// tile, every row as tall as the canvas allows for the longer of the two;
/// and at the foot, the peptide in focus, a tile a place, on one line.
final class EmbeddingLayout {
  EmbeddingLayout(Size size, LmView view)
    : shift = ShiftLayout(size, view),
      right = size.width - 16,
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
    final double room = size.height - 2 * _edge - tag - _tagGap - _footGap - footTile.height;
    pitch = math.min(_mostPitch, room / rows);
    final double content = tag + _tagGap + rows * pitch + _footGap + footTile.height;
    tagTop = math.max(_edge, (size.height - content) / 2);
    tableTop = tagTop + tag + _tagGap;
    footTop = tableTop + rows * pitch + _footGap;
    chipSide = (pitch - 3).clamp(3.0, 14.0);
    idSize = (pitch * 0.62).clamp(6.0, 9.5);
    idWidth = view.kit
            .layout('8' * '${trace.vocab.length - 1}'.length, inked(view.kit.mono, idSize, view.inks.quiet))
            .width +
        6;
    cellsLeft = left + idWidth + chipSide + 6;
    cell = (right - cellsLeft) / width;

    final TraceCheckpoint at = view.checkpoint;
    tokenPlaces = placesFor(at.tokenEmbeddingScale);
    placePlaces = placesFor(at.positionEmbeddingScale);
    streamPlaces = placesFor(at.streamScales[0]);
    final (double tokens, double positions) = _largest(view);
    tokenStyle = _style(view, tokens, math.max(tokenPlaces, streamPlaces));
    placeStyle = _style(view, positions, placePlaces);
  }

  /// From the canvas's edge, from the tag to the matrix, and from the matrix
  /// to the foot.
  static const double _edge = 6;
  static const double _tagGap = 6;
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

  final double left = 16;
  final double right;

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

  /// How many places each array's numbers are written to: as many as its
  /// stored step allows.
  late final int tokenPlaces;
  late final int placePlaces;
  late final int streamPlaces;

  /// What the token rows, their sums and x0 are written in, and the
  /// position rows; null where the cells are too small for numbers.
  late final TextStyle? tokenStyle;
  late final TextStyle? placeStyle;

  /// The largest token row number, sum or x0, and the largest position row
  /// number, over the table and the places in focus.
  static (double, double) _largest(LmView view) => view.kit.memo<(double, double)>(
    ('embedding-largest', view.step, view.peptide),
    () {
      final TrainingTrace trace = view.trace;
      double tokens = 0;
      double places = 0;
      for (int id = 0; id < trace.vocab.length; id++) {
        for (int d = 0; d < trace.model.width; d++) {
          tokens = math.max(tokens, trace.tokenEmbedding(view.checkpoint, id, d).abs());
        }
      }
      for (int i = 0; i < view.focus.inputs; i++) {
        final int id = trace.inputAt(view.peptide, i);
        for (int d = 0; d < trace.model.width; d++) {
          final double place = trace.positionEmbedding(view.checkpoint, i, d);
          places = math.max(places, place.abs());
          tokens = math.max(tokens, (trace.tokenEmbedding(view.checkpoint, id, d) + place).abs());
          tokens = math.max(tokens, trace.stream(view.checkpoint, 0, view.peptide, i, d).abs());
        }
      }
      return (tokens, places);
    },
  );

  /// The numbers' face at the largest size up to 9 points at which the
  /// widest of them fits its cell and its row, or null below [leastNumber].
  TextStyle? _style(LmView view, double largest, int places) {
    final int whole = '${largest.floor()}'.length;
    final String widest = '−${'8' * whole}${places > 0 ? '.${'8' * places}' : ''}';
    TextStyle at(double points) => inked(view.kit.mono, points, view.inks.ink).copyWith(letterSpacing: 0);
    final double perPoint = view.kit.layout(widest, at(10)).width / 10;
    // Held to the half point below, so a number is never wider than drawn.
    final double points = (math.min(9, math.min(pitch * 0.62, (cell - 2 * gap - 1) / perPoint)) * 2).floorToDouble() / 2;
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
