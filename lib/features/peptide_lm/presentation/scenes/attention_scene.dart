import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'stream_table.dart';

/// When one head does each part of its reading, in beats: its keys and the
/// query come, the query passes every key up to its own place, the scores
/// become shares, the values flow; and when it is done.
typedef HeadTimes = ({double keys, double scan, double soft, double values, double end});

/// Attention, block 1's first part, as the engine runs it
/// (`nn.MultiheadAttention` after the block's first LayerNorm). It opens on
/// Embedding's last frame, x0 a row a place, whose numbers go as the table
/// narrows to a strip a place. Then, for the place in focus, one head at a
/// time: every place makes a key, the place in focus a query; the query
/// passes each key up to its own place and a score is written beside each;
/// softmax makes them shares; each key turns into its place's value, and
/// arcs carry each share of each value into the head's answer. Head 1 takes
/// its time and the others follow quicker; their answers, side by side, are
/// mixed back to the stream's width. Every place does the same at once: a
/// map a head, a row a place. Last, the table widens again: what attention
/// adds to each place, alone, and then added, x0 + attention, the first
/// point of the stream after x0.
///
/// Every number is the run's: the scores, the shares, and each point of the
/// stream, whole.
final class AttentionScene extends LmScene {
  const AttentionScene();

  /// The block this stage shows; Forward shows them all.
  static const int block = 0;

  static double get _beats => LmStage.attention.beats.toDouble();

  // The open: x0's numbers go, then the table narrows to a strip a place, and
  // the place in focus is outlined.
  static const (double, double) _numbersOut = (0.0, 0.25);
  static const (double, double) _squeeze = (0.2, 0.95);
  static const (double, double) _outline = (0.5, 0.9);
  static const (double, double) _noteOut = (0.0, 0.25);

  // The heads: the first takes its time, the others share what is left
  // before the join.
  static const double _headsFrom = 1.0;
  static const double _firstHeadTo = 6.0;
  static const double _joinFrom = 8.8;
  static const double _mapsFrom = 9.6;
  static const double _widenFrom = 11.0;
  static const double _widenTo = 11.8;

  // What attention added, alone on its own scale, then the sums.
  static const (double, double) _alone = (11.0, 11.6);
  static const (double, double) _gainWritten = (11.8, 12.0);
  static const (double, double) _gainUnwritten = (12.4, 12.6);
  static const (double, double) _add = (12.5, 12.9);
  static const (double, double) _sumsWritten = (12.7, 12.9);

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// When head [h] of [heads] does each part.
  static HeadTimes times(int h, int heads) {
    if (h == 0 || heads < 2) {
      return (keys: _headsFrom, scan: 1.8, soft: 3.6, values: 4.4, end: _firstHeadTo);
    }
    final double span = (_joinFrom - _firstHeadTo) / (heads - 1);
    final double start = _firstHeadTo + (h - 1) * span;
    return (
      keys: start,
      scan: start + span * 0.18,
      soft: start + span * 0.46,
      values: start + span * 0.6,
      end: start + span,
    );
  }

  /// The head on screen at [beat], or null outside the heads.
  static int? headAt(double beat, int heads) {
    if (beat < _headsFrom || beat >= _joinFrom) {
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
    // Embedding's note and its x0 tag, going as this stage's come.
    const EmbeddingScene().paintEnd(
      canvas,
      size,
      view,
      EmbeddingFade(
        rows: false,
        chrome: 1 - through(beat, _widenFrom - 0.1, _widenFrom + 0.1),
        note: 1 - _span(beat, _noteOut),
      ),
    );
    table.note(canvas, notes(view), beat);
    final int width = trace.model.width;
    final int n = view.focus.inputs;
    table.tag(
      canvas,
      'what attention adds · $n × $width',
      through(beat, _widenFrom + 0.1, _widenFrom + 0.3) * (1 - through(beat, _gainUnwritten.$1, _gainUnwritten.$2)),
    );
    table.tag(canvas, 'x0 + attention · $n × $width', through(beat, _gainUnwritten.$2, _gainUnwritten.$2 + 0.2));
    _stream(canvas, size, view, layout, beat);
    table.drawTiles(canvas);
    table.outline(canvas, view.position, layout.stream(view.position, _squeezeAt(beat)).right, _span(beat, _outline));
    final int heads = trace.model.heads;
    for (int h = 0; h < heads; h++) {
      _head(canvas, view, layout, beat, h);
    }
    _answers(canvas, view, layout, beat);
    _maps(canvas, view, layout, beat);
  }

  /// How narrow the table is at [beat]: 0 written out, 1 a strip a place.
  static double _squeezeAt(double beat) =>
      _span(beat, _squeeze) * (1 - through(beat, _widenFrom, _widenTo));

  // ---------------------------------------------------------------- stream

  /// Each place's row: x0, its numbers going as it narrows; then, wide again,
  /// what attention adds to it, alone on its own scale, and the sum.
  void _stream(Canvas canvas, Size size, LmView view, AttentionLayout layout, double beat) {
    final StreamTable table = layout.table;
    final int n = view.focus.inputs;
    final double squeeze = _squeezeAt(beat);
    final double alone = _span(beat, _alone);
    final double add = _span(beat, _add);
    final double scale = table.scale;
    final double gainScale = table.gainScale(0, 1);
    final double x0Text = 1 - _span(beat, _numbersOut);
    final double gainText = _span(beat, _gainWritten) * (1 - _span(beat, _gainUnwritten));
    final double sumText = _span(beat, _sumsWritten);
    for (int i = 0; i < n; i++) {
      final Rect rect = layout.stream(i, squeeze);
      final List<double> x0 = table.values(0, i);
      if (alone <= 0) {
        table.drawRow(canvas, rect, x0, scale: scale, text: squeeze > 0.02 ? 0 : x0Text);
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
  static double _qkvScale(LmView view, int h) => view.kit.memo<double>(
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

  /// Place [key]'s share of what the place in focus reads, in head [h].
  static double share(LmView view, int h, int key) =>
      view.trace.attention(view.checkpoint, block, h, view.peptide, view.position, key);

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
    final int focus = view.position;
    final int size = trace.headSize;
    final double scale = _qkvScale(view, h);
    final double flip = through(beat, t.values, t.values + 0.4);
    // Every place's key, then its value; those after the place in focus
    // faint, and struck through: it never reads them.
    for (int j = 0; j < n; j++) {
      final double grow = through(beat, t.keys + 0.3 * j / math.max(1, n - 1), t.keys + 0.3 * j / math.max(1, n - 1) + 0.3);
      if (grow <= 0) {
        continue;
      }
      final Rect strip = layout.kv(j);
      // Each strip comes out of its row from the left, its cells uncovered,
      // not squeezed.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(strip.left - 1, strip.top - 1, strip.width * grow + 2, strip.height + 2));
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
              shown * (j > focus ? 0.3 : 1),
            )!,
        ],
        gap: 0.5,
        radius: 1.5,
      );
      canvas.restore();
    }
    _hatch(canvas, view, layout, shown);
    _scores(canvas, view, layout, beat, h, t, shown);
    _query(canvas, view, layout, beat, h, t, shown);
    _arcs(canvas, view, layout, beat, h, t, shown);
    final double named = through(beat, t.keys, t.keys + 0.3) * (1 - through(beat, t.end - 0.1, t.end + 0.15));
    if (named > 0) {
      drawTag(
        canvas,
        view,
        'head ${h + 1} · ${beat < t.values ? 'query and keys' : 'values'}',
        Offset(layout.kvLeft - tagPadding, layout.table.layout.tagTop),
        alpha: named,
      );
    }
  }

  /// The places after the one in focus, which it never reads: their keys and
  /// scores struck through.
  void _hatch(Canvas canvas, LmView view, AttentionLayout layout, double alpha) {
    final int n = view.focus.inputs;
    final int focus = view.position;
    if (focus >= n - 1) {
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
  static double _scanRow(double beat, HeadTimes t, int focus) =>
      focus * (1 - ((beat - t.scan) / (t.soft - t.scan)).clamp(0.0, 1.0));

  /// Each score beside its key as the query passes it, then each share.
  void _scores(Canvas canvas, LmView view, AttentionLayout layout, double beat, int h, HeadTimes t, double shown) {
    if (beat < t.scan) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int focus = view.position;
    final double row = _scanRow(beat, t, focus);
    final double soft = through(beat, t.soft, t.soft + 0.5);
    final TextStyle face = inked(view.kit.mono, layout.textSize, view.inks.ink);
    for (int j = 0; j <= focus; j++) {
      // A key's score appears as the query reaches it.
      final double reached = (j - row + 1).clamp(0.0, 1.0) * shown;
      if (reached <= 0) {
        continue;
      }
      final Rect cell = layout.score(j);
      final double score = trace.score(view.checkpoint, block, h, view.peptide, focus, j);
      final double part = share(view, h, j);
      if (soft < 1) {
        view.kit.draw(
          canvas,
          fixed(score, 1),
          inked(view.kit.mono, layout.textSize, view.inks.ink, alpha: reached * (1 - soft)),
          Offset(cell.right, cell.center.dy),
          anchor: const Offset(1, 0.5),
        );
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

  /// The query of the place in focus: over its own key as it comes, then
  /// passing each key up to `<bos>`, lifted over it and outlined.
  void _query(Canvas canvas, LmView view, AttentionLayout layout, double beat, int h, HeadTimes t, double shown) {
    final double alpha = through(beat, t.keys + 0.2, t.keys + 0.5) * (1 - through(beat, t.soft, t.soft + 0.3)) * shown;
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int focus = view.position;
    final double row = _scanRow(beat, t, focus);
    final Rect at = layout.kv(focus).shift(Offset(0, (row - focus) * layout.table.layout.pitch - 3));
    final double scale = _qkvScale(view, h);
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
    final Rect slot = layout.slot(h);
    final Offset end = Offset(slot.center.dx, slot.top);
    // Values ride the arcs while the answer fills, about once a beat.
    final double riding = beat >= t.values + 0.4 && beat < t.end - 0.1 ? (beat - t.values) % 1 : -1;
    for (int j = 0; j <= focus; j++) {
      final double part = share(view, h, j);
      final double w = part / most;
      if (part < 0.01) {
        continue;
      }
      final (Offset, Offset, Offset, Offset) curve = layout.arc(j, end);
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
  /// stream's width: what the place in focus gains.
  void _answers(Canvas canvas, LmView view, AttentionLayout layout, double beat) {
    final TrainingTrace trace = view.trace;
    final int heads = trace.model.heads;
    final int focus = view.position;
    final double gone = 1 - through(beat, _mapsFrom, _mapsFrom + 0.25);
    if (gone <= 0) {
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
    for (int h = 0; h < heads; h++) {
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
    final double sweep = through(beat, _joinFrom, _joinFrom + 0.6);
    if (sweep > 0 && sweep < 1) {
      final Rect all = Rect.fromLTRB(layout.slot(0).left, layout.slot(0).top, layout.slot(heads - 1).right, layout.slot(0).bottom);
      final double x = all.left + all.width * sweep;
      canvas.drawRect(
        Rect.fromLTRB(math.max(all.left, x - 10), all.top - 1, math.min(all.right, x + 2), all.bottom + 1),
        Paint()..color = view.inks.signal.withValues(alpha: 0.35 * math.sin(math.pi * sweep)),
      );
    }
    if (joined > 0) {
      final Rect all = Rect.fromLTRB(layout.slot(0).left, layout.slot(0).top, layout.slot(heads - 1).right, layout.slot(0).bottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(all.inflate(1), const Radius.circular(2.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: joined * gone),
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

  // ------------------------------------------------------------------- maps

  /// How far the maps have come: in, built a row at a time, and gone as the
  /// table widens.
  static double _mapsShown(double beat) =>
      through(beat, _mapsFrom, _mapsFrom + 0.25) * (1 - through(beat, _widenFrom, _widenFrom + 0.25));

  /// Every place's reading at once: a map a head, a row a place, its shares
  /// of the places up to its own; above the diagonal, the places after it,
  /// struck through.
  void _maps(Canvas canvas, LmView view, AttentionLayout layout, double beat) {
    final double shown = _mapsShown(beat);
    if (shown <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final int n = view.focus.inputs;
    final double built = through(beat, _mapsFrom + 0.2, _mapsFrom + 1.0) * n;
    for (int h = 0; h < trace.model.heads; h++) {
      final Rect square = layout.map(h);
      canvas.drawRect(square, Paint()..color = view.inks.card.withValues(alpha: shown));
      final GridMesh map = GridMesh(square, n, n);
      for (int i = 0; i < n; i++) {
        final double row = (built - i).clamp(0.0, 1.0) * shown;
        for (int j = 0; j < n; j++) {
          if (j > i || row <= 0) {
            map.cell(j, i, view.inks.card.withValues(alpha: shown));
            continue;
          }
          final double w = trace.attention(view.checkpoint, block, h, view.peptide, i, j);
          map.cell(j, i, Color.lerp(view.inks.card, view.inks.signal, math.sqrt(w) * row)!.withValues(alpha: shown));
        }
      }
      map.draw(canvas);
      canvas.save();
      canvas.clipPath(Path()
        ..moveTo(square.left + square.width / n, square.top)
        ..lineTo(square.right, square.top)
        ..lineTo(square.right, square.bottom - square.height / n)
        ..close());
      final Path hatch = Path();
      for (double d = 0; d < square.width * 2; d += 6) {
        hatch
          ..moveTo(square.left + d, square.top)
          ..lineTo(square.left + d - square.width, square.top + square.width);
      }
      canvas.drawPath(
        hatch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = view.inks.rule.withValues(alpha: shown),
      );
      canvas.restore();
      final double rowHeight = square.height / n;
      canvas.drawRect(
        Rect.fromLTWH(
          square.left,
          square.top + view.position * rowHeight,
          (view.position + 1) * square.width / n,
          rowHeight,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: shown * (built > view.position ? 1 : 0)),
      );
      final bool chosen = view.head == h;
      canvas.drawRect(
        square.inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = chosen ? 1.6 : 0.8
          ..color = (chosen ? view.inks.signal : view.inks.rule).withValues(alpha: shown),
      );
      view.kit.draw(
        canvas,
        'head ${h + 1}',
        inked(view.kit.sans, 9, chosen ? view.inks.signal : view.inks.quiet, alpha: shown),
        Offset(square.left, square.bottom + 3),
      );
    }
  }

  // ------------------------------------------------------------------- taps

  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) {
    final double beat = frame.local * _beats;
    final AttentionLayout layout = AttentionLayout(size, view);
    if (_mapsShown(beat) > 0.5) {
      for (int h = 0; h < view.trace.model.heads; h++) {
        if (layout.map(h).inflate(6).contains(at)) {
          return FocusHead(view.head == h ? null : h);
        }
      }
    }
    final int? i = layout.table.placeAt(at);
    return i == null ? null : FocusPosition(i);
  }

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
    final int size = trace.headSize;
    final int heads = trace.model.heads;
    final HeadTimes first = times(0, heads);
    return <(double, double, String)>[
      (
        0.25,
        _headsFrom,
        'A place still knows only itself: which residue, and where.\n'
            'Attention lets it read the places up to its own, never those after.',
      ),
      (
        _headsFrom,
        first.soft,
        'query: what a place looks for; key: what each place offers\n'
            'both made from the row evened out (LayerNorm), $size numbers a head\n'
            'a score: the two multiplied number by number, summed, over √$size',
      ),
      (
        first.soft,
        first.values,
        'softmax: e to each score, over their sum\n'
            'shares that add to 100%, the highest score taking most',
      ),
      (
        first.values,
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
        _mapsFrom,
        'the answers side by side, then mixed by one more learned matrix\n'
            "back to the stream's ${trace.model.width} numbers",
      ),
      (
        _mapsFrom,
        _widenFrom,
        "every place reads at once; a map's row is one place's shares\n"
            'the hatched half: the places after it, never read',
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
    if (beat < _headsFrom) {
      return 'Block 1 of ${trace.model.layers}, attention: each place reads the places up to its own';
    }
    final int? h = headAt(beat, heads);
    if (h != null) {
      final HeadTimes t = times(h, heads);
      if (h > 0) {
        return 'Head ${h + 1}, its own query and keys: $focus reads ${readsMost(view, h)}';
      }
      if (beat < t.scan) {
        return 'Head 1: every place makes a key, and $focus a query, $size numbers each';
      }
      if (beat < t.soft) {
        return "$focus's query against each key up to its own: ${grouped(view.position + 1)} "
            '${view.position == 0 ? 'score' : 'scores'}';
      }
      if (beat < t.values) {
        return 'Softmax makes the scores shares of one: ${readsMost(view, 0)}';
      }
      return "Head 1 hands $focus its shares of each place's value: $size numbers";
    }
    if (beat < _mapsFrom) {
      return heads > 1
          ? "The ${spelled(heads)} heads' ${List<String>.filled(heads, '$size').join(' + ')} numbers, "
                'mixed back to $width: what $focus read'
          : 'Mixed back to $width: what $focus read';
    }
    if (beat < _widenFrom) {
      return 'Every place at once: a map row each, nothing above the diagonal';
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
/// slot for each head's answer, at the right. The maps take the room right
/// of the strips.
final class AttentionLayout {
  AttentionLayout(this.size, LmView view) : table = StreamTable(size, view) {
    final EmbeddingLayout e = table.layout;
    final TrainingTrace trace = view.trace;
    final double room = e.right - e.cellsLeft;
    const double gaps = 6 + 6;
    scoreWidth = math.max(
      26.0,
      view.kit.layout('100%', inked(view.kit.mono, textSize, view.inks.ink)).width + 4,
    );
    // A unit a cell: the narrowed strip 0.8 of it, keys, values and answers
    // one each, the arcs what is left, at least 50.
    final double unit = math.min(
      7.0,
      (room - gaps - scoreWidth - 50) / (trace.model.width * 0.8 + trace.headSize + trace.model.width),
    );
    narrow = trace.model.width * unit * 0.8;
    scoreLeft = e.cellsLeft + narrow + 6;
    kvLeft = scoreLeft + scoreWidth + 6;
    kvRight = kvLeft + trace.headSize * unit;
    slotCell = unit;
    slotsLeft = e.right - trace.model.width * unit - 2;
    focusRow = view.position;
    headSize = trace.headSize;
    heads = trace.model.heads;
    places = view.focus.inputs;
  }

  final Size size;
  final StreamTable table;

  /// The narrowed strip's width.
  late final double narrow;

  late final double scoreWidth;
  late final double scoreLeft;
  late final double kvLeft;
  late final double kvRight;
  late final double slotCell;
  late final double slotsLeft;
  late final int focusRow;
  late final int headSize;
  late final int heads;
  late final int places;

  /// The size scores and shares are written at.
  double get textSize => (table.layout.pitch * 0.6).clamp(6.5, 9.0);

  /// Place [i]'s row, [squeeze] of the way to the narrowed strip.
  Rect stream(int i, double squeeze) => table.squeezed(i, narrow, squeeze);

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

  /// Head [h]'s answer, on the row in focus.
  Rect slot(int h) {
    final Rect band = _band(focusRow);
    final double left = slotsLeft + h * headSize * slotCell;
    return Rect.fromLTRB(left, band.top, left + headSize * slotCell, band.bottom);
  }

  /// The arc from place [j]'s value to [end], the top of a head's answer:
  /// out of the value level, then down onto the answer from above.
  (Offset, Offset, Offset, Offset) arc(int j, Offset end) {
    final double y = table.row(j).center.dy;
    final Offset start = Offset(kvRight + 2, y);
    final double lift = math.max(8.0, (end.dy - y) * 0.5);
    return (
      start,
      Offset(start.dx + (end.dx - start.dx) * 0.55, math.min(y, end.dy - 6)),
      Offset(end.dx, end.dy - lift),
      end,
    );
  }

  /// Head [h]'s map, the heads' maps stacked in the room right of the strips.
  Rect map(int h) {
    final double top = table.row(0).top;
    final double bottom = table.row(places - 1).bottom;
    const double label = 14;
    final double side = math.min(table.layout.right - kvLeft, (bottom - top - heads * label) / heads);
    return Rect.fromLTWH(kvLeft, top + h * (side + label), side, side);
  }
}
