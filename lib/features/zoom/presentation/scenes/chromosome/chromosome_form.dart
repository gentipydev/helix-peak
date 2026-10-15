import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/locus_track.dart';
import '../../../domain/zoom_depth.dart';
import '../contour.dart';

/// A chromosome at metaphase as a form, from its locus track alone: two
/// sister chromatids, each a tube as thick as a chromatid is, lying side by
/// side and joined at the centromere, their arms splayed a little. Every
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

  /// How far apart the two chromatids' middles lie at the centromere's
  /// height: touching, along a groove.
  double get apart => half * 1.12;

  /// How far each arm splays from its sister, for each unit of length from
  /// the centromere.
  static const double splay = 0.07;

  double yOf(num base) => -length / 2 + (base - 1) / track.length * length;

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

  /// Where chromatid [side]'s middle lies at [y]: touching its sister along
  /// the groove at the centromere, splayed a little toward its ends, and
  /// [merge] of the way onto the axis.
  double centreAt(double side, double y, {double merge = 0}) =>
      side *
      (apart * (1 - 0.7 * waist(y)) + splay * (y - centromere).abs()) *
      (1 - merge);

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
      final double centre = centreAt(1, y);
      final double w = widthAt(y);
      left.add(Offset(-centre - w, y));
      right.add(Offset(centre + w, y));
    }
    return Contour(<Offset>[...right, ...left.reversed]);
  }
}
