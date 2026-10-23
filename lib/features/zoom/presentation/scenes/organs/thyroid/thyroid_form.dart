import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'thyroid_anatomy.dart';
import 'thyroid_style.dart';

/// Where in the thyroid the zoom's cell lives, which its drawing lights in
/// the mark, by the Atlas's name for the cell. By the kind of cell, never
/// by gene.
enum ThyroidHome {
  /// The follicles: their cells, and every cell that has no part of the
  /// gland of its own to be drawn at its size (its endothelium, its
  /// fibroblasts, its immune cells), the whole parenchyma the cut shows.
  follicles,

  /// The C cells, the parafollicular cells, among the follicles of the
  /// lobes' middle thirds.
  cCells;

  /// Where a cell the Atlas calls [cell] lives.
  static ThyroidHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('parafollicular') || name.contains('c cell')) {
      return cCells;
    }
    return follicles;
  }

  /// What its name says, at the place it lives.
  String get word => switch (this) {
    follicles => 'follicles',
    cCells => 'C cells',
  };
}

/// The thyroid gland as the zoom's organ scene draws it, seen from the front
/// in place, the lobe the body goes into cut open: every part in the
/// scene's units at its real size, the middle of the body's outline of it at
/// the origin.
///
/// The gland is drawn from general anatomy ([ThyroidAnatomy]), its right
/// lobe the one cut open, turned over where the body goes into its left;
/// and laid on the body's outline of it so that the place it is gone into
/// in the anatomy ([ThyroidAnatomy.site]) lies on the place the body goes
/// in ([site]). The step from the body draws the body's outline in toward
/// the gland's own ([pathAt]). Everything here is geometry: what it is
/// drawn in is `ThyroidArt`'s.
final class ThyroidForm {
  ThyroidForm({
    required List<Offset> diagram,
    required this.site,
    required this.view,
    this.home = ThyroidHome.follicles,
  }) : scale = 1e-3 / view,
       flip = site.dx <= _bounds(diagram).center.dx ? 1 : -1 {
    final List<Offset> knots = _placed(ThyroidAnatomy.outline);
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(ThyroidStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool turned = _area(knots).sign != _area(diagramDense).sign;
    final List<Offset> template = turned ? knots.reversed.toList() : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(ThyroidStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: ThyroidStyle.morphPoints,
      bed: mm(ThyroidStyle.bed),
      marks: _marks,
      start: (List<Offset> p) => _apex(p, -flip),
    );
  }

  /// The gland where the body draws it as [part], in a view [view] metres
  /// across, its cells' [home] in it.
  factory ThyroidForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    ThyroidHome home = ThyroidHome.follicles,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return ThyroidForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the gland, in the scene: low in the middle of
  /// the lobe cut open.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final ThyroidHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Which way across the anatomy is laid: 1 as it is drawn, its right
  /// lobe cut open on the left of the scene, as the body's right is; -1
  /// turned over, its left lobe the one cut open, on the right.
  final double flip;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The gland's outline, its capsule, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) =>
      site +
      Offset(
            flip * (mm.dx - ThyroidAnatomy.site.dx),
            mm.dy - ThyroidAnatomy.site.dy,
          ) *
          scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) {
    final Offset d = (p - site) / scale;
    return ThyroidAnatomy.site + Offset(flip * d.dx, d.dy);
  }

  /// How far the gland's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the gland's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the gland's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every gland.

  /// The outline followed closely, in millimetres, its knots at every
  /// [ThyroidStyle.outlineSpan]th point.
  static final List<Offset> _outlineMm = Contour(ThyroidAnatomy.outline)
      .sampled(ThyroidStyle.outlineSpan)
      .points;

  /// The cut lobe's face, in millimetres: its run of the outline, and the
  /// line it ends at by the isthmus, back up to where the run began.
  static final List<Offset> _faceMm = <Offset>[
    ..._outlineMm.sublist(
      0,
      (ThyroidAnatomy.cutRun.length - 1) * ThyroidStyle.outlineSpan + 1,
    ),
    ..._open(ThyroidAnatomy.lobeEnd)
        .skip(1)
        .take(_open(ThyroidAnatomy.lobeEnd).length - 2),
  ];

  /// What the cut leaves whole, in millimetres: the isthmus and the other
  /// lobe, from where the cut lobe's face ends at the isthmus.
  static final List<Offset> _wholeMm = <Offset>[
    ..._outlineMm.sublist(
      (ThyroidAnatomy.cutRun.length - 1) * ThyroidStyle.outlineSpan,
    ),
    ..._open(ThyroidAnatomy.lobeEnd).reversed
        .take(_open(ThyroidAnatomy.lobeEnd).length - 1),
  ];

  /// The cut face's edge under the capsule, and the line it turns away to,
  /// point for point, in millimetres.
  static final List<Offset> _faceRunMm = _outlineMm.sublist(
    0,
    (ThyroidAnatomy.cutRun.length - 1) * ThyroidStyle.outlineSpan + 1,
  );

  /// The lobules the cut shows, each a cell of the lattice its middles lie
  /// on, laid over the face's box and cut by it when drawn, in
  /// millimetres.
  static final List<List<Offset>> _lobulesMm = () {
    final math.Random random = math.Random(ThyroidStyle.seed);
    final Rect box = _bounds(_faceMm).inflate(ThyroidAnatomy.lobule);
    const double a = ThyroidAnatomy.lobule;
    final double rowStep = a * math.sqrt(3) / 2;
    final List<Offset> middles = <Offset>[];
    int row = 0;
    for (double y = box.top; y <= box.bottom; y += rowStep, row++) {
      for (
        double x = box.left + (row.isOdd ? a / 2 : 0);
        x <= box.right;
        x += a
      ) {
        middles.add(
          Offset(
            x + (random.nextDouble() * 2 - 1) * a * ThyroidAnatomy.lobuleStray,
            y + (random.nextDouble() * 2 - 1) * a * ThyroidAnatomy.lobuleStray,
          ),
        );
      }
    }
    return <List<Offset>>[
      for (int i = 0; i < middles.length; i++)
        if (_toLine(_faceMm, middles[i], closed: true) < 2 * a ||
            _inside(_faceMm, middles[i]))
          _cell(middles, i, 2.4 * a),
    ];
  }();

  /// The C cells, in millimetres: a dust on a lattice over the cut lobe's
  /// middle thirds, clear of its edge.
  static final List<Offset> _cCellsMm = () {
    final math.Random random = math.Random(ThyroidStyle.seed + 1);
    final double apex = _bounds(_faceMm).top;
    final double from = apex + ThyroidAnatomy.lobeLength * ThyroidAnatomy.cFrom;
    final double to = apex + ThyroidAnatomy.lobeLength * ThyroidAnatomy.cTo;
    final Rect box = _bounds(_faceMm);
    const double a = ThyroidStyle.cApart;
    final List<Offset> out = <Offset>[];
    for (double y = from; y <= to; y += a) {
      for (double x = box.left; x <= box.right; x += a) {
        final Offset p = Offset(
          x + (random.nextDouble() - 0.5) * a,
          y + (random.nextDouble() - 0.5) * a,
        );
        if (_inside(_faceMm, p) &&
            _toLine(_faceMm, p, closed: true) > ThyroidStyle.cClear) {
          out.add(p);
        }
      }
    }
    return out;
  }();

  // The parts, laid in the scene.

  /// The cut lobe's face, closed; what the cut leaves whole, closed.
  late final List<Offset> face = _placed(_faceMm);
  late final List<Offset> whole = _placed(_wholeMm);

  /// The face's edge under the capsule, and the line it turns away to,
  /// point for point.
  late final List<Offset> faceRun = _placed(_faceRunMm);
  late final List<Offset> rimInner = () {
    final List<Offset> run = _faceRunMm;
    final List<Offset> normals = _normals(run);
    final int middle = run.length ~/ 2;
    final double inward = _inside(_faceMm, run[middle] + normals[middle])
        ? 1
        : -1;
    return _placed(<Offset>[
      for (int i = 0; i < run.length; i++)
        run[i] + normals[i] * (inward * ThyroidStyle.rim),
    ]);
  }();

  /// Where the face meets the isthmus the cut leaves whole.
  late final List<Offset> lobeEnd = _placed(_open(ThyroidAnatomy.lobeEnd));

  /// The lobules the cut shows, each a cell; the C cells.
  late final List<List<Offset>> lobules = <List<Offset>>[
    for (final List<Offset> cell in _lobulesMm) _placed(cell),
  ];
  late final List<Offset> cCells = _placed(_cCellsMm);

  /// The thyroid cartilage, the cricoid's arch, the cricothyroid membrane
  /// and the muscles either side of it, each closed.
  late final List<Offset> cartilage = _placed(
    _mirrored(ThyroidAnatomy.cartilageHalf),
  );
  late final List<Offset> cricoid = _placed(
    _mirrored(ThyroidAnatomy.cricoidHalf),
  );
  late final List<Offset> membrane = _placed(ThyroidAnatomy.membrane);
  late final List<List<Offset>> cricothyroids = <List<Offset>>[
    _placed(ThyroidAnatomy.cricothyroid),
    _placed(<Offset>[
      for (final Offset p in ThyroidAnatomy.cricothyroid.reversed)
        Offset(-p.dx, p.dy),
    ]),
  ];

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(ThyroidStyle.edgeStep), bend: 0.9);

  /// [tube] turned over to the body's other side, and whether its end is
  /// cut there.
  static AnatomyTube _other(AnatomyTube tube, {bool? cutEnd}) => AnatomyTube(
    <Offset>[for (final Offset p in tube.points) Offset(-p.dx, p.dy)],
    tube.radii,
    fadeIn: tube.fadeIn,
    fadeOut: tube.fadeOut,
    cutStart: tube.cutStart,
    cutEnd: cutEnd ?? tube.cutEnd,
  );

  /// The trachea, and each of its rings as the rows of it the ring covers.
  late final TubeCourse trachea = _tube(ThyroidAnatomy.trachea);
  late final List<(int, int)> rings = <(int, int)>[
    for (int k = 0; k < ThyroidAnatomy.rings; k++)
      () {
        final double top =
            ThyroidAnatomy.ringTop + k * ThyroidAnatomy.ringPitch;
        return (
          _rowAt(trachea, place(Offset(0, top)).dy),
          _rowAt(trachea, place(Offset(0, top + ThyroidAnatomy.ringDepth)).dy),
        );
      }(),
  ];

  /// The arteries: each common carotid, its internal and external carotids,
  /// and its superior thyroid artery, the cut lobe's side's first; and the
  /// branch that runs down the whole lobe to meet the other along the
  /// isthmus.
  late final List<TubeCourse> carotids = <TubeCourse>[
    _tube(ThyroidAnatomy.carotid),
    _tube(_other(ThyroidAnatomy.carotid)),
  ];
  late final List<TubeCourse> internalCarotids = <TubeCourse>[
    _tube(ThyroidAnatomy.internalCarotid),
    _tube(_other(ThyroidAnatomy.internalCarotid)),
  ];
  late final List<TubeCourse> externalCarotids = <TubeCourse>[
    _tube(ThyroidAnatomy.externalCarotid),
    _tube(_other(ThyroidAnatomy.externalCarotid)),
  ];
  late final List<TubeCourse> superiorArteries = <TubeCourse>[
    _tube(ThyroidAnatomy.superiorArtery),
    _tube(_other(ThyroidAnatomy.superiorArtery, cutEnd: false)),
  ];
  late final TubeCourse anteriorBranch = _tube(ThyroidAnatomy.anteriorBranch);

  /// The veins: each internal jugular, middle thyroid vein and inferior
  /// thyroid vein, the cut lobe's side's first.
  late final List<TubeCourse> jugulars = <TubeCourse>[
    _tube(ThyroidAnatomy.jugular),
    _tube(_other(ThyroidAnatomy.jugular)),
  ];

  /// Each jugular run the other way, for the end it is cut at above.
  late final List<TubeCourse> jugularTops = <TubeCourse>[
    for (final AnatomyTube t in <AnatomyTube>[
      ThyroidAnatomy.jugular,
      _other(ThyroidAnatomy.jugular),
    ])
      _tube(
        AnatomyTube(
          t.points.reversed.toList(),
          t.radii.reversed.toList(),
          cutEnd: true,
        ),
      ),
  ];
  late final List<TubeCourse> middleVeins = <TubeCourse>[
    _tube(ThyroidAnatomy.middleVein),
    _tube(_other(ThyroidAnatomy.middleVein)),
  ];
  late final List<TubeCourse> inferiorVeins = <TubeCourse>[
    _tube(ThyroidAnatomy.inferiorVein),
    _tube(_other(ThyroidAnatomy.inferiorVein)),
  ];

  /// Every tube drawn beside the gland, for its names to keep clear of.
  late final List<TubeCourse> beside = <TubeCourse>[
    trachea,
    ...carotids,
    ...internalCarotids,
    ...externalCarotids,
    ...superiorArteries,
    ...jugulars,
    ...middleVeins,
    ...inferiorVeins,
  ];

  // Where the parts are named.

  late final Offset isthmusName = place(ThyroidAnatomy.isthmusName);
  late final Offset larynxName = place(ThyroidAnatomy.larynxName);
  late final Offset tracheaName = place(ThyroidAnatomy.tracheaName);
  late final Offset carotidName = place(ThyroidAnatomy.carotidName);
  late final Offset jugularName = place(ThyroidAnatomy.jugularName);

  /// Where the zoom's cell's home is named: at the site, or at the C cell
  /// nearest it.
  late final Offset homeName = home == ThyroidHome.follicles
      ? site
      : cCells.reduce(
          (Offset a, Offset b) =>
              (a - site).distanceSquared <= (b - site).distanceSquared ? a : b,
        );

  /// Where the step from the body meets the gland's outline and the
  /// body's: first at the apex of the lobe cut open (the morph's start),
  /// then at the other lobe's apex, each lobe's outermost point and its
  /// base, the isthmus's foot, and the notch between the lobes, each
  /// picked out of either outline alike.
  late final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => _apex(p, flip),
        (List<Offset> p) => OutlineMarks.outermost(p, -flip, 0.2, 0.9),
        (List<Offset> p) => _base(p, -flip),
        _isthmusFoot,
        (List<Offset> p) => _base(p, flip),
        (List<Offset> p) => OutlineMarks.outermost(p, flip, 0.2, 0.9),
        _notch,
      ];

  /// The topmost of [points] on the [side] half of their box, -1 the left
  /// and 1 the right: a lobe's apex.
  static int _apex(List<Offset> points, double side) {
    final double middle = _bounds(points).center.dx;
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      if ((points[i].dx - middle) * side <= 0) {
        continue;
      }
      if (best < 0 || points[i].dy < points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The lowest of [points] on the [side] half of their box: a lobe's
  /// base.
  static int _base(List<Offset> points, double side) {
    final Rect box = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      if ((points[i].dx - box.center.dx) * side < box.width * 0.2) {
        continue;
      }
      if (best < 0 || points[i].dy > points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// Of [points] near the middle of their box, the highest, the notch
  /// between the lobes, and the lowest, the isthmus's foot.
  static int _notch(List<Offset> points) => _middling(points, -1);
  static int _isthmusFoot(List<Offset> points) => _middling(points, 1);
  static int _middling(List<Offset> points, double way) {
    final Rect box = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      if ((points[i].dx - box.center.dx).abs() > box.width * 0.08) {
        continue;
      }
      if (best < 0 || (points[i].dy - points[best].dy) * way > 0) {
        best = i;
      }
    }
    return best;
  }

  /// The points of the gland's own outline where the step from the body
  /// meets the body's, for tests: the morph's start first, then the rest in
  /// the order they are given.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_apex(points, -flip)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];

  /// The C cells and the lobules in millimetres, and how far a point lies
  /// from the cut face's edge there, for tests.
  static List<Offset> get faceMm => _faceMm;
  static List<Offset> get cCellsMm => _cCellsMm;
}

/// The row of [tube] nearest the height [y].
int _rowAt(TubeCourse tube, double y) {
  int best = 0;
  for (int i = 1; i < tube.length; i++) {
    if ((tube.centres[i].dy - y).abs() < (tube.centres[best].dy - y).abs()) {
      best = i;
    }
  }
  return best;
}

/// [half], the body's right half of a shape symmetric about the midline,
/// from the midline at its top to the midline at its foot, made whole.
List<Offset> _mirrored(List<Offset> half) => <Offset>[
  ...half,
  for (final Offset p in half.reversed.skip(1).take(half.length - 2))
    Offset(-p.dx, p.dy),
];

/// An open line through [knots] as a Catmull-Rom curve, closely followed.
List<Offset> _open(List<Offset> knots) {
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
    for (int k = 0; k < ThyroidStyle.outlineSpan; k++) {
      final double t = k / ThyroidStyle.outlineSpan;
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

/// The cell of [middles] round the [i]th: the square [reach] round it cut
/// by the line halfway to each other middle near it.
List<Offset> _cell(List<Offset> middles, int i, double reach) {
  final Offset c = middles[i];
  List<Offset> poly = <Offset>[
    c + Offset(-reach, -reach),
    c + Offset(reach, -reach),
    c + Offset(reach, reach),
    c + Offset(-reach, reach),
  ];
  for (int j = 0; j < middles.length; j++) {
    final Offset d = middles[j] - c;
    if (j == i || d.distance > 2 * reach) {
      continue;
    }
    // Keep the side of the halfway line that holds c: p·d <= |d|²/2.
    final double limit = d.distanceSquared / 2;
    double side(Offset p) => (p - c).dx * d.dx + (p - c).dy * d.dy - limit;
    final List<Offset> out = <Offset>[];
    for (int k = 0; k < poly.length; k++) {
      final Offset a = poly[k];
      final Offset b = poly[(k + 1) % poly.length];
      final double sa = side(a);
      final double sb = side(b);
      if (sa <= 0) {
        out.add(a);
      }
      if ((sa < 0) != (sb < 0)) {
        out.add(Offset.lerp(a, b, sa / (sa - sb))!);
      }
    }
    poly = out;
    if (poly.length < 3) {
      return poly;
    }
  }
  return poly;
}

/// The left hand of the way along [line] at each point, a unit.
List<Offset> _normals(List<Offset> line) {
  final int n = line.length;
  return <Offset>[
    for (int i = 0; i < n; i++)
      () {
        final Offset t =
            line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)];
        final double length = t.distance;
        return length <= 0 ? Offset.zero : Offset(t.dy, -t.dx) / length;
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
