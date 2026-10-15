import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/gene_layout.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'band_scene.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene as a genome browser draws a transcript: its coding exons thick,
/// their untranslated ends thin, each a lit block in the walk's own colours,
/// its introns a line with chevrons running the way it is read, every part
/// at its real length, along the span MANE gives it, with a ruler from its
/// 5′ end and the bent arrow where transcription starts. Nothing moves on
/// it: nothing reads it, as nothing reads the helix at the DNA (the user's
/// choice of 2026-10-15, when the gene had its stop again).
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
  const GeneScene(this.subject);

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

  @override
  Offset get portal => Offset(_facing * unitAlong(subject.dnaView), 0);

  // The gene comes up out of the band's mark of it a little before the map
  // starts to give way.
  @override
  double asChild(double progress) => smoothstep((progress - 0.25) / 0.45);

  // On the way to the DNA its exons give way by how wide the view is
  // ([exonsShown]); the scene goes after them.
  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.5) / 0.45);

  /// How wide the view is, in base pairs, when the gene's exons are gone on
  /// the way to the DNA: the helix comes up below it.
  static const double exonsGone = 400;

  /// How much of the gene's exons and introns show where the view is [span]
  /// base pairs wide, on the way from the gene to the DNA of [depth]: all of
  /// them at the gene, and none once the view is [exonsGone] wide, so they
  /// are gone before the DNA's helix comes up. They give way evenly in the
  /// view's log over a tenfold narrowing, as they did on the dive from the
  /// band, or over 0.45 of the step where that is more: a deep step crosses
  /// a decade too fast for a fade at 60 fps. A gene too short for that gives
  /// way from its own stop, and over the octave below it at the least.
  static double exonsShownAt(double span, ZoomDepth depth) {
    final double gene = depth.widthOf(ZoomStop.gene);
    final double decades =
        math.log(gene / depth.widthOf(ZoomStop.dna)) / math.ln10;
    final double whole = math.min(
      gene,
      exonsGone * math.pow(10, math.max(1, 0.45 * decades)),
    );
    final double gone = math.min(exonsGone, whole / 2);
    return smoothstep(math.log(span / gone) / math.log(whole / gone));
  }

  /// How much of the gene's exons and introns show at [frame].
  @visibleForTesting
  double exonsShown(ZoomFrame frame) =>
      exonsShownAt(_span(frame), subject.depth);

  /// How much the ruler, the exons' numbers, the start and the 3′ end show
  /// at [frame]: they come up over the end of the step that reaches the
  /// gene, once the band's map has given way, and go first on the way to
  /// the DNA.
  @visibleForTesting
  double annotationsShown(ZoomFrame frame) => frame.isChild
      ? smoothstep((frame.progress - 0.55) / 0.45)
      : 1 - smoothstep(frame.progress / 0.45);

  /// How many base pairs the view spans at [frame].
  double _span(ZoomFrame frame) =>
      frame.size.width / frame.view.pixelsPerUnit * _width;

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
    final double exons = exonsShown(frame);
    final double annotations = annotationsShown(frame);
    if (exons > 0) {
      _parts(canvas, frame, mid, exons, annotations);
    }
    if (annotations > 0) {
      _ends(canvas, frame, mid, annotations);
      _ruler(canvas, frame, mid + rulerY, annotations);
      _start(canvas, frame, mid, annotations);
    }
  }

  /// The least width, in pixels, a coding exon has at the gene's stop to be
  /// numbered there.
  static const double numbered = 16;

  /// The gene's parts along its line, [alpha] of them showing, and the
  /// coding exons' numbers [numbers] of the way up.
  void _parts(
    Canvas canvas,
    ZoomFrame frame,
    double mid,
    double alpha,
    double numbers,
  ) {
    final double w = frame.size.width;
    double clampX(double x) => x.clamp(-8.0, w + 8);
    // An intron as a browser draws one: a thin line, light enough to read
    // on the dark ground, which the walk's intron tile colour is not.
    final Color line = frame.inks.label.withValues(alpha: 0.75 * alpha);
    final Paint intron = Paint()
      ..strokeWidth = 1.6
      ..color = line;
    final Paint chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = line;
    Color faded(Color colour) => colour.withValues(alpha: colour.a * alpha);
    // How many times as big as at its stop the gene is drawn: an exon's
    // number comes up as its block grows from half its size there.
    final double scale = frame.view.pixelsPerUnit / w;
    final double grown = smoothstep(math.log(2 * scale) / math.ln2);
    int exon = 0;
    GenePieceKind? last;
    for (final GenePiece piece in subject.layout.pieces) {
      if (piece.kind != GenePieceKind.intron &&
          (last == null || last == GenePieceKind.intron)) {
        exon++;
      }
      last = piece.kind;
      final double a = _x(frame, piece.start);
      final double b = _x(frame, piece.end);
      final double left = math.min(a, b);
      final double right = math.max(a, b);
      if (right < -8 || left > w + 8) {
        continue;
      }
      switch (piece.kind) {
        case GenePieceKind.intron:
          canvas.drawLine(
            Offset(clampX(left), mid),
            Offset(clampX(right), mid),
            intron,
          );
          // Chevrons the way it is read, 5′ to 3′.
          final double from = math.max(left, -8) + 18;
          for (double x = from; x < math.min(right, w + 8) - 12; x += 36) {
            canvas.drawPath(
              Path()
                ..moveTo(x - 3, mid - 4)
                ..lineTo(x + 3, mid)
                ..lineTo(x - 3, mid + 4),
              chevron,
            );
          }
        case GenePieceKind.utr || GenePieceKind.cds:
          final bool coding = piece.kind == GenePieceKind.cds;
          final double half = coding ? 9 : 5;
          final double centre = (left + right) / 2;
          final double reach = math.max((right - left) / 2, 0.5);
          final Rect block = Rect.fromLTRB(
            clampX(centre - reach),
            mid - half,
            clampX(centre + reach),
            mid + half,
          );
          // A block lit from above: brighter along its top, in shade below.
          final Color colour = coding ? frame.inks.cds : frame.inks.utr;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              block,
              Radius.circular(math.min(3, block.width / 2)),
            ),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  faded(Color.lerp(colour, frame.inks.text, 0.3)!),
                  faded(colour),
                  faded(Color.lerp(colour, frame.inks.ground, 0.35)!),
                ],
                stops: const <double>[0, 0.45, 1],
              ).createShader(block),
          );
          if (coding &&
              numbers * grown > 0 &&
              (right - left) / scale >= numbered) {
            _number(
              canvas,
              frame,
              '$exon',
              Offset(centre, mid - 22),
              numbers * grown,
            );
          }
      }
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

  /// 3′ at the gene's far end; its 5′ end has the scene's callout.
  void _ends(Canvas canvas, ZoomFrame frame, double mid, double alpha) {
    final double end = _x(frame, subject.layout.length);
    if (end > -8 && end < frame.size.width - 36) {
      _number(canvas, frame, '3′', Offset(end + 14, mid), alpha);
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
