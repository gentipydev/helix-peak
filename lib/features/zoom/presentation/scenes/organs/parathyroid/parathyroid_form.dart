import 'dart:math' as math;
import 'dart:ui';

import '../../tube_course.dart';
import 'parathyroid_anatomy.dart';
import 'parathyroid_style.dart';

/// Where in the parathyroid the zoom's cell lives, which its drawing
/// lights in the mark, by the Atlas's name for the cell. By the kind of
/// cell, never by gene.
enum ParathyroidHome {
  /// The parenchyma, its chief cells: any cell the Atlas finds in the
  /// gland that is not one of the others, and the tissue's own cells where
  /// it names none.
  chief,

  /// The oxyphil nodules.
  oxyphil,

  /// The stromal fat.
  fat;

  /// Where a cell the Atlas calls [cell] lives.
  static ParathyroidHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('oxyphil')) {
      return oxyphil;
    }
    if (name.contains('adipocyte') || name.contains('fat')) {
      return fat;
    }
    return chief;
  }

  /// What its name says.
  String get word => switch (this) {
    chief => 'chief cells',
    oxyphil => 'oxyphil cells',
    fat => 'fat cells',
  };
}

/// The parathyroid as the zoom's organ scene draws it, seen from behind on
/// the back of its thyroid lobe and cut through its thickness: every part
/// in the scene's units at its real size, the middle of the view at the
/// origin.
///
/// It is drawn from general anatomy ([ParathyroidAnatomy]) on its own: the
/// body has no parathyroid, so the scene comes up over the body's drawing
/// of the thyroid. Everything here is geometry: what it is drawn in is
/// `ParathyroidArt`'s.
final class ParathyroidForm {
  ParathyroidForm({required this.view, this.home = ParathyroidHome.chief})
    : scale = 1e-3 / view;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final ParathyroidHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => mm * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => p / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  // The anatomy in millimetres, built once for every gland.

  static final double _cos = math.cos(ParathyroidAnatomy.tilt);
  static final double _sin = math.sin(ParathyroidAnatomy.tilt);

  /// A point of the gland's own frame (x across it, y down its long axis)
  /// in the view.
  static Offset glandAt(Offset local) =>
      ParathyroidAnatomy.gland +
      Offset(
        local.dx * _cos - local.dy * _sin,
        local.dx * _sin + local.dy * _cos,
      );

  /// How far out the gland's outline reaches at [angle] in its own frame,
  /// from its middle: an oval a little uneven, notched at its hilum.
  static Offset _rimLocal(double angle) {
    const double a = ParathyroidAnatomy.breadth / 2;
    const double b = ParathyroidAnatomy.length / 2;
    final double r =
        1 +
        0.035 * math.sin(3 * angle + 0.7) +
        0.02 * math.sin(5 * angle + 2.1);
    // The hilum's way: down its long axis, turned toward its medial side.
    final double from = _wrap(
      angle - (math.pi / 2 + ParathyroidAnatomy.hilumAngle),
    );
    final double notch = math.exp(
      -(from * from) /
          (ParathyroidAnatomy.hilumWidth * ParathyroidAnatomy.hilumWidth),
    );
    final Offset p = Offset(math.cos(angle) * a, math.sin(angle) * b) * r;
    final double reach = p.distance;
    return reach <= 0
        ? p
        : p * ((reach - ParathyroidAnatomy.hilumDepth * notch) / reach);
  }

  static double _wrap(double a) => math.atan2(math.sin(a), math.cos(a));

  /// The gland's outline, round from its lower pole, in millimetres.
  static final List<Offset> _outlineMm = <Offset>[
    for (int i = 0; i < ParathyroidStyle.outlinePoints; i++)
      glandAt(
        _rimLocal(
          math.pi / 2 + 2 * math.pi * i / ParathyroidStyle.outlinePoints,
        ),
      ),
  ];

  /// The hilum, on the outline, in millimetres.
  static final Offset _hilumMm = glandAt(
    _rimLocal(math.pi / 2 + ParathyroidAnatomy.hilumAngle),
  );

  /// The way into the gland at each point of its outline, a unit.
  static final List<Offset> _inMm = () {
    final int n = _outlineMm.length;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t =
              _outlineMm[(i + 1) % n] - _outlineMm[(i - 1 + n) % n];
          final Offset left = Offset(-t.dy, t.dx) / t.distance;
          return _inside(_outlineMm, _outlineMm[i] + left * 0.05)
              ? left
              : -left;
        }(),
    ];
  }();

  /// The cut face's edge under the capsule, turning away.
  static final List<Offset> _rimInnerMm = <Offset>[
    for (int i = 0; i < _outlineMm.length; i++)
      _outlineMm[i] + _inMm[i] * ParathyroidStyle.rim,
  ];

  /// Whether [mm] lies inside the gland, and how far in from its capsule.
  static bool inGland(Offset mm) => _inside(_outlineMm, mm);
  static double depth(Offset mm) {
    final double edge = _toLine(_outlineMm, mm);
    return _inside(_outlineMm, mm) ? edge : -edge;
  }

  /// The oxyphil nodules, each a ring a little uneven, in millimetres.
  static final List<List<Offset>> _nodulesMm = <List<Offset>>[
    for (int k = 0; k < ParathyroidAnatomy.oxyphil.length; k++)
      () {
        final (Offset c, double r) = ParathyroidAnatomy.oxyphil[k];
        return <Offset>[
          for (int i = 0; i < 48; i++)
            () {
              final double t = 2 * math.pi * i / 48;
              final double reach =
                  r *
                  (1 +
                      0.09 * math.sin(3 * t + k * 1.7) +
                      0.05 * math.sin(5 * t + k * 0.6));
              return glandAt(
                c + Offset(math.cos(t) * reach, math.sin(t) * reach * 0.85),
              );
            }(),
        ];
      }(),
  ];

  /// Whether [mm] lies in an oxyphil nodule, or [margin] round one.
  static bool inNodule(Offset mm, {double margin = 0}) {
    for (int k = 0; k < _nodulesMm.length; k++) {
      final List<Offset> n = _nodulesMm[k];
      if (_inside(n, mm) || (margin > 0 && _toLine(n, mm) < margin)) {
        return true;
      }
    }
    return false;
  }

  /// The place the body goes in, in millimetres.
  static final Offset _siteMm = glandAt(ParathyroidAnatomy.site);

  /// The stromal fat: a cell every [ParathyroidAnatomy.fatCell], about
  /// [ParathyroidAnatomy.fatShare] of the cut face, most in its clusters,
  /// none in a nodule nor at the capsule, nor on the place the body goes
  /// in.
  static final List<Offset> _fatMm = () {
    final math.Random random = math.Random(ParathyroidStyle.seed);
    double area = 0;
    for (int i = 0; i < _outlineMm.length; i++) {
      final Offset a = _outlineMm[i];
      final Offset b = _outlineMm[(i + 1) % _outlineMm.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    area = area.abs() / 2;
    const double cell = ParathyroidAnatomy.fatCell;
    final int count = (ParathyroidAnatomy.fatShare * area / (cell * cell))
        .round();
    double weights = 0;
    for (final (Offset _, double spread) in ParathyroidAnatomy.fatClusters) {
      weights += spread * spread;
    }
    double gauss() {
      final double u = math.max(1e-9, random.nextDouble());
      final double v = random.nextDouble();
      return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
    }

    final List<Offset> out = <Offset>[];
    const double apart = cell * 0.92;
    int tries = 0;
    while (out.length < count && tries < count * 40) {
      tries++;
      Offset local;
      if (random.nextDouble() < ParathyroidAnatomy.fatScattered) {
        local = Offset(
          (random.nextDouble() - 0.5) * ParathyroidAnatomy.breadth,
          (random.nextDouble() - 0.5) * ParathyroidAnatomy.length,
        );
      } else {
        double pick = random.nextDouble() * weights;
        (Offset, double) cluster = ParathyroidAnatomy.fatClusters.last;
        for (final (Offset, double) c in ParathyroidAnatomy.fatClusters) {
          pick -= c.$2 * c.$2;
          if (pick <= 0) {
            cluster = c;
            break;
          }
        }
        local = cluster.$1 + Offset(gauss(), gauss()) * cluster.$2;
      }
      final Offset p = glandAt(local);
      if (depth(p) < ParathyroidStyle.fatClear + ParathyroidStyle.rim ||
          inNodule(p, margin: ParathyroidStyle.fatClear) ||
          (p - _siteMm).distance < 0.3) {
        continue;
      }
      bool near = false;
      for (final Offset q in out) {
        if ((q - p).distanceSquared < apart * apart) {
          near = true;
          break;
        }
      }
      if (!near) {
        out.add(p);
      }
    }
    return out;
  }();

  /// The vessels in the gland, from the hilum along its septa, in
  /// millimetres: the first runs from the hilum itself.
  static final List<List<Offset>> _vesselsMm = <List<Offset>>[
    for (int k = 0; k < ParathyroidAnatomy.vessels.length; k++)
      _smoothLine(<Offset>[
        if (k == 0) _hilumMm else glandAt(ParathyroidAnatomy.vessels[k].first),
        for (final Offset p in ParathyroidAnatomy.vessels[k].skip(1))
          glandAt(p),
      ], 0.05),
  ];

  /// The veins beside them, a little apart, on their lateral side.
  static final List<List<Offset>> _veinsMm = <List<Offset>>[
    for (final List<Offset> line in _vesselsMm)
      <Offset>[
        for (int i = 0; i < line.length; i++)
          () {
            final Offset t =
                line[math.min(line.length - 1, i + 1)] -
                line[math.max(0, i - 1)];
            final double length = t.distance;
            final Offset across = length <= 0
                ? Offset.zero
                : Offset(-t.dy, t.dx) / length;
            return line[i] + across * ParathyroidStyle.veinApart;
          }(),
      ],
  ];

  /// The septa: each from the capsule in, toward the gland's middle.
  static final List<(Offset, Offset)> _septaMm = () {
    final List<double> along = _along(<Offset>[
      ..._outlineMm,
      _outlineMm.first,
    ]);
    return <(Offset, Offset)>[
      for (final (double share, double reach) in ParathyroidAnatomy.septa)
        () {
          final int i = _indexAt(along, along.last * share) % _outlineMm.length;
          final Offset a = _outlineMm[i];
          final Offset toward = ParathyroidAnatomy.gland - a;
          final Offset way = (_inMm[i] + toward / toward.distance) / 2;
          return (a, a + way / way.distance * reach);
        }(),
    ];
  }();

  /// The lobe's outline, closely, in millimetres.
  static final List<Offset> _lobeMm = _closedCurve(
    ParathyroidAnatomy.lobe,
    0.3,
  );

  /// The lobe's medial border, the stretch of its outline that shows.
  static final List<Offset> _lobeBorderMm = <Offset>[
    for (final Offset p in _lobeMm)
      if (p.dx < -2 && p.dy > -16 && p.dy < 16) p,
  ];

  /// How much of the lobe shows at [mm]: all of it about the gland, none
  /// above and below where the names stand, nor out by the view's side.
  static double lobeShownAt(Offset mm) {
    const double p = ParathyroidAnatomy.lobeRound;
    final Offset d = mm - ParathyroidAnatomy.lobeMiddle;
    final double x = (d.dx / ParathyroidAnatomy.lobeAcross).abs();
    final double y = (d.dy / ParathyroidAnatomy.lobeDown).abs();
    final double r = math
        .pow(math.pow(x, p) + math.pow(y, p), 1 / p)
        .toDouble();
    return 1 -
        _smooth(
          (r - ParathyroidAnatomy.lobeWhole) /
              (ParathyroidAnatomy.lobeGone - ParathyroidAnatomy.lobeWhole),
        );
  }

  // The parts, laid in the scene.

  /// The gland's outline, the capsule, and the points it is followed by.
  late final List<Offset> outlinePoints = _placed(_outlineMm);
  late final Path outline = Path()..addPolygon(outlinePoints, true);
  late final Rect box = _bounds(outlinePoints);

  /// The cut face's edge under the capsule and the line it turns away to,
  /// point for point, all the way round.
  late final List<Offset> rimInner = _placed(_rimInnerMm);

  late final List<List<Offset>> nodules = <List<Offset>>[
    for (final List<Offset> n in _nodulesMm) _placed(n),
  ];
  late final List<Offset> fat = _placed(_fatMm);
  late final List<List<Offset>> vessels = <List<Offset>>[
    for (final List<Offset> v in _vesselsMm) _placed(v),
  ];
  late final List<List<Offset>> veins = <List<Offset>>[
    for (final List<Offset> v in _veinsMm) _placed(v),
  ];
  late final List<(Offset, Offset)> septa = <(Offset, Offset)>[
    for (final (Offset a, Offset b) in _septaMm) (place(a), place(b)),
  ];

  /// The lobe's outline and its medial border, in the scene; how much of
  /// it shows at a point of the scene.
  late final List<Offset> lobe = _placed(_lobeMm);
  late final List<Offset> lobeBorder = _placed(_lobeBorderMm);
  double lobeShown(Offset p) => lobeShownAt(toMm(p));

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(ParathyroidStyle.tubeRow), bend: 0.9);

  /// The inferior thyroid artery, its branches up and down the lobe, and
  /// the gland's own artery to its hilum; the nerve over them.
  late final TubeCourse artery = _tube(ParathyroidAnatomy.artery);
  late final TubeCourse ascending = _tube(ParathyroidAnatomy.ascending);
  late final TubeCourse descending = _tube(ParathyroidAnatomy.descending);
  late final TubeCourse own = _tube(
    AnatomyTube(
      <Offset>[
        ...ParathyroidAnatomy.own,
        _hilumMm + (_hilumMm - ParathyroidAnatomy.gland) * 0.06,
      ],
      <double>[
        for (int i = 0; i <= ParathyroidAnatomy.own.length; i++)
          ParathyroidAnatomy.ownRadius,
      ],
    ),
  );
  late final TubeCourse nerve = _tube(ParathyroidAnatomy.nerve);

  /// What is drawn outside the gland, for its names to keep clear of.
  late final List<TubeCourse> beside = <TubeCourse>[
    artery,
    ascending,
    descending,
    own,
    nerve,
  ];

  /// Where the body goes in: in the parenchyma above the gland's middle.
  late final Offset site = place(_siteMm);

  // Where the parts are named.

  /// An oxyphil nodule and a cluster of the fat in the gland's lower half,
  /// named below it; the lobe, the artery on the lobe's back and the nerve
  /// beside the gland.
  late final Offset oxyphilName = place(
    glandAt(ParathyroidAnatomy.oxyphil[2].$1),
  );
  late final Offset fatName = place(
    glandAt(ParathyroidAnatomy.fatClusters.last.$1),
  );
  late final Offset thyroidName = place(ParathyroidAnatomy.thyroidName);
  late final Offset arteryName = artery.centres[artery.length * 2 ~/ 5];
  late final Offset nerveName = place(ParathyroidAnatomy.nerveName);

  /// Where the zoom's cell's home is named.
  Offset get homeName => switch (home) {
    ParathyroidHome.chief => site,
    ParathyroidHome.oxyphil => oxyphilName,
    ParathyroidHome.fat => fatName,
  };

  /// Whether [p] lies inside the gland's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  /// For tests: the gland's outline, its hilum, its fat and its site in
  /// millimetres.
  static List<Offset> get outlineMm => _outlineMm;
  static Offset get hilumMm => _hilumMm;
  static List<Offset> get fatMm => _fatMm;
  static Offset get siteMm => _siteMm;
}

/// A closed curve through [knots], in points [step] apart at most.
List<Offset> _closedCurve(List<Offset> knots, double step) {
  final int n = knots.length;
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset p0 = knots[(i - 1 + n) % n];
    final Offset p1 = knots[i];
    final Offset p2 = knots[(i + 1) % n];
    final Offset p3 = knots[(i + 2) % n];
    final int steps = math.max(2, ((p2 - p1).distance / step).ceil());
    for (int k = 0; k < steps; k++) {
      out.add(_catmull(p0, p1, p2, p3, k / steps));
    }
  }
  return out;
}

/// A curve through [knots], in points [step] apart at most.
List<Offset> _smoothLine(List<Offset> knots, double step) {
  final List<Offset> out = <Offset>[knots.first];
  for (int i = 0; i + 1 < knots.length; i++) {
    final Offset p0 = i > 0 ? knots[i - 1] : knots[i] * 2 - knots[i + 1];
    final Offset p1 = knots[i];
    final Offset p2 = knots[i + 1];
    final Offset p3 = i + 2 < knots.length
        ? knots[i + 2]
        : knots[i + 1] * 2 - knots[i];
    final int steps = math.max(2, ((p2 - p1).distance / step).ceil());
    for (int k = 1; k <= steps; k++) {
      out.add(_catmull(p0, p1, p2, p3, k / steps));
    }
  }
  return out;
}

Offset _catmull(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final double t2 = t * t;
  final double t3 = t2 * t;
  return (p1 * 2 +
          (p2 - p0) * t +
          (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
          (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
      0.5;
}

/// The distance along [line] at each of its points.
List<double> _along(List<Offset> line) {
  final List<double> out = <double>[0];
  for (int i = 1; i < line.length; i++) {
    out.add(out.last + (line[i] - line[i - 1]).distance);
  }
  return out;
}

/// The point of [along] nearest [d].
int _indexAt(List<double> along, double d) {
  int best = 0;
  for (int i = 1; i < along.length; i++) {
    if ((along[i] - d).abs() < (along[best] - d).abs()) {
      best = i;
    }
  }
  return best;
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

double _toSegment(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double length = ab.distanceSquared;
  final double t = length <= 0
      ? 0
      : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// How far [p] lies from the closed outline [line].
double _toLine(List<Offset> line, Offset p) {
  double best = double.infinity;
  final int n = line.length;
  for (int i = 0; i < n; i++) {
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
