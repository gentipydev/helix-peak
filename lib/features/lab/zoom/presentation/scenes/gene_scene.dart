import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/gene_layout.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene as a genome browser draws a transcript: its coding exons thick,
/// their untranslated ends thin, its introns a line with chevrons running the
/// way it is read, every part at its real length, along the span MANE gives
/// it on the genome.
final class GeneScene extends ZoomScene {
  const GeneScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.gene;

  double get _width => subject.depth.widthOf(stop);

  /// A genome position in the scene's units, from the gene's middle.
  double unitOf(double position) => (position - subject.geneMiddle) / _width;

  /// The point [offset] base pairs into the gene from its 5′ end.
  double unitAlong(double offset) => unitOf(subject.genomeAt(offset));

  @override
  Offset get portal => Offset(unitAlong(subject.dnaMiddle), 0);

  double _x(ZoomFrame frame, double offset) =>
      frame.toScreen(Offset(unitAlong(offset), 0)).dx;

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
    // An intron as a browser draws one: a thin line, light enough to read
    // on the dark ground, which the walk's intron tile colour is not.
    final Color line = frame.inks.label.withValues(alpha: 0.75);
    final Paint intron = Paint()
      ..strokeWidth = 1.6
      ..color = line;
    final Paint utr = Paint()..color = frame.inks.utr;
    final Paint cds = Paint()..color = frame.inks.cds;
    final double direction = subject.track.strand < 0 ? -1 : 1;
    for (final GenePiece piece in subject.layout.pieces) {
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
          // Chevrons every 36 pixels, pointing the way the gene is read.
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
      }
    }
  }
}
