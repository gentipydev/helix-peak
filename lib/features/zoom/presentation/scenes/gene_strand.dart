import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/gene_layout.dart';
import '../zoom_inks.dart';

/// The gene's exons as its stop draws them, over its DNA ([ChromatinFibre]):
/// lit blocks in the walk's own colours, coding parts tall and untranslated
/// ones short; and the inks the DNA is drawn in.
///
/// The gene's scene draws them on the step that reaches the gene, and the
/// DNA's from the gene's stop on, so the hand-over at the stop changes no
/// pixel. On the way to the DNA the exons sink into the line ([sink]): each
/// block eases down to the line's width, and the line along it takes its
/// colour, so the exons are stretches of the DNA itself by the time the
/// fibre packs.
abstract final class GeneStrand {
  /// The line's width at the gene's stop, in pixels, and how much of the
  /// quiet ink it is drawn in, over the ground.
  static const double line = 1.6;
  static const double lineInk = 0.75;

  /// How far a coding exon's block and an untranslated one's reach above
  /// and below the line, in pixels.
  static const double coding = 9;
  static const double untranslated = 5;

  /// The colour the DNA is drawn in where it is [kind], [tint] of the way
  /// to its exon's own colour: the quiet ink, as the helix's backbones are,
  /// laid on the ground so that it is opaque, and where two of its strokes
  /// meet or cross nothing doubles.
  static Color ink(ZoomInks inks, GenePieceKind kind, double tint) {
    final Color dna = Color.lerp(inks.ground, inks.label, lineInk)!;
    return switch (kind) {
      GenePieceKind.intron => dna,
      GenePieceKind.cds => Color.lerp(dna, inks.cds, tint)!,
      GenePieceKind.utr => Color.lerp(dna, inks.utr, tint)!,
    };
  }

  /// Strokes [path] as a stretch of DNA [width] pixels thick in [colour]:
  /// a line, and once it is thick enough to have one, a lit tube, its upper
  /// edge catching the light.
  static void tube(
    Canvas canvas,
    Path path,
    Color colour,
    double width,
    ZoomInks inks,
  ) {
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..color = colour;
    canvas.drawPath(path, stroke);
    final double lit = ((width - 2.5) / 3).clamp(0.0, 1.0);
    if (lit > 0) {
      canvas.drawPath(
        path.shift(Offset(0, -0.2 * width)),
        stroke
          ..strokeWidth = 0.35 * width
          ..color = Color.lerp(
            colour,
            inks.text,
            0.45,
          )!.withValues(alpha: colour.a * 0.55 * lit),
      );
    }
  }

  /// Draws the exons of [layout] on the line at [mid], the point [offset]
  /// base pairs from the 5′ end at screen x [x], on a canvas [width] wide:
  /// [sink] of the way sunk into a line [thick] pixels wide, at [alpha].
  static void paint(
    Canvas canvas,
    ZoomInks inks,
    GeneLayout layout, {
    required double Function(double offset) x,
    required double mid,
    required double width,
    double sink = 0,
    double thick = GeneStrand.line,
    double alpha = 1,
  }) {
    final double kept = 1 - sink;
    if (alpha <= 0 || kept <= 0) {
      return;
    }
    double clampX(double at) => at.clamp(-8.0, width + 8);
    Color faded(Color colour) => colour.withValues(alpha: colour.a * alpha);
    // Exon by exon, 5′ to 3′, as a browser draws a transcript: a block lit
    // from above, brighter along its top and in shade below, sinking to the
    // line's width.
    for (final GenePiece piece in layout.pieces) {
      if (piece.kind == GenePieceKind.intron) {
        continue;
      }
      final double a = x(piece.start);
      final double b = x(piece.end);
      final double left = math.min(a, b);
      final double right = math.max(a, b);
      if (right < -8 || left > width + 8) {
        continue;
      }
      final bool isCoding = piece.kind == GenePieceKind.cds;
      final double half =
          (isCoding ? coding : untranslated) * kept + thick / 2 * sink;
      final double centre = (left + right) / 2;
      final double reach = math.max((right - left) / 2, 0.5);
      final Rect block = Rect.fromLTRB(
        clampX(centre - reach),
        mid - half,
        clampX(centre + reach),
        mid + half,
      );
      final Color colour = isCoding ? inks.cds : inks.utr;
      final Color tone = Color.lerp(ink(inks, piece.kind, 1), colour, kept)!;
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
              faded(Color.lerp(tone, inks.text, 0.3 * kept)!),
              faded(tone),
              faded(Color.lerp(tone, inks.ground, 0.35 * kept)!),
            ],
            stops: const <double>[0, 0.45, 1],
          ).createShader(block),
      );
    }
  }
}
