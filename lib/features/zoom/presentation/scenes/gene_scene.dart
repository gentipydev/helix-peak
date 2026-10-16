import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/chromatin_layout.dart';
import '../../domain/dna_dive.dart';
import '../../domain/gene_layout.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'band_scene.dart';
import 'body_scene.dart';
import 'chromatin_beads.dart';
import 'chromatin_fibre.dart';
import 'gene_strand.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene as a stretch of chromatin, still: its DNA a line beaded with its
/// nucleosomes, each its DNA wound round a histone core, larger than life
/// ([ChromatinFibre]; the user's choice of 2026-10-16, to see them), going
/// on either side of it, and its exons, as a genome browser draws a transcript, lit blocks in the walk's
/// own colours, coding parts tall and untranslated ends short, every part
/// at its real length along the span MANE gives it; a ruler from its 5′ end
/// and the bent arrow where transcription starts (the user's choice of
/// 2026-10-16: a snapshot of the gene, nothing reading it, after a still of
/// it being read that read as an animation laid out in space).
///
/// It reads 5′ to 3′, left to right, as the walk does, from the moment it
/// appears: on the band's strip the gene is a mark with nothing inside it to
/// turn, and turned over about its middle a mark is the same mark, so a gene
/// on the reverse strand is drawn facing the walk's way without a turn that
/// would swing its ends across the view.
///
/// It opens out of that mark as the band's map gives way, and its ruler,
/// its exons' numbers, its start and its 3′ end come up as it is reached. On
/// the way to the DNA those go first, and the exons give way as the view
/// closes in on its 5′ end, gone before the double helix comes up there.
final class GeneScene extends ZoomScene {
  GeneScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.gene;

  double get _width => subject.depth.widthOf(stop);

  bool get _reverse => subject.track.strand < 0;

  /// Which way the gene lies on screen: 1 the genome's way, -1 turned over,
  /// as a gene on the reverse strand is to read 5′ to 3′.
  double get _facing => _reverse ? -1 : 1;

  /// A genome position in the scene's units, from the gene's middle, the
  /// genome's way round.
  double unitOf(double position) => (position - subject.geneMiddle) / _width;

  /// The point [offset] base pairs into the gene from its 5′ end, the
  /// genome's way round.
  double unitAlong(double offset) => unitOf(subject.genomeAt(offset));

  // The DNA's view lies [ZoomSubject.dnaView] base pairs of the genome
  // along from the gene's 5′ end: the DNA counts the genome's base pairs,
  // where this scene lays the record's along MANE's span, a little shorter
  // for a few genes, so the two meet exactly at the 5′ end.
  @override
  Offset get portal => Offset(
    _facing *
        unitOf(subject.genomeAt(0) + (_reverse ? -1 : 1) * subject.dnaView),
    0,
  );

  // The gene comes up out of the band's mark of it a little before the map
  // starts to give way.
  @override
  double asChild(double progress) => smoothstep((progress - 0.25) / 0.45);

  // On the way to the DNA the DNA's scene draws the gene's DNA from the
  // first ([DnaScene]); this one draws only what names it, gone before the
  // nucleosomes wind in their DNA, and goes after it.
  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.5) / 0.45);

  /// How much the ruler, the exons' numbers, the start and the 3′ end show
  /// at [frame]: they come up over the end of the step that reaches the
  /// gene, once the band's map has given way, and go first on the way to
  /// the DNA, gone before the nucleosomes start to wind in their DNA
  /// ([DnaDive.windsFrom]).
  @visibleForTesting
  double annotationsShown(ZoomFrame frame) => frame.isChild
      ? smoothstep((frame.progress - 0.55) / 0.45)
      : 1 - _leaving(frame);

  /// How far the step has gone, at [frame] on the way to the DNA, from the
  /// gene's stop to where its nucleosomes start to wind in their DNA, in
  /// the step's own depth:
  /// a long gene's empty decades go by fast, and a fade keyed to them would
  /// go as fast.
  double _leaving(ZoomFrame frame) {
    final DnaDive dive = subject.depth.dive;
    // Over a sixth of the step at the least, so a gene whose DNA packs soon
    // after its stop does not drop them in a few frames; they are faint by
    // then.
    return smoothstep(
      frame.progress / math.max(dive.spentAt(DnaDive.windsFrom(_width)), 0.15),
    );
  }

  /// The screen x of [offset] base pairs into the gene, facing as it does.
  double _x(ZoomFrame frame, double offset) {
    final double centre = frame.toScreen(Offset.zero).dx;
    final double x = frame.toScreen(Offset(unitAlong(offset), 0)).dx;
    return centre + (x - centre) * _facing;
  }

  /// Where the point [offset] base pairs into the gene from its 5′ end lies
  /// across the screen at [frame].
  @visibleForTesting
  double screenX(ZoomFrame frame, double offset) => _x(frame, offset);

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double mid = frame.size.height / 2;
    final Offset start = Offset(_x(frame, 0), mid - 12);
    out.item('gene:start', start, frame.opacity);
    out.callout('gene', '5′', start, calloutPresence(frame));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double mid = frame.size.height / 2;
    final double annotations = annotationsShown(frame);
    // On the step that reaches the gene this scene draws its DNA; from the
    // gene's stop on the DNA's scene does, drawing the same. Its beads and
    // the DNA either side of it come up with its annotations.
    if (frame.isChild) {
      _strand(canvas, frame, mid, annotations);
    }
    if (annotations > 0) {
      _numbers(canvas, frame, mid, annotations);
      _ends(canvas, frame, mid, annotations);
      _ruler(canvas, frame, mid + rulerY, annotations);
      _start(canvas, frame, mid, annotations);
    }
  }

  /// The gene's DNA, as the DNA's scene draws it from the gene's stop on
  /// ([ChromatinFibre]): its line, the DNA either side of it and its
  /// nucleosomes [around] of the way up, and its exons over them.
  void _strand(Canvas canvas, ZoomFrame frame, double mid, double around) {
    final ZoomInks inks = frame.inks;
    final double w = frame.size.width;
    // The genome's base pairs, as the DNA counts them, to the record's.
    final double scale = subject.track.geneLengthBp / subject.layout.length;
    double x(double offset) => _x(frame, offset / scale);
    final double end = subject.track.geneLengthBp.toDouble();
    // The nucleosomes its stop shows, coming up with it: which they are
    // does not change as the gene opens out, and they grow with it, never
    // larger than the room between them.
    final int depth = ChromatinBeads.depthAt(_width, w);
    final double perBase = (x(1000) - x(0)).abs() / 1000;
    final double room = (1 << depth) * ChromatinLayout.period * perBase;
    ChromatinFibre.paint(
      canvas,
      inks,
      x: x,
      perBase: perBase,
      grown: math.min(1, room / ChromatinBeads.apart),
      mid: mid,
      width: w,
      packed: 0,
      thick: GeneStrand.line,
      twist: 0,
      marks: subject.fibreMarks,
      colourAt: (double offset) {
        final Color ink = GeneStrand.ink(
          inks,
          subject.layout.kindAt(offset / scale),
          0,
        );
        return offset < 0 || offset > end
            ? ink.withValues(alpha: ink.a * around)
            : ink;
      },
      depth: depth,
      shownOf: (int index) =>
          ChromatinBeads.depthOf(index) >= depth ? around : 0,
    );
    GeneStrand.paint(
      canvas,
      inks,
      subject.layout,
      x: (double offset) => _x(frame, offset),
      mid: mid,
      width: w,
    );
  }

  /// The least width, in pixels, a coding exon has at the gene's stop to be
  /// numbered there.
  static const double numbered = 16;

  /// The coding exons' numbers over their blocks, [alpha] of the way up.
  void _numbers(Canvas canvas, ZoomFrame frame, double mid, double alpha) {
    final double w = frame.size.width;
    // How many times as big as at its stop the gene is drawn: an exon's
    // number comes up as its block grows from half its size there.
    final double scale = frame.view.pixelsPerUnit / w;
    final double grown = smoothstep(math.log(2 * scale) / math.ln2);
    if (alpha * grown <= 0) {
      return;
    }
    int exon = 0;
    GenePieceKind? last;
    for (final GenePiece piece in subject.layout.pieces) {
      if (piece.kind != GenePieceKind.intron &&
          (last == null || last == GenePieceKind.intron)) {
        exon++;
      }
      last = piece.kind;
      if (piece.kind != GenePieceKind.cds) {
        continue;
      }
      final double a = _x(frame, piece.start);
      final double b = _x(frame, piece.end);
      final double left = math.min(a, b);
      final double right = math.max(a, b);
      if (right < -8 || left > w + 8 || (right - left) / scale < numbered) {
        continue;
      }
      _number(
        canvas,
        frame,
        '$exon',
        Offset((left + right) / 2, mid - 22),
        alpha * grown,
      );
    }
  }

  /// Where the gene's ruler runs, in pixels from the middle of the view.
  static const double rulerY = -84;

  /// Where transcription starts: the bent arrow standing on the gene's 5′
  /// end and pointing the way it is read.
  void _start(Canvas canvas, ZoomFrame frame, double mid, double alpha) {
    final double x = _x(frame, 0);
    if (x < -20 || x > frame.size.width + 20) {
      return;
    }
    final Paint arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = frame.inks.glow(alpha * frame.opacity);
    const double rise = 30;
    const double reach = 16;
    canvas.drawPath(
      Path()
        ..moveTo(x, mid - 10)
        ..lineTo(x, mid - rise)
        ..lineTo(x + reach, mid - rise)
        ..moveTo(x + reach - 5, mid - rise - 4)
        ..lineTo(x + reach, mid - rise)
        ..lineTo(x + reach - 5, mid - rise + 4),
      arrow,
    );
  }

  void _number(
    Canvas canvas,
    ZoomFrame frame,
    String text,
    Offset at, [
    double alpha = 1,
  ]) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: frame.labels.copyWith(
          color: frame.inks.label.withValues(alpha: frame.opacity * alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  /// 3′ at the gene's far end, over the DNA going on past it; its 5′ end
  /// has the scene's callout.
  void _ends(Canvas canvas, ZoomFrame frame, double mid, double alpha) {
    final double end = _x(frame, subject.layout.length);
    if (end > -8 && end < frame.size.width - 24) {
      _number(canvas, frame, '3′', Offset(end + 10, mid - 16), alpha);
    }
  }

  /// A ruler from the 5′ end, in base pairs along the gene.
  void _ruler(Canvas canvas, ZoomFrame frame, double y, double alpha) {
    final double w = frame.size.width;
    final double atLeft = _along(frame, 0);
    final double atRight = _along(frame, w);
    final double from = math.min(atLeft, atRight);
    final double to = math.max(atLeft, atRight);
    final double step = roundStep((to - from) / 4);
    final Paint rule = Paint()
      ..strokeWidth = 1
      ..color = frame.inks.outline.withValues(alpha: frame.opacity * alpha);
    canvas.drawLine(Offset(0, y), Offset(w, y), rule);
    rule.color = frame.inks.label.withValues(alpha: frame.opacity * alpha);
    for (
      double at = math.max(0, (from / step).ceil() * step);
      at <= math.min(to, subject.layout.length);
      at += step
    ) {
      final double x = _x(frame, at);
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), rule);
      if (at > 0) {
        _number(
          canvas,
          frame,
          '+${basePairLabel(at)}',
          Offset(x, y - 14),
          alpha,
        );
      }
    }
  }

  /// Base pairs along the gene from its 5′ end at screen x [x].
  double _along(ZoomFrame frame, double x) {
    final double centre = frame.toScreen(Offset.zero).dx;
    final double genomeX = centre + (x - centre) / _facing;
    final double unit = frame.view
        .fromScreen(Offset(genomeX, 0), frame.size)
        .dx;
    final double position = subject.geneMiddle + unit * _width;
    final double fraction = _reverse
        ? (subject.track.spanEnd - position) / subject.track.geneLengthBp
        : (position - subject.track.spanStart) / subject.track.geneLengthBp;
    return fraction * subject.layout.length;
  }
}
