import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/anatomy_colors.dart';
import '../../core/theme/app_typography.dart';
import '../anatomy/anatomy_layout.dart';
import '../anatomy/anatomy_motion.dart';
import 'translation_painter.dart';

/// The chain flying from where translation left it into its cells.
///
/// The arithmetic is the walk's own reflow, [AnatomyScene.positionOf], over
/// two sets of points instead of two layouts: a quadratic from start to end
/// bowed sideways by [AnatomyMotion.bow], each residue's clock set off 5′ to
/// 3′ by [AnatomyMotion.staggered] and eased by [AnatomyMotion.ease]. A residue
/// the translation had no room to draw sets off from the end of the trail.
class TranslationFlightPainter extends CustomPainter {
  TranslationFlightPainter({
    required List<Offset?> starts,
    required this.layout,
    required this.letters,
    required this.progress,
    required this.anatomy,
    required this.ground,
  }) : _from = _startsOf(starts, letters.length),
       _to = _endsOf(layout, letters.length);

  /// How long the flight takes, the chain's first residue to its last.
  static const Duration duration = Duration(milliseconds: 2400);

  final AnatomyLayout layout;
  final String letters;
  final double progress;
  final AnatomyColors anatomy;
  final Color ground;

  final Float32List _from;
  final Float32List _to;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Map<(String, int), ui.Paragraph> _glyphs =
      <(String, int), ui.Paragraph>{};

  static Float32List _startsOf(List<Offset?> starts, int count) {
    final Float32List points = Float32List(2 * count);
    // Walk back from the C terminus, which is always drawn, so a hidden
    // residue takes the position of the drawn one nearest it along the chain:
    // the end of the trail.
    Offset held = Offset.zero;
    for (int r = count - 1; r >= 0; r--) {
      final Offset? start = r < starts.length ? starts[r] : null;
      if (start != null) {
        held = start;
      }
      points[2 * r] = held.dx;
      points[2 * r + 1] = held.dy;
    }
    return points;
  }

  static Float32List _endsOf(AnatomyLayout layout, int count) {
    final Float32List points = Float32List(2 * count);
    for (int i = 0; i < count; i++) {
      final Offset end = layout.centreOf(i);
      points[2 * i] = end.dx;
      points[2 * i + 1] = end.dy;
    }
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final int count = letters.length;
    final double side = layout.side;
    for (int i = 0; i < count; i++) {
      final double u = count > 1 ? i / (count - 1) : 0;
      final double local = flightProgress(progress, u);
      final Offset at = flightPosition(
        Offset(_from[2 * i], _from[2 * i + 1]),
        Offset(_to[2 * i], _to[2 * i + 1]),
        local,
      );
      if (at.dy < -side || at.dy > size.height + side) {
        continue;
      }
      final String residue = letters[i];
      final double radius =
          TranslationPainter.residueRadius +
          (side / 2 - TranslationPainter.residueRadius) * local;
      _fill.color = anatomy.forResidue(residue);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCircle(center: at, radius: radius),
          Radius.circular(radius * (1 - 0.7 * local)),
        ),
        _fill,
      );
      if (radius >= 6) {
        final ui.Paragraph glyph = _glyphs.putIfAbsent(
          (residue, radius.round()),
          () =>
              (ui.ParagraphBuilder(
                      ui.ParagraphStyle(
                        textAlign: TextAlign.center,
                        fontFamily: AppTypography.monoFamily,
                        fontSize: radius * 1.2,
                      ),
                    )
                    ..pushStyle(ui.TextStyle(color: ground))
                    ..addText(residue))
                  .build()
                ..layout(const ui.ParagraphConstraints(width: 64)),
        );
        canvas.drawParagraph(
          glyph,
          Offset(at.dx - 32, at.dy - glyph.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TranslationFlightPainter old) =>
      old.progress != progress ||
      old.layout != layout ||
      old.letters != letters ||
      old.anatomy != anatomy;
}

/// How far residue [u] of the chain (0 at the N terminus, 1 at the C) has
/// flown at [t]: the walk's stagger, 5′ first, and its ease.
double flightProgress(double t, double u) =>
    AnatomyMotion.ease(AnatomyMotion.staggered(t, u));

/// Where a residue [local] of the way from [from] to [to] is: the walk's own
/// reflow path, a quadratic bowed sideways by [AnatomyMotion.bow].
Offset flightPosition(Offset from, Offset to, double local) {
  final Offset delta = to - from;
  final Offset control =
      (from + to) / 2 + Offset(-delta.dy, delta.dx) * AnatomyMotion.bow;
  final double inverse = 1 - local;
  return from * (inverse * inverse) +
      control * (2 * inverse * local) +
      to * (local * local);
}
