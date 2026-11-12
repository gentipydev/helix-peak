import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import '../lm_info_sheet.dart';
import '../lm_inks.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';
import 'weight_flow.dart';
import 'worked_answer.dart';

/// When one head does each part of its reading, in beats: its keys come, the
/// query passes every key up to its own place and goes, the scores become
/// shares, the values flow; and when it is done.
typedef HeadTimes = ({double keys, double scan, double soft, double shares, double values, double end});

/// Attention, block 1's first part after Scores, as the engine runs it
/// (`nn.MultiheadAttention`). It opens on Scores' last frame: head 1's keys,
/// its scores and its shares at the place in focus. Each key turns into its
/// place's value, and arcs carry each share of each value into the head's
/// answer. The other heads follow quicker, each its own keys, query, scores
/// and shares. Then number 1 of head 1's answer is worked out
/// ([WorkedAnswer]): the answers stand up off the row at the bench's right
/// edge, faint and unwritten, number 1 an empty slot; where each place's
/// value comes from, the same weights for every place, and what each brings,
/// its share of it, summed; then the answers are written, side by side,
/// where Scores stood the evened row. Then they flow through the output
/// weights into what attention adds, as
/// Scores makes a query: number 1 alone and slowly, then the rest in one
/// cascade; the column made lies down onto the row in focus.
/// Every place does the same at once: the table narrows to its token
/// column and head 1's map takes the width beside it, a row a place, the
/// tiles naming its rows, and under it its columns; the place in focus's row
/// fills first, with the shares Scores found, then every other row. Then
/// head 2's map takes the same rows, filled the same way: what attention
/// adds is both heads' answers through the output weights. Last, the table
/// widens again: what attention adds to each place, alone, and then added,
/// x0 + block 1's attention, the first point of the stream after x0. What
/// the stage names, the block's parts and sums, it names as block 1's.
///
/// Every number is the run's: the scores, the shares, and each point of the
/// stream, whole.
final class AttentionScene extends LmScene {
  const AttentionScene();

  /// The block this stage shows; Forward shows them all.
  static const int block = 0;

  static double get _beats => LmStage.attention.beats.toDouble();

  // The heads: the first hands its values over, the others read in full and
  // share what is left before the join.
  static const double _firstHeadTo = 1.6;
  static const double _joinFrom = 4.4;
  static const double _mapFrom = 16.3;
  static const double _widenFrom = 21.7;
  static const double _widenTo = 22.5;

  // Number 1 of head 1's answer worked out, as soon as head 2 has read: the
  // answers stand up off the row in focus into its column, and it ends on
  // them written, where Scores stood the evened row, for the output weights.
  // Everything after it is [WorkedAnswer.beats] later.
  static const double _mixFrom = _joinFrom;
  static const double _mixTo = _mixFrom + WorkedAnswer.beats;

  // The heads' answers through the output weights, standing where Scores
  // stood the evened row, a slice a head: an empty column stands where
  // Scores stood the query, the weights' plate under the strings; the row
  // flows through them, number 1 alone and slowly, then the rest in one
  // cascade; the bench clears, and the column made, what attention adds,
  // lies down where the answers sat. Its box comes, and the map grows out
  // of it.
  static const (double, double) _outSlotsIn = (13.4, 13.65);
  static const (double, double) _outPlateIn = (13.5, 13.75);
  static const WeightFlow _outFlow = WeightFlow(
    alone: <(double, double)>[(13.8, 14.4)],
    cascade: (14.55, 15.35),
    webOut: (15.65, 15.9),
    firstRelax: 0.3,
  );
  static const (double, double) _benchOut = (15.65, 15.9);
  static const (double, double) _outNumbersOut = (15.65, 15.75);
  static const (double, double) _lieDown = (15.75, 16.2);
  static const (double, double) _boxIn = (16.05, 16.25);

  // Scores' bars of head 1's shares go as its arcs come.
  static const (double, double) _barsOut = (0.0, 0.6);

  // Head 1's map, out of the heads' answers. x0's tag goes, and the answers'
  // numbers and names. Their box grows from the row in focus into the map,
  // up to the first row, down to the last and left to the token column, as
  // the table narrows to its tiles at the same pace; inside it, the map's
  // empty slots, the places after each row hatched. The box's outline goes
  // once it is the map's, and the map's tag comes. The place in focus's row
  // fills, a cell at a time, then every other row, top to bottom; then it
  // holds.
  static const (double, double) _x0TagOut = (16.3, 16.5);
  static const (double, double) _answersOut = (16.3, 16.45);
  static const (double, double) _grow = (16.35, 17.0);
  static const (double, double) _boxOut = (16.95, 17.2);
  static const (double, double) _mapIn = (16.35, 16.6);
  static const (double, double) _mapTagIn = (16.7, 16.9);
  static const (double, double) _focusRow = (17.0, 17.8);
  static const (double, double) _rows = (17.9, 18.7);

  // Then head 2's map on the same rows (the user's ask of 2026-11-02: what
  // attention adds mixes both heads' answers): head 1's cells empty to their
  // slots and its tag goes, head 2's tag comes, and its map fills as head
  // 1's did, a little quicker; then it holds. The heads after the first
  // share this span between them.
  static const double _mapTurnFrom = 19.4;

  // What attention added, alone on its own scale, then the sums.
  static const (double, double) _alone = (21.7, 22.3);
  static const (double, double) _gainWritten = (22.5, 22.7);
  static const (double, double) _gainUnwritten = (23.1, 23.3);
  static const (double, double) _add = (23.2, 23.6);
  static const (double, double) _sumsWritten = (23.4, 23.6);

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// When head [h] of [heads] does each part. Head 1 read in Scores: its keys
  /// are out, every score written and its query gone; here its scores become
  /// shares as its values come.
  static HeadTimes times(int h, int heads) {
    if (h == 0 || heads < 2) {
      return (keys: -3, scan: -2.5, soft: -0.5, shares: 0, values: 0, end: _firstHeadTo);
    }
    final double span = (_joinFrom - _firstHeadTo) / (heads - 1);
    final double start = _firstHeadTo + (h - 1) * span;
    return (
      keys: start,
      scan: start + span * 0.18,
      soft: start + span * 0.46,
      shares: start + span * 0.46,
      values: start + span * 0.6,
      end: start + span,
    );
  }

  /// The head on screen at [beat], or null outside the heads.
  static int? headAt(double beat, int heads) {
    if (beat < 0 || beat >= _joinFrom) {
      return null;
    }
    for (int h = heads - 1; h >= 0; h--) {
      if (beat >= times(h, heads).keys) {
        return h;
      }
    }
    return 0;
  }

  /// How strongly head [h]'s tag shows at [beat]: in with its keys, out as
  /// it ends.
  static double headTagShown(double beat, int h, int heads) {
    final HeadTimes t = times(h, heads);
    return through(beat, t.keys, t.keys + 0.3) * (1 - through(beat, t.end - 0.1, t.end + 0.15));
  }

  /// How strongly x0's tag shows at [beat]: away from Scores' head 1 until
  /// the last head's tag has gone, never under one, then going for the map.
  static double x0TagShown(double beat, int heads) {
    final double back = times(heads - 1, heads).end + 0.15;
    return through(beat, back, back + 0.25) * (1 - _span(beat, _x0TagOut));
  }

  /// x0 and what block 1's attention adds, the stream's first point after
  /// x0, as its table is named: Feed-forward opens on it.
  static String sumTag(LmView view) =>
      "x0 + block 1's attention · ${view.focus.inputs} × ${view.trace.model.width}";

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats);

  /// The stage's last frame: Feed-forward opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view) => _paint(canvas, size, view, _beats);

  void _paint(Canvas canvas, Size size, LmView view, double beat) {
    final AttentionLayout layout = AttentionLayout(size, view);
    final StreamTable table = layout.table;
    final TrainingTrace trace = view.trace;
    // Embedding's x0 tag, away while the heads' tags are up, going as the
    // table narrows to its token column.
    const EmbeddingScene().paintEnd(
      canvas,
      size,
      view,
      EmbeddingFade(rows: false, chrome: x0TagShown(beat, trace.model.heads), note: 0, twins: 0),
    );
    table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, ScoresScene.lastNote(view).$3), ...notes(view)],
      beat,
    );
    final int width = trace.model.width;
    final int n = view.focus.inputs;
    // Each head's map named in turn, each name gone before the next is
    // written in its place.
    for (int h = 0; h < trace.model.heads; h++) {
      table.tag(canvas, 'block 1 · head ${h + 1} · shares in % · $n × $n', mapTagShown(h, trace.model.heads, beat));
    }
    table.tag(
      canvas,
      "what block 1's attention adds · $n × $width",
      through(beat, _widenFrom + 0.1, _widenFrom + 0.3) * (1 - through(beat, _gainUnwritten.$1, _gainUnwritten.$2)),
    );
    table.tag(canvas, sumTag(view), through(beat, _gainUnwritten.$2, _gainUnwritten.$2 + 0.2));
    _stream(canvas, size, view, layout, beat);
    final double squeeze = _squeezeAt(beat);
    table.drawTiles(canvas, dx: layout.slide(squeeze));
    // The row in focus, outlined from its tile to its row's end; while the
    // map shows, over it, across the places it reads.
    final bool overMap = _mapShown(beat) > 0;
    void outline() => table.outline(
      canvas,
      view.position,
      _outlineRight(layout, view.position, beat),
      1,
      dx: layout.slide(squeeze),
    );
    if (!overMap) {
      outline();
    }
    final int heads = trace.model.heads;
    for (int h = 0; h < heads; h++) {
      _head(canvas, view, layout, beat, h);
    }
    _answers(canvas, view, layout, beat);
    _output(canvas, size, view, layout, beat);
    if (_working(beat)) {
      WorkedAnswer.paint(canvas, size, view, beat - _mixFrom);
    }
    _map(canvas, view, layout, beat);
    if (overMap) {
      outline();
    }
  }

  /// Whether number 1 of head 1's answer is being worked out at [beat].
  static bool _working(double beat) => beat >= _mixFrom && beat < _mixTo;

  /// When number 1 of head 1's answer is worked out, in beats: it opens on
  /// the answers on the row in focus and ends on them written, where the
  /// output weights take them.
  static (double, double) get worked => (_mixFrom, _mixTo);

  /// How narrow the table is at [beat]: 1 a strip a place, as Scores left
  /// it, 0 written out again.
  static double _squeezeAt(double beat) => 1 - through(beat, _widenFrom, _widenTo);

  /// Where the outline of the row in focus ends at [beat]: at its row's end;
  /// from just before its row of the map fills, at the place it reads last,
  /// itself, until the row widens past it.
  static double _outlineRight(AttentionLayout layout, int focus, double beat) {
    final double row = layout.stream(focus, _squeezeAt(beat), _span(beat, _grow)).right;
    final double across = through(beat, _focusRow.$1 - 0.25, _focusRow.$1);
    if (across <= 0) {
      return row;
    }
    final double reads = layout.mapCell(focus, focus).right;
    return math.max(row, layout.mapLeft + (reads - layout.mapLeft) * across);
  }

  // ---------------------------------------------------------------- stream

  /// Each place's row: x0, its numbers going as it narrows, then going into
  /// its tile while the map shows; then, wide again, out of its tile, what
  /// attention adds to it, alone on its own scale, and the sum.
  void _stream(Canvas canvas, Size size, LmView view, AttentionLayout layout, double beat) {
    final StreamTable table = layout.table;
    final int n = view.focus.inputs;
    final double squeeze = _squeezeAt(beat);
    final double collapse = _span(beat, _grow);
    final double alone = _span(beat, _alone);
    final double add = _span(beat, _add);
    final double scale = table.scale;
    final double gainScale = table.gainScale(0, 1);
    final double gainText = _span(beat, _gainWritten) * (1 - _span(beat, _gainUnwritten));
    final double sumText = _span(beat, _sumsWritten);
    for (int i = 0; i < n; i++) {
      final Rect rect = layout.stream(i, squeeze, collapse);
      if (rect.width < 1) {
        continue;
      }
      final List<double> x0 = table.values(0, i);
      if (alone <= 0) {
        table.drawRow(canvas, rect, x0, scale: scale, text: 0);
        continue;
      }
      final List<double> gain = table.gained(0, 1, i);
      final List<double> sums = table.values(1, i);
      final List<Color> colors = <Color>[
        for (int d = 0; d < x0.length; d++)
          Color.lerp(
            Color.lerp(view.inks.cell(x0[d] / scale), view.inks.cell(gain[d] / gainScale), alone)!,
            view.inks.cell(sums[d] / scale),
            add,
          )!,
      ];
      table.drawRow(canvas, rect, x0, scale: scale, colors: colors, text: 0);
      if (squeeze <= 0.02) {
        if (gainText > 0) {
          table.drawRow(canvas, rect, gain, scale: gainScale, fill: 0, text: gainText);
        }
        if (sumText > 0) {
          table.drawRow(canvas, rect, sums, scale: scale, fill: 0, text: sumText);
        }
      }
    }
  }

  // ------------------------------------------------------------------ heads

  /// The colour scale of head [h]'s queries, keys and values over the places
  /// in focus: one scale, so their colours can be set against each other.
  static double qkvScale(LmView view, int h) => view.kit.memo<double>(
    ('attention-qkv', view.step, view.peptide, block, h),
    () {
      final TrainingTrace trace = view.trace;
      return percentileScale(<double>[
        for (int i = 0; i < view.focus.inputs; i++)
          for (int d = 0; d < trace.headSize; d++) ...<double>[
            trace.query(view.checkpoint, block, h, view.peptide, i, d),
            trace.key(view.checkpoint, block, h, view.peptide, i, d),
            trace.value(view.checkpoint, block, h, view.peptide, i, d),
          ],
      ]);
    },
  );

  /// The scale of what the heads hand the places in focus.
  static double answerScale(LmView view) => view.kit.memo<double>(
    ('attention-mix', view.step, view.peptide, block),
    () {
      final TrainingTrace trace = view.trace;
      return percentileScale(<double>[
        for (int h = 0; h < trace.model.heads; h++)
          for (int i = 0; i < view.focus.inputs; i++)
            for (int d = 0; d < trace.headSize; d++) trace.mixed(view.checkpoint, block, h, view.peptide, i, d),
      ]);
    },
  );

  /// What the place in focus reads of each place up to its own in head [h]
  /// of [layer], this stage's block unless another is named: softmax of its
  /// scores, worked out from the scores as they are kept, whole.
  static List<double> shares(LmView view, int h, {int layer = block}) => view.kit.memo<List<double>>(
    ('attention-shares', view.step, view.peptide, layer, h, view.position),
    () => _softmax(view, h, view.position, layer),
  );

  /// Every place's shares in head [h] of [layer], a row a place, each adding
  /// to one: what its map draws. The place in focus's row is [shares],
  /// number for number.
  static List<List<double>> allShares(LmView view, int h, {int layer = block}) => view.kit.memo<List<List<double>>>(
    ('attention-map', view.step, view.peptide, layer, h),
    () => <List<double>>[for (int i = 0; i < view.focus.inputs; i++) _softmax(view, h, i, layer)],
  );

  /// What place [i] reads of each place up to its own in head [h] of
  /// [layer]: softmax of its scores as they are kept.
  static List<double> _softmax(LmView view, int h, int i, int layer) {
    final TrainingTrace trace = view.trace;
    final List<double> scores = <double>[
      for (int j = 0; j <= i; j++) trace.score(view.checkpoint, layer, h, view.peptide, i, j),
    ];
    final double top = scores.reduce(math.max);
    final List<double> e = <double>[for (final double s in scores) math.exp(s - top)];
    final double sum = e.reduce((double a, double b) => a + b);
    return <double>[for (final double x in e) x / sum];
  }

  /// Place [key]'s share of what the place in focus reads, in head [h] of
  /// [layer].
  static double share(LmView view, int h, int key, {int layer = block}) => shares(view, h, layer: layer)[key];

  /// Head [h]'s part: every place's key, then its value; the query passing
  /// the keys; each score, then each share; and the arcs carrying the values
  /// into the head's answer.
  void _head(Canvas canvas, LmView view, AttentionLayout layout, double beat, int h) {
    final TrainingTrace trace = view.trace;
    final HeadTimes t = times(h, trace.model.heads);
    final double shown = through(beat, t.keys, t.keys + 0.35) * (1 - through(beat, t.end - 0.05, t.end + 0.3));
    if (shown <= 0) {
      return;
    }
    final int n = view.focus.inputs;
    drawStrips(
      canvas,
      view,
      layout,
      h,
      grow: (int j) => through(beat, t.keys + 0.3 * j / math.max(1, n - 1), t.keys + 0.3 * j / math.max(1, n - 1) + 0.3),
      flip: through(beat, t.values, t.values + 0.4),
      alpha: shown,
    );
    drawHatch(canvas, view, layout, shown);
    _scores(canvas, view, layout, beat, h, t, shown);
    final double query = through(beat, t.keys + 0.2, t.keys + 0.5) * (1 - through(beat, t.soft, t.soft + 0.3)) * shown;
    drawQuery(canvas, view, layout, h, _scanRow(beat, t, view.position), query);
    if (h == 0) {
      ScoresScene.drawShares(canvas, view, layout, alpha: 1 - _span(beat, _barsOut));
    }
    _arcs(canvas, view, layout, beat, h, t, shown);
    final double named = headTagShown(beat, h, trace.model.heads);
    drawHeadTag(canvas, view, layout, h, beat < t.values + 0.2 ? 'query and keys' : 'values', named);
  }

  /// Head [h]'s tag, its block and what its strips hold.
  static String headTag(int h, String what) => 'block 1 · head ${h + 1} · $what';

  /// Head [h]'s name over its strips, and what they hold: kept on the
  /// canvas, its left edge set by its longer words so it holds still as
  /// they change.
  static void drawHeadTag(Canvas canvas, LmView view, AttentionLayout layout, int h, String what, double alpha) {
    if (alpha > 0) {
      final EmbeddingLayout e = layout.table.layout;
      final double widest = tagSize(view, headTag(h, 'query and keys')).width;
      drawTag(
        canvas,
        view,
        headTag(h, what),
        Offset(math.max(e.left, math.min(layout.kvLeft - tagPadding, e.right - widest)), e.tagTop),
        alpha: alpha,
      );
    }
  }

  /// Every place's key in head [h], [flip] of the way to its value, each
  /// [grow] of the way out of its row; those after the place in focus faint:
  /// it never reads them.
  static void drawStrips(
    Canvas canvas,
    LmView view,
    AttentionLayout layout,
    int h, {
    required double Function(int j) grow,
    double flip = 0,
    double alpha = 1,
    bool Function(int j)? skip,
  }) {
    final TrainingTrace trace = view.trace;
    final int focus = view.position;
    final int size = trace.headSize;
    final double scale = qkvScale(view, h);
    for (int j = 0; j < view.focus.inputs; j++) {
      final double out = grow(j);
      if (out <= 0 || (skip != null && skip(j))) {
        continue;
      }
      final Rect strip = layout.kv(j);
      // Each strip comes out of its row from the left, its cells uncovered,
      // not squeezed.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(strip.left - 1, strip.top - 1, strip.width * out + 2, strip.height + 2));
      layout.table.layout.fill(
        canvas,
        strip,
        <Color>[
          for (int d = 0; d < size; d++)
            Color.lerp(
              view.inks.ground,
              view.inks.signed(
                (flip >= 1
                        ? trace.value(view.checkpoint, block, h, view.peptide, j, d)
                        : flip <= 0
                        ? trace.key(view.checkpoint, block, h, view.peptide, j, d)
                        : trace.key(view.checkpoint, block, h, view.peptide, j, d) * (1 - flip) +
                              trace.value(view.checkpoint, block, h, view.peptide, j, d) * flip) /
                    scale,
              ),
              alpha * (j > focus ? 0.3 : 1),
            )!,
        ],
        gap: 0.5,
        radius: 1.5,
      );
      canvas.restore();
    }
  }

  /// The places after the one in focus, which it never reads: their keys and
  /// scores struck through.
  static void drawHatch(Canvas canvas, LmView view, AttentionLayout layout, double alpha) {
    final int n = view.focus.inputs;
    final int focus = view.position;
    if (focus >= n - 1 || alpha <= 0) {
      return;
    }
    hatch(
      canvas,
      view,
      Rect.fromLTRB(layout.scoreLeft, layout.table.row(focus + 1).top, layout.kvRight, layout.table.row(n - 1).bottom),
      alpha,
    );
  }

  /// [area] struck through, as the places a row never reads are.
  static void hatch(Canvas canvas, LmView view, Rect area, double alpha) {
    if (alpha <= 0) {
      return;
    }
    canvas.save();
    canvas.clipRect(area);
    final Path lines = Path();
    for (double d = -area.height; d < area.width; d += 6) {
      lines
        ..moveTo(area.left + d, area.bottom)
        ..lineTo(area.left + d + area.height, area.top);
    }
    canvas.drawPath(
      lines,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  /// Where the query is, as a row (fractional): it rises from its own place
  /// to `<bos>` through the scan.
  static double _scanRow(double beat, HeadTimes t, int focus) => scanRow(beat, t.scan, t.soft, focus);

  /// The row the query passes at [beat], rising from [focus] at [from] to
  /// `<bos>` at [to].
  static double scanRow(double beat, double from, double to, int focus) =>
      focus * (1 - ((beat - from) / (to - from)).clamp(0.0, 1.0));

  /// Place [j]'s score, [value], written beside its key.
  static void drawScore(Canvas canvas, LmView view, AttentionLayout layout, int j, double value, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final Rect cell = layout.score(j);
    view.kit.draw(
      canvas,
      fixed(value, 2),
      inked(view.kit.mono, layout.textSize, view.inks.ink, alpha: alpha),
      Offset(cell.right, cell.center.dy),
      anchor: const Offset(1, 0.5),
    );
  }

  /// Each score beside its key as the query passes it, then each share.
  void _scores(Canvas canvas, LmView view, AttentionLayout layout, double beat, int h, HeadTimes t, double shown) {
    if (beat < t.scan) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int focus = view.position;
    final double row = _scanRow(beat, t, focus);
    // The scores go, then the shares come in their place, never over them.
    final double gone = through(beat, t.shares, t.shares + 0.2);
    final double soft = through(beat, t.shares + 0.2, t.shares + 0.45);
    final TextStyle face = inked(view.kit.mono, layout.textSize, view.inks.ink);
    for (int j = 0; j <= focus; j++) {
      // A key's score appears as the query reaches it.
      final double reached = (j - row + 1).clamp(0.0, 1.0) * shown;
      if (reached <= 0) {
        continue;
      }
      final Rect cell = layout.score(j);
      final double part = share(view, h, j);
      if (gone < 1) {
        drawScore(canvas, view, layout, j, trace.score(view.checkpoint, block, h, view.peptide, focus, j), reached * (1 - gone));
      }
      if (soft > 0) {
        view.kit.draw(
          canvas,
          percent(part),
          face.copyWith(color: face.color!.withValues(alpha: ((reached * soft) * 8).round() / 8)),
          Offset(cell.right, cell.center.dy - 1),
          anchor: const Offset(1, 0.5),
        );
        canvas.drawRect(
          Rect.fromLTWH(cell.left, cell.bottom - 2.5, cell.width * part * soft, 1.6),
          Paint()..color = view.inks.signal.withValues(alpha: reached),
        );
      }
    }
  }

  /// Head [h]'s query of the place in focus, over its own key's level less a
  /// lift, at [row] (fractional, as it passes the keys), outlined.
  static void drawQuery(Canvas canvas, LmView view, AttentionLayout layout, int h, double row, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int focus = view.position;
    final Rect at = queryAt(layout, focus, row);
    final double scale = qkvScale(view, h);
    layout.table.layout.fill(
      canvas,
      at,
      <Color>[
        for (int d = 0; d < trace.headSize; d++)
          Color.lerp(
            view.inks.ground,
            view.inks.signed(trace.query(view.checkpoint, block, h, view.peptide, focus, d) / scale),
            alpha,
          )!,
      ],
      gap: 0.5,
      radius: 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(at.inflate(1), const Radius.circular(2.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = view.inks.signal.withValues(alpha: alpha),
    );
  }

  /// Where the query of the place in focus is drawn at [row].
  static Rect queryAt(AttentionLayout layout, int focus, double row) =>
      layout.kv(focus).shift(Offset(0, (row - focus) * layout.table.layout.pitch - 3));

  /// The arcs from each place's value into the head's answer, as wide as the
  /// place's share against the largest, values riding them.
  void _arcs(Canvas canvas, LmView view, AttentionLayout layout, double beat, int h, HeadTimes t, double shown) {
    final double drawn = through(beat, t.values + 0.25, t.values + 0.7) * shown;
    if (drawn <= 0) {
      return;
    }
    final int focus = view.position;
    double most = 1e-9;
    for (int j = 0; j <= focus; j++) {
      most = math.max(most, share(view, h, j));
    }
    // Values ride the arcs while the answer fills, about once a beat.
    final double riding = beat >= t.values + 0.4 && beat < t.end - 0.1 ? (beat - t.values) % 1 : -1;
    for (int j = 0; j <= focus; j++) {
      final double part = share(view, h, j);
      final double w = part / most;
      if (part < 0.01) {
        continue;
      }
      final (Offset, Offset, Offset, Offset) curve = layout.arc(j, h);
      final Path path = Path()
        ..moveTo(curve.$1.dx, curve.$1.dy)
        ..cubicTo(curve.$2.dx, curve.$2.dy, curve.$3.dx, curve.$3.dy, curve.$4.dx, curve.$4.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.7 + 2.5 * w
          ..color = view.inks.signal.withValues(alpha: (0.15 + 0.85 * w) * drawn),
      );
      if (riding >= 0) {
        for (final double offset in const <double>[0, 0.5]) {
          final double s = (riding + offset) % 1;
          canvas.drawCircle(
            _cubic(curve, s),
            1 + 2.2 * math.sqrt(w),
            Paint()..color = view.inks.signal.withValues(alpha: 0.9 * drawn),
          );
        }
      }
    }
  }

  static Offset _cubic((Offset, Offset, Offset, Offset) c, double s) {
    final double u = 1 - s;
    return c.$1 * (u * u * u) + c.$2 * (3 * u * u * s) + c.$3 * (3 * u * s * s) + c.$4 * (s * s * s);
  }

  // ---------------------------------------------------------------- answers

  /// Each head's answer for the place in focus, filling as its values
  /// arrive and kept, side by side, till they stand up for number 1 to be
  /// worked out; once what the output weights make of them has lain down in
  /// their place, the row holds what the place in focus gains. Then their
  /// names go, and their box grows into head 1's map.
  void _answers(Canvas canvas, LmView view, AttentionLayout layout, double beat) {
    final TrainingTrace trace = view.trace;
    final int heads = trace.model.heads;
    final int focus = view.position;
    final double gone = 1 - _span(beat, _answersOut);
    final double outlined = 1 - _span(beat, _boxOut);
    if (outlined <= 0) {
      return;
    }
    final double mixScale = answerScale(view);
    // Off the row from when they stand up until the output has lain down.
    final bool away = beat >= _mixFrom + WorkedAnswer.stand.$1 && beat < _lieDown.$2;
    final double joined = beat >= _lieDown.$2 ? 1 : 0;
    // One label under the answers at a time: each head's, then the join's.
    final double headLabels = 1 - through(beat, _joinFrom, _joinFrom + 0.2);
    final double joinLabel = _span(beat, _boxIn);
    final StreamTable table = layout.table;
    final List<double> gain = table.gained(0, 1, focus);
    final double gainScale = table.gainScale(0, 1);
    for (int h = 0; h < heads && gone > 0 && !away; h++) {
      final HeadTimes t = times(h, heads);
      final double filled = through(beat, t.values + 0.5, t.end - 0.1);
      final double frame = through(beat, t.values + 0.3, t.values + 0.5);
      if (frame <= 0) {
        continue;
      }
      final Rect slot = layout.slot(h);
      layout.table.layout.fill(
        canvas,
        slot,
        <Color>[
          for (int d = 0; d < trace.headSize; d++)
            Color.lerp(
              Color.lerp(
                view.inks.zero,
                view.inks.signed(trace.mixed(view.checkpoint, block, h, view.peptide, focus, d) / mixScale),
                filled,
              )!,
              view.inks.signed(gain[h * trace.headSize + d] / gainScale),
              joined,
            )!.withValues(alpha: frame * gone),
        ],
        gap: 0.5,
        radius: 1.5,
      );
      final double filling = filled > 0 && filled < 1 ? 1 : 0.35;
      canvas.drawRRect(
        RRect.fromRectAndRadius(slot.inflate(1), const Radius.circular(2.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (filling >= 1 ? view.inks.signal : view.inks.rule).withValues(alpha: frame * gone * (1 - joined)),
      );
      view.kit.draw(
        canvas,
        'head ${h + 1}',
        inked(view.kit.sans, 8.5, view.inks.quiet, alpha: frame * gone * headLabels),
        Offset(slot.center.dx, slot.bottom + 2),
        anchor: const Offset(0.5, 0),
      );
    }
    final Rect all = layout.answers;
    final double box = _span(beat, _boxIn);
    if (box > 0) {
      // The box round both, which grows into head 1's map: what the place in
      // focus read came through its row; the map is every place's.
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.growing(_span(beat, _grow)).inflate(1), const Radius.circular(2.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: box * outlined),
      );
      view.kit.draw(
        canvas,
        'what ${StreamTable.placeName(view, focus)} read',
        inked(view.kit.sans, 8.5, view.inks.quiet, alpha: joinLabel * gone),
        Offset(all.center.dx, all.bottom + 2),
        anchor: const Offset(0.5, 0),
      );
    }
  }

  // ------------------------------------------------------- output weights

  /// When the strings into number [out] of what attention adds run, of
  /// [width] numbers: they leave the heads' answers at the first and reach
  /// the number at the second. Number 1 alone and slowly, then the rest in
  /// one cascade.
  static (double, double) outputFanAt(int out, int width) => _outFlow.fanAt(out, width);

  /// How far number [out] of what attention adds is made at [beat]: it fills
  /// as its strings land.
  static double outputMadeAt(int out, int width, double beat) => _outFlow.madeAt(out, width, beat);

  /// The heads' answers for the place in focus, side by side: what goes
  /// through the output weights.
  static List<double> joinedAnswers(LmView view) {
    final TrainingTrace trace = view.trace;
    return <double>[
      for (int h = 0; h < trace.model.heads; h++)
        for (int d = 0; d < trace.headSize; d++) trace.mixed(view.checkpoint, block, h, view.peptide, view.position, d),
    ];
  }

  static double _outWeight(LmView view, int out, int d) => view.trace.outWeight(view.checkpoint, block, out, d);

  /// The largest of the output weights at the checkpoint in focus.
  static double _outWeightReach(LmView view) => view.kit.memo<double>(
    ('attention-out-reach', view.step, block),
    () => weightReach(
      view.trace.model.width,
      view.trace.model.width,
      (int out, int d) => _outWeight(view, out, d),
    ),
  );

  /// The largest of what the output weights' strings carry from the place in
  /// focus's answers, a number of them times a weight.
  static double _outProductReach(LmView view) => view.kit.memo<double>(
    ('attention-out-products', view.step, view.peptide, view.position, block),
    () => productReach(joinedAnswers(view), view.trace.model.width, (int out, int d) => _outWeight(view, out, d)),
  );

  /// The heads' answers for the place in focus, side by side, standing on
  /// Scores' bench at [x], a slice a head: number d's tile in its colour,
  /// [tile] of d strong, and its number at its left, [number] of d strong;
  /// the place's name over them, [title] strong; and Scores' cut named right
  /// of each head's slice, [labels] strong.
  static void drawJoined(
    Canvas canvas,
    LmView view,
    ScoresLayout bench, {
    required double x,
    required double Function(int d) tile,
    required double Function(int d) number,
    required double title,
    required double labels,
  }) {
    final TrainingTrace trace = view.trace;
    final int slice = trace.headSize;
    final int heads = trace.model.heads;
    final List<double> joined = joinedAnswers(view);
    final double mixScale = answerScale(view);
    final List<Color> colours = <Color>[for (final double v in joined) view.inks.signed(v / mixScale)];
    Rect at(int d) => bench.tileAt(x, d, 1);
    drawColumn(canvas, at, <Color>[
      for (int d = 0; d < colours.length; d++) colours[d].withValues(alpha: colours[d].a * tile(d)),
    ]);
    drawColumnNumbers(
      canvas,
      view,
      at,
      joined,
      1,
      textSize: bench.textSize,
      writes: bench.writes,
      left: true,
      alphaOf: number,
    );
    drawColumnTitle(
      canvas,
      view,
      StreamTable.placeName(view, view.position),
      title,
      x: x,
      top: bench.columnAt(x, 1).top,
    );
    if (labels > 0 && heads > 1) {
      final TextStyle words = inked(view.kit.sans, 8.5, view.inks.quiet, alpha: labels);
      for (int h = 0; h < heads; h++) {
        final Rect part = bench.sliceAt(x, h);
        view.kit.draw(canvas, 'head ${h + 1}', words, Offset(part.right + 5, part.center.dy - 1), anchor: const Offset(0, 1));
        view.kit.draw(canvas, '${h * slice + 1}–${(h + 1) * slice}', words, Offset(part.right + 5, part.center.dy + 1));
      }
    }
  }

  /// The heads' answers through the output weights, on Scores' bench, where
  /// number 1 being worked out left them: standing where Scores stood the
  /// evened row, a slice a head, Scores' cut between them; an empty column
  /// stands where Scores stood the query, named on a plate under the
  /// strings; the row flows through, each number's strings lit with what they
  /// carry, the number made, what attention adds, as they land; then the
  /// bench clears and the column lies down onto the row, where the answers
  /// sat.
  void _output(Canvas canvas, Size size, LmView view, AttentionLayout layout, double beat) {
    // Until number 1 is worked out, it draws the answers itself.
    if (beat < _mixTo || beat >= _lieDown.$2) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final StreamTable table = layout.table;
    final ScoresLayout bench = ScoresLayout(size, view);
    final int width = trace.model.width;
    final List<double> joined = joinedAnswers(view);
    final List<double> gain = table.gained(0, 1, view.position);
    final double gainScale = table.gainScale(0, 1);
    final List<Color> gainColours = <Color>[for (final double v in gain) view.inks.signed(v / gainScale)];
    Rect inTile(int d) => bench.tileAt(bench.inputX, d, 1);
    Rect outTile(int out) => bench.tileAt(bench.outputX[0], out, 0);
    final double shown = 1 - _span(beat, _benchOut);
    if (shown > 0) {
      final double web = _outFlow.webShown(width, beat);
      if (web > 0) {
        Offset from(int d) => inTile(d).centerRight;
        Offset to(int out) => outTile(out).centerLeft;
        double weight(int out, int d) => _outWeight(view, out, d);
        drawWeights(
          canvas,
          view,
          _outFlow,
          inputs: width,
          outputs: width,
          weight: weight,
          from: from,
          to: to,
          most: _outWeightReach(view),
          beat: beat,
          alpha: web,
        );
        drawFans(
          canvas,
          view,
          _outFlow,
          input: joined,
          outputs: width,
          weight: weight,
          from: from,
          to: to,
          most: _outProductReach(view),
          beat: beat,
          alpha: web,
        );
      }
      // Scores' cut, named in the band the strings will cross, till they flow.
      final double flows = _outFlow.fanAt(0, width).$1;
      drawJoined(
        canvas,
        view,
        bench,
        x: bench.inputX,
        tile: (int d) => shown,
        number: (int d) => shown,
        title: shown,
        labels: shown * (1 - through(beat, flows - 0.25, flows - 0.1)),
      );
      final double slots = _span(beat, _outSlotsIn) * shown;
      final List<double> made = <double>[for (int out = 0; out < width; out++) _outFlow.madeAt(out, width, beat)];
      drawSlots(canvas, view, outTile, slots, made);
      if (beat < _lieDown.$1) {
        drawColumn(canvas, outTile, <Color>[
          for (int out = 0; out < width; out++) gainColours[out].withValues(alpha: made[out]),
        ]);
        drawColumnNumbers(
          canvas,
          view,
          outTile,
          gain,
          1 - _span(beat, _outNumbersOut),
          textSize: bench.textSize,
          writes: bench.writes,
          alphaOf: (int out) => _outFlow.written(out, width, beat),
        );
      }
      drawColumnTitle(canvas, view, 'output', slots, x: bench.outputX[0], top: bench.columnAt(bench.outputX[0], 0).top);
      final double plate = _span(beat, _outPlateIn) * shown;
      if (plate > 0) {
        final String name = ScoresScene.weightsName(view, 'output');
        final Rect at = bench.plateAt(tagSize(view, name));
        drawTag(canvas, view, name, at.topLeft, alpha: plate);
        drawPlateStatus(canvas, view, at, ScoresScene.weightsStatus(view), plate, left: bench.benchLeft, right: bench.right);
      }
    }
    if (beat >= _lieDown.$1) {
      table.strip(
        canvas,
        from: layout.answers,
        to: bench.columnAt(bench.outputX[0], 0),
        f: 1 - _span(beat, _lieDown),
        colors: gainColours,
        lyingGap: 0.5,
        lyingRadius: 1.5,
      );
    }
  }

  // -------------------------------------------------------------------- map

  /// The head whose map comes first: the first, whose reading Scores worked
  /// out. The others' follow it on the same rows.
  static const int mapHead = 0;

  /// How far the map has come: in with its slots as the answers' box grows
  /// into it, and gone as the table widens again.
  static double _mapShown(double beat) =>
      _span(beat, _mapIn) * (1 - through(beat, _widenFrom, _widenFrom + 0.25));

  /// Head 2's own pace, in beats, scaled to each later head's share of the
  /// span after head 1's map when there are more than two.
  static double _mapPace(int heads) => (_widenFrom - _mapTurnFrom) / math.max(1, heads - 1) / 2.3;

  /// When head [h]'s map, of [heads], does each part: its tag comes over
  /// [tagIn]; its row in focus fills over [focus], then every other row
  /// over [rows]; from [away] its cells empty to their slots and its tag
  /// goes, as the next head's map comes (never, for the last, which holds
  /// until the table widens). Head 1's map comes out of the heads' answers;
  /// each later head's takes the rows once the one before has emptied.
  static ({(double, double) tagIn, (double, double) focus, (double, double) rows, double away}) mapTimes(
    int h,
    int heads,
  ) {
    final double pace = _mapPace(heads);
    final double share = 2.3 * pace;
    final double away = h < heads - 1 ? _mapTurnFrom + h * share : double.infinity;
    if (h == 0) {
      return (tagIn: _mapTagIn, focus: _focusRow, rows: _rows, away: away);
    }
    final double start = _mapTurnFrom + (h - 1) * share;
    return (
      tagIn: (start + 0.15 * pace, start + 0.35 * pace),
      focus: (start + 0.35 * pace, start + 0.85 * pace),
      rows: (start + 0.9 * pace, start + 1.5 * pace),
      away: away,
    );
  }

  /// The head whose map the grid draws at [beat], of [heads]: each until
  /// its cells have emptied, then the next.
  static int mapHeadAt(double beat, int heads) {
    for (int h = 0; h < heads - 1; h++) {
      if (beat < mapTimes(h, heads).away + 0.3 * _mapPace(heads)) {
        return h;
      }
    }
    return heads - 1;
  }

  /// How strongly head [h]'s map is named at [beat], of [heads]: each tag
  /// gone before the next is written in its place.
  static double mapTagShown(int h, int heads, double beat) {
    final ({(double, double) tagIn, (double, double) focus, (double, double) rows, double away}) t = mapTimes(h, heads);
    return _span(beat, t.tagIn) *
        (1 - through(beat, t.away, t.away + 0.15 * _mapPace(heads))) *
        (1 - through(beat, _widenFrom - 0.1, _widenFrom + 0.1));
  }

  /// How far the map's cell at row [i], column [j] has filled at [beat], of
  /// [n] places, [focus] in focus, in head [head]'s map of [heads]: the row
  /// in focus first, a cell at a time from `<bos>`; then every other row,
  /// top to bottom, a row at a time; and back to its slot as the next
  /// head's map comes.
  static double mapFilled(int i, int j, int focus, int n, double beat, {int head = 0, int heads = 1}) {
    final ({(double, double) tagIn, (double, double) focus, (double, double) rows, double away}) t =
        mapTimes(head, heads);
    final double emptied = through(beat, t.away, t.away + 0.3 * _mapPace(heads));
    if (i == focus) {
      final double span = t.focus.$2 - t.focus.$1;
      final double each = math.min(0.25, span / 2);
      final double start = t.focus.$1 + (focus < 1 ? 0 : (span - each) * j / focus);
      return through(beat, start, start + each) * (1 - emptied);
    }
    final double span = t.rows.$2 - t.rows.$1;
    final double each = math.min(0.2, span / 3);
    final int rank = i < focus ? i : i - 1;
    final double start = t.rows.$1 + (n < 3 ? 0 : (span - each) * rank / (n - 2));
    return through(beat, start, start + each) * (1 - emptied);
  }

  /// How many rows of head [h]'s map put their largest share on another
  /// place than head [h] − 1's map does: the first of the largest in each.
  static int movedRows(LmView view, int h) {
    final List<List<double>> now = allShares(view, h);
    final List<List<double>> before = allShares(view, h - 1);
    int top(List<double> row) {
      int best = 0;
      for (int j = 1; j < row.length; j++) {
        if (row[j] > row[best]) {
          best = j;
        }
      }
      return best;
    }

    int moved = 0;
    for (int i = 0; i < now.length; i++) {
      if (top(now[i]) != top(before[i])) {
        moved++;
      }
    }
    return moved;
  }

  /// Each head's map in turn, every place's reading at once, on the table's
  /// rows: a row a place, the tile at its left naming it; its shares of the
  /// places up to its own, each on a soft tile of its colour, its percentage
  /// written on it where it fits; the places after it struck through, never
  /// read; and the places read named under the columns. Head 1's comes in as
  /// empty slots, seen only inside the answers' box as the box grows into
  /// it; each later head's fills the slots the one before emptied.
  void _map(Canvas canvas, LmView view, AttentionLayout layout, double beat) {
    final double shown = _mapShown(beat);
    if (shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int n = view.focus.inputs;
    final int focus = view.position;
    final double grow = _span(beat, _grow);
    final int heads = trace.model.heads;
    final int head = mapHeadAt(beat, heads);
    final List<List<double>> rows = allShares(view, head);
    final TextStyle? numbers = layout.mapNumbers;
    canvas.save();
    if (grow < 1) {
      canvas.clipRRect(RRect.fromRectAndRadius(layout.growing(grow), const Radius.circular(2.5)));
    }
    _mapHatch(canvas, view, layout, shown);
    for (int i = 0; i < n; i++) {
      for (int j = 0; j <= i; j++) {
        drawShareCell(
          canvas,
          view,
          layout.mapCell(i, j),
          share: rows[i][j],
          filled: mapFilled(i, j, focus, n, beat, head: head, heads: heads),
          shown: shown,
          numbers: numbers,
        );
      }
    }
    // The places read, a tile under each column.
    for (int j = 0; j < n; j++) {
      drawToken(canvas, view, layout.mapTile(j), trace.inputAt(view.peptide, j), alpha: shown);
    }
    canvas.restore();
  }

  /// A cell of a head's map of shares at [cell]: [filled] of the way from an
  /// empty slot, outlined in the quiet ink, to a soft tile in [share]'s
  /// colour, [shown] as strongly as the map; the share written on it as a
  /// percentage in [numbers], where the map's cells fit one.
  static void drawShareCell(
    Canvas canvas,
    LmView view,
    Rect cell, {
    required double share,
    required double filled,
    required double shown,
    TextStyle? numbers,
  }) {
    final Rect tile = cell.deflate(EmbeddingLayout.gap);
    // The tables' corners, less on a small cell, so it stays a tile.
    final RRect shape = RRect.fromRectAndRadius(
      tile,
      Radius.circular(math.min(EmbeddingLayout.radius, tile.shortestSide * 0.2)),
    );
    if (filled < 1) {
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = view.inks.quiet.withValues(alpha: 0.6 * shown * (1 - filled)),
      );
    }
    if (filled <= 0) {
      return;
    }
    // The share's ramp, softened as the tables' tiles are, so the number on
    // it reads.
    final Color colour = Color.lerp(view.inks.zero, view.inks.share(share, view.inks.signal), LmInks.soft)!;
    canvas.drawRRect(shape, Paint()..color = Color.lerp(view.inks.ground, colour, filled * shown)!);
    if (numbers != null) {
      view.kit.draw(
        canvas,
        percentNumber(share),
        numbers.copyWith(color: numbers.color!.withValues(alpha: (filled * shown * 8).round() / 8)),
        tile.center,
        anchor: const Offset(0.5, 0.5),
      );
    }
  }

  /// The places after each row's own, which it never reads: whole cells,
  /// struck through as Scores strikes them.
  static void _mapHatch(Canvas canvas, LmView view, AttentionLayout layout, double alpha) {
    final int n = layout.places;
    if (n < 2 || alpha <= 0) {
      return;
    }
    final Rect first = layout.mapCell(0, 0);
    final double column = first.width;
    final double pitch = first.height;
    final Rect area = Rect.fromLTRB(first.left, first.top, layout.mapCell(0, n - 1).right, first.top + n * pitch);
    // Down the steps: each row's first cell after its own.
    final Path steps = Path()..moveTo(first.right, first.top);
    for (int i = 0; i < n - 1; i++) {
      final double x = first.left + (i + 1) * column;
      final double y = first.top + (i + 1) * pitch;
      steps
        ..lineTo(x, y)
        ..lineTo(x + column, y);
    }
    steps
      ..lineTo(area.right, area.top)
      ..close();
    canvas.save();
    canvas.clipPath(steps);
    final Path hatch = Path();
    for (double d = -area.height; d < area.width; d += 6) {
      hatch
        ..moveTo(area.left + d, area.bottom)
        ..lineTo(area.left + d + area.height, area.top);
    }
    canvas.drawPath(
      hatch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = view.inks.rule.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  // ------------------------------------------------------------------- taps

  /// A tap on a row, or on its row of the map, puts its place in focus.
  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final int? i = AttentionLayout(size, view).table.placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

  @override
  int? positionAt(Size size, LmView view, Offset at) => AttentionLayout(size, view).table.placeAt(at);

  // ---------------------------------------------------------------- caption

  /// The places [h] reads most at the place in focus: the largest share, and
  /// the next where it is a tenth or more.
  static String readsMost(LmView view, int h, {int layer = block}) {
    double of(int key) => share(view, h, key, layer: layer);
    final List<int> order = <int>[for (int j = 0; j <= view.position; j++) j]
      ..sort((int a, int b) => of(b).compareTo(of(a)));
    return <String>[
      for (int k = 0; k < math.min(2, order.length); k++)
        if (k == 0 || of(order[k]) >= 0.1) '${StreamTable.placeName(view, order[k])} ${percent(of(order[k]))}',
    ].join(', ');
  }

  /// Why each part happens, over the table, a line a thought.
  static List<(double, double, String)> notes(LmView view) {
    final TrainingTrace trace = view.trace;
    final int heads = trace.model.heads;
    final HeadTimes first = times(0, heads);
    return <(double, double, String)>[
      (
        0.25,
        first.end,
        'value: what a place hands over when it is read\n'
            "the head's answer: each value times its share, summed",
      ),
      // Kept while the other heads read; then number 1 is worked out, and
      // the output weights take the answers.
      if (heads > 1)
        (
          first.end,
          _mixFrom,
          '${spelledLeading(heads)} heads ask ${spelled(heads)} questions at once,\n'
              'each with its own query, keys and values',
        ),
      for (final (double from, double to, String text) in WorkedAnswer.notes(view))
        (_mixFrom + from, _mixFrom + to, text),
      (
        _mixTo,
        _mapFrom,
        "Output weights mix the ${heads > 1 ? "heads'" : "head's"} findings into one row of ${trace.model.width}.\n"
            'A fourth trainable ${trace.model.width} × ${trace.model.width}, random at first like the others.',
      ),
      // How to read the map, in Scores' words and the values': then what it
      // says of every row, and why half of it is never read: Shift's y.
      (
        _mapFrom,
        _rows.$1,
        "a row: one place's query on each key up to its own, as shares\n"
            "a column: one place's key and value, read by those after it",
      ),
      (
        _rows.$1,
        heads > 1 ? _mapTurnFrom : _widenFrom,
        'each row adds to 100%: the first places share it among few\n'
            'hatched: the places after it, never read; the next is its answer',
      ),
      // The other heads' maps, and where their answers go with head 1's.
      if (heads > 1)
        (
          _mapTurnFrom,
          _widenFrom,
          '${heads == 2 ? 'head 2 reads with its own query and keys: a map of its own' : 'the other ${spelled(heads - 1)} heads read with their own: a map each'}\n'
              'the ${spelled(heads)} answers, side by side, go through the output weights',
        ),
      (
        _widenFrom,
        double.infinity,
        'nothing is overwritten: what attention found is added to the row\n'
            'next: the feed-forward, each place on its own',
      ),
    ];
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final double beat = frame.local * _beats;
    final int heads = trace.model.heads;
    final int n = view.focus.inputs;
    final int width = trace.model.width;
    final int size = trace.headSize;
    final String focus = StreamTable.placeName(view, view.position);
    final int? h = headAt(beat, heads);
    if (h != null) {
      if (h > 0) {
        return 'Head ${h + 1}, its own query and keys: $focus reads ${readsMost(view, h)}';
      }
      return "Head 1 hands $focus its shares of each place's value: $size numbers";
    }
    // Number 1 is worked out as soon as the heads have read.
    if (beat < _mixTo) {
      return WorkedAnswer.caption(view, beat - _mixFrom);
    }
    if (beat < _outFlow.fanAt(1, width).$1) {
      // Its bias, where training has given it one: every bias starts at 0.
      final bool biased = trace.outBias(view.checkpoint, block, 0) != 0;
      // What the stream gained across attention, as the table writes it.
      final double first = trace.stream(view.checkpoint, 1, view.peptide, view.position, 0) -
          EmbeddingScene.value(view, view.position, 0);
      // Named by its column, for each value and the heads' answers have a
      // number 1 too.
      return 'Output number 1: all $width × their weights, summed${biased ? ', + bias' : ''}: ${fixed(first, 2)}';
    }
    if (beat < _outFlow.fanAt(width - 1, width).$2) {
      return 'The other ${grouped(width - 1)} the same: ${grouped(width * width)} output weights, $width into each';
    }
    if (beat < _mapFrom) {
      return 'What attention adds to $focus';
    }
    if (beat < _rows.$1) {
      return "Head 1's map: $focus's row first, its shares from Scores";
    }
    if (beat < _widenFrom) {
      // The head whose map's span this is: head 1's until its map gives way.
      int h = 0;
      while (h < heads - 1 && beat >= mapTimes(h, heads).away) {
        h++;
      }
      if (h == 0) {
        return 'Every place does what $focus did, its query on the keys up to it';
      }
      final int moved = movedRows(view, h);
      return moved == 0
          ? "Head ${h + 1}'s map: every row reads most the same place as head $h's"
          : "Head ${h + 1}'s map: the place read most changes in ${grouped(moved)} of ${grouped(n)} rows";
    }
    if (beat < _gainUnwritten.$1) {
      final String answers = switch (heads) {
        1 => "its head's answer",
        2 => "both heads' answers",
        _ => "all ${spelled(heads)} heads' answers",
      };
      return "Every row made as $focus's: $answers × output weights";
    }
    return "Added: x0 + block 1's attention, ${grouped(n)} × $width";
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Attention, step ${view.step}. ${caption(view, frame)}.';

  /// Attention's own page: what it takes and gives, what reading changes in
  /// a row, a misreading the canvas invites, and how training sharpens the
  /// maps, in the run's numbers.
  @override
  LmInfo info(LmView view) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int heads = trace.model.heads;
    // The sum's tag, less its size.
    final String sum = sumTag(view).split(' · ').first;
    return LmInfo(
      title: LmStage.attention.label,
      lead: 'Each place takes its shares of the values up to its own; the output weights mix what '
          '${heads == 1 ? 'the head gathered' : 'the ${spelled(heads)} heads gathered'} into $width numbers, '
          'added to its row: $sum. A row now carries what came before it, not only its own token and place.',
      sections: <LmInfoSection>[
        const LmInfoSection('Values', <String>[
          'Made beside the keys, from the same evened row, through weights of their own: a key does not turn '
              'into its value.',
        ]),
        LmInfoSection('Output', <String>[
          "Each head's answer is its values times its shares, summed: ${trace.headSize} numbers. "
              '${heads == 1 ? 'The answer goes' : 'The ${spelled(heads)} answers, side by side, go'} through a '
              '$width × $width table of output weights.',
        ]),
        LmInfoSection('Shares in %', <String>[
          "A map row is one place's shares, adding up to 100%; above the diagonal, hatched, are the places it "
              'may not read.${heads > 1 ? ' Each head has its own map.' : ''}',
        ]),
        LmInfoSection(sum, const <String>[
          'Added, not replaced: the row keeps what it had and gains what it gathered.',
        ]),
      ],
    );
  }

}

/// Attention's canvas, on Embedding's: the rows where Embedding left them,
/// the table narrowed to a strip a place at the left; beside it each place's
/// score or share, its key or value; the arcs; and, on the row in focus, a
/// slot for each head's answer, at the right. Head 1's map lies on the same
/// rows, once the strips have gone into their tiles: from where the strips
/// started to the canvas's side, the places read named under it.
final class AttentionLayout {
  AttentionLayout(this.size, LmView view) : table = StreamTable(size, view) {
    final EmbeddingLayout e = table.layout;
    final TrainingTrace trace = view.trace;
    final double room = e.right - e.cellsLeft + table.gutter;
    const double gaps = 6 + 6;
    // Wide enough for a share, and for a score or the plain sum it came
    // from, to two places.
    scoreWidth = math.max(
      26.0,
      view.kit.layout('−88.88', inked(view.kit.mono, textSize, view.inks.ink)).width + 4,
    );
    // A unit a cell: the narrowed strip 0.8 of it, keys, values and answers
    // one each, the arcs what is left, at least [leastArcs].
    final double unit = math.min(
      7.0,
      (room - gaps - scoreWidth - leastArcs) / (trace.model.width * 0.8 + trace.headSize + trace.model.width),
    );
    narrow = trace.model.width * unit * 0.8;
    // The narrowed rows slide left over the ids' gutter.
    scoreLeft = e.cellsLeft - table.gutter + narrow + 6;
    kvLeft = scoreLeft + scoreWidth + 6;
    kvRight = kvLeft + trace.headSize * unit;
    // The heads' answers take the room right of the keys the arcs leave them:
    // never shorter than a unit a number, nor wider than the table's.
    slotCell = math.max(unit, math.min(e.cell, (e.right - 2 - kvRight - leastArcs) / trace.model.width));
    slotsLeft = e.right - trace.model.width * slotCell - 2;
    barLeft = kvRight + 8;
    percentWidth = view.kit.layout('100%', inked(view.kit.mono, textSize, view.inks.ink)).width + 3;
    barRoom = math.max(10.0, e.right - percentWidth - barLeft);
    focusRow = view.position;
    headSize = trace.headSize;
    heads = trace.model.heads;
    places = view.focus.inputs;
  }

  final Size size;
  final StreamTable table;

  /// The least room the arcs have, from the values to the heads' answers.
  static const double leastArcs = 50;

  /// The narrowed strip's width.
  late final double narrow;

  late final double scoreWidth;
  late final double scoreLeft;
  late final double kvLeft;
  late final double kvRight;
  late final double slotCell;
  late final double slotsLeft;

  /// Where the bars of the shares start, right of the keys, how wide a
  /// percentage is written beside a bar, and how long a bar of 100% is.
  late final double barLeft;
  late final double percentWidth;
  late final double barRoom;
  late final int focusRow;
  late final int headSize;
  late final int heads;
  late final int places;

  /// The size scores and shares are written at.
  double get textSize => (table.layout.pitch * 0.6).clamp(6.5, 9.0);

  /// Place [i]'s row, [squeeze] of the way to the narrowed strip, and that
  /// strip [collapse] of the way into its tile, as it goes while the map
  /// shows.
  Rect stream(int i, double squeeze, [double collapse = 0]) =>
      table.squeezed(i, narrow * (1 - collapse), squeeze).shift(Offset(slide(squeeze), 0));

  /// How far the tiles and the rows have slid left at [squeeze]: over the
  /// ids' gutter, as far as the canvas's side, once narrowed.
  double slide(double squeeze) => -table.gutter * squeeze;

  Rect _band(int i) => table.row(i).deflate(math.min(1.0, table.layout.pitch * 0.06));

  /// Place [i]'s key or value.
  Rect kv(int i) {
    final Rect band = _band(i);
    return Rect.fromLTRB(kvLeft, band.top, kvRight, band.bottom);
  }

  /// Place [i]'s score or share.
  Rect score(int i) {
    final Rect band = _band(i);
    return Rect.fromLTRB(scoreLeft, band.top, scoreLeft + scoreWidth, band.bottom);
  }

  /// Place [j]'s bar for [share], on its row.
  Rect bar(int j, double share) {
    final Rect band = _band(j);
    final double thick = (band.height * 0.5).clamp(2.0, 8.0);
    return Rect.fromLTWH(barLeft, band.center.dy - thick / 2, barRoom * share.clamp(0.0, 1.0), thick);
  }

  /// Head [h]'s answer, on the row in focus.
  Rect slot(int h) {
    final Rect band = _band(focusRow);
    final double left = slotsLeft + h * headSize * slotCell;
    return Rect.fromLTRB(left, band.top, left + headSize * slotCell, band.bottom);
  }

  /// The arc from place [j]'s value to the middle of the top of head [h]'s
  /// answer: out of the value level, then down onto the answer from above.
  /// An arc from a row near the answers' own rises first, both its handles
  /// lifted together just enough that, over the answers before its own and
  /// the near side of its own, it keeps [clearance] above their tops, and a
  /// little more for each row it starts above the answers' own, so lifted
  /// arcs nest rather than cross: it passes over them and lands on its
  /// target from above. A lifted arc climbs early, its first handle nearer
  /// its value, and so runs flatter over the answers.
  (Offset, Offset, Offset, Offset) arc(int j, int h) {
    final Rect target = slot(h);
    final Offset end = Offset(target.center.dx, target.top);
    final double y = table.row(j).center.dy;
    final Offset start = Offset(kvRight + 2, y);
    final double lift = math.max(8.0, (end.dy - y) * 0.5);
    final double reach = end.dx - start.dx;
    final Offset second = Offset(end.dx, end.dy - lift);
    final double ceiling = end.dy - clearance * (1 + 0.5 * math.max(0, focusRow - j));
    final double from = slotsLeft - 2;
    final double to = target.left + target.width * 0.3;
    Offset first = Offset(start.dx + reach * 0.55, math.min(y, end.dy - 6));
    double raise = _raise(start, first, second, end, ceiling, from, to);
    if (raise > 0) {
      first = Offset(start.dx + reach * (0.55 - 0.35 * (raise / clearance).clamp(0.0, 1.0)), first.dy);
      raise = _raise(start, first, second, end, ceiling, from, to);
    }
    return (start, first.translate(0, -raise), second.translate(0, -raise), end);
  }

  /// How far both handles of the arc from [start] to [end] must go up for it
  /// to keep above [ceiling] wherever it passes between [from] and [to].
  static double _raise(Offset start, Offset first, Offset second, Offset end, double ceiling, double from, double to) {
    double raise = 0;
    for (int k = 1; k < _arcSamples; k++) {
      final double t = k / _arcSamples;
      final double u = 1 - t;
      final double x = start.dx * u * u * u + first.dx * 3 * u * u * t + second.dx * 3 * u * t * t + end.dx * t * t * t;
      if (x < from || x > to) {
        continue;
      }
      final double at = start.dy * u * u * u + first.dy * 3 * u * u * t + second.dy * 3 * u * t * t + end.dy * t * t * t;
      // Each handle raised by r raises the arc here by r times this.
      final double handles = 3 * u * u * t + 3 * u * t * t;
      raise = math.max(raise, (at - ceiling) / handles);
    }
    return raise;
  }

  /// How far an arc keeps above the answers it passes over: half a row, and
  /// never less than its widest stroke and the value riding it leave room for.
  double get clearance => math.max(8.0, table.layout.pitch * 0.5);

  static const int _arcSamples = 48;

  /// The heads' answers, side by side on the row in focus: the box head 1's
  /// map grows out of.
  Rect get answers => Rect.fromLTRB(slot(0).left, slot(0).top, slot(heads - 1).right, slot(0).bottom);

  /// Where head 1's map starts once the strips have gone into their tiles:
  /// where the strips started, right of the tiles slid over the gutter. It
  /// runs to the canvas's side, on the table's rows.
  late final double mapLeft = table.layout.cellsLeft - table.gutter;

  /// How wide a column of the map is.
  late final double mapColumn = (table.layout.right - mapLeft) / places;

  /// The map's cell at row [i], column [j]: what place [i] reads of place
  /// [j], on the table's row [i].
  Rect mapCell(int i, int j) {
    final Rect row = table.row(i);
    final double left = mapLeft + j * mapColumn;
    return Rect.fromLTRB(left, row.top, left + mapColumn, row.bottom);
  }

  /// The tile naming the map's column [j], the place read, under its last
  /// row, as the token column names the rows: as tall as theirs, so it
  /// carries its letter where they do, and no wider than its column.
  Rect mapTile(int j) {
    final Rect cell = mapCell(places - 1, j);
    final double side = table.layout.chipSide;
    final double wide = math.max(1.0, math.min(side, cell.width - 1));
    return Rect.fromLTWH(cell.center.dx - wide / 2, cell.bottom + 4, wide, side);
  }

  /// What head 1's map takes: its rows and, under them, the tiles naming its
  /// columns.
  late final Rect mapBox = Rect.fromLTRB(mapLeft, table.row(0).top, table.layout.right, mapTile(0).bottom + 2);

  /// The answers' box [grow] of the way to the map's: up to the first row,
  /// down to the tiles and left to the token column.
  Rect growing(double grow) => Rect.lerp(answers, mapBox, grow)!;

  /// What the map's shares are written in: as large as the widest, `100`,
  /// fits a cell, up to 9 points and the rows' own number size; null where
  /// that is under the least a number is written, and the map is drawn in
  /// its colours alone.
  late final TextStyle? mapNumbers = shareNumbers(table.view, mapColumn, table.layout.pitch);

  /// What a map's shares are written in, its columns [column] wide and its
  /// rows [pitch] tall: as large as the widest, `100`, fits a cell, up to 9
  /// points and the rows' own number size; null where that is under the
  /// least a number is written, and the map is drawn in its colours alone.
  static TextStyle? shareNumbers(LmView view, double column, double pitch) {
    TextStyle at(double points) => inked(view.kit.mono, points, view.inks.ink).copyWith(letterSpacing: 0);
    final double perPoint = view.kit.layout('100', at(10)).width / 10;
    final double room = column - 2 * EmbeddingLayout.gap - 2;
    // Held to the half point below, so a number is never wider than drawn.
    final double points = (math.min(9, math.min(pitch * 0.62, room / perPoint)) * 2).floorToDouble() / 2;
    return points < EmbeddingLayout.leastNumber ? null : at(points);
  }
}
