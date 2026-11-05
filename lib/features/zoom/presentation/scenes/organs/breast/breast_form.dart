import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../lobules.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'breast_anatomy.dart';
import 'breast_style.dart';

/// The figure's lymph nodes: those of its axilla are named beside the
/// breast, where the figure draws them.
const String _lymphNodes = 'UBERON_0000029';

/// Where in the breast the zoom's cell lives, which its drawing lights in
/// the mark, by the Atlas's name for the cell. By the kind of cell, never
/// by gene.
enum BreastHome {
  /// The gland, its lobes and the ducts that run from them to the nipple:
  /// every epithelial cell of it, luminal or myoepithelial, lactating,
  /// secretory or hormone-responsive, and every cell that has no part of
  /// the breast of its own to be drawn at its size (its fibroblasts, its
  /// vessels' lining, its immune cells).
  gland,

  /// The fat: its adipocytes.
  fat,

  /// The nipple and the areola: a smooth muscle cell, of the muscle that
  /// rings the nipple's base and lies under the areola.
  nipple;

  /// Where a cell the Atlas calls [cell] lives.
  static BreastHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('adipocyte')) {
      return fat;
    }
    if (name.contains('smooth muscle')) {
      return nipple;
    }
    return gland;
  }

  /// What its name says.
  String get word => switch (this) {
    gland => 'ducts and lobules',
    fat => 'fat',
    nipple => 'nipple and areola',
  };
}

/// One of the gland's ducts: its course, how wide it is, in millimetres of
/// the real breast, and which generation of branch it is, its lobe's main
/// duct the 0th and the short ones lobules bud from the 4th.
typedef BreastDuct = ({List<Offset> course, double width, int generation});

/// The breast as the zoom's organ scene draws it, seen from the front in
/// place, its lower half dissected: every part in the scene's units at its
/// real size, the middle of the body's outline of it at the origin.
///
/// The breast is drawn from general anatomy ([BreastAnatomy]) and laid on
/// the body's outline of it so that the place it is gone into in the
/// anatomy ([BreastAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline in toward the
/// breast's own ([pathAt]). Everything here is geometry: what it is drawn
/// in is `BreastArt`'s.
final class BreastForm {
  BreastForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.home = BreastHome.gland,
    this.nodesOutline,
  }) : scale = length / BreastAnatomy.length {
    final List<Offset> knots = <Offset>[
      for (final Offset p in BreastAnatomy.outline) place(p),
    ];
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(BreastStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(BreastStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: BreastStyle.morphPoints,
      bed: mm(BreastStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The breast where the body draws it as [part] of [figure], in a view
  /// [view] metres across, about a cell that lives in its [home]; the
  /// figure's axillary lymph nodes beside it.
  factory BreastForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    AnatomyFigure? figure,
    BreastHome home = BreastHome.gland,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    // The figure's nodes nearest the place the body goes in: its axilla's.
    List<Offset>? nodes;
    final AnatomyPart? lymph = figure?.parts[_lymphNodes];
    if (lymph != null) {
      double least = double.infinity;
      for (final List<Offset> c in lymph.contours) {
        final Rect r = _bounds(c);
        final double dx = math.max(
          0,
          math.max(r.left - part.site.dx, part.site.dx - r.right),
        );
        final double dy = math.max(
          0,
          math.max(r.top - part.site.dy, part.site.dy - r.bottom),
        );
        final double d = math.sqrt(dx * dx + dy * dy);
        if (d < least) {
          least = d;
          nodes = c;
        }
      }
    }
    return BreastForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
      nodesOutline: nodes == null
          ? null
          : <Offset>[for (final Offset p in nodes) placed(p)],
    );
  }

  /// Where the body goes into the breast, in the scene: a duct under the
  /// areola.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Where the zoom's cell lives in it.
  final BreastHome home;

  /// The body's outline of the axillary lymph nodes beside the breast, in
  /// the scene; none where no figure is given or it draws none.
  final List<Offset>? nodesOutline;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The breast's outline, its base, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - BreastAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => BreastAnatomy.site + (p - site) / scale;

  /// How far the breast's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  /// How far the middle of the breast's mound lies from the middle of the
  /// body's outline, in millimetres: each the middle of its top's middle and
  /// its lowest point, down, and of its two outermost points, across (the
  /// places the step from the body meets them at), so that the axillary
  /// tail, which the body does not draw, counts for nothing.
  double get moundShift {
    Offset middle(List<Offset> marks) => Offset(
      (marks[1].dx + marks[3].dx) / 2,
      (marks[0].dy + marks[2].dy) / 2,
    );
    return (middle(marksOf(outlinePoints)) - middle(marksOf(outlineAt(0))))
            .distance /
        scale;
  }

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the breast's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the breast's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every breast.

  /// The outline followed closely, in millimetres.
  static final List<Offset> _outlineMm = const Contour(BreastAnatomy.outline)
      .sampled(BreastStyle.outlineSpan)
      .points;

  /// The way into the breast at each of the outline's points, a unit.
  static final List<Offset> _inwardMm = () {
    final List<Offset> normals = _normals(_outlineMm, closed: true);
    final double inward = _inside(_outlineMm, _outlineMm[0] + normals[0] * 0.5)
        ? 1
        : -1;
    return <Offset>[for (final Offset n in normals) n * inward];
  }();

  /// The breast above the skin's cut, and below it.
  static final List<Offset> _upperMm = _cutBy(
    _outlineMm,
    BreastAnatomy.cut,
    below: false,
  );
  static final List<Offset> _lowerMm = _cutBy(
    _outlineMm,
    BreastAnatomy.cut,
    below: true,
  );

  /// The dissection: the lower half inside its cut skin, round its lower
  /// edge and along the cut.
  static final List<Offset> _dissectionMm = _cutBy(
    <Offset>[
      for (int i = 0; i < _outlineMm.length; i++)
        _outlineMm[i] + _inwardMm[i] * BreastAnatomy.skinBelow,
    ],
    BreastAnatomy.cut + BreastAnatomy.skin,
    below: true,
  );

  /// Where the cut runs across the breast, from its lateral side to its
  /// medial, in millimetres.
  static final (Offset, Offset) _cutMm = () {
    final List<Offset> on = <Offset>[
      for (final Offset p in _lowerMm)
        if ((p.dy - BreastAnatomy.cut).abs() < 1e-9) p,
    ]..sort((Offset a, Offset b) => a.dx.compareTo(b.dx));
    return (on.first, on.last);
  }();

  /// The lower edge, from one end of the cut round the lower pole to the
  /// other, in millimetres.
  static final List<Offset> _lowerEdgeMm = () {
    final int n = _lowerMm.length;
    final int from = _lowerMm.indexOf(_cutMm.$1);
    final int to = _lowerMm.indexOf(_cutMm.$2);
    // Round the way that does not run along the cut: the longer.
    List<Offset> way(int step) {
      final List<Offset> out = <Offset>[];
      for (int i = from; ; i = (i + step + n) % n) {
        out.add(_lowerMm[i]);
        if (i == to) {
          return out;
        }
      }
    }

    final List<Offset> forward = way(1);
    final List<Offset> back = way(-1);
    return _length(forward) > _length(back) ? forward : back;
  }();

  // The gland.

  static final List<_LobeMm> _lobesMm = <_LobeMm>[
    for (final (double axis, double reach, double spread, int seed)
        in BreastAnatomy.lobes)
      _LobeMm.lay(axis, reach, spread, seed),
  ];

  /// Whether [mm] lies in one of the lobes.
  static bool inLobe(Offset mm) =>
      _lobesMm.any((_LobeMm lobe) => _inside(lobe.outline, mm));

  /// How far [mm] lies from the nearest duct's wall, in millimetres: below
  /// zero inside a duct. For tests.
  static double clearOfDucts(Offset mm) {
    double best = double.infinity;
    for (final _LobeMm lobe in _lobesMm) {
      for (final BreastDuct duct in lobe.ducts) {
        best = math.min(
          best,
          _toLine(duct.course, mm, closed: false) - duct.width / 2,
        );
      }
    }
    return best;
  }

  /// How far [mm] lies below the skin's cut band, in millimetres: below
  /// zero in it or above it. For tests.
  static double clearOfCut(Offset mm) =>
      mm.dy - BreastAnatomy.cut - BreastAnatomy.skin;

  /// The lobes' outlines, their ducts and their lobules, and the
  /// dissection's outline, in millimetres. For tests.
  static List<List<Offset>> get lobesMm => <List<Offset>>[
    for (final _LobeMm lobe in _lobesMm) lobe.outline,
  ];
  static List<List<BreastDuct>> get ductsMm => <List<BreastDuct>>[
    for (final _LobeMm lobe in _lobesMm) lobe.ducts,
  ];
  static List<Offset> get lobulesMm => <Offset>[
    for (final _LobeMm lobe in _lobesMm) ...lobe.lobules,
  ];
  static List<Offset> get dissectionMm => _dissectionMm;

  // The ligaments.

  /// The suspensory ligaments, each from a lobe's edge, or the septum
  /// between two, out through the fat to the cut skin, in millimetres.
  static final List<List<Offset>> _ligamentsMm = () {
    final math.Random random = math.Random(BreastStyle.seed + 7);
    final List<List<Offset>> out = <List<Offset>>[];
    for (final double degrees in BreastAnatomy.ligaments) {
      final double a = degrees * math.pi / 180;
      final Offset way = Offset(math.cos(a), math.sin(a));
      final _LobeMm? lobe = _lobesMm.cast<_LobeMm?>().firstWhere(
        (_LobeMm? l) => _inside(l!.outline, way * (BreastAnatomy.lobeFrom + 6)),
        orElse: () => null,
      );
      // From the lobe's outer edge along this way, or the septum's middle.
      double from = BreastAnatomy.lobeFrom + 6;
      if (lobe != null) {
        while (_inside(lobe.outline, way * (from + 0.25))) {
          from += 0.25;
        }
      }
      double to = from;
      while (_inside(_dissectionMm, way * (to + 0.25))) {
        to += 0.25;
      }
      to -= 0.2;
      if (to - from < 4) {
        continue;
      }
      final Offset start = way * from;
      final Offset end = way * to;
      final Offset across = Offset(-way.dy, way.dx);
      final Offset control =
          Offset.lerp(start, end, 0.5)! +
          across * (2.5 * (random.nextBool() ? 1 : -1));
      out.add(_quadratic(start, control, end, BreastStyle.edgeStep));
    }
    return out;
  }();

  static List<List<Offset>> get ligamentsMm => _ligamentsMm;

  // The pectoralis.

  static final List<Offset> _pectoralisMm = const Contour(
    BreastAnatomy.pectoralis,
  ).sampled(4).points;

  /// How much of what lies at [mm] round the breast shows: all of it near
  /// the breast, fading out with its distance from it.
  static double fadeAt(Offset mm) {
    if (!_reach.contains(mm)) {
      return 0;
    }
    if (_inside(_outlineMm, mm)) {
      return 1;
    }
    final double d = _toLine(_coarseMm, mm, closed: true);
    return 1 -
        _smooth(
          (d - BreastStyle.fadeFrom) /
              (BreastStyle.fadeTo - BreastStyle.fadeFrom),
        );
  }

  static final Rect _reach = _bounds(_outlineMm)
      .inflate(BreastStyle.fadeTo + 2);

  static final List<Offset> _coarseMm = <Offset>[
    for (int i = 0; i < _outlineMm.length; i += 2) _outlineMm[i],
  ];

  /// The box the pectoralis is drawn in: as far as it shows round the
  /// breast, in millimetres.
  static final Rect pectoralisReachMm = _bounds(_pectoralisMm)
      .intersect(_reach);

  /// The pectoralis's fascicles and its border, each laid as short runs,
  /// each with how much of it shows, in millimetres.
  static final List<(Offset, Offset, double)> _fibresMm = () {
    final List<Offset> origin = <Offset>[
      for (int i = 0; i <= 8; i++) BreastAnatomy.pectoralis[i],
    ];
    final List<double> along = <double>[0];
    for (int i = 1; i < origin.length; i++) {
      along.add(along.last + (origin[i] - origin[i - 1]).distance);
    }
    final List<(Offset, Offset, double)> out = <(Offset, Offset, double)>[];
    for (
      double s = BreastAnatomy.fascicle / 2;
      s < along.last;
      s += BreastAnatomy.fascicle
    ) {
      int j = 1;
      while (j < along.length - 1 && along[j] < s) {
        j++;
      }
      final double t = (s - along[j - 1]) / (along[j] - along[j - 1]);
      final Offset from = Offset.lerp(origin[j - 1], origin[j], t)!;
      out.addAll(_runs(from, BreastAnatomy.insertion));
    }
    return out;
  }();
  static final List<(Offset, Offset, double)> _borderMm = () {
    final List<(Offset, Offset, double)> out = <(Offset, Offset, double)>[];
    final int n = _pectoralisMm.length;
    for (int i = 0; i < n; i++) {
      out.addAll(_runs(_pectoralisMm[i], _pectoralisMm[(i + 1) % n]));
    }
    return out;
  }();

  /// [from] to [to] in runs about a fibre step long, each with how much of
  /// it shows at its middle; none that do not show at all.
  static List<(Offset, Offset, double)> _runs(Offset from, Offset to) {
    final double length = (to - from).distance;
    final int steps = math.max(1, (length / BreastStyle.fibreStep).ceil());
    return <(Offset, Offset, double)>[
      for (int k = 0; k < steps; k++)
        () {
          final Offset a = Offset.lerp(from, to, k / steps)!;
          final Offset b = Offset.lerp(from, to, (k + 1) / steps)!;
          final Offset middle = Offset.lerp(a, b, 0.5)!;
          // Under the breast, a run is hidden: none.
          return (a, b, _inside(_outlineMm, middle) ? 0.0 : fadeAt(middle));
        }(),
    ].where(((Offset, Offset, double) r) => r.$3 > 0.004).toList();
  }

  // The parts, laid in the scene.

  /// The breast above the cut and below it, the dissection inside the cut
  /// skin, and the cut's line across it.
  late final List<Offset> upper = _placed(_upperMm);
  late final List<Offset> lower = _placed(_lowerMm);
  late final List<Offset> dissection = _placed(_dissectionMm);
  late final (Offset, Offset) cutLine = (place(_cutMm.$1), place(_cutMm.$2));
  late final List<Offset> lowerEdge = _placed(_lowerEdgeMm);

  /// The nipple's middle, and the nipple's and the areola's radii.
  late final Offset nipple = place(Offset.zero);
  late final double nippleRadius = mm(BreastAnatomy.nipple);
  late final double areolaRadius = mm(BreastAnatomy.areola);

  /// The areolar glands, and the ducts' orifices on the nipple.
  late final List<Offset> areolarGlands = _placed(BreastAnatomy.areolarGlands);
  late final List<Offset> orifices = _placed(BreastAnatomy.orifices);

  /// The lobes' outlines, the ducts, the lobules, and the ligaments.
  late final List<List<Offset>> lobes = <List<Offset>>[
    for (final _LobeMm lobe in _lobesMm) _placed(lobe.outline),
  ];
  late final List<BreastDuct> ducts = <BreastDuct>[
    for (final _LobeMm lobe in _lobesMm)
      for (final BreastDuct duct in lobe.ducts)
        (
          course: _placed(duct.course),
          width: duct.width,
          generation: duct.generation,
        ),
  ];
  late final List<Offset> lobules = <Offset>[
    for (final _LobeMm lobe in _lobesMm) ..._placed(lobe.lobules),
  ];
  late final List<List<Offset>> ligaments = <List<Offset>>[
    for (final List<Offset> l in _ligamentsMm) _placed(l),
  ];

  /// The fat's lobules, laid in the dissection, and those of them that lie
  /// in the fat: neither in a lobe nor under the areola, where there is no
  /// fat.
  late final Lobules fat = Lobules.lay(
    dissection,
    box: _bounds(dissection),
    inward: _area(dissection) > 0 ? 1.0 : -1.0,
    style: BreastStyle.fat,
    mm: mm,
    seed: BreastStyle.seed,
  );
  late final List<Lobule> fatLobules = <Lobule>[
    for (final Lobule lobule in fat.all)
      if (_inFat(toMm(lobule.centre))) lobule,
  ];

  static bool _inFat(Offset mm) =>
      !inLobe(mm) && mm.distance > BreastAnatomy.areola + 1;

  /// The pectoralis, its fascicles and its border, each run with how much
  /// of it shows.
  late final List<Offset> pectoralis = _placed(_pectoralisMm);
  late final List<(Offset, Offset, double)> fibres = <(Offset, Offset, double)>[
    for (final (Offset a, Offset b, double shown) in _fibresMm)
      (place(a), place(b), shown),
  ];
  late final List<(Offset, Offset, double)> border = <(Offset, Offset, double)>[
    for (final (Offset a, Offset b, double shown) in _borderMm)
      (place(a), place(b), shown),
  ];
  late final Rect pectoralisReach = Rect.fromPoints(
    place(pectoralisReachMm.topLeft),
    place(pectoralisReachMm.bottomRight),
  );

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(BreastStyle.edgeStep), bend: 0.9);

  /// The internal thoracic artery's branches, and the lateral thoracic
  /// artery, each cut short.
  late final List<TubeCourse> perforators = <TubeCourse>[
    for (final AnatomyTube t in BreastAnatomy.perforators) _tube(t),
  ];
  late final TubeCourse lateralThoracic = _tube(BreastAnatomy.lateralThoracic);
  late final List<TubeCourse> arteries = <TubeCourse>[
    ...perforators,
    lateralThoracic,
  ];

  /// The lateral thoracic artery's small branches into the breast's edge.
  late final List<TubeCourse> branches = <TubeCourse>[
    for (final AnatomyTube t in _branchesMm) _tube(t),
  ];

  static final List<AnatomyTube> _branchesMm = () {
    final List<AnatomyTube> out = <AnatomyTube>[];
    final math.Random random = math.Random(BreastStyle.seed + 3);
    final TubeCourse course = TubeCourse(
      BreastAnatomy.lateralThoracic,
      (Offset p) => p,
      1,
      BreastStyle.edgeStep,
      bend: 0.9,
    );
    double next = BreastAnatomy.branchApart / 2;
    for (int i = 0; i < course.length; i++) {
      if (course.arc[i] < next || course.shown[i] < 0.5) {
        continue;
      }
      final Offset c = course.centres[i];
      final Offset way = Offset(course.across[i].dy, -course.across[i].dx);
      final Offset aim =
          c + way * (BreastAnatomy.branchLean * (2 * random.nextDouble() - 1));
      Offset edge = _outlineMm.first;
      for (final Offset q in _outlineMm) {
        if ((q - aim).distanceSquared < (edge - aim).distanceSquared) {
          edge = q;
        }
      }
      final Offset to = edge - c;
      final double reach = to.distance;
      if (reach > BreastAnatomy.branchReach || reach <= 0) {
        continue;
      }
      next =
          course.arc[i] +
          BreastAnatomy.branchApart +
          BreastAnatomy.branchJitter * (2 * random.nextDouble() - 1);
      out.add(
        AnatomyTube(
          <Offset>[c, edge + to / reach * BreastAnatomy.branchUnder],
          const <double>[BreastAnatomy.branch, BreastAnatomy.branch],
        ),
      );
    }
    return out;
  }();

  /// What runs on beside the breast.
  late final List<TubeCourse> beside = arteries;

  // Where the parts are named.

  /// Its nipple, its areola's upper half, a lobe below the site, a
  /// ligament, the fat, the pectoralis above it and its axillary tail.
  late final Offset nippleName = nipple;
  late final Offset areolaName = place(BreastAnatomy.areolaName);
  late final Offset glandName = place(BreastAnatomy.glandName);
  late final Offset ligamentName = _nearest(
    ligaments,
    place(BreastAnatomy.ligamentName),
  );
  late final Offset fatName = _nearestLobule(place(BreastAnatomy.fatName));
  late final Offset pectoralisName = place(BreastAnatomy.pectoralisName);
  late final Offset tailName = place(
    Offset.lerp(BreastAnatomy.tailRoot, BreastAnatomy.tailTip, 0.5)!,
  );

  /// Where the zoom's cell lives, named at the place its tissue is sampled:
  /// on its duct for a cell of the gland, the fat's lobule nearest it for a
  /// fat cell, the nipple for a cell of its muscle.
  late final Offset homeName = switch (home) {
    BreastHome.gland => site,
    BreastHome.fat => _nearestLobule(site),
    BreastHome.nipple => nipple,
  };

  Offset _nearestLobule(Offset p) {
    Offset best = fatLobules.first.centre;
    for (final Lobule lobule in fatLobules) {
      if ((lobule.centre - p).distanceSquared < (best - p).distanceSquared) {
        best = lobule.centre;
      }
    }
    return best;
  }

  /// The figure's axillary nodes, named where they show beside the breast:
  /// the point of them furthest in from their outline and out from the
  /// breast, clear of the pectoralis over them and inside the view; none
  /// where the figure draws none.
  late final Offset? nodesName = () {
    final List<Offset>? shape = nodesOutline;
    if (shape == null) {
      return null;
    }
    final Rect bounds = _bounds(shape);
    final double step = mm(BreastStyle.nodeStep);
    const double reach = BreastStyle.nodeReach;
    Offset? best;
    double most = 0;
    for (double y = bounds.top; y <= bounds.bottom; y += step) {
      for (double x = bounds.left; x <= bounds.right; x += step) {
        final Offset p = Offset(x, y);
        if (p.dx.abs() > reach ||
            p.dy.abs() > reach ||
            !_inside(shape, p) ||
            _inside(outlinePoints, p) ||
            _inside(pectoralis, p)) {
          continue;
        }
        final double room = math.min(
          _toLine(shape, p, closed: true) * BreastStyle.nodeInside,
          _toLine(outlinePoints, p, closed: true),
        );
        if (room > most) {
          most = room;
          best = p;
        }
      }
    }
    return best;
  }();

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

  /// Where the step from the body meets the breast's outline and the
  /// body's: the middle of the top, in place of the topmost point, which on
  /// the breast is its axillary tail's tip; each side's outermost point,
  /// the lateral below the tail, and the lowest, each picked out of either
  /// outline alike.
  static int _topMiddle(List<Offset> points) {
    final Rect box = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      final Offset p = points[i];
      if (p.dy > box.top + box.height * 0.25) {
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
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.3, 0.7),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.5, 0.9),
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

  /// The points of the breast's own outline where the step from the body
  /// meets the body's, for tests: the top's middle, then the rest in the
  /// order round it from there.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topMiddle(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

/// One lobe of the gland, laid in millimetres: its lobulated outline, the
/// ducts that branch through it from the nipple, and its lobules.
final class _LobeMm {
  _LobeMm(this.outline, this.ducts, this.lobules);

  /// The lobe whose duct runs out from the nipple [axis] degrees below the
  /// level, its lobe reaching [reach] from the nipple's middle and spreading
  /// [spread] degrees either side, laid by [seed].
  factory _LobeMm.lay(double axis, double reach, double spread, int seed) {
    final double a = axis * math.pi / 180;
    final double w = spread * math.pi / 180;
    final math.Random random = math.Random(BreastStyle.seed * 31 + seed);
    final List<double> phase = <double>[
      for (int k = 0; k < 4; k++) random.nextDouble() * 2 * math.pi,
    ];
    const double from = BreastAnatomy.lobeFrom;
    Offset polar(double r, double angle) =>
        Offset(r * math.cos(angle), r * math.sin(angle));
    // How far the lobe's outer edge reaches, [u] of the way across it from
    // -1 to 1.
    double outer(double u) =>
        reach * (0.9 + 0.1 * math.cos(u * math.pi / 2)) +
        BreastAnatomy.lobeBumps * math.sin(3.5 * math.pi * u + phase[0]) +
        BreastAnatomy.lobeRipples * math.sin(7 * math.pi * u + phase[1]);
    double out(double s) => from + (reach - from) * s;
    final List<Offset> outline = Contour(<Offset>[
      polar(from + 0.6 * math.sin(phase[2]), a - 0.72 * w),
      polar(from - 1, a),
      polar(from + 0.6 * math.sin(phase[3]), a + 0.72 * w),
      polar(out(0.33), a + w * (0.95 + 0.04 * math.sin(phase[2]))),
      polar(out(0.66), a + w),
      for (int k = 0; k <= 6; k++)
        () {
          final double u = 0.92 - k * 1.84 / 6;
          return polar(outer(u), a + u * w);
        }(),
      polar(out(0.66), a - w),
      polar(out(0.33), a - w * (0.95 + 0.04 * math.sin(phase[3]))),
    ]).sampled(6).points;

    final List<BreastDuct> ducts = <BreastDuct>[];
    final List<Offset> lobules = <Offset>[];
    const List<double> widths = BreastAnatomy.ductWidths;
    const double lobule = BreastAnatomy.lobule;
    bool holds(Offset p) =>
        _inside(outline, p) && _toLine(outline, p, closed: true) > lobule / 2;
    double jitter(double by) => by * (2 * random.nextDouble() - 1);
    // How far out the lobe's drawn edge lies along the way [angle], from
    // [inside] it.
    double edgeAt(double angle, double inside) {
      final Offset way = Offset(math.cos(angle), math.sin(angle));
      double r = inside;
      while (_inside(outline, way * (r + 0.25))) {
        r += 0.25;
      }
      return r;
    }

    // The main duct, from under the nipple's edge out to its first branch.
    final Offset first = polar(BreastAnatomy.firstBranch, a);
    ducts.add((
      course: _quadratic(
        polar(BreastAnatomy.nipple * 0.7, a),
        polar((BreastAnatomy.nipple * 0.7 + BreastAnatomy.firstBranch) / 2, a),
        first,
        BreastStyle.edgeStep,
      ),
      width: widths[0],
      generation: 0,
    ));
    // Lobules budding from [course] on short ducts, every so far along it,
    // to either side in turn.
    void buds(List<Offset> course) {
      double along = 0;
      double next = BreastAnatomy.budApart * 0.6;
      bool left = random.nextBool();
      for (int i = 1; i < course.length; i++) {
        along += (course[i] - course[i - 1]).distance;
        if (along < next) {
          continue;
        }
        next += BreastAnatomy.budApart;
        final Offset t = _unit(course[i] - course[i - 1]);
        final double turn = (left ? -1 : 1) * 0.87;
        left = !left;
        final Offset way = Offset(
          t.dx * math.cos(turn) - t.dy * math.sin(turn),
          t.dx * math.sin(turn) + t.dy * math.cos(turn),
        );
        final Offset end = course[i] + way * BreastAnatomy.budLength;
        final Offset first = end + way * (lobule / 2);
        final Offset second =
            end +
            Offset(-way.dy, way.dx) * (lobule * 0.8 * (left ? 1 : -1)) +
            way * (lobule * 0.2);
        if (!holds(first) || !holds(second)) {
          continue;
        }
        ducts.add((
          course: <Offset>[course[i], end],
          width: widths[4],
          generation: 4,
        ));
        lobules
          ..add(first)
          ..add(second);
      }
    }

    // Each branch forks twice more on the way out to the lobe's edge, the
    // last ending in a cluster of lobules.
    void grow(Offset start, double angle, int generation) {
      final double r = switch (generation) {
        1 => out(0.15),
        2 => out(0.5),
        _ => edgeAt(angle, start.distance) - BreastAnatomy.clusterReach - 0.9,
      };
      final Offset end = polar(r, angle);
      final Offset t = _unit(end - start);
      final Offset control =
          Offset.lerp(start, end, 0.5)! + Offset(-t.dy, t.dx) * jitter(0.8);
      final List<Offset> course = _quadratic(
        start,
        control,
        end,
        BreastStyle.edgeStep,
      );
      ducts.add((
        course: course,
        width: widths[generation],
        generation: generation,
      ));
      if (generation >= 2) {
        buds(course);
      }
      if (generation == 3) {
        // The cluster at its end: one on the duct's line, the rest fanned
        // round it.
        final double heading = math.atan2(t.dy, t.dx);
        final List<Offset> cluster = <Offset>[
          end + t * (lobule / 2),
          for (int k = 0; k < BreastAnatomy.cluster - 1; k++)
            end +
                polar(
                  BreastAnatomy.clusterReach * (0.62 + 0.1 * (k % 2)),
                  heading + (k - (BreastAnatomy.cluster - 2) / 2) * 0.66,
                ),
        ];
        lobules.addAll(cluster.where(holds));
        return;
      }
      final double fork = w * (generation == 1 ? 0.22 : 0.11);
      grow(end, angle - fork + jitter(0.03 * w), generation + 1);
      grow(end, angle + fork + jitter(0.03 * w), generation + 1);
    }

    grow(first, a - 0.45 * w + jitter(0.03 * w), 1);
    grow(first, a + 0.45 * w + jitter(0.03 * w), 1);
    return _LobeMm(outline, ducts, lobules);
  }

  final List<Offset> outline;
  final List<BreastDuct> ducts;
  final List<Offset> lobules;
}

// Geometry, in the anatomy's millimetres or the scene's units.

/// [polygon] cut by the level [y]: the part below it where [below], else
/// the part above.
List<Offset> _cutBy(List<Offset> polygon, double y, {required bool below}) {
  final List<Offset> out = <Offset>[];
  bool keeps(Offset p) => below ? p.dy >= y : p.dy <= y;
  final int n = polygon.length;
  for (int i = 0; i < n; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % n];
    final bool ka = keeps(a);
    final bool kb = keeps(b);
    if (ka) {
      out.add(a);
    }
    if (ka != kb) {
      final double t = (y - a.dy) / (b.dy - a.dy);
      out.add(Offset(a.dx + (b.dx - a.dx) * t, y));
    }
  }
  return out;
}

/// The quadratic curve from [from] by [control] to [to], in points [step]
/// apart at most.
List<Offset> _quadratic(Offset from, Offset control, Offset to, double step) {
  final double length = (control - from).distance + (to - control).distance;
  final int steps = math.max(2, (length / step).ceil());
  return <Offset>[
    for (int i = 0; i <= steps; i++)
      () {
        final double t = i / steps;
        final double u = 1 - t;
        return from * (u * u) + control * (2 * u * t) + to * (t * t);
      }(),
  ];
}

double _length(List<Offset> points) {
  double sum = 0;
  for (int i = 1; i < points.length; i++) {
    sum += (points[i] - points[i - 1]).distance;
  }
  return sum;
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
