import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';

/// Linear-light sRGB, the space the dichromacy matrices work in.
List<double> _linear(Color c) => <double>[
  for (final double v in <double>[c.r, c.g, c.b])
    v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble(),
];

/// Machado, Oliveira & Fernandes (2009), severity 1.0. This suite keeps its own
/// matrices rather than `anatomy_colors_test.dart`'s `simulate()`, whose
/// coefficients are known to be wrong.
const Map<String, List<List<double>>> _dichromacy = <String, List<List<double>>>{
  'deuteranopia': <List<double>>[
    <double>[0.367322, 0.860646, -0.227968],
    <double>[0.280085, 0.672501, 0.047413],
    <double>[-0.011820, 0.042940, 0.968881],
  ],
  'protanopia': <List<double>>[
    <double>[0.152286, 1.052583, -0.204868],
    <double>[0.114503, 0.786281, 0.099216],
    <double>[-0.003882, -0.048116, 1.051998],
  ],
  'tritanopia': <List<double>>[
    <double>[1.255528, -0.076749, -0.178779],
    <double>[-0.078411, 0.930809, 0.147602],
    <double>[0.004733, 0.691367, 0.303900],
  ],
};

List<double> _seen(Color c, String? vision) {
  final List<double> rgb = _linear(c);
  if (vision == null) {
    return rgb;
  }
  final List<List<double>> m = _dichromacy[vision]!;
  return <double>[
    for (final List<double> row in m)
      (row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2]).clamp(0.0, 1.0),
  ];
}

/// OKLab (Ottosson 2020), scaled by 100 so a just-noticeable step is about 2.
List<double> _oklab(List<double> rgb) {
  double cbrt(double v) => math.pow(v, 1 / 3).toDouble();
  final double l = cbrt(
    0.4122214708 * rgb[0] + 0.5363325363 * rgb[1] + 0.0514459929 * rgb[2],
  );
  final double m = cbrt(
    0.2119034982 * rgb[0] + 0.6806995451 * rgb[1] + 0.1073969566 * rgb[2],
  );
  final double s = cbrt(
    0.0883024619 * rgb[0] + 0.2817188376 * rgb[1] + 0.6299787005 * rgb[2],
  );
  return <double>[
    100 * (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s),
    100 * (1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s),
    100 * (0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s),
  ];
}

double _distance(Color a, Color b, [String? vision]) {
  final List<double> x = _oklab(_seen(a, vision));
  final List<double> y = _oklab(_seen(b, vision));
  return math.sqrt(
    math.pow(x[0] - y[0], 2) + math.pow(x[1] - y[1], 2) + math.pow(x[2] - y[2], 2),
  );
}

/// CIE L\*a\*b\*, the space the residue rhyme and the chroma cap are read in.
List<double> _lab(Color c) {
  final List<double> v = _linear(c);
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final double fx = f((0.4124 * v[0] + 0.3576 * v[1] + 0.1805 * v[2]) / 0.95047);
  final double fy = f(0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]);
  final double fz = f((0.0193 * v[0] + 0.1192 * v[1] + 0.9505 * v[2]) / 1.08883);
  return <double>[116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

double _lightness(Color c) => _lab(c)[0];

double _chroma(Color c) {
  final List<double> lab = _lab(c);
  return math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
}

double _hueGap(Color a, Color b) {
  double hue(Color c) {
    final List<double> lab = _lab(c);
    return (math.atan2(lab[2], lab[1]) * 180 / math.pi) % 360;
  }

  final double d = (hue(a) - hue(b)).abs();
  return d > 180 ? 360 - d : d;
}

double _contrast(Color a, Color b) {
  double luminance(Color c) {
    final List<double> v = _linear(c);
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
  }

  final double x = luminance(a);
  final double y = luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// The closest two of [bases] for [vision], and which two they are.
({double distance, String pair}) _closest(
  Map<String, Color> bases, [
  String? vision,
]) {
  final List<String> names = bases.keys.toList();
  ({double distance, String pair}) closest = (
    distance: double.infinity,
    pair: '',
  );
  for (int i = 0; i < names.length; i++) {
    for (int j = i + 1; j < names.length; j++) {
      final double d = _distance(bases[names[i]]!, bases[names[j]]!, vision);
      if (d < closest.distance) {
        closest = (distance: d, pair: '${names[i]}/${names[j]}');
      }
    }
  }
  return closest;
}

Map<String, Color> _four(NucleotideColors set) => <String, Color>{
  'A': set.adenine,
  'T': set.thymine,
  'G': set.guanine,
  'C': set.cytosine,
};

void main() {
  // What the home screen's helix, and the zoom's at its DNA, draw their bases
  // in: on the warm ground, beside the teal of the transcript and the quiet
  // ink of the backbones.
  const NucleotideColors helix = NucleotideColors.helix;
  const AppColorTokens tokens = AppColorTokens.warm;
  final Map<String, Color> bases = _four(helix);
  const List<String> dichromacies = <String>[
    'deuteranopia',
    'protanopia',
    'tritanopia',
  ];

  test('is the colours it was set to', () {
    expect(helix.adenine.toARGB32(), 0xFF557C39);
    expect(helix.thymine.toARGB32(), 0xFFBE7367);
    expect(helix.guanine.toARGB32(), 0xFFC89D5C);
    expect(helix.cytosine.toARGB32(), 0xFF5981B6);
    // The helix draws no N; the field takes the walk's warm grey.
    expect(helix.unknown, NucleotideColors.muted.unknown);
  });

  test('keeps the hue of the residue each base builds', () {
    // The rhyme the other two sets are held to in `anatomy_colors_test`: the
    // four colours a reader learns as the letters of the gene come back as
    // the four chemistries those letters build. Leaning warm stays inside it.
    const AnatomyColors residues = AnatomyColors.dark;
    final Map<String, (Color, Color)> rhymes = <String, (Color, Color)>{
      'polar / adenine': (residues.aminoPolar, helix.adenine),
      'negative / thymine': (residues.aminoNegative, helix.thymine),
      'special / guanine': (residues.aminoSpecial, helix.guanine),
      'positive / cytosine': (residues.aminoPositive, helix.cytosine),
    };
    rhymes.forEach((String name, (Color, Color) pair) {
      expect(_hueGap(pair.$1, pair.$2), lessThan(10), reason: name);
    });
  });

  test('no base is more saturated than the accent', () {
    // The home screen is the accent on the warm ground; the bases sit beside
    // it rather than over it. The convention at full strength did not: its
    // thymine is half as saturated again.
    final double accent = _chroma(tokens.accent);
    bases.forEach((String base, Color colour) {
      expect(_chroma(colour), lessThanOrEqualTo(accent), reason: base);
    });
    expect(_chroma(NucleotideColors.dark.thymine), greaterThan(accent * 1.5));
  });

  test('every base stands off the ground', () {
    bases.forEach((String base, Color colour) {
      expect(
        _contrast(colour, tokens.surfaceBase),
        greaterThanOrEqualTo(3.5),
        reason: base,
      );
    });
  });

  test('lightness spreads the four, where the convention sat level', () {
    // Three of the convention's four sit within three points of L* 50, which
    // is what folds them into one olive for a deuteranope.
    final List<double> lightness = bases.values.map(_lightness).toList();
    expect(
      lightness.reduce(math.max) - lightness.reduce(math.min),
      greaterThanOrEqualTo(15),
    );
  });

  test('the four stay apart for every dichromat', () {
    double worst(Map<String, Color> set) => <double>[
      for (final String vision in dichromacies) _closest(set, vision).distance,
    ].reduce(math.min);
    for (final String vision in dichromacies) {
      final ({double distance, String pair}) closest = _closest(bases, vision);
      expect(
        closest.distance,
        greaterThanOrEqualTo(6),
        reason: '${closest.pair}, $vision',
      );
    }
    // The convention at full strength, by the same measure: its worst is a
    // deuteranope's thymine and guanine, 2.3 apart. Tritanopia, the rarest,
    // is the one it held better, and there the two stay about level.
    expect(worst(bases), greaterThan(2 * worst(_four(NucleotideColors.dark))));
    expect(_closest(bases).distance, greaterThanOrEqualTo(10));
  });

  test('where size cannot tell two bases apart, colour does', () {
    // The painter draws the two purines a size up and the two pyrimidines a
    // size down, so A and G, and T and C, are told apart by colour alone.
    // Every closer pair is a purine against a pyrimidine.
    final List<(String, Color, Color)> sameSize = <(String, Color, Color)>[
      ('A/G', helix.adenine, helix.guanine),
      ('T/C', helix.thymine, helix.cytosine),
    ];
    for (final String? vision in <String?>[null, ...dichromacies]) {
      for (final (String name, Color a, Color b) in sameSize) {
        expect(
          _distance(a, b, vision),
          greaterThanOrEqualTo(12),
          reason: '$name, ${vision ?? 'normal'}',
        );
      }
    }
  });

  test('stays clear of the helix\'s other two colours', () {
    // The transcript is drawn in the accent and carries bases along it; the
    // backbones are drawn in the quiet ink.
    final Map<String, Color> others = <String, Color>{
      'transcript': tokens.accent,
      'backbone': tokens.onSurfaceVariant,
    };
    for (final String? vision in <String?>[null, ...dichromacies]) {
      bases.forEach((String base, Color colour) {
        others.forEach((String name, Color other) {
          expect(
            _distance(colour, other, vision),
            greaterThanOrEqualTo(11),
            reason: '$base / $name, ${vision ?? 'normal'}',
          );
        });
      });
    }
  });
}
