import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';

/// CIE L*, the perceptual lightness the palette is built on.
double lightness(Color colour) {
  final double y = colour.computeLuminance();
  return y > 0.008856 ? 116 * math.pow(y, 1 / 3) - 16 : 903.3 * y;
}

double contrast(Color a, Color b) {
  final double x = a.computeLuminance();
  final double y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

// --------------------------------------------------------------- colour space
//
// The amino palette was searched rather than picked, and a search is only worth
// as much as the measurements that scored it. These are those measurements,
// written out here so a hand-nudged colour fails a test instead of quietly
// undoing the search.

double _lin(int v) {
  final double c = v / 255;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
}

/// The three linear-light channels of [colour].
List<double> _channels(Color colour) {
  final int argb = colour.toARGB32();
  return <double>[
    _lin((argb >> 16) & 0xFF),
    _lin((argb >> 8) & 0xFF),
    _lin(argb & 0xFF),
  ];
}

/// CIE L*a*b* under D65.
List<double> lab(Color colour) {
  final List<double> c = _channels(colour);
  return _labFrom(c[0], c[1], c[2]);
}

List<double> _labFrom(double r, double g, double b) {
  final double x = 0.4124 * r + 0.3576 * g + 0.1805 * b;
  final double y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final double z = 0.0193 * r + 0.1192 * g + 0.9505 * b;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3) as double : 7.787 * t + 16 / 116;
  final double fx = f(x / 0.95047);
  final double fy = f(y);
  final double fz = f(z / 1.08883);
  return <double>[116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// Hue angle in L*a*b*, which is the axis the palette's anchors are set on.
double hue(Color colour) {
  final List<double> v = lab(colour);
  return (math.atan2(v[2], v[1]) * 180 / math.pi + 360) % 360;
}

double _hueGap(Color a, Color b) {
  final double d = (hue(a) - hue(b)).abs();
  return d > 180 ? 360 - d : d;
}

/// A dichromat's view of [colour] — Viénot, Brettel and Mollon's LMS
/// projection, the same one every colour-blindness checker uses.
Color simulate(Color colour, {required bool deutan}) {
  final List<double> c = _channels(colour);
  final double r = c[0];
  final double g = c[1];
  final double b = c[2];

  double l = 0.31399 * r + 0.63951 * g + 0.04649 * b;
  double m = 0.15537 * r + 0.75789 * g + 0.08670 * b;
  final double s = 0.01775 * r + 0.10945 * g + 0.87262 * b;
  if (deutan) {
    m = 0.494207 * l + 1.24827 * s;
  } else {
    l = 2.02344 * m - 2.52581 * s;
  }

  double gam(double c) {
    final double v = c.clamp(0.0, 1.0);
    return v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  }

  final double rr = gam(5.47221 * l - 4.64190 * m + 0.16963 * s);
  final double gg = gam(-1.12520 * l + 2.29317 * m - 0.16780 * s);
  final double bb = gam(0.02980 * l - 0.19318 * m + 1.16364 * s);
  return Color.fromARGB(
    255,
    (rr * 255).round(),
    (gg * 255).round(),
    (bb * 255).round(),
  );
}

/// CIEDE2000. CIE76 flatters a palette in the saturated corners, which is
/// exactly where seven categorical colours live.
double deltaE(Color x, Color y) {
  final List<double> p = lab(x);
  final List<double> q = lab(y);
  final double c1 = math.sqrt(p[1] * p[1] + p[2] * p[2]);
  final double c2 = math.sqrt(q[1] * q[1] + q[2] * q[2]);
  final double cBar = (c1 + c2) / 2;
  final double gg = cBar == 0
      ? 0.5
      : 0.5 *
            (1 -
                math.sqrt(
                  math.pow(cBar, 7) / (math.pow(cBar, 7) + math.pow(25, 7)),
                ));
  final double a1 = (1 + gg) * p[1];
  final double a2 = (1 + gg) * q[1];
  final double cp1 = math.sqrt(a1 * a1 + p[2] * p[2]);
  final double cp2 = math.sqrt(a2 * a2 + q[2] * q[2]);
  final double h1 = (math.atan2(p[2], a1) * 180 / math.pi + 360) % 360;
  final double h2 = (math.atan2(q[2], a2) * 180 / math.pi + 360) % 360;

  final double dl = q[0] - p[0];
  final double dc = cp2 - cp1;
  final double dh = cp1 * cp2 == 0 ? 0 : ((h2 - h1 + 180) % 360) - 180;
  final double dhh = 2 * math.sqrt(cp1 * cp2) * math.sin(dh * math.pi / 360);

  final double lBar = (p[0] + q[0]) / 2;
  final double cpBar = (cp1 + cp2) / 2;
  final double hBar = cp1 * cp2 == 0
      ? h1 + h2
      : (h1 - h2).abs() <= 180
      ? (h1 + h2) / 2
      : h1 + h2 < 360
      ? (h1 + h2 + 360) / 2
      : (h1 + h2 - 360) / 2;

  double cosd(double deg) => math.cos(deg * math.pi / 180);
  final double t =
      1 -
      0.17 * cosd(hBar - 30) +
      0.24 * cosd(2 * hBar) +
      0.32 * cosd(3 * hBar + 6) -
      0.20 * cosd(4 * hBar - 63);
  final double sl =
      1 +
      0.015 * math.pow(lBar - 50, 2) / math.sqrt(20 + math.pow(lBar - 50, 2));
  final double sc = 1 + 0.045 * cpBar;
  final double sh = 1 + 0.015 * cpBar * t;
  final double rt =
      -2 *
      math.sqrt(
        math.pow(cpBar, 7) / (math.pow(cpBar, 7) + math.pow(25, 7)),
      ) *
      math.sin(
        60 * math.exp(-math.pow((hBar - 275) / 25, 2)) * math.pi / 180,
      );

  return math.sqrt(
    math.pow(dl / sl, 2) +
        math.pow(dc / sc, 2) +
        math.pow(dhh / sh, 2) +
        rt * (dc / sc) * (dhh / sh),
  );
}

/// The smallest distance between any two of [colours] as seen by normal,
/// deuteranopic and protanopic vision at once — the number the search
/// maximised.
({double distance, String pair}) closest(Map<String, Color> colours) {
  double worst = double.infinity;
  String which = '';
  for (final bool? vision in <bool?>[null, true, false]) {
    final Map<String, Color> seen = <String, Color>{
      for (final MapEntry<String, Color> e in colours.entries)
        e.key: vision == null ? e.value : simulate(e.value, deutan: vision),
    };
    final List<String> names = seen.keys.toList();
    for (int i = 0; i < names.length; i++) {
      for (int j = i + 1; j < names.length; j++) {
        final double d = deltaE(seen[names[i]]!, seen[names[j]]!);
        if (d < worst) {
          worst = d;
          which =
              '${names[i]} / ${names[j]} '
              '(${vision == null
                  ? 'normal'
                  : vision
                  ? 'deuteranopia'
                  : 'protanopia'})';
        }
      }
    }
  }
  return (distance: worst, pair: which);
}

void main() {
  const AnatomyColors palette = AnatomyColors.dark;
  // The ground this palette is actually drawn on: the anatomy screens live in
  // the Protein Analyses flow, which is set on the warm tokens.
  final Color ground = AppColorTokens.warm.surfaceBase;

  // Twelve colours that must all be told apart on a near-black ground is more
  // than the eye has room for, so they were searched rather than picked: hue
  // per family, lightness per member, maximising the smallest perceptual
  // distance across normal, deuteranopic and protanopic vision. Nudging one by
  // hand moves it off that optimum, so the values are pinned here and a change
  // has to be made deliberately in this file first.
  group('the searched palette', () {
    final Map<String, (Color, int)> pinned = <String, (Color, int)>{
      'intron': (palette.roleIntron, 0xFF212F2D),
      'untranscribed': (palette.roleUntranscribed, 0xFF475C60),
      "3' UTR": (palette.roleUtr3, 0xFF784C36),
      "5' UTR": (palette.roleUtr5, 0xFFA88661),
      'exon': (palette.roleExon, 0xFF5F869B),
      'CDS': (palette.roleCds, 0xFF90AFD6),
      'C-peptide': (palette.roleMature2, 0xFF75597E),
      'signal peptide': (palette.roleSignal, 0xFFA594BE),
      'B chain': (palette.roleMature1, 0xFF569150),
      'A chain': (palette.roleMature3, 0xFF6CCB9F),
      'start codon': (palette.roleStartCodon, 0xFF26843E),
      'stop codon': (palette.roleStopCodon, 0xFFC44A52),
    };

    pinned.forEach((String feature, (Color, int) row) {
      test('$feature is the colour it was searched to', () {
        expect(row.$1.toARGB32(), row.$2);
      });
    });

    test('the cut sites keep their own colour', () {
      // dibasic outlives this page - it is read among the residues too, where
      // it carries a letter and answers to the amino palette instead. It was
      // held fixed while the rest was searched around it.
      expect(palette.dibasic.toARGB32(), 0xFFD97BB8);
    });

    test('the cut sites do not shout down the gene', () {
      // Twelve cells on a page of 1,431. At full chroma they were the loudest
      // thing on it, which is an emphasis the shape of the gene then had to
      // compete with. Half chroma is the ceiling.
      expect(HSLColor.fromColor(palette.dibasic).saturation, lessThan(0.7));
    });

    test('a cut site is not mistaken for a stop codon', () {
      // Both are small, both are pink, and on the gene page they sit a few rows
      // apart. Toning the cut sites down may not tone them toward red.
      final double cut = HSLColor.fromColor(palette.dibasic).hue;
      final double stop = HSLColor.fromColor(palette.roleStopCodon).hue;
      expect((cut - stop).abs(), greaterThan(30));
    });
  });

  group('what the palette has to mean', () {
    test('the introns recede furthest of anything drawn', () {
      // Two thirds of every pixel of this gene. A field that large reads as a
      // colour choice however quiet the hue is, so it is the darkest thing on
      // the page and very nearly colourless.
      for (final Color other in <Color>[
        palette.roleUntranscribed, palette.roleUtr5, palette.roleUtr3,
        palette.roleExon, palette.roleCds, palette.roleSignal,
        palette.roleStartCodon, palette.roleStopCodon,
        palette.roleMature1, palette.roleMature2,
        palette.roleMature3, palette.dibasic,
      ]) {
        expect(lightness(palette.roleIntron), lessThan(lightness(other)));
      }
      expect(contrast(palette.roleIntron, ground), lessThan(2.0));
    });

    test('what survives outranks what is cut away', () {
      // A reader who has not read a label should still be able to see that the
      // two chains are kept and the peptide between them is not.
      expect(lightness(palette.roleMature3),
          greaterThan(lightness(palette.roleMature2)));
      expect(lightness(palette.roleMature1),
          greaterThan(lightness(palette.roleMature2)));
    });

    test('the base tile is a ground for type, not a colour', () {
      // Every base on the transcript page sits on it and its letter carries
      // the colour, so it is a warm neutral one step off the ground: enough to
      // read as a square, not enough to become a fourth region.
      expect(palette.baseTile.toARGB32(), 0xFF2A2723);
      expect(HSLColor.fromColor(palette.baseTile).saturation, lessThan(0.15));
      expect(contrast(palette.baseTile, ground), inInclusiveRange(1.1, 1.3));
    });

    test('the reading frame carries white type, so it is dark enough for it', () {
      // The one place on this screen where a letter is drawn *in* a colour
      // rather than knocked out of the ground. White at 12pt is body type, so
      // it answers to 4.5:1 and not to the 3:1 large-text floor — which is what
      // pushed both of these well below the lightness the rest of the roles sit
      // at, and why the old 0xFFEB686E could not stay.
      const Color white = Color(0xFFFFFFFF);
      for (final Color fill in <Color>[
        palette.roleStartCodon,
        palette.roleStopCodon,
      ]) {
        expect(contrast(fill, white), greaterThanOrEqualTo(4.5));
      }

      // And to each other: the pair is one instruction in two states, so they
      // are set to one lightness and the eye is left to read the hue. A start
      // codon that sat brighter than its stop would rank them.
      expect(
        lightness(palette.roleStartCodon),
        closeTo(lightness(palette.roleStopCodon), 1),
      );
    });

    test('every role is distinct', () {
      final List<Color> roles = <Color>[
        palette.roleIntron, palette.roleUntranscribed, palette.roleUtr5,
        palette.roleUtr3, palette.roleExon, palette.roleCds, palette.roleSignal,
        palette.roleStartCodon, palette.roleStopCodon,
        palette.roleMature1, palette.roleMature2,
        palette.roleMature3, palette.dibasic,
      ];
      expect(roles.map((Color c) => c.toARGB32()).toSet(), hasLength(roles.length));
    });
  });

  group('the amino acid groups', () {
    final Map<String, Color> groups = <String, Color>{
      'aliphatic': palette.aminoAliphatic,
      'aromatic': palette.aminoAromatic,
      'positive': palette.aminoPositive,
      'negative': palette.aminoNegative,
      'polar': palette.aminoPolar,
      'special': palette.aminoSpecial,
      'cysteine': palette.aminoCysteine,
    };

    test('carry a knocked-out letter', () {
      // These squares have their residue punched out of them in the ground
      // colour, so one too close to the ground erases its own letter. It is
      // also why none of them may be darkened toward the base it rhymes with:
      // white would need the other half of the lightness axis, and the two inks
      // meet around L* 50 with no overlap.
      // aminoUnknown is not one of the seven and is quiet on purpose.
      groups.forEach((String name, Color residue) {
        expect(
          contrast(residue, ground),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
      });
      // dibasic is read among the residues too, so it answers to the same
      // floor.
      expect(contrast(palette.dibasic, ground), greaterThanOrEqualTo(4.5));
    });

    test('four of them are the nucleotide they build', () {
      // The rhyme, and the reason these hues are not free. A reader spends two
      // pages learning four colours as the letters of the gene; those four come
      // back as the four chemistries those letters build. It costs nothing in
      // accuracy, because it is also the convention — polar is green in Zappo,
      // Clustal and RasMol, negative is red in Zappo and RasMol, positive is
      // blue in both, and Clustal draws glycine orange.
      //
      // Both base sets rhyme, because they are one set of hues: the muted four
      // the transcript is lettered in are the convention's own, held to 40%.
      for (final NucleotideColors bases in <NucleotideColors>[
        NucleotideColors.dark,
        NucleotideColors.muted,
      ]) {
        final Map<String, (Color, Color)> rhymes = <String, (Color, Color)>{
          'polar / adenine': (palette.aminoPolar, bases.adenine),
          'negative / thymine': (palette.aminoNegative, bases.thymine),
          'special / guanine': (palette.aminoSpecial, bases.guanine),
          'positive / cytosine': (palette.aminoPositive, bases.cytosine),
        };
        rhymes.forEach((String name, (Color, Color) pair) {
          expect(
            _hueGap(pair.$1, pair.$2),
            lessThan(10),
            reason: '$name are no longer the same hue (${pair.$2})',
          );
        });
      }
    });

    test('the field recedes and the rarest residue leads', () {
      // A, I, L, M and V are together some two fifths of any protein, so
      // aliphatic is not a category so much as the ground the other six sit on,
      // and it is the darkest of them for the same reason the introns are the
      // darkest thing on the gene page. Cysteine is the opposite: the rarest
      // residue, and the one that holds the two insulin chains together.
      final double aliphatic = lightness(palette.aminoAliphatic);
      final double cysteine = lightness(palette.aminoCysteine);
      for (final MapEntry<String, Color> group in groups.entries) {
        if (group.key == 'aliphatic') {
          continue;
        }
        expect(
          aliphatic,
          lessThan(lightness(group.value)),
          reason: 'aliphatic should recede behind ${group.key}',
        );
      }
      for (final MapEntry<String, Color> group in groups.entries) {
        if (group.key == 'cysteine') {
          continue;
        }
        expect(
          cysteine,
          greaterThan(lightness(group.value)),
          reason: 'cysteine should lead ${group.key}',
        );
      }
    });

    test('stay apart for a dichromat, as well as they do for the bases', () {
      // The number the search maximised, and the bar it was held to: the four
      // bases are 10.2 apart at their closest across normal, deuteranopic and
      // protanopic vision, and seven colours have to manage the same. The
      // palette this replaced managed 1.8, because its lightness happened to
      // fall where its hues did.
      //
      // The spread of lightness is what buys this. A palette at one lightness
      // collapses to about 1 for a deuteranope however far apart its hues are,
      // which is why these are not one tidy band.
      const NucleotideColors bases = NucleotideColors.dark;
      final double bar = closest(<String, Color>{
        'A': bases.adenine,
        'T': bases.thymine,
        'G': bases.guanine,
        'C': bases.cytosine,
      }).distance;
      expect(bar, closeTo(10.2, 0.5));

      final ({double distance, String pair}) worst = closest(groups);
      expect(
        worst.distance,
        greaterThanOrEqualTo(9),
        reason: '${worst.pair} are too close to tell apart',
      );
    });

    test('stay clear of the cut sites and the name chips', () {
      // A floor rather than part of the number above, because both of these
      // carry a second signal: a cut site is outlined into its own mortar, and
      // a chip is a pill with a word in it. Neither has to win on colour alone
      // — and a deuteranope sees the magenta of a cut site as very nearly the
      // grey the aliphatic field has to be, so letting that pair drive the
      // search only ever dragged the seven groups together.
      //
      // The chips are measured as the painter actually draws them: the role
      // colour lifted off the ground, not the role colour itself.
      Color chip(Color role, double strength) =>
          Color.lerp(ground, role, strength)!;
      final Map<String, Color> others = <String, Color>{
        'dibasic': palette.dibasic,
        'chip signal': chip(palette.roleSignal, 0.16),
        'chip proprotein': chip(palette.roleCds, 0.34),
        'chip B chain': chip(palette.roleMature1, 0.34),
        'chip C-peptide': chip(palette.roleMature2, 0.34),
        'chip A chain': chip(palette.roleMature3, 0.34),
      };

      for (final MapEntry<String, Color> group in groups.entries) {
        for (final MapEntry<String, Color> other in others.entries) {
          final ({double distance, String pair}) worst = closest(
            <String, Color>{group.key: group.value, other.key: other.value},
          );
          expect(
            worst.distance,
            greaterThanOrEqualTo(6),
            reason: worst.pair,
          );
        }
      }
    });

    test('are the colours they were searched to', () {
      // Pinned for the same reason the role colours above are: these were
      // searched, not picked, and nudging one by hand moves it off the optimum
      // without anything saying so.
      expect(palette.aminoAliphatic.toARGB32(), 0xFF7D8494);
      expect(palette.aminoAromatic.toARGB32(), 0xFFC599D9);
      expect(palette.aminoPositive.toARGB32(), 0xFF78B1FF);
      expect(palette.aminoNegative.toARGB32(), 0xFFF07369);
      expect(palette.aminoPolar.toARGB32(), 0xFF70B063);
      expect(palette.aminoSpecial.toARGB32(), 0xFFD0934F);
      expect(palette.aminoCysteine.toARGB32(), 0xFFE5D86B);
    });
  });

  // What the Protein Analyses flow actually draws: the searched palette through
  // the colour filter of an E Ink Kaleido 3 panel. The filter keeps lightness
  // and hue, so every promise above made in those terms has to still hold here.
  group('through the Kaleido filter', () {
    final AnatomyColors filtered = AnatomyColors.kaleido;
    final Map<String, Color> groups = <String, Color>{
      'aliphatic': filtered.aminoAliphatic,
      'aromatic': filtered.aminoAromatic,
      'positive': filtered.aminoPositive,
      'negative': filtered.aminoNegative,
      'polar': filtered.aminoPolar,
      'special': filtered.aminoSpecial,
      'cysteine': filtered.aminoCysteine,
    };

    test('is the colours the filter makes of the searched ones', () {
      // Pinned, so a change to the filter is a change made deliberately here.
      expect(filtered.aminoAliphatic.toARGB32(), 0xFF81848C);
      expect(filtered.aminoAromatic.toARGB32(), 0xFFB8A1C1);
      expect(filtered.aminoPositive.toARGB32(), 0xFF9AB0D7);
      expect(filtered.aminoNegative.toARGB32(), 0xFFC98981);
      expect(filtered.aminoPolar.toARGB32(), 0xFF8BA982);
      expect(filtered.aminoSpecial.toARGB32(), 0xFFBB9978);
      expect(filtered.aminoCysteine.toARGB32(), 0xFFE0D6A2);
      expect(filtered.aminoUnknown.toARGB32(), 0xFF53575E);
      expect(filtered.dibasic.toARGB32(), 0xFFBB8DA9);
    });

    test('leaves the roles as they were searched', () {
      // The gene page draws these, and it is not what the filter is for.
      final List<(Color, Color)> untouched = <(Color, Color)>[
        (filtered.roleIntron, palette.roleIntron),
        (filtered.roleUntranscribed, palette.roleUntranscribed),
        (filtered.roleUtr5, palette.roleUtr5),
        (filtered.roleUtr3, palette.roleUtr3),
        (filtered.roleExon, palette.roleExon),
        (filtered.roleCds, palette.roleCds),
        (filtered.roleStartCodon, palette.roleStartCodon),
        (filtered.roleStopCodon, palette.roleStopCodon),
        (filtered.roleSignal, palette.roleSignal),
        (filtered.roleMature1, palette.roleMature1),
        (filtered.roleMature2, palette.roleMature2),
        (filtered.roleMature3, palette.roleMature3),
        (filtered.baseTile, palette.baseTile),
      ];
      for (final (Color, Color) pair in untouched) {
        expect(pair.$1, pair.$2);
      }
    });

    test('still carries a knocked-out letter', () {
      for (final MapEntry<String, Color> group in <String, Color>{
        ...groups,
        'dibasic': filtered.dibasic,
      }.entries) {
        expect(
          contrast(group.value, ground),
          greaterThanOrEqualTo(4.5),
          reason: group.key,
        );
      }
    });

    test('still lets the field recede and cysteine lead', () {
      final double aliphatic = lightness(filtered.aminoAliphatic);
      final double cysteine = lightness(filtered.aminoCysteine);
      groups.forEach((String name, Color colour) {
        if (name != 'aliphatic') {
          expect(aliphatic, lessThan(lightness(colour)), reason: name);
        }
        if (name != 'cysteine') {
          expect(cysteine, greaterThan(lightness(colour)), reason: name);
        }
      });
    });

    test('still rhymes with both sets of bases', () {
      for (final NucleotideColors bases in <NucleotideColors>[
        NucleotideColors.dark,
        NucleotideColors.muted,
      ]) {
        final Map<String, (Color, Color)> rhymes = <String, (Color, Color)>{
          'polar / adenine': (filtered.aminoPolar, bases.adenine),
          'negative / thymine': (filtered.aminoNegative, bases.thymine),
          'special / guanine': (filtered.aminoSpecial, bases.guanine),
          'positive / cytosine': (filtered.aminoPositive, bases.cytosine),
        };
        rhymes.forEach((String name, (Color, Color) pair) {
          expect(
            _hueGap(pair.$1, pair.$2),
            lessThan(10),
            reason: '$name (${pair.$2})',
          );
        });
      }
    });

    test('keeps the cut site magenta, and no louder than it was', () {
      final HSLColor cut = HSLColor.fromColor(filtered.dibasic);
      expect(cut.saturation, lessThan(0.7));
      expect(
        (cut.hue - HSLColor.fromColor(filtered.roleStopCodon).hue).abs(),
        greaterThan(30),
      );
    });

    test('stays apart at a glance', () {
      // For normal vision. [simulate] above pairs the normalised LMS matrix
      // with the projections made for the unnormalised one, which scores any
      // loss of chroma as a collapse, so it can only judge the searched
      // palette it was tuned beside; correcting it is a change of its own.
      final List<String> names = groups.keys.toList();
      for (int i = 0; i < names.length; i++) {
        for (int j = i + 1; j < names.length; j++) {
          expect(
            deltaE(groups[names[i]]!, groups[names[j]]!),
            greaterThanOrEqualTo(14),
            reason: '${names[i]} / ${names[j]}',
          );
        }
      }
      Color chip(Color role, double strength) =>
          Color.lerp(ground, role, strength)!;
      final Map<String, Color> others = <String, Color>{
        'dibasic': filtered.dibasic,
        'chip signal': chip(filtered.roleSignal, 0.16),
        'chip proprotein': chip(filtered.roleCds, 0.34),
        'chip B chain': chip(filtered.roleMature1, 0.34),
        'chip C-peptide': chip(filtered.roleMature2, 0.34),
        'chip A chain': chip(filtered.roleMature3, 0.34),
      };
      groups.forEach((String name, Color colour) {
        others.forEach((String other, Color against) {
          expect(
            deltaE(colour, against),
            greaterThanOrEqualTo(6),
            reason: '$name / $other',
          );
        });
      });
    });
  });
}
