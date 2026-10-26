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
/// tall about the origin, its short arm up. Its numbers are [look]'s, and
/// its knobs are globules, each of one material ([KnobField.material]), with
/// a cleft kept between the sisters.
final class ChromosomeForm {
  ChromosomeForm(this.track, {required this.half, required this.look});

  final LocusTrack track;

  /// One chromatid's half-width, in the scene's units.
  final double half;

  /// The look it is drawn in, and tuned by.
  final ChromosomeLookSpec look;

  /// The chromosome's length in the scene's units: the view is
  /// [ZoomDepth.chromosomeView] times it.
  static const double length = 1 / ZoomDepth.chromosomeView;

  /// How far apart the two chromatids' middles lie: touching, along a
  /// hairline groove.
  double get apart => half * look.apart;

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

  /// The short arm's length, in half-widths, that holds the waist's reach
  /// and the rounded end with room between them.
  static const double _shortArmRoom = 3.2;

  /// How much of their size the waist and the short arm's rounded end are
  /// drawn at: all of it, but on a short arm too short to hold both with
  /// room between them, less, in proportion, so that what lies between
  /// them, a stalk among it, is as thick as its arm. Of the chromosomes the
  /// curated proteins lie on, 13's and 14's arms are that short.
  late final double _fit = math.max(
    0.25,
    math.min(1.0, (centromere - top) / (half * _shortArmRoom)),
  );

  /// How pinched the chromatids are at [y]: 1 at the centromere.
  double waist(double y) {
    final double d = (y - centromere) / (half * look.waistLength * _fit);
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
    final bool upper = y - top < bottom - y;
    final double cap = upper ? _topCap : _cap;
    final double fromEnd = upper ? y - top : bottom - y;
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
      look.opening * half * math.pow(_along(y), look.openingPower).toDouble();

  /// How far both arms bend the same way at [y].
  double bend(double y) {
    final double a = _along(y);
    return look.bend * half * a * a;
  }

  /// Where chromatid [side]'s middle lies at [y]: touching its sister along
  /// the groove, drawn together at the waist, opening a little toward its
  /// ends, bent with its sister, and [merge] of the way onto the axis.
  double centreAt(double side, double y, {double merge = 0}) =>
      (side * (apart * (1 - look.pinch * waist(y)) + opening(y)) + bend(y)) *
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
    return look.bow * widthAt(y) * t * t;
  }

  /// How far in from either end a chromatid rounds to nothing.
  double get _cap => half * look.endRound;

  /// How far in from the short arm's end: the same, drawn down with the
  /// waist on a short arm too short for both.
  double get _topCap => _cap * _fit;

  /// The heights an outline is drawn through, top to bottom: [steps] even
  /// ones, and more round each end, where it turns fastest.
  List<double> _rows(int steps) {
    const int round = 16;
    final double top = yOf(1);
    final double bottom = yOf(track.length + 1);
    return <double>{
      for (int i = 0; i <= steps; i++) top + (bottom - top) * i / steps,
      for (int i = 1; i < round; i++) ...<double>[
        top + _topCap * (1 - math.cos(math.pi / 2 * i / round)),
        bottom - _cap * (1 - math.cos(math.pi / 2 * i / round)),
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

  /// How far apart the sisters' facing sides are at [y]: below 0 where they
  /// overlap along the groove.
  double _gap(double y) => centreAt(1, y) - centreAt(-1, y) - 2 * widthAt(y);

  /// The two chromatids' outline, as one shape: round each sister's outer
  /// side and its ends, and into the cleft between them toward each end,
  /// where they part wider than the groove is drawn, so a shape drawn in to
  /// it covers only what the sisters do. It starts at the top of the right
  /// sister and runs clockwise on screen.
  Contour outline() {
    final List<double> rows = _outlineRows;
    final int n = rows.length;
    final double parted = 0.07 * half;
    int first = 0;
    while (first < n && _gap(rows[first]) > parted) {
      first++;
    }
    int last = n - 1;
    while (last > first && _gap(rows[last]) > parted) {
      last--;
    }
    // Where the facing sides close to the groove's width, between two rows.
    Offset meet(int a, int b) {
      final double ga = _gap(rows[a]) - parted;
      final double gb = _gap(rows[b]) - parted;
      final double t = ga == gb ? 0 : (ga / (ga - gb)).clamp(0.0, 1.0);
      final double y = rows[a] + (rows[b] - rows[a]) * t;
      return Offset((centreAt(1, y) + centreAt(-1, y)) / 2, y);
    }

    Offset outer(double side, double y) =>
        Offset(centreAt(side, y) + side * widthAt(y), y);
    Offset inner(double side, double y) =>
        Offset(centreAt(side, y) - side * widthAt(y), y);
    final bool apart = first > 0 && first < n;
    final bool apartBelow = last < n - 1 && apart;
    return Contour(<Offset>[
      // The right sister: up its side facing the cleft at the top, down
      // its outer side, and up into the cleft at the bottom.
      if (apart) ...<Offset>[
        meet(first - 1, first),
        for (int i = first - 1; i >= 0; i--) inner(1, rows[i]),
      ],
      for (int i = 0; i < n; i++) outer(1, rows[i]),
      if (apartBelow) ...<Offset>[
        for (int i = n - 1; i > last; i--) inner(1, rows[i]),
        meet(last, last + 1),
        for (int i = last + 1; i < n; i++) inner(-1, rows[i]),
      ],
      // The left sister: up its outer side, and down into the cleft.
      for (int i = n - 1; i >= 0; i--) outer(-1, rows[i]),
      if (apart)
        for (int i = 0; i < first; i++) inner(-1, rows[i]),
    ]);
  }

  // The bands, softened at their edges.

  /// The softening at the top edge of each band: none at the first.
  late final List<double> _feathers = <double>[
    for (int i = 0; i < track.bands.length; i++)
      i == 0
          ? 0
          : math.min(
              look.feather * half,
              look.featherShare * math.min(_thickness(i - 1), _thickness(i)),
            ),
  ];

  double _thickness(int i) =>
      yOf(track.bands[i].end + 1) - yOf(track.bands[i].start);

  /// How far the top edge of band [i] is softened to either side: none at
  /// the first.
  double featherAt(int i) => _feathers[i];

  /// The band [y] lies in, by its place in the track's bands.
  int bandAt(double y) => _bandAt(y);

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

  /// How dark the stain is at [y] ([ChromosomeLookSpec.tone]), each band's
  /// edges softened into the next.
  double toneAt(double y) {
    final int i = _bandAt(y);
    final List<CytoBand> bands = track.bands;
    final double own = ChromosomeLookSpec.tone(bands[i].stain);
    final double a = yOf(bands[i].start);
    final double b = yOf(bands[i].end + 1);
    if (i > 0 && y < a + _feathers[i]) {
      final double f = _feathers[i];
      final double above = ChromosomeLookSpec.tone(bands[i - 1].stain);
      return above + (own - above) * (y - (a - f)) / (2 * f);
    }
    if (i < bands.length - 1 && y > b - _feathers[i + 1]) {
      final double f = _feathers[i + 1];
      final double below = ChromosomeLookSpec.tone(bands[i + 1].stain);
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

  // The centromere and the telomeres.

  /// How much of the centromere's tint is at [y], from 0 to 1: all of it at
  /// the centromere, none [ChromosomeLookSpec.centromereReach] half-widths
  /// either side of it, and none in the gene's band, which keeps its own.
  double centromereAt(double y) => _nearCentromere(y) * (1 - geneAt(y));

  /// How much of a telomere's tint is at [y], from 0 to 1: all of it at
  /// either end, none [ChromosomeLookSpec.telomereReach] half-widths in
  /// from it, and none in the gene's band. Both sisters end at the same
  /// heights, so every chromatid's two ends are capped.
  double telomereAt(double y) => _nearEnd(y) * (1 - geneAt(y));

  /// [centromereAt] and [telomereAt] with the gene's band left in: the
  /// chromosome's alone, the same for every protein on it.
  double _nearCentromere(double y) =>
      _fall((y - centromere).abs() / (look.centromereReach * half));
  double _nearEnd(double y) =>
      _fall(math.min(y - top, bottom - y) / (look.telomereReach * half));

  /// 1 at [d] 0, falling smoothly to 0 at [d] 1 and beyond.
  static double _fall(double d) {
    final double t = d.clamp(0.0, 1.0);
    return 1 - t * t * (3 - 2 * t);
  }

  /// The rows the body is drawn through, top to bottom: one every so far
  /// along, closer round the waist and the rounded ends, and two at each
  /// band's edge, where its softening begins and ends.
  late final Float64List bodyRows = () {
    final double step = look.rowStep * half;
    final double fine = look.waistRowStep * half;
    final double reach = look.waistRows * half;
    const int round = 16;
    final List<double> rows = <double>[
      for (double y = top; y < bottom; y += step) y,
      bottom,
      for (int i = 1; i < round; i++) ...<double>[
        top + _topCap * (1 - math.cos(math.pi / 2 * i / round)),
        bottom - _cap * (1 - math.cos(math.pi / 2 * i / round)),
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

  // The gene.

  /// The middle of the gene's span.
  double get geneY => yOf((track.spanStart + track.spanEnd + 1) / 2);

  /// The radius of the ring that pings round the gene's place on each
  /// sister: about half a chromatid, whatever the gene's length, and never
  /// wider than the chromatid where it lies.
  double get pingRadius =>
      math.min(look.ping * half, look.pingShare * widthAt(geneY));

  /// The gene's place on chromatid [side], where its chromatin is gathered
  /// round: on its axis, at the gene.
  Offset geneOn(double side, {double merge = 0}) =>
      Offset(centreAt(side, geneY, merge: merge), geneY);

  // The relief.

  /// The knobs on chromatid [side]'s surface: globules on a jittered
  /// lattice and granules strewn between, laid by a seed of the
  /// chromosome's own, so every protein on it has the same.
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
  /// globules are smaller.
  double _zone(double y) {
    double acen = 0;
    final int i = _bandAt(y);
    if (track.bands[i].stain == Stain.acen) {
      acen = 1;
    }
    return math.max(waist(y), acen);
  }

  /// How far a knob at [y] keeps off the middle of the pair, of a
  /// half-width; below 0, how far it may reach across it: none at all down
  /// the arms, where a cleft runs between the sisters, closing to a hair
  /// across at the waist, where they meet.
  double keepOff(double y) {
    const double hair = -0.05;
    final ChromosomeGlobules globules = look.globules;
    return globules.cleftGap + (hair - globules.cleftGap) * waist(y);
  }

  /// How much smaller a globule is drawn at [y], and so how much closer the
  /// lattice of them lies: finer at the centromere, and at the caps.
  double _fineness(double y, ChromosomeGlobules globules) =>
      (1 - look.lobeWaist * _zone(y)) * (1 - globules.capShrink * _nearEnd(y));

  KnobField _lay(double side) {
    final math.Random random = math.Random(_seed(side));
    final ChromosomeGlobules globules = look.globules;
    final List<double> ys = <double>[];
    final List<double> phis = <double>[];
    final List<double> radii = <double>[];
    final List<int> kinds = <int>[];
    // How far a knob of radius [r] at [y], [phi] round the tube, keeps off
    // the middle of the pair: a sphere, whole.
    double room(double y, double phi, double r) {
      final double x =
          centreAt(side, y) + globules.surface * widthAt(y) * math.sin(phi);
      return side * (x - bend(y)) - r;
    }

    // Nothing of one sister crosses the groove onto the other.
    bool clear(double y, double phi, double r) =>
        room(y, phi, r) >= keepOff(y) * half;

    final double mean = (look.lobe + look.lobeSpread / 2) * half;
    final double spacing = look.lobeLattice * mean;
    // A lattice of globules, closer where they are finer, round as far as
    // the rim; [behind], the layer half a cell off the first, of globules
    // [ChromosomeGlobules.back] the size. By the cleft a globule is drawn
    // smaller rather than left out, while it is still half its size.
    void lattice({required bool behind}) {
      final double scale = behind ? globules.back : 1;
      int row = 0;
      double y = top + spacing * (behind ? 0.866 : 0.433);
      while (y < bottom) {
        final double step = spacing * _fineness(y, globules);
        final double w = widthAt(y);
        if (w > 0.25 * half) {
          final double around = math.pi * globules.surface * w;
          final double shift =
              (row.isOdd ? step / 2 : 0) + (behind ? step / 4 : 0);
          for (
            double arc = -around / 2 + shift + step / 2;
            arc < around / 2;
            arc += step
          ) {
            final double ay =
                (y + (random.nextDouble() - 0.5) * 0.5 * step * 0.866).clamp(
                  top,
                  bottom,
                );
            final double aw = globules.surface * widthAt(ay);
            if (aw <= 0) {
              continue;
            }
            final double a = arc + (random.nextDouble() - 0.5) * 0.5 * step;
            final double phi = (a / aw).clamp(-globules.rim, globules.rim);
            final double taper = math.sqrt(
              math.min(1, widthAt(ay) / (0.6 * half)),
            );
            double r =
                half *
                (look.lobe + look.lobeSpread * random.nextDouble()) *
                _fineness(ay, globules) *
                taper *
                scale;
            final double over = keepOff(ay) * half - room(ay, phi, r);
            if (over > 0) {
              if (over > r / 2) {
                continue;
              }
              r -= over;
            }
            ys.add(ay);
            phis.add(phi);
            radii.add(r);
            kinds.add(behind ? KnobField.deep : KnobField.lobe);
          }
        }
        y += step * 0.866;
        row++;
      }
    }

    lattice(behind: false);
    if (globules.back > 0) {
      lattice(behind: true);
    }
    final int granules = (look.granules * length / half).round();
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
        look.granuleFloor,
        half * (look.granule + look.granuleSpread * random.nextDouble()),
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
    // Each knob's own jitters, drawn after everything else is laid: the one
    // its material is picked with, and how much lighter or darker it is.
    // A telomere's where the telomeres' tint, so moved, passes the mark;
    // else the centromere's likewise; else the arms'. The gene's band is
    // not left out, so every protein on the chromosome has the same: the
    // gene's globules are the art's to pick, round its place, the gene being
    // each protein's own.
    final int n = ys.length;
    final Float32List pick = Float32List(n);
    final Float32List lift = Float32List(n);
    final Uint8List material = Uint8List(n);
    for (int k = 0; k < n; k++) {
      pick[k] = random.nextDouble() * 2 - 1;
      lift[k] = random.nextDouble() * 2 - 1;
      final double y = ys[k];
      final double moved = globules.pickJitter * pick[k];
      material[k] =
          (_nearEnd(y) + moved > globules.pickAt
                  ? ChromatinMaterial.telomere
                  : _nearCentromere(y) + moved > globules.pickAt
                  ? ChromatinMaterial.centromere
                  : ChromatinMaterial.body)
              .index;
    }
    return KnobField(
      Float32List.fromList(ys),
      Float32List.fromList(phis),
      Float32List.fromList(radii),
      Uint8List.fromList(kinds),
      pick: pick,
      lift: lift,
      material: material,
    );
  }
}

/// The knobs on one chromatid's surface: where each lies along the
/// chromosome ([y]) and round the tube ([phi], 0 facing out of the screen),
/// its radius, and what it is.
final class KnobField {
  KnobField(
    this.y,
    this.phi,
    this.radius,
    this.kind, {
    required this.pick,
    required this.lift,
    required this.material,
  });

  /// A globule: a knob of chromatin, lit as a sphere.
  static const int lobe = 0;

  /// A granule standing out of the surface, or sunk into it.
  static const int bump = 1;
  static const int pit = 2;

  /// A globule of the layer behind the first, filling between its globules
  /// ([ChromosomeGlobules.back]).
  static const int deep = 3;

  final Float32List y;
  final Float32List phi;
  final Float32List radius;
  final Uint8List kind;

  /// Each knob's own jitters, from -1 to 1: the one its material was picked
  /// with, and how much lighter or darker it is drawn than the next.
  final Float32List pick;
  final Float32List lift;

  /// What each knob is made of, as a [ChromatinMaterial]'s index: the
  /// arms', the centromere's or a telomere's.
  final Uint8List material;

  int get length => y.length;
}
