import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'liver_anatomy.dart';
import 'liver_style.dart';

/// Where in the liver the zoom's cell lives, which its drawing lights in
/// the mark, by the Atlas's name for the cell. By the kind of cell, never
/// by gene.
enum LiverHome {
  /// The parenchyma: the hepatocytes, and every cell that has no part of
  /// the liver of its own to be drawn at its size (its Kupffer cells, its
  /// stellate cells, its sinusoids' lining, its immune cells).
  parenchyma,

  /// The bile ducts: the cholangiocytes that line them.
  ducts;

  /// Where a cell the Atlas calls [cell] lives.
  static LiverHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('cholangiocyte') || name.contains('bile duct')) {
      return ducts;
    }
    return parenchyma;
  }
}

/// A small vessel the cut crosses, in the scene: its outline, and, for a
/// portal tract, its sheath's.
final class LiverVessel {
  const LiverVessel(this.lumen, this.sheath, this.centre);

  final List<Offset> lumen;
  final List<Offset>? sheath;
  final Offset centre;

  bool get portal => sheath != null;
}

/// The liver as the zoom's organ scene draws it, cut open from front to
/// back: every part in the scene's units at its real size, the middle of
/// the body's outline of it at the origin.
///
/// The liver is drawn from general anatomy ([LiverAnatomy]) and laid on
/// the body's outline of it so that the place it is gone into in the
/// anatomy ([LiverAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline in toward the
/// liver's own ([pathAt]). Everything here is geometry: what it is drawn in
/// is `LiverArt`'s.
final class LiverForm {
  LiverForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.home = LiverHome.parenchyma,
  }) : scale = length / LiverAnatomy.length {
    final List<Offset> knots = <Offset>[
      for (final Offset p in LiverAnatomy.outline) place(p),
    ];
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(LiverStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(LiverStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: LiverStyle.morphPoints,
      bed: mm(LiverStyle.bed),
      marks: _marks,
    );
  }

  /// The liver where the body draws it as [part], in a view [view] metres
  /// across, its cells' [home] in it.
  factory LiverForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    LiverHome home = LiverHome.parenchyma,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return LiverForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the liver, in the scene: in its right lobe,
  /// between the right and middle hepatic veins.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final LiverHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The liver's outline, the capsule, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - LiverAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => LiverAnatomy.site + (p - site) / scale;

  /// How far the liver's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the liver's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the liver's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every liver.

  /// The outline followed closely, in millimetres.
  static final List<Offset> _outlineMm = const Contour(LiverAnatomy.outline)
      .sampled(LiverStyle.outlineSpan)
      .points;
  // Followed by its points, not its curves: cutting a union of tubes by
  // the curves themselves can fail.
  static final Path _outlinePathMm = Path()..addPolygon(_outlineMm, true);

  /// Each of [tubes] round its course, as one shape, cut by the outline:
  /// [extra] wider than its lumen to either side.
  ///
  /// The tubes are gathered into one path and cut once: each turns the
  /// same way round, so where they overlap they stay filled, and no union
  /// is taken tube by tube, which can fail where three meet at one point
  /// with their round ends almost one inside another.
  static Path _channels(List<AnatomyTube> tubes, {double extra = 0}) {
    final Path all = Path()..fillType = PathFillType.nonZero;
    for (final AnatomyTube tube in tubes) {
      all.addPolygon(_tubeShape(tube, extra: extra), true);
    }
    return Path.combine(PathOperation.intersect, all, _outlinePathMm);
  }

  static final Path _veinsMm = _channels(<AnatomyTube>[
    LiverAnatomy.cava,
    ...LiverAnatomy.hepaticVeins,
  ]);
  static final Path _portalMm = _channels(<AnatomyTube>[
    LiverAnatomy.portalVein,
    ...LiverAnatomy.portalBranches,
  ]);
  static final Path _sheathsMm = _channels(<AnatomyTube>[
    LiverAnatomy.portalVein,
    ...LiverAnatomy.portalBranches,
  ], extra: LiverAnatomy.sheath);

  /// The gallbladder's lumen and its outer wall, in millimetres.
  static final List<Offset> _gallbladderMm = _shapeOf(
    LiverAnatomy.gallbladder,
    LiverAnatomy.gallbladderHalf,
  );
  static final List<Offset> _gallbladderWallMm = _shapeOf(
    LiverAnatomy.gallbladder,
    <double>[
      for (final double h in LiverAnatomy.gallbladderHalf)
        h + LiverAnatomy.gallbladderWall,
    ],
  );

  /// The courses of the large vessels, and how far each reaches from its
  /// middle, sheath and all, a millimetre apart along them: what the small
  /// vessels keep clear of.
  static final List<(Offset, double)> _largeMm = () {
    final List<(Offset, double)> out = <(Offset, double)>[];
    void add(AnatomyTube tube, double extra) {
      final (List<Offset> course, List<double> radii) = _course(tube, 1);
      for (int i = 0; i < course.length; i++) {
        out.add((course[i], radii[i] + extra));
      }
    }

    add(LiverAnatomy.cava, 0);
    for (final AnatomyTube t in LiverAnatomy.hepaticVeins) {
      add(t, 0);
    }
    add(LiverAnatomy.portalVein, LiverAnatomy.sheath);
    for (final AnatomyTube t in LiverAnatomy.portalBranches) {
      add(t, LiverAnatomy.sheath);
    }
    add(LiverAnatomy.hepaticArtery, 0);
    add(LiverAnatomy.bileDuct, 0);
    add(LiverAnatomy.cysticDuct, 0);
    return out;
  }();

  /// The small vessels the cut crosses, in millimetres: one in each square
  /// of a lattice [LiverAnatomy.smallApart] across, moved about in it, where
  /// it keeps clear of the large vessels, the gallbladder, the capsule and
  /// the site.
  static final List<(List<Offset>, List<Offset>?, Offset)> _smallMm = () {
    final math.Random random = math.Random(LiverStyle.seed);
    final Rect box = _bounds(_outlineMm);
    const double apart = LiverAnatomy.smallApart;
    final List<(List<Offset>, List<Offset>?, Offset)> out =
        <(List<Offset>, List<Offset>?, Offset)>[];
    for (double y = box.top; y < box.bottom; y += apart) {
      for (double x = box.left; x < box.right; x += apart) {
        final Offset c = Offset(
          x + apart * (0.15 + 0.7 * random.nextDouble()),
          y + apart * (0.15 + 0.7 * random.nextDouble()),
        );
        final double r =
            LiverAnatomy.smallLeast +
            (LiverAnatomy.smallMost - LiverAnatomy.smallLeast) *
                random.nextDouble();
        final double long =
            1 + (LiverAnatomy.smallLong - 1) * random.nextDouble();
        final double angle = random.nextDouble() * math.pi;
        final bool portal = random.nextDouble() < LiverAnatomy.smallPortal;
        final double reach = r * long + (portal ? LiverStyle.smallSheath : 0);
        const double clear = LiverStyle.smallClear;
        if (!_inside(_outlineMm, c) ||
            _toLine(_outlineMm, c, closed: true) < reach + clear + 1 ||
            (c - LiverAnatomy.site).distance < LiverStyle.siteClear + reach ||
            _inside(_gallbladderWallMm, c) ||
            _toLine(_gallbladderWallMm, c, closed: true) < reach + clear ||
            _largeMm.any(
              ((Offset, double) v) =>
                  (v.$1 - c).distance < v.$2 + reach + clear,
            )) {
          continue;
        }
        List<Offset> oval(double grow) => <Offset>[
          for (int k = 0; k < 14; k++)
            () {
              final double t = 2 * math.pi * k / 14;
              final double u = math.cos(t) * (r * long + grow);
              final double v = math.sin(t) * (r + grow);
              return c +
                  Offset(
                    u * math.cos(angle) - v * math.sin(angle),
                    u * math.sin(angle) + v * math.cos(angle),
                  );
            }(),
        ];
        out.add((oval(0), portal ? oval(LiverStyle.smallSheath) : null, c));
      }
    }
    return out;
  }();

  // The parts, laid in the scene.

  /// The anatomy's millimetres taken into the scene, as a matrix.
  late final Float64List _matrix = Float64List.fromList(<double>[
    scale, 0, 0, 0, //
    0, scale, 0, 0, //
    0, 0, 1, 0, //
    site.dx - LiverAnatomy.site.dx * scale,
    site.dy - LiverAnatomy.site.dy * scale, 0, 1, //
  ]);

  /// The hepatic veins and the vena cava where the cut shows them, one
  /// cavity; the portal veins, another; and their sheaths round them.
  late final Path veins = _veinsMm.transform(_matrix);
  late final Path portal = _portalMm.transform(_matrix);
  late final Path sheaths = _sheathsMm.transform(_matrix);

  /// The edges of the emptied veins, along which their rims are drawn.
  late final List<List<Offset>> veinEdges = _edges(veins);
  late final List<List<Offset>> portalEdges = _edges(portal);

  List<List<Offset>> _edges(Path path) => <List<Offset>>[
    for (final PathMetric metric in path.computeMetrics())
      <Offset>[
        for (double s = 0; s < metric.length; s += mm(LiverStyle.edgeStep))
          metric.getTangentForOffset(s)!.position,
      ],
  ];

  /// The gallbladder's lumen and its outer wall, in the scene.
  late final List<Offset> gallbladder = _placed(_gallbladderMm);
  late final List<Offset> gallbladderWall = _placed(_gallbladderWallMm);

  /// The small vessels the cut crosses.
  late final List<LiverVessel> small = <LiverVessel>[
    for (final (List<Offset> lumen, List<Offset>? sheath, Offset c) in _smallMm)
      LiverVessel(
        _placed(lumen),
        sheath == null ? null : _placed(sheath),
        place(c),
      ),
  ];

  /// The parenchyma's edge under the capsule, and the line it turns away
  /// to, point for point with the outline.
  late final List<Offset> rimInner = () {
    final List<Offset> normals = _normals(outlinePoints, closed: true);
    final int n = outlinePoints.length;
    final double inward =
        _inside(outlinePoints, outlinePoints[0] + normals[0] * mm(1)) ? 1 : -1;
    return <Offset>[
      for (int i = 0; i < n; i++)
        outlinePoints[i] + normals[i] * (inward * mm(LiverStyle.rim)),
    ];
  }();

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(LiverStyle.edgeStep), bend: 0.9);

  /// The vena cava, cut short above the liver; the portal vein and the
  /// hepatic artery, cut short below it; the bile duct and the round
  /// ligament, fading out below it; the cystic duct.
  late final TubeCourse cava = _tube(LiverAnatomy.cava);
  late final TubeCourse portalVein = _tube(LiverAnatomy.portalVein);
  late final TubeCourse hepaticArtery = _tube(LiverAnatomy.hepaticArtery);
  late final TubeCourse bileDuct = _tube(LiverAnatomy.bileDuct);
  late final TubeCourse cysticDuct = _tube(LiverAnatomy.cysticDuct);
  late final TubeCourse roundLigament = _tube(LiverAnatomy.roundLigament);

  /// What runs on below or above the liver, beside it.
  late final List<TubeCourse> beside = <TubeCourse>[
    cava,
    portalVein,
    hepaticArtery,
    bileDuct,
    roundLigament,
  ];

  /// The portal branches, laid in the scene.
  late final List<TubeCourse> portalBranches = <TubeCourse>[
    for (final AnatomyTube t in LiverAnatomy.portalBranches) _tube(t),
  ];

  /// The bile ducts beside the portal branches, in their sheaths: each a
  /// line along its branch's side.
  late final List<List<Offset>> ducts = <List<Offset>>[
    for (final int i in LiverAnatomy.ductBranches)
      _beside(portalBranches[i], 1),
  ];

  /// The arteries beside the right and left portal veins, on their other
  /// side.
  late final List<List<Offset>> arteries = <List<Offset>>[
    _beside(portalBranches[0], -1),
    _beside(portalBranches[4], -1),
  ];

  List<Offset> _beside(TubeCourse tube, double side) {
    final double out = mm(LiverAnatomy.sheath) * 0.55;
    return <Offset>[
      for (int i = 0; i < tube.length; i++)
        tube.centres[i] +
            tube.across[i] *
                (side * ((side > 0 ? tube.plus[i] : tube.minus[i]) + out)),
    ];
  }

  // Where the parts are named.

  late final Offset cavaName = place(LiverAnatomy.cavaName);
  late final Offset hepaticVeinsName = place(LiverAnatomy.hepaticVeinsName);
  late final Offset portalVeinName = place(LiverAnatomy.portalVeinName);
  late final Offset gallbladderName = place(LiverAnatomy.gallbladderName);
  late final Offset rightLobeName = place(LiverAnatomy.rightLobeName);
  late final Offset leftLobeName = place(LiverAnatomy.leftLobeName);

  /// The point of a bile duct beside a portal branch nearest [p].
  Offset ductNear(Offset p) {
    Offset best = ducts.first.first;
    for (final List<Offset> line in ducts) {
      for (final Offset q in line) {
        if ((q - p).distanceSquared < (best - p).distanceSquared) {
          best = q;
        }
      }
    }
    return best;
  }

  /// Where the step from the body meets the liver's outline and the
  /// body's, beside their tops: the right lobe's lateral border, its
  /// lowest point and the left lobe's tip, each picked out of either
  /// outline alike.
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.3, 0.7),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.1, 0.6),
      ];

  static int _lowest(List<Offset> points) {
    int best = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy > points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The points of the liver's own outline where the step from the body
  /// meets the body's, for tests: in the order round it from the top.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];

  /// How far [p] lies from the nearest large vessel's lumen, or its sheath,
  /// in millimetres: below zero inside one. For tests.
  static double clearOfVessels(Offset mm) {
    double best = double.infinity;
    for (final (Offset c, double r) in _largeMm) {
      best = math.min(best, (c - mm).distance - r);
    }
    return best;
  }
}

// Geometry, in the anatomy's millimetres.

/// A tube's course through its knots, as an open Catmull-Rom curve [step]
/// apart, and its radius at each point.
(List<Offset>, List<double>) _course(AnatomyTube tube, double step) {
  final List<Offset> knots = tube.points;
  final int n = knots.length;
  Offset knot(int i) => i < 0
      ? knots[0] * 2 - knots[1]
      : i >= n
      ? knots[n - 1] * 2 - knots[n - 2]
      : knots[i];
  final List<Offset> points = <Offset>[];
  final List<double> radii = <double>[];
  for (int i = 0; i < n - 1; i++) {
    final Offset p0 = knot(i - 1);
    final Offset p1 = knot(i);
    final Offset p2 = knot(i + 1);
    final Offset p3 = knot(i + 2);
    final Offset c1 = p1 + (p2 - p0) / 6;
    final Offset c2 = p2 - (p3 - p1) / 6;
    final int steps = math.max(2, ((p2 - p1).distance / step).ceil());
    for (int k = 0; k < steps; k++) {
      final double t = k / steps;
      final double u = 1 - t;
      points.add(
        p1 * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            p2 * (t * t * t),
      );
      radii.add(tube.radii[i] + (tube.radii[i + 1] - tube.radii[i]) * t);
    }
  }
  points.add(knots.last);
  radii.add(tube.radii.last);
  return (points, radii);
}

/// A tube's shape round its course, [extra] wider than its lumen to either
/// side, its ends rounded.
List<Offset> _tubeShape(AnatomyTube tube, {double extra = 0}) {
  final (List<Offset> course, List<double> radii) = _course(tube, 0.5);
  final int n = course.length;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset t = _unit(
      course[math.min(n - 1, i + 1)] - course[math.max(0, i - 1)],
    );
    final Offset across = Offset(-t.dy, t.dx);
    final double h = radii[i] + extra;
    left.add(course[i] + across * h);
    right.add(course[i] - across * h);
  }
  List<Offset> round(Offset centre, Offset out, Offset across, double h) =>
      <Offset>[
        for (int k = 1; k < 8; k++)
          centre +
              (across * math.cos(math.pi * k / 8) +
                      out * math.sin(math.pi * k / 8)) *
                  h,
      ];
  final Offset endWay = _unit(course[n - 1] - course[n - 2]);
  final Offset startWay = _unit(course[0] - course[1]);
  return <Offset>[
    ...left,
    ...round(
      course.last,
      endWay,
      Offset(-endWay.dy, endWay.dx),
      radii.last + extra,
    ),
    ...right.reversed,
    ...round(
      course.first,
      startWay,
      Offset(-startWay.dy, startWay.dx),
      radii.first + extra,
    ),
  ];
}

/// A closed shape round an axis through [knots], as wide to either side of
/// it as [halves] at each knot, its ends rounded.
List<Offset> _shapeOf(List<Offset> knots, List<double> halves) =>
    _tubeShape(AnatomyTube(knots, halves));

Offset _unit(Offset p) {
  final double length = p.distance;
  return length <= 0 ? Offset.zero : p / length;
}

/// The left hand of the way along [line] at each point, a unit.
List<Offset> _normals(List<Offset> line, {bool closed = false}) {
  final int n = line.length;
  return <Offset>[
    for (int i = 0; i < n; i++)
      () {
        final Offset t = _unit(
          closed
              ? line[(i + 1) % n] - line[(i - 1 + n) % n]
              : line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)],
        );
        return Offset(t.dy, -t.dx);
      }(),
  ];
}

double _toSegment(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double length = ab.distanceSquared;
  final double t = length <= 0
      ? 0
      : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

double _toLine(List<Offset> line, Offset p, {required bool closed}) {
  double best = double.infinity;
  final int n = line.length;
  final int last = closed ? n : n - 1;
  for (int i = 0; i < last; i++) {
    best = math.min(best, _toSegment(p, line[i], line[(i + 1) % n]));
  }
  return best;
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

double _area(List<Offset> points) {
  double sum = 0;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
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
