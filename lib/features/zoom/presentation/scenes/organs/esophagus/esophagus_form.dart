import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'esophagus_anatomy.dart';
import 'esophagus_style.dart';

/// Where in the esophagus the zoom's cell lives, which its drawing lights
/// in the mark, by the Atlas's name for the cell. By the kind of cell,
/// never by gene.
enum EsophagusHome {
  /// The mucosa: its basal, suprabasal and apical squamous cells, and
  /// every cell that has no part of the esophagus of its own to be drawn at
  /// its size (the lamina propria's fibroblasts and immune cells).
  mucosa,

  /// The glands in its submucosa.
  glands;

  /// Where a cell the Atlas calls [cell] lives.
  static EsophagusHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('submucosal gland')) {
      return glands;
    }
    return mucosa;
  }
}

/// The esophagus as the zoom's organ scene draws it, opened from the
/// front: every part in the scene's units at its real size, the middle of
/// the body's outline of it at the origin.
///
/// The esophagus is drawn from general anatomy ([EsophagusAnatomy]) and
/// laid on the body's outline of it so that the place it is gone into in
/// the anatomy lies on the place the body goes in ([site]). The step from
/// the body draws the body's outline in toward the esophagus's own
/// ([pathAt]). Everything here is geometry: what it is drawn in is
/// `EsophagusArt`'s.
final class EsophagusForm {
  EsophagusForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.home = EsophagusHome.mucosa,
  }) : scale = length / EsophagusAnatomy.length {
    final List<Offset> own = _placed(_ringMm(0));
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(EsophagusStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(own).sign != _area(diagramDense).sign
        ? own.reversed.toList()
        : own;
    outlinePoints = template;
    outline = Path()..addPolygon(template, true);
    box = _bounds(template);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: template,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: EsophagusStyle.morphPoints,
      bed: mm(EsophagusStyle.bed),
      marks: _marks,
    );
  }

  /// The esophagus where the body draws it as [part], in a view [view]
  /// metres across, its cells' [home] in it.
  factory EsophagusForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    EsophagusHome home = EsophagusHome.mucosa,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return EsophagusForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the esophagus, in the scene: on its lining,
  /// in its lower third.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final EsophagusHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The esophagus's outline, the fibrous coat's outer edge where the cut
  /// runs down either side of it, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - siteMm) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => siteMm + (p - site) / scale;

  /// How far the esophagus's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the esophagus's at 1, and [bed] of the way on toward the
  /// bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the esophagus's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every esophagus.

  /// Its course, followed closely: each row its middle, the way across it
  /// (toward the body's right) and how far along it lies.
  static final TubeCourse _course = TubeCourse(
    AnatomyTube(
      EsophagusAnatomy.course,
      List<double>.filled(EsophagusAnatomy.course.length, 1),
    ),
    (Offset p) => p,
    1,
    EsophagusStyle.edgeStep,
    bend: 0.9,
  );

  static int get _rows => _course.length;

  /// How far along it each row lies, how far it reaches to either side of
  /// its middle there, and how thick its wall is.
  static double _along(int i) => _course.arc[i];
  static final List<double> _halfMm = <double>[
    for (int i = 0; i < _rows; i++) _lerp(EsophagusAnatomy.half, _along(i)),
  ];
  static final List<double> _wallMm = <double>[
    for (int i = 0; i < _rows; i++) _lerp(EsophagusAnatomy.wall, _along(i)),
  ];

  /// How deep in from its outline each edge between the wall's coats lies
  /// at each row: the outline, the fibrous coat's inner edge, the line
  /// between the muscle's two planes, the muscularis's inner edge, the
  /// submucosa's, and the mucosa's surface.
  static final List<List<double>> _depthsMm = <List<double>>[
    for (int i = 0; i < _rows; i++)
      () {
        final double w = _wallMm[i];
        final double fibrous = math.min(
          w * EsophagusAnatomy.fibrousShare,
          EsophagusAnatomy.fibrousMost,
        );
        final double submucosa = math.min(
          w * EsophagusAnatomy.submucosaShare,
          EsophagusAnatomy.submucosaMost,
        );
        final double mucosa = math.min(
          w * EsophagusAnatomy.mucosaShare,
          EsophagusAnatomy.mucosaMost,
        );
        final double muscle = math.max(0, w - fibrous - submucosa - mucosa);
        final double plane = math.min(
          EsophagusAnatomy.longitudinal,
          muscle / 2,
        );
        return <double>[
          0,
          fibrous,
          fibrous + plane,
          fibrous + muscle,
          fibrous + muscle + submucosa,
          w,
        ];
      }(),
  ];

  /// The point [depth] in from the outline at row [i], on the body's right
  /// ([side] 1) or its left (-1).
  static Offset _sideMm(int i, double side, double depth) =>
      _course.centres[i] + _course.across[i] * (side * (_halfMm[i] - depth));

  /// The edge between two of the wall's coats, [k] of [_depthsMm], down
  /// one side of it, row by row.
  static List<Offset> _edgeMm(int k, double side) => <Offset>[
    for (int i = 0; i < _rows; i++) _sideMm(i, side, _depthsMm[i][k]),
  ];

  /// The shape inside the edge [k] of [_depthsMm]: down its right side, the
  /// body's, across the cut into the cardia, up its left side and across
  /// its top, cut through where it meets the pharynx and arched a little,
  /// as the cut through a tube is.
  static List<Offset> _ringMm(int k) {
    final List<Offset> right = _edgeMm(k, 1);
    final List<Offset> left = _edgeMm(k, -1);
    final Offset up = -_way(0);
    const int arch = 8;
    return <Offset>[
      ...right,
      ...left.reversed,
      for (int j = 1; j < arch; j++)
        Offset.lerp(left.first, right.first, j / arch)! +
            up * (EsophagusStyle.topArch * math.sin(math.pi * j / arch)),
    ];
  }

  /// The way along the course at row [i], a unit.
  static Offset _way(int i) {
    final Offset m = _course.across[i];
    return Offset(m.dy, -m.dx);
  }

  /// The row nearest [s] millimetres along it.
  static int _rowAt(double s) {
    int best = 0;
    for (int i = 1; i < _rows; i++) {
      if ((_along(i) - s).abs() < (_along(best) - s).abs()) {
        best = i;
      }
    }
    return best;
  }

  /// The point of its middle [s] millimetres along it.
  static Offset _middleAt(double s) {
    int j = 1;
    while (j < _rows - 1 && _along(j) < s) {
      j++;
    }
    final double span = _along(j) - _along(j - 1);
    return Offset.lerp(
      _course.centres[j - 1],
      _course.centres[j],
      span <= 0 ? 0 : ((s - _along(j - 1)) / span).clamp(0.0, 1.0),
    )!;
  }

  /// Where the body goes into it, in millimetres: on its middle, so far
  /// along it.
  static final Offset siteMm = _middleAt(EsophagusAnatomy.siteAlong);

  /// The lining's edges, the mucosa's surface, down either side.
  static final List<Offset> _liningRightMm = _edgeMm(5, 1);
  static final List<Offset> _liningLeftMm = _edgeMm(5, -1);

  /// The folds' middle lines, in millimetres, each so far across the
  /// lining as it says, wandering a little along it.
  static final List<List<Offset>> _foldsMm = <List<Offset>>[
    for (final (double u, double from, double to, int seed)
        in EsophagusAnatomy.folds)
      () {
        final math.Random random = math.Random(seed);
        final double wavePhase = random.nextDouble() * 2 * math.pi;
        final double ripplePhase = random.nextDouble() * 2 * math.pi;
        return <Offset>[
          for (int i = 0; i < _rows; i++)
            if (_along(i) >= from && _along(i) <= to)
              () {
                final double s = _along(i);
                final double wander =
                    EsophagusAnatomy.wander *
                    (0.65 *
                            math.sin(
                              s / EsophagusAnatomy.wave * 2 * math.pi +
                                  wavePhase,
                            ) +
                        0.35 *
                            math.sin(
                              s / EsophagusAnatomy.ripple * 2 * math.pi +
                                  ripplePhase,
                            ));
                // From the body's right edge of the lining at -1 to its
                // left at 1.
                return _course.centres[i] -
                    _course.across[i] *
                        ((u + wander) * (_halfMm[i] - _wallMm[i]));
              }(),
        ];
      }(),
  ];

  /// The Z-line, from the mucosa's outer edge on the body's right to its
  /// left at the gastroesophageal junction: its tongues of the stomach's
  /// mucosa reach up into the esophagus's, rounded, each its own height.
  static final List<Offset> _zLineMm = () {
    final int row = _rowAt(EsophagusAnatomy.length);
    final Offset right = _sideMm(row, 1, _depthsMm[row][4]);
    final Offset left = _sideMm(row, -1, _depthsMm[row][4]);
    final Offset up = -_way(row);
    const int tongues = EsophagusAnatomy.tongues;
    final math.Random random = math.Random(EsophagusStyle.seed);
    final List<double> heights = <double>[
      for (int k = 0; k < tongues; k++)
        EsophagusAnatomy.tongue * (0.55 + 0.45 * random.nextDouble()),
    ];
    const int steps = tongues * 8;
    return <Offset>[
      for (int i = 0; i <= steps; i++)
        () {
          final double s = i / steps;
          final double within = s * tongues;
          final int k = math.min(tongues - 1, within.floor());
          final double rise = math.sin(math.pi * (within - k));
          return Offset.lerp(right, left, s)! + up * (heights[k] * rise * rise);
        }(),
    ];
  }();

  /// The stomach's mucosa past the Z-line, its own coat in the cut wall
  /// with it: the Z-line, and the submucosa's inner edge down the body's
  /// left side to where the cut ends, across it and back up the right.
  static final List<Offset> _gastricMm = () {
    final int from = _rowAt(EsophagusAnatomy.length);
    final List<Offset> right = _edgeMm(4, 1);
    final List<Offset> left = _edgeMm(4, -1);
    return <Offset>[
      ..._zLineMm,
      for (int i = from + 1; i < _rows; i++) left[i],
      for (int i = _rows - 1; i > from; i--) right[i],
    ];
  }();

  /// The glands in the submucosa, down either side, in millimetres.
  static final List<Offset> _glandsMm = () {
    final math.Random random = math.Random(EsophagusStyle.seed + 1);
    final List<Offset> out = <Offset>[];
    for (final double side in <double>[1, -1]) {
      double s =
          EsophagusAnatomy.glandApart / 2 +
          EsophagusAnatomy.glandJitter * random.nextDouble();
      while (s < EsophagusAnatomy.length + 8) {
        final int i = _rowAt(s);
        final List<double> d = _depthsMm[i];
        out.add(_sideMm(i, side, (d[3] + d[4]) / 2));
        s +=
            EsophagusAnatomy.glandApart +
            EsophagusAnatomy.glandJitter * (2 * random.nextDouble() - 1);
      }
    }
    return out;
  }();

  /// How far [mm] lies from the nearest fold's middle line, in
  /// millimetres. For tests.
  static double clearOfFolds(Offset mm) {
    double best = double.infinity;
    for (final List<Offset> fold in _foldsMm) {
      best = math.min(best, _toLine(fold, mm, closed: false));
    }
    return best;
  }

  /// How far [mm] lies inside the lining, from the nearer of its edges, in
  /// millimetres: below zero in the wall or outside it. For tests.
  static double clearOfWall(Offset mm) {
    final List<Offset> lining = _ringMm(5);
    final double d = _toLine(lining, mm, closed: true);
    return _inside(lining, mm) ? d : -d;
  }

  /// How thick its wall is and how far it reaches to either side of its
  /// middle, [s] millimetres along it. For tests.
  static double wallAt(double s) => _lerp(EsophagusAnatomy.wall, s);
  static double halfAt(double s) => _lerp(EsophagusAnatomy.half, s);

  /// How long its course is followed, in millimetres, to where its cut
  /// ends. For tests.
  static double get courseLength => _along(_rows - 1);

  /// How far along it the point of its middle nearest [mm] lies. For
  /// tests.
  static double alongOf(Offset mm) {
    int best = 0;
    for (int i = 1; i < _rows; i++) {
      if ((_course.centres[i] - mm).distanceSquared <
          (_course.centres[best] - mm).distanceSquared) {
        best = i;
      }
    }
    return _along(best);
  }

  // The parts, laid in the scene.

  /// The shapes inside each edge between the wall's coats: the fibrous
  /// coat's inner edge, the line between the muscle's planes, the
  /// muscularis's inner edge, the submucosa's, and the lining, the mucosa's
  /// surface.
  late final List<Offset> fibrousInner = _placed(_ringMm(1));
  late final List<Offset> muscleInner = _placed(_ringMm(3));
  late final List<Offset> submucosaInner = _placed(_ringMm(4));
  late final List<Offset> lining = _placed(_ringMm(5));

  /// The line between the muscle's two planes, down either side.
  late final List<List<Offset>> planes = <List<Offset>>[
    _placed(_edgeMm(2, 1)),
    _placed(_edgeMm(2, -1)),
  ];

  /// The lining's edges down either side, and the lines they turn up to
  /// the cut from, point for point.
  late final List<(List<Offset>, List<Offset>)> rims =
      <(List<Offset>, List<Offset>)>[
        for (final (List<Offset> edge, double side) in <(List<Offset>, double)>[
          (_liningRightMm, 1),
          (_liningLeftMm, -1),
        ])
          (
            _placed(edge),
            <Offset>[
              for (int i = 0; i < _rows; i++)
                place(
                  edge[i] - _course.across[i] * (side * EsophagusStyle.rim),
                ),
            ],
          ),
      ];

  /// The folds' middle lines, and each as the crease cut along it,
  /// tapering in from its ends.
  late final List<List<Offset>> folds = <List<Offset>>[
    for (final List<Offset> fold in _foldsMm) _placed(fold),
  ];
  late final Path creases = () {
    final Path path = Path();
    for (final List<Offset> fold in _foldsMm) {
      path.addPolygon(
        _placed(
          _tapered(fold, EsophagusStyle.crease / 2, EsophagusStyle.creaseTaper),
        ),
        true,
      );
    }
    return path;
  }();

  /// The Z-line, and the stomach's mucosa past it.
  late final List<Offset> zLine = _placed(_zLineMm);
  late final List<Offset> gastric = _placed(_gastricMm);

  /// The glands' middles, and how big each is.
  late final List<Offset> glands = _placed(_glandsMm);
  late final double glandRadius = mm(EsophagusAnatomy.gland);

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(EsophagusStyle.edgeStep), bend: 0.9);

  /// The pharynx above it and the stomach below, cut short; the aorta,
  /// cut where its arch crosses in front of it; the diaphragm either side
  /// of the hiatus, cut short.
  late final TubeCourse pharynx = _tube(EsophagusAnatomy.pharynx);
  late final TubeCourse stomach = _tube(EsophagusAnatomy.stomach);
  late final TubeCourse aorta = _tube(EsophagusAnatomy.aorta);
  late final List<TubeCourse> diaphragm = <TubeCourse>[
    for (final AnatomyTube t in EsophagusAnatomy.diaphragm) _tube(t),
  ];

  /// What runs on beside the esophagus.
  late final List<TubeCourse> beside = <TubeCourse>[
    pharynx,
    stomach,
    aorta,
    ...diaphragm,
  ];

  // Where the parts are named.

  late final Offset pharynxName = place(EsophagusAnatomy.pharynxName);
  late final Offset archName = place(EsophagusAnatomy.archName);
  late final Offset stomachName = place(EsophagusAnatomy.stomachName);
  late final Offset cervicalName = place(
    _middleAt(EsophagusAnatomy.cervicalName),
  );
  late final Offset thoracicName = place(
    _middleAt(EsophagusAnatomy.thoracicName),
  );
  late final Offset abdominalName = place(
    _middleAt(EsophagusAnatomy.abdominalName),
  );

  /// The sphincters, each named in the muscle of its wall on the body's
  /// left, the lower above the hiatus.
  late final Offset upperSphincterName = _muscleAt(
    EsophagusAnatomy.upperSphincterName,
    -1,
  );
  late final Offset lowerSphincterName = _muscleAt(
    EsophagusAnatomy.lowerSphincterName,
    -1,
  );

  Offset _muscleAt(double s, double side) {
    final int i = _rowAt(s);
    return place(_sideMm(i, side, (_depthsMm[i][1] + _depthsMm[i][3]) / 2));
  }

  /// The Z-line named an eighth of the way across from the body's right,
  /// where it lies lowest, and the diaphragm at the cut end of its right
  /// half, its higher.
  late final Offset zLineName = zLine[zLine.length ~/ 8];
  late final Offset diaphragmName = diaphragm.first.centres.last;

  /// The gland nearest [p].
  Offset glandNear(Offset p) {
    Offset best = glands.first;
    for (final Offset q in glands) {
      if ((q - p).distanceSquared < (best - p).distanceSquared) {
        best = q;
      }
    }
    return best;
  }

  /// Where the esophagus and what is drawn beside it reach furthest to
  /// either side at the height of [at]: the outline's crossings there, and
  /// the tubes' where they pass it, with room to spare.
  (Offset, Offset) edgesAt(Offset at) {
    double left = double.infinity;
    double right = double.negativeInfinity;
    for (final double x in _crossings(outlinePoints, at.dy)) {
      left = math.min(left, x);
      right = math.max(right, x);
    }
    final double clear = mm(EsophagusStyle.nameClear);
    for (final TubeCourse tube in beside) {
      for (int i = 0; i < tube.length; i++) {
        if (tube.shown[i] <= EsophagusStyle.nameShown) {
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

  /// Where the step from the body meets the esophagus's outline and the
  /// body's, besides their tops, each picked out of either outline alike at
  /// the same height in the scene, the drawing being laid on the body's
  /// outline at its site: either side a little below its top, where the two
  /// are cut through, and level with the site; the outermost point toward
  /// the body's left below it, where it turns to the cardia; and its lowest
  /// point, at the cardia.
  late final List<int Function(List<Offset>)> _marks = () {
    final double top = place(_middleAt(EsophagusStyle.markTop)).dy;
    final double middle = site.dy;
    final double low = site.dy + mm(EsophagusStyle.markLow);
    return <int Function(List<Offset>)>[
      (List<Offset> p) => _levelAt(p, -1, top),
      (List<Offset> p) => _levelAt(p, 1, top),
      (List<Offset> p) => _levelAt(p, 1, middle),
      (List<Offset> p) => _outermostBelow(p, 1, low),
      _lowest,
      (List<Offset> p) => _levelAt(p, -1, middle),
    ];
  }();

  /// The point of [points] where they cross the height [y] furthest to
  /// [side], -1 the left and 1 the right: of the two ends of the stretch
  /// that crosses it there, the nearer, as `OutlineMarks.level` picks it.
  static int _levelAt(List<Offset> points, double side, double y) {
    final int n = points.length;
    int best = 0;
    double outermost = double.negativeInfinity;
    for (int i = 0; i < n; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % n];
      if ((a.dy <= y) == (b.dy <= y)) {
        continue;
      }
      final double t = (y - a.dy) / (b.dy - a.dy);
      final double x = (a.dx + (b.dx - a.dx) * t) * side;
      if (x > outermost) {
        outermost = x;
        best = t < 0.5 ? i : (i + 1) % n;
      }
    }
    return best;
  }

  /// The point of [points] furthest to [side] of those below the height
  /// [y].
  static int _outermostBelow(List<Offset> points, double side, double y) {
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      if (points[i].dy < y) {
        continue;
      }
      if (best < 0 || (points[i].dx - points[best].dx) * side > 0) {
        best = i;
      }
    }
    return best;
  }

  static int _lowest(List<Offset> points) {
    int best = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy > points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The points of the esophagus's own outline where the step from the
  /// body meets the body's, for tests: in the order round it from the top.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

/// [table]'s value at [s], straight between its points, held at its ends.
double _lerp(List<(double, double)> table, double s) {
  if (s <= table.first.$1) {
    return table.first.$2;
  }
  for (int i = 1; i < table.length; i++) {
    final (double s1, double v1) = table[i];
    if (s <= s1) {
      final (double s0, double v0) = table[i - 1];
      return v0 + (v1 - v0) * (s - s0) / (s1 - s0);
    }
  }
  return table.last.$2;
}

/// Where the closed outline [points] crosses the level [y].
List<double> _crossings(List<Offset> points, double y) {
  final List<double> out = <double>[];
  final int n = points.length;
  for (int i = 0; i < n; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    if ((a.dy > y) != (b.dy > y)) {
      out.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
    }
  }
  return out;
}

/// The shape of a line [half] wide to either side, narrowing to nothing
/// over [taper] at each end.
List<Offset> _tapered(List<Offset> line, double half, double taper) {
  final List<double> along = <double>[0];
  for (int i = 1; i < line.length; i++) {
    along.add(along.last + (line[i] - line[i - 1]).distance);
  }
  final double total = along.last;
  final int n = line.length;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset t = _unit(
      line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)],
    );
    final Offset across = Offset(-t.dy, t.dx);
    final double w =
        half * _smooth(along[i] / taper) * _smooth((total - along[i]) / taper);
    left.add(line[i] + across * w);
    right.add(line[i] - across * w);
  }
  return <Offset>[...left, ...right.reversed];
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

Offset _unit(Offset p) {
  final double length = p.distance;
  return length <= 0 ? Offset.zero : p / length;
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
