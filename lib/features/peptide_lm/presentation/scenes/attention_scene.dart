import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import '../lm_inks.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';

/// When one head does each part of its reading, in beats: its keys come, the
/// query passes every key up to its own place and goes, the scores become
/// shares, the values flow; and when it is done.
typedef HeadTimes = ({double keys, double scan, double soft, double shares, double values, double end});

/// Attention, block 1's first part after Scores, as the engine runs it
/// (`nn.MultiheadAttention`). It opens on Scores' last frame: head 1's keys,
/// its scores and its shares at the place in focus. Each key turns into its
/// place's value, and arcs carry each share of each value into the head's
/// answer. The other heads follow quicker, each its own keys, query, scores
/// and shares; their answers, side by side, are mixed back to the stream's
/// width. Every place does the same at once: the table narrows to its token
/// column and head 1's map takes the width beside it, a row a place, the
/// tiles naming its rows, and under it its columns; the place in focus's row
/// fills first, with the shares Scores found, then every other row. Head 2's
/// map is not drawn. Last, the table widens again: what attention adds to
/// each place, alone, and then added, x0 + attention, the first point of the
/// stream after x0.
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
  static const double _mapFrom = 5.2;
  static const double _widenFrom = 8.6;
  static const double _widenTo = 9.4;

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
  static const (double, double) _x0TagOut = (5.2, 5.4);
  static const (double, double) _answersOut = (5.2, 5.35);
  static const (double, double) _grow = (5.25, 5.9);
  static const (double, double) _boxOut = (5.85, 6.1);
  static const (double, double) _mapIn = (5.25, 5.5);
  static const (double, double) _mapTagIn = (5.6, 5.8);
  static const (double, double) _focusRow = (5.9, 6.7);
  static const (double, double) _rows = (6.8, 7.6);

  // What attention added, alone on its own scale, then the sums.
  static const (double, double) _alone = (8.6, 9.2);
  static const (double, double) _gainWritten = (9.4, 9.6);
  static const (double, double) _gainUnwritten = (10.0, 10.2);
  static const (double, double) _add = (10.1, 10.5);
  static const (double, double) _sumsWritten = (10.3, 10.5);

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

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local * _beats);

  /// The stage's last frame: Feed-forward opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view) => _paint(canvas, size, view, _beats);

  void _paint(Canvas canvas, Size size, LmView view, double beat) {
    final AttentionLayout layout = AttentionLayout(size, view);
    final StreamTable table = layout.table;
    final TrainingTrace trace = view.trace;
    // Embedding's x0 tag, going as the table narrows to its token column.
    const EmbeddingScene().paintEnd(
      canvas,
      size,
      view,
      EmbeddingFade(rows: false, chrome: 1 - _span(beat, _x0TagOut), note: 0, twins: 0),
    );
    table.note(
      canvas,
      <(double, double, String)>[(double.negativeInfinity, 0.25, ScoresScene.lastNote(view).$3), ...notes(view)],
      beat,
    );
    final int width = trace.model.width;
    final int n = view.focus.inputs;
    // The map's name, gone before the next is written in its place.
    table.tag(
      canvas,
      'head 1 · shares in % · $n × $n',
      _span(beat, _mapTagIn) * (1 - through(beat, _widenFrom - 0.1, _widenFrom + 0.1)),
    );
    table.tag(
      canvas,
      'what attention adds · $n × $width',
      through(beat, _widenFrom + 0.1, _widenFrom + 0.3) * (1 - through(beat, _gainUnwritten.$1, _gainUnwritten.$2)),
    );
    table.tag(canvas, 'x0 + attention · $n × $width', through(beat, _gainUnwritten.$2, _gainUnwritten.$2 + 0.2));
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
    _map(canvas, view, layout, beat);
    if (overMap) {
      outline();
    }
  }

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
  static double _mixScale(LmView view) => view.kit.memo<double>(
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

  /// What the place in focus reads of each place up to its own in head [h]:
  /// softmax of its scores, worked out from the scores as they are kept,
  /// whole.
  static List<double> shares(LmView view, int h) => view.kit.memo<List<double>>(
    ('attention-shares', view.step, view.peptide, block, h, view.position),
    () => _softmax(view, h, view.position),
  );

  /// Every place's shares in head [h], a row a place, each adding to one:
  /// what its map draws. The place in focus's row is [shares], number for
  /// number.
  static List<List<double>> allShares(LmView view, int h) => view.kit.memo<List<List<double>>>(
    ('attention-map', view.step, view.peptide, block, h),
    () => <List<double>>[for (int i = 0; i < view.focus.inputs; i++) _softmax(view, h, i)],
  );

  /// What place [i] reads of each place up to its own in head [h]: softmax
  /// of its scores as they are kept.
  static List<double> _softmax(LmView view, int h, int i) {
    final TrainingTrace trace = view.trace;
    final List<double> scores = <double>[
      for (int j = 0; j <= i; j++) trace.score(view.checkpoint, block, h, view.peptide, i, j),
    ];
    final double top = scores.reduce(math.max);
    final List<double> e = <double>[for (final double s in scores) math.exp(s - top)];
    final double sum = e.reduce((double a, double b) => a + b);
    return <double>[for (final double x in e) x / sum];
  }

  /// Place [key]'s share of what the place in focus reads, in head [h].
  static double share(LmView view, int h, int key) => shares(view, h)[key];

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
    final double named = through(beat, t.keys, t.keys + 0.3) * (1 - through(beat, t.end - 0.1, t.end + 0.15));
    drawHeadTag(canvas, view, layout, h, beat < t.values + 0.2 ? 'query and keys' : 'values', named);
  }

  /// Head [h]'s name over its strips, and what they hold.
  static void drawHeadTag(Canvas canvas, LmView view, AttentionLayout layout, int h, String what, double alpha) {
    if (alpha > 0) {
      drawTag(
        canvas,
        view,
        'head ${h + 1} · $what',
        Offset(layout.kvLeft - tagPadding, layout.table.layout.tagTop),
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
    final Rect area = Rect.fromLTRB(
      layout.scoreLeft,
      layout.table.row(focus + 1).top,
      layout.kvRight,
      layout.table.row(n - 1).bottom,
    );
    canvas.save();
    canvas.clipRect(area);
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
  /// arrive and kept, side by side, till the join mixes them back to the
  /// stream's width: what the place in focus gains. Then their numbers and
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
    final double mixScale = _mixScale(view);
    final double joined = through(beat, _joinFrom + 0.3, _joinFrom + 0.6);
    // One label under the answers at a time: each head's, then the join's.
    final double headLabels = 1 - through(beat, _joinFrom, _joinFrom + 0.2);
    final double joinLabel = through(beat, _joinFrom + 0.45, _joinFrom + 0.7);
    final StreamTable table = layout.table;
    final List<double> gain = table.gained(0, 1, focus);
    final double gainScale = table.gainScale(0, 1);
    for (int h = 0; h < heads && gone > 0; h++) {
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
    // The join: a sweep across both answers as one more matrix mixes them.
    final Rect all = layout.answers;
    final double sweep = through(beat, _joinFrom, _joinFrom + 0.6);
    if (sweep > 0 && sweep < 1) {
      final double x = all.left + all.width * sweep;
      canvas.drawRect(
        Rect.fromLTRB(math.max(all.left, x - 10), all.top - 1, math.min(all.right, x + 2), all.bottom + 1),
        Paint()..color = view.inks.signal.withValues(alpha: 0.35 * math.sin(math.pi * sweep)),
      );
    }
    if (joined > 0) {
      // The box round both, which grows into head 1's map: what the place in
      // focus read came through its row; the map is every place's.
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.growing(_span(beat, _grow)).inflate(1), const Radius.circular(2.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: joined * outlined),
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

  // -------------------------------------------------------------------- map

  /// The head whose map is drawn: the first, whose reading Scores worked
  /// out. The second's is not drawn.
  static const int mapHead = 0;

  /// How far head 1's map has come: in with its slots as the answers' box
  /// grows into it, and gone as the table widens again.
  static double _mapShown(double beat) =>
      _span(beat, _mapIn) * (1 - through(beat, _widenFrom, _widenFrom + 0.25));

  /// How far the map's cell at row [i], column [j] has filled at [beat], of
  /// [n] places, [focus] in focus: the row in focus first, a cell at a time
  /// from `<bos>`; then every other row, top to bottom, a row at a time.
  static double mapFilled(int i, int j, int focus, int n, double beat) {
    if (i == focus) {
      const double each = 0.25;
      final double start = _focusRow.$1 + (focus < 1 ? 0 : (_focusRow.$2 - _focusRow.$1 - each) * j / focus);
      return through(beat, start, start + each);
    }
    const double each = 0.2;
    final int rank = i < focus ? i : i - 1;
    final double start = _rows.$1 + (n < 3 ? 0 : (_rows.$2 - _rows.$1 - each) * rank / (n - 2));
    return through(beat, start, start + each);
  }

  /// Head 1's map, every place's reading at once, on the table's rows: a row
  /// a place, the tile at its left naming it; its shares of the places up to
  /// its own, each on a soft tile of its colour, its percentage written on it
  /// where it fits; the places after it struck through, never read; and the
  /// places read named under the columns. It comes in as empty slots, seen
  /// only inside the answers' box as the box grows into it.
  void _map(Canvas canvas, LmView view, AttentionLayout layout, double beat) {
    final double shown = _mapShown(beat);
    if (shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int n = view.focus.inputs;
    final int focus = view.position;
    final double grow = _span(beat, _grow);
    final List<List<double>> rows = allShares(view, mapHead);
    final TextStyle? numbers = layout.mapNumbers;
    canvas.save();
    if (grow < 1) {
      canvas.clipRRect(RRect.fromRectAndRadius(layout.growing(grow), const Radius.circular(2.5)));
    }
    _mapHatch(canvas, view, layout, shown);
    final Paint slot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final Paint fill = Paint();
    for (int i = 0; i < n; i++) {
      for (int j = 0; j <= i; j++) {
        final Rect cell = layout.mapCell(i, j).deflate(EmbeddingLayout.gap);
        // The tables' corners, less on a small cell, so it stays a tile.
        final RRect shape = RRect.fromRectAndRadius(
          cell,
          Radius.circular(math.min(EmbeddingLayout.radius, cell.shortestSide * 0.2)),
        );
        final double filled = mapFilled(i, j, focus, n, beat);
        if (filled < 1) {
          canvas.drawRRect(shape, slot..color = view.inks.quiet.withValues(alpha: 0.6 * shown * (1 - filled)));
        }
        if (filled <= 0) {
          continue;
        }
        final double share = rows[i][j];
        // The share's ramp, softened as the tables' tiles are, so the number
        // on it reads.
        final Color colour = Color.lerp(view.inks.zero, view.inks.share(share, view.inks.signal), LmInks.soft)!;
        canvas.drawRRect(shape, fill..color = Color.lerp(view.inks.ground, colour, filled * shown)!);
        if (numbers != null) {
          view.kit.draw(
            canvas,
            percentNumber(share),
            numbers.copyWith(color: numbers.color!.withValues(alpha: (filled * shown * 8).round() / 8)),
            cell.center,
            anchor: const Offset(0.5, 0.5),
          );
        }
      }
    }
    // The places read, a tile under each column.
    for (int j = 0; j < n; j++) {
      drawToken(canvas, view, layout.mapTile(j), trace.inputAt(view.peptide, j), alpha: shown);
    }
    canvas.restore();
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
  static String readsMost(LmView view, int h) {
    final List<int> order = <int>[for (int j = 0; j <= view.position; j++) j]
      ..sort((int a, int b) => share(view, h, b).compareTo(share(view, h, a)));
    return <String>[
      for (int k = 0; k < math.min(2, order.length); k++)
        if (k == 0 || share(view, h, order[k]) >= 0.1)
          '${StreamTable.placeName(view, order[k])} ${percent(share(view, h, order[k]))}',
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
      if (heads > 1)
        (
          first.end,
          _joinFrom,
          '${spelledLeading(heads)} heads ask ${spelled(heads)} questions at once,\n'
              'each with its own query, keys and values',
        ),
      (
        _joinFrom,
        _mapFrom,
        'the answers side by side, then mixed by one more learned matrix\n'
            "back to the stream's ${trace.model.width} numbers",
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
        _widenFrom,
        'each row adds to 100%: the first places share it among few\n'
            'hatched: the places after it, never read; the next is its answer'
            '${switch (heads) {
              1 => '',
              2 => '\nhead 2 reads the same way, with a map of its own',
              _ => '\nthe other ${spelled(heads - 1)} heads read the same way, each with its own map',
            }}',
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
    if (beat < _mapFrom) {
      return heads > 1
          ? "The heads' ${List<String>.filled(heads, '$size').join(' + ')} numbers "
                '× output weights $width × $width: what $focus read'
          : 'Its $size numbers × output weights $width × $width: what $focus read';
    }
    if (beat < _rows.$1) {
      return "Head 1's map: $focus's row first, its shares from Scores";
    }
    if (beat < _widenFrom) {
      return 'Every place does what $focus did, its query on the keys up to it';
    }
    if (beat < _gainUnwritten.$1) {
      return 'What attention adds to each place: ${grouped(n)} rows of $width';
    }
    return 'Added: x0 + attention, ${grouped(n)} × $width';
  }

  @override
  String describe(LmView view, TrainingFrame frame) => 'Attention, step ${view.step}. ${caption(view, frame)}.';
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
  late final TextStyle? mapNumbers = _mapNumbers();

  TextStyle? _mapNumbers() {
    final LmView view = table.view;
    TextStyle at(double points) => inked(view.kit.mono, points, view.inks.ink).copyWith(letterSpacing: 0);
    final double perPoint = view.kit.layout('100', at(10)).width / 10;
    final double room = mapColumn - 2 * EmbeddingLayout.gap - 2;
    // Held to the half point below, so a number is never wider than drawn.
    final double points = (math.min(9, math.min(table.layout.pitch * 0.62, room / perPoint)) * 2).floorToDouble() / 2;
    return points < EmbeddingLayout.leastNumber ? null : at(points);
  }
}
