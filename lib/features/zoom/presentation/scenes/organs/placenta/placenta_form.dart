import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../tube_course.dart';
import 'placenta_anatomy.dart';
import 'placenta_style.dart';

/// Where in the placenta the zoom's cell lives, which its drawing lights in
/// the mark, by the name the Atlas gives the cell, as the skin chooses its
/// own: every cell of the placenta the Atlas names is drawn as one shape,
/// which cannot tell them apart.
enum PlacentaHome {
  /// The villi: their trophoblast, the stroma in them, and any cell the
  /// Atlas finds everywhere.
  villi('villi'),

  /// The decidua: the basal plate, the septa and the decidua under the
  /// plate, where its stromal cells live and the extravillous trophoblast
  /// goes.
  decidua('decidua');

  const PlacentaHome(this.word);

  /// What its name reads.
  final String word;

  /// Where a cell the Atlas calls [cellName] lives.
  static PlacentaHome of(String? cellName) {
    final String name = (cellName ?? '').toLowerCase();
    if (name.contains('decidua') || name.contains('extravillous')) {
      return decidua;
    }
    return villi;
  }
}

/// A stem villus or one of its branches, in the front face's millimetres:
/// the way it runs, how broad it is at each point, and how many times the
/// tree has branched to reach it.
final class PlacentaBranch {
  const PlacentaBranch(this.points, this.widths, this.order);

  final List<Offset> points;
  final List<double> widths;
  final int order;
}

/// Clumps of villi of one size, in the scene: where each lies, as pairs of
/// x and y, and their radius.
typedef PlacentaClumps = ({Float32List points, double radius});

/// A block of a placenta at term in its uterine wall as the zoom's organ
/// scene draws it: every shape in the scene's units at the placenta's real
/// size, the middle of the drawn block at the origin. The anatomy is
/// `PlacentaAnatomy`'s, in millimetres of the block ([at]): across its
/// front face, down from the fetal surface and back into the block, seen
/// in an oblique view, the front face flat to the screen and the top and
/// the right side receding up and to the right, as the skin's block is.
///
/// The front face is the cut: the amnion and the chorionic plate, two
/// lobules of villous trees hanging from it in the intervillous space, each
/// round a central cavity, septa rising between them from the basal plate,
/// the decidua under it, and the uterine muscle; a spiral artery coiling up
/// into each lobule through its funnel, and veins leaving at the lobules'
/// edges. The top is the fetal surface, the chorionic vessels over it, and
/// the cord rising from it, cut across; the right side a second cut, its
/// layers carried round.
///
/// The place its tissue is sampled is in the villi of the left lobule
/// ([site]). Everything here is geometry: what it is drawn in is
/// `PlacentaArt`'s.
final class PlacentaForm {
  PlacentaForm({required double width, required this.view})
    : scale = width / PlacentaAnatomy.width;

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's millimetres, in the scene's units.
  final double scale;

  static const double _w = PlacentaAnatomy.width;
  static const double _d = PlacentaAnatomy.depth;
  static const double _h = PlacentaAnatomy.faceDepth;

  /// A point of the block, [x] across its front face, [y] down from the
  /// fetal surface and [z] back from the front face, on the screen in
  /// millimetres, before it is placed.
  static Offset project(double x, double y, [double z = 0]) =>
      Offset(x + z * PlacentaStyle.backAcross, y - z * PlacentaStyle.backUp);

  // The cord, in the screen's millimetres.

  static const double _cordRadius = PlacentaAnatomy.cord / 2;
  static const Offset _root = PlacentaAnatomy.cordRoot;

  /// A ring of the cord [y] down from the fetal surface, [r] from its
  /// middle, [dx] across and [dz] back of it: a circle level with the
  /// surface, as the screen shows it.
  static List<Offset> _ring(
    double y,
    double r, {
    double dx = 0,
    double dz = 0,
    int n = 48,
  }) => <Offset>[
    for (int k = 0; k < n; k++)
      project(
        _root.dx + dx + r * math.cos(2 * math.pi * k / n),
        y,
        _root.dy + dz + r * math.sin(2 * math.pi * k / n),
      ),
  ];

  /// The cord's outline as the screen shows it: round both its ends.
  static final List<Offset> _cordHull = _hull(<Offset>[
    ..._ring(0, _cordRadius),
    ..._ring(-PlacentaAnatomy.cordShown, _cordRadius),
  ]);

  /// How high the drawing reaches, the cord's cut end above the block.
  static final double _top = math.min(
    -_d * PlacentaStyle.backUp,
    _cordHull.map((Offset p) => p.dy).reduce(math.min),
  );

  /// The middle of the block as it is drawn, its front, top and side and
  /// the cord, in the screen's millimetres: the scene's origin.
  static final Offset middle = Offset(
    project(_w, 0, _d).dx / 2 + PlacentaStyle.offCentre,
    (_top + _h) / 2,
  );

  /// A point of the screen's millimetres, in the scene.
  Offset place(Offset mm) => (mm - middle) * scale;

  /// A point of the block, in the scene.
  Offset at(double x, double y, [double z = 0]) => place(project(x, y, z));

  /// [millimetres] of the real placenta, in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the scene, in the screen's millimetres.
  Offset toMm(Offset p) => p / scale + middle;

  // The block.

  /// Its corners as drawn: the front face's lower left, upper left, the
  /// top's back left and back right, the side's lower back, the front
  /// face's lower right.
  static final List<Offset> _corners = <Offset>[
    project(0, _h),
    project(0, 0),
    project(0, 0, _d),
    project(_w, 0, _d),
    project(_w, _h, _d),
    project(_w, _h),
  ];

  /// Its outline, front, top and side and the cord rising from it, in the
  /// scene: one line round all of it.
  late final List<Offset> outlinePoints = () {
    final Path union = Path.combine(
      PathOperation.union,
      Path()..addPolygon(_corners, true),
      Path()..addPolygon(_cordHull, true),
    );
    final List<Offset> out = <Offset>[];
    for (final PathMetric m in union.computeMetrics()) {
      final int n = (m.length / 0.25).ceil();
      for (int i = 0; i < n; i++) {
        out.add(place(m.getTangentForOffset(m.length * i / n)!.position));
      }
    }
    return out;
  }();
  late final Path outline = Path()..addPolygon(outlinePoints, true);

  /// Its front face, its top and its right side, in the scene.
  late final Path front = _polygon(<Offset>[
    project(0, 0),
    project(_w, 0),
    project(_w, _h),
    project(0, _h),
  ]);
  late final Path top = _polygon(<Offset>[
    project(0, 0),
    project(_w, 0),
    project(_w, 0, _d),
    project(0, 0, _d),
  ]);
  late final Path side = _polygon(<Offset>[
    project(_w, 0),
    project(_w, 0, _d),
    project(_w, _h, _d),
    project(_w, _h),
  ]);

  /// The edges where the top meets the front and the side, and where the
  /// side meets the front, in the scene.
  late final List<Offset> topEdge = <Offset>[
    at(0, 0),
    at(_w, 0),
    at(_w, 0, _d),
  ];
  late final List<Offset> sideEdge = <Offset>[at(_w, 0), at(_w, _h)];

  /// The outermost points of what is drawn at [y] millimetres down the
  /// screen, to its left and to its right, in the scene: where a name
  /// level with what it names stands clear of it.
  (Offset, Offset) edgesAt(double y) {
    double? left;
    double? right;
    const double back = _d * PlacentaStyle.backUp;
    if (y >= -back) {
      left = y >= 0 ? 0 : -y * PlacentaStyle.backAcross / PlacentaStyle.backUp;
      const double far = _w + _d * PlacentaStyle.backAcross;
      right = y <= _h - back
          ? far
          : far -
                (math.min(y, _h) - (_h - back)) /
                    PlacentaStyle.backUp *
                    PlacentaStyle.backAcross;
    }
    final int n = _cordHull.length;
    for (int i = 0; i < n; i++) {
      final Offset a = _cordHull[i];
      final Offset b = _cordHull[(i + 1) % n];
      if ((a.dy > y) != (b.dy > y)) {
        final double x = a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
        left = left == null ? x : math.min(left, x);
        right = right == null ? x : math.max(right, x);
      }
    }
    if (left == null || right == null) {
      // Above it all: the cord's cut end's extent.
      left = _cordHull.map((Offset p) => p.dx).reduce(math.min);
      right = _cordHull.map((Offset p) => p.dx).reduce(math.max);
    }
    return (place(Offset(left, y)), place(Offset(right, y)));
  }

  // The layers on the front face, each edge across it from left to right.

  /// How many points an edge across the face is followed by.
  static final int _across = (_w * PlacentaStyle.perMm).round();

  static List<double> get _xs => <double>[
    for (int i = 0; i <= _across; i++) _w * i / _across,
  ];

  /// The chorionic plate's floor at [x].
  static double plateAt(double x) =>
      PlacentaAnatomy.chorionicPlate + 0.08 * math.sin(x * 0.9 + 0.3);

  /// The basal plate's top, where the intervillous space ends, and its
  /// floor, at [x].
  static double basalTopAt(double x) =>
      PlacentaAnatomy.thickness -
      PlacentaAnatomy.basalPlate +
      0.25 * math.sin(x * 0.37 + 1) +
      0.12 * math.sin(x * 1.3);
  static double basalFloorAt(double x) =>
      PlacentaAnatomy.thickness + 0.2 * math.sin(x * 0.29 + 2);

  /// Where the decidua meets the uterine muscle, at [x].
  static double deciduaAt(double x) =>
      PlacentaAnatomy.thickness +
      PlacentaAnatomy.decidua +
      0.3 * math.sin(x * 0.23 + 0.5) +
      0.12 * math.sin(x * 0.9);

  List<Offset> _edge(double Function(double) y) => <Offset>[
    for (final double x in _xs) at(x, y(x)),
  ];

  Path _band(double Function(double) upper, double Function(double) lower) {
    final List<double> xs = _xs;
    return Path()..addPolygon(<Offset>[
      for (final double x in xs) at(x, upper(x)),
      for (final double x in xs.reversed) at(x, lower(x)),
    ], true);
  }

  /// The amnion's cut edge, along the top of the face, in the scene.
  late final List<Offset> amnion = <Offset>[
    at(0, PlacentaAnatomy.amnion / 2),
    at(_w, PlacentaAnatomy.amnion / 2),
  ];

  /// The chorionic plate, the intervillous space, the basal plate, the
  /// decidua under it and the uterine muscle, each a band across the face,
  /// in the scene.
  late final Path plate = _band((double _) => PlacentaAnatomy.amnion, plateAt);
  late final Path space = _band(plateAt, basalTopAt);
  late final Path basal = _band(basalTopAt, basalFloorAt);
  late final Path decidua = _band(basalFloorAt, deciduaAt);
  late final Path myometrium = _band(deciduaAt, (double _) => _h);

  /// The lines between the layers, in the scene: the chorionic plate's
  /// floor, the basal plate's top and floor, and the decidua's floor.
  late final List<List<Offset>> layerLines = <List<Offset>>[
    _edge(plateAt),
    _edge(basalTopAt),
    _edge(basalFloorAt),
    _edge(deciduaAt),
  ];

  // The septa.

  static const double _footSink = 0.4;

  /// How far up the [k]th septum reaches.
  static double _tipOf(int k) {
    final (double x, double share) = PlacentaAnatomy.septa[k];
    final double base = basalTopAt(x);
    return base - share * (base - plateAt(x));
  }

  /// The [k]th septum's middle and its half-breadth [t] of the way from its
  /// foot to its tip.
  static (double, double) _septumAt(int k, double t) {
    final (double x, double _) = PlacentaAnatomy.septa[k];
    final double lean = 0.6 * math.sin(t * 2.6 + k) * t;
    final double half =
        PlacentaAnatomy.septumFoot /
        2 *
        math.pow(1 - t, 0.85).toDouble() *
        (1 + 0.15 * math.sin(t * 9 + k));
    return (x + lean, half);
  }

  static double _footOf(int k) =>
      basalTopAt(PlacentaAnatomy.septa[k].$1) + _footSink;

  /// The septa, each rising from the basal plate to an irregular point, in
  /// the scene.
  late final List<List<Offset>> septaPoints = <List<Offset>>[
    for (int k = 0; k < PlacentaAnatomy.septa.length; k++)
      () {
        const int n = 40;
        final double foot = _footOf(k);
        final double tip = _tipOf(k);
        final List<Offset> left = <Offset>[];
        final List<Offset> right = <Offset>[];
        for (int i = 0; i <= n; i++) {
          final double t = i / n;
          final (double x, double half) = _septumAt(k, t);
          final double y = foot - t * (foot - tip);
          left.add(at(x - half, y));
          right.add(at(x + half, y));
        }
        return <Offset>[...left, ...right.reversed.skip(1)];
      }(),
  ];

  /// Whether [p], a point of the front face, lies in a septum or within
  /// [clear] of one.
  static bool _inSeptum(Offset p, double clear) {
    for (int k = 0; k < PlacentaAnatomy.septa.length; k++) {
      final double foot = _footOf(k);
      final double tip = _tipOf(k);
      if (p.dy < tip - clear || p.dy > foot) {
        continue;
      }
      final double t = ((foot - p.dy) / (foot - tip)).clamp(0.0, 1.0);
      final (double x, double half) = _septumAt(k, t);
      if ((p.dx - x).abs() < half + clear) {
        return true;
      }
    }
    return false;
  }

  // The lobules.

  /// The middle of each lobule's central cavity, in the face's millimetres.
  static Offset cavityOf(double x) =>
      Offset(x, basalTopAt(x) - PlacentaAnatomy.cavityHeight / 2);

  /// How far [p] lies inside or outside the central cavity of the lobule
  /// round [x]: under 1 inside it.
  static double _cavityDistance(Offset p, double x) {
    final Offset c = cavityOf(x);
    return Offset(
      (p.dx - c.dx) / (PlacentaAnatomy.cavityWidth / 2),
      (p.dy - c.dy) / (PlacentaAnatomy.cavityHeight / 2),
    ).distance;
  }

  static double _nearestCavity(Offset p) => PlacentaAnatomy.lobules
      .map((double x) => _cavityDistance(p, x))
      .reduce(math.min);

  // The villous trees.

  /// Each lobule's tree, its stem villus first, in the face's millimetres.
  late final List<PlacentaBranch> branches = () {
    final math.Random random = math.Random(PlacentaStyle.seed);
    final List<PlacentaBranch> out = <PlacentaBranch>[];
    for (int k = 0; k < PlacentaAnatomy.lobules.length; k++) {
      final double x = PlacentaAnatomy.lobules[k];
      final double start =
          x + (k.isEven ? -1 : 1) * PlacentaAnatomy.trunkOffset;
      _grow(
        out,
        random,
        Offset(start, plateAt(start)),
        const Offset(0, 1),
        PlacentaAnatomy.trunk,
        PlacentaAnatomy.trunkLength,
        0,
        x,
        PlacentaAnatomy.septa[k].$1,
        PlacentaAnatomy.septa[k + 1].$1,
      );
    }
    return out;
  }();

  /// Grows a branch from [from] along [way], [width] broad and [length]
  /// long, its tree branched [order] times already, in the lobule round
  /// [x] between the septa at [low] and [high]; and its own branches from
  /// its end, unless it reaches the basal plate there, as an anchoring
  /// villus does.
  static void _grow(
    List<PlacentaBranch> out,
    math.Random random,
    Offset from,
    Offset way,
    double width,
    double length,
    int order,
    double x,
    double low,
    double high,
  ) {
    const double step = 0.4;
    final double end = order == 0
        ? width * 0.8
        : math.max(PlacentaAnatomy.twig, width * 0.65);
    final int n = math.max(2, (length / step).round());
    final List<Offset> points = <Offset>[from];
    final List<double> widths = <double>[width];
    Offset p = from;
    Offset dir = way;
    double turn = 0;
    bool anchored = false;
    final Offset cavity = cavityOf(x);
    for (int i = 1; i <= n; i++) {
      turn = turn * 0.8 + (random.nextDouble() - 0.5) * 0.18;
      Offset d = _turned(dir, turn) + const Offset(0, 0.06);
      // Round the central cavity, which no villus crosses.
      final double inside = 1 - _cavityDistance(p, x) / 1.45;
      if (inside > 0) {
        final Offset away = p - cavity;
        d += away / math.max(away.distance, 1e-6) * (0.6 * inside + 0.12);
      }
      // Within its lobule, clear of the chorionic plate.
      if (p.dx < low + 2) {
        d += const Offset(0.25, 0);
      }
      if (p.dx > high - 2) {
        d -= const Offset(0.25, 0);
      }
      if (p.dy < plateAt(p.dx) + 1.2) {
        d += const Offset(0, 0.3);
      }
      dir = d / d.distance;
      p += dir * step;
      // Never into it: out to its rim, along the way from its middle.
      final double into = _cavityDistance(p, x);
      if (into < 1) {
        p = cavity + (p - cavity) / math.max(into, 1e-6);
      }
      final double w = width + (end - width) * i / n;
      if (p.dy >= basalTopAt(p.dx) - w / 2) {
        // Anchored on the basal plate.
        p = Offset(p.dx, basalTopAt(p.dx));
        points.add(p);
        widths.add(w);
        anchored = true;
        break;
      }
      points.add(p);
      widths.add(w);
      if (p.dx < 0.3 || p.dx > _w - 0.3) {
        break;
      }
    }
    out.add(PlacentaBranch(points, widths, order));
    if (anchored || order >= PlacentaStyle.branchings) {
      return;
    }
    final int count = order == 0 ? 4 : 2;
    for (int j = 0; j < count; j++) {
      final bool outer = j == 0 || j == count - 1;
      final double angle = order == 0
          ? -1.15 + 2.3 * j / (count - 1)
          : (j == 0 ? -1 : 1) *
                PlacentaStyle.spread *
                (0.7 + 0.6 * random.nextDouble());
      _grow(
        out,
        random,
        p,
        _turned(dir, angle),
        order == 0 ? 1.3 : math.max(PlacentaAnatomy.twig, end * 0.75),
        order == 0 ? (outer ? 15 : 10) : length * PlacentaStyle.shorten,
        order + 1,
        x,
        low,
        high,
      );
    }
  }

  static Offset _turned(Offset v, double a) => Offset(
    v.dx * math.cos(a) - v.dy * math.sin(a),
    v.dx * math.sin(a) + v.dy * math.cos(a),
  );

  /// The stem villi and their branches, each a tapering band, in the
  /// scene.
  late final Path stems = () {
    final Path path = Path()..fillType = PathFillType.nonZero;
    for (final PlacentaBranch b in branches) {
      final int n = b.points.length;
      final List<Offset> left = <Offset>[];
      final List<Offset> right = <Offset>[];
      for (int i = 0; i < n; i++) {
        final Offset t =
            b.points[math.min(n - 1, i + 1)] - b.points[math.max(0, i - 1)];
        final Offset across = Offset(-t.dy, t.dx) / t.distance;
        final Offset l = b.points[i] + across * (b.widths[i] / 2);
        final Offset r = b.points[i] - across * (b.widths[i] / 2);
        left.add(at(l.dx, l.dy));
        right.add(at(r.dx, r.dy));
      }
      path.addPolygon(<Offset>[...left, ...right.reversed], true);
    }
    return path;
  }();

  /// Whether a clump of villi may lie at [p], a point of the front face:
  /// in the intervillous space, clear of its plates, of the septa and of
  /// the central cavities.
  static bool _roomFor(Offset p, math.Random random) {
    if (p.dx < 0.2 || p.dx > _w - 0.2) {
      return false;
    }
    if (p.dy < plateAt(p.dx) + 0.35 || p.dy > basalTopAt(p.dx) - 0.3) {
      return false;
    }
    if (_inSeptum(p, 0.25)) {
      return false;
    }
    final double e = _nearestCavity(p);
    return e >= 0.85 && random.nextDouble() < (e - 0.85) / 0.5;
  }

  /// The villi, clumps of them round each branch of the trees, more
  /// round the finer ones, and those hanging free between, in the scene,
  /// by size.
  late final List<PlacentaClumps> clumps = () {
    final math.Random random = math.Random(PlacentaStyle.seed + 1);
    final List<List<double>> bins = <List<double>>[
      <double>[],
      <double>[],
      <double>[],
    ];
    void add(Offset p) {
      final double u = random.nextDouble();
      final int bin = u < 0.45
          ? 0
          : u < 0.8
          ? 1
          : 2;
      final Offset q = at(p.dx, p.dy);
      bins[bin]
        ..add(q.dx)
        ..add(q.dy);
    }

    const double gap = 1 / PlacentaStyle.clumpsPerMm;
    for (final PlacentaBranch b in branches) {
      if (b.order == 0) {
        continue;
      }
      final double reach =
          PlacentaAnatomy.foliage *
          (0.35 + 0.65 * b.order / PlacentaStyle.branchings);
      double carried = 0;
      for (int i = 1; i < b.points.length; i++) {
        carried += (b.points[i] - b.points[i - 1]).distance;
        while (carried >= gap) {
          carried -= gap;
          final double a = random.nextDouble() * 2 * math.pi;
          final double s = reach * math.sqrt(random.nextDouble());
          final Offset p = b.points[i] + Offset(math.cos(a), math.sin(a)) * s;
          if (_roomFor(p, random)) {
            add(p);
          }
        }
      }
    }
    // Those hanging free, thicker toward the face's edges, where the
    // neighbouring lobules' trees are cut.
    const double area = _w * PlacentaAnatomy.thickness;
    final int free = (area * PlacentaStyle.fillPerMm2 * 0.5).round();
    for (int i = 0; i < free * 2; i++) {
      final Offset p = Offset(
        random.nextDouble() * _w,
        random.nextDouble() * PlacentaAnatomy.thickness,
      );
      final double edge = math.min(p.dx, _w - p.dx);
      if ((edge < 3 || random.nextDouble() < 0.5) && _roomFor(p, random)) {
        add(p);
      }
    }
    return <PlacentaClumps>[
      for (int k = 0; k < 3; k++)
        (
          points: Float32List.fromList(bins[k]),
          radius: mm(
            PlacentaAnatomy.clumpMin +
                (PlacentaAnatomy.clumpMax - PlacentaAnatomy.clumpMin) * k / 2,
          ),
        ),
    ];
  }();

  // The vessels.

  /// Each lobule's spiral artery, coiling up through the uterine muscle
  /// and the decidua, as its middle line in the scene; and its funnel
  /// opening through the basal plate.
  late final List<List<Offset>> spirals = <List<Offset>>[
    for (final double x in PlacentaAnatomy.lobules) _spiral(x),
  ];
  late final List<Path> funnels = <Path>[
    for (final double x in PlacentaAnatomy.lobules) _funnel(x),
  ];

  /// Where the [x] lobule's spiral artery's funnel begins.
  static double _funnelFoot(double x) => basalTopAt(x) + PlacentaAnatomy.funnel;

  /// The middle of the [x] lobule's spiral artery [y] down the face.
  static double spiralAt(double x, double y) {
    final double foot = _funnelFoot(x);
    final double settle = _smooth((y - foot) / 1.5);
    final double deep = 1 - 0.5 * _smooth((y - (_h - 2)) / 2);
    return x +
        PlacentaAnatomy.coilSwing *
            settle *
            deep *
            math.sin(2 * math.pi * (y - foot) / PlacentaAnatomy.coilPitch);
  }

  List<Offset> _spiral(double x) {
    final double foot = _funnelFoot(x);
    const double bottom = _h + 0.5;
    final int n = ((bottom - foot) / 0.08).ceil();
    return <Offset>[
      for (int i = 0; i <= n; i++)
        () {
          final double y = bottom - (bottom - foot) * i / n;
          return at(spiralAt(x, y), y);
        }(),
    ];
  }

  Path _funnel(double x) {
    final double foot = _funnelFoot(x);
    final double mouth = basalTopAt(x) - 0.15;
    const int n = 16;
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i <= n; i++) {
      final double t = i / n;
      final double y = foot + (mouth - foot) * t;
      final double half =
          (PlacentaAnatomy.spiral +
              (PlacentaAnatomy.mouth - PlacentaAnatomy.spiral) * t * t) /
          2;
      left.add(at(x - half, y));
      right.add(at(x + half, y));
    }
    return Path()..addPolygon(<Offset>[...left, ...right.reversed], true);
  }

  /// The veins leaving the basal plate at the lobules' edges, each down
  /// through the decidua, leaning away from the nearer lobule's middle, in
  /// the scene; and the veins cut in the uterine muscle.
  late final List<Path> veins = <Path>[
    for (final double x in PlacentaAnatomy.veins)
      () {
        final double nearest = PlacentaAnatomy.lobules.reduce(
          (double a, double b) => (a - x).abs() < (b - x).abs() ? a : b,
        );
        final double lean = x < nearest ? -1.4 : 1.4;
        final double from = basalTopAt(x) - 0.2;
        final double to = deciduaAt(x) + 0.5;
        const double half = PlacentaAnatomy.vein / 2;
        const int n = 12;
        final List<Offset> left = <Offset>[];
        final List<Offset> right = <Offset>[];
        for (int i = 0; i <= n; i++) {
          final double t = i / n;
          final double y = from + (to - from) * t;
          final double c = x + lean * t * t;
          final double h = half * (1 + 0.4 * t);
          left.add(at(c - h, y));
          right.add(at(c + h, y));
        }
        return Path()..addPolygon(<Offset>[...left, ...right.reversed], true);
      }(),
  ];
  late final List<Path> sinuses = <Path>[
    for (final (Offset c, double w, double h) in PlacentaAnatomy.sinuses)
      _ellipse(c, w, h),
  ];

  /// The bundles of the uterine muscle, short wavy lines lying mostly
  /// across the face, in the scene.
  late final List<List<Offset>> fibres = () {
    final math.Random random = math.Random(PlacentaStyle.seed + 2);
    return <List<Offset>>[
      for (int k = 0; k < PlacentaStyle.fibres; k++)
        () {
          final double x = random.nextDouble() * _w;
          final double top = deciduaAt(x) + 0.4;
          final double y = top + random.nextDouble() * (_h - 0.3 - top);
          final double turn = (random.nextDouble() - 0.5) * 0.7;
          final double length =
              PlacentaStyle.fibreLength * (0.6 + 0.8 * random.nextDouble());
          final double phase = random.nextDouble() * math.pi * 2;
          return <Offset>[
            for (int i = 0; i <= 12; i++)
              () {
                final double s = (i / 12 - 0.5) * length;
                return at(
                  x + s * math.cos(turn),
                  y +
                      s * math.sin(turn) +
                      PlacentaStyle.fibreWave * math.sin(phase + s * 2.4),
                );
              }(),
          ];
        }(),
    ];
  }();

  /// The chorionic vessels cut at the front edge, in the chorionic plate,
  /// each with its radius and whether it is a vein: an artery just under
  /// the amnion, a vein deeper, as Gray has them.
  late final List<(Offset, double, bool)> cutVessels = <(Offset, double, bool)>[
    for (final (List<Offset> course, bool vein) in PlacentaAnatomy.chorionic)
      if (course.last.dy == 0)
        () {
          final double r =
              (vein
                  ? PlacentaAnatomy.chorionicVein
                  : PlacentaAnatomy.chorionicArtery) /
              2;
          final double y = PlacentaAnatomy.amnion + r + (vein ? 0.15 : 0);
          return (at(course.last.dx, y), mm(r), vein);
        }(),
  ];

  // The fetal surface.

  /// A point of the fetal surface, [x] across and [z] back, in the scene.
  Offset onTop(double x, double z) => at(x, 0, z);

  /// The chorionic vessels over it, the veins and then the arteries, as
  /// tubes.
  late final List<TubeCourse> chorionicVeins = <TubeCourse>[
    for (final (List<Offset> course, bool vein) in PlacentaAnatomy.chorionic)
      if (vein) _vessel(course, PlacentaAnatomy.chorionicVein),
  ];
  late final List<TubeCourse> chorionicArteries = <TubeCourse>[
    for (final (List<Offset> course, bool vein) in PlacentaAnatomy.chorionic)
      if (!vein) _vessel(course, PlacentaAnatomy.chorionicArtery),
  ];

  TubeCourse _vessel(List<Offset> course, double breadth) => TubeCourse(
    AnatomyTube(
      <Offset>[for (final Offset p in course) p],
      <double>[for (int i = 0; i < course.length; i++) breadth / 2],
    ),
    (Offset p) => onTop(p.dx, p.dy),
    scale,
    mm(0.3),
    bend: 0.6,
  );

  // The cord.

  /// Its flank, a lit tube from the surface up to where it is cut, in the
  /// scene.
  late final TubeCourse cord = TubeCourse(
    AnatomyTube(
      <Offset>[
        project(_root.dx, 0, _root.dy),
        project(_root.dx, -PlacentaAnatomy.cordShown / 2, _root.dy),
        project(_root.dx, -PlacentaAnatomy.cordShown, _root.dy),
      ],
      const <double>[_cordRadius, _cordRadius, _cordRadius],
    ),
    place,
    scale,
    mm(0.3),
    bend: 0.6,
  );

  /// Its foot on the surface and its cut end, each the ring round it as
  /// the screen shows it, in the scene.
  late final Path cordFoot = Path()
    ..addPolygon(<Offset>[
      for (final Offset p in _ring(0, _cordRadius)) place(p),
    ], true);
  late final Path cordEnd = Path()
    ..addPolygon(<Offset>[
      for (final Offset p in _ring(-PlacentaAnatomy.cordShown, _cordRadius))
        place(p),
    ], true);

  /// Its vein and its two arteries on its cut end, each with its radius,
  /// across and back of the cord's middle.
  static const List<(double, double, double)> _cordVessels =
      <(double, double, double)>[
        (2.4, 0, PlacentaAnatomy.cordVein / 2),
        (-3.4, -3.2, PlacentaAnatomy.cordArtery / 2),
        (-3.4, 3.2, PlacentaAnatomy.cordArtery / 2),
      ];

  /// Each of them on its cut end, the vein first, as a ring in the scene,
  /// [share] of its radius.
  List<Path> cordVessels(double share) => <Path>[
    for (final (double dx, double dz, double r) in _cordVessels)
      Path()..addPolygon(<Offset>[
        for (final Offset p in _ring(
          -PlacentaAnatomy.cordShown,
          r * share,
          dx: dx,
          dz: dz,
          n: 32,
        ))
          place(p),
      ], true),
  ];

  /// Its outline as the screen shows it, in the scene.
  late final Path cordOutline = Path()
    ..addPolygon(<Offset>[for (final Offset p in _cordHull) place(p)], true);

  /// Its two arteries winding round it, as its jelly shows them: each a run
  /// of short lengths from its foot to its cut end, where each meets its
  /// place on the cut, and how near the eye each length lies, from 1 in
  /// front to -1 behind, in the scene.
  late final List<List<(Offset, Offset, double)>> cordWindings = () {
    final List<List<(Offset, Offset, double)>> out =
        <List<(Offset, Offset, double)>>[];
    for (final (double dx, double dz, double _) in _cordVessels.skip(1)) {
      final double r = math.sqrt(dx * dx + dz * dz);
      // Where it lies on the cut, round the cord's middle: sideways by its
      // sine, toward the eye by its cosine.
      final double top = math.atan2(dx, -dz);
      const int n = 48;
      Offset at(int i) {
        final double t = i / n;
        final double a =
            top -
            2 *
                math.pi *
                PlacentaAnatomy.coiling *
                PlacentaAnatomy.cordShown *
                (1 - t);
        return place(
          project(
            _root.dx + r * math.sin(a),
            -PlacentaAnatomy.cordShown * t,
            _root.dy - r * math.cos(a),
          ),
        );
      }

      out.add(<(Offset, Offset, double)>[
        for (int i = 0; i < n; i++)
          (
            at(i),
            at(i + 1),
            math.cos(
              top -
                  2 *
                      math.pi *
                      PlacentaAnatomy.coiling *
                      PlacentaAnatomy.cordShown *
                      (1 - (i + 0.5) / n),
            ),
          ),
      ]);
    }
    return out;
  }();

  // The right side, a second cut.

  /// A point of the side, [z] back and [y] down, in the scene.
  Offset onSide(double z, double y) => at(_w, y, z);

  Path _sideBand(double from, double to) => _polygon(<Offset>[
    project(_w, from),
    project(_w, from, _d),
    project(_w, to, _d),
    project(_w, to),
  ]);

  /// Its layers, as bands from the front edge back, in the scene: the
  /// chorionic plate, the intervillous space, the basal plate with the
  /// decidua under it, and the uterine muscle.
  late final Path sidePlate = _sideBand(0, PlacentaAnatomy.chorionicPlate);
  late final Path sideSpace = _sideBand(
    PlacentaAnatomy.chorionicPlate,
    PlacentaAnatomy.thickness - PlacentaAnatomy.basalPlate,
  );
  late final Path sideDecidua = _sideBand(
    PlacentaAnatomy.thickness - PlacentaAnatomy.basalPlate,
    PlacentaAnatomy.thickness + PlacentaAnatomy.decidua,
  );
  late final Path sideMuscle = _sideBand(
    PlacentaAnatomy.thickness + PlacentaAnatomy.decidua,
    _h,
  );

  /// The villi cut on it, in the scene, by size.
  late final List<PlacentaClumps> sideClumps = () {
    final math.Random random = math.Random(PlacentaStyle.seed + 3);
    final List<List<double>> bins = <List<double>>[
      <double>[],
      <double>[],
      <double>[],
    ];
    const double top = PlacentaAnatomy.chorionicPlate + 0.4;
    const double bottom =
        PlacentaAnatomy.thickness - PlacentaAnatomy.basalPlate - 0.3;
    final int n = (_d * (bottom - top) * PlacentaStyle.fillPerMm2 * 0.35)
        .round();
    for (int i = 0; i < n; i++) {
      final double z = 0.3 + random.nextDouble() * (_d - 0.6);
      final double y = top + random.nextDouble() * (bottom - top);
      final double u = random.nextDouble();
      final int bin = u < 0.45
          ? 0
          : u < 0.8
          ? 1
          : 2;
      final Offset q = onSide(z, y);
      bins[bin]
        ..add(q.dx)
        ..add(q.dy);
    }
    return <PlacentaClumps>[
      for (int k = 0; k < 3; k++)
        (
          points: Float32List.fromList(bins[k]),
          radius:
              mm(
                PlacentaAnatomy.clumpMin +
                    (PlacentaAnatomy.clumpMax - PlacentaAnatomy.clumpMin) *
                        k /
                        2,
              ) *
              0.7,
        ),
    ];
  }();

  // The place its tissue is sampled, and its names.

  /// In the villi of the left lobule, above its central cavity.
  late final Offset site = at(PlacentaAnatomy.site.dx, PlacentaAnatomy.site.dy);

  /// The points its names point at, in the scene, each column's spread
  /// down the block so that each name can stand level with its own: the
  /// villi at the site and the decidua under it; the chorionic plate where
  /// the fetal surface shows it, in front; the cord's flank; the right
  /// lobule's central cavity, in its upper half (at its middle its name
  /// jolted 1.5016 pixels a frame, stepping back out, over the 1.5 the zoom
  /// allows), and its spiral artery low in the uterine muscle.
  late final Offset villiName = site;
  late final Offset deciduaName = _inDecidua(PlacentaAnatomy.site.dx);
  late final Offset plateName = onTop(5, 6);
  late final Offset cordName = place(
    project(_root.dx, -PlacentaAnatomy.cordShown * 0.55, _root.dy) +
        const Offset(_cordRadius * 0.8, 0),
  );
  late final Offset spaceName = () {
    final Offset c = cavityOf(PlacentaAnatomy.lobules.last);
    return at(c.dx, c.dy - 3);
  }();
  late final Offset spiralName = () {
    final double x = PlacentaAnatomy.lobules.last;
    const double y = _h - 2.5;
    return at(spiralAt(x, y), y);
  }();

  /// Where its name for [home] points.
  Offset nameOf(PlacentaHome home) => switch (home) {
    PlacentaHome.villi => villiName,
    PlacentaHome.decidua => deciduaName,
  };

  Offset _inDecidua(double x) => at(x, (basalFloorAt(x) + deciduaAt(x)) / 2);

  // Helpers.

  /// An ellipse [width] across and [height] tall round [c] in the face's
  /// millimetres, in the scene.
  Path _ellipse(Offset c, double width, double height) =>
      Path()..addPolygon(<Offset>[
        for (int k = 0; k < 40; k++)
          at(
            c.dx + width / 2 * math.cos(2 * math.pi * k / 40),
            c.dy + height / 2 * math.sin(2 * math.pi * k / 40),
          ),
      ], true);

  /// The polygon through [mm], points of the screen's millimetres, in the
  /// scene.
  Path _polygon(List<Offset> mm) =>
      Path()..addPolygon(<Offset>[for (final Offset p in mm) place(p)], true);
}

/// The convex hull of [points], round from its leftmost.
List<Offset> _hull(List<Offset> points) {
  final List<Offset> sorted = List<Offset>.of(points)
    ..sort(
      (Offset a, Offset b) =>
          a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy),
    );
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final List<Offset> lower = <Offset>[];
  for (final Offset p in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final List<Offset> upper = <Offset>[];
  for (final Offset p in sorted.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  return <Offset>[
    ...lower.sublist(0, lower.length - 1),
    ...upper.sublist(0, upper.length - 1),
  ];
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
