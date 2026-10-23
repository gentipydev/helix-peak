import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'kidney_anatomy.dart';
import 'kidney_style.dart';

/// Where in the kidney the zoom's cell lives, which its drawing lights in
/// the mark, by the Atlas's name for the cell: every one of the kidney's
/// cells is drawn as one shape, an epithelial cell, so its name is what
/// tells them apart. By the kind of cell, never by gene.
enum KidneyHome {
  /// The cortex: the cells of its convoluted tubules, proximal and distal,
  /// and of its connecting tubules, and every cell that has no part of the
  /// kidney of its own (its endothelium, its fibroblasts, its immune cells).
  cortex,

  /// The loops of Henle: their thick ascending limbs, up through the outer
  /// medulla and on in the medullary rays.
  loops,

  /// The collecting ducts: down the medullary rays and through the
  /// pyramids to the papillae.
  ducts,

  /// The papillae, where the ducts open into the calyces.
  papillae,

  /// The glomeruli: their podocytes and mesangial cells.
  glomeruli;

  /// Where a cell the Atlas calls [cell] lives.
  static KidneyHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    bool has(String word) => name.contains(word);
    if (has('henle')) {
      return loops;
    }
    if (has('collecting duct') || has('intercalated') || has('principal')) {
      return ducts;
    }
    if (has('papillary')) {
      return papillae;
    }
    if (has('podocyte') || has('glomerul') || has('mesangial')) {
      return glomeruli;
    }
    return cortex;
  }
}

/// A medullary pyramid as the cut shows it, in the scene: its outline; its
/// two flanks from its base's ends to its papilla, point for point, which
/// its cut face is laid between; its outer medulla, the band along its
/// base, and its papilla; its striations; and the medullary rays that run
/// up from its base into the cortex.
final class KidneyPyramid {
  KidneyPyramid._({
    required this.outline,
    required this.left,
    required this.right,
    required this.outer,
    required this.papilla,
    required this.tip,
    required this.striations,
    required this.rays,
  });

  final List<Offset> outline;
  final List<Offset> left;
  final List<Offset> right;
  final List<Offset> outer;
  final List<Offset> papilla;
  final Offset tip;
  final List<List<Offset>> striations;
  final List<(Offset, Offset)> rays;

  /// Its middle: the mean of its outline.
  late final Offset centre = _mean(outline);
}

/// The kidney as the zoom's organ scene draws it, cut open from front to
/// back: every part in the scene's units at its real size, the middle of
/// the body's outline of it at the origin.
///
/// The kidney is drawn from general anatomy ([KidneyAnatomy]) as a right
/// kidney, mirrored where the body follows its left, so that its hilum
/// faces the figure's midline, and laid on the body's outline of it, its
/// box's middle on that outline's, moved across so that the middle of its
/// cortex at the height the body goes in runs through the place it goes in
/// ([site]), which is the body's. The step from the body draws the body's
/// outline in toward the kidney's own ([pathAt]). Everything here is
/// geometry: what it is drawn in is `KidneyArt`'s.
final class KidneyForm {
  KidneyForm({
    required List<Offset> diagram,
    required this.site,
    required double midline,
    required double length,
    required this.view,
    this.home = KidneyHome.cortex,
  }) : side = midline >= 0 ? 1 : -1,
       scale = length / KidneyAnatomy.length {
    _shift = _cortexMiddleAt(site.dy / scale) - site.dx / (side * scale);
    final List<Offset> knots = <Offset>[
      for (final Offset p in KidneyAnatomy.outline) place(p),
    ];
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(KidneyStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(KidneyStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: KidneyStyle.morphPoints,
      bed: mm(KidneyStyle.bed),
      marks: _marks,
    );
  }

  /// The kidney where the body draws it as [part], in a view [view] metres
  /// across, its cells' [home] in it.
  factory KidneyForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    KidneyHome home = KidneyHome.cortex,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return KidneyForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      midline: placed(Offset(0, part.site.dy)).dx,
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the kidney, in the scene: in the middle of
  /// its cortex at its lower pole, on its lateral side.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it: the rays are laid so that one runs
  /// through the site where they are its home, and so that it lies between
  /// two where they are not.
  final KidneyHome home;

  /// Which way across the scene the hilum faces: 1 to the right, the body's
  /// right kidney, and -1 to the left, its left one.
  final double side;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// How far across the kidney is moved, in its own millimetres, so that
  /// the middle of its cortex runs through the site.
  late final double _shift;

  late final OutlineMorph _morph;

  /// The kidney's outline, the capsule closed across the hilum, and the
  /// points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) =>
      Offset(side * (mm.dx - _shift) * scale, mm.dy * scale);

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => Offset(p.dx / (side * scale) + _shift, p.dy / scale);

  /// How far the kidney is moved across to lay its cortex through the
  /// site, in millimetres: what laying it so costs.
  double get anchorShift => _shift;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the kidney's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the kidney's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every kidney.

  /// The outline followed closely, in millimetres, the way its knots run.
  static final List<Offset> _outlineMm = const Contour(KidneyAnatomy.outline)
      .sampled(KidneyStyle.outlineSpan)
      .points;

  /// The parenchyma's run of the outline, in millimetres: from the upper
  /// lip round over the upper pole, down the lateral border and round the
  /// lower pole to the lower lip.
  static final List<Offset> _runMm = () {
    final int n = _outlineMm.length;
    const int from = KidneyAnatomy.upperLip * KidneyStyle.outlineSpan;
    const int to = KidneyAnatomy.lowerLip * KidneyStyle.outlineSpan;
    final List<Offset> out = <Offset>[];
    for (int i = from; ; i = (i - 1 + n) % n) {
      out.add(_outlineMm[i]);
      if (i == to) {
        return out;
      }
    }
  }();

  /// The way into the kidney from each point of the run, a unit.
  static final List<Offset> _runIn = () {
    final List<Offset> normals = _normals(_runMm);
    final int middle = _runMm.length ~/ 2;
    final double inward = _inside(_outlineMm, _runMm[middle] + normals[middle])
        ? 1
        : -1;
    return <Offset>[for (final Offset n in normals) n * inward];
  }();
  static final Float64List _runAlong = _alongOf(_runMm);

  /// The corticomedullary junction, point for point with the run: the
  /// run drawn in by the cortex's thickness.
  static final List<Offset> _junctionMm = <Offset>[
    for (int i = 0; i < _runMm.length; i++)
      _runMm[i] + _runIn[i] * KidneyAnatomy.cortex,
  ];
  static final Float64List _junctionAlong = _alongOf(_junctionMm);

  /// The sinus's wall from the upper lip to the lower, and the sinus
  /// closed by the outline's stretch across the hilum back up to the upper
  /// lip.
  static final List<Offset> _sinusWallMm = _resample(
    _catmull(KidneyAnatomy.sinus),
    KidneyStyle.edgeStep,
  );
  static final List<Offset> _sinusMm = () {
    const int span = KidneyStyle.outlineSpan;
    const int from = KidneyAnatomy.upperLip * span;
    const int to = KidneyAnatomy.lowerLip * span;
    return <Offset>[
      ..._sinusWallMm,
      for (int i = to - 1; i > from; i--) _outlineMm[i],
    ];
  }();

  /// The middle of the cortex at the height [y], on the lateral side: half
  /// way from the capsule to the junction there.
  static double _cortexMiddleAt(double y) =>
      (_lateralCrossing(_runMm, y) + _lateralCrossing(_junctionMm, y)) / 2;

  // The parts, laid in the scene.

  /// The run of the outline the parenchyma's edge follows, and the line the
  /// cortex's rim turns away to, in the scene.
  late final List<Offset> run = _placed(_runMm);
  late final List<Offset> rimInner = _placed(<Offset>[
    for (int i = 0; i < _runMm.length; i++)
      _runMm[i] + _runIn[i] * KidneyStyle.rim,
  ]);

  /// The corticomedullary junction, in the scene.
  late final List<Offset> junction = _placed(_junctionMm);

  /// The sinus, closed, in the scene.
  late final List<Offset> sinus = _placed(_sinusMm);

  /// The site in the anatomy's millimetres, and how far along the junction
  /// the point of it nearest the site lies.
  late final Offset _siteMm = toMm(site);
  late final double _siteAlong =
      _junctionAlong[_nearestIndex(_junctionMm, _siteMm)];

  /// Where along the junction each pyramid's base is centred, in
  /// millimetres along it: evenly between the ends the anatomy sets, but
  /// that the one nearest the site is centred under it.
  late final List<double> _baseCentres = () {
    const int count = KidneyAnatomy.pyramids;
    final double total = _junctionAlong.last;
    final double from = total * KidneyAnatomy.pyramidsFrom;
    final double to = total * KidneyAnatomy.pyramidsTo;
    final int k = _sitePyramid;
    return <double>[
      for (int i = 0; i < count; i++)
        i < k
            ? from + (_siteAlong - from) * (i + 0.5) / (k + 0.5)
            : i == k
            ? _siteAlong
            : _siteAlong + (to - _siteAlong) * (i - k) / (count - k - 0.5),
    ];
  }();

  /// The pyramid whose base lies under the site: the one whose even share
  /// of the junction it lies in.
  late final int _sitePyramid = () {
    const int count = KidneyAnatomy.pyramids;
    final double total = _junctionAlong.last;
    final double from = total * KidneyAnatomy.pyramidsFrom;
    final double slot =
        total * (KidneyAnatomy.pyramidsTo - KidneyAnatomy.pyramidsFrom) / count;
    return ((_siteAlong - from) / slot - 0.5).round().clamp(0, count - 1);
  }();

  /// The pyramids, in millimetres, each with what is laid in it.
  late final List<_PyramidMm> _pyramidsMm = () {
    const int count = KidneyAnatomy.pyramids;
    final List<double> centres = _baseCentres;
    final double slot =
        _junctionAlong.last *
        (KidneyAnatomy.pyramidsTo - KidneyAnatomy.pyramidsFrom) /
        count;
    final double half = slot * KidneyAnatomy.pyramidBase / 2;
    // Each papilla opens where the sinus's wall comes nearest its base, but
    // that, in their order round the sinus, two open a gap apart at least,
    // as they gather toward a pole.
    final Float64List wallAlong = _alongOf(_sinusWallMm);
    final List<double> opens = <double>[
      for (int i = 0; i < count; i++)
        wallAlong[_nearestIndex(
          _sinusWallMm,
          _junctionMm[_indexAt(_junctionAlong, centres[i])],
        )],
    ];
    const double gap = KidneyAnatomy.papillaGap;
    for (int pass = 0; pass < 40; pass++) {
      for (int i = 1; i < count; i++) {
        final double short = gap - (opens[i] - opens[i - 1]);
        if (short > 0) {
          opens[i - 1] -= short / 2;
          opens[i] += short / 2;
        }
      }
      opens[0] = math.max(opens[0], gap / 2);
      opens[count - 1] = math.min(opens[count - 1], wallAlong.last - gap / 2);
    }
    return <_PyramidMm>[
      for (int i = 0; i < count; i++)
        _pyramid(
          centres[i] - half,
          centres[i] + half,
          _sinusWallMm[_indexAt(wallAlong, opens[i])],
          site: i == _sitePyramid,
        ),
    ];
  }();

  _PyramidMm _pyramid(
    double from,
    double to,
    Offset wall, {
    required bool site,
  }) {
    final int a = _indexAt(_junctionAlong, from);
    final int b = _indexAt(_junctionAlong, to);
    final List<Offset> base = <Offset>[
      for (int i = a; i <= b; i++) _junctionMm[i],
    ];
    final Offset middle = _junctionMm[(a + b) ~/ 2];
    // Its papilla stands into the sinus past the wall where it opens.
    final Offset way = _unit(wall - middle);
    final Offset tip = wall + way * KidneyAnatomy.papillaInto;
    final Offset across = Offset(-way.dy, way.dx);
    // Which side of its axis its base's first end lies on.
    final double first = _dot(base.first - middle, across) >= 0 ? 1 : -1;
    // The papilla is blunt: the flanks end either side of a round over the
    // tip, and bow out a little from the axis.
    const double round = KidneyAnatomy.papillaRound;
    final Offset roundCentre = tip - way * round;
    List<Offset> flank(Offset corner, double toward) {
      final Offset end = roundCentre + across * (toward * round);
      final Offset control =
          Offset.lerp(corner, end, 0.5)! +
          across * (toward * KidneyAnatomy.flankBow * (end - corner).distance);
      return _resample(<Offset>[
        for (int k = 0; k <= 24; k++) _quadratic(corner, control, end, k / 24),
      ], KidneyStyle.edgeStep);
    }

    final List<Offset> left = flank(base.first, first);
    final List<Offset> right = flank(base.last, -first);
    // The round over the tip, from the second flank's end to the first's.
    final List<Offset> cap = <Offset>[
      for (int k = 1; k < 8; k++)
        roundCentre +
            (across * (-first * math.cos(math.pi * k / 8)) +
                    way * math.sin(math.pi * k / 8)) *
                round,
    ];
    final List<Offset> outline = <Offset>[
      ...base,
      ...right.skip(1),
      ...cap,
      ...left.reversed.take(left.length - 1),
    ];
    // Its flanks matched point for point, so a face can be laid between.
    final int n = math.max(left.length, right.length);
    final List<Offset> leftEven = _evenly(left, n);
    final List<Offset> rightEven = _evenly(right, n);
    int at(double share) => (share * (n - 1)).round().clamp(1, n - 2);
    final int outerTo = at(KidneyAnatomy.outerMedulla);
    final int papillaFrom = at(1 - KidneyAnatomy.papilla);
    final List<Offset> outer = <Offset>[
      ...base,
      ...rightEven.sublist(1, outerTo + 1),
      ..._bowed(rightEven[outerTo], leftEven[outerTo], middle, 0.12),
      ...leftEven.sublist(1, outerTo + 1).reversed,
    ];
    final List<Offset> papilla = <Offset>[
      ..._bowed(leftEven[papillaFrom], rightEven[papillaFrom], tip, -0.12),
      ...rightEven.sublist(papillaFrom),
      ...cap,
      ...leftEven.sublist(papillaFrom).reversed,
    ];
    // Its striations, from along its base toward its papilla.
    final List<List<Offset>> striations = <List<Offset>>[
      for (int k = 1; k <= KidneyStyle.striations; k++)
        () {
          final double t = k / (KidneyStyle.striations + 1);
          final Offset start = base[(t * (base.length - 1)).round()];
          final Offset end = roundCentre - way * 0.6;
          final Offset control =
              Offset.lerp(start, end, 0.45)! +
              across * (_dot(start - middle, across) * 0.2);
          return <Offset>[
            for (int j = 0; j <= 12; j++)
              _quadratic(start, control, end, j / 12),
          ];
        }(),
    ];
    // Its rays, up from its base into the cortex, a ray's spacing apart:
    // where they are the cell's home one runs through the site, and where
    // they are not the site lies between two.
    final double baseFrom = _junctionAlong[a];
    final double baseTo = _junctionAlong[b];
    const double spacing = KidneyAnatomy.raySpacing;
    final bool through =
        site && (home == KidneyHome.loops || home == KidneyHome.ducts);
    double phase = spacing / 2;
    if (site) {
      final double offset = (_siteAlong - baseFrom) % spacing;
      phase = through ? offset : (offset + spacing / 2) % spacing;
    }
    final List<(Offset, Offset)> rays = <(Offset, Offset)>[
      for (
        double s = baseFrom + phase;
        s <= baseTo - KidneyAnatomy.ray;
        s += spacing
      )
        if (s >= baseFrom + KidneyAnatomy.ray)
          () {
            final int i = _indexAt(_junctionAlong, s);
            final Offset from = _junctionMm[i];
            final Offset end = _runMm[i] + _runIn[i] * KidneyAnatomy.rayShort;
            // The one under the site, where the rays are the cell's home,
            // runs through it.
            if (through && (s - _siteAlong).abs() < spacing / 2) {
              return (
                from,
                from + _unit(_siteMm - from) * (end - from).distance,
              );
            }
            return (from, end);
          }(),
    ];
    return _PyramidMm(
      base: base,
      outline: outline,
      left: leftEven,
      right: rightEven,
      outer: outer,
      papilla: papilla,
      tip: tip,
      way: way,
      striations: striations,
      rays: rays,
    );
  }

  /// The pyramids, in the scene, in their order round the kidney from the
  /// upper lip.
  late final List<KidneyPyramid> pyramids = <KidneyPyramid>[
    for (final _PyramidMm p in _pyramidsMm)
      KidneyPyramid._(
        outline: _placed(p.outline),
        left: _placed(p.left),
        right: _placed(p.right),
        outer: _placed(p.outer),
        papilla: _placed(p.papilla),
        tip: place(p.tip),
        striations: <List<Offset>>[
          for (final List<Offset> line in p.striations) _placed(line),
        ],
        rays: <(Offset, Offset)>[
          for (final (Offset a, Offset b) in p.rays) (place(a), place(b)),
        ],
      ),
  ];

  /// The pyramid whose base lies under the site.
  KidneyPyramid get sitePyramid => pyramids[_sitePyramid];

  // The calyces and the pelvis: one cavity, emptied.

  /// The collecting system's cavity, in millimetres: the pelvis, the major
  /// calyces and a minor calyx cupped round each papilla, as one shape.
  late final Path _collectingMm = () {
    Path all = Path();
    void add(List<Offset> polygon) {
      if (polygon.length < 3) {
        return;
      }
      all = Path.combine(
        PathOperation.union,
        all,
        Path()..addPolygon(polygon, true),
      );
    }

    add(_tubeShape(KidneyAnatomy.pelvis, KidneyAnatomy.pelvisHalf));
    add(_tubeShape(KidneyAnatomy.upperCalyx, KidneyAnatomy.upperCalyxHalf));
    add(_tubeShape(KidneyAnatomy.middleCalyx, KidneyAnatomy.middleCalyxHalf));
    add(_tubeShape(KidneyAnatomy.lowerCalyx, KidneyAnatomy.lowerCalyxHalf));
    final List<Offset> majors = <Offset>[
      ..._catmull(KidneyAnatomy.upperCalyx, per: 4),
      ..._catmull(KidneyAnatomy.middleCalyx, per: 4),
      ..._catmull(KidneyAnatomy.lowerCalyx, per: 4),
    ];
    for (final _PyramidMm p in _pyramidsMm) {
      add(_cup(p));
      // Its neck, into the nearest of the major calyces.
      final Offset bottom = p.tip + p.way * KidneyAnatomy.cupClear;
      final Offset nearest = majors[_nearestIndex(majors, bottom)];
      add(_tubeShape(<Offset>[bottom, nearest], const <double>[2.2, 2.4]));
    }
    return all;
  }();

  /// A minor calyx's cup round [p]'s papilla: its wall a clearance out from
  /// the papilla, from as far back as the cup reaches on one side round
  /// over the tip to the other.
  static List<Offset> _cup(_PyramidMm p) {
    final Offset centre = p.tip - p.way * (KidneyAnatomy.cupBack / 2);
    return <Offset>[
      for (final Offset q in p.outline)
        if (_dot(q - p.tip, p.way) > -KidneyAnatomy.cupBack)
          q + _unit(q - centre) * KidneyAnatomy.cupClear,
    ];
  }

  /// The anatomy's millimetres taken into the scene, as a matrix.
  late final Float64List _matrix = Float64List.fromList(<double>[
    side * scale, 0, 0, 0, //
    0, scale, 0, 0, //
    0, 0, 1, 0, //
    -side * _shift * scale, 0, 0, 1, //
  ]);

  /// The collecting system's cavity, in the scene, and its edges, along
  /// which its rim is drawn.
  late final Path collecting = _collectingMm.transform(_matrix);
  late final List<List<Offset>> collectingEdges = <List<Offset>>[
    for (final PathMetric metric in collecting.computeMetrics())
      <Offset>[
        for (double s = 0; s < metric.length; s += mm(KidneyStyle.edgeStep))
          metric.getTangentForOffset(s)!.position,
      ],
  ];

  // The vessels and the ureter.

  TubeCourse _tube(
    List<Offset> points,
    double radius, {
    double fadeOut = 0,
    bool cutEnd = false,
  }) => TubeCourse(
    AnatomyTube(
      points,
      <double>[for (int i = 0; i < points.length; i++) radius],
      fadeOut: fadeOut,
      cutEnd: cutEnd,
    ),
    place,
    scale,
    mm(KidneyStyle.edgeStep),
    bend: 0.9,
  );

  /// The renal artery and vein, cut short past the hilum.
  late final TubeCourse renalArtery = _tube(
    KidneyAnatomy.renalArtery,
    KidneyAnatomy.arteryRadius,
    cutEnd: true,
  );
  late final TubeCourse renalVein = _tube(
    KidneyAnatomy.renalVein,
    KidneyAnatomy.veinRadius,
    cutEnd: true,
  );

  /// The ureter, fading out below the hilum.
  late final TubeCourse ureter = _tube(
    KidneyAnatomy.ureter,
    KidneyAnatomy.ureterRadius,
    fadeOut: KidneyAnatomy.ureterFade,
  );

  /// The vein's branches into the sinus.
  late final List<TubeCourse> veinBranches = <TubeCourse>[
    for (final List<Offset> branch in KidneyAnatomy.veinBranches)
      _tube(branch, KidneyAnatomy.veinBranchRadius),
  ];

  /// Each column's root at the sinus and its top at the junction, between
  /// two neighbouring pyramids, in millimetres.
  late final List<(Offset, Offset)> _columnsMm = <(Offset, Offset)>[
    for (int i = 0; i + 1 < _pyramidsMm.length; i++)
      () {
        final Offset top =
            (_pyramidsMm[i].base.last + _pyramidsMm[i + 1].base.first) / 2;
        final Offset root = _sinusWallMm[_nearestIndex(_sinusWallMm, top)];
        return (root, top);
      }(),
  ];

  /// The segmental arteries, from the renal artery's end in the sinus to
  /// each column's root; the interlobar arteries, up each column; and the
  /// arcuate arteries, over each pyramid's base.
  late final List<TubeCourse> segmental = <TubeCourse>[
    for (final (Offset root, Offset _) in _columnsMm)
      () {
        final Offset from = KidneyAnatomy.renalArtery.first;
        final Offset middle = Offset.lerp(from, root, 0.55)!;
        return _tube(<Offset>[
          from,
          middle,
          root,
        ], KidneyAnatomy.segmentalRadius);
      }(),
  ];
  late final List<TubeCourse> interlobar = <TubeCourse>[
    for (final (Offset root, Offset top) in _columnsMm)
      _tube(<Offset>[
        root,
        Offset.lerp(root, top, 0.5)!,
        top,
      ], KidneyAnatomy.interlobarRadius),
  ];
  late final List<TubeCourse> arcuate = <TubeCourse>[
    for (final _PyramidMm p in _pyramidsMm)
      _tube(<Offset>[
        for (int k = 0; k <= 4; k++)
          p.base[(k * (p.base.length - 1)) ~/ 4] + p.way * 0.6,
      ], KidneyAnatomy.arcuateRadius),
  ];

  // The glomeruli.

  /// The glomeruli the cut shows, in the scene: a dust through the cortex
  /// under the capsule and down its columns, clear of the rays, the
  /// capsule, the pyramids, the sinus and the site.
  late final List<Offset> glomeruli = () {
    final math.Random random = math.Random(KidneyStyle.seed);
    const double r = KidneyAnatomy.glomerulus;
    const double clear = r + KidneyStyle.glomerulusClear;
    const double density = KidneyAnatomy.glomeruliPerMm2;
    final _Grid rays = _Grid(2);
    for (final _PyramidMm p in _pyramidsMm) {
      for (final (Offset a, Offset b) in p.rays) {
        rays.addSegment(a, b);
      }
    }
    final _Grid placed = _Grid(1);
    final List<Offset> out = <Offset>[];
    void add(Offset p) {
      if ((p - _siteMm).distance < KidneyStyle.siteClear ||
          rays.nearSegment(p, KidneyAnatomy.ray / 2 + clear) ||
          placed.nearPoint(p, 2 * r + 0.15)) {
        return;
      }
      out.add(p);
      placed.addPoint(p);
    }

    // Under the capsule, a band the cortex's thickness, but by the lips,
    // where the sinus comes near it.
    const double lips = 7;
    final double length = _runAlong.last - 2 * lips;
    const double depth = KidneyAnatomy.cortex - 3 * clear;
    final int band = (length * depth * density).round();
    for (int k = 0; k < band; k++) {
      final int i = _indexAt(_runAlong, lips + random.nextDouble() * length);
      final Offset p =
          _runMm[i] + _runIn[i] * (2 * clear + random.nextDouble() * depth);
      if (!_inside(_sinusMm, p) &&
          _toLine(_sinusMm, p, closed: true) >= clear) {
        add(p);
      }
    }
    // Down each column, between two neighbouring pyramids' flanks.
    for (int c = 0; c + 1 < _pyramidsMm.length; c++) {
      final List<Offset> one = _pyramidsMm[c].right;
      final List<Offset> other = _pyramidsMm[c + 1].left;
      final int n = math.min(one.length, other.length);
      double area = 0;
      for (int j = 1; j < n; j++) {
        area +=
            ((one[j] - other[j]).distance +
                (one[j - 1] - other[j - 1]).distance) /
            2 *
            ((one[j] - one[j - 1]).distance +
                (other[j] - other[j - 1]).distance) /
            2;
      }
      final int count = (area * density).round();
      for (int k = 0; k < count; k++) {
        final int j = random.nextInt(n);
        final Offset a = one[j];
        final Offset b = other[j];
        final double gap = (b - a).distance;
        if (gap < 4 * clear) {
          continue;
        }
        final Offset p = Offset.lerp(
          a,
          b,
          (2 * clear + random.nextDouble() * (gap - 4 * clear)) / gap,
        )!;
        if (!_inside(_sinusMm, p) &&
            _toLine(_sinusMm, p, closed: true) >= clear) {
          add(p);
        }
      }
    }
    return _placed(out);
  }();

  /// The glomerulus at the site, where the glomeruli are the cell's home.
  Offset? get siteGlomerulus => home == KidneyHome.glomeruli ? site : null;

  // Where the parts are named.

  /// The cortex, half way through it on the lateral side, a share of the
  /// way down the kidney.
  late final Offset cortexName = () {
    const double y =
        KidneyAnatomy.length * (KidneyAnatomy.cortexNameDown - 0.5);
    return place(Offset(_cortexMiddleAt(y), y));
  }();

  /// The medulla: in the pyramid whose base is nearest the lateral side a
  /// share of the way down the kidney, toward its papilla.
  late final Offset medullaName = () {
    const double y =
        KidneyAnatomy.length * (KidneyAnatomy.medullaNameDown - 0.5);
    final Offset at = Offset(_lateralCrossing(_junctionMm, y), y);
    _PyramidMm best = _pyramidsMm.first;
    for (final _PyramidMm p in _pyramidsMm) {
      if ((p.middleOfBase - at).distance < (best.middleOfBase - at).distance) {
        best = p;
      }
    }
    return place(Offset.lerp(best.middleOfBase, best.tip, 0.45)!);
  }();

  /// The renal pelvis and the ureter.
  late final Offset pelvisName = place(KidneyAnatomy.pelvisName);
  late final Offset ureterName = place(KidneyAnatomy.ureterName);

  /// The papilla nearest [p], a little back from its tip.
  Offset papillaNear(Offset p) {
    KidneyPyramid best = pyramids.first;
    for (final KidneyPyramid q in pyramids) {
      if ((q.tip - p).distance < (best.tip - p).distance) {
        best = q;
      }
    }
    return Offset.lerp(best.tip, best.centre, 0.15)!;
  }

  /// Where the kidney and what is drawn beside it reach furthest to either
  /// side at the height of [at]: the outline's crossings there, and the
  /// vessels' and the ureter's where they pass it, with room to spare.
  (Offset, Offset) edgesAt(Offset at) {
    double left = double.infinity;
    double right = double.negativeInfinity;
    for (final double x in _crossings(outlinePoints, at.dy)) {
      left = math.min(left, x);
      right = math.max(right, x);
    }
    final double clear = mm(KidneyStyle.nameClear);
    for (final TubeCourse tube in <TubeCourse>[
      renalArtery,
      renalVein,
      ureter,
    ]) {
      for (int i = 0; i < tube.length; i++) {
        if (tube.shown[i] <= 0.5) {
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

  /// Where the step from the body meets the kidney's outline and the
  /// body's, beside their tops: the lateral border's outermost point, the
  /// lower pole, the hilum's deepest point and the upper pole's medial
  /// bulge, each picked out of either outline alike.
  late final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, -side, 0.3, 0.7),
        _lowest,
        (List<Offset> p) => _hilum(p, side),
        (List<Offset> p) => OutlineMarks.outermost(p, side, 0.1, 0.4),
      ];

  /// The lowest of [points].
  static int _lowest(List<Offset> points) {
    int best = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy > points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The deepest point of the hilum's notch: of [points] on the [side] half
  /// of their box between 0.4 and 0.75 of the way down, the least far out.
  static int _hilum(List<Offset> points, double side) {
    final Rect box = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      final Offset p = points[i];
      final double down = (p.dy - box.top) / box.height;
      if (down < 0.4 || down > 0.75 || (p.dx - box.center.dx) * side <= 0) {
        continue;
      }
      if (best < 0 || p.dx * side < points[best].dx * side) {
        best = i;
      }
    }
    return best;
  }

  /// The points of the kidney's own outline where the step from the body
  /// meets the body's, for tests: in the order round it from the top.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

/// A pyramid in millimetres, with what is laid in it.
final class _PyramidMm {
  _PyramidMm({
    required this.base,
    required this.outline,
    required this.left,
    required this.right,
    required this.outer,
    required this.papilla,
    required this.tip,
    required this.way,
    required this.striations,
    required this.rays,
  });

  /// Its base, along the junction, and its outline.
  final List<Offset> base;
  final List<Offset> outline;

  /// Its flanks, from its base's ends to its papilla, point for point.
  final List<Offset> left;
  final List<Offset> right;
  final List<Offset> outer;
  final List<Offset> papilla;

  /// Its papilla's tip, and the way from its base toward it, a unit.
  final Offset tip;
  final Offset way;
  final List<List<Offset>> striations;
  final List<(Offset, Offset)> rays;

  late final Offset middleOfBase = base[base.length ~/ 2];
}

/// Points and segments kept in square cells, to find what lies near a
/// point quickly.
final class _Grid {
  _Grid(this.cell);

  final double cell;
  final Map<int, List<Offset>> _points = <int, List<Offset>>{};
  final Map<int, List<(Offset, Offset)>> _segments =
      <int, List<(Offset, Offset)>>{};

  static int _key(int i, int j) => (i + 4096) * 8192 + (j + 4096);

  void addPoint(Offset p) {
    final int i = (p.dx / cell).floor();
    final int j = (p.dy / cell).floor();
    (_points[_key(i, j)] ??= <Offset>[]).add(p);
  }

  void addSegment(Offset a, Offset b) {
    final Rect box = Rect.fromPoints(a, b);
    for (
      int i = (box.left / cell).floor();
      i <= (box.right / cell).floor();
      i++
    ) {
      for (
        int j = (box.top / cell).floor();
        j <= (box.bottom / cell).floor();
        j++
      ) {
        (_segments[_key(i, j)] ??= <(Offset, Offset)>[]).add((a, b));
      }
    }
  }

  bool nearPoint(Offset p, double distance) {
    final int ci = (p.dx / cell).floor();
    final int cj = (p.dy / cell).floor();
    final int reach = (distance / cell).ceil();
    for (int i = ci - reach; i <= ci + reach; i++) {
      for (int j = cj - reach; j <= cj + reach; j++) {
        for (final Offset q in _points[_key(i, j)] ?? const <Offset>[]) {
          if ((q - p).distance < distance) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool nearSegment(Offset p, double distance) {
    final int ci = (p.dx / cell).floor();
    final int cj = (p.dy / cell).floor();
    final int reach = (distance / cell).ceil();
    for (int i = ci - reach; i <= ci + reach; i++) {
      for (int j = cj - reach; j <= cj + reach; j++) {
        for (final (Offset a, Offset b)
            in _segments[_key(i, j)] ?? const <(Offset, Offset)>[]) {
          if (_toSegment(p, a, b) < distance) {
            return true;
          }
        }
      }
    }
    return false;
  }
}

// Geometry.

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

Offset _unit(Offset p) {
  final double length = p.distance;
  return length <= 0 ? Offset.zero : p / length;
}

Offset _mean(List<Offset> points) {
  Offset sum = Offset.zero;
  for (final Offset p in points) {
    sum += p;
  }
  return sum / points.length.toDouble();
}

Offset _quadratic(Offset a, Offset control, Offset b, double t) {
  final double u = 1 - t;
  return a * (u * u) + control * (2 * u * t) + b * (t * t);
}

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

Float64List _alongOf(List<Offset> line) {
  final Float64List out = Float64List(line.length);
  for (int i = 1; i < line.length; i++) {
    out[i] = out[i - 1] + (line[i] - line[i - 1]).distance;
  }
  return out;
}

/// The index of the point of a line that lies [at] along it, by [along],
/// its points' distances along it.
int _indexAt(Float64List along, double at) {
  int low = 0;
  int high = along.length - 1;
  while (high - low > 1) {
    final int middle = (low + high) ~/ 2;
    if (along[middle] < at) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return (at - along[low]).abs() <= (along[high] - at).abs() ? low : high;
}

int _nearestIndex(List<Offset> points, Offset p) {
  int best = 0;
  for (int i = 1; i < points.length; i++) {
    if ((points[i] - p).distanceSquared < (points[best] - p).distanceSquared) {
      best = i;
    }
  }
  return best;
}

/// Where the open [line] crosses the height [y] furthest toward the
/// kidney's lateral side, the anatomy's left.
double _lateralCrossing(List<Offset> line, double y) {
  double? best;
  for (int i = 1; i < line.length; i++) {
    final Offset a = line[i - 1];
    final Offset b = line[i];
    if ((a.dy - y) * (b.dy - y) <= 0 && a.dy != b.dy) {
      final double x = a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy);
      best = best == null ? x : math.min(best, x);
    }
  }
  return best ?? line.map((Offset p) => p.dx).reduce(math.min);
}

/// Where the closed [points] cross the height [y].
List<double> _crossings(List<Offset> points, double y) {
  final List<double> out = <double>[];
  final int n = points.length;
  for (int i = 0; i < n; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    if ((a.dy <= y) != (b.dy <= y)) {
      out.add(a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy));
    }
  }
  return out;
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
  final Float64List along = _alongOf(line);
  final int count = math.max(2, (along.last / step).round() + 1);
  return _evenly(line, count, along: along);
}

/// [line] laid again as [count] points evenly along it, its ends kept.
List<Offset> _evenly(List<Offset> line, int count, {Float64List? along}) {
  final Float64List at = along ?? _alongOf(line);
  final double total = at.last;
  final List<Offset> out = <Offset>[];
  int j = 1;
  for (int k = 0; k < count; k++) {
    final double s = total * k / (count - 1);
    while (j < line.length - 1 && at[j] < s) {
      j++;
    }
    final double span = at[j] - at[j - 1];
    final double t = span <= 0 ? 0 : (s - at[j - 1]) / span;
    out.add(Offset.lerp(line[j - 1], line[j], t.clamp(0.0, 1.0))!);
  }
  return out;
}

/// The inner points of a curve from [a] to [b], bowed toward [toward] by
/// [bow] of their distance apart, or away where [bow] is negative.
List<Offset> _bowed(Offset a, Offset b, Offset toward, double bow) {
  final Offset middle = (a + b) / 2;
  final Offset control =
      middle + _unit(toward - middle) * (bow * (b - a).distance);
  return <Offset>[for (int k = 1; k < 8; k++) _quadratic(a, control, b, k / 8)];
}

/// A tube's shape round its course through [knots], as wide either side
/// of it as [halves] along it, its ends rounded.
List<Offset> _tubeShape(List<Offset> knots, List<double> halves) {
  final List<Offset> course = _resample(
    knots.length < 3 ? knots : _catmull(knots, per: 8),
    0.5,
  );
  final Float64List along = _alongOf(course);
  final double total = along.last;
  double halfAt(double s) {
    final double x = (halves.length - 1) * (total <= 0 ? 0 : s / total);
    final int i = x.floor().clamp(0, halves.length - 2);
    return halves[i] + (halves[i + 1] - halves[i]) * (x - i);
  }

  final int n = course.length;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset t = _unit(
      course[math.min(n - 1, i + 1)] - course[math.max(0, i - 1)],
    );
    final Offset across = Offset(-t.dy, t.dx);
    final double h = halfAt(along[i]);
    left.add(course[i] + across * h);
    right.add(course[i] - across * h);
  }
  // Round over each end: from one side, out past the end, to the other.
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
    ...round(course.last, endWay, Offset(-endWay.dy, endWay.dx), halfAt(total)),
    ...right.reversed,
    ...round(
      course.first,
      startWay,
      Offset(-startWay.dy, startWay.dx),
      halfAt(0),
    ),
  ];
}

double _toSegment(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double length = ab.distanceSquared;
  final double t = length <= 0 ? 0 : (_dot(p - a, ab) / length).clamp(0.0, 1.0);
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
