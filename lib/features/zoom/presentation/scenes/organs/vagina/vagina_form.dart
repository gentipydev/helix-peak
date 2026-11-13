import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import 'vagina_anatomy.dart';
import 'vagina_style.dart';

/// The vagina as the zoom's organ scene draws it, opened down its front
/// wall and pinned flat: every part in the scene's units at its real size,
/// the middle of the body's outline of it at the origin.
///
/// The vagina is drawn from general anatomy ([VaginaAnatomy]) and laid on
/// the body's outline of it so that the place it is gone into in the
/// anatomy ([VaginaAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline, the closed
/// tube it draws as a cup, in toward the pinned specimen's ([pathAt]). Its
/// front wall is where the zoom goes in, whatever the protein: no cell the
/// Atlas names has the vagina as its home, so the zoom draws the tissue's
/// own, and the tissue is its squamous epithelium, taken from the front
/// wall. Everything here is geometry: what it is drawn in is `VaginaArt`'s.
final class VaginaForm {
  VaginaForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
  }) : scale = length / VaginaAnatomy.length {
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(VaginaStyle.outlineSpan)
        .points;
    _diagramBox = _bounds(diagramDense);
    final List<Offset> placed = _placed(_outlineMm);
    outlinePoints = _area(placed).sign != _area(diagramDense).sign
        ? placed.reversed.toList()
        : placed;
    outline = Path()..addPolygon(outlinePoints, true);
    box = _bounds(outlinePoints);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: VaginaStyle.morphPoints,
      bed: mm(VaginaStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The vagina where the body draws it as [part], in a view [view] metres
  /// across.
  factory VaginaForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return VaginaForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
    );
  }

  /// Where the body goes into the vagina, in the scene: its front wall's
  /// half on the body's right, in its middle third.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The pinned specimen's outline, the points it is followed by, and its
  /// box.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - VaginaAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => VaginaAnatomy.site + (p - site) / scale;

  /// How far the vagina lies from the body's outline it draws in from, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the vagina's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the vagina's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every vagina.

  /// The outline's own points, its right half and then its left, mirrored,
  /// from the middle of the posterior fornix round by the fourchette,
  /// followed closely.
  static final List<Offset> _outlineMm = Contour(<Offset>[
    ...VaginaAnatomy.half,
    for (int i = VaginaAnatomy.half.length - 2; i >= 1; i--)
      Offset(-VaginaAnatomy.half[i].dx, VaginaAnatomy.half[i].dy),
  ]).sampled(VaginaStyle.outlineSpan).points;

  /// The outline in millimetres. For tests.
  static List<Offset> get outlineMm => _outlineMm;

  /// The lateral sulcus on the body's left, followed closely, from the
  /// lateral fornix down to the introitus.
  static final List<Offset> _sulcusMm = _openSampled(
    VaginaAnatomy.sulcus,
    VaginaStyle.outlineSpan,
  );

  /// How far out from the middle the sulci lie at [y].
  static double sulcusAt(double y) {
    final List<Offset> s = _sulcusMm;
    if (y <= s.first.dy) {
      return s.first.dx;
    }
    for (int i = 1; i < s.length; i++) {
      if (s[i].dy >= y) {
        final double t = (y - s[i - 1].dy) / (s[i].dy - s[i - 1].dy);
        return s[i - 1].dx + (s[i].dx - s[i - 1].dx) * t;
      }
    }
    return s.last.dx;
  }

  /// How far out from the middle the outline lies at [y], on the body's
  /// left.
  static double edgeAt(double y) {
    double most = 0;
    final int n = _outlineMm.length;
    for (int i = 0; i < n; i++) {
      final Offset a = _outlineMm[i];
      final Offset b = _outlineMm[(i + 1) % n];
      if ((a.dy <= y) != (b.dy <= y)) {
        most = math.max(
          most,
          a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy),
        );
      }
    }
    return most;
  }

  /// The vaginal part of the cervix, round its middle, and its os.
  static final List<Offset> _portioMm = <Offset>[
    for (int i = 0; i < 96; i++)
      () {
        final double a = 2 * math.pi * i / 96;
        // A little flatter below, where it rests on the back wall.
        final double down = math.sin(a) > 0 ? 0.94 : 1;
        return VaginaAnatomy.portio +
            Offset(
              VaginaAnatomy.portioWide * math.cos(a),
              VaginaAnatomy.portioHigh * down * math.sin(a),
            );
      }(),
  ];
  static final List<Offset> _osMm = <Offset>[
    for (int i = 0; i < 32; i++)
      () {
        final double a = 2 * math.pi * i / 32;
        return const Offset(0, 0) +
            Offset(
              VaginaAnatomy.osWide * math.cos(a),
              VaginaAnatomy.osHigh * math.sin(a),
            );
      }(),
  ];

  /// The vaginal part in millimetres. For tests.
  static List<Offset> get portioMm => _portioMm;

  /// Whether [mm] lies on the vaginal part of the cervix.
  static bool inPortio(Offset mm) => _inside(_portioMm, mm);

  /// Whether [mm] lies on the front wall, where the zoom goes in: inside
  /// the outline, out beyond a sulcus, and off the cervix.
  static bool inHome(Offset mm) =>
      _inside(_outlineMm, mm) && mm.dx.abs() > sulcusAt(mm.dy) && !inPortio(mm);

  /// Whether [mm] lies on the back wall, between the sulci, off the
  /// cervix.
  static bool inBack(Offset mm) =>
      _inside(_outlineMm, mm) &&
      mm.dx.abs() <= sulcusAt(mm.dy) &&
      !inPortio(mm);

  /// The front wall's halves, each the outline's part out beyond its
  /// sulcus: the body's right's and left's.
  static final List<List<Offset>> _frontMm = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      () {
        final List<Offset> sulcus = <Offset>[
          for (final Offset p in _sulcusMm) Offset(side * p.dx, p.dy),
        ];
        // The outline beyond the sulcus, from the introitus up its cut edge
        // to the lateral fornix: the points of the outline on this side
        // whose height the sulcus reaches and which lie out beyond it.
        final List<Offset> edge = <Offset>[
          for (final Offset p in _outlineMm)
            if (p.dx * side > 0 &&
                p.dy >= sulcus.first.dy &&
                p.dy <= sulcus.last.dy &&
                p.dx.abs() >= sulcusAt(p.dy))
              p,
        ]..sort((Offset a, Offset b) => b.dy.compareTo(a.dy));
        return <Offset>[...sulcus, ...edge];
      }(),
  ];

  /// The front wall's halves in millimetres. For tests.
  static List<List<Offset>> get frontMm => _frontMm;

  /// The rugae: on the back wall, from the posterior column out to near
  /// either sulcus, bowed up at their middles; on the front wall's halves,
  /// from near the cut edge, where the anterior column runs, in to near
  /// the sulcus.
  static final List<List<Offset>> _rugaeMm = () {
    final math.Random random = math.Random(VaginaStyle.seed);
    final List<List<Offset>> out = <List<Offset>>[];
    List<Offset> ruga(double from, double to, double y, double side) {
      final int steps = math.max(
        3,
        ((to - from) / VaginaStyle.edgeStep).ceil(),
      );
      final double phase = random.nextDouble() * 2 * math.pi;
      final double length = to - from;
      return <Offset>[
        for (int i = 0; i <= steps; i++)
          () {
            final double x = from + length * i / steps;
            final double t = (2 * (x - from) / length - 1);
            return Offset(
              side * x,
              y -
                  VaginaAnatomy.rugaBow * (1 - t * t) +
                  0.2 * math.sin(x / 2.1 + phase),
            );
          }(),
      ];
    }

    for (
      double y = VaginaAnatomy.firstBack;
      y < VaginaAnatomy.posteriorBottom;
      y += VaginaAnatomy.rugaApart
    ) {
      for (final double side in <double>[-1, 1]) {
        const double from = VaginaAnatomy.column / 2 + 0.2;
        final double to = sulcusAt(y) - VaginaAnatomy.rugaShort;
        final List<Offset> line = <Offset>[
          for (final Offset p in ruga(from, to, y, side))
            if (_inside(_outlineMm, p) && _toLine(_outlineMm, p) > 0.8) p,
        ];
        if (line.length > 4) {
          out.add(line);
        }
      }
    }
    for (
      double y = VaginaAnatomy.firstFront;
      y < VaginaAnatomy.anteriorBottom + 2;
      y += VaginaAnatomy.rugaApart * 1.05
    ) {
      for (final double side in <double>[-1, 1]) {
        final double from = sulcusAt(y) + VaginaAnatomy.rugaShort;
        final double to = edgeAt(y) - VaginaAnatomy.anteriorIn - 0.4;
        if (to - from < 2) {
          continue;
        }
        final List<Offset> line = <Offset>[
          for (final Offset p in ruga(from, to, y, side))
            if (_inside(_outlineMm, p) && _toLine(_outlineMm, p) > 0.8) p,
        ];
        if (line.length > 4) {
          out.add(line);
        }
      }
    }
    return out;
  }();

  /// The rugae in millimetres. For tests.
  static List<List<Offset>> get rugaeMm => _rugaeMm;

  /// The posterior column down the back wall's middle, and the anterior
  /// column's halves along the front wall's cut edges, each wandering a
  /// little; the urethral carina, the anterior column's lower part.
  static final List<Offset> _posteriorMm = _wandering(
    const Offset(0, VaginaAnatomy.posteriorTop),
    const Offset(0, VaginaAnatomy.posteriorBottom),
    math.Random(VaginaStyle.seed + 1),
    0.15,
  );
  static final List<List<Offset>> _anteriorMm = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      <Offset>[
        for (
          double y = VaginaAnatomy.anteriorTop;
          y <= VaginaAnatomy.anteriorBottom;
          y += VaginaStyle.edgeStep
        )
          Offset(side * (edgeAt(y) - VaginaAnatomy.anteriorIn), y),
      ],
  ];
  static final List<List<Offset>> _carinaMm = <List<Offset>>[
    for (final List<Offset> column in _anteriorMm)
      <Offset>[
        for (final Offset p in column)
          if (p.dy >= VaginaAnatomy.carinaTop) p,
      ],
  ];

  /// The hymen's caruncles along the introitus: each one's middle and
  /// radius, pushed out past the edge so that only its free part shows.
  static final List<(Offset, double)> _caruncleMm = () {
    final math.Random random = math.Random(VaginaStyle.seed + 2);
    // The introitus: the outline's bottom edge, between the cut edges'
    // lowest corners.
    final List<Offset> edge = <Offset>[
      for (final Offset p in _outlineMm)
        if (p.dy > 74.5) p,
    ]..sort((Offset a, Offset b) => a.dx.compareTo(b.dx));
    final List<double> along = _along(edge);
    final List<(Offset, double)> out = <(Offset, double)>[];
    const int n = VaginaAnatomy.caruncles;
    for (int k = 0; k < n; k++) {
      final double at =
          along.last * (k + 0.5) / n +
          (random.nextDouble() - 0.5) * along.last / n * 0.4;
      int i = 1;
      while (i < along.length - 1 && along[i] < at) {
        i++;
      }
      final double t = (at - along[i - 1]) / (along[i] - along[i - 1]);
      final Offset p = Offset.lerp(edge[i - 1], edge[i], t)!;
      final Offset way = _unit(edge[i] - edge[i - 1]);
      // Out of the outline, below its edge.
      Offset out0 = Offset(-way.dy, way.dx);
      if (out0.dy < 0) {
        out0 = -out0;
      }
      final double r =
          VaginaAnatomy.caruncleLeast +
          (VaginaAnatomy.caruncleMost - VaginaAnatomy.caruncleLeast) *
              random.nextDouble();
      out.add((p + out0 * (r * 0.25), r));
    }
    return out;
  }();

  /// The caruncles in millimetres. For tests.
  static List<(Offset, double)> get caruncleMm => _caruncleMm;

  // The parts, laid in the scene.

  /// The front wall's halves, the sulci, the vaginal part and its os.
  late final List<List<Offset>> front = <List<Offset>>[
    for (final List<Offset> half in _frontMm) _placed(half),
  ];
  late final List<List<Offset>> sulci = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      _placed(<Offset>[
        for (final Offset p in _sulcusMm) Offset(side * p.dx, p.dy),
      ]),
  ];
  late final List<Offset> portio = _placed(_portioMm);
  late final List<Offset> os = _placed(_osMm);

  /// The rugae as the creases cut along them, tapering in from their ends.
  late final Path rugaCreases = _creases(
    _rugaeMm,
    VaginaStyle.crease,
    VaginaStyle.creaseTaper,
  );

  /// The columns and the carina, each its line and the crease cut along it.
  late final List<List<Offset>> columns = <List<Offset>>[
    _placed(_posteriorMm),
    for (final List<Offset> c in _anteriorMm) _placed(c),
  ];
  late final Path columnCreases = _creases(
    <List<Offset>>[_posteriorMm, ..._anteriorMm],
    VaginaStyle.columnCrease,
    3,
  );
  late final List<List<Offset>> carinae = <List<Offset>>[
    for (final List<Offset> c in _carinaMm) _placed(c),
  ];

  /// The caruncles: each one's middle and radius.
  late final List<(Offset, double)> caruncles = <(Offset, double)>[
    for (final (Offset at, double r) in _caruncleMm) (place(at), mm(r)),
  ];

  Path _creases(List<List<Offset>> lines, double width, double taper) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      path.addPolygon(_placed(_tapered(line, width / 2, taper)), true);
    }
    return path;
  }

  // Where the parts are named.

  /// The front wall, at the site; the vaginal part; the posterior fornix;
  /// the rugae; the hymen's caruncles.
  late final Offset homeName = site;
  late final Offset cervixName = place(VaginaAnatomy.cervixName);
  late final Offset fornixName = place(VaginaAnatomy.fornixName);
  late final Offset rugaeName = place(VaginaAnatomy.rugaeName);
  late final Offset hymenName = place(VaginaAnatomy.hymenName);

  /// The points its names are set round: its outline and its caruncles.
  late final List<Offset> namedPoints = <Offset>[
    for (int i = 0; i < outlinePoints.length; i += 3) outlinePoints[i],
    for (final (Offset at, double r) in caruncles) at + Offset(0, r),
  ];

  // The step from the body.

  /// Where the step from the body meets the vagina's outline and the
  /// body's: the middle of the top, in place of the topmost point; each
  /// side's outermost point in its upper part; and the lowest.
  static int _topMiddle(List<Offset> points) {
    final Rect box = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      final Offset p = points[i];
      if (p.dy > box.top + box.height * 0.2) {
        continue;
      }
      if (best < 0 ||
          (p.dx - box.center.dx).abs() <
              (points[best].dx - box.center.dx).abs()) {
        best = i;
      }
    }
    return best;
  }

  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0, 0.4),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0, 0.4),
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

  /// The points of an outline where the step from the body meets the
  /// vagina's and the body's, for tests: the top's middle, then the rest
  /// in the order round it from there.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topMiddle(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

/// A smooth open curve through [knots], [perSpan] points from each to the
/// next, its ends at the first and the last.
List<Offset> _openSampled(List<Offset> knots, int perSpan) {
  final int n = knots.length;
  Offset knot(int i) => knots[i.clamp(0, n - 1)];
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < n - 1; i++) {
    final Offset p0 = knot(i - 1);
    final Offset p1 = knot(i);
    final Offset p2 = knot(i + 1);
    final Offset p3 = knot(i + 2);
    final Offset c1 = p1 + (p2 - p0) / 6;
    final Offset c2 = p2 - (p3 - p1) / 6;
    for (int k = 0; k < perSpan; k++) {
      final double t = k / perSpan;
      final double u = 1 - t;
      out.add(
        p1 * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            p2 * (t * t * t),
      );
    }
  }
  return out..add(knots.last);
}

/// A line from [from] to [to] in points [VaginaStyle.edgeStep] apart,
/// wandering to either side by up to [wander], laid by [random].
List<Offset> _wandering(
  Offset from,
  Offset to,
  math.Random random,
  double wander,
) {
  final Offset way = to - from;
  final double length = way.distance;
  final Offset along = way / length;
  final Offset across = Offset(-along.dy, along.dx);
  final double phase = random.nextDouble() * 2 * math.pi;
  final double wave = 6 + 4 * random.nextDouble();
  final int steps = math.max(2, (length / VaginaStyle.edgeStep).ceil());
  return <Offset>[
    for (int i = 0; i <= steps; i++)
      () {
        final double s = length * i / steps;
        final double fade = math.sin(math.pi * i / steps);
        return from +
            along * s +
            across * (wander * fade * math.sin(s / wave * 2 * math.pi + phase));
      }(),
  ];
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

/// How far [p] lies from the closed outline [polygon].
double _toLine(List<Offset> polygon, Offset p) {
  double best = double.infinity;
  for (int i = 0; i < polygon.length; i++) {
    best = math.min(
      best,
      _toSegment(p, polygon[i], polygon[(i + 1) % polygon.length]),
    );
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
