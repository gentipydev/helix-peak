import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../tube_course.dart';
import 'eye_anatomy.dart';
import 'eye_style.dart';

/// A coat or a part of the eye the section cuts, as its two edges point for
/// point, in millimetres: [outer], the side toward the outside of the globe
/// (the front, for the iris), and [inner].
final class EyeBand {
  const EyeBand(this.outer, this.inner);

  final List<Offset> outer;
  final List<Offset> inner;

  int get length => outer.length;

  /// The band's outline: along its outer edge and back along its inner.
  List<Offset> get outline => <Offset>[...outer, ...inner.reversed];

  /// How thick the band is at its [i]th point.
  double thicknessAt(int i) => (outer[i] - inner[i]).distance;
}

/// The right eye's horizontal section as the zoom's organ scene draws it,
/// and what lies round it: every shape in the scene's units at the eye's
/// real size, the middle of the globe at the origin, where the body's
/// circle of the eye has its middle. The anatomy is `EyeAnatomy`'s, in
/// millimetres, its origin there too, laid with the cornea up and the
/// temporal side to the right; the scene draws it turned a quarter to the
/// left ([turn]), the cornea to the left and the nerve leaving to the
/// right, the temporal side up.
///
/// The globe's back is an ellipse the sclera follows, as broad as the
/// globe and as long as leaves the cornea's bulge in front of it; the
/// coats lie inside it, each as thick as it is measured where it is, the
/// sclera from the limbus back to the scleral canal, the choroid and the
/// retina from the ora serrata back to the optic disc. Angles round the
/// globe's back are the ellipse's own, from the posterior pole, temporal
/// positive; lengths along a coat are millimetres from the posterior pole.
///
/// The place its tissue is sampled is the retina's middle at the posterior
/// pole ([site]), between the disc and the fovea. Everything here is
/// geometry: what it is drawn in is `EyeArt`'s.
final class EyeForm {
  EyeForm({required double length, required this.view})
    : scale = length / EyeAnatomy.length;

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's millimetres, in the scene's units.
  final double scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => turn(mm) * scale;

  /// A point of the scene, in the anatomy's millimetres.
  Offset toMm(Offset p) => _unturn(p / scale);

  /// [p], a point or a way of the anatomy, turned a quarter to the left,
  /// as the scene draws the eye: its cornea to the left and the nerve
  /// leaving to the right (the user's choice of 2026-10-19).
  static Offset turn(Offset p) => Offset(p.dy, -p.dx);
  static Offset _unturn(Offset p) => Offset(-p.dy, p.dx);

  /// [millimetres] of the real eye, in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// [mm], in the scene.
  List<Offset> placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  // The globe.

  /// Half the cornea's breadth at the limbus, and how far its front bulges
  /// forward of the limbus.
  static const double _half = EyeAnatomy.corneaAcross / 2;
  static final double _bulge =
      EyeAnatomy.corneaRadius -
      math.sqrt(
        EyeAnatomy.corneaRadius * EyeAnatomy.corneaRadius - _half * _half,
      );

  /// The ellipse the sclera's outer face follows: its half-breadth and
  /// half-length, and how far behind the origin its middle lies.
  static const double _a = EyeAnatomy.breadth / 2;
  static final double _k = math.sqrt(1 - (_half / _a) * (_half / _a));
  static final double _b = (EyeAnatomy.length - _bulge) / (1 + _k);
  static final double _cy = EyeAnatomy.length / 2 - _b;

  /// The middle of the circle the cornea's front follows.
  static const Offset corneaMiddle = Offset(
    0,
    EyeAnatomy.corneaRadius - EyeAnatomy.length / 2,
  );

  /// How far round the globe's back from the posterior pole the limbus
  /// lies, on the temporal side; the nasal is its negative.
  static final double limbusAngle = math.pi - math.asin(_half / _a);

  /// How far round the cornea's front from its apex the limbus lies.
  static final double limbusCorneaAngle = math.asin(
    _half / EyeAnatomy.corneaRadius,
  );

  /// The globe's outer face at [angle] round its back.
  static Offset outer(double angle) =>
      Offset(_a * math.sin(angle), _cy + _b * math.cos(angle));

  /// The way out of the globe at [angle] round its back, a unit.
  static Offset outward(double angle) {
    final Offset n = Offset(math.sin(angle) / _a, math.cos(angle) / _b);
    return n / n.distance;
  }

  /// The way from the cornea's middle to its front at [angle] from its
  /// apex, a unit.
  static Offset _corneaWay(double angle) =>
      Offset(math.sin(angle), -math.cos(angle));

  /// How thick the sclera is at [angle]: thickest at the back, by the
  /// nerve, thinnest at the equator, and a little thicker again at the
  /// limbus.
  static double scleraAt(double angle) {
    final double from = angle.abs();
    const double equator = math.pi / 2;
    if (from <= equator) {
      return EyeAnatomy.scleraEquator +
          (EyeAnatomy.scleraNerve - EyeAnatomy.scleraEquator) *
              _smooth(1 - from / equator);
    }
    return EyeAnatomy.scleraEquator +
        (EyeAnatomy.scleraLimbus - EyeAnatomy.scleraEquator) *
            _smooth((from - equator) / (limbusAngle - equator));
  }

  /// The sclera's inner face at [angle].
  static Offset scleraInner(double angle) =>
      outer(angle) - outward(angle) * scleraAt(angle);

  // Lengths along the globe.

  static const int _samples = 7200;

  /// The angles the faces are measured at, evenly round, the posterior pole
  /// at the middle one.
  static final List<double> _angles = <double>[
    for (int i = 0; i <= _samples; i++) -math.pi + 2 * math.pi * i / _samples,
  ];

  /// How far along the outer face, and along the sclera's inner face, from
  /// the posterior pole each of [_angles] lies.
  static final Float64List _outerArcs = _arcsOf(outer);
  static final Float64List _innerArcs = _arcsOf(scleraInner);

  static Float64List _arcsOf(Offset Function(double) at) {
    final Float64List out = Float64List(_samples + 1);
    const int pole = _samples ~/ 2;
    for (int i = pole + 1; i <= _samples; i++) {
      out[i] = out[i - 1] + (at(_angles[i]) - at(_angles[i - 1])).distance;
    }
    for (int i = pole - 1; i >= 0; i--) {
      out[i] = out[i + 1] - (at(_angles[i]) - at(_angles[i + 1])).distance;
    }
    return out;
  }

  /// How far along the outer face from the posterior pole [angle] lies,
  /// and the angle that lies [arc] along it.
  static double outerArcAt(double angle) => _lookup(_angles, _outerArcs, angle);
  static double outerAngleAt(double arc) => _lookup(_outerArcs, _angles, arc);

  /// The same along the sclera's inner face.
  static double innerArcAt(double angle) => _lookup(_angles, _innerArcs, angle);
  static double innerAngleAt(double arc) => _lookup(_innerArcs, _angles, arc);

  /// How far along the outer face from the posterior pole the limbus lies,
  /// temporally; nasally the same.
  static final double limbusArc = outerArcAt(limbusAngle);

  /// The angle [behind] millimetres back along the outer face from the
  /// limbus, on the temporal side for a [side] of 1, the nasal for -1.
  static double behindLimbus(double behind, int side) =>
      outerAngleAt(side * (limbusArc - behind));

  // Landmarks.

  /// Where the optic nerve enters, nasal of the posterior pole.
  static final double nerveAngle = outerAngleAt(-EyeAnatomy.nerveNasal);

  /// How far along the sclera's inner face from the posterior pole the
  /// disc's middle lies, and the fovea's.
  static final double discArc = innerArcAt(nerveAngle);
  static final double foveaArc =
      discArc + EyeAnatomy.disc / 2 + EyeAnatomy.foveaFromDisc;

  /// The disc's margins, where the choroid, the retina and the sclera's
  /// inner face end at the scleral canal: nasal, then temporal.
  static final (double, double) discMargins = (
    innerAngleAt(discArc - EyeAnatomy.disc / 2),
    innerAngleAt(discArc + EyeAnatomy.disc / 2),
  );

  /// The scleral canal's edges on the outer face, as wide as the nerve
  /// behind the globe: nasal, then temporal.
  static final (double, double) canal = (
    outerAngleAt(outerArcAt(nerveAngle) - EyeAnatomy.nerveNearAcross / 2),
    outerAngleAt(outerArcAt(nerveAngle) + EyeAnatomy.nerveNearAcross / 2),
  );

  /// The ora serrata, nasal and temporal, and how far along the sclera's
  /// inner face each lies.
  static final double oraNasal = behindLimbus(EyeAnatomy.oraNasal, -1);
  static final double oraTemporal = behindLimbus(EyeAnatomy.oraTemporal, 1);
  static final double _oraArcNasal = innerArcAt(oraNasal);
  static final double _oraArcTemporal = innerArcAt(oraTemporal);

  /// The scleral spur, where the ciliary body begins, nasal and temporal.
  static final double spurNasal = behindLimbus(EyeAnatomy.ciliaryFrom, -1);
  static final double spurTemporal = behindLimbus(EyeAnatomy.ciliaryFrom, 1);

  /// Where the sclera's inner face meets the cornea's back, on the
  /// temporal side: the angle round the globe's back, and round the
  /// cornea's front from its apex.
  static final double junctionAngle = () {
    const double reach = EyeAnatomy.corneaRadius - EyeAnatomy.corneaEdge;
    double over(double angle) =>
        (scleraInner(angle) - corneaMiddle).distance - reach;
    double low = limbusAngle;
    double high = math.pi;
    for (int i = 0; i < 60; i++) {
      final double middle = (low + high) / 2;
      if (over(middle) > 0) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return (low + high) / 2;
  }();
  static final double junctionCorneaAngle = () {
    final Offset j = scleraInner(junctionAngle) - corneaMiddle;
    return math.atan2(j.dx, -j.dy);
  }();

  // The coats' thicknesses, by how far along the sclera's inner face from
  // the posterior pole.

  /// How thick the cornea is at [angle] from its apex.
  static double corneaAt(double angle) =>
      EyeAnatomy.corneaMiddle +
      (EyeAnatomy.corneaEdge - EyeAnatomy.corneaMiddle) *
          _smooth(angle.abs() / junctionCorneaAngle);

  /// How thick the choroid is [arc] along: thickest under the fovea,
  /// thinning fast toward the nose and slowly toward the temple, to its
  /// thickness at the ora serrata.
  static double choroidAt(double arc) {
    final double d = arc - foveaArc;
    final double width = d >= 0 ? EyeStyle.choroidReach : _choroidNasalReach;
    return EyeStyle.choroidFront +
        (EyeAnatomy.choroidFovea - EyeStyle.choroidFront) *
            math.exp(-(d / width) * (d / width));
  }

  /// How far nasal of the fovea the choroid keeps its thickness: as far as
  /// it is measured as thin as it is [EyeAnatomy.choroidNasalAt] nasal.
  static final double _choroidNasalReach =
      EyeAnatomy.choroidNasalAt /
      math.sqrt(
        math.log(
          (EyeAnatomy.choroidFovea - EyeStyle.choroidFront) /
              (EyeAnatomy.choroidNasal - EyeStyle.choroidFront),
        ),
      );

  /// How thick the retina is [arc] along: thin at the fovea's floor,
  /// thickest at its rim, and thinning from there to the ora serrata on
  /// either side.
  static double retinaAt(double arc) {
    final double d = (arc - foveaArc).abs();
    const double rim = EyeAnatomy.fovea / 2;
    if (d <= rim) {
      return EyeAnatomy.retinaFloor +
          (EyeAnatomy.retinaRim - EyeAnatomy.retinaFloor) * _smooth(d / rim);
    }
    final double ora = arc >= foveaArc
        ? _oraArcTemporal - foveaArc
        : foveaArc - _oraArcNasal;
    final double x = ((d - rim) / (ora - rim)).clamp(0.0, 1.0);
    final double l = EyeStyle.retinaFalloff / (ora - rim);
    final double end = math.exp(-1 / l);
    return EyeAnatomy.retinaOra +
        (EyeAnatomy.retinaRim - EyeAnatomy.retinaOra) *
            (math.exp(-x / l) - end) /
            (1 - end);
  }

  /// The choroid's inner face, where the pigment epithelium lies, at
  /// [angle], and the retina's inner face there.
  static Offset pigmentAt(double angle) =>
      scleraInner(angle) - outward(angle) * choroidAt(innerArcAt(angle));
  static Offset retinaInner(double angle) =>
      pigmentAt(angle) - outward(angle) * retinaAt(innerArcAt(angle));

  // The outline.

  /// The globe's outline, in millimetres: its outer face from the temporal
  /// limbus round the back to the nasal, then the cornea's front over its
  /// apex.
  late final List<Offset> outlineMm = <Offset>[
    for (final double angle in _span(limbusAngle, -limbusAngle)) outer(angle),
    for (final double angle in _cornea(
      -limbusCorneaAngle,
      limbusCorneaAngle,
    ).skip(1).take(_corneaRows - 2))
      corneaMiddle + _corneaWay(angle) * EyeAnatomy.corneaRadius,
  ];

  /// The outline in the scene, and as a path.
  late final List<Offset> outlinePoints = placed(outlineMm);
  late final Path outline = Path()..addPolygon(outlinePoints, true);

  /// Whether [p] lies inside the globe's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  /// Inside the globe, where the vitreous and the chambers are: within the
  /// sclera's inner face and the cornea's back.
  late final List<Offset> interiorMm = <Offset>[
    for (final double angle in _span(junctionAngle, -junctionAngle))
      scleraInner(angle),
    for (final double angle in _cornea(
      -junctionCorneaAngle,
      junctionCorneaAngle,
    ).skip(1).take(_corneaRows - 2))
      corneaMiddle +
          _corneaWay(angle) * (EyeAnatomy.corneaRadius - corneaAt(angle)),
  ];
  late final Path interior = Path()..addPolygon(placed(interiorMm), true);

  // The coats.

  /// The sclera, temporal then nasal: each from the limbus back to the
  /// scleral canal, its outer face to the canal's outer edge and its inner
  /// face from where it meets the cornea to the disc's margin.
  late final List<EyeBand> sclera = <EyeBand>[
    _band(
      (limbusAngle, canal.$2),
      (junctionAngle, discMargins.$2),
      outer,
      scleraInner,
    ),
    _band(
      (-limbusAngle, canal.$1),
      (-junctionAngle, discMargins.$1),
      outer,
      scleraInner,
    ),
  ];

  /// The choroid, temporal then nasal: from the ora serrata back to the
  /// disc's margin, its outer face the sclera's inner.
  late final List<EyeBand> choroid = <EyeBand>[
    _band(
      (oraTemporal, discMargins.$2),
      (oraTemporal, discMargins.$2),
      scleraInner,
      pigmentAt,
    ),
    _band(
      (oraNasal, discMargins.$1),
      (oraNasal, discMargins.$1),
      scleraInner,
      pigmentAt,
    ),
  ];

  /// The retina, temporal then nasal: from the ora serrata back to the
  /// disc's margin, on the pigment epithelium.
  late final List<EyeBand> retina = <EyeBand>[
    _band(
      (oraTemporal, discMargins.$2),
      (oraTemporal, discMargins.$2),
      pigmentAt,
      retinaInner,
    ),
    _band(
      (oraNasal, discMargins.$1),
      (oraNasal, discMargins.$1),
      pigmentAt,
      retinaInner,
    ),
  ];

  /// The cornea: its front from the nasal limbus over its apex to the
  /// temporal, its back from where it meets the sclera on one side to the
  /// other.
  late final EyeBand cornea = () {
    final List<double> front = _cornea(-limbusCorneaAngle, limbusCorneaAngle);
    final List<double> back = _cornea(
      -junctionCorneaAngle,
      junctionCorneaAngle,
    );
    return EyeBand(
      <Offset>[
        for (final double angle in front)
          corneaMiddle + _corneaWay(angle) * EyeAnatomy.corneaRadius,
      ],
      <Offset>[
        for (final double angle in back)
          corneaMiddle +
              _corneaWay(angle) * (EyeAnatomy.corneaRadius - corneaAt(angle)),
      ],
    );
  }();

  // The ciliary body, the iris and the lens.

  /// The ciliary body, temporal then nasal: on the sclera's inner face from
  /// the scleral spur back to the ora serrata, thickest at its front face,
  /// its processes standing up over its pars plicata.
  late final List<EyeBand> ciliary = <EyeBand>[
    _ciliaryBody(spurTemporal, oraTemporal),
    _ciliaryBody(spurNasal, oraNasal),
  ];

  EyeBand _ciliaryBody(double spur, double ora) {
    final double length = (innerArcAt(ora) - innerArcAt(spur)).abs();
    final double plicata = EyeAnatomy.plicata / length;
    final List<double> angles = _span(spur, ora);
    final int n = angles.length;
    return EyeBand(
      <Offset>[for (final double angle in angles) scleraInner(angle)],
      <Offset>[
        for (int i = 0; i < n; i++)
          scleraInner(angles[i]) -
              outward(angles[i]) * ciliaryAt(i / (n - 1), plicata),
      ],
    );
  }

  /// How thick the ciliary body is [t] of the way from its front face to
  /// the ora serrata, its pars plicata the first [plicata] of it.
  static double ciliaryAt(double t, double plicata) {
    if (t <= plicata) {
      final double u = t / plicata;
      final double process = math.sin(math.pi * EyeStyle.processesCut * u);
      return EyeStyle.ciliaryFront +
          (EyeStyle.plicataEnd - EyeStyle.ciliaryFront) * _smooth(u) +
          EyeStyle.processRise * process * process;
    }
    final double u = (t - plicata) / (1 - plicata);
    return EyeStyle.plana +
        (EyeStyle.plicataEnd - EyeStyle.plana) * (1 - _smooth(4 * u));
  }

  /// The ciliary muscle, temporal then nasal: in the ciliary body's outer
  /// part, against the sclera, from the spur back as broad as it is,
  /// thinning to nothing.
  late final List<EyeBand> muscles = <EyeBand>[
    _muscle(spurTemporal, 1),
    _muscle(spurNasal, -1),
  ];

  EyeBand _muscle(double spur, int side) {
    final double end = innerAngleAt(
      innerArcAt(spur) - side * EyeAnatomy.ciliaryMuscle,
    );
    final List<double> angles = _span(spur, end);
    final int n = angles.length;
    return EyeBand(
      <Offset>[for (final double angle in angles) scleraInner(angle)],
      <Offset>[
        for (int i = 0; i < n; i++)
          scleraInner(angles[i]) -
              outward(angles[i]) *
                  (EyeStyle.muscle * math.pow(1 - i / (n - 1), 1.4).toDouble()),
      ],
    );
  }

  /// The lens's front and back poles, and its equator's middle: its front
  /// [EyeAnatomy.chamber] behind the cornea's back.
  static const double lensFront =
      EyeAnatomy.corneaMiddle + EyeAnatomy.chamber - EyeAnatomy.length / 2;
  static const double lensBack = lensFront + EyeAnatomy.lensThick;
  static const double _lensFrontHalf =
      EyeAnatomy.lensThick / (1 + EyeAnatomy.lensFlatter);
  static const double _lensBackHalf = EyeAnatomy.lensThick - _lensFrontHalf;
  static const double lensEquator = lensFront + _lensFrontHalf;
  static const double _lensHalf = EyeAnatomy.lensAcross / 2;

  /// The lens's outline at [t] round it from its front pole, temporal
  /// first, [share] of its size about its equator's middle: two halves of
  /// ellipses, the front the flatter.
  static Offset lensAt(double t, {double share = 1}) {
    final double c = math.cos(t);
    return Offset(
      _lensHalf * math.sin(t) * share,
      lensEquator - (c >= 0 ? _lensFrontHalf : _lensBackHalf) * c * share,
    );
  }

  /// How far forward the lens's front lies [x] from its axis.
  static double lensFrontAt(double x) {
    final double u = (x / _lensHalf).clamp(-1.0, 1.0);
    return lensEquator - _lensFrontHalf * math.sqrt(1 - u * u);
  }

  /// The lens's outline and its nucleus's, in millimetres, and the middle
  /// they are drawn about.
  late final List<Offset> lensMm = _lensOutline(1);
  late final List<Offset> nucleusMm = _lensOutline(EyeStyle.nucleus);
  static const Offset lensMiddle = Offset(0, lensEquator);

  static List<Offset> _lensOutline(double share) => <Offset>[
    for (int i = 0; i < EyeStyle.lensPoints; i++)
      lensAt(2 * math.pi * i / EyeStyle.lensPoints, share: share),
  ];

  /// The iris, temporal then nasal: its front and its back, from its root
  /// on the ciliary body's front face to the pupil's margin, which rests on
  /// the lens; bowed a little forward.
  late final List<EyeBand> iris = <EyeBand>[_iris(1), _iris(-1)];

  EyeBand _iris(int side) {
    final double spur = side > 0 ? spurTemporal : spurNasal;
    final Offset root =
        scleraInner(spur) - outward(spur) * (EyeStyle.ciliaryFront / 2);
    final double x = side * EyeAnatomy.pupil / 2;
    final Offset margin = Offset(x, lensFrontAt(x) - EyeStyle.irisMargin / 2);
    final Offset bow =
        (root + margin) / 2 + const Offset(0, -2 * EyeStyle.irisBow);
    const int n = 48;
    final List<Offset> middle = <Offset>[
      for (int i = 0; i <= n; i++)
        () {
          final double t = i / n;
          final double u = 1 - t;
          return root * (u * u) + bow * (2 * u * t) + margin * (t * t);
        }(),
    ];
    double long = 0;
    for (int i = 1; i <= n; i++) {
      long += (middle[i] - middle[i - 1]).distance;
    }
    final double collarette = 1 - EyeStyle.collarette / long;
    double thickness(double t) => t <= collarette
        ? EyeAnatomy.irisRoot +
              (EyeAnatomy.irisMost - EyeAnatomy.irisRoot) *
                  _smooth(t / collarette)
        : EyeAnatomy.irisMost +
              (EyeStyle.irisMargin - EyeAnatomy.irisMost) *
                  _smooth((t - collarette) / (1 - collarette));
    final List<Offset> front = <Offset>[];
    final List<Offset> back = <Offset>[];
    for (int i = 0; i <= n; i++) {
      final Offset way =
          middle[math.min(n, i + 1)] - middle[math.max(0, i - 1)];
      Offset forward = Offset(-way.dy, way.dx) / way.distance;
      if (forward.dy > 0) {
        forward = -forward;
      }
      final double half = thickness(i / n) / 2;
      front.add(middle[i] + forward * half);
      back.add(middle[i] - forward * half);
    }
    return EyeBand(front, back);
  }

  /// The zonular fibres, temporal then nasal, each from the ciliary body's
  /// inner face to the lens's equator: those from further back to its
  /// front, those from further forward behind it, so that they cross.
  late final List<(Offset, Offset)> zonules = <(Offset, Offset)>[
    for (final (EyeBand body, double side) in <(EyeBand, double)>[
      (ciliary[0], 1),
      (ciliary[1], -1),
    ])
      for (int k = 0; k < EyeStyle.zonules; k++)
        () {
          final double f = k / (EyeStyle.zonules - 1);
          final int at = ((0.06 + 0.5 * f) * (body.length - 1)).round();
          final Offset lens = lensAt(math.pi / 2 + 0.32 - 0.64 * f);
          return (body.inner[at], Offset(side * lens.dx, lens.dy));
        }(),
  ];

  /// Schlemm's canal, temporal then nasal: where it lies in the sclera at
  /// the limbus, and the way along the sclera there.
  late final List<(Offset, Offset)> schlemm = <(Offset, Offset)>[
    for (final int side in const <int>[1, -1])
      () {
        final double angle = behindLimbus(EyeStyle.schlemmAt, side);
        final Offset out = outward(angle);
        return (
          outer(angle) - out * (scleraAt(angle) - EyeStyle.schlemmIn),
          Offset(-out.dy, out.dx),
        );
      }(),
  ];

  // The optic nerve.

  /// Where the nerve leaves the globe, and the way it leaves it.
  static final Offset _exit = outer(nerveAngle);
  static final Offset _leaving = outward(nerveAngle);

  /// The way toward the orbit's apex, nasal of straight back.
  static final Offset _ahead = Offset(
    -math.sin(EyeStyle.heading),
    math.cos(EyeStyle.heading),
  );

  static const double _axisStep = 0.25;

  /// The nerve's middle behind the globe, a point every [_axisStep]
  /// millimetres from where it leaves it: turning from the way it leaves
  /// toward the apex, and waving a little either side of that way, as it
  /// runs slack.
  static final List<Offset> axis = () {
    final Offset across = Offset(-_ahead.dy, _ahead.dx);
    final List<Offset> out = <Offset>[_exit];
    Offset p = _exit;
    final int n = (EyeStyle.nerveShown / _axisStep).round();
    for (int i = 1; i <= n; i++) {
      final double d = i * _axisStep;
      final double turn = _smooth(d / 4);
      Offset way = _leaving * (1 - turn) + _ahead * turn;
      way = way / way.distance;
      p += way * _axisStep;
      final double wave =
          EyeStyle.nerveWave * math.sin(2 * math.pi * d / 10) * _smooth(d / 3);
      out.add(p + across * wave);
    }
    return out;
  }();

  /// The nerve's middle [behind] millimetres behind the globe.
  static Offset axisAt(double behind) =>
      axis[(behind / _axisStep).round().clamp(0, axis.length - 1)];

  /// The disc's face, where the nerve meets the vitreous: as far in as the
  /// retina's inner face at the disc's margins.
  static final Offset discFace = () {
    final double margin =
        (choroidAt(discArc - EyeAnatomy.disc / 2) +
            retinaAt(discArc - EyeAnatomy.disc / 2) +
            choroidAt(discArc + EyeAnatomy.disc / 2) +
            retinaAt(discArc + EyeAnatomy.disc / 2)) /
        2;
    return scleraInner(nerveAngle) - _leaving * margin;
  }();

  /// How wide the nerve is [behind] millimetres behind the globe, and its
  /// sheath.
  static double nerveAcrossAt(double behind) =>
      _between(behind, EyeAnatomy.nerveNearAcross, EyeAnatomy.nerveFarAcross);
  static double sheathAcrossAt(double behind) => behind < EyeAnatomy.nerveNear
      ? EyeStyle.sheathFlare +
            (EyeAnatomy.sheathNearAcross - EyeStyle.sheathFlare) *
                _smooth(behind / EyeAnatomy.nerveNear)
      : _between(
          behind,
          EyeAnatomy.sheathNearAcross,
          EyeAnatomy.sheathFarAcross,
        );

  static double _between(double behind, double near, double far) =>
      near +
      (far - near) *
          ((behind - EyeAnatomy.nerveNear) /
                  (EyeAnatomy.nerveFar - EyeAnatomy.nerveNear))
              .clamp(0.0, 1.0);

  /// How far apart the nerve's knots lie behind the globe.
  static const double _knot = 2;

  static List<double> get _knots => <double>[
    for (double d = 0; d <= EyeStyle.nerveShown + 1e-9; d += _knot) d,
  ];

  /// The optic nerve: from the disc's face through the lamina cribrosa and
  /// the scleral canal, widening as it leaves the globe, and on behind it,
  /// fading out.
  static final AnatomyTube nerveTube = AnatomyTube(
    <Offset>[
      discFace,
      scleraInner(nerveAngle),
      for (final double d in _knots) axisAt(d),
    ],
    <double>[
      EyeAnatomy.disc / 2,
      EyeAnatomy.disc / 2,
      for (final double d in _knots) nerveAcrossAt(d) / 2,
    ],
    fadeOut: EyeStyle.nerveFade,
  );

  /// Its sheath: from under the sclera, where it flares into it, on behind
  /// the globe round the nerve, fading out with it.
  static final AnatomyTube sheathTube = AnatomyTube(
    <Offset>[
      _exit - _leaving * EyeStyle.dura,
      for (final double d in _knots) axisAt(d),
    ],
    <double>[
      EyeStyle.sheathFlare / 2,
      for (final double d in _knots) sheathAcrossAt(d) / 2,
    ],
    fadeOut: EyeStyle.nerveFade,
  );

  /// The central retinal artery and vein, the artery the nasal: from where
  /// they come into the nerve, up out of nothing, along its middle to the
  /// disc's face; where that lies past the nerve as it is drawn, from its
  /// end, fading with it.
  static final List<AnatomyTube> centralTubes = <AnatomyTube>[
    for (final (double side, double across) in <(double, double)>[
      (-1, EyeStyle.centralArtery),
      (1, EyeStyle.centralVein),
    ])
      () {
        // To the right of the way toward the globe is the temporal side.
        Offset beside(Offset p, Offset way) =>
            p +
            Offset(-way.dy, way.dx) /
                way.distance *
                (side * EyeStyle.centralApart);
        final List<Offset> points = <Offset>[
          for (double d = _vesselsFrom; d > 1e-9; d -= _knot)
            beside(axisAt(d), axisAt(d - _axisStep) - axisAt(d)),
          beside(_exit, -_leaving),
          beside(scleraInner(nerveAngle), -_leaving),
          beside(discFace, -_leaving),
        ];
        return AnatomyTube(
          points,
          <double>[for (final Offset _ in points) across / 2],
          fadeIn: _vesselsFrom < EyeAnatomy.vesselsJoin
              ? EyeStyle.nerveFade
              : EyeStyle.centralFade,
        );
      }(),
  ];

  /// How far behind the globe the central vessels are drawn from.
  static const double _vesselsFrom =
      EyeAnatomy.vesselsJoin < EyeStyle.nerveShown
      ? EyeAnatomy.vesselsJoin
      : EyeStyle.nerveShown;

  /// The long posterior ciliary arteries, nasal then temporal: up out of
  /// nothing beside the sheath, through the sclera to either side of the
  /// nerve, and forward between the sclera and the choroid to the ciliary
  /// body, where they fade.
  static final List<AnatomyTube> ciliaryArteryTubes = <AnatomyTube>[
    for (final int side in const <int>[-1, 1])
      () {
        final double entry = outerAngleAt(
          outerArcAt(nerveAngle) + side * EyeAnatomy.ciliaryArteries,
        );
        final double inside = outerAngleAt(outerArcAt(entry) + side * 0.8);
        final double spur = side > 0 ? spurTemporal : spurNasal;
        const double from = EyeStyle.ciliaryArteryFrom;
        final Offset back = axisAt(from);
        final Offset way = axisAt(from - _axisStep) - back;
        final Offset across = Offset(-way.dy, way.dx) / way.distance;
        // Which side of the nerve faces the entry.
        final double facing =
            (outer(entry) - back).dx * across.dx +
                    (outer(entry) - back).dy * across.dy >
                0
            ? 1
            : -1;
        final double beside =
            sheathAcrossAt(from) / 2 + EyeStyle.ciliaryArteryBeside;
        final List<Offset> points = <Offset>[
          back + across * (facing * beside),
          outer(entry) + outward(entry) * 1.5,
          outer(entry),
          scleraInner(inside),
          for (final double angle in _span(
            innerAngleAt(innerArcAt(inside) + side * 2),
            spur,
            step: 2,
          ))
            scleraInner(angle),
        ];
        return AnatomyTube(
          points,
          <double>[for (final Offset _ in points) EyeStyle.ciliaryArtery / 2],
          fadeIn: EyeStyle.ciliaryArteryFade,
          fadeOut: EyeStyle.ciliaryArteryFade,
        );
      }(),
  ];

  /// The lamina cribrosa, fine lines across the scleral canal, each from
  /// its nasal wall to its temporal [EyeStyle.lamina] of the way out
  /// through the sclera from its inner face.
  late final List<(Offset, Offset)> lamina = <(Offset, Offset)>[
    for (final double f in EyeStyle.lamina)
      (
        Offset.lerp(scleraInner(discMargins.$1), outer(canal.$1), f)!,
        Offset.lerp(scleraInner(discMargins.$2), outer(canal.$2), f)!,
      ),
  ];

  /// The disc's cup, a hollow in its face: its outline, in millimetres.
  late final List<Offset> cupMm = () {
    final Offset across = Offset(-_leaving.dy, _leaving.dx);
    const int n = 24;
    return <Offset>[
      for (int i = 0; i <= n; i++)
        () {
          final double s = math.pi * i / n;
          return discFace +
              across * (EyeStyle.cup / 2 * math.cos(s)) +
              _leaving * (EyeStyle.cupDeep * math.sin(s));
        }(),
    ];
  }();

  // The recti.

  /// The lateral rectus and the medial: each from its insertion behind the
  /// limbus, its tendon lying on the sclera and thickening into its belly
  /// round the globe to where it leaves it for the orbit's apex, then on
  /// toward the apex, fading out.
  static final List<AnatomyTube> rectusTubes = <AnatomyTube>[
    _rectus(1),
    _rectus(-1),
  ];

  static AnatomyTube _rectus(int side) {
    final double insertion = behindLimbus(
      side > 0 ? EyeAnatomy.lateralInsertion : EyeAnatomy.medialInsertion,
      side,
    );
    final double belly =
        (side > 0 ? EyeAnatomy.lateralBelly : EyeAnatomy.medialBelly) / 2;
    const double tendon = EyeStyle.tendon / 2;
    double radiusAt(double run) =>
        tendon + (belly - tendon) * _smooth(run / EyeStyle.belly);
    final Offset apex = _exit + _ahead * EyeStyle.apex;
    final double from = outerArcAt(insertion);
    Offset middle(double angle) =>
        outer(angle) +
        outward(angle) * radiusAt((outerArcAt(angle) - from).abs());
    // Where it leaves the globe: the way to the apex runs along the globe
    // there.
    double toward(double angle) {
      final Offset to = apex - middle(angle);
      final Offset out = outward(angle);
      return to.dx * out.dx + to.dy * out.dy;
    }

    double low = insertion;
    double high = 0;
    for (int i = 0; i < 60; i++) {
      final double m = (low + high) / 2;
      if (toward(m) < 0) {
        low = m;
      } else {
        high = m;
      }
    }
    final double leaves = (low + high) / 2;
    final double to = outerArcAt(leaves);
    final int wrap = math.max(2, ((to - from).abs() / 1.0).ceil() + 1);
    final List<Offset> points = <Offset>[];
    final List<double> radii = <double>[];
    for (int k = 0; k < wrap; k++) {
      final double arc = from + (to - from) * k / (wrap - 1);
      points.add(middle(outerAngleAt(arc)));
      radii.add(radiusAt((arc - from).abs()));
    }
    final Offset start = points.last;
    final Offset way = (apex - start) / (apex - start).distance;
    final double run = (to - from).abs();
    for (double d = 2; d <= EyeStyle.rectusShown + 1e-9; d += 2) {
      points.add(start + way * d);
      radii.add(radiusAt(run + d));
    }
    return AnatomyTube(points, radii, fadeOut: EyeStyle.rectusFade);
  }

  // The tubes, laid in the scene.

  /// A tube of the anatomy laid in the scene.
  TubeCourse tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(EyeStyle.tubeRow), bend: EyeStyle.bend);

  late final TubeCourse nerve = tube(nerveTube);
  late final TubeCourse sheath = tube(sheathTube);
  late final List<TubeCourse> central = <TubeCourse>[
    for (final AnatomyTube t in centralTubes) tube(t),
  ];
  late final List<TubeCourse> ciliaryArteries = <TubeCourse>[
    for (final AnatomyTube t in ciliaryArteryTubes) tube(t),
  ];
  late final List<TubeCourse> recti = <TubeCourse>[
    for (final AnatomyTube t in rectusTubes) tube(t),
  ];

  // Landmarks, and where they are named.

  /// The fovea's middle and the disc's, on the pigment epithelium and on
  /// the sclera's inner face.
  static final Offset fovea = pigmentAt(innerAngleAt(foveaArc));
  static final Offset disc = scleraInner(nerveAngle);

  /// Where the tissue is sampled: the retina's middle at the posterior
  /// pole, in millimetres and in the scene.
  static final Offset siteMm = (pigmentAt(0) + retinaInner(0)) / 2;
  late final Offset site = place(siteMm);

  /// Where the cornea, the lens and the optic nerve are named.
  late final Offset corneaName = place(
    const Offset(0, (EyeAnatomy.corneaMiddle - EyeAnatomy.length) / 2),
  );
  late final Offset lensName = place(
    const Offset(0, (lensFront + lensBack) / 2),
  );
  late final Offset nerveName = place(axisAt(5));

  // Helpers.

  static const int _corneaRows = 96;

  /// [_corneaRows] angles round the cornea's front from [from] to [to].
  static List<double> _cornea(double from, double to) => <double>[
    for (int i = 0; i < _corneaRows; i++)
      from + (to - from) * i / (_corneaRows - 1),
  ];

  /// Angles from [from] to [to] round the globe's back at most [step]
  /// millimetres apart along its outer face, both ends included.
  static List<double> _span(
    double from,
    double to, {
    double step = EyeStyle.step,
  }) {
    final double length = (outerArcAt(to) - outerArcAt(from)).abs();
    final int n = math.max(2, (length / step).ceil() + 1);
    return <double>[
      for (int i = 0; i < n; i++) from + (to - from) * i / (n - 1),
    ];
  }

  /// A band between two faces of the globe's back: its outer edge on
  /// [outerFace] over the angles [outerSpan], its inner on [innerFace] over
  /// [innerSpan], point for point.
  static EyeBand _band(
    (double, double) outerSpan,
    (double, double) innerSpan,
    Offset Function(double) outerFace,
    Offset Function(double) innerFace,
  ) {
    final int n = _span(outerSpan.$1, outerSpan.$2).length;
    double at((double, double) span, int i) =>
        span.$1 + (span.$2 - span.$1) * i / (n - 1);
    return EyeBand(
      <Offset>[for (int i = 0; i < n; i++) outerFace(at(outerSpan, i))],
      <Offset>[for (int i = 0; i < n; i++) innerFace(at(innerSpan, i))],
    );
  }

  /// [ys] at [x] along [xs], which rise.
  static double _lookup(List<double> xs, List<double> ys, double x) {
    int low = 0;
    int high = xs.length - 1;
    if (x <= xs[low]) {
      return ys[low];
    }
    if (x >= xs[high]) {
      return ys[high];
    }
    while (high - low > 1) {
      final int middle = (low + high) >> 1;
      if (xs[middle] <= x) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final double t = (x - xs[low]) / (xs[high] - xs[low]);
    return ys[low] + (ys[high] - ys[low]) * t;
  }
}

/// Whether [p] lies inside the closed outline [points].
bool _inside(List<Offset> points, Offset p) {
  bool inside = false;
  final int n = points.length;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final Offset a = points[i];
    final Offset b = points[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
