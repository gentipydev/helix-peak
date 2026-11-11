import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import '../../voronoi.dart';
import 'lung_anatomy.dart';
import 'lung_style.dart';

/// Where in the lung the zoom's cell lives, by the Atlas's name for it.
enum LungHome {
  /// The alveoli, the parenchyma of the cut face: the alveolar cells, and
  /// any cell the Atlas finds in the lung that lives in neither of the
  /// others (its macrophages, its fibroblasts, its capillaries' cells).
  alveoli,

  /// The lining of the bronchi: the airways' own cells, from the basal
  /// cells to the ciliated, secretory and club cells, the ionocytes, the
  /// neuroendocrine and tuft cells, the submucosal glands' cells, and the
  /// bronchial muscle's.
  airways,

  /// The visceral pleura: its mesothelial cells.
  pleura;

  static LungHome of(String? cell) {
    if (cell == null) {
      return alveoli;
    }
    final String name = cell.toLowerCase();
    if (name.contains('mesothelial')) {
      return pleura;
    }
    if (name.contains('respiratory') ||
        name.contains('club') ||
        name.contains('ciliated') ||
        name.contains('deuterosomal') ||
        name.contains('ionocyte') ||
        name.contains('neuroendocrine') ||
        name.contains('tuft') ||
        name.contains('submucosal gland') ||
        name.contains('basal') ||
        name.contains('smooth muscle')) {
      return airways;
    }
    return alveoli;
  }
}

/// An airway of the left lung's cut face laid in the scene: its course,
/// and its generation from the trachea.
typedef LungTube = ({TubeCourse course, int generation});

/// A bronchus cut across where it crosses the cut, in the scene: its
/// middle and radius, and its artery's beside it.
typedef LungCrossing = ({
  Offset centre,
  double radius,
  Offset artery,
  double arteryRadius,
});

/// The lungs as the zoom's organ scene draws them, in place, seen from the
/// front, the left lung cut open: every part in the scene's units at its
/// real size, the middle of the body's outline of the left lung at the
/// origin.
///
/// The lungs are drawn from general anatomy ([LungAnatomy]) and laid on the
/// body's outline of the left lung so that the place it is gone into in the
/// anatomy ([LungAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline in toward the
/// left lung's own ([pathAt]); the body's right lung ([others]) gives way
/// under the right lung drawn here. Where the zoom's cell lives is [home].
/// Everything here is geometry: what it is drawn in is `LungArt`'s.
final class LungForm {
  LungForm({
    required List<Offset> diagram,
    required this.others,
    required this.site,
    required double length,
    required this.view,
    this.home = LungHome.alveoli,
  }) : scale = length / LungAnatomy.height {
    final List<Offset> diagramDense = Contour(diagram).sampled(8).points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool reversed = _area(_outlineMm).sign != _area(diagramDense).sign;
    final List<Offset> placed = _placed(_outlineMm);
    outlinePoints = reversed ? placed.reversed.toList() : placed;
    outline = Path()..addPolygon(outlinePoints, true);
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: LungStyle.morphPoints,
      bed: mm(LungStyle.bed),
      marks: _marks,
    );
  }

  /// The left lung where the body draws the lung as [part], in a view
  /// [view] metres across, the cell living in it at [home].
  factory LungForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    LungHome home = LungHome.alveoli,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return LungForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      others: <List<Offset>>[
        for (final List<Offset> other in part.others)
          <Offset>[for (final Offset p in other) placed(p)],
      ],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the lung, in the scene: the left lung's
  /// lingula.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Where in the lung the zoom's cell lives.
  final LungHome home;

  /// The body's other outlines of the lung, its right lung, in the scene.
  final List<List<Offset>> others;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The left lung's outline, the cut's edge, and the points it is
  /// followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - LungAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => LungAnatomy.site + (p - site) / scale;

  /// How far the left lung's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the left lung's at 1, and [bed] of the way on toward the
  /// bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the left lung's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every lung.

  /// The left lung's outline, the right lung's, in millimetres.
  static final List<Offset> _outlineMm = _closedCurve(
    LungAnatomy.leftOutline,
    LungStyle.outlineStep,
  );
  static final List<Offset> _rightMm = _closedCurve(
    LungAnatomy.rightOutline,
    LungStyle.outlineStep,
  );

  /// The left lung's outline followed more coarsely, what clearances and
  /// depths are measured by: its chords part from the curve by under a
  /// twentieth of a millimetre.
  static final List<Offset> _coarseMm = <Offset>[
    for (int i = 0; i < _outlineMm.length; i += 3) _outlineMm[i],
  ];

  /// The left lung's oblique fissure, followed closely, in millimetres.
  static final List<Offset> _fissureMm = _smoothLine(
    LungAnatomy.fissure,
    LungStyle.outlineStep,
  );

  /// The side of the fissure the upper lobe lies on, far out round it: the
  /// upper lobe is the outline's part inside it.
  static final List<Offset> _upperSideMm = <Offset>[
    ..._fissureMm,
    Offset(_fissureMm.last.dx, 600),
    const Offset(-400, 600),
    const Offset(-400, -400),
    const Offset(400, -400),
    Offset(400, _fissureMm.first.dy - 400),
  ];

  /// Whether [mm] lies in the upper lobe's side of the fissure.
  static bool _upperSide(Offset mm) => _inside(_upperSideMm, mm);

  /// How far [mm] lies from the left lung's pleura, in millimetres: from
  /// its outline, or from the fissure where nearer; below zero outside
  /// the outline.
  static double pleuraDepth(Offset mm) {
    final double edge = _toLine(_coarseMm, mm, closed: true);
    if (!_inside(_coarseMm, mm)) {
      return -edge;
    }
    return math.min(edge, _toLine(_fissureMm, mm, closed: false));
  }

  /// The left lung's outline in millimetres, and its fissure. For tests.
  static List<Offset> get outlineMm => _outlineMm;
  static List<Offset> get fissureMm => _fissureMm;

  /// Whether [mm] lies in the upper lobe, inside the outline. For tests.
  static bool inUpperLobe(Offset mm) =>
      _inside(_outlineMm, mm) && _upperSide(mm);

  // The airways.

  /// Every airway of the cut face, in millimetres: the anatomy's, laid by
  /// hand down to the segmental bronchi, and those the rule branches on
  /// from each of these, each kept clear of the pleura, the fissure, the
  /// site and the airways laid before it.
  static final List<LungAirway> _airwaysMm = () {
    final List<LungAirway> out = <LungAirway>[...LungAnatomy.airways];
    final math.Random random = math.Random(LungStyle.seed);
    // Every airway's middle line, followed closely, to keep the new ones
    // clear of: each with its radius.
    final List<(List<Offset>, double)> laid = <(List<Offset>, double)>[
      for (final LungAirway a in out)
        (_smoothLine(a.course, LungStyle.outlineStep), a.radius),
    ];

    bool clear(List<Offset> line, double radius, int parent) {
      for (final Offset p in line.skip(2)) {
        if (!_inside(_coarseMm, p) || !_upperSide(p)) {
          return false;
        }
        if (_toLine(_coarseMm, p, closed: true) <
            radius + LungAnatomy.edgeClear) {
          return false;
        }
        if (_toLine(_fissureMm, p, closed: false) <
            radius + LungAnatomy.fissureClear) {
          return false;
        }
        if ((p - LungAnatomy.site).distance < radius + LungAnatomy.siteClear) {
          return false;
        }
      }
      // Not where it leaves the fork it shares with its sister.
      final double fork = 3 * radius + 3;
      for (int k = 0; k < laid.length; k++) {
        if (k == parent) {
          continue;
        }
        final (List<Offset> other, double r) = laid[k];
        for (final Offset p in line) {
          if ((p - line.first).distance < fork) {
            continue;
          }
          if (_toLine(other, p, closed: false) < radius + r + 1.2) {
            return false;
          }
        }
      }
      return true;
    }

    // A branch from [from] along [way], [generation] deep, from the airway
    // laid at [parent]; and on from its end, to the deepest generation.
    void grow(Offset from, Offset way, int generation, int parent) {
      final int g = generation - 4;
      if (g < 0 ||
          g >= LungAnatomy.branchRadius.length ||
          generation > LungAnatomy.deepest) {
        return;
      }
      final double radius = LungAnatomy.branchRadius[g];
      for (final double share in <double>[1, 0.65]) {
        final double length = LungAnatomy.branchLength[g] * share;
        final Offset bow =
            Offset(-way.dy, way.dx) *
            ((random.nextDouble() - 0.5) * 0.12 * length);
        final Offset end = from + way * length;
        final List<Offset> course = <Offset>[
          from,
          Offset.lerp(from, end, 0.5)! + bow,
          end,
        ];
        final List<Offset> line = _smoothLine(course, LungStyle.outlineStep);
        if (!clear(line, radius, parent)) {
          continue;
        }
        out.add((
          course: course,
          radius: radius,
          generation: generation,
          forks: false,
        ));
        laid.add((line, radius));
        final int at = laid.length - 1;
        _fork(way, random, (Offset w, bool major) {
          grow(end, w, generation + 1, at);
        });
        return;
      }
    }

    for (int k = 0; k < LungAnatomy.airways.length; k++) {
      final LungAirway a = LungAnatomy.airways[k];
      if (!a.forks) {
        continue;
      }
      final List<Offset> line = laid[k].$1;
      final Offset end = line.last;
      final Offset way = _unit(line.last - line[line.length - 3]);
      _fork(way, random, (Offset w, bool major) {
        grow(end, w, a.generation + 1, k);
      });
      // A segmental bronchus's side branches, a third and two thirds along
      // it, to either side in turn.
      for (
        int j = 0;
        a.generation == 3 && j < LungAnatomy.sideBranches.length;
        j++
      ) {
        final int at = (line.length * LungAnatomy.sideBranches[j]).round();
        final Offset along = _unit(line[at + 2] - line[at - 2]);
        final double side = (k + j).isEven ? 1 : -1;
        grow(
          line[at],
          _turned(along, side * LungAnatomy.branchTurnMinor * 1.2),
          a.generation + 2,
          k,
        );
      }
    }
    return out;
  }();

  /// [way] parted at a fork, the larger branch turning a little to one
  /// side and the smaller more to the other, which side by chance; [each]
  /// is called with each branch's way, the larger first.
  static void _fork(
    Offset way,
    math.Random random,
    void Function(Offset way, bool major) each,
  ) {
    final double side = random.nextBool() ? 1 : -1;
    final double jitter = (random.nextDouble() - 0.5) * 0.16;
    each(_turned(way, side * (LungAnatomy.branchTurn + jitter)), true);
    each(_turned(way, -side * (LungAnatomy.branchTurnMinor - jitter)), false);
  }

  /// Every airway of the cut face, in millimetres. For tests.
  static List<LungAirway> get airwaysMm => _airwaysMm;

  /// Each artery beside an airway, in millimetres: from the lobar bronchus
  /// on, the whole of its length, on its side toward the apex and the
  /// costal border, as the artery runs above and beside its bronchus; where
  /// it passes another airway, that airway is drawn over it.
  static final List<(List<Offset>, double)> _besideMm = () {
    final List<(List<Offset>, double)> out = <(List<Offset>, double)>[];
    for (final LungAirway a in _airwaysMm) {
      if (a.generation < 2) {
        continue;
      }
      final List<Offset> line = _smoothLine(a.course, LungStyle.outlineStep);
      final double r = a.radius * LungAnatomy.arteryShare;
      final double apart = a.radius + r * (1 + LungAnatomy.arteryGap);
      final Offset middle = _normal(line, line.length ~/ 2);
      final double side =
          middle.dx * LungAnatomy.arteryToward.dx +
                  middle.dy * LungAnatomy.arteryToward.dy >=
              0
          ? 1
          : -1;
      out.add((
        <Offset>[
          for (int i = 0; i < line.length; i += 2)
            line[i] + _normal(line, i) * (side * apart),
          line.last + _normal(line, line.length - 1) * (side * apart),
        ],
        r,
      ));
    }
    return out;
  }();

  /// Every artery beside an airway, in millimetres. For tests.
  static List<(List<Offset>, double)> get besideMm => _besideMm;

  // The lobules.

  /// The septa between the left lung's secondary lobules, in millimetres,
  /// each edge with how deep under the pleura its middle lies: every edge
  /// of the lobules whose middles lie inside the outline.
  static final List<(Offset, Offset, double)> _septaMm = _mosaic(
    _coarseMm,
    LungAnatomy.lobule,
    LungStyle.seed,
    depth: pleuraDepth,
  );

  /// The lobules marked on the right lung's surface, in millimetres.
  static final List<(Offset, Offset, double)> _surfaceSeptaMm = _mosaic(
    <Offset>[for (int i = 0; i < _rightMm.length; i += 3) _rightMm[i]],
    LungAnatomy.lobule * 1.1,
    LungStyle.seed + 1,
    depth: (Offset _) => 0,
  );

  /// The septa in millimetres, each with its depth. For tests.
  static List<(Offset, Offset, double)> get septaMm => _septaMm;

  /// The edges of a relaxed, jittered mosaic of cells [pitch] apart over
  /// [shape], those whose middles lie inside it, each with [depth] at its
  /// middle.
  static List<(Offset, Offset, double)> _mosaic(
    List<Offset> shape,
    double pitch,
    int seed, {
    required double Function(Offset) depth,
  }) {
    final math.Random random = math.Random(seed);
    final Rect bounds = _bounds(shape).inflate(1.5 * pitch);
    final double rowHeight = pitch * math.sqrt(3) / 2;
    final List<Offset> seeds = <Offset>[];
    int row = 0;
    for (double y = bounds.top; y <= bounds.bottom; y += rowHeight, row++) {
      final double shift = row.isOdd ? pitch / 2 : 0;
      for (double x = bounds.left + shift; x <= bounds.right; x += pitch) {
        seeds.add(
          Offset(x, y) +
              Offset(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1) *
                  (pitch * LungAnatomy.lobuleJitter),
        );
      }
    }
    const double reachShare = 1.3;
    final List<Offset> even = relaxedSeeds(
      seeds,
      reachShare * pitch,
      times: LungAnatomy.lobuleRelax,
    );
    final Map<(int, int, int, int), (Offset, Offset, double)> edges =
        <(int, int, int, int), (Offset, Offset, double)>{};
    int key(double v) => (v * 1000).round();
    for (final List<Offset> cell in voronoiCells(even, reachShare * pitch)) {
      for (int i = 0; i < cell.length; i++) {
        final Offset a = cell[i];
        final Offset b = cell[(i + 1) % cell.length];
        if ((b - a).distance < 0.05) {
          continue;
        }
        final Offset middle = Offset.lerp(a, b, 0.5)!;
        if (!_inside(shape, middle)) {
          continue;
        }
        final (int, int) ka = (key(a.dx), key(a.dy));
        final (int, int) kb = (key(b.dx), key(b.dy));
        final (int, int, int, int) k =
            ka.$1 < kb.$1 || (ka.$1 == kb.$1 && ka.$2 <= kb.$2)
            ? (ka.$1, ka.$2, kb.$1, kb.$2)
            : (kb.$1, kb.$2, ka.$1, ka.$2);
        edges.putIfAbsent(k, () => (a, b, depth(middle)));
      }
    }
    return edges.values.toList();
  }

  // The parts, laid in the scene.

  /// The left lung's outline drawn in by the rim the cut face turns away
  /// over under the pleura, point for point.
  late final List<Offset> rimInner = () {
    final int n = outlinePoints.length;
    final double inward =
        _inside(
          outlinePoints,
          outlinePoints[0] + _normal(outlinePoints, 0) * mm(1),
        )
        ? 1
        : -1;
    return <Offset>[
      for (int i = 0; i < n; i++)
        outlinePoints[i] +
            _closedNormal(outlinePoints, i) * (inward * mm(LungStyle.rim)),
    ];
  }();

  /// The right lung's outline, in the scene, and the points it is followed
  /// by.
  late final List<Offset> rightPoints = _placed(_rightMm);
  late final Path rightOutline = Path()..addPolygon(rightPoints, true);

  /// The left lung's two lobes, each the outline's part on its side of the
  /// fissure.
  late final Path upperLobe = Path.combine(
    PathOperation.intersect,
    outline,
    Path()..addPolygon(_placed(_upperSideMm), true),
  );
  late final Path lowerLobe = Path.combine(
    PathOperation.difference,
    outline,
    Path()..addPolygon(_placed(_upperSideMm), true),
  );

  /// The fissures as creases, tapering in from their ends: the left lung's
  /// oblique fissure, and the right lung's oblique and horizontal ones; and
  /// the left one's middle line.
  late final Path fissure = _crease(_fissureMm);
  late final List<Offset> fissureLine = _placed(_fissureMm);
  late final Path rightFissures = Path()
    ..addPath(
      _crease(_smoothLine(LungAnatomy.rightOblique, LungStyle.outlineStep)),
      Offset.zero,
    )
    ..addPath(
      _crease(_smoothLine(LungAnatomy.rightHorizontal, LungStyle.outlineStep)),
      Offset.zero,
    );

  Path _crease(List<Offset> line) => Path()
    ..addPolygon(
      _placed(_tapered(line, LungStyle.fissure / 2, LungStyle.fissureTaper)),
      true,
    );

  /// The septa as paths of lines, from under the pleura in: each band a
  /// [septaBands]th of their reach deeper than the one before, and the
  /// right lung's surface's.
  static const int septaBands = 4;
  late final List<Path> septa = () {
    final List<Path> bands = <Path>[
      for (int b = 0; b < septaBands; b++) Path(),
    ];
    for (final (Offset a, Offset b, double depth) in _septaMm) {
      final int band = (depth / LungAnatomy.septaReach * septaBands).floor();
      if (band >= septaBands) {
        continue;
      }
      final Offset p = place(a);
      final Offset q = place(b);
      bands[math.max(0, band)]
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
    return bands;
  }();
  late final Path surfaceSepta = () {
    final Path path = Path();
    for (final (Offset a, Offset b, double _) in _surfaceSeptaMm) {
      final Offset p = place(a);
      final Offset q = place(b);
      path
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
    return path;
  }();

  TubeCourse _course(List<Offset> points, List<double> radii) => TubeCourse(
    AnatomyTube(points, radii),
    place,
    scale,
    mm(LungStyle.edgeStep),
    bend: 0.9,
  );

  /// The airways laid open in the cut, the main bronchus first.
  late final List<LungTube> airways = <LungTube>[
    for (final LungAirway a in _airwaysMm)
      (
        course: _course(a.course, <double>[
          for (final Offset _ in a.course) a.radius,
        ]),
        generation: a.generation,
      ),
  ];

  /// The arteries laid open in the cut: the left pulmonary artery's course
  /// over the main bronchus, and each artery beside its airway.
  late final List<TubeCourse> arteries = <TubeCourse>[
    _course(LungAnatomy.arteryCut, <double>[
      for (final Offset _ in LungAnatomy.arteryCut) LungAnatomy.arteryRadius,
    ]),
    for (final (List<Offset> line, double r) in _besideMm)
      _course(line, <double>[for (final Offset _ in line) r]),
  ];

  /// The upper pulmonary vein laid open in the cut, from the hilum to where
  /// it turns back; and where the artery and the vein turn back, each cut
  /// across there.
  late final TubeCourse vein = _course(LungAnatomy.upperVeinCut, <double>[
    for (final Offset _ in LungAnatomy.upperVeinCut)
      LungAnatomy.upperVeinCutRadius,
  ]);
  late final (Offset, double) arteryEnd = (
    place(LungAnatomy.arteryCut.last),
    mm(LungAnatomy.arteryRadius),
  );
  late final (Offset, double) veinEnd = (
    place(LungAnatomy.upperVeinCut.last),
    mm(LungAnatomy.upperVeinCutRadius),
  );

  /// The veins cut across between the segments, in millimetres: those clear
  /// of every airway and artery, of the pleura, the fissure and the site.
  static final List<(Offset, double)> _veinsMm = () {
    final List<List<Offset>> airways = <List<Offset>>[
      for (final LungAirway a in _airwaysMm)
        _smoothLine(a.course, LungStyle.outlineStep),
    ];
    final List<(Offset, double)> out = <(Offset, double)>[];
    for (final (Offset c, double r) in LungAnatomy.veinsCrossed) {
      bool ok =
          _inside(_coarseMm, c) &&
          _toLine(_coarseMm, c, closed: true) > r + 2 &&
          _toLine(_fissureMm, c, closed: false) > r + 1.5 &&
          (c - LungAnatomy.site).distance > r + 6;
      for (int k = 0; k < airways.length && ok; k++) {
        ok =
            _toLine(airways[k], c, closed: false) >
            r + _airwaysMm[k].radius + 1;
      }
      for (final (List<Offset> line, double a) in _besideMm) {
        if (!ok) {
          break;
        }
        ok = _toLine(line, c, closed: false) > r + a + 1;
      }
      if (ok) {
        out.add((c, r));
      }
    }
    return out;
  }();

  /// The veins cut across, in millimetres. For tests.
  static List<(Offset, double)> get veinsMm => _veinsMm;

  /// The veins cut across between the segments, in the scene.
  late final List<(Offset, double)> veins = <(Offset, double)>[
    for (final (Offset c, double r) in _veinsMm) (place(c), mm(r)),
  ];

  /// The lower lobe's bronchus where it leaves the cut, and the lower
  /// lobe's bronchi crossing it, each with its artery beside it toward the
  /// lamp's side.
  late final List<LungCrossing> crossings = <LungCrossing>[
    for (final (Offset c, double r) in <(Offset, double)>[
      (LungAnatomy.lowerBronchus, LungAnatomy.lowerBronchusRadius),
      ...LungAnatomy.crossed,
    ])
      (
        centre: place(c),
        radius: mm(r),
        artery: place(
          c +
              const Offset(-0.62, -0.78) *
                  (r *
                      (1 +
                          LungAnatomy.arteryShare *
                              (1 + LungAnatomy.arteryGap))),
        ),
        arteryRadius: mm(r * LungAnatomy.arteryShare),
      ),
  ];

  // What runs outside the lungs, each a lit tube.

  /// The trachea, from the carina up to where it is cut below the larynx.
  late final TubeCourse trachea = _course(LungAnatomy.trachea, <double>[
    for (final Offset _ in LungAnatomy.trachea) LungAnatomy.tracheaRadius,
  ]);

  /// The main bronchi, from the carina to each lung.
  late final TubeCourse rightBronchus = _course(
    LungAnatomy.rightBronchus,
    <double>[
      for (final Offset _ in LungAnatomy.rightBronchus)
        LungAnatomy.rightBronchusRadius,
    ],
  );
  late final TubeCourse leftBronchus = _course(
    LungAnatomy.leftBronchus,
    <double>[
      for (final Offset _ in LungAnatomy.leftBronchus)
        LungAnatomy.leftBronchusRadius,
    ],
  );

  /// The root's vessels, each from the hilum to where it is cut short in
  /// the mediastinum: the left pulmonary artery and the two veins.
  late final TubeCourse rootArtery = _course(
    LungAnatomy.artery.reversed.toList(),
    <double>[
      for (final Offset _ in LungAnatomy.artery) LungAnatomy.arteryRadius,
    ],
  );
  late final TubeCourse rootUpperVein = _course(
    LungAnatomy.upperVein.reversed.toList(),
    <double>[
      for (final Offset _ in LungAnatomy.upperVein) LungAnatomy.upperVeinRadius,
    ],
  );
  late final TubeCourse rootLowerVein = _course(
    LungAnatomy.lowerVein.reversed.toList(),
    <double>[
      for (final Offset _ in LungAnatomy.lowerVein) LungAnatomy.lowerVeinRadius,
    ],
  );

  /// The trachea's cartilages, each from one side of it to the other at its
  /// height: their middles.
  late final List<(Offset, Offset)> rings = <(Offset, Offset)>[
    for (int k = 0; k < LungAnatomy.rings; k++)
      () {
        final double length =
            LungAnatomy.trachea.first.dy - LungAnatomy.trachea.last.dy;
        final double pitch =
            (length - LungAnatomy.ringFrom) / LungAnatomy.rings;
        final double y =
            LungAnatomy.trachea.first.dy -
            LungAnatomy.ringFrom -
            pitch * (k + 0.5);
        return (
          place(Offset(-LungAnatomy.tracheaRadius, y)),
          place(Offset(LungAnatomy.tracheaRadius, y)),
        );
      }(),
  ];

  /// How tall a cartilage is in the scene, and how far apart two lie.
  late final double ringDepth = mm(LungAnatomy.ringDepth);
  late final double ringPitch = mm(
    (LungAnatomy.trachea.first.dy -
            LungAnatomy.trachea.last.dy -
            LungAnatomy.ringFrom) /
        LungAnatomy.rings,
  );

  /// What runs outside the lungs, for the room they need.
  late final List<TubeCourse> outside = <TubeCourse>[
    trachea,
    rightBronchus,
    leftBronchus,
    rootArtery,
    rootUpperVein,
    rootLowerVein,
  ];

  // Where the parts are named.

  /// Where the cell lives: at the site in the alveoli; on the bronchus
  /// nearest the site for the airways; on the pleura nearest the site for
  /// the pleura.
  late final Offset homeName = switch (home) {
    LungHome.alveoli => site,
    LungHome.airways => () {
      Offset best = airways.first.course.centres.first;
      for (final LungTube a in airways) {
        for (final Offset p in a.course.centres) {
          if ((p - site).distanceSquared < (best - site).distanceSquared) {
            best = p;
          }
        }
      }
      return best;
    }(),
    LungHome.pleura => _nearest(outlinePoints, site),
  };
  late final Offset tracheaName = place(LungAnatomy.tracheaName);
  late final Offset bronchusName = place(LungAnatomy.bronchusName);
  late final Offset arteryName = place(LungAnatomy.arteryName);
  late final Offset upperLobeName = place(LungAnatomy.upperLobeName);
  late final Offset lowerLobeName = place(LungAnatomy.lowerLobeName);
  late final Offset rightLungName = place(LungAnatomy.rightLungName);

  static Offset _nearest(List<Offset> line, Offset p) {
    Offset best = line.first;
    for (final Offset q in line) {
      if ((q - p).distanceSquared < (best - p).distanceSquared) {
        best = q;
      }
    }
    return best;
  }

  /// Where the step from the body meets the left lung's outline and the
  /// body's, besides their apices: the costal border's outermost point;
  /// the base's lateral corner, where the costal border meets it, which the
  /// lowest point is not on the body's nearly level base (its lowest point
  /// there lies half way along it, and the base slid 51 mm to meet the
  /// lung's); the mediastinal border at the lingula's height and at the
  /// cardiac notch's, its deepest point on the lung's, so that the lingula
  /// and the notch draw in where the body's border is, level, and no point
  /// slides round them; and the hilum's innermost: each picked out of
  /// either outline alike.
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.3, 0.7),
        (List<Offset> p) => OutlineMarks.level(p, 1, 0.97),
        (List<Offset> p) => OutlineMarks.level(p, -1, 0.87),
        (List<Offset> p) => OutlineMarks.level(p, -1, 0.65),
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.25, 0.55),
      ];

  static int _topmost(List<Offset> points) {
    int best = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy < points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The points of an outline where the step from the body meets the
  /// body's, for tests: the apex, then the rest in the order of [_marks].
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topmost(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

/// [way] turned by [angle] radians, clockwise on screen.
Offset _turned(Offset way, double angle) {
  final double c = math.cos(angle);
  final double s = math.sin(angle);
  return Offset(way.dx * c - way.dy * s, way.dx * s + way.dy * c);
}

/// The left hand of the way along [line] at its point [i], a unit.
Offset _normal(List<Offset> line, int i) {
  final int n = line.length;
  final Offset t = _unit(
    line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)],
  );
  return Offset(-t.dy, t.dx);
}

/// The left hand of the way round the closed outline [line] at its point
/// [i], a unit.
Offset _closedNormal(List<Offset> line, int i) {
  final int n = line.length;
  final Offset t = _unit(line[(i + 1) % n] - line[(i - 1 + n) % n]);
  return Offset(-t.dy, t.dx);
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

/// How far along [line] each of its points lies.
List<double> _along(List<Offset> line) {
  final List<double> out = <double>[0];
  for (int i = 1; i < line.length; i++) {
    out.add(out.last + (line[i] - line[i - 1]).distance);
  }
  return out;
}

/// The shape of a line [half] wide to either side, narrowing to nothing
/// over [taper] at each end.
List<Offset> _tapered(List<Offset> line, double half, double taper) {
  final List<double> along = _along(line);
  final double total = along.last;
  final int n = line.length;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset across = _normal(line, i);
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
