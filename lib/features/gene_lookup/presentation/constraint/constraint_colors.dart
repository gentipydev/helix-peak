import 'package:flutter/material.dart';

import '../../domain/entities/protein_constraint.dart';

abstract final class ConstraintColors {
  // Slate -> sand -> amber, identical for every position and domain.
  //
  // Lightness rises with constraint (L* 54, 71, 77), so the most constrained
  // residues are the brightest things on the page: the scale was cool, light
  // amber, coral, which put the moderate middle above both ends. Every stop
  // holds a residue letter knocked out in the ground at 4.5:1 or better.
  static const Color tolerant = Color(0xFF6F8594);
  static const Color moderate = Color(0xFFC9A873);
  static const Color constrained = Color(0xFFF2B36B);

  static Color heat(double value) => value <= 0.5
      ? Color.lerp(tolerant, moderate, value * 2)!
      : Color.lerp(moderate, constrained, (value - 0.5) * 2)!;

  static Color badge(ConstraintLevel level) => switch (level) {
    ConstraintLevel.high => constrained,
    ConstraintLevel.middle => moderate,
    ConstraintLevel.low => tolerant,
  };
}
