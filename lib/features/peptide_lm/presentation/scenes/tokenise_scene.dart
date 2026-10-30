import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

/// Tokenise: the dataset, and under it the vocabulary. A light crosses each
/// peptide and every residue it passes flips into its id, its count in the
/// vocabulary rising; then `<bos>` and `<eos>` drop in to frame each one and
/// padding fills to the longest. Each part is named on a tag, as the zoom
/// names its parts, in the field's words.
final class TokeniseScene extends LmScene {
  const TokeniseScene();

  static const double _scanFrom = 0.08;
  static const double _scanTo = 0.62;
  static const double _stagger = 0.035;
  static const double _frameTo = 0.74;
  static const double _shiftFrom = 0.76;

  /// How tall a tile must be to carry its id's number.
  static const double _numbered = 11;

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

  /// The token the dataset holds most of, framed: the vocabulary's tallest
  /// bar once every peptide is read, where its counts are named.
  static int commonest(TrainingTrace trace) {
    final List<int> counts = List<int>.filled(trace.vocab.length, 0);
    for (int p = 0; p < trace.peptides.length; p++) {
      final List<int> ids = frameOf(trace, p);
      for (int k = 0; k <= trace.peptides[p].sequence.length + 1; k++) {
        counts[ids[k]]++;
      }
    }
    int best = 0;
    for (int id = 1; id < counts.length; id++) {
      if (counts[id] > counts[best]) {
        best = id;
      }
    }
    return best;
  }

  /// The ids' numbers under the vocabulary.
  static TextStyle _idStyle(LmView view) => inked(view.kit.mono, 8, view.inks.quiet);

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final _Layout layout = _Layout(size, view);
    final TrainingTrace trace = view.trace;
    final double u = frame.local;
    final double framing = through(u, _scanTo, _frameTo);

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
    for (int p = 0; p < trace.peptides.length; p++) {
      _row(canvas, view, layout, p, u, framing);
    }
    _vocabulary(canvas, view, layout, counts, most);
    _tags(canvas, view, layout, counts, most, u, framing);
  }

  void _vocabulary(Canvas canvas, LmView view, _Layout layout, List<int> counts, int most) {
    final TokenLayout row = layout.vocab;
    for (int id = 0; id < view.trace.vocab.length; id++) {
      final Rect cell = row.at(id);
      final double height = layout.histogram * counts[id] / most;
      if (height > 0) {
        final Color bar = view.trace.isResidue(id)
            ? view.inks.residue(view.trace.token(id))
            : view.inks.quiet;
        canvas.drawRect(
          Rect.fromLTWH(cell.left + cell.width * 0.2, cell.top - 3 - height, cell.width * 0.6, height),
          Paint()..color = bar.withValues(alpha: 0.8),
        );
      }
      drawToken(canvas, view, cell, id);
      view.kit.draw(
        canvas,
        '$id',
        _idStyle(view),
        Offset(cell.center.dx, cell.bottom + 2),
        anchor: const Offset(0.5, 0),
      );
    }
  }

  /// Each part named, as the zoom names its parts: the dataset and its
  /// padding once the frames close; the vocabulary, its counts once the light
  /// starts, its special tokens and its ids.
  void _tags(
    Canvas canvas,
    LmView view,
    _Layout layout,
    List<int> counts,
    int most,
    double u,
    double framing,
  ) {
    final TrainingTrace trace = view.trace;
    // Plates stand out of the column as far as the focused peptide's card,
    // so their words line up with what is under them.
    final double start = layout.left - 6;
    final double end = layout.right + 6;

    final Rect dataset = drawTag(canvas, view, 'dataset', Offset(start, layout.datasetTag));
    // Padding, on the last place of the shortest peptide, the first: its
    // plate at the right, or left of there until its line drops straight.
    final List<int> shortest = frameOf(trace, 0);
    if (trace.token(shortest.last) == '<pad>') {
      final Size plate = tagSize(view, 'padding');
      final Offset pad = layout.batchAt(0, shortest.length - 1).center;
      double x = end - plate.width;
      if (pad.dx < x + tagPadding) {
        x = math.max(dataset.right + 8, pad.dx + tagPadding - plate.width);
      }
      drawTag(
        canvas,
        view,
        'padding',
        Offset(x, layout.datasetTag),
        target: pad,
        alpha: framing,
      );
    }

    final Rect vocabulary = drawTag(canvas, view, 'vocabulary', Offset(start, layout.vocabularyTag));
    // The counts, on the bar of the token the dataset holds most of.
    final int top = commonest(trace);
    final Rect chip = layout.vocab.at(top);
    final Size counted = tagSize(view, 'token counts');
    drawTag(
      canvas,
      view,
      'token counts',
      Offset(
        math.min(math.max(chip.center.dx - counted.width / 2, vocabulary.right + 8), end - counted.width),
        layout.vocabularyTag,
      ),
      target: Offset(chip.center.dx, chip.top - 3 - layout.histogram * counts[top] / most),
      alpha: through(u, _scanFrom, _scanFrom + 0.06),
    );

    // The special tokens, bracketed under their ids.
    final List<int> specials = <int>[
      for (int id = 0; id < trace.vocab.length; id++)
        if (!trace.isResidue(id)) id,
    ];
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
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.quiet,
      );
      drawTag(
        canvas,
        view,
        'special tokens',
        Offset(start, layout.partsTag),
        target: Offset((x0 + x1) / 2, y),
        dot: false,
      );
    }
    // The ids, on the last.
    final Size ids = tagSize(view, 'token ids');
    drawTag(
      canvas,
      view,
      'token ids',
      Offset(end - ids.width, layout.partsTag),
      target: Offset(layout.vocab.centre(trace.vocab.length - 1), layout.idsBottom + 3),
    );
  }

  /// A token as its id: a plain tile under a stripe of its residue's colour,
  /// the id in the accent; an end of the frame or padding in the quiet ink.
  void _idTile(Canvas canvas, LmView view, Rect rect, int id, {double alpha = 1}) {
    if (alpha <= 0) {
      return;
    }
    final TrainingTrace trace = view.trace;
    final Rect tile = rect.deflate(math.min(1.0, rect.width * 0.08));
    final bool residue = trace.isResidue(id);
    final bool pad = trace.token(id) == '<pad>';
    final RRect shape = RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.18));
    if (pad) {
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = view.inks.rule.withValues(alpha: alpha),
      );
    } else {
      canvas.drawRRect(shape, Paint()..color = view.inks.zero.withValues(alpha: alpha));
      final Color stripe = residue ? view.inks.residue(trace.token(id)) : view.inks.quiet;
      final double band = tile.height < 11 ? tile.height * 0.4 : math.max(1.5, tile.height * 0.14);
      canvas.save();
      canvas.clipRRect(shape);
      canvas.drawRect(
        Rect.fromLTWH(tile.left, tile.top, tile.width, band),
        Paint()..color = stripe.withValues(alpha: alpha),
      );
      canvas.restore();
    }
    // The number as large as the tile's height allows, and narrow enough
    // that the vocabulary's longest id fits across it.
    final String widest = '8' * '${trace.vocab.length - 1}'.length;
    final double perPoint = view.kit.layout(widest, inked(view.kit.mono, 10, view.inks.quiet)).width / 10;
    // Held to the half point below, so the drawn number is never wider.
    final double size = (math.min(math.min(tile.height * 0.52, tile.width / perPoint), 14) * 2).floorToDouble() / 2;
    if (tile.height >= _numbered && size >= 5) {
      view.kit.draw(
        canvas,
        '$id',
        inked(
          view.kit.mono,
          size,
          residue ? view.inks.signal : view.inks.quiet,
          alpha: alpha,
        ),
        tile.center + Offset(0, tile.height * 0.06),
        anchor: const Offset(0.5, 0.5),
      );
    }
  }

  /// A residue's tile part way through turning into its id: [flip] 0 is the
  /// letter, 1 the id.
  void _flipping(Canvas canvas, LmView view, Rect rect, int id, double flip) {
    final double squash = math.cos(math.pi * flip).abs();
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(1, math.max(0.04, squash));
    canvas.translate(-rect.center.dx, -rect.center.dy);
    if (flip < 0.5) {
      drawToken(canvas, view, rect, id, outline: flip > 0 ? view.inks.truth : null);
    } else {
      _idTile(canvas, view, rect, id);
    }
    canvas.restore();
  }

  void _row(Canvas canvas, LmView view, _Layout layout, int p, double u, double framing) {
    final TrainingTrace trace = view.trace;
    final TracePeptide peptide = trace.peptides[p];
    final List<int> ids = frameOf(trace, p);
    final int residues = peptide.sequence.length;
    final double top = layout.rowTop(p);
    final bool focus = p == view.peptide;
    if (focus) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(layout.left - 6, top - 4, layout.width + 12, layout.block + 9),
          const Radius.circular(6),
        ),
        Paint()..color = view.inks.card,
      );
    }
    view.kit.draw(
      canvas,
      '${peptide.source.label} · $residues aa',
      inked(view.kit.sans, 10, focus ? view.inks.ink : view.inks.quiet),
      Offset(layout.left, top),
    );
    final double done = scanned(trace, p, u);
    for (int k = 0; k < ids.length; k++) {
      final Rect rect = layout.batchAt(p, k);
      if (k == 0 || k > residues) {
        drawToken(canvas, view, rect, ids[k], alpha: framing);
      } else {
        _flipping(canvas, view, rect, ids[k], (done - (k - 1)).clamp(0.0, 1.0));
      }
    }
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final _Layout layout = _Layout(size, view);
    for (int p = 0; p < view.trace.peptides.length; p++) {
      final double top = layout.rowTop(p);
      if (at.dy >= top - 4 && at.dy < top + layout.block + 6) {
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
    if (frame.local < _shiftFrom) {
      return '<bos> and <eos> frame each one, <pad> fills to the longest: '
          '$peptides × ${trace.width + 1} ids';
    }
    return 'Each id is trained to predict the one after it: '
        '${trace.targetCount} targets, ${trace.pads} pads ignored';
  }

  @override
  String describe(LmView view, TrainingFrame frame) {
    final TracePeptide focus = view.focus;
    return 'Tokenise. ${caption(view, frame)}. In focus, ${focus.source.label}, '
        '${focus.sequence.length} residues.';
  }
}

/// Top to bottom: the dataset's tag and its peptides, each on two lines
/// where that leaves its tiles room for their numbers, else on one;
/// then the vocabulary's tag, its counts, its tokens and their ids; then the
/// tags under it. The tiles are as large as the width and the height both
/// allow, the room left goes between the peptides, within reason, and the
/// whole is centred.
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
  }

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

  final double histogram = 24;
  final double label = 14;

  double rowTop(int peptide) => batchTop + peptide * rowPitch;

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
}
