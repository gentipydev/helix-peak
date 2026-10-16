import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/gene_layout.dart';
import '../zoom_inks.dart';

/// The gene's DNA as its stop draws it: a line, light enough to read on the
/// dark ground, beaded with its nucleosomes ([ChromatinBeads]), and its
/// exons as lit blocks in the walk's own colours, coding parts tall and
/// untranslated ones short; the DNA going on either side of it.
///
/// The gene's scene draws it on the step that reaches the gene, and the
/// DNA's from the gene's stop on, so the hand-over at the stop changes no
/// pixel. On the way to the DNA the exons sink into the line ([sink]): each
/// block eases down to the line's width, and the line along it takes its
/// colour, so the exons are stretches of the DNA itself by the time it
/// winds onto its histones.
abstract final class GeneStrand {
  /// The line's width at the gene's stop, in pixels, and how much of the
  /// quiet ink it is drawn in.
  static const double line = 1.6;
  static const double lineInk = 0.75;

  /// How far a coding exon's block and an untranslated one's reach above
  /// and below the line, in pixels.
  static const double coding = 9;
  static const double untranslated = 5;

  /// The colour the DNA is drawn in where it is [kind], [tint] of the way
  /// to its exon's own colour: the quiet ink, as the helix's backbones are.
  static Color ink(ZoomInks inks, GenePieceKind kind, double tint) {
    final Color dna = inks.label.withValues(alpha: lineInk);
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

  /// Draws the DNA either side of the gene on the line at [mid], from the
  /// canvas's edge to the gene's 5′ end at screen x [start] and from its 3′
  /// end at [end] to the canvas's other edge, [thick] pixels wide, at
  /// [alpha]: the gene's own line going on.
  static void flanks(
    Canvas canvas,
    ZoomInks inks, {
    required double start,
    required double end,
    required double mid,
    required double width,
    double thick = GeneStrand.line,
    double alpha = 1,
  }) {
    if (alpha <= 0) {
      return;
    }
    final Color dna = ink(inks, GenePieceKind.intron, 0);
    final Color faded = dna.withValues(alpha: dna.a * alpha);
    if (start > -8) {
      tube(
        canvas,
        Path()
          ..moveTo(-8, mid)
          ..lineTo(start, mid),
        faded,
        thick,
        inks,
      );
    }
    if (end < width + 8) {
      tube(
        canvas,
        Path()
          ..moveTo(end, mid)
          ..lineTo(width + 8, mid),
        faded,
        thick,
        inks,
      );
    }
  }

  /// Draws the gene of [layout] on the line at [mid], its point [offset]
  /// base pairs from the 5′ end at screen x [x], on a canvas [width] wide:
  /// its exons [sink] of the way sunk into a line [thick] pixels wide, all
  /// of it at [alpha]; without its [line] where the DNA is drawn otherwise,
  /// and without its [blocks] where its beads go between the two.
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
    bool line = true,
    bool blocks = true,
  }) {
    if (alpha <= 0) {
      return;
    }
    double clampX(double at) => at.clamp(-8.0, width + 8);
    Color faded(Color colour) => colour.withValues(alpha: colour.a * alpha);
    final double kept = 1 - sink;
    // Piece by piece, 5′ to 3′, as a browser draws a transcript: an
    // intron's line, an exon's block lit from above, brighter along its top
    // and in shade below, sinking to the line's width with the line along
    // it in its colour.
    for (final GenePiece piece in layout.pieces) {
      final double a = x(piece.start);
      final double b = x(piece.end);
      final double left = math.min(a, b);
      final double right = math.max(a, b);
      if (right < -8 || left > width + 8) {
        continue;
      }
      final bool intron = piece.kind == GenePieceKind.intron;
      // Under an exon only once it has begun to sink: at the gene's stop a
      // sink a rounding away from none draws nothing more.
      if (line && (intron || sink > 1e-6)) {
        final Color colour = faded(ink(inks, piece.kind, sink));
        if (thick <= 2.5) {
          canvas.drawLine(
            Offset(clampX(left), mid),
            Offset(clampX(right), mid),
            Paint()
              ..strokeWidth = thick
              ..color = colour,
          );
        } else {
          tube(
            canvas,
            Path()
              ..moveTo(clampX(left), mid)
              ..lineTo(clampX(right), mid),
            colour,
            thick,
            inks,
          );
        }
      }
      if (kept <= 0 || intron || !blocks) {
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
