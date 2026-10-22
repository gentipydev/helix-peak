import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'heart_anatomy.dart';
import 'heart_style.dart';

/// A great vessel: cut open down its length from its root as far as [cut],
/// its two walls there, each laid between its outer edge and its inner one
/// point for point, and the lumen between them; and whole from there on,
/// a lit tube. The infundibulum is one too, cut open all its length, its
/// walls heart muscle.
final class HeartVessel {
  HeartVessel._(this._spec, this.course, double scale) {
    final int n = course.length;
    final double wall = _spec.wall * scale;
    final double taper = _spec.taper * scale;
    // A wall that grows out of nothing over [taper] from the start: the
    // outflow rising out of its ventricle's cavity.
    double wallAt(int i) =>
        taper <= 0 ? wall : wall * _smooth(course.arc[i] / taper);
    int cutRow = 0;
    while (cutRow < n - 1 && course.arc[cutRow] < _spec.cutTo * scale) {
      cutRow++;
    }
    cut = _spec.cutTo >= double.infinity ? n - 1 : cutRow;
    final List<Offset> outerLeft = <Offset>[
      for (int i = 0; i < n; i++) course.at(i, 1),
    ];
    final List<Offset> outerRight = <Offset>[
      for (int i = 0; i < n; i++) course.at(i, -1),
    ];
    outer = <Offset>[...outerLeft, ...outerRight.reversed];
    final List<Offset> innerLeft = <Offset>[
      for (int i = 0; i <= cut; i++)
        course.centres[i] +
            course.across[i] * math.max(0, course.plus[i] - wallAt(i)),
    ];
    final List<Offset> innerRight = <Offset>[
      for (int i = 0; i <= cut; i++)
        course.centres[i] -
            course.across[i] * math.max(0, course.minus[i] - wallAt(i)),
    ];
    walls = cut <= 0
        ? const <(List<Offset>, List<Offset>)>[]
        : <(List<Offset>, List<Offset>)>[
            (outerLeft.sublist(0, cut + 1), innerLeft),
            (outerRight.sublist(0, cut + 1), innerRight),
          ];
    lumen = cut <= 0
        ? const <Offset>[]
        : <Offset>[...innerLeft, ...innerRight.reversed];
  }

  /// A vessel of the heart's own frame, in millimetres.
  factory HeartVessel._mm(_VesselSpec spec) => HeartVessel._(
    spec,
    TubeCourse(
      AnatomyTube(spec.knots, spec.radii),
      (Offset p) => p,
      1,
      HeartStyle.edgeStep,
      bend: 0.9,
    ),
    1,
  );

  final _VesselSpec _spec;

  /// Its course, row by row along it.
  final TubeCourse course;

  /// The row up to which it is cut open from its root: none where it is
  /// whole all its length, its last where it is cut open all of it.
  late final int cut;

  late final List<(List<Offset>, List<Offset>)> walls;
  late final List<Offset> lumen;

  /// Its outside, all of it.
  late final List<Offset> outer;

  bool get artery => _spec.artery;
  bool get muscle => _spec.muscle;

  /// Whether its far end is cut short, as a plate cuts what it has taken
  /// away, rather than running on into its branches.
  bool get endCut => _spec.endCut;

  /// Whether any of it is whole, from [cut] on.
  bool get whole => cut < course.length - 1;

  /// Its walls' inner edges, along which its lumen is rimmed.
  List<List<Offset>> get rims => <List<Offset>>[
    for (final (List<Offset> _, List<Offset> inner) in walls) inner,
  ];

  /// The same vessel laid in the scene by [place], a millimetre [scale]
  /// long there.
  HeartVessel _placed(Offset Function(Offset) place, double scale) =>
      HeartVessel._(
        _spec,
        TubeCourse(
          AnatomyTube(_spec.knots, _spec.radii),
          place,
          scale,
          HeartStyle.edgeStep * scale,
          bend: 0.9,
        ),
        scale,
      );
}

/// What a great vessel is: its course and its radii along it, its wall, how
/// far from its root it is cut open, whether an artery, whether its walls
/// are heart muscle, and how far up its walls grow out of nothing.
final class _VesselSpec {
  const _VesselSpec(
    this.knots,
    this.radii,
    this.wall, {
    required this.cutTo,
    required this.artery,
    this.muscle = false,
    this.taper = 0,
    this.endCut = true,
  });

  final List<Offset> knots;
  final List<double> radii;
  final double wall;
  final double cutTo;
  final bool artery;
  final bool muscle;
  final double taper;
  final bool endCut;
}

/// A chamber's cavity, emptied: its shape, closed across its openings, and
/// its walls' inner edges, the runs of it that are wall and not opening.
final class HeartCavity {
  HeartCavity({required this.shape, required this.rims});

  final List<Offset> shape;
  final List<List<Offset>> rims;

  HeartCavity _placed(Offset Function(Offset) place) => HeartCavity(
    shape: _map(shape, place),
    rims: <List<Offset>>[for (final List<Offset> r in rims) _map(r, place)],
  );
}

/// A coronary artery cut across: where, how wide its lumen is, and how
/// wide with its wall.
typedef HeartCoronary = ({Offset centre, double lumen, double outer});

/// The heart as the zoom's organ scene draws it for heart muscle: cut open
/// from front to back and seen from the front, every part in the scene's
/// units at its real size.
///
/// The heart is drawn from general anatomy ([HeartAnatomy]) in its own
/// frame, a composite of the cut every textbook draws, and laid on the
/// body's outline of it: as high as that outline's middle, and across so
/// that the left ventricle's free wall, at the height the body goes in, runs
/// through the place the body goes in ([site]), which is the body's. The
/// body's outline is grown to the heart's own size first ([realFor]), so
/// the step from the body draws it in toward the heart's outline by a few
/// millimetres ([pathAt]). Everything here is geometry: what it is drawn in
/// is `HeartArt`'s.
final class HeartForm {
  HeartForm({
    required List<Offset> diagram,
    required this.site,
    required this.view,
  }) : scale = 1e-3 / view {
    final _Composite c = _Composite.instance;
    final double middle = c.box.center.dy;
    _origin = Offset(c.freeWallMiddleAt(site.dy / scale + middle), middle);
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(HeartStyle.morphSpan)
        .points;
    final List<Offset> placed = _map(c.outline, place);
    if (_area(placed).sign != _area(diagramDense).sign) {
      placed.setAll(0, placed.reversed.toList());
    }
    outlinePoints = placed;
    outline = _polygon(placed);
    box = _bounds(placed);
    _morph = OutlineMorph(
      template: placed,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: HeartStyle.morphPoints,
      bed: mm(HeartStyle.bed),
      marks: _marks,
    );
  }

  /// The heart where the body draws it as [part], in a view [view] metres
  /// across.
  factory HeartForm.place({required AnatomyPart part, required double view}) {
    final double real = realFor(part);
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return HeartForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      view: view,
    );
  }

  /// How many times the size the body draws it at the heart really is: the
  /// body's outline grown to cover as much as the heart's own does. The
  /// anatomogram draws a heart about seven tenths the size of one.
  static double realFor(AnatomyPart part) {
    final Rect heart = _Composite.instance.box;
    final Rect drawn = part.box;
    return math.sqrt(
      heart.width * heart.height * 1e-6 / (drawn.width * drawn.height),
    );
  }

  /// Where the body goes into the heart, in the scene: in the left
  /// ventricle's free wall.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long a millimetre is in the scene.
  final double scale;

  /// The heart's point that lies at the scene's origin's height and at the
  /// site's x, in millimetres.
  late final Offset _origin;

  late final OutlineMorph _morph;

  /// The heart's outline, all of it: its chambers, the fat of its grooves
  /// and the great vessels as far as they are drawn.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the heart's frame, in millimetres, in the scene.
  Offset place(Offset mm) => Offset(
    (mm.dx - _origin.dx) * scale + site.dx,
    (mm.dy - _origin.dy) * scale,
  );

  /// A point of the scene in the heart's frame, in millimetres.
  Offset toMm(Offset p) =>
      Offset((p.dx - site.dx) / scale + _origin.dx, p.dy / scale + _origin.dy);

  /// How far, in millimetres, the heart's box's middle lies across from the
  /// body's outline's: what laying its free wall through the site costs.
  double get anchorShift => place(_Composite.instance.box.center).dx / scale;

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the heart's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  // The chambers: each one's muscle, closed round its outside, and its
  // cavity, its inner edge rough with trabeculae in the ventricles.

  late final List<Offset> lvMuscle = _map(_Composite.instance.lvMuscle, place);
  late final List<Offset> rvMuscle = _map(_Composite.instance.rvMuscle, place);
  late final List<Offset> raMuscle = _map(_Composite.instance.raMuscle, place);
  late final List<Offset> laMuscle = _map(_Composite.instance.laMuscle, place);
  late final HeartCavity lvCavity = _Composite.instance.lvCavity._placed(place);
  late final HeartCavity rvCavity = _Composite.instance.rvCavity._placed(place);
  late final HeartCavity raCavity = _Composite.instance.raCavity._placed(place);
  late final HeartCavity laCavity = _Composite.instance.laCavity._placed(place);

  /// The muscle's cut faces, each laid between its outer edge and its
  /// inner one point for point: the left ventricle's free wall round the
  /// apex, the septum, the right ventricle's free wall and the atria's.
  late final List<(List<Offset>, List<Offset>)> bands =
      <(List<Offset>, List<Offset>)>[
        for (final (List<Offset> a, List<Offset> b)
            in _Composite.instance.bands)
          (_map(a, place), _map(b, place)),
      ];

  /// The muscle's inner edges, along which a crisp line is drawn: the
  /// atria's, and the ventricles'.
  late final List<List<Offset>> atrialEdges = <List<Offset>>[
    for (final List<Offset> edge in _Composite.instance.atrialEdges)
      _map(edge, place),
  ];
  late final List<List<Offset>> innerEdges = <List<Offset>>[
    for (final List<Offset> edge in _Composite.instance.innerEdges)
      _map(edge, place),
  ];

  /// The papillary muscles' and the moderator band's edges, drawn where
  /// they stand in the ventricles' cavities.
  late final List<List<Offset>> columnEdges = <List<Offset>>[
    for (final List<Offset> edge in _Composite.instance.columnEdges)
      _map(edge, place),
  ];

  /// The compact free wall's two edges, base to apex point for point, and
  /// the septum's, base to the right ventricle's apex: where the walls'
  /// thicknesses are measured.
  late final List<Offset> freeEndo = _map(_Composite.instance.freeEndo, place);
  late final List<Offset> freeEpi = _map(_Composite.instance.freeEpi, place);
  late final List<Offset> septumLv = _map(_Composite.instance.septumLv, place);
  late final List<Offset> septumRv = _map(_Composite.instance.septumRv, place);
  late final List<Offset> rvEndo = _map(_Composite.instance.rvEndo, place);
  late final List<Offset> rvEpi = _map(_Composite.instance.rvEpi, place);

  /// The mitral annulus's hinges, the anterior leaflet's and the
  /// posterior's, and the tricuspid's, the septal leaflet's and the
  /// anterior's.
  late final (Offset, Offset) mitral = (
    place(_Composite.instance.mitralA),
    place(_Composite.instance.mitralL),
  );
  late final (Offset, Offset) tricuspid = (
    place(_Composite.instance.tricuspidS),
    place(_Composite.instance.tricuspidL),
  );

  // The papillary muscles and the moderator band, the leaflets and the
  // cusps, and the chordae between them.

  late final List<List<Offset>> papillary = <List<Offset>>[
    for (final List<Offset> p in _Composite.instance.papillary) _map(p, place),
  ];
  late final List<Offset> moderator = _map(
    _Composite.instance.moderator,
    place,
  );
  late final List<List<Offset>> leaflets = <List<Offset>>[
    for (final List<Offset> p in _Composite.instance.leaflets) _map(p, place),
  ];
  late final List<List<Offset>> cusps = <List<Offset>>[
    for (final List<Offset> p in _Composite.instance.cusps) _map(p, place),
  ];
  late final List<(Offset, Offset)> chordae = <(Offset, Offset)>[
    for (final (Offset a, Offset b) in _Composite.instance.chordae)
      (place(a), place(b)),
  ];

  // The great vessels, in the order they are drawn: those behind the
  // atria, the veins into them, the arch's branches, the aorta, and in
  // front the right ventricle's outflow and the pulmonary trunk.

  late final List<HeartVessel> behind = _vessels(_Composite.instance.behind);
  late final List<HeartVessel> veins = _vessels(_Composite.instance.veins);
  late final List<HeartVessel> branches = _vessels(
    _Composite.instance.branches,
  );
  late final HeartVessel aorta = _Composite.instance.aorta._placed(
    place,
    scale,
  );
  late final HeartVessel infundibulum = _Composite.instance.infundibulum
      ._placed(place, scale);
  late final List<HeartVessel> pulmonary = _vessels(
    _Composite.instance.pulmonary,
  );

  List<HeartVessel> _vessels(List<HeartVessel> vessels) => <HeartVessel>[
    for (final HeartVessel v in vessels) v._placed(place, scale),
  ];

  // The fat of the grooves and the coronary arteries in it.

  late final List<List<Offset>> fat = <List<Offset>>[
    for (final List<Offset> f in _Composite.instance.fat) _map(f, place),
  ];
  late final List<HeartCoronary> coronaries = <HeartCoronary>[
    for (final HeartCoronary c in _Composite.instance.coronaries)
      (centre: place(c.centre), lumen: mm(c.lumen), outer: mm(c.outer)),
  ];

  /// The epicardium: the heart's own surface, its chambers' and its fat's,
  /// in runs broken where the great vessels leave it.
  late final List<List<Offset>> epicardium = <List<Offset>>[
    for (final List<Offset> run in _Composite.instance.epicardium)
      _map(run, place),
  ];

  /// The point of the epicardium nearest [p].
  Offset epicardiumNear(Offset p) {
    Offset best = p;
    double nearest = double.infinity;
    for (final List<Offset> run in epicardium) {
      for (final Offset q in run) {
        final double d = (q - p).distanceSquared;
        if (d < nearest) {
          nearest = d;
          best = q;
        }
      }
    }
    return best;
  }

  // Where each chamber is named.

  late final Offset rightAtrium = place(HeartAnatomy.rightAtrium);
  late final Offset leftAtrium = place(HeartAnatomy.leftAtrium);
  late final Offset rightVentricle = place(HeartAnatomy.rightVentricle);
  late final Offset leftVentricle = place(HeartAnatomy.leftVentricle);

  /// Where the step from the body meets the heart's outline and the body's,
  /// beside their tops: the right pulmonary vessels' ends, the right
  /// atrium's border, the inferior vena cava, the apex, the left
  /// ventricle's border and the left pulmonary vessels' ends, each picked
  /// out of either outline alike.
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0, 0.45),
        (List<Offset> p) => OutlineMarks.level(p, -1, 0.62),
        (List<Offset> p) => _lowest(p, 0.25),
        _apex,
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.35, 0.9),
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0, 0.32),
      ];

  /// The lowest of [points] of those in the left [share] of their box.
  static int _lowest(List<Offset> points, double share) {
    final Rect box = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      if (points[i].dx > box.left + box.width * share) {
        continue;
      }
      if (best < 0 || points[i].dy > points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The one of [points] furthest down and to the right together, as
  /// shares of their box: the apex.
  static int _apex(List<Offset> points) {
    final Rect box = _bounds(points);
    int best = 0;
    double most = double.negativeInfinity;
    for (int i = 0; i < points.length; i++) {
      final double at =
          (points[i].dx - box.left) / box.width +
          (points[i].dy - box.top) / box.height;
      if (at > most) {
        most = at;
        best = i;
      }
    }
    return best;
  }

  /// The points of the heart's own outline where the step from the body
  /// meets the body's, for tests: in the order round it from the top.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

/// The heart in its own frame, in millimetres: built once.
final class _Composite {
  _Composite() {
    _build();
  }

  static final _Composite instance = _Composite();

  static const double _tilt = HeartAnatomy.tilt * math.pi / 180;

  /// Down the long axis toward the apex, and across it toward the free
  /// wall.
  final Offset ax = Offset(math.sin(_tilt), math.cos(_tilt));
  final Offset nx = Offset(math.cos(_tilt), -math.sin(_tilt));

  final double _a = HeartAnatomy.lvLength - HeartAnatomy.lvWidest;
  final double _u0 = HeartAnatomy.lvWidest;
  final double _half = HeartAnatomy.lvWidth / 2;
  late final double _halfBase = _half * math.sqrt(1 - _sq(_u0 / _a));

  /// The middle of the left ventricle's base.
  late final Offset _base =
      nx * (_wall(HeartAnatomy.septum, 0) / 2 + _halfBase);

  Offset _at(double u, double v) => _base + ax * u + nx * v;
  double _uOf(Offset p) => _dot(p - _base, ax);

  late final List<Offset> freeEndo;
  late final List<Offset> freeEpi;
  late final List<Offset> septumLv;
  late final List<Offset> septumRv;
  late final List<Offset> rvEndo;
  late final List<Offset> rvEpi;
  late final Offset mitralA;
  late final Offset mitralL;
  late final Offset tricuspidS;
  late final Offset tricuspidL;

  late final List<Offset> lvMuscle;
  late final List<Offset> rvMuscle;
  late final List<Offset> raMuscle;
  late final List<Offset> laMuscle;
  late final HeartCavity lvCavity;
  late final HeartCavity rvCavity;
  late final HeartCavity raCavity;
  late final HeartCavity laCavity;
  late final List<(List<Offset>, List<Offset>)> bands;
  late final List<List<Offset>> atrialEdges;
  late final List<List<Offset>> innerEdges;
  late final List<List<Offset>> columnEdges;

  late final List<List<Offset>> papillary;
  late final List<Offset> moderator;
  late final List<List<Offset>> leaflets;
  late final List<List<Offset>> cusps;
  late final List<(Offset, Offset)> chordae;

  late final List<HeartVessel> behind;
  late final List<HeartVessel> veins;
  late final List<HeartVessel> branches;
  late final HeartVessel aorta;
  late final HeartVessel infundibulum;
  late final List<HeartVessel> pulmonary;

  late final List<List<Offset>> fat;
  late final List<HeartCoronary> coronaries;

  late final List<Offset> outline;
  late final Rect box;
  late final List<List<Offset>> epicardium;

  /// The middle of the left ventricle's compact free wall at height [y].
  double freeWallMiddleAt(double y) {
    final double inner = _crossingAt(freeEndo, y);
    final double outer = _crossingAt(freeEpi, y);
    return (inner + outer) / 2;
  }

  static double _wall(List<double> wall, double u) {
    const double middle = HeartAnatomy.wallMiddle;
    const double apex = HeartAnatomy.wallApex;
    if (u <= middle) {
      return wall[0] + (wall[1] - wall[0]) * _smooth(u / middle);
    }
    return wall[1] +
        (wall[2] - wall[1]) * _smooth((u - middle) / (apex - middle));
  }

  void _build() {
    // The left ventricle: its cavity a long ellipse cut off at its base,
    // the free wall and the septum round it as thick as each is measured at
    // its height. Followed from the base round the apex, t from the free
    // side's base through 0 at the apex to the septum's base.
    final double t0 = math.acos(-_u0 / _a);
    // The right ventricle's apex meets the septum so far down the axis.
    final double tApexRv = -math.acos((HeartAnatomy.rvApex - _u0) / _a);
    const int steps = 240;
    final List<Offset> free = <Offset>[];
    final List<Offset> freeOut = <Offset>[];
    final List<Offset> sept = <Offset>[];
    final List<Offset> septOut = <Offset>[];
    final List<Offset> apexIn = <Offset>[];
    final List<Offset> apexOut = <Offset>[];
    for (int k = 0; k <= steps; k++) {
      final double t = t0 - (t0 - tApexRv) * k / steps;
      final (double u, Offset p, Offset normal) = _ellipse(t);
      final double wall = t >= 0
          ? _wall(HeartAnatomy.freeWall, u)
          : _wall(HeartAnatomy.freeWall, u) +
                (_wall(HeartAnatomy.septum, u) -
                        _wall(HeartAnatomy.freeWall, u)) *
                    _smooth(t / tApexRv);
      if (t >= 0) {
        free.add(p);
        freeOut.add(p + normal * wall);
      } else {
        apexIn.add(p);
        apexOut.add(p + normal * wall);
      }
    }
    for (int k = 0; k <= steps; k++) {
      final double t = -t0 + (t0 + tApexRv) * k / steps;
      final (double u, Offset p, Offset normal) = _ellipse(t);
      sept.add(p);
      septOut.add(p + normal * _wall(HeartAnatomy.septum, u));
    }
    freeEndo = free;
    freeEpi = freeOut;
    septumLv = sept;
    septumRv = septOut;
    mitralA = _at(0, HeartAnatomy.mitralFrom);
    mitralL = free.first;

    // The right ventricle: the tricuspid annulus a little below the
    // mitral, from the septum out to the right; its free wall round from
    // there to its apex on the septum.
    tricuspidS = _alongU(septOut, HeartAnatomy.tricuspidDrop);
    tricuspidL =
        tricuspidS -
        nx * HeartAnatomy.tricuspid +
        ax * HeartAnatomy.tricuspidLean;
    final Offset rvApex = septOut.last;
    rvEndo = _resample(
      _catmull(<Offset>[tricuspidL, ...HeartAnatomy.rvFree, rvApex]),
      HeartStyle.edgeStep,
    );
    rvEpi = _offset(rvEndo, -HeartAnatomy.rvWall);

    // The trabeculae: the ventricles' inner edges rough toward the apex.
    final math.Random random = math.Random(HeartStyle.seed);
    final List<Offset> freeRough = _rough(
      free,
      HeartStyle.trabeculaLeft,
      random,
      (Offset p) => _smooth((_uOf(p) - 40) / 20),
      inward: _towardMiddle(free),
    );
    final List<Offset> apexRough = _rough(
      apexIn,
      HeartStyle.trabeculaLeft,
      random,
      (Offset p) => _smooth((_uOf(p) - 40) / 20),
      inward: _towardMiddle(apexIn),
    );
    final List<Offset> septRough = _rough(
      sept,
      HeartStyle.trabeculaLeft * 0.6,
      random,
      (Offset p) => _smooth((_uOf(p) - 40) / 20),
      inward: _towardMiddle(sept),
    );
    final List<Offset> rvRough = _rough(
      rvEndo,
      HeartStyle.trabeculaRight,
      random,
      (Offset p) => 1,
      inward: _towardCavity(rvEndo, septOut),
      fade: 8,
    );

    // The left ventricle's muscle: its outside from the free wall's base
    // round the apex to where the right ventricle's apex meets the septum,
    // up the septum's right side, and across the base. Its cavity: the
    // inner edge round from the free wall's base to the septum's.
    lvMuscle = <Offset>[...freeOut, ...apexOut, ...septOut.reversed];
    // Each ventricle's cavity reaches a little past its openings, so no
    // seam of the muscle shows across them.
    final Offset up = -ax * HeartStyle.openingOverlap;
    lvCavity = HeartCavity(
      shape: <Offset>[
        ...freeRough,
        ...apexRough,
        ...septRough.reversed,
        septRough.first + up,
        freeRough.first + up,
      ],
      rims: <List<Offset>>[
        <Offset>[...freeRough, ...apexRough, ...septRough.reversed],
      ],
    );

    // The right ventricle's muscle: its free wall's outside round to the
    // apex, up the septum to the tricuspid annulus and across it. Its
    // cavity the same inside.
    final List<Offset> septUp = <Offset>[
      for (final Offset p in septOut.reversed)
        if (_uOf(p) >= HeartAnatomy.tricuspidDrop) p,
    ];
    rvMuscle = <Offset>[...rvEpi, ...septUp, tricuspidS, tricuspidL];
    final Offset toAtrium =
        _unit(
          Offset(tricuspidS.dy - tricuspidL.dy, tricuspidL.dx - tricuspidS.dx),
        ) *
        HeartStyle.openingOverlap;
    rvCavity = HeartCavity(
      shape: <Offset>[
        ...rvRough,
        ...septUp,
        tricuspidS + toAtrium,
        tricuspidL + toAtrium,
      ],
      rims: <List<Offset>>[
        <Offset>[...rvRough, ...septUp],
      ],
    );

    // The atria: each its outside over the top from the interatrial septum
    // to the groove, its wall inside it, closed across its valve and up the
    // septum, behind the aorta.
    final List<Offset> raRun = _resample(
      _catmull(<Offset>[...HeartAnatomy.raOutside, rvEpi.first]),
      HeartStyle.edgeStep,
    );
    final List<Offset> raInner = _offset(raRun, HeartAnatomy.atrialWall);
    raMuscle = <Offset>[
      ...raRun,
      tricuspidL,
      tricuspidS,
      Offset.zero,
      const Offset(-4, -20),
      const Offset(-8, -44),
    ];
    raCavity = HeartCavity(
      shape: <Offset>[
        ...raInner,
        tricuspidL,
        tricuspidS,
        const Offset(-2, -1),
        const Offset(-6, -20),
        const Offset(-10, -43),
      ],
      rims: <List<Offset>>[raInner],
    );
    final List<Offset> laRun = _resample(
      _catmull(<Offset>[...HeartAnatomy.laOutside, freeOut.first]),
      HeartStyle.edgeStep,
    );
    final List<Offset> laInner = _offset(laRun, -HeartAnatomy.atrialWall);
    laMuscle = <Offset>[
      ...laRun,
      mitralL,
      mitralA,
      const Offset(6, -14),
      const Offset(4, -30),
      const Offset(2, -48),
    ];
    laCavity = HeartCavity(
      shape: <Offset>[
        ...laInner,
        mitralL,
        mitralA,
        const Offset(8, -14),
        const Offset(6, -30),
        const Offset(5, -47),
      ],
      rims: <List<Offset>>[laInner],
    );
    bands = <(List<Offset>, List<Offset>)>[
      (<Offset>[...freeOut, ...apexOut], <Offset>[...free, ...apexIn]),
      (septOut, sept),
      (rvEpi, rvEndo),
      (raRun, raInner),
      (laRun, laInner),
    ];

    // The leaflets, open in diastole, hanging into the ventricles.
    final (List<Offset> mitralAnterior, Offset _) = _leaflet(
      mitralA,
      ax + nx * 0.3,
      HeartAnatomy.mitralAnterior,
      -0.1,
    );
    final (List<Offset> mitralPosterior, Offset _) = _leaflet(
      mitralL,
      ax - nx * 0.5,
      HeartAnatomy.mitralPosterior,
      0.1,
    );
    final (List<Offset> tricuspidAnterior, Offset _) = _leaflet(
      tricuspidL,
      ax + nx * 0.75,
      HeartAnatomy.tricuspidAnterior,
      0.1,
    );
    final (List<Offset> tricuspidSeptal, Offset _) = _leaflet(
      tricuspidS,
      ax - nx * 0.2,
      HeartAnatomy.tricuspidSeptal,
      -0.08,
    );
    leaflets = <List<Offset>>[
      _leafletShape(mitralAnterior),
      _leafletShape(mitralPosterior),
      _leafletShape(tricuspidAnterior),
      _leafletShape(tricuspidSeptal),
    ];

    // The papillary muscles, toward the leaflets they hold, and the
    // moderator band.
    final (double lvLength, double lvWidth) = HeartAnatomy.lvPapillary;
    final Offset anterolateral = _alongU(free, HeartAnatomy.anterolateral);
    final Offset posteromedial = _alongU(sept, HeartAnatomy.posteromedial);
    final Offset mitralTips = (mitralAnterior.last + mitralPosterior.last) / 2;
    final List<Offset> alp = _finger(
      anterolateral,
      _unit(mitralTips - anterolateral + nx * 8),
      lvLength,
      lvWidth,
    );
    final List<Offset> pmp = _finger(
      posteromedial,
      _unit(mitralTips - posteromedial - nx * 4),
      lvLength * 0.92,
      lvWidth * 0.9,
    );
    final Offset rvAnteriorBase = _alongShare(rvEndo, HeartAnatomy.rvAnterior);
    final Offset rvSeptalBase = _alongU(septOut, HeartAnatomy.rvSeptal);
    final (double raLength, double raWidth) = HeartAnatomy.rvAnteriorSize;
    final (double rsLength, double rsWidth) = HeartAnatomy.rvSeptalSize;
    final List<Offset> rap = _finger(
      rvAnteriorBase,
      _unit(tricuspidAnterior.last - rvAnteriorBase),
      raLength,
      raWidth,
    );
    final List<Offset> rsp = _finger(
      rvSeptalBase,
      _unit(tricuspidSeptal.last - rvSeptalBase),
      rsLength,
      rsWidth,
    );
    papillary = <List<Offset>>[alp, pmp, rap, rsp];
    moderator = _band(
      _alongU(septOut, HeartAnatomy.moderator),
      rvAnteriorBase,
      HeartAnatomy.moderatorWidth,
    );

    // The chordae, from each papillary muscle's tip to the free third of
    // its leaflets.
    chordae = <(Offset, Offset)>[
      ..._chordae(alp, mitralPosterior),
      ..._chordae(pmp, mitralAnterior),
      ..._chordae(rap, tricuspidAnterior),
      ..._chordae(rsp, tricuspidSeptal, count: 3),
    ];

    atrialEdges = <List<Offset>>[raInner, laInner];
    innerEdges = <List<Offset>>[
      <Offset>[...freeRough, ...apexRough],
      septRough,
      rvRough,
      <Offset>[for (final Offset p in septUp.reversed) p],
    ];
    columnEdges = <List<Offset>>[
      for (final List<Offset> p in papillary) <Offset>[...p, p.first],
      <Offset>[...moderator, moderator.first],
    ];

    // The great vessels: cut open from their roots, the aorta's and the
    // pulmonary trunk's far enough to show their valves, the right
    // ventricle's outflow all of it; whole beyond.
    List<double> even(List<Offset> course, double radius) => <double>[
      for (int i = 0; i < course.length; i++) radius,
    ];
    behind = <HeartVessel>[
      HeartVessel._mm(
        _VesselSpec(
          HeartAnatomy.rightPulmonary,
          even(HeartAnatomy.rightPulmonary, HeartAnatomy.pulmonaryRadius),
          HeartAnatomy.pulmonaryWall,
          cutTo: 0,
          artery: true,
        ),
      ),
      for (final List<Offset> v in HeartAnatomy.rightVeins)
        HeartVessel._mm(
          _VesselSpec(
            v,
            even(v, HeartAnatomy.veinRadius),
            HeartAnatomy.veinWall,
            cutTo: 0,
            artery: false,
          ),
        ),
      HeartVessel._mm(
        _VesselSpec(
          HeartAnatomy.superiorCava,
          even(HeartAnatomy.superiorCava, HeartAnatomy.cavaRadius),
          HeartAnatomy.veinWall,
          cutTo: 0,
          artery: false,
        ),
      ),
      HeartVessel._mm(
        _VesselSpec(
          HeartAnatomy.inferiorCava,
          even(HeartAnatomy.inferiorCava, HeartAnatomy.cavaRadius),
          HeartAnatomy.veinWall,
          cutTo: 0,
          artery: false,
        ),
      ),
      for (final List<Offset> v in HeartAnatomy.leftVeins)
        HeartVessel._mm(
          _VesselSpec(
            v,
            even(v, HeartAnatomy.veinRadius),
            HeartAnatomy.veinWall,
            cutTo: 0,
            artery: false,
          ),
        ),
    ];
    veins = const <HeartVessel>[];
    branches = <HeartVessel>[
      for (int i = 0; i < HeartAnatomy.branches.length; i++)
        HeartVessel._mm(
          _VesselSpec(
            HeartAnatomy.branches[i],
            even(HeartAnatomy.branches[i], HeartAnatomy.branchRadii[i]),
            HeartAnatomy.branchWall,
            cutTo: 0,
            artery: true,
          ),
        ),
    ];
    aorta = HeartVessel._mm(
      const _VesselSpec(
        HeartAnatomy.aorta,
        HeartAnatomy.aortaRadii,
        HeartAnatomy.aortaWall,
        cutTo: HeartAnatomy.aortaOpen,
        artery: true,
      ),
    );
    infundibulum = HeartVessel._mm(
      _VesselSpec(
        HeartAnatomy.infundibulum,
        even(HeartAnatomy.infundibulum, HeartAnatomy.infundibulumRadius),
        HeartAnatomy.rvWall,
        cutTo: double.infinity,
        artery: false,
        muscle: true,
        taper: HeartStyle.outflowTaper,
      ),
    );
    // The left pulmonary artery first, so the trunk lies over its root.
    pulmonary = <HeartVessel>[
      HeartVessel._mm(
        _VesselSpec(
          HeartAnatomy.leftPulmonary,
          even(HeartAnatomy.leftPulmonary, HeartAnatomy.pulmonaryRadius),
          HeartAnatomy.pulmonaryWall,
          cutTo: 0,
          artery: true,
        ),
      ),
      HeartVessel._mm(
        _VesselSpec(
          HeartAnatomy.trunk,
          even(HeartAnatomy.trunk, HeartAnatomy.trunkRadius),
          HeartAnatomy.pulmonaryWall,
          cutTo: HeartAnatomy.trunkOpen,
          artery: true,
          endCut: false,
        ),
      ),
    ];

    // The semilunar valves, closed: two cusps of each seen in the cut,
    // their bellies sagging toward the ventricle.
    cusps = <List<Offset>>[..._cuspsOf(aorta), ..._cuspsOf(pulmonary.last)];

    // The fat of the atrioventricular grooves, the coronary arteries cut
    // across in it.
    final Offset rightGroove = rvEpi.first;
    final Offset leftGroove = freeOut.first;
    final Offset rightOut = _unit(rightGroove - tricuspidL);
    final Offset leftOut = _unit(leftGroove - mitralL);
    fat = <List<Offset>>[
      _blob(rightGroove + rightOut * 2, HeartAnatomy.grooveFat),
      _blob(leftGroove + leftOut * 2, HeartAnatomy.grooveFat * 0.9),
    ];
    coronaries = <HeartCoronary>[
      (
        centre: rightGroove + rightOut * 3,
        lumen: HeartAnatomy.rightCoronary / 2,
        outer: HeartAnatomy.rightCoronary / 2 + HeartAnatomy.coronaryWall,
      ),
      (
        centre: leftGroove + leftOut * 3,
        lumen: HeartAnatomy.circumflex / 2,
        outer: HeartAnatomy.circumflex / 2 + HeartAnatomy.coronaryWall,
      ),
    ];

    // The outline: everything drawn, as one shape; the epicardium: the
    // heart's own, where no great vessel leaves it.
    final List<HeartVessel> vessels = <HeartVessel>[
      ...behind,
      ...veins,
      ...branches,
      aorta,
      ...pulmonary,
    ];
    final Path body = _union(<List<Offset>>[
      lvMuscle,
      rvMuscle,
      raMuscle,
      laMuscle,
      infundibulum.outer,
      ...fat,
    ]);
    final Path all = Path.combine(
      PathOperation.union,
      body,
      _union(<List<Offset>>[for (final HeartVessel v in vessels) v.outer]),
    );
    outline = _outerOf(all, HeartStyle.outlineStep);
    box = _bounds(outline);
    final Path leaving = _union(<List<Offset>>[
      for (final HeartVessel v in vessels) v.outer,
    ]);
    // The epicardium: the outline where, just inside it, no great vessel
    // lies; broken where one leaves.
    final double inward = _area(outline) > 0 ? 1 : -1;
    final List<Offset> normals = _normals(outline);
    final List<List<Offset>> runs = <List<Offset>>[];
    List<Offset> run = <Offset>[];
    for (int i = 0; i < outline.length; i++) {
      final Offset probe =
          outline[i] - normals[i] * (inward * HeartStyle.epicardiumProbe);
      if (leaving.contains(probe)) {
        if (run.length > 1) {
          runs.add(run);
        }
        run = <Offset>[];
      } else {
        run.add(outline[i]);
      }
    }
    if (run.length > 1) {
      // The outline closes: a run through its start is one run.
      if (runs.isNotEmpty &&
          !leaving.contains(
            outline.first -
                normals.first * (inward * HeartStyle.epicardiumProbe),
          )) {
        runs[0] = <Offset>[...run, ...runs[0]];
      } else {
        runs.add(run);
      }
    }
    epicardium = runs;
  }

  /// The ellipse of the left ventricle's cavity at [t]: how far down the
  /// axis, the point, and the way out of it there.
  (double, Offset, Offset) _ellipse(double t) {
    final double u = _u0 + _a * math.cos(t);
    final double v = _half * math.sin(t);
    final double nu = math.cos(t) / _a;
    final double nv = math.sin(t) / _half;
    final double length = math.sqrt(nu * nu + nv * nv);
    return (u, _at(u, v), _unit(ax * (nu / length) + nx * (nv / length)));
  }

  /// The point of [points] [u] down the left ventricle's axis.
  Offset _alongU(List<Offset> points, double u) {
    for (int i = 1; i < points.length; i++) {
      final double a = _uOf(points[i - 1]);
      final double b = _uOf(points[i]);
      if ((a - u) * (b - u) <= 0 && a != b) {
        return Offset.lerp(points[i - 1], points[i], (u - a) / (b - a))!;
      }
    }
    return points.last;
  }

  /// Which way into the left ventricle's cavity each point of [edge] is.
  List<Offset> _towardMiddle(List<Offset> edge) => <Offset>[
    for (final Offset p in edge) _unit(_at(math.max(_uOf(p), 0), 0) - p),
  ];

  /// Which way into the right ventricle's cavity each point of its free
  /// wall's inner [edge] is: toward the septum.
  List<Offset> _towardCavity(List<Offset> edge, List<Offset> septum) {
    final List<Offset> left = _normals(edge);
    final Offset middle = septum[septum.length ~/ 2];
    final double side =
        _dot(middle - edge[edge.length ~/ 2], left[edge.length ~/ 2]) >= 0
        ? 1
        : -1;
    return <Offset>[for (final Offset n in left) n * side];
  }

  static double _crossingAt(List<Offset> line, double y) {
    double? best;
    for (int i = 1; i < line.length; i++) {
      final Offset a = line[i - 1];
      final Offset b = line[i];
      if ((a.dy - y) * (b.dy - y) <= 0 && a.dy != b.dy) {
        final double x = a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy);
        best = best == null ? x : math.max(best, x);
      }
    }
    if (best != null) {
      return best;
    }
    // Above or below the wall: its nearest end.
    final Offset end = (line.first.dy - y).abs() < (line.last.dy - y).abs()
        ? line.first
        : line.last;
    return end.dx;
  }
}

// Geometry.

double _sq(double x) => x * x;

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

Offset _unit(Offset p) {
  final double length = p.distance;
  return length <= 0 ? Offset.zero : p / length;
}

List<Offset> _map(List<Offset> points, Offset Function(Offset) place) =>
    <Offset>[for (final Offset p in points) place(p)];

/// The left hand of the way along [line] at each point, a unit.
List<Offset> _normals(List<Offset> line) {
  final int n = line.length;
  return <Offset>[
    for (int i = 0; i < n; i++)
      () {
        final Offset t = _unit(
          line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)],
        );
        return Offset(t.dy, -t.dx);
      }(),
  ];
}

/// [line] moved [by] to the left hand of the way along it.
List<Offset> _offset(List<Offset> line, double by) {
  final List<Offset> normals = _normals(line);
  return <Offset>[
    for (int i = 0; i < line.length; i++) line[i] + normals[i] * by,
  ];
}

/// [edge] made rough by the trabeculae: each point moved [inward] by up to
/// [height], as two waves of [HeartStyle.trabeculaWave] and a longer one
/// together rise and fall along it, by [share] of it at each point, and
/// faded in over [fade] at either end.
List<Offset> _rough(
  List<Offset> edge,
  double height,
  math.Random random,
  double Function(Offset) share, {
  required List<Offset> inward,
  double fade = 0,
}) {
  const double wave = HeartStyle.trabeculaWave;
  final double phase1 = random.nextDouble() * 2 * math.pi;
  final double phase2 = random.nextDouble() * 2 * math.pi;
  final List<double> along = <double>[0];
  for (int i = 1; i < edge.length; i++) {
    along.add(along.last + (edge[i] - edge[i - 1]).distance);
  }
  final double total = along.last;
  return <Offset>[
    for (int i = 0; i < edge.length; i++)
      () {
        final double s = along[i];
        final double bump =
            (0.5 + 0.5 * math.sin(2 * math.pi * s / wave + phase1)) *
            (0.5 + 0.5 * math.sin(2 * math.pi * s / (1.7 * wave) + phase2));
        final double ends = fade <= 0
            ? 1
            : _smooth(s / fade) * _smooth((total - s) / fade);
        return edge[i] + inward[i] * (height * bump * share(edge[i]) * ends);
      }(),
  ];
}

/// The point [share] of the way along [line].
Offset _alongShare(List<Offset> line, double share) {
  double total = 0;
  for (int i = 1; i < line.length; i++) {
    total += (line[i] - line[i - 1]).distance;
  }
  double at = share * total;
  for (int i = 1; i < line.length; i++) {
    final double d = (line[i] - line[i - 1]).distance;
    if (at <= d && d > 0) {
      return Offset.lerp(line[i - 1], line[i], at / d)!;
    }
    at -= d;
  }
  return line.last;
}

/// An open Catmull-Rom curve through [knots], [per] points a span.
List<Offset> _catmull(List<Offset> knots, {int per = 16}) {
  final int n = knots.length;
  Offset knot(int i) => i < 0
      ? knots[0] * 2 - knots[1]
      : i >= n
      ? knots[n - 1] * 2 - knots[n - 2]
      : knots[i];
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < n - 1; i++) {
    final Offset p0 = knot(i - 1);
    final Offset p1 = knot(i);
    final Offset p2 = knot(i + 1);
    final Offset p3 = knot(i + 2);
    final Offset c1 = p1 + (p2 - p0) / 6;
    final Offset c2 = p2 - (p3 - p1) / 6;
    for (int k = 0; k < per; k++) {
      final double t = k / per;
      final double u = 1 - t;
      out.add(
        p1 * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            p2 * (t * t * t),
      );
    }
  }
  out.add(knots.last);
  return out;
}

/// [line] laid again with its points [step] apart along it.
List<Offset> _resample(List<Offset> line, double step) {
  final List<double> along = <double>[0];
  for (int i = 1; i < line.length; i++) {
    along.add(along.last + (line[i] - line[i - 1]).distance);
  }
  final double total = along.last;
  final int count = math.max(2, (total / step).round() + 1);
  final List<Offset> out = <Offset>[];
  int j = 1;
  for (int k = 0; k < count; k++) {
    final double at = total * k / (count - 1);
    while (j < line.length - 1 && along[j] < at) {
      j++;
    }
    final double span = along[j] - along[j - 1];
    final double t = span <= 0 ? 0 : (at - along[j - 1]) / span;
    out.add(Offset.lerp(line[j - 1], line[j], t.clamp(0.0, 1.0))!);
  }
  return out;
}

/// A leaflet's middle line from [hinge] along [toward], [length] long,
/// bowed [bow] of its length to its left; and its tip.
(List<Offset>, Offset) _leaflet(
  Offset hinge,
  Offset toward,
  double length,
  double bow,
) {
  final Offset d = _unit(toward);
  final Offset side = Offset(d.dy, -d.dx);
  final Offset tip = hinge + d * length;
  final Offset control = hinge + d * (length / 2) + side * (bow * length);
  final List<Offset> line = <Offset>[
    for (int k = 0; k <= 16; k++)
      () {
        final double t = k / 16;
        final double u = 1 - t;
        return hinge * (u * u) + control * (2 * u * t) + tip * (t * t);
      }(),
  ];
  return (line, tip);
}

/// A leaflet's shape round its middle [line]: as thick at its hinge as
/// [HeartStyle.leafletHinge], thinning to its free edge.
List<Offset> _leafletShape(List<Offset> line) {
  final List<Offset> normals = _normals(line);
  final int n = line.length;
  double half(int i) =>
      (HeartStyle.leafletHinge +
          (HeartStyle.leafletEdge - HeartStyle.leafletHinge) * i / (n - 1)) /
      2;
  return <Offset>[
    for (int i = 0; i < n; i++) line[i] + normals[i] * half(i),
    for (int i = n - 1; i >= 0; i--) line[i] - normals[i] * half(i),
  ];
}

/// A papillary muscle: a rounded column rising from [base] on its wall
/// [toward] its leaflets, [length] long and [width] wide at its base,
/// rooted a little into the wall.
List<Offset> _finger(Offset base, Offset toward, double length, double width) {
  final Offset d = _unit(toward);
  final Offset p = Offset(-d.dy, d.dx);
  final Offset tip = base + d * length;
  final Offset middle = base + d * (length * 0.5);
  return _resample(
    _closedCatmull(<Offset>[
      base - d * 3 + p * (width * 0.55),
      base + p * (width * 0.5),
      middle + p * (width * 0.3),
      tip + p * (width * 0.2) - d * (width * 0.1),
      tip + d * (width * 0.15),
      tip - p * (width * 0.2) - d * (width * 0.1),
      middle - p * (width * 0.3),
      base - p * (width * 0.5),
      base - d * 3 - p * (width * 0.55),
    ]),
    HeartStyle.edgeStep,
  );
}

/// The tip of a papillary muscle laid by [_finger]: the furthest of its
/// points from its first.
Offset _tipOf(List<Offset> finger) {
  Offset best = finger.first;
  double far = 0;
  for (final Offset q in finger) {
    final double d = (q - finger.first).distanceSquared;
    if (d > far) {
      far = d;
      best = q;
    }
  }
  return best;
}

/// The chordae from the tip of [muscle], a papillary muscle laid by
/// [_finger], to the free part of [leaflet]'s middle line: [count] of them,
/// fanned across the tip and along the leaflet.
List<(Offset, Offset)> _chordae(
  List<Offset> muscle,
  List<Offset> leaflet, {
  int count = HeartAnatomy.chordae,
}) {
  final Offset tip = _tipOf(muscle);
  final Offset toward = _unit(tip - muscle.first);
  final Offset across = Offset(-toward.dy, toward.dx);
  final double spread = (muscle[muscle.length ~/ 4] - tip).distance * 0.25;
  return <(Offset, Offset)>[
    for (int k = 0; k < count; k++)
      () {
        final double t = count == 1 ? 0.5 : k / (count - 1);
        return (
          tip + across * (spread * (t - 0.5)),
          _alongShare(leaflet, 0.6 + 0.4 * t),
        );
      }(),
  ];
}

/// A band [width] wide from [from] to [to], bowed a little.
List<Offset> _band(Offset from, Offset to, double width) {
  final Offset d = _unit(to - from);
  final Offset side = Offset(-d.dy, d.dx);
  final Offset middle = (from + to) / 2 + side * ((to - from).distance * 0.08);
  final List<Offset> line = _catmull(<Offset>[from, middle, to], per: 12);
  return <Offset>[
    ..._offset(line, width / 2),
    ..._offset(line, -width / 2).reversed,
  ];
}

/// A round of fat about [centre], [radius] across, a little lobed.
List<Offset> _blob(Offset centre, double radius) => <Offset>[
  for (int k = 0; k < 48; k++)
    () {
      final double a = 2 * math.pi * k / 48;
      final double r =
          radius * (1 + 0.08 * math.sin(3 * a) + 0.05 * math.sin(5 * a + 1));
      return centre + Offset(math.cos(a), math.sin(a)) * r;
    }(),
];

/// A closed Catmull-Rom curve through [knots].
List<Offset> _closedCatmull(List<Offset> knots, {int per = 12}) {
  final int n = knots.length;
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset p0 = knots[(i - 1 + n) % n];
    final Offset p1 = knots[i];
    final Offset p2 = knots[(i + 1) % n];
    final Offset p3 = knots[(i + 2) % n];
    final Offset c1 = p1 + (p2 - p0) / 6;
    final Offset c2 = p2 - (p3 - p1) / 6;
    for (int k = 0; k < per; k++) {
      final double t = k / per;
      final double u = 1 - t;
      out.add(
        p1 * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            p2 * (t * t * t),
      );
    }
  }
  return out;
}

/// The two cusps of [vessel]'s valve seen in the cut, closed at its root:
/// each from its wall a little above the root, its belly sagging toward the
/// ventricle, to the middle.
List<List<Offset>> _cuspsOf(HeartVessel vessel) {
  final (List<Offset> _, List<Offset> left) = vessel.walls.first;
  final (List<Offset> _, List<Offset> right) = vessel.walls.last;
  final int hinge = math.min(left.length - 1, 5);
  final Offset middle = (left.first + right.first) / 2;
  final Offset up = _unit((left[hinge] + right[hinge]) / 2 - middle);
  final Offset meet = middle - up * 1.5;
  List<Offset> cusp(Offset from) {
    final Offset control = (from + meet) / 2 - up * 4;
    final List<Offset> line = <Offset>[
      for (int k = 0; k <= 12; k++)
        () {
          final double t = k / 12;
          final double u = 1 - t;
          return from * (u * u) + control * (2 * u * t) + meet * (t * t);
        }(),
    ];
    final List<Offset> normals = _normals(line);
    return <Offset>[
      for (int i = 0; i < line.length; i++) line[i] + normals[i] * 0.45,
      for (int i = line.length - 1; i >= 0; i--) line[i] - normals[i] * 0.3,
    ];
  }

  return <List<Offset>>[cusp(left[hinge]), cusp(right[hinge])];
}

Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

/// The shapes of [polygons] as one.
Path _union(List<List<Offset>> polygons) {
  Path out = Path();
  for (final List<Offset> p in polygons) {
    out = Path.combine(PathOperation.union, out, _polygon(p));
  }
  return out;
}

/// The outside of [path], its largest contour, laid with points [step]
/// apart along it.
List<Offset> _outerOf(Path path, double step) {
  List<Offset> best = <Offset>[];
  double largest = 0;
  for (final PathMetric metric in path.computeMetrics()) {
    final List<Offset> points = <Offset>[
      for (double s = 0; s < metric.length; s += step)
        metric.getTangentForOffset(s)!.position,
    ];
    final double area = _area(points).abs();
    if (area > largest) {
      largest = area;
      best = points;
    }
  }
  return best;
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
