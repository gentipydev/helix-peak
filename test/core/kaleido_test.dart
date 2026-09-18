import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/anatomy_colors.dart';
import 'package:helixpeak/core/theme/kaleido.dart';

double _linear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// CIE L\*C\*h under D65, written out here rather than borrowed from the filter,
/// so this file checks the filter against the standard and not against itself.
({double l, double c, double h}) _lch(Color colour) {
  final double r = _linear(colour.r);
  final double g = _linear(colour.g);
  final double b = _linear(colour.b);
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final double fx = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
  final double fy = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
  final double fz = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
  final double a = 500 * (fx - fy);
  final double bb = 200 * (fy - fz);
  return (
    l: 116 * fy - 16,
    c: math.sqrt(a * a + bb * bb),
    h: (math.atan2(bb, a) * 180 / math.pi + 360) % 360,
  );
}

void main() {
  group('Kaleido.filter', () {
    // Everything the flow puts through it, and four saturated strangers so the
    // filter is not only ever checked on the colours it was tuned against.
    const AnatomyColors searched = AnatomyColors.dark;
    final List<Color> samples = <Color>[
      searched.aminoAliphatic,
      searched.aminoAromatic,
      searched.aminoPositive,
      searched.aminoNegative,
      searched.aminoPolar,
      searched.aminoSpecial,
      searched.aminoCysteine,
      searched.aminoUnknown,
      searched.dibasic,
      const Color(0xFF3366CC),
      const Color(0xFFCC3333),
      const Color(0xFF22AA66),
      const Color(0xFFFFCC00),
    ];

    test('keeps lightness, which is what carries a residue letter', () {
      for (final Color colour in samples) {
        expect(
          _lch(Kaleido.filter(colour)).l,
          closeTo(_lch(colour).l, 0.5),
          reason: '$colour',
        );
      }
    });

    test('keeps hue', () {
      for (final Color colour in samples) {
        final double before = _lch(colour).h;
        final double after = _lch(Kaleido.filter(colour)).h;
        final double gap = (before - after).abs();
        expect(math.min(gap, 360 - gap), lessThan(2), reason: '$colour');
      }
    });

    test('lets through only its share of the chroma', () {
      for (final Color colour in samples) {
        expect(
          _lch(Kaleido.filter(colour)).c,
          closeTo(_lch(colour).c * Kaleido.through, 0.75),
          reason: '$colour',
        );
      }
    });

    test('leaves a grey grey', () {
      const Color grey = Color(0xFF808080);
      expect(Kaleido.filter(grey).toARGB32(), grey.toARGB32());
    });
  });
}
