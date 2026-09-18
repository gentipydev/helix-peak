import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_colors.dart';

double _contrast(Color a, Color b) {
  final double x = a.computeLuminance();
  final double y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  group('AppColorTokens.warm', () {
    const AppColorTokens warm = AppColorTokens.warm;
    const AppColorTokens cool = AppColorTokens.dark;

    test('is a warm dark neutral', () {
      expect(warm.surfaceBase.toARGB32(), 0xFF1C1A18);
      final HSLColor ground = HSLColor.fromColor(warm.surfaceBase);
      expect(ground.hue, inInclusiveRange(20, 40), reason: 'warm');
      expect(ground.saturation, lessThan(0.15), reason: 'neutral');
      expect(ground.lightness, lessThan(0.15), reason: 'dark');
    });

    test('climbs one surface at a time', () {
      final List<Color> ramp = <Color>[
        warm.surfaceBase,
        warm.surfaceRaised,
        warm.surfaceOverlay,
        warm.surfaceHigh,
        warm.outline,
      ];
      for (int i = 1; i < ramp.length; i++) {
        expect(
          ramp[i].computeLuminance(),
          greaterThan(ramp[i - 1].computeLuminance()),
          reason: '${ramp[i]} is not above ${ramp[i - 1]}',
        );
      }
    });

    test('keeps the pills visible on its own ground', () {
      // The count badge and the paginator are drawn in the overlay. The cool
      // one left on this ground sits at 1.09:1 and all but vanishes, so the
      // ramp moved with the ground, and holds the step it had on the old one.
      expect(
        _contrast(cool.surfaceOverlay, warm.surfaceBase),
        lessThan(1.1),
        reason: 'the reason the ramp had to move at all',
      );
      final double step = _contrast(warm.surfaceOverlay, warm.surfaceBase);
      expect(step, greaterThanOrEqualTo(1.15));
      expect(
        step,
        closeTo(_contrast(cool.surfaceOverlay, cool.surfaceBase), 0.02),
      );
    });
  });
}
