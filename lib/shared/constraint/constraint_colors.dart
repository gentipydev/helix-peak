import 'package:flutter/material.dart';

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

  // The sheets no longer colour a model's band: its meter is drawn in ink, and
  // hue there belongs to ClinVar. This ramp is for filling a protein — the
  // grid in ESM mode and the band under the overview's strip — and nothing
  // else, so a ClinVar mark can never be read as a step of it.
}
