import 'package:flutter/material.dart';

import '../../domain/entities/gene_clinvar.dart';

/// The only hues on the walk that mean "observed".
///
/// ClinVar owns colour wherever its records are drawn; the two models are
/// drawn in neutral ink, or on the constraint ramp where a whole protein is
/// shaded. So none of these may pass for a step of that ramp — slate, sand,
/// amber — which is what the old pathogenic amber did, one ΔE away from
/// "highly constrained". Pathogenic is a rose, benign a blue (the teal it was
/// sat beside the app's own accent, the colour of every link and of the mask),
/// conflicting a violet, and uncertain a warm neutral because it is the
/// absence of a call.
///
/// Other is not a fifth hue. A risk allele or a record with no classification
/// says nothing on the pathogenic–benign axis, and a hollow ring says that
/// without spending a colour a dichromat would confuse with another.
///
/// `clinvar_colors_test.dart` holds the palette to its measurements: OKLab
/// distances between every pair, for normal vision and each dichromacy, and
/// away from the ramp and the accent. The violet is the darkest of them, so
/// every mark is drawn on a halo of the surface.
abstract final class ClinVarColors {
  static const Color pathogenic = Color(0xFFE64D74);
  static const Color conflicting = Color(0xFF7D56B8);
  static const Color uncertain = Color(0xFFB3ACA1);
  static const Color benign = Color(0xFF5991FC);

  /// The ring's stroke.
  static const Color other = Color(0xFF9BA6BC);

  static Color of(ClinVarGroup group) => switch (group) {
    ClinVarGroup.pathogenic => pathogenic,
    ClinVarGroup.conflicting => conflicting,
    ClinVarGroup.uncertain => uncertain,
    ClinVarGroup.benign => benign,
    ClinVarGroup.other => other,
  };

  static bool hollow(ClinVarGroup group) => group == ClinVarGroup.other;

  /// Draws one group's mark: a disc, or a ring for [ClinVarGroup.other]. The
  /// halo keeps a mark legible over a coloured cell or a crowded strip.
  static void paintMark(
    Canvas canvas,
    Offset centre,
    double radius,
    ClinVarGroup group, {
    Color? halo,
    double opacity = 1,
  }) {
    if (halo != null) {
      canvas.drawCircle(
        centre,
        radius + 1.2,
        Paint()..color = halo.withValues(alpha: halo.a * opacity),
      );
    }
    final Color colour = of(group).withValues(alpha: opacity);
    if (hollow(group)) {
      canvas.drawCircle(
        centre,
        radius - 0.75,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else {
      canvas.drawCircle(centre, radius, Paint()..color = colour);
    }
  }
}

/// What the protein page marks a residue with in ESM mode: its most severe
/// group, and how many records stand behind the one dot.
@immutable
final class ClinVarMark {
  const ClinVarMark(this.group, this.count);
  final ClinVarGroup group;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ClinVarMark && other.group == group && other.count == count;

  @override
  int get hashCode => Object.hash(group, count);
}

/// A group's mark as a widget, for rows, chips and tags.
class ClinVarDot extends StatelessWidget {
  const ClinVarDot({required this.group, this.size = 10, super.key});

  final ClinVarGroup group;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _DotPainter(group)),
  );
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.group);

  final ClinVarGroup group;

  @override
  void paint(Canvas canvas, Size size) => ClinVarColors.paintMark(
    canvas,
    size.center(Offset.zero),
    size.shortestSide / 2,
    group,
  );

  @override
  bool shouldRepaint(_DotPainter old) => old.group != group;
}
