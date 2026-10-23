import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'stomach_anatomy.dart';
import 'stomach_style.dart';

/// Where in the stomach the zoom's cell lives, which its drawing lights in
/// the mark, by the Atlas's name for the cell. By the kind of cell, never
/// by gene.
enum StomachHome {
  /// The mucosa: its pit, neck, parietal, chief, endocrine and dividing
  /// cells, and every cell that has no part of the stomach of its own to
  /// be drawn at its size (the lamina propria's fibroblasts and immune
  /// cells).
  mucosa,

  /// The muscularis: its smooth muscle cells, and the interstitial cells
  /// of Cajal among them.
  muscularis;

  /// Where a cell the Atlas calls [cell] lives.
  static StomachHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('smooth muscle') ||
        name.contains('interstitial cells of cajal')) {
      return muscularis;
    }
    return mucosa;
  }
}

/// The stomach as the zoom's organ scene draws it, opened from the front:
/// every part in the scene's units at its real size, the middle of the
/// body's outline of it at the origin.
///
/// The stomach is drawn from general anatomy ([StomachAnatomy]) and laid
/// on the body's outline of it so that the place it is gone into in the
/// anatomy ([StomachAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline in toward the
/// stomach's own ([pathAt]). Everything here is geometry: what it is drawn
/// in is `StomachArt`'s.
final class StomachForm {
  StomachForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.home = StomachHome.mucosa,
  }) : scale = length / StomachAnatomy.length {
    final List<Offset> knots = <Offset>[
      for (final Offset p in StomachAnatomy.outline) place(p),
    ];
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(StomachStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(StomachStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: StomachStyle.morphPoints,
      bed: mm(StomachStyle.bed),
      marks: _marks,
    );
  }

  /// The stomach where the body draws it as [part], in a view [view]
  /// metres across, its cells' [home] in it.
  factory StomachForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    StomachHome home = StomachHome.mucosa,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return StomachForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the stomach, in the scene: in its body,
  /// between two rugae.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final StomachHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The stomach's outline, the serosa, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - StomachAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => StomachAnatomy.site + (p - site) / scale;

  /// How far the stomach's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the stomach's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the stomach's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every stomach.

  /// The outline followed closely, in millimetres, and how thick the wall
  /// is at each of its points.
  static final List<Offset> _outlineMm = const Contour(StomachAnatomy.outline)
      .sampled(StomachStyle.outlineSpan)
      .points;
  static final List<double> _wallMm = () {
    const List<double> wall = StomachAnatomy.wall;
    const int span = StomachStyle.outlineSpan;
    final int n = wall.length;
    return <double>[
      for (int i = 0; i < n; i++)
        for (int k = 0; k < span; k++)
          wall[i] + (wall[(i + 1) % n] - wall[i]) * k / span,
    ];
  }();

  /// The way into the stomach at each of the outline's points, a unit.
  static final List<Offset> _inwardMm = () {
    final List<Offset> normals = _normals(_outlineMm, closed: true);
    final double inward = _inside(_outlineMm, _outlineMm[0] + normals[0] * 0.5)
        ? 1
        : -1;
    return <Offset>[for (final Offset n in normals) n * inward];
  }();

  /// The edges of the wall's coats, point for point with the outline, in
  /// millimetres: the serosa's inner edge, the muscularis's, the
  /// submucosa's and the mucosa's, its surface.
  static final List<List<Offset>> _coatsMm = () {
    final List<List<Offset>> out = <List<Offset>>[
      for (int k = 0; k < 4; k++) <Offset>[],
    ];
    for (int i = 0; i < _outlineMm.length; i++) {
      final double w = _wallMm[i];
      final double serosa = math.min(
        w * StomachAnatomy.serosaShare,
        StomachAnatomy.serosaMost,
      );
      final double mucosa = math.min(
        w * StomachAnatomy.mucosaShare,
        StomachAnatomy.mucosaMost,
      );
      final double submucosa = math.min(
        w * StomachAnatomy.submucosaShare,
        StomachAnatomy.submucosaMost,
      );
      final double muscle = math.max(0, w - serosa - mucosa - submucosa);
      final Offset p = _outlineMm[i];
      final Offset n = _inwardMm[i];
      double depth = 0;
      for (final (int k, double coat) in <(int, double)>[
        (0, serosa),
        (1, muscle),
        (2, submucosa),
        (3, mucosa),
      ]) {
        depth += coat;
        out[k].add(p + n * depth);
      }
    }
    return out;
  }();

  /// The mucosa's surface, the wall's inner edge, in millimetres.
  static List<Offset> get _innerMm => _coatsMm[3];

  /// The two curvatures' inner edges, each from the cardia to the pylorus,
  /// and how far along each its points lie: the greater from the incisura
  /// cardiaca round the fundus, the lesser from the esophagus's right
  /// margin the other way round the outline.
  static final List<Offset> _greaterMm = _run(
    StomachAnatomy.notch,
    StomachAnatomy.lowerLip,
    1,
  );
  static final List<Offset> _lesserMm = _run(
    StomachAnatomy.cardia,
    StomachAnatomy.upperLip,
    -1,
  );
  static final List<double> _greaterAlong = _along(_greaterMm);
  static final List<double> _lesserAlong = _along(_lesserMm);

  static List<Offset> _run(int from, int to, int step) {
    const int span = StomachStyle.outlineSpan;
    final List<Offset> inner = _innerMm;
    final int n = inner.length;
    final List<Offset> out = <Offset>[];
    for (int i = from * span; ; i += step) {
      out.add(inner[i % n]);
      if ((i - to * span) % n == 0) {
        break;
      }
    }
    return out;
  }

  /// How far along the greater curvature, and across from it to the
  /// lesser, at [t] of the way along both: the point [u] of the way across,
  /// and the way across, from the greater to the lesser.
  static (Offset, Offset) _rung(double t, double u) {
    final Offset g = _at(_greaterMm, _greaterAlong, t);
    final Offset l = _at(_lesserMm, _lesserAlong, t);
    return (Offset.lerp(g, l, u)!, l - g);
  }

  /// The rugae's middle lines, in millimetres: each ruga broken off a time
  /// or two along its length, as rugae are.
  static final List<List<Offset>> _rugaeMm = <List<Offset>>[
    for (final (double u, double from, double to, int seed)
        in StomachAnatomy.rugae)
      ..._ruga(u, from, to, math.Random(seed)),
  ];

  static List<List<Offset>> _ruga(
    double u,
    double from,
    double to,
    math.Random random,
  ) {
    final double wavePhase = random.nextDouble() * 2 * math.pi;
    final double ripplePhase = random.nextDouble() * 2 * math.pi;
    final double greater = _greaterAlong.last;
    // Where it breaks off, each break a stretch of its length, along the
    // greater curvature, kept off its ends.
    final double gap = StomachAnatomy.breakLength / greater;
    final List<(double, double)> breaks = <(double, double)>[
      for (int k = random.nextInt(StomachAnatomy.breaks + 1); k > 0; k--)
        () {
          final double at =
              from +
              0.15 * (to - from) +
              random.nextDouble() * 0.7 * (to - from);
          return (at - gap / 2, at + gap / 2);
        }(),
    ]..sort(((double, double) a, (double, double) b) => a.$1.compareTo(b.$1));
    final int steps = math.max(
      2,
      ((to - from) * greater / (2 * StomachStyle.edgeStep)).ceil(),
    );
    final List<List<Offset>> out = <List<Offset>>[];
    List<Offset> run = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final double t = from + (to - from) * i / steps;
      if (breaks.any(((double, double) b) => t > b.$1 && t < b.$2)) {
        if (run.length > 1) {
          out.add(run);
        }
        run = <Offset>[];
        continue;
      }
      final (Offset p, Offset across) = _rung(t, u);
      final double width = across.distance;
      if (width <= 0) {
        run.add(p);
        continue;
      }
      final double along = t * greater;
      final double wander =
          math.min(StomachAnatomy.wander, StomachAnatomy.wanderShare * width) *
          (0.65 *
                  math.sin(
                    along / StomachAnatomy.wave * 2 * math.pi + wavePhase,
                  ) +
              0.35 *
                  math.sin(
                    along / StomachAnatomy.ripple * 2 * math.pi + ripplePhase,
                  ));
      run.add(p + across / width * wander);
    }
    if (run.length > 1) {
      out.add(run);
    }
    return out;
  }

  /// The Z-line, from the esophagus's right margin to its left, where the
  /// curvatures begin: its tongues reach up into the esophagus, rounded,
  /// each its own height.
  static final List<Offset> _zLineMm = () {
    final Offset l = _lesserMm.first;
    final Offset g = _greaterMm.first;
    final Offset across = g - l;
    // Up, into the esophagus, which lies above it.
    final Offset normal = Offset(across.dy, -across.dx) / across.distance;
    final Offset up = normal.dy <= 0 ? normal : -normal;
    const int tongues = StomachAnatomy.tongues;
    final math.Random random = math.Random(StomachStyle.seed);
    final List<double> heights = <double>[
      for (int k = 0; k < tongues; k++)
        StomachAnatomy.tongue * (0.55 + 0.45 * random.nextDouble()),
    ];
    const int steps = tongues * 8;
    return <Offset>[
      for (int i = 0; i <= steps; i++)
        () {
          final double s = i / steps;
          final double within = s * tongues;
          final int k = math.min(tongues - 1, within.floor());
          final double rise = math.sin(math.pi * (within - k));
          return Offset.lerp(l, g, s)! + up * (heights[k] * rise * rise);
        }(),
    ];
  }();

  /// The esophagus's lining, above the Z-line, in millimetres, its own
  /// mucosa where the wall is cut as well: the submucosa's inner edge from
  /// its right margin round its cut end to its left, and back along the
  /// Z-line.
  static final List<Offset> _liningMm = () {
    const int span = StomachStyle.outlineSpan;
    final List<Offset> inner = _coatsMm[2];
    final int n = inner.length;
    const int from = StomachAnatomy.cardia * span;
    final int count =
        ((StomachAnatomy.notch - StomachAnatomy.cardia) * span) % n;
    return <Offset>[
      for (int k = 0; k <= count; k++) inner[(from + k) % n],
      ..._zLineMm.reversed,
    ];
  }();

  /// The esophagus's folds, from its cut end down to the Z-line.
  static final List<List<Offset>> _liningFoldsMm = () {
    const int span = StomachStyle.outlineSpan;
    final Offset topLeft = _outlineMm[0];
    final Offset topRight = _outlineMm[3 * span];
    final Offset l = _zLineMm.first;
    final Offset g = _zLineMm.last;
    return <List<Offset>>[
      for (final double s in StomachAnatomy.esophagealFolds)
        () {
          final Offset top = Offset.lerp(topLeft, topRight, s)!;
          final Offset foot = Offset.lerp(l, g, s)!;
          final Offset way = foot - top;
          final double length = way.distance;
          final Offset start = top + way / length * 1.5;
          final Offset end = foot - way / length * (StomachAnatomy.tongue + 1);
          final int steps = math.max(
            2,
            (length / StomachStyle.edgeStep).ceil(),
          );
          return <Offset>[
            for (int i = 0; i <= steps; i++)
              Offset.lerp(start, end, i / steps)!,
          ];
        }(),
    ];
  }();

  /// How far [p] lies from the nearest ruga's middle line, in millimetres.
  /// For tests.
  static double clearOfRugae(Offset mm) {
    double best = double.infinity;
    for (final List<Offset> ruga in _rugaeMm) {
      best = math.min(best, _toLine(ruga, mm, closed: false));
    }
    return best;
  }

  /// How far [p] lies inside the mucosa's surface, from the wall's inner
  /// edge, in millimetres: below zero in the wall or outside it. For tests.
  static double clearOfWall(Offset mm) {
    final double d = _toLine(_innerMm, mm, closed: true);
    return _inside(_innerMm, mm) ? d : -d;
  }

  /// How thick the wall is at the point of the outline nearest [mm], in
  /// millimetres. For tests.
  static double wallAt(Offset mm) {
    int best = 0;
    for (int i = 1; i < _outlineMm.length; i++) {
      if ((_outlineMm[i] - mm).distanceSquared <
          (_outlineMm[best] - mm).distanceSquared) {
        best = i;
      }
    }
    return _wallMm[best];
  }

  /// The two curvatures' lengths, the greater's and the lesser's, along
  /// their inner edges, in millimetres. For tests.
  static (double, double) get curvatures =>
      (_greaterAlong.last, _lesserAlong.last);

  // The parts, laid in the scene.

  /// The wall's coats' edges, point for point with the outline: the
  /// serosa's inner edge, the muscularis's, the submucosa's and the
  /// mucosa's surface.
  late final List<List<Offset>> coats = <List<Offset>>[
    for (final List<Offset> edge in _coatsMm) _placed(edge),
  ];

  /// The outline as the coats are laid round it, point for point with
  /// them.
  late final List<Offset> serosa = _placed(_outlineMm);

  /// The mucosa's surface, the wall's inner edge, and the line it turns up
  /// to the cut from, point for point.
  List<Offset> get inner => coats[3];
  late final List<Offset> rimInner = <Offset>[
    for (int i = 0; i < _innerMm.length; i++)
      place(_innerMm[i] + _inwardMm[i] * StomachStyle.rim),
  ];

  /// The muscularis's middle, in runs along the wall where it shows: what
  /// its floor is drawn along where it is the cell's home.
  late final List<List<Offset>> muscleMiddle = () {
    final List<List<Offset>> runs = <List<Offset>>[];
    List<Offset> run = <Offset>[];
    final int n = _outlineMm.length;
    // From a place with no wall, the esophagus's cut end, so that no run
    // is cut where the loop closes.
    final int from = _wallMm.indexWhere((double w) => w <= 0);
    for (int k = 0; k <= n; k++) {
      final int i = (from + k) % n;
      if (_wallMm[i] <= 0.5) {
        if (run.length > 1) {
          runs.add(run);
        }
        run = <Offset>[];
        continue;
      }
      run.add(Offset.lerp(coats[0][i], coats[1][i], 0.5)!);
    }
    if (run.length > 1) {
      runs.add(run);
    }
    return runs;
  }();

  /// The rugae's middle lines, and each as the crease cut along it,
  /// tapering in from its ends.
  late final List<List<Offset>> rugae = <List<Offset>>[
    for (final List<Offset> ruga in _rugaeMm) _placed(ruga),
  ];
  late final Path creases = _creases(_rugaeMm);
  late final Path liningCreases = _creases(_liningFoldsMm);

  Path _creases(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      path.addPolygon(
        _placed(
          _tapered(line, StomachStyle.crease / 2, StomachStyle.creaseTaper),
        ),
        true,
      );
    }
    return path;
  }

  /// The esophagus's lining above the Z-line, and the Z-line.
  late final List<Offset> lining = _placed(_liningMm);
  late final List<Offset> zLine = _placed(_zLineMm);

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(StomachStyle.edgeStep), bend: 0.9);

  /// The esophagus and the duodenum, cut short; the arteries along the
  /// curvatures, cut short at their origins.
  late final TubeCourse esophagus = _tube(StomachAnatomy.esophagus);
  late final TubeCourse duodenum = _tube(StomachAnatomy.duodenum);
  late final List<TubeCourse> arteries = <TubeCourse>[
    for (final AnatomyTube t in StomachAnatomy.arteries) _tube(t),
  ];

  /// The arcades' small branches into the wall, each running in under it.
  late final List<TubeCourse> branches = <TubeCourse>[
    for (final AnatomyTube t in _branchesMm) _tube(t),
  ];

  static final List<AnatomyTube> _branchesMm = () {
    final List<AnatomyTube> out = <AnatomyTube>[];
    final math.Random random = math.Random(StomachStyle.seed);
    for (final int index in StomachAnatomy.arcades) {
      final TubeCourse arcade = TubeCourse(
        StomachAnatomy.arteries[index],
        (Offset p) => p,
        1,
        StomachStyle.edgeStep,
        bend: 0.9,
      );
      double next = StomachAnatomy.branchApart / 2;
      for (int i = 0; i < arcade.length; i++) {
        if (arcade.arc[i] < next) {
          continue;
        }
        final Offset c = arcade.centres[i];
        // Leaning a little ahead along the arcade, or behind.
        final Offset way = Offset(arcade.across[i].dy, -arcade.across[i].dx);
        final Offset aim =
            c +
            way * (StomachAnatomy.branchLean * (2 * random.nextDouble() - 1));
        Offset edge = _outlineMm.first;
        for (final Offset q in _outlineMm) {
          if ((q - aim).distanceSquared < (edge - aim).distanceSquared) {
            edge = q;
          }
        }
        final Offset to = edge - c;
        final double reach = to.distance;
        if (reach > StomachAnatomy.branchReach || reach <= 0) {
          continue;
        }
        next =
            arcade.arc[i] +
            StomachAnatomy.branchApart +
            StomachAnatomy.branchJitter * (2 * random.nextDouble() - 1);
        out.add(
          AnatomyTube(
            <Offset>[c, edge + to / reach * StomachAnatomy.branchUnder],
            const <double>[StomachAnatomy.branch, StomachAnatomy.branch],
          ),
        );
      }
    }
    return out;
  }();

  /// What runs on beside the stomach.
  late final List<TubeCourse> beside = <TubeCourse>[
    esophagus,
    duodenum,
    ...arteries,
  ];

  // Where the parts are named.

  late final Offset fundusName = place(StomachAnatomy.fundusName);
  late final Offset bodyName = place(StomachAnatomy.bodyName);
  late final Offset antrumName = place(StomachAnatomy.antrumName);
  late final Offset pylorusName = place(StomachAnatomy.pylorusName);
  late final Offset duodenumName = place(StomachAnatomy.duodenumName);
  late final Offset esophagusName = place(StomachAnatomy.esophagusName);

  /// The point of a ruga nearest [p], and where they are named: low in
  /// the body by the greater curvature, where they run long.
  Offset rugaNear(Offset p) => _nearest(rugae, p);
  late final Offset rugaeName = rugaNear(place(StomachAnatomy.rugaeName));

  /// The point of the muscularis's middle nearest [p].
  Offset wallNear(Offset p) => _nearest(muscleMiddle, p);

  static Offset _nearest(List<List<Offset>> lines, Offset p) {
    Offset best = lines.first.first;
    for (final List<Offset> line in lines) {
      for (final Offset q in line) {
        if ((q - p).distanceSquared < (best - p).distanceSquared) {
          best = q;
        }
      }
    }
    return best;
  }

  /// Where the step from the body meets the stomach's outline and the
  /// body's, beside their tops, the esophagus's cut end: the greater
  /// curvature's outermost point, its lowest, and the pylorus, each picked
  /// out of either outline alike.
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.1, 0.6),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.45, 0.9),
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

  /// The points of the stomach's own outline where the step from the body
  /// meets the body's, for tests: in the order round it from the top.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

/// How far along [line] each of its points lies.
List<double> _along(List<Offset> line) {
  final List<double> out = <double>[0];
  for (int i = 1; i < line.length; i++) {
    out.add(out.last + (line[i] - line[i - 1]).distance);
  }
  return out;
}

/// The point [t] of the way along [line], whose points lie [along] it.
Offset _at(List<Offset> line, List<double> along, double t) {
  final double s = t.clamp(0.0, 1.0) * along.last;
  int j = 1;
  while (j < line.length - 1 && along[j] < s) {
    j++;
  }
  final double span = along[j] - along[j - 1];
  return Offset.lerp(
    line[j - 1],
    line[j],
    span <= 0 ? 0 : (s - along[j - 1]) / span,
  )!;
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
