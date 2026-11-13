import 'dart:math' as math;
import 'dart:ui';

import '../../contour.dart';
import '../../tube_course.dart';
import 'aorta_anatomy.dart';
import 'aorta_style.dart';

/// Which of an artery's coats the zoom's cell lives in, by the Atlas's name
/// for it, and the word the stop names it by.
enum AortaHome {
  /// The intima: a vascular endothelial cell.
  intima('intima'),

  /// The media: a vascular smooth muscle cell, and any other.
  media('media'),

  /// The adventitia, where the vasa vasorum run: a pericyte.
  adventitia('adventitia');

  const AortaHome(this.word);

  final String word;

  /// Where a cell the Atlas calls [cell] lives: the media unless the name
  /// says otherwise.
  static AortaHome of(String? cell) {
    final String name = cell?.toLowerCase() ?? '';
    if (name.contains('endothelial')) {
      return intima;
    }
    if (name.contains('pericyte')) {
      return adventitia;
    }
    return media;
  }
}

/// The aorta as the zoom's organ scene draws it: a length of the descending
/// thoracic aorta on its vertebrae, every part in the scene's units at its
/// real size, the middle of what is drawn at the origin.
///
/// The body draws its blood vessels as one tree, the aorta down the
/// middle of the trunk, so the step from it is a crossfade, as the lymph
/// node's is, onto the place the body goes in, in the aorta's thoracic
/// part. Where the zoom's cell lives is [home], one of the wall's three
/// coats. Everything here is geometry: what it is drawn in is
/// `AortaArt`'s.
final class AortaForm {
  AortaForm({
    required double length,
    required this.view,
    this.home = AortaHome.media,
  }) : scale = length / AortaAnatomy.length {
    aorta = _tube(AortaAnatomy.aorta);
    outlinePoints = <Offset>[
      for (int i = 0; i < aorta.length; i++) aorta.at(i, 1),
      for (int i = aorta.length - 1; i >= 0; i--) aorta.at(i, -1),
    ];
    outline = Path()..addPolygon(outlinePoints, true);
    box = _bounds(outlinePoints);
  }

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Which coat the zoom's cell lives in.
  final AortaHome home;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => (mm - const Offset(AortaStyle.middleX, 0)) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => p / scale + const Offset(AortaStyle.middleX, 0);

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(AortaStyle.edgeStep), bend: 0.9);

  /// The aorta laid along its course, and its outline, the points it is
  /// followed by and its box.
  late final TubeCourse aorta;
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// Whether [p] lies on the aorta.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The aorta in millimetres.

  static final TubeCourse _aortaMm = TubeCourse(
    AortaAnatomy.aorta,
    (Offset p) => p,
    1,
    AortaStyle.edgeStep,
    bend: 0.9,
  );

  /// Where the aorta's middle lies at [y], and how wide it is there, in
  /// millimetres.
  static double centreAt(double y) =>
      _rowAt(y, (int i) => _aortaMm.centres[i].dx);
  static double radiusAt(double y) => _rowAt(y, (int i) => _aortaMm.radius[i]);

  static double _rowAt(double y, double Function(int) value) {
    final List<Offset> c = _aortaMm.centres;
    if (y <= c.first.dy) {
      return value(0);
    }
    for (int i = 1; i < c.length; i++) {
      if (c[i].dy >= y) {
        final double t = (y - c[i - 1].dy) / (c[i].dy - c[i - 1].dy);
        return value(i - 1) + (value(i) - value(i - 1)) * t;
      }
    }
    return value(c.length - 1);
  }

  /// A window on the aorta's front, [wide] across and [high] along either
  /// side of its middle, its corners as square as [AortaAnatomy.windowSquare]
  /// makes them, following the aorta's middle as it leans.
  static List<Offset> _window(double wide, double high) {
    const int n = 160;
    const double p = AortaAnatomy.windowSquare;
    return <Offset>[
      for (int k = 0; k < n; k++)
        () {
          final double a = 2 * math.pi * k / n;
          final double c = math.cos(a);
          final double s = math.sin(a);
          final double dx = wide * c.sign * math.pow(c.abs(), 2 / p);
          final double dy = high * s.sign * math.pow(s.abs(), 2 / p);
          final double y = AortaAnatomy.windowAt + dy;
          return Offset(centreAt(y) + dx, y);
        }(),
    ];
  }

  static final List<Offset> _outerMm = _window(
    AortaAnatomy.outerWide,
    AortaAnatomy.outerHigh,
  );
  static final List<Offset> _innerMm = _window(
    AortaAnatomy.innerWide,
    AortaAnatomy.innerHigh,
  );

  /// The windows in millimetres. For tests.
  static List<Offset> get outerMm => _outerMm;
  static List<Offset> get innerMm => _innerMm;

  /// Whether [mm] lies in the media bared round the inner window, or in
  /// the inner window, or on the adventitia outside the outer window.
  static bool inMedia(Offset mm) =>
      _inside(_outerMm, mm) && !_inside(_innerMm, mm);
  static bool inInner(Offset mm) => _inside(_innerMm, mm);
  static bool onAdventitia(Offset mm) =>
      (mm.dx - centreAt(mm.dy)).abs() < radiusAt(mm.dy) &&
      !_inside(_outerMm, mm);

  /// The media's lamellae, level across the bared media.
  static final List<List<Offset>> _lamellaeMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    const double top = AortaAnatomy.windowAt - AortaAnatomy.outerHigh;
    const double bottom = AortaAnatomy.windowAt + AortaAnatomy.outerHigh;
    int k = 0;
    for (
      double y = top + AortaAnatomy.lamellaApart / 2;
      y < bottom;
      y += AortaAnatomy.lamellaApart
    ) {
      final double c = centreAt(y);
      const double reach = AortaAnatomy.outerWide;
      const int steps = 24;
      final double phase = k++ * 1.7;
      out.add(<Offset>[
        for (int i = 0; i <= steps; i++)
          () {
            final double x = -reach + 2 * reach * i / steps;
            return Offset(c + x, y + 0.08 * math.sin(x * 0.9 + phase));
          }(),
      ]);
    }
    return out;
  }();

  /// The openings of the pair of intercostal arteries on the back wall.
  static final List<Offset> _ostiaMm = () {
    const double y = AortaAnatomy.windowAt + AortaAnatomy.ostiaDown;
    final double c = centreAt(y);
    return <Offset>[
      Offset(c - AortaAnatomy.ostiaApart, y),
      Offset(c + AortaAnatomy.ostiaApart, y),
    ];
  }();

  /// The ostia in millimetres. For tests.
  static List<Offset> get ostiaMm => _ostiaMm;

  /// The vasa vasorum, each wandering along the aorta's front.
  static final List<List<Offset>> _vasaMm = () {
    final math.Random random = math.Random(AortaStyle.seed);
    final List<List<Offset>> out = <List<Offset>>[];
    for (int k = 0; k < AortaAnatomy.vasa; k++) {
      final double y0 =
          -58 + 116 * (k + random.nextDouble()) / AortaAnatomy.vasa;
      final double across = (random.nextDouble() * 2 - 1) * 0.75;
      final double phase = random.nextDouble() * 2 * math.pi;
      const int steps = 40;
      out.add(<Offset>[
        for (int i = 0; i <= steps; i++)
          () {
            final double y =
                (y0 -
                        AortaAnatomy.vasumRun / 2 +
                        AortaAnatomy.vasumRun * i / steps)
                    .clamp(-60.0, 60.0);
            final double r = radiusAt(y);
            final double u = (across + 0.12 * math.sin(y / 3.1 + phase)).clamp(
              -0.9,
              0.9,
            );
            return Offset(centreAt(y) + u * r, y);
          }(),
      ]);
    }
    return out;
  }();

  // The column.

  /// A vertebral body, round its middle at [y].
  static List<Offset> _body(double y) {
    const double w = AortaAnatomy.bodyWide;
    const double h = AortaAnatomy.bodyHigh;
    const double r = AortaAnatomy.bodyCorner;
    const double waist = AortaAnatomy.bodyWaist;
    return Contour(<Offset>[
      Offset(-w + r, y - h),
      Offset(-w, y - h + r),
      Offset(-waist, y),
      Offset(-w, y + h - r),
      Offset(-w + r, y + h),
      Offset(w - r, y + h),
      Offset(w, y + h - r),
      Offset(waist, y),
      Offset(w, y - h + r),
      Offset(w - r, y - h),
    ]).sampled(6).points;
  }

  /// A disc between [top] and [bottom], bulging a little at its sides.
  static List<Offset> _disc(double top, double bottom) {
    const double w = AortaAnatomy.discWide;
    final double mid = (top + bottom) / 2;
    return Contour(<Offset>[
      Offset(-w + 1, top),
      Offset(-w - 0.4, mid),
      Offset(-w + 1, bottom),
      Offset(w - 1, bottom),
      Offset(w + 0.4, mid),
      Offset(w - 1, top),
    ]).sampled(6).points;
  }

  static final List<List<Offset>> _bodiesMm = <List<Offset>>[
    for (final double y in AortaAnatomy.bodies) _body(y),
  ];
  static final List<List<Offset>> _discsMm = () {
    const double h = AortaAnatomy.bodyHigh;
    const List<double> b = AortaAnatomy.bodies;
    const double apart = 27;
    return <List<Offset>>[
      _disc(b.first - apart + h, b.first - h),
      for (int i = 0; i + 1 < b.length; i++) _disc(b[i] + h, b[i + 1] - h),
      _disc(b.last + h, b.last + apart - h),
    ];
  }();

  /// How much of the column shows at [y]: all of it near the middle,
  /// fading out above and below.
  static double columnShown(double y) =>
      1 -
      _smooth(
        (y.abs() - AortaAnatomy.columnFrom) /
            (AortaAnatomy.columnTo - AortaAnatomy.columnFrom),
      );

  // The parts, laid in the scene.

  /// The windows, the lamellae, the ostia and the vasa vasorum.
  late final List<Offset> outer = _placed(_outerMm);
  late final List<Offset> inner = _placed(_innerMm);
  late final List<List<Offset>> lamellae = <List<Offset>>[
    for (final List<Offset> l in _lamellaeMm) _placed(l),
  ];
  late final List<Offset> ostia = _placed(_ostiaMm);
  late final List<List<Offset>> vasa = <List<Offset>>[
    for (final List<Offset> v in _vasaMm) _placed(v),
  ];

  /// The vertebral bodies and the discs.
  late final List<List<Offset>> bodies = <List<Offset>>[
    for (final List<Offset> b in _bodiesMm) _placed(b),
  ];
  late final List<List<Offset>> discs = <List<Offset>>[
    for (final List<Offset> d in _discsMm) _placed(d),
  ];

  /// The column's top and bottom, where it has faded out, and where it
  /// begins to: in the scene, for the gradient it is drawn through.
  late final (double, double, double, double) columnFade = (
    place(const Offset(0, -AortaAnatomy.columnTo)).dy,
    place(const Offset(0, -AortaAnatomy.columnFrom)).dy,
    place(const Offset(0, AortaAnatomy.columnFrom)).dy,
    place(const Offset(0, AortaAnatomy.columnTo)).dy,
  );

  /// The posterior intercostal arteries, the right ones and the left.
  late final List<TubeCourse> rightIntercostals = <TubeCourse>[
    for (final double y in AortaAnatomy.bodies)
      _tube(
        AnatomyTube(AortaAnatomy.rightIntercostal(y, centreAt(y)), <double>[
          for (int i = 0; i < 6; i++) AortaAnatomy.intercostal,
        ], fadeOut: AortaAnatomy.intercostalFade),
      ),
  ];
  late final List<TubeCourse> leftIntercostals = <TubeCourse>[
    for (final double y in AortaAnatomy.bodies)
      _tube(
        AnatomyTube(AortaAnatomy.leftIntercostal(y, centreAt(y)), <double>[
          for (int i = 0; i < 4; i++) AortaAnatomy.intercostal,
        ], fadeOut: AortaAnatomy.intercostalFade / 2),
      ),
  ];

  /// The azygos, the thoracic duct and the hemiazygos.
  late final TubeCourse azygos = _tube(AortaAnatomy.azygos);
  late final TubeCourse duct = _tube(AortaAnatomy.duct);
  late final TubeCourse hemiazygos = _tube(AortaAnatomy.hemiazygos);

  /// The aorta's top end, its course run backward, so that its end can be
  /// drawn as the bottom's is.
  late final TubeCourse aortaTop = _tube(
    AnatomyTube(
      AortaAnatomy.aorta.points.reversed.toList(),
      AortaAnatomy.aorta.radii.reversed.toList(),
      cutEnd: true,
    ),
  );

  /// What runs beside the aorta.
  late final List<TubeCourse> beside = <TubeCourse>[
    hemiazygos,
    ...rightIntercostals,
    ...leftIntercostals,
    azygos,
    duct,
  ];

  // Where it is gone into, and where its parts are named.

  /// Where the tissue is sampled: in the media bared in the window, just
  /// outside the inner window on the body's right, at its middle.
  late final Offset site = place(
    Offset(
      centreAt(AortaAnatomy.windowAt) - AortaAnatomy.siteOut,
      AortaAnatomy.windowAt,
    ),
  );

  Offset _onAorta(Offset at) => place(Offset(centreAt(at.dy) + at.dx, at.dy));

  /// Each coat's name point, the home's at the site in the media, and the
  /// rest.
  late final Offset intimaName = _onAorta(AortaAnatomy.intimaName);
  late final Offset mediaName = home == AortaHome.media
      ? site
      : _onAorta(AortaAnatomy.mediaName);
  late final Offset adventitiaName = _onAorta(AortaAnatomy.adventitiaName);
  late final Offset intercostalName = place(AortaAnatomy.intercostalName);
  late final Offset azygosName = place(AortaAnatomy.azygosName);
  late final Offset ductName = place(AortaAnatomy.ductName);
  late final Offset bodyName = place(AortaAnatomy.bodyName);

  /// The name point of the coat the zoom's cell lives in.
  Offset get homeName => switch (home) {
    AortaHome.intima => intimaName,
    AortaHome.media => mediaName,
    AortaHome.adventitia => adventitiaName,
  };

  /// The points its names are set round: its outline and the azygos, the
  /// column where it shows.
  late final List<Offset> namedPoints = <Offset>[
    for (int i = 0; i < outlinePoints.length; i += 6) outlinePoints[i],
    for (int i = 0; i < azygos.length; i += 6)
      if (azygos.shown[i] > AortaStyle.nameShown) ...<Offset>[
        azygos.centres[i] + azygos.across[i] * azygos.radius[i],
        azygos.centres[i] - azygos.across[i] * azygos.radius[i],
      ],
  ];

  /// The outermost points of what is drawn at the height of [at], on
  /// either side, with room round them: the aorta, the column where it
  /// shows, and the vessels beside it where they show.
  (Offset, Offset) edgesAt(Offset at) {
    final double y = toMm(at).dy;
    double left = double.infinity;
    double right = double.negativeInfinity;
    for (final double x in _crossings(outlinePoints, at.dy)) {
      left = math.min(left, x);
      right = math.max(right, x);
    }
    if (columnShown(y) > AortaStyle.nameShown) {
      for (final List<Offset> part in <List<Offset>>[...bodies, ...discs]) {
        for (final double x in _crossings(part, at.dy)) {
          left = math.min(left, x);
          right = math.max(right, x);
        }
      }
    }
    final double clear = mm(AortaStyle.nameClear);
    for (final TubeCourse tube in beside) {
      for (int i = 0; i < tube.length; i++) {
        if (tube.shown[i] <= AortaStyle.nameShown) {
          continue;
        }
        final double reach = tube.radius[i] + clear;
        if ((tube.centres[i].dy - at.dy).abs() > reach) {
          continue;
        }
        left = math.min(left, tube.centres[i].dx - reach);
        right = math.max(right, tube.centres[i].dx + reach);
      }
    }
    if (left > right) {
      return (at, at);
    }
    return (Offset(left, at.dy), Offset(right, at.dy));
  }

  static List<double> _crossings(List<Offset> points, double y) {
    final List<double> out = <double>[];
    final int n = points.length;
    for (int i = 0; i < n; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % n];
      if ((a.dy <= y) != (b.dy <= y)) {
        out.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
      }
    }
    return out;
  }
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

bool _inside(List<Offset> polygon, Offset p) {
  bool odd = false;
  final int n = polygon.length;
  for (int i = 0; i < n; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % n];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy)) {
      odd = !odd;
    }
  }
  return odd;
}

Rect _bounds(List<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset p in points) {
    left = math.min(left, p.dx);
    right = math.max(right, p.dx);
    top = math.min(top, p.dy);
    bottom = math.max(bottom, p.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}
