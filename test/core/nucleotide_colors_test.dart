import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';

/// WCAG relative luminance, spelled out rather than taken from
/// `Color.computeLuminance` so this file is checking the standard rather than
/// checking Flutter against itself.
double _luminance(Color colour) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(colour.r) +
      0.7152 * channel(colour.g) +
      0.0722 * channel(colour.b);
}

double _contrast(Color a, Color b) {
  final double x = _luminance(a);
  final double y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// CIE L\*, the lightness the eye sees — the one the muted set is level in.
double _lightness(Color colour) {
  final double y = _luminance(colour);
  return y > 0.008856 ? 116 * math.pow(y, 1 / 3) - 16 : 903.3 * y;
}

void main() {
  group('NucleotideColors.forBase', () {
    const NucleotideColors palette = NucleotideColors.dark;

    test('maps each canonical base to its own colour', () {
      expect(palette.forBase('A'), palette.adenine);
      expect(palette.forBase('T'), palette.thymine);
      expect(palette.forBase('G'), palette.guanine);
      expect(palette.forBase('C'), palette.cytosine);
    });

    test('is case-insensitive', () {
      expect(palette.forBase('a'), palette.adenine);
      expect(palette.forBase('t'), palette.thymine);
      expect(palette.forBase('g'), palette.guanine);
      expect(palette.forBase('c'), palette.cytosine);
    });

    test('maps uracil onto thymine so RNA renders consistently', () {
      expect(palette.forBase('U'), palette.thymine);
      expect(palette.forBase('u'), palette.thymine);
    });

    test('falls back to the neutral colour for ambiguity and gap codes', () {
      expect(palette.forBase('N'), palette.unknown);
      expect(palette.forBase('-'), palette.unknown);
      expect(palette.forBase('?'), palette.unknown);
      expect(palette.forBase(''), palette.unknown);
    });

    test('is the IGV/UCSC convention, which readers already know', () {
      expect(palette.adenine, const Color(0xFF2E8B3D), reason: 'A is green');
      expect(palette.thymine, const Color(0xFFD13B3B), reason: 'T is red');
      expect(palette.guanine, const Color(0xFFA36913), reason: 'G is orange');
      expect(palette.cytosine, const Color(0xFF2F5FA8), reason: 'C is blue');
    });

    test('the four bases are mutually distinct', () {
      final Set<int> values = <int>{
        palette.adenine.toARGB32(),
        palette.thymine.toARGB32(),
        palette.guanine.toARGB32(),
        palette.cytosine.toARGB32(),
      };
      expect(values, hasLength(4));
    });
  });

  // The transcript page letters its bases in these, each on one neutral tile,
  // on the warm ground of the Protein Analyses flow.
  group('NucleotideColors.muted', () {
    const NucleotideColors palette = NucleotideColors.muted;
    const NucleotideColors convention = NucleotideColors.dark;
    final Color ground = AppColorTokens.warm.surfaceBase;
    final Color tile = AnatomyColors.dark.baseTile;

    final Map<String, (Color, Color)> bases = <String, (Color, Color)>{
      'A': (palette.adenine, convention.adenine),
      'T': (palette.thymine, convention.thymine),
      'G': (palette.guanine, convention.guanine),
      'C': (palette.cytosine, convention.cytosine),
    };

    test('is the colours it was set to', () {
      expect(palette.adenine.toARGB32(), 0xFF46A355);
      expect(palette.thymine.toARGB32(), 0xFFC77C7C);
      expect(palette.guanine.toARGB32(), 0xFFB38A4D);
      expect(palette.cytosine.toARGB32(), 0xFF7292C3);
      expect(palette.unknown.toARGB32(), 0xFF969089);
    });

    test('keeps the hue each base already has', () {
      // Muted, not recoloured: a reader who knows the convention's four still
      // knows these without a legend.
      bases.forEach((String base, (Color, Color) pair) {
        final double gap =
            (HSLColor.fromColor(pair.$1).hue - HSLColor.fromColor(pair.$2).hue)
                .abs();
        expect(math.min(gap, 360 - gap), lessThan(1), reason: base);
      });
    });

    test('is held to one saturation', () {
      bases.forEach((String base, (Color, Color) pair) {
        expect(
          HSLColor.fromColor(pair.$1).saturation,
          closeTo(0.40, 0.02),
          reason: base,
        );
      });
    });

    test('is one lightness, as the eye measures it', () {
      // CIE L*, not HSL's lightness: at an HSL 50% apiece A would sit at L* 65
      // and T at 46, which is the ranking this set exists to remove.
      final List<double> lightness = <double>[
        for (final (Color, Color) pair in bases.values) _lightness(pair.$1),
      ];
      expect(
        lightness.reduce(math.max) - lightness.reduce(math.min),
        lessThan(1),
      );
    });

    test('letters every base legibly on its tile', () {
      // The letter is the only thing on the tile that says which base it is,
      // and the page exists to be read, so 12pt type is held to the 4.5:1
      // floor.
      for (final Color base in <Color>[
        palette.adenine,
        palette.thymine,
        palette.guanine,
        palette.cytosine,
        palette.unknown,
      ]) {
        expect(_contrast(base, tile), greaterThanOrEqualTo(4.5), reason: '$base');
      }
    });

    test('an untranslated base steps back and stays readable', () {
      // The painter washes a UTR tile 20% of the way off the ground and its
      // letter 67% — `AnatomyPainter._utrTile` and `_utrInk`. The coding
      // sequence has to lead, but a reader reads the ends too: the Kozak
      // context, an upstream ATG, the polyadenylation signal.
      final Color quietTile = Color.lerp(ground, tile, 0.2)!;
      for (final (Color, Color) pair in bases.values) {
        final double utr = _contrast(
          Color.lerp(ground, pair.$1, 0.67)!,
          quietTile,
        );
        expect(utr, greaterThanOrEqualTo(3), reason: '${pair.$1} is unreadable in a UTR');
        expect(
          utr,
          lessThan(_contrast(pair.$1, tile)),
          reason: '${pair.$1} is as loud in a UTR as in the coding sequence',
        );
      }
    });

    test('the four bases are mutually distinct', () {
      final Set<int> values = <int>{
        for (final (Color, Color) pair in bases.values) pair.$1.toARGB32(),
      };
      expect(values, hasLength(4));
    });
  });
}
