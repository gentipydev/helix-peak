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
/// their untranslated ends thin, its introns a line with chevrons running the
/// way it is read, every part at its real length, along the span MANE gives
/// it, with a ruler from its 5′ end.
///
/// It reads 5′ to 3′, left to right, as the walk does, from the moment it
/// appears: on the band's map the gene is a bar with nothing inside it to
/// turn, so a gene on the reverse strand is drawn facing the walk's way
/// without a turn that would swing its ends across the view.
final class GeneScene extends ZoomScene {
  const GeneScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.gene;

  double get _width => subject.depth.widthOf(stop);

  bool get _reverse => subject.track.strand < 0;

  /// A genome position in the scene's units, from the gene's middle, the
  /// genome's way round.
  double unitOf(double position) => (position - subject.geneMiddle) / _width;

  /// The point [offset] base pairs into the gene from its 5′ end, the
  /// genome's way round.
  double unitAlong(double offset) => unitOf(subject.genomeAt(offset));

  @override
  Offset get portal =>
      Offset((_reverse ? -1 : 1) * unitAlong(subject.dnaMiddle), 0);

  @override
  double asChild(double progress) => smoothstep((progress - 0.02) / 0.45);

  @override
  double asParent(double progress) =>
      1 - smoothstep((progress - 0.35) / 0.5);

  /// Which way the gene lies on screen: 1 the genome's way, -1 turned over,
  /// as a gene on the reverse strand is to read 5′ to 3′.
  double _facing(ZoomFrame frame) => _reverse ? -1 : 1;

  /// The screen x of [offset] base pairs into the gene, facing as it does at
  /// [frame].
  double _x(ZoomFrame frame, double offset) {
    final double centre = frame.toScreen(Offset.zero).dx;
    final double x = frame.toScreen(Offset(unitAlong(offset), 0)).dx;
    return centre + (x - centre) * _facing(frame);
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double mid = frame.size.height / 2;
    final Offset start = Offset(_x(frame, 0), mid - 12);
    out.item('gene:start', start, frame.opacity);
    out.callout('gene', '5′', start, calloutPresence(frame));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double w = frame.size.width;
    final double mid = frame.size.height / 2;
    double clampX(double x) => x.clamp(-8.0, w + 8);
    final double facing = _facing(frame);
    // An intron as a browser draws one: a thin line, light enough to read
    // on the dark ground, which the walk's intron tile colour is not.
    final Color line = frame.inks.label.withValues(alpha: 0.75);
    final Paint intron = Paint()
      ..strokeWidth = 1.6
      ..color = line;
    final Paint utr = Paint()..color = frame.inks.utr;
    final Paint cds = Paint()..color = frame.inks.cds;
    // Which way the chevrons point on screen: the way the gene is read.
    final double direction = (_reverse ? -1 : 1) * facing.sign;
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
          final double from = math.max(left, -8) + 18;
          for (double x = from; x < math.min(right, w + 8) - 12; x += 36) {
            final Path chevron = Path()
              ..moveTo(x - 3 * direction, mid - 4)
              ..lineTo(x + 3 * direction, mid)
              ..lineTo(x - 3 * direction, mid + 4);
            canvas.drawPath(
              chevron,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = line,
            );
          }
        case GenePieceKind.utr || GenePieceKind.cds:
          final double half = piece.kind == GenePieceKind.cds ? 9 : 5;
          final double centre = (left + right) / 2;
          final double span = math.max((right - left) / 2, 0.5);
          canvas.drawRect(
            Rect.fromLTRB(
              clampX(centre - span),
              mid - half,
              clampX(centre + span),
              mid + half,
            ),
            piece.kind == GenePieceKind.cds ? cds : utr,
          );
          if (piece.kind == GenePieceKind.cds && right - left >= 16) {
            _number(canvas, frame, '$exon', Offset(centre, mid - 22));
          }
      }
    }
    // The ruler and the 3′ end come up once the gene faces the reader.
    final double reveal = frame.isChild
        ? smoothstep((frame.progress - 0.55) / 0.3)
        : 1;
    if (reveal > 0) {
      _ends(canvas, frame, mid, reveal);
      _ruler(canvas, frame, mid + BandScene.rulerY, reveal);
    }
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
    for (double at = math.max(0, (from / step).ceil() * step);
        at <= math.min(to, subject.layout.length);
        at += step) {
      final double x = _x(frame, at);
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), rule);
      if (at > 0) {
        _number(canvas, frame, '+${basePairLabel(at)}', Offset(x, y - 14), alpha);
      }
    }
  }

  /// Base pairs along the gene from its 5′ end at screen x [x].
  double _along(ZoomFrame frame, double x) {
    final double facing = _facing(frame);
    final double centre = frame.toScreen(Offset.zero).dx;
    final double genomeX = centre + (x - centre) / (facing == 0 ? 1e-9 : facing);
    final double unit = frame.view.fromScreen(Offset(genomeX, 0), frame.size).dx;
    final double position = subject.geneMiddle + unit * _width;
    final double fraction = _reverse
        ? (subject.track.spanEnd - position) / subject.track.geneLengthBp
        : (position - subject.track.spanStart) / subject.track.geneLengthBp;
    return fraction * subject.layout.length;
  }
}
