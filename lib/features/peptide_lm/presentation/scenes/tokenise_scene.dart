import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

/// Tokenise: the dataset, and under it the vocabulary. A light crosses each
/// peptide and every residue it passes flips into its id, its count in the
/// vocabulary rising, `<bos>` leading each from the first frame; then
/// `<eos>` drops in to close each one and padding fills to the longest; then the peptides close up into one matrix,
/// the batch Forward reads, which rises to the top; and the vocabulary turns
/// into a list under it, each token's count along its row. Each part is
/// named on a tag, as the zoom names its parts, in the field's words.
final class TokeniseScene extends LmScene {
  const TokeniseScene();

  /// [beat] of the stage's beats, as a share of the stage.
  static double _at(double beat) => beat / LmStage.tokenise.beats;

  static final double _scanFrom = _at(0.64);
  static final double _scanTo = _at(4.96);
  static final double _stagger = _at(0.28);
  static final double _frameTo = _at(5.92);
  static final double _tableFrom = _at(6.08);
  static final double _tableTo = _at(7.52);
  static final double _liftFrom = _at(7.7);
  static final double _liftTo = _at(8.5);

  /// The vocabulary's turn: its first token leaves the strip, its last
  /// leaves, and how long each takes to reach its row.
  static final double _turnFrom = _at(8.0);
  static final double _turnLast = _at(9.5);
  static final double _flight = _at(1.0);
  static final double _listTagsFrom = _at(10.3);
  static final double _listTagsTo = _at(10.7);

  /// How tall a tile must be to carry its id's number.
  static const double _numbered = idNumbered;

  /// The frame a peptide was trained in: `<bos>`, its residues, `<eos>`, and
  /// padding to the longest.
  static List<int> frameOf(TrainingTrace trace, int peptide) =>
      <int>[trace.inputs[peptide].first, ...trace.targets[peptide]];

  /// How many residues of [peptide] the light has passed.
  static double scanned(TrainingTrace trace, int peptide, double local) {
    final int count = trace.peptides.length;
    final double span = (_scanTo - _scanFrom) - (count - 1) * _stagger;
    final double start = _scanFrom + peptide * _stagger;
    final int residues = trace.peptides[peptide].sequence.length;
    return ((local - start) / span).clamp(0.0, 1.0) * (residues + 1);
  }

  /// How far [id] has gone from its place in the strip to its row of the
  /// list, from 0 to 1: the tokens leave one after another, in order.
  static double turned(TrainingTrace trace, int id, double local) {
    final int count = trace.vocab.length;
    final double start = _turnFrom + (count < 2 ? 0 : id * (_turnLast - _turnFrom) / (count - 1));
    return through(local, start, start + _flight);
  }

  /// Each token's count in the framed peptides, padding left out: the
  /// vocabulary's bars once every peptide is read.
  static List<int> totals(TrainingTrace trace) {
    final List<int> counts = List<int>.filled(trace.vocab.length, 0);
    for (int p = 0; p < trace.peptides.length; p++) {
      final List<int> ids = frameOf(trace, p);
      for (int k = 0; k <= trace.peptides[p].sequence.length + 1; k++) {
        counts[ids[k]]++;
      }
    }
    return counts;
  }

  /// The token the dataset holds most of, framed: the vocabulary's tallest
  /// bar once every peptide is read, where its counts are named.
  static int commonest(TrainingTrace trace) {
    final List<int> counts = totals(trace);
    int best = 0;
    for (int id = 1; id < counts.length; id++) {
      if (counts[id] > counts[best]) {
        best = id;
      }
    }
    return best;
  }

  /// The ids' numbers under the vocabulary, at [size] points.
  static TextStyle _idStyle(LmView view, {double size = 8, double alpha = 1}) =>
      inked(view.kit.mono, size, view.inks.quiet, alpha: alpha);

  /// A token's count at the end of its row of the list.
  static TextStyle _countStyle(LmView view, {double alpha = 1, bool quiet = false}) =>
      inked(view.kit.mono, 10, quiet ? view.inks.quiet : view.inks.ink, alpha: alpha);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) =>
      _paint(canvas, size, view, frame.local, const TokeniseFade());

  /// The stage's last frame, with [fade] leaving out or fading what the
  /// stage after it draws itself or retires: Forward opens on it.
  void paintEnd(Canvas canvas, Size size, LmView view, TokeniseFade fade) =>
      _paint(canvas, size, view, 1, fade);

  void _paint(Canvas canvas, Size size, LmView view, double u, TokeniseFade fade) {
    final _Layout layout = _Layout(size, view);
    final TrainingTrace trace = view.trace;
    final double framing = through(u, _scanTo, _frameTo);
    final double table = through(u, _tableFrom, _tableTo);
    final double lift = through(u, _liftFrom, _liftTo);

    // How many of each token have been read so far: the vocabulary's counts.
    final List<int> counts = List<int>.filled(trace.vocab.length, 0);
    for (int p = 0; p < trace.peptides.length; p++) {
      final List<int> ids = frameOf(trace, p);
      final int residues = trace.peptides[p].sequence.length;
      final double done = scanned(trace, p, u);
      for (int k = 0; k < residues; k++) {
        if (done - k >= 0.5) {
          counts[ids[k + 1]]++;
        }
      }
      if (framing >= 0.5) {
        counts[ids.first]++;
        counts[ids[residues + 1]]++;
      }
    }
    final int most = math.max(1, counts.reduce(math.max));
    if (fade.rows) {
      for (int p = 0; p < trace.peptides.length; p++) {
        _row(canvas, view, layout, p, u, framing, table, lift);
      }
    }
    _vocabulary(canvas, view, layout, counts, most, u, fade);
    _tags(canvas, view, layout, counts, most, u, framing, table, lift, fade.tags);
  }

  /// The vocabulary: a strip of tokens, each count a bar standing on its
  /// token and its id under it; then, one token after another, a list. As a
  /// token flies to its row its bar swings down to lie along the row, still
  /// short, so no long bar sweeps over the rows already set; once level it
  /// grows to the list's length, and the count comes up at the row's end.
  void _vocabulary(
    Canvas canvas,
    LmView view,
    _Layout layout,
    List<int> counts,
    int most,
    double u,
    TokeniseFade fade,
  ) {
    final TrainingTrace trace = view.trace;
    for (int id = 0; id < trace.vocab.length; id++) {
      final double q = turned(trace, id, u);
      final Rect from = layout.vocab.at(id);
      final Rect to = layout.listChip(id);
      final Rect chip = q <= 0 ? from : Rect.lerp(from, to, q)!;
      final double swing = through(q, 0, 0.6);
      final double length =
          _mix(layout.histogram, layout.barMax, through(q, 0.6, 1)) * counts[id] / most;
      if (length > 0) {
        final Color bar = trace.isResidue(id) ? view.inks.residue(trace.token(id)) : view.inks.quiet;
        final double reach = _mix(from.width / 2 + 3, to.width / 2 + 6, q);
        final double thick = _mix(from.width * 0.6, to.height * 0.6, q);
        canvas.save();
        canvas.translate(chip.center.dx, chip.center.dy);
        canvas.rotate(-math.pi / 2 * (1 - swing));
        canvas.drawRect(
          Rect.fromLTWH(reach, -thick / 2, length, thick),
          Paint()..color = bar.withValues(alpha: 0.8 * fade.bars),
        );
        canvas.restore();
      }
      if (fade.entries) {
        drawEntry(canvas, view, chip, id, q, layout.listIdSize);
      }
      // Its count, at the row's end once its bar has grown; padding is
      // none of the data, so it has none.
      final double shown = through(q, 0.75, 1);
      if (shown > 0) {
        final bool pad = trace.token(id) == '<pad>';
        view.kit.draw(
          canvas,
          pad ? '–' : '${counts[id]}',
          _countStyle(view, alpha: shown * fade.counts, quiet: pad),
          Offset(layout.listEnd(id), chip.center.dy),
          anchor: const Offset(1, 0.5),
        );
      }
    }
  }

  /// Token [id]'s tile in the vocabulary and its id: under it in the strip,
  /// left of it in the list ([q] 1, [listIdSize] its size there), going round
  /// the tile's corner on the way rather than across it; at [alpha].
  static void drawEntry(
    Canvas canvas,
    LmView view,
    Rect chip,
    int id,
    double q,
    double listIdSize, {
    double alpha = 1,
  }) {
    drawToken(canvas, view, chip, id, alpha: alpha);
    final double around = math.pi / 2 * q;
    view.kit.draw(
      canvas,
      '$id',
      _idStyle(view, size: _mix(8, listIdSize, q), alpha: alpha),
      chip.center +
          Offset(-(chip.width / 2 + 5) * math.sin(around), (chip.height / 2 + 2) * math.cos(around)),
      anchor: Offset(0.5 + 0.5 * math.sin(around), 0.5 - 0.5 * math.cos(around)),
    );
  }

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  /// Each part named, as the zoom names its parts: the dataset and its
  /// padding once the frames close, then the batch's, which rise with it;
  /// the vocabulary, its counts once the light starts, its special tokens
  /// and its ids, which fade as the vocabulary turns and come up again round
  /// its list.
  void _tags(
    Canvas canvas,
    LmView view,
    _Layout layout,
    List<int> counts,
    int most,
    double u,
    double framing,
    double table,
    double lift,
    double fade,
  ) {
    final TrainingTrace trace = view.trace;
    // Plates stand out of the column as far as the focused peptide's card,
    // so their words line up with what is under them.
    final double start = layout.left - 6;
    final double end = layout.right + 6;

    // The dataset's tags fade where they are as the table starts to close,
    // and the batch's come up over it as it finishes: no plate travels over
    // a name still fading. The batch's rise with it.
    final double leaving = (1 - through(table, 0, 0.5)) * fade;
    final double coming = through(table, 0.5, 1) * fade;
    final double band = layout.batchTag(lift);
    final Rect dataset = drawTag(canvas, view, 'dataset', Offset(start, layout.datasetTag), alpha: leaving);
    final Rect batch = coming > 0
        ? drawTag(canvas, view, 'batch 2D matrix', Offset(start, band), alpha: coming)
        : Rect.zero;
    // Padding, on the last place of the shortest peptide, the first.
    final List<int> shortest = frameOf(trace, 0);
    if (trace.token(shortest.last) == '<pad>') {
      final Offset pad = layout.placeAt(0, shortest.length - 1, table, lift).center;
      if (leaving > 0) {
        _padding(canvas, view, dataset, layout.datasetTag, end, pad, framing * leaving);
      }
      if (coming > 0) {
        _padding(canvas, view, batch, band, end, pad, coming);
      }
    }

    final double strip = (1 - through(u, _liftFrom, _liftFrom + _at(0.4))) * fade;
    if (strip > 0) {
      _stripTags(canvas, view, layout, counts, most, start, end, strip * through(u, _scanFrom, _scanFrom + _at(0.48)), strip);
    }
    final double listed = through(u, _listTagsFrom, _listTagsTo) * fade;
    if (listed > 0) {
      _listTags(canvas, view, layout, counts, most, start, end, listed);
    }
  }

  /// The strip's tags: its name, its counts on the commonest token's bar, its
  /// special tokens bracketed under their ids, and its ids.
  void _stripTags(
    Canvas canvas,
    LmView view,
    _Layout layout,
    List<int> counts,
    int most,
    double start,
    double end,
    double counted,
    double alpha,
  ) {
    final TrainingTrace trace = view.trace;
    final Rect vocabulary = drawTag(canvas, view, 'vocabulary', Offset(start, layout.vocabularyTag), alpha: alpha);
    final int top = commonest(trace);
    final Rect chip = layout.vocab.at(top);
    final Size plate = tagSize(view, 'token counts');
    drawTag(
      canvas,
      view,
      'token counts',
      Offset(
        math.min(math.max(chip.center.dx - plate.width / 2, vocabulary.right + 8), end - plate.width),
        layout.vocabularyTag,
      ),
      target: Offset(chip.center.dx, chip.top - 3 - layout.histogram * counts[top] / most),
      alpha: counted,
    );
    final List<int> specials = _specials(trace);
    if (specials.isNotEmpty) {
      final double x0 = layout.vocab.at(specials.first).left + 2;
      final double x1 = layout.vocab.at(specials.last).right - 2;
      final double y = layout.bracket;
      canvas.drawPath(
        Path()
          ..moveTo(x0, y - 3)
          ..lineTo(x0, y)
          ..lineTo(x1, y)
          ..lineTo(x1, y - 3),
        _bracketPaint(view, alpha),
      );
      drawTag(
        canvas,
        view,
        'special tokens',
        Offset(start, layout.partsTag),
        target: Offset((x0 + x1) / 2, y),
        dot: false,
        alpha: alpha,
      );
    }
    final Size ids = tagSize(view, 'token ids');
    drawTag(
      canvas,
      view,
      'token ids',
      Offset(end - ids.width, layout.partsTag),
      target: Offset(layout.vocab.centre(trace.vocab.length - 1), layout.idsBottom + 3),
      alpha: alpha,
    );
  }

  /// The list's tags: its name and its counts over it, its special tokens
  /// bracketed beside their bars, and its ids from under it.
  void _listTags(
    Canvas canvas,
    LmView view,
    _Layout layout,
    List<int> counts,
    int most,
    double start,
    double end,
    double alpha,
  ) {
    final TrainingTrace trace = view.trace;
    final Rect vocabulary = drawTag(canvas, view, 'vocabulary', Offset(start, layout.listTag), alpha: alpha);
    final Size counted = tagSize(view, 'token counts');
    drawTag(canvas, view, 'token counts', Offset(end - counted.width, layout.listTag), alpha: alpha);
    final List<int> specials = _specials(trace);
    if (specials.isNotEmpty) {
      // A bracket beside the special tokens' bars, past the longest of them
      // and clear of the vocabulary's tag, its tag over it in the same band.
      double reach = 0;
      for (final int id in specials) {
        reach = math.max(reach, layout.listChip(id).right + 6 + layout.barMax * counts[id] / most);
      }
      final Rect first = layout.listChip(specials.first);
      final Rect last = layout.listChip(specials.last);
      final double x = math.max(reach + 8, vocabulary.right + 8 + tagPadding);
      canvas.drawPath(
        Path()
          ..moveTo(x - 3, first.top)
          ..lineTo(x, first.top)
          ..lineTo(x, last.bottom)
          ..lineTo(x - 3, last.bottom),
        _bracketPaint(view, alpha),
      );
      final Size plate = tagSize(view, 'special tokens');
      drawTag(
        canvas,
        view,
        'special tokens',
        Offset(
          math.min(math.max(x - plate.width / 2, vocabulary.right + 8), end - counted.width - 8 - plate.width),
          layout.listTag,
        ),
        target: Offset(x, first.top),
        dot: false,
        alpha: alpha,
      );
    }
    // The ids, on the lowest of the first column's.
    final int lowest = math.min(layout.perColumn, trace.vocab.length) - 1;
    final Rect chip = layout.listChip(lowest);
    final TextPainter number = view.kit.layout('$lowest', _idStyle(view, size: layout.listIdSize));
    drawTag(
      canvas,
      view,
      'token ids',
      Offset(start, layout.listPartsTag),
      target: Offset(chip.left - 5 - number.width / 2, chip.center.dy + number.height / 2 + 2),
      alpha: alpha,
    );
  }

  static List<int> _specials(TrainingTrace trace) => <int>[
    for (int id = 0; id < trace.vocab.length; id++)
      if (!trace.isResidue(id)) id,
  ];

  static Paint _bracketPaint(LmView view, double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = view.inks.quiet.withValues(alpha: alpha);

  /// The padding's tag in the band at [band], beside the tag [beside]: at the
  /// right, [end], or left of there until its line drops straight onto
  /// [pad].
  void _padding(
    Canvas canvas,
    LmView view,
    Rect beside,
    double band,
    double end,
    Offset pad,
    double alpha,
  ) {
    final Size plate = tagSize(view, 'padding');
    double x = end - plate.width;
    if (pad.dx < x + tagPadding) {
      x = math.max(beside.right + 8, pad.dx + tagPadding - plate.width);
    }
    drawTag(canvas, view, 'padding', Offset(x, band), target: pad, alpha: alpha);
  }

  /// A residue's tile part way through turning into its id: [flip] 0 is the
  /// letter, 1 the id.
  static void drawFlip(Canvas canvas, LmView view, Rect rect, int id, double flip, {double numberScale = 0.52}) {
    final double squash = math.cos(math.pi * flip).abs();
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(1, math.max(0.04, squash));
    canvas.translate(-rect.center.dx, -rect.center.dy);
    if (flip < 0.5) {
      drawToken(canvas, view, rect, id, outline: flip > 0 ? view.inks.truth : null);
    } else {
      drawIdTile(canvas, view, rect, id, numberScale: numberScale);
    }
    canvas.restore();
  }

  void _row(
    Canvas canvas,
    LmView view,
    _Layout layout,
    int p,
    double u,
    double framing,
    double table,
    double lift,
  ) {
    final TrainingTrace trace = view.trace;
    final TracePeptide peptide = trace.peptides[p];
    final List<int> ids = frameOf(trace, p);
    final int residues = peptide.sequence.length;
    final double top = layout.rowTop(p);
    final bool focus = p == view.peptide;
    if (focus) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.cardAt(p, table, lift), const Radius.circular(6)),
        Paint()..color = view.inks.card,
      );
    }
    if (table < 1) {
      view.kit.draw(
        canvas,
        '${peptide.source.label} · $residues aa',
        inked(view.kit.sans, 10, focus ? view.inks.ink : view.inks.quiet, alpha: 1 - through(table, 0, 0.5)),
        Offset(layout.left, top),
      );
    }
    final double done = scanned(trace, p, u);
    for (int k = 0; k < ids.length; k++) {
      final Rect rect = layout.placeAt(p, k, table, lift);
      if (k == 0) {
        drawToken(canvas, view, rect, ids[k]);
      } else if (k > residues) {
        drawToken(canvas, view, rect, ids[k], alpha: framing);
      } else {
        drawFlip(canvas, view, rect, ids[k], (done - (k - 1)).clamp(0.0, 1.0));
      }
    }
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) => _focusAt(_Layout(size, view), view, at, 0, 0);

  @override
  LmHit? hitAt(Size size, LmView view, Offset at, TrainingFrame frame) => _focusAt(
    _Layout(size, view),
    view,
    at,
    through(frame.local, _tableFrom, _tableTo),
    through(frame.local, _liftFrom, _liftTo),
  );

  /// The peptide whose rows, or whose row of the table, lie under [at].
  LmHit? _focusAt(_Layout layout, LmView view, Offset at, double table, double lift) {
    for (int p = 0; p < view.trace.peptides.length; p++) {
      final Rect card = layout.cardAt(p, table.roundToDouble(), lift);
      if (at.dy >= card.top && at.dy < card.bottom + 1) {
        return FocusPeptide(p);
      }
    }
    return null;
  }

  @override
  String caption(LmView view, TrainingFrame frame) {
    final TrainingTrace trace = view.trace;
    final int peptides = trace.peptides.length;
    if (frame.local < _scanTo) {
      return '${spelledLeading(peptides)} peptides, ${trace.residues} residues, '
          'become ids in a ${trace.vocab.length}-token vocabulary';
    }
    if (frame.local < _tableFrom) {
      return '<bos> and <eos> frame each one, <pad> fills to the longest: '
          '$peptides × ${trace.width + 1} ids';
    }
    if (frame.local < _liftFrom) {
      final String all = switch (peptides) {
        1 => 'the one peptide',
        2 => 'both peptides',
        _ => 'all ${spelled(peptides)} peptides',
      };
      return 'One batch: $all in one matrix, read by Forward in one pass';
    }
    final int top = commonest(trace);
    final int count = totals(trace)[top];
    return trace.isResidue(top)
        ? 'The vocabulary, counted: ${trace.token(top)} the commonest, '
              '${grouped(count)} of ${grouped(trace.residues)} residues'
        : 'The vocabulary, counted: ${trace.token(top)} the commonest token, ${grouped(count)}';
  }

  @override
  String describe(LmView view, TrainingFrame frame) {
    final TracePeptide focus = view.focus;
    return 'Tokenise. ${caption(view, frame)}. In focus, ${focus.source.label}, '
        '${focus.sequence.length} residues.';
  }
}

/// What Tokenise's last frame leaves out or fades, for the stage that opens
/// on it: the batch's rows and the vocabulary's entries, which it draws
/// itself, and the bars, counts and tags it retires. By default, the frame
/// as Tokenise draws it.
@immutable
final class TokeniseFade {
  const TokeniseFade({
    this.rows = true,
    this.entries = true,
    this.bars = 1,
    this.counts = 1,
    this.tags = 1,
  });

  final bool rows;
  final bool entries;
  final double bars;
  final double counts;
  final double tags;
}

/// Where Tokenise's last frame lays its parts, for the stage that opens on
/// it.
final class TokeniseEnd {
  TokeniseEnd(Size size, LmView view) : _layout = _Layout(size, view);

  final _Layout _layout;

  /// Place [k] of [peptide]'s frame in the risen matrix.
  Rect place(int peptide, int k) => _layout.tableAt(peptide, k, 1);

  /// The card under the peptide in focus, round its row of the matrix.
  Rect card(int peptide) => _layout.cardAt(peptide, 1, 1);

  /// Where the matrix's tag stands, and where every tag starts and ends.
  double get tagBand => _layout.batchTag(1);
  double get tagStart => _layout.left - 6;
  double get tagEnd => _layout.right + 6;

  /// Token [id]'s tile in the vocabulary's list, and its id's size there.
  Rect chip(int id) => _layout.listChip(id);
  double get idSize => _layout.listIdSize;

  /// How many tokens a column of the list holds: all of them where it has
  /// one.
  int get perColumn => _layout.perColumn;
}

/// Top to bottom: the dataset's tag and its peptides, each on two lines
/// where that leaves its tiles room for their numbers, else on one;
/// then the vocabulary's tag, its counts, its tokens and their ids; then the
/// tags under it. The tiles are as large as the width and the height both
/// allow, the room left goes between the peptides, within reason, and the
/// whole is centred. Then the batch's table, centred where the dataset was,
/// risen to the top; and under it the vocabulary as a list, a token a row,
/// in two columns where one would be too cramped.
final class _Layout {
  _Layout(Size size, LmView view) : left = 20, right = size.width - 16 {
    final TrainingTrace trace = view.trace;
    final int peptides = trace.peptides.length;
    width = right - left;
    final double vocabCell = math.min(22, width / trace.vocab.length);
    final int frame = trace.width + 1;
    final double tag = tagSize(view, 'dataset').height;
    final double ids = view.kit.layout('0', TokeniseScene._idStyle(view)).height;
    final double fixed =
        tag + _tagGap + tag + _tagGap + histogram + 3 + vocabCell + 2 + ids + _partsGap + tag;
    final double room = size.height - 12 - fixed;
    // A frame folds once, the same place for every peptide, so its places
    // stay in columns; the second line is the longer, which leaves the first
    // line's last column free for the padding tag's line to pass down. Its
    // square tiles are as large as the width allows, and as the height lets
    // every peptide's two lines be at the least room between peptides.
    final double tallest =
        (room - _leastBetween - peptides * (label + _lineGap) - (peptides - 1) * _leastGap) / (2 * peptides);
    final double folded = math.min(math.min(22, width / (frame - frame ~/ 2)), tallest);
    if (folded >= TokeniseScene._numbered) {
      firstLine = frame ~/ 2;
      tileWidth = folded;
      tileHeight = folded;
    } else {
      // Where two lines cannot number their tiles, one: every place across
      // the width, each as tall as a number needs, up to the 16 pt a wide
      // canvas gives square.
      firstLine = frame;
      tileWidth = math.min(16, width / frame);
      tileHeight = math.max(tileWidth, math.min(16, math.max(TokeniseScene._numbered, tileWidth * 1.5)));
    }
    final int lines = firstLine < frame ? 2 : 1;
    block = label + lines * tileHeight + (lines - 1) * _lineGap;
    final double between = math.min(
      math.max(room - peptides * block - (peptides - 1) * _leastGap, _leastBetween),
      40,
    );
    final double gap = peptides < 2
        ? 0
        : math.min(math.max((room - between - peptides * block) / (peptides - 1), _leastGap), 22);
    rowPitch = block + gap;
    final double rows = peptides * block + (peptides - 1) * gap;
    final double content = fixed + rows + between;
    final double top = math.max(6, (size.height - content) / 2);
    datasetTag = top;
    batchTop = top + tag + _tagGap;
    vocabularyTag = batchTop + rows + between;
    vocab = TokenLayout(
      Rect.fromLTWH(left, vocabularyTag + tag + _tagGap + histogram + 3, width, vocabCell),
      trace.vocab.length,
      most: 22,
    );
    idsBottom = vocab.top + vocab.cell + 2 + ids;
    bracket = idsBottom + 4;
    partsTag = idsBottom + _partsGap;
    // The batch as one matrix: a peptide a row, every place across the
    // width, each tall enough for its number; centred where the dataset
    // was, its tag over it; then risen, its tag where the dataset's was.
    tableWidth = math.min(16, width / frame);
    tableHeight = math.max(tableWidth, math.min(16, math.max(TokeniseScene._numbered, tableWidth * 1.5)));
    final double grid = peptides * tableHeight + (peptides - 1) * _tableGap;
    final double extent = tag + _tagGap + rows;
    datasetTagEnd = datasetTag + math.max(0, (extent - tag - _tagGap - grid) / 2);
    tableTop = datasetTagEnd + tag + _tagGap;
    risenTableTop = datasetTag + tag + _tagGap;
    // The vocabulary as a list under the risen table, its tag over it and
    // the ids' tag under it: a token a row, in one column where each row has
    // 15 pt, else in two.
    final int count = trace.vocab.length;
    listTag = risenTableTop + grid + _listGap;
    listTop = listTag + tag + _tagGap;
    final double listBottom = size.height - 6 - _partsGap - tag;
    listPartsTag = listBottom + _partsGap;
    final double area = math.max(0, listBottom - listTop);
    final int columns = area / count >= 15 ? 1 : 2;
    perColumn = (count / columns).ceil();
    listRow = math.min(22, area / perColumn);
    listColumn = (width - (columns - 1) * _columnGap) / columns;
    listChipSize = math.max(4, math.min(18, listRow - 3));
    listIdSize = math.min(9.5, math.max(8, listChipSize * 0.6));
    listIdWidth =
        view.kit.layout('8' * '${count - 1}'.length, TokeniseScene._idStyle(view, size: listIdSize)).width + 6;
    final double countWidth = view.kit.layout('8' * '${trace.residues}'.length, TokeniseScene._countStyle(view)).width;
    barMax = math.max(0, listColumn - listIdWidth - listChipSize - 6 - countWidth - 8);
  }

  /// Between the table's rows.
  static const double _tableGap = 2;

  /// From a tag over a block to the block.
  static const double _tagGap = 8;

  /// From the ids' numbers to the tags under them: room for a bracket and
  /// its line.
  static const double _partsGap = 12;

  /// Between a peptide's two lines.
  static const double _lineGap = 3;

  /// The least room between two peptides, and between the dataset and the
  /// vocabulary.
  static const double _leastGap = 5;
  static const double _leastBetween = 12;

  /// From the risen table to the list's tag, and between the list's two
  /// columns.
  static const double _listGap = 16;
  static const double _columnGap = 16;

  final double left;
  final double right;
  late final double width;

  /// How many places of a frame the first line holds: all of them where it
  /// is not folded.
  late final int firstLine;

  /// A place's tile: square where the frame is folded, else taller than wide.
  late final double tileWidth;
  late final double tileHeight;

  /// A peptide's name and its lines.
  late final double block;
  late final double rowPitch;
  late final double datasetTag;
  late final double batchTop;
  late final double vocabularyTag;
  late final TokenLayout vocab;
  late final double idsBottom;
  late final double bracket;
  late final double partsTag;

  /// The table's tiles, and where it and its tag are once it has closed,
  /// and once it has risen.
  late final double tableWidth;
  late final double tableHeight;
  late final double tableTop;
  late final double datasetTagEnd;
  late final double risenTableTop;

  /// The vocabulary's list: its tag, its first row, the ids' tag under it,
  /// how many rows a column, a row's height and a column's width, a token's
  /// tile, its id's size and the room for its id, and the longest bar.
  late final double listTag;
  late final double listTop;
  late final double listPartsTag;
  late final int perColumn;
  late final double listRow;
  late final double listColumn;
  late final double listChipSize;
  late final double listIdSize;
  late final double listIdWidth;
  late final double barMax;

  final double histogram = 24;
  final double label = 14;

  double rowTop(int peptide) => batchTop + peptide * rowPitch;

  /// The batch's tag, [lift] of the way from over the closed table to the
  /// top.
  double batchTag(double lift) => datasetTagEnd + (datasetTag - datasetTagEnd) * lift;

  double _tableTopAt(double lift) => tableTop + (risenTableTop - tableTop) * lift;

  /// Place [k] of [peptide]'s frame in the table, [lift] of the way risen.
  Rect tableAt(int peptide, int k, double lift) => Rect.fromLTWH(
    left + k * tableWidth,
    _tableTopAt(lift) + peptide * (tableHeight + _tableGap),
    tableWidth,
    tableHeight,
  );

  /// Place [k] of [peptide]'s frame, [table] of the way from its rows to
  /// the table, and the table [lift] of the way risen.
  Rect placeAt(int peptide, int k, double table, double lift) => table <= 0
      ? batchAt(peptide, k)
      : table >= 1
      ? tableAt(peptide, k, lift)
      : Rect.lerp(batchAt(peptide, k), tableAt(peptide, k, lift), table)!;

  /// The card under [peptide] in focus: round its name and its lines, then
  /// round its row of the table.
  Rect cardAt(int peptide, double table, double lift) {
    final Rect rows = Rect.fromLTWH(left - 6, rowTop(peptide) - 4, width + 12, block + 9);
    final Rect row = Rect.fromLTWH(
      left - 4,
      _tableTopAt(lift) + peptide * (tableHeight + _tableGap) - _tableGap / 2 - 1,
      width + 8,
      tableHeight + _tableGap + 2,
    );
    return Rect.lerp(rows, row, table)!;
  }

  /// Place [k] of [peptide]'s frame: on the first line, or folded onto the
  /// second.
  Rect batchAt(int peptide, int k) {
    final int line = k < firstLine ? 0 : 1;
    final int column = k - line * firstLine;
    return Rect.fromLTWH(
      left + column * tileWidth,
      rowTop(peptide) + label + line * (tileHeight + _lineGap),
      tileWidth,
      tileHeight,
    );
  }

  double _columnLeft(int id) => left + (id ~/ perColumn) * (listColumn + _columnGap);

  /// Token [id]'s tile in the list: its row, after the room for its id.
  Rect listChip(int id) => Rect.fromLTWH(
    _columnLeft(id) + listIdWidth,
    listTop + (id % perColumn) * listRow + (listRow - listChipSize) / 2,
    listChipSize,
    listChipSize,
  );

  /// The end of token [id]'s row, where its count is set.
  double listEnd(int id) => _columnLeft(id) + listColumn;
}
