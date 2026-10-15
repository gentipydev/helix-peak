import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../domain/locus_track.dart';
import '../../../domain/zoom_depth.dart';
import '../contour.dart';
import 'chromosome_style.dart';

/// A chromosome at metaphase as a form, from its locus track alone: two
/// sister chromatids, each a tube as thick as a chromatid is, touching along
/// a hairline groove and pinched together at the centromere, opening a
/// little toward their ends, both arms bent a little the same way. Every
/// protein's chromosome is this form, its track's own; proteins on one
/// chromosome share it, and only the gene's mark tells them apart.
///
/// Its units are the chromosome scene's: the chromosome stands [length]
/// tall about the origin, its short arm up.
final class ChromosomeForm {
  ChromosomeForm(this.track, {required this.half});

  final LocusTrack track;

  /// One chromatid's half-width, in the scene's units.
  final double half;

  /// The chromosome's length in the scene's units: the view is
  /// [ZoomDepth.chromosomeView] times it.
  static const double length = 1 / ZoomDepth.chromosomeView;

  /// How far apart the two chromatids' middles lie: touching, along a
  /// hairline groove.
  double get apart => half * ChromosomeStyle.apart;

  double yOf(num base) => -length / 2 + (base - 1) / track.length * length;

  /// The chromosome's two ends.
  double get top => yOf(1);
  double get bottom => yOf(track.length + 1);

  /// The middle of the band or bands the gene lies in.
  double get bandY => (yOf(track.bandStart) + yOf(track.bandEnd + 1)) / 2;

  /// Where the centromere is: the end of the short arm.
  late final double centromere = () {
    for (final CytoBand band in track.bands) {
      if (!band.onShortArm) {
        return yOf(band.start);
      }
    }
    return 0.0;
  }();

  /// How pinched the chromatids are at [y]: 1 at the centromere.
  double waist(double y) {
    final double d = (y - centromere) / (half * 0.9);
    return math.exp(-d * d);
  }

  /// A chromatid's half-width at [y]: narrower at the waist, rounded to
  /// nothing at each end. An acrocentric's stalk and satellite are bands
  /// like any other, as thick as the arm they are in: drawn thin, the stalk
  /// read as a cut.
  double widthAt(double y) {
    double w = half * (1 - 0.42 * waist(y));
    final double top = yOf(1);
    final double bottom = yOf(track.length + 1);
    final double cap = half;
    final double fromEnd = math.min(y - top, bottom - y);
    if (fromEnd < cap) {
      final double t = (cap - fromEnd) / cap;
      w *= math.sqrt(math.max(0, 1 - t * t));
    }
    return w;
  }

  /// The longer arm's length: how far the arms' opening and bend reach.
  late final double _reach = math.max(centromere - top, bottom - centromere);

  /// How far along the longer arm [y] lies from the centromere, 0 to 1.
  double _along(double y) => ((y - centromere).abs() / _reach).clamp(0.0, 1.0);

  /// How far each sister opens from the other at [y].
  double opening(double y) =>
      ChromosomeStyle.opening *
      half *
      math.pow(_along(y), ChromosomeStyle.openingPower).toDouble();

  /// How far both arms bend the same way at [y].
  double bend(double y) {
    final double a = _along(y);
    return ChromosomeStyle.bend * half * a * a;
  }

  /// Where chromatid [side]'s middle lies at [y]: touching its sister along
  /// the groove, drawn together at the waist, opening a little toward its
  /// ends, bent with its sister, and [merge] of the way onto the axis.
  double centreAt(double side, double y, {double merge = 0}) =>
      (side * (apart * (1 - ChromosomeStyle.pinch * waist(y)) + opening(y)) +
          bend(y)) *
      (1 - merge);

  /// How much the sisters touch at [y]: 1 along the groove, falling to 0
  /// as they open apart.
  double contact(double y) {
    final double gap = centreAt(1, y) - centreAt(-1, y) - 2 * widthAt(y);
    if (gap <= 0) {
      return 1;
    }
    final double t = (gap / (half * 0.12)).clamp(0.0, 1.0);
    return 1 - t * t * (3 - 2 * t);
  }

  /// How fast a chromatid widens at [y], going down: how far its surface
  /// faces up or down there.
  double slope(double y) {
    const double step = 1e-4;
    final double a = math.max(top, y - step);
    final double b = math.min(bottom, y + step);
    if (b <= a) {
      return 0;
    }
    return ((widthAt(b) - widthAt(a)) / (b - a)).clamp(-8.0, 8.0);
  }

  /// How far a band's edge bows at [y], as a ring round the tube seen a
  /// little from below: none in the rounded ends, where rows close in.
  double bowAt(double y) {
    final double fromEnd = math.min(y - top, bottom - y);
    final double t = (fromEnd / half).clamp(0.0, 1.0);
    return ChromosomeStyle.bow * widthAt(y) * t * t;
  }

  /// The heights an outline is drawn through, top to bottom: [steps] even
  /// ones, and more round each end, where it turns fastest.
  List<double> _rows(int steps) {
    const int round = 16;
    final double top = yOf(1);
    final double bottom = yOf(track.length + 1);
    return <double>{
      for (int i = 0; i <= steps; i++) top + (bottom - top) * i / steps,
      for (int i = 1; i < round; i++) ...<double>[
        top + half * (1 - math.cos(math.pi / 2 * i / round)),
        bottom - half * (1 - math.cos(math.pi / 2 * i / round)),
      ],
    }.toList()..sort();
  }

  late final List<double> _chromatidRows = _rows(120);
  late final List<double> _outlineRows = _rows(64);

  /// One chromatid's outline, [merge] of the way to lying on the axis, at
  /// [thin] of the way to [target] half-width.
  Contour chromatid(
    double side, {
    double merge = 0,
    double thin = 0,
    double? target,
  }) {
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (final double y in _chromatidRows) {
      final double centre = centreAt(side, y, merge: merge);
      final double w = widthAt(y) + ((target ?? half) - widthAt(y)) * thin;
      left.add(Offset(centre - w, y));
      right.add(Offset(centre + w, y));
    }
    return Contour(<Offset>[...right, ...left.reversed]);
  }

  /// The two chromatids' outer outline, as one shape.
  Contour outline() {
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (final double y in _outlineRows) {
      final double w = widthAt(y);
      left.add(Offset(centreAt(-1, y) - w, y));
      right.add(Offset(centreAt(1, y) + w, y));
    }
    return Contour(<Offset>[...right, ...left.reversed]);
  }

  // The bands, softened at their edges.

  /// The softening at the top edge of each band: none at the first.
  late final List<double> _feathers = <double>[
    for (int i = 0; i < track.bands.length; i++)
      i == 0
          ? 0
          : math.min(
              ChromosomeStyle.feather * half,
              ChromosomeStyle.featherShare *
                  math.min(_thickness(i - 1), _thickness(i)),
            ),
  ];

  double _thickness(int i) =>
      yOf(track.bands[i].end + 1) - yOf(track.bands[i].start);

  /// The band [y] lies in.
  int _bandAt(double y) {
    int lo = 0;
    int hi = track.bands.length - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) ~/ 2;
      if (yOf(track.bands[mid].start) <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// How dark the stain is at [y] ([ChromosomeStyle.tone]), each band's
  /// edges softened into the next.
  double toneAt(double y) {
    final int i = _bandAt(y);
    final List<CytoBand> bands = track.bands;
    final double own = ChromosomeStyle.tone(bands[i].stain);
    final double a = yOf(bands[i].start);
    final double b = yOf(bands[i].end + 1);
    if (i > 0 && y < a + _feathers[i]) {
      final double f = _feathers[i];
      final double above = ChromosomeStyle.tone(bands[i - 1].stain);
      return above + (own - above) * (y - (a - f)) / (2 * f);
    }
    if (i < bands.length - 1 && y > b - _feathers[i + 1]) {
      final double f = _feathers[i + 1];
      final double below = ChromosomeStyle.tone(bands[i + 1].stain);
      return own + (below - own) * (y - (b - f)) / (2 * f);
    }
    return own;
  }

  /// How much of the gene's band is at [y], from 0 to 1, its edges softened
  /// as every band's are.
  double geneAt(double y) {
    double ramp(double reach, double f) =>
        f <= 0 ? (reach >= 0 ? 1 : 0) : ((reach + f) / (2 * f)).clamp(0.0, 1.0);
    final int first = _bandAt(yOf(track.bandStart));
    final int last = _bandAt(yOf(track.bandEnd));
    final double softTop = _feathers[first];
    final double softBottom = last + 1 < _feathers.length
        ? _feathers[last + 1]
        : 0;
    return math.min(
      ramp(y - yOf(track.bandStart), softTop),
      ramp(yOf(track.bandEnd + 1) - y, softBottom),
    );
  }

  /// The rows the body is drawn through, top to bottom: one every so far
  /// along, closer round the waist and the rounded ends, and two at each
  /// band's edge, where its softening begins and ends.
  late final Float64List bodyRows = () {
    final double step = ChromosomeStyle.rowStep * half;
    final double fine = ChromosomeStyle.waistRowStep * half;
    final double reach = ChromosomeStyle.waistRows * half;
    const int round = 16;
    final List<double> rows = <double>[
      for (double y = top; y < bottom; y += step) y,
      bottom,
      for (int i = 1; i < round; i++) ...<double>[
        top + half * (1 - math.cos(math.pi / 2 * i / round)),
        bottom - half * (1 - math.cos(math.pi / 2 * i / round)),
      ],
      for (double y = centromere - reach; y <= centromere + reach; y += fine) y,
      for (int i = 1; i < track.bands.length; i++) ...<double>[
        yOf(track.bands[i].start) - _feathers[i],
        yOf(track.bands[i].start) + _feathers[i],
      ],
    ]..sort();
    final List<double> kept = <double>[];
    for (final double y in rows) {
      if (y < top || y > bottom) {
        continue;
      }
      if (kept.isEmpty || y - kept.last > 1e-7) {
        kept.add(y);
      }
    }
    return Float64List.fromList(kept);
  }();

  // The gene, and the kinetochores.

  /// The middle of the gene's span.
  double get geneY => yOf((track.spanStart + track.spanEnd + 1) / 2);

  /// A FISH spot's radius: about half a chromatid, whatever the gene's
  /// length, and never wider than the chromatid where it lies.
  double get fishRadius => math.min(
    ChromosomeStyle.fish * half,
    ChromosomeStyle.fishShare * widthAt(geneY),
  );

  /// Where chromatid [side]'s FISH spot lies: on its axis, at the gene.
  Offset fish(double side, {double merge = 0}) =>
      Offset(centreAt(side, geneY, merge: merge), geneY);

  /// Where chromatid [side]'s kinetochore lies: on its outer face at the
  /// centromere.
  Offset kinetochore(double side) => Offset(
    centreAt(side, centromere) +
        side * ChromosomeStyle.plateOut * widthAt(centromere),
    centromere,
  );

  // The relief.

  /// The knobs on chromatid [side]'s surface: lobes on a jittered lattice
  /// and granules strewn between, laid by a seed of the chromosome's own, so
  /// every protein on it has the same.
  KnobField knobs(double side) => side < 0 ? _knobs[0] : _knobs[1];

  late final List<KnobField> _knobs = <KnobField>[_lay(-1), _lay(1)];

  int _seed(double side) {
    int seed = track.length % 1000003;
    for (final int unit in track.chromosome.codeUnits) {
      seed = (seed * 31 + unit) % 1000003;
    }
    return seed * 2 + (side < 0 ? 0 : 1);
  }

  /// How fine the relief is at [y]: 1 in the centromere's zone, where
  /// lobes are fewer and smaller.
  double _zone(double y) {
    double acen = 0;
    final int i = _bandAt(y);
    if (track.bands[i].stain == Stain.acen) {
      acen = 1;
    }
    return math.max(waist(y), acen);
  }

  KnobField _lay(double side) {
    final math.Random random = math.Random(_seed(side));
    final List<double> ys = <double>[];
    final List<double> phis = <double>[];
    final List<double> radii = <double>[];
    final List<int> kinds = <int>[];
    // Nothing of one sister crosses the groove onto the other.
    bool clear(double y, double phi, double r) {
      final double x = centreAt(side, y) + widthAt(y) * math.sin(phi);
      final double across = r * math.max(math.cos(phi), 0.45);
      final double middle = bend(y);
      return side * (x - middle) - across >= -0.05 * half;
    }

    final double mean =
        (ChromosomeStyle.lobe + ChromosomeStyle.lobeSpread / 2) * half;
    final double spacing = ChromosomeStyle.lobeLattice * mean;
    int row = 0;
    for (double y = top + spacing * 0.433; y < bottom; y += spacing * 0.866) {
      final double w = widthAt(y);
      if (w > 0.25 * half) {
        final double around = math.pi * w;
        final double shift = row.isOdd ? spacing / 2 : 0;
        for (
          double arc = -around / 2 + shift + spacing / 2;
          arc < around / 2;
          arc += spacing
        ) {
          final double ay =
              (y + (random.nextDouble() - 0.5) * 0.5 * spacing * 0.866).clamp(
                top,
                bottom,
              );
          final double aw = widthAt(ay);
          if (aw <= 0) {
            continue;
          }
          final double a = arc + (random.nextDouble() - 0.5) * 0.5 * spacing;
          final double phi = (a / aw).clamp(-1.5, 1.5);
          final double taper = math.sqrt(math.min(1, aw / (0.6 * half)));
          final double r =
              half *
              (ChromosomeStyle.lobe +
                  ChromosomeStyle.lobeSpread * random.nextDouble()) *
              (1 - ChromosomeStyle.lobeWaist * _zone(ay)) *
              taper;
          if (clear(ay, phi, r)) {
            ys.add(ay);
            phis.add(phi);
            radii.add(r);
            kinds.add(KnobField.lobe);
          }
        }
      }
      row++;
    }
    final int granules = (ChromosomeStyle.granules * length / half).round();
    int laid = 0;
    int tries = 0;
    while (laid < granules && tries < granules * 8) {
      tries++;
      final double y = top + (bottom - top) * random.nextDouble();
      final double w = widthAt(y);
      if (random.nextDouble() > w / half) {
        continue;
      }
      final double phi = (random.nextDouble() * 2 - 1) * 1.45;
      final double r = math.max(
        ChromosomeStyle.granuleFloor,
        half *
            (ChromosomeStyle.granule +
                ChromosomeStyle.granuleSpread * random.nextDouble()),
      );
      if (!clear(y, phi, r)) {
        continue;
      }
      ys.add(y);
      phis.add(phi);
      radii.add(r);
      kinds.add(random.nextDouble() < 0.6 ? KnobField.bump : KnobField.pit);
      laid++;
    }
    return KnobField(
      Float32List.fromList(ys),
      Float32List.fromList(phis),
      Float32List.fromList(radii),
      Uint8List.fromList(kinds),
    );
  }
}

/// The knobs on one chromatid's surface: where each lies along the
/// chromosome ([y]) and round the tube ([phi], 0 facing out of the screen),
/// its radius, and what it is.
final class KnobField {
  KnobField(this.y, this.phi, this.radius, this.kind);

  /// A lobe: a knob of chromatin, lit as a small dome.
  static const int lobe = 0;

  /// A granule standing out of the surface, or sunk into it.
  static const int bump = 1;
  static const int pit = 2;

  final Float32List y;
  final Float32List phi;
  final Float32List radius;
  final Uint8List kind;

  int get length => y.length;
}
