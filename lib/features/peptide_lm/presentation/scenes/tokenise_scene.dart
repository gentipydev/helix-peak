import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/format.dart';
import '../../domain/training_timeline.dart';
import '../../domain/training_trace.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

/// Tokenise: a light crosses each peptide and every residue it passes flips
/// into its id, which flies to its place in the vocabulary; `<bos>` and
/// `<eos>` drop in to frame each one, padding fills to the longest, and the
/// targets slide one place along under the inputs.
final class TokeniseScene extends LmScene {
  const TokeniseScene();

  static const double _scanFrom = 0.08;
  static const double _scanTo = 0.62;
  static const double _stagger = 0.035;
  static const double _frameTo = 0.74;
  static const double _shiftFrom = 0.76;
  static const double _shiftTo = 0.94;

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

  @override
  void paint(Canvas canvas, Size size, LmView view, TrainingFrame frame) {
    final _Layout layout = _Layout(size, view.trace);
    final TrainingTrace trace = view.trace;
    final double u = frame.local;
    final double framing = through(u, _scanTo, _frameTo);
    final double shift = through(u, _shiftFrom, _shiftTo);

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
    _vocabulary(canvas, view, layout, counts, most);
    _magnifier(canvas, view, layout, u, framing, shift);
    for (int p = 0; p < trace.peptides.length; p++) {
      _row(canvas, view, layout, p, u, framing);
    }
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
        inked(view.kit.mono, 8, view.inks.quiet),
        Offset(cell.center.dx, cell.bottom + 2),
        anchor: const Offset(0.5, 0),
      );
    }
  }

  void _magnifier(
    Canvas canvas,
    LmView view,
    _Layout layout,
    double u,
    double framing,
    double shift,
  ) {
    final TrainingTrace trace = view.trace;
    final int p = view.peptide;
    final List<int> ids = frameOf(trace, p);
    final int residues = trace.peptides[p].sequence.length;
    final double cell = layout.magnifierCell;
    final int shown = layout.magnified;
    final double done = scanned(trace, p, u);
    // The window follows the light, then goes back to the start of the frame;
    // where the whole frame fits, it stays at the start.
    final double following = (done + 1 - shown / 2)
        .clamp(0.0, math.max(0, ids.length - shown).toDouble());
    final double start = following * (1 - framing);
    final double left = layout.left;
    final double xTop = layout.magnifierTop;
    final double yTop = xTop + cell + 8;
    final Rect window = Rect.fromLTRB(left, xTop - 6, layout.right, yTop + cell + 6);

    final List<Path> flights = <Path>[];
    final List<double> reaches = <double>[];
    canvas.save();
    canvas.clipRect(window);
    for (int k = 0; k < ids.length; k++) {
      final double x = left + (k - start) * cell;
      if (x < left - cell || x > layout.right) {
        continue;
      }
      final Rect rect = Rect.fromLTWH(x, xTop, cell, cell);
      if (k == 0 || k > residues) {
        // The frame's ends and its padding, as ids, dropped in.
        final double drop = (1 - framing) * cell * 0.5;
        _idTile(canvas, view, rect.translate(0, -drop), ids[k], alpha: framing);
        continue;
      }
      final double flip = (done - (k - 1)).clamp(0.0, 1.0);
      _flipping(canvas, view, rect, ids[k], flip);
      if (flip > 0 && flip < 1) {
        // The id on its way to the vocabulary.
        final Rect chip = layout.vocab.at(ids[k]);
        flights.add(Path()
          ..moveTo(rect.center.dx, rect.top)
          ..quadraticBezierTo(
            (rect.center.dx + chip.center.dx) / 2,
            (rect.top + chip.bottom) / 2 - 12,
            chip.center.dx,
            chip.bottom + 12,
          ));
        reaches.add(math.sin(math.pi * flip));
      }
    }
    if (shift > 0) {
      // The targets: the same frame, one place along, under the inputs.
      final double ticks = through(shift, 0.7, 1);
      for (int k = 1; k < ids.length; k++) {
        final double x = left + (k - shift - start) * cell;
        if (x < left - cell || x > layout.right) {
          continue;
        }
        final Rect rect = Rect.fromLTWH(x, yTop, cell, cell);
        final bool pad = k > residues + 1;
        _idTile(canvas, view, rect, ids[k], alpha: shift);
        if (ticks > 0) {
          final double cx = left + (k - 1 - start) * cell + cell / 2;
          canvas.drawLine(
            Offset(cx, xTop + cell + 1),
            Offset(cx, yTop - 1),
            Paint()
              ..strokeWidth = 1
              ..color = (pad ? view.inks.rule : view.inks.signal).withValues(alpha: ticks),
          );
          if (pad) {
            canvas.drawLine(
              rect.bottomLeft + const Offset(4, -4),
              rect.topRight + const Offset(-4, 4),
              Paint()
                ..strokeWidth = 1
                ..color = view.inks.quiet.withValues(alpha: ticks),
            );
          }
        }
      }
    }
    canvas.restore();
    for (int i = 0; i < flights.length; i++) {
      canvas.drawPath(
        flights[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = view.inks.signal.withValues(alpha: 0.7 * reaches[i]),
      );
    }
    if (shift > 0) {
      final TextStyle style = inked(view.kit.sans, 10, view.inks.quiet, alpha: shift);
      view.kit.draw(canvas, 'x', style, Offset(left - 5, xTop + cell / 2), anchor: const Offset(1, 0.5));
      view.kit.draw(canvas, 'y', style, Offset(left - 5, yTop + cell / 2), anchor: const Offset(1, 0.5));
    }
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
    if (tile.height >= 11) {
      view.kit.draw(
        canvas,
        '$id',
        inked(
          view.kit.mono,
          (tile.height * 0.46).clamp(6.0, 14.0),
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
          Rect.fromLTWH(layout.left - 6, top - 4, layout.width + 12, layout.label + layout.batchCell + 9),
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
      final Rect rect = Rect.fromLTWH(
        layout.left + k * layout.batchCell,
        top + layout.label,
        layout.batchCell,
        layout.batchCell,
      );
      if (k == 0 || k > residues) {
        drawToken(canvas, view, rect, ids[k], alpha: framing);
      } else {
        _flipping(canvas, view, rect, ids[k], (done - (k - 1)).clamp(0.0, 1.0));
      }
    }
  }

  @override
  LmHit? hit(Size size, LmView view, Offset at) {
    final _Layout layout = _Layout(size, view.trace);
    for (int p = 0; p < view.trace.peptides.length; p++) {
      final double top = layout.rowTop(p);
      if (at.dy >= top - 4 && at.dy < top + layout.label + layout.batchCell + 6) {
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

final class _Layout {
  _Layout(Size size, TrainingTrace trace)
    : left = 20,
      right = size.width - 16,
      peptides = trace.peptides.length {
    width = right - left;
    final double vocabCell = math.min(22, width / trace.vocab.length);
    magnifierCell = math.min(34, math.max(18, width / 11));
    magnified = (width / magnifierCell).floor();
    batchCell = math.min(16, width / (trace.width + 1));
    // As much room between the rows as the canvas has, within reason, and
    // the whole of it centred.
    const double gaps = 24 + 28;
    final double fixed = histogram + vocabCell + 14 + magnifierCell * 2 + 8 + gaps;
    final double roomy = batchCell + label + 14;
    final double tight = batchCell + label + 5;
    rowPitch = ((size.height - 12 - fixed) / peptides).clamp(tight, roomy);
    final double content = fixed + rowPitch * peptides;
    final double top = math.max(6, (size.height - content) / 2);
    vocab = TokenLayout(
      Rect.fromLTWH(left, top + histogram, width, vocabCell),
      trace.vocab.length,
      most: 22,
    );
    magnifierTop = vocab.top + vocab.cell + 14 + 24;
    batchTop = magnifierTop + magnifierCell * 2 + 8 + 28;
  }

  final double left;
  final double right;
  final int peptides;
  late final double width;
  late final TokenLayout vocab;
  late final double magnifierCell;
  late final int magnified;
  late final double magnifierTop;
  late final double batchTop;
  late final double batchCell;
  late final double rowPitch;

  final double histogram = 16;
  final double label = 14;

  double rowTop(int peptide) => batchTop + peptide * rowPitch;
}
