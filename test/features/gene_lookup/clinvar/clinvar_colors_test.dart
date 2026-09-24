import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/clinvar_colors.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_colors.dart';

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

double _contrast(Color a, Color b) {
  double luminance(Color c) {
    final List<double> v = _linear(c);
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
  }

  final double x = luminance(a);
  final double y = luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  // Other is a ring, told apart by shape; the four filled classes carry hue.
  final Map<ClinVarGroup, Color> filled = <ClinVarGroup, Color>{
    for (final ClinVarGroup g in ClinVarGroup.values)
      if (!ClinVarColors.hollow(g)) g: ClinVarColors.of(g),
  };
  const List<String?> visions = <String?>[
    null,
    'deuteranopia',
    'protanopia',
    'tritanopia',
  ];

  test('the filled classes stay apart, for every kind of colour vision', () {
    expect(filled, hasLength(4));
    final List<ClinVarGroup> groups = filled.keys.toList();
    for (final String? vision in visions) {
      for (int i = 0; i < groups.length; i++) {
        for (int j = i + 1; j < groups.length; j++) {
          expect(
            _distance(filled[groups[i]]!, filled[groups[j]]!, vision),
            greaterThanOrEqualTo(vision == null ? 15 : 9),
            reason: '${groups[i].name}/${groups[j].name}, ${vision ?? 'normal'}',
          );
        }
      }
    }
  });

  test('no class can be read as a step of the constraint ramp', () {
    for (final Color stop in <Color>[
      ConstraintColors.tolerant,
      ConstraintColors.moderate,
      ConstraintColors.constrained,
    ]) {
      for (final MapEntry<ClinVarGroup, Color> entry in filled.entries) {
        for (final String? vision in visions) {
          expect(
            _distance(entry.value, stop, vision),
            greaterThanOrEqualTo(5),
            reason: '${entry.key.name} vs $stop, ${vision ?? 'normal'}',
          );
        }
      }
    }
    // The old pathogenic amber was about one unit from "highly constrained".
    expect(
      _distance(const Color(0xFFF0AF69), ConstraintColors.constrained),
      lessThan(2),
    );
  });

  test('no class is the accent every link and the mask are drawn in', () {
    for (final MapEntry<ClinVarGroup, Color> entry in filled.entries) {
      expect(
        _distance(entry.value, AppColorTokens.dark.accent),
        greaterThanOrEqualTo(12),
        reason: entry.key.name,
      );
    }
  });

  test('every mark holds 3:1 against both analysis surfaces', () {
    for (final Color surface in <Color>[
      AppColorTokens.warm.surfaceBase,
      AppColorTokens.warm.surfaceRaised,
    ]) {
      for (final ClinVarGroup group in ClinVarGroup.values) {
        expect(
          _contrast(ClinVarColors.of(group), surface),
          greaterThanOrEqualTo(2.95),
          reason: '${group.name} on $surface',
        );
      }
    }
  });
}
