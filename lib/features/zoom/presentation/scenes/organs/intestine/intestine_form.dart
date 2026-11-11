import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'intestine_anatomy.dart';
import 'intestine_style.dart';

/// Where in the intestines the zoom's cell lives, by the Atlas's name for
/// it: the lining of the colon, seen through the window in the cecum and the
/// ascending colon, for a cell of the colon (and for any cell the Atlas
/// names no home of its own in the intestine, which only its pairing of
/// cells with the colon brings here); the lining of the terminal ileum,
/// laid open beside it, for an enterocyte or a Paneth cell; both, one
/// lining through the valve, for a cell of either; or their muscle, the
/// colon's bands and the muscle coats of the wall cut round the window, for
/// a smooth muscle cell, an interstitial cell of Cajal or an enteric glial
/// cell, whose plexus lies between them.
enum IntestineHome {
  colon,
  ileum,
  both,
  muscle;

  static IntestineHome of(String? cell) {
    if (cell == null) {
      return both;
    }
    final String name = cell.toLowerCase();
    if (name.contains('smooth muscle') ||
        name.contains('interstitial cells of cajal') ||
        name.contains('enteric glia')) {
      return muscle;
    }
    if (name.contains('colon')) {
      return colon;
    }
    if (name.contains('enterocyte') || name.contains('paneth')) {
      return ileum;
    }
    if (name.contains('goblet') ||
        name.contains('tuft') ||
        name.contains('neuroendocrine') ||
        name.contains('enteric stem') ||
        name.contains('transient amplifying') ||
        name.contains('mitotic')) {
      return both;
    }
    return colon;
  }

  /// Whether the colon's lining is where the cell lives.
  bool get inColon => this == colon || this == both;

  /// Whether the ileum's lining is where the cell lives.
  bool get inIleum => this == ileum || this == both;
}

/// A tube's rows laid in the scene: each its middle, the way across it, how
/// far it reaches to either side, how much it tips toward or away from the
/// way along it, and how much of it shows.
typedef IntestineRows = ({
  List<Offset> centres,
  List<Offset> across,
  List<double> plus,
  List<double> minus,
  List<double> tilt,
  List<double> shown,
});

/// The intestines as the zoom's organ scene draws them, in place from the
/// front: every part in the scene's units at its real size, the middle of
/// the body's outline of the intestine at the origin.
///
/// They are drawn from general anatomy ([IntestineAnatomy]) and laid on the
/// body's outline of the intestine so that the place they are gone into in
/// the anatomy ([IntestineAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline in toward the
/// intestines' own ([pathAt]). Where the zoom's cell lives is [home].
/// Everything here is geometry: what it is drawn in is `IntestineArt`'s.
final class IntestineForm {
  IntestineForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    required this.home,
  }) : scale = length / IntestineAnatomy.length {
    final List<Offset> diagramDense = Contour(diagram).sampled(8).points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool reversed = _area(_outlineMm).sign != _area(diagramDense).sign;
    final List<Offset> placed = _placed(_outlineMm);
    outlinePoints = reversed ? placed.reversed.toList() : placed;
    outline = Contour(outlinePoints).toPath();
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: IntestineStyle.morphPoints,
      bed: mm(IntestineStyle.bed),
      marks: _marks,
    );
  }

  /// The intestines where the body draws the intestine as [part], in a view
  /// [view] metres across, the zoom's cell living in [home].
  factory IntestineForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    required IntestineHome home,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return IntestineForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the intestines, in the scene: on the Peyer's
  /// patch in the terminal ileum, just short of the valve.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Where the zoom's cell lives.
  final IntestineHome home;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The intestines' outline, round everything drawn, and the points it is
  /// followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - IntestineAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => IntestineAnatomy.site + (p - site) / scale;

  /// How far the intestines' box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying them so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the intestines' at 1, and [bed] of the way on toward the
  /// bed they lie on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the intestines' outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The colon, in millimetres, built once for every form.

  /// The colon's middle line followed closely: its rows, the way across
  /// each, how far along it each lies.
  static final TubeCourse _colon = TubeCourse(
    const AnatomyTube(IntestineAnatomy.colon, IntestineAnatomy.colonHalf),
    (Offset p) => p,
    1,
    IntestineStyle.edgeStep,
    bend: 0.9,
  );

  static double get _colonLength => _colon.arc[_colon.length - 1];

  /// How wide the colon is to either side at each of its rows: the
  /// anatomy's widths at its points, eased between them (a cubic through
  /// them), so its sides bend where they widen or narrow and never break.
  static final List<double> _colonBase = () {
    final List<int> knots = _colon.knotRows;
    const List<double> h = IntestineAnatomy.colonHalf;
    final int n = h.length;
    final List<double> a = <double>[for (final int k in knots) _colon.arc[k]];
    final List<double> slope = <double>[
      for (int k = 0; k < n; k++)
        k == 0
            ? 0
            : k == n - 1
            ? 0
            : (h[k + 1] - h[k - 1]) / (a[k + 1] - a[k - 1]),
    ];
    final List<double> out = <double>[];
    for (int i = 0; i < _colon.length; i++) {
      int k = 0;
      while (k + 1 < n - 1 && knots[k + 1] <= i) {
        k++;
      }
      final double span = a[k + 1] - a[k];
      final double t = span > 0
          ? ((_colon.arc[i] - a[k]) / span).clamp(0.0, 1.0)
          : 0;
      final double t2 = t * t;
      final double t3 = t2 * t;
      out.add(
        (2 * t3 - 3 * t2 + 1) * h[k] +
            (t3 - 2 * t2 + t) * span * slope[k] +
            (-2 * t3 + 3 * t2) * h[k + 1] +
            (t3 - t2) * span * slope[k + 1],
      );
    }
    return out;
  }();

  /// How far the sacculi bulge the colon out at [s] millimetres along it,
  /// a share of its half-width (none at their grooves), and how fast that
  /// changes along it.
  static (double, double) _sacculusAt(double s) {
    const double from = IntestineAnatomy.sacculiFrom;
    const double pitch = IntestineAnatomy.sacculus;
    final double to = _colonLength - IntestineAnatomy.sacculiStop;
    if (s <= from || s >= to) {
      return (0, 0);
    }
    final double envelope =
        _smooth((s - from) / (pitch / 2)) * _smooth((to - s) / (pitch / 2));
    final double phase = 2 * math.pi * (s - from) / pitch;
    const double bulge = IntestineAnatomy.sacculusBulge;
    return (
      bulge * (0.5 - 0.5 * math.cos(phase)) * envelope,
      bulge * math.pi / pitch * math.sin(phase) * envelope,
    );
  }

  /// How far the cecum's blind end is drawn in to its rounded tip at [s]
  /// millimetres along the colon: a share of its width.
  static double _domeAt(double s) {
    const double r = IntestineAnatomy.cecumRound;
    if (s >= r) {
      return 1;
    }
    final double t = 1 - s / r;
    return math.sqrt(math.max(0, 1 - t * t));
  }

  /// The colon's half-width at each row, its sacculi and its rounded end
  /// in it, and how much its surface tips along it there.
  static final List<double> _colonHalf = <double>[
    for (int i = 0; i < _colon.length; i++)
      _colonBase[i] *
          (1 + _sacculusAt(_colon.arc[i]).$1) *
          _domeAt(_colon.arc[i]),
  ];
  static final List<double> _colonTilt = <double>[
    for (int i = 0; i < _colon.length; i++)
      _colonBase[i] * _sacculusAt(_colon.arc[i]).$2,
  ];

  /// How far the colon reaches to either side of its middle at row [i], a
  /// bend's inner side drawn in as its course's.
  static double _colonPlusAt(int i) => _colon.plus[i] < _colon.radius[i]
      ? math.min(_colonHalf[i], _colon.plus[i])
      : _colonHalf[i];
  static double _colonMinusAt(int i) => _colon.minus[i] < _colon.radius[i]
      ? math.min(_colonHalf[i], _colon.minus[i])
      : _colonHalf[i];

  /// The row [s] millimetres along a course.
  static int _rowAt(TubeCourse course, double s) {
    int best = 0;
    for (int i = 1; i < course.length; i++) {
      if ((course.arc[i] - s).abs() < (course.arc[best] - s).abs()) {
        best = i;
      }
    }
    return best;
  }

  /// The row the window ends at, and the row the sigmoid colon starts at.
  static final int _windowRow = _rowAt(_colon, IntestineAnatomy.windowTo);
  static final int _sigmoidRow = _colon.knotRows[IntestineAnatomy.sigmoidFrom];

  /// The grooves between the sacculi, how far along the colon each lies.
  static final List<double> _grooves = () {
    final List<double> out = <double>[];
    for (
      double s = IntestineAnatomy.sacculiFrom;
      s < _colonLength - IntestineAnatomy.sacculiStop;
      s += IntestineAnatomy.sacculus
    ) {
      out.add(s);
    }
    return out;
  }();

  /// The colon's outline, its plus side up from the cecum's tip, across
  /// its cut end, and back down its minus side, in millimetres.
  static final List<Offset> _colonOutlineMm = <Offset>[
    for (int i = 0; i < _colon.length; i++)
      _colon.centres[i] + _colon.across[i] * _colonPlusAt(i),
    for (int i = _colon.length - 1; i >= 0; i--)
      _colon.centres[i] - _colon.across[i] * _colonMinusAt(i),
  ];

  /// The window's outer edge, the cut through the wall's outer face: the
  /// colon's rows from the cecum's tip to where the window is cut across.
  static final List<Offset> _windowOuter = () {
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    for (
      int i = 0;
      i < _colon.length && _colon.arc[i] <= IntestineAnatomy.windowTo;
      i++
    ) {
      plus.add(_colon.centres[i] + _colon.across[i] * _colonPlusAt(i));
      minus.add(_colon.centres[i] - _colon.across[i] * _colonMinusAt(i));
    }
    // The tip once, where the two sides meet.
    return <Offset>[...plus, ...minus.reversed.skip(1)];
  }();

  /// The window's edge drawn in by [depth] millimetres all round, along
  /// the edge's own normals: round the cecum's rounded end and down from
  /// the cut across the colon alike.
  static List<Offset> _windowEdge(double depth) {
    final List<Offset> points = _windowOuter;
    if (depth <= 0) {
      return points;
    }
    final int n = points.length;
    final double inward = _area(points) > 0 ? 1 : -1;
    Offset normal(Offset a, Offset b) {
      final Offset t = _unit(b - a);
      return Offset(-t.dy, t.dx) * inward;
    }

    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          // Mitred: along the bisector of the two edges' normals, far
          // enough to lie [depth] in from both.
          final Offset a = normal(points[(i - 1 + n) % n], points[i]);
          final Offset b = normal(points[i], points[(i + 1) % n]);
          final Offset mid = _unit(a + b);
          final double cos = math.max(0.5, mid.dx * a.dx + mid.dy * a.dy);
          return points[i] + mid * (depth / cos);
        }(),
    ];
  }

  /// How deep each of the cut wall's coats lies under its outer face, from
  /// the outside in: the serosa's inner edge, the longitudinal muscle's,
  /// the circular muscle's, the submucosa's; and the lining, the wall's
  /// inner edge, for a wall [wall] thick.
  static List<double> _depths(double wall) {
    double d = 0;
    final List<double> out = <double>[];
    for (final double share in <double>[
      IntestineAnatomy.serosaShare,
      IntestineAnatomy.longitudinalShare,
      IntestineAnatomy.circularShare,
      IntestineAnatomy.submucosaShare,
    ]) {
      d += wall * share;
      out.add(d);
    }
    out.add(wall);
    return out;
  }

  static final List<List<Offset>> _windowMm = <List<Offset>>[
    _windowEdge(0),
    for (final double d in _depths(IntestineAnatomy.colonWall)) _windowEdge(d),
  ];

  // The terminal ileum, in millimetres.

  static final TubeCourse _ileum = TubeCourse(
    IntestineAnatomy.terminalIleum,
    (Offset p) => p,
    1,
    IntestineStyle.edgeStep,
    bend: 0.9,
  );

  static double get _ileumLength => _ileum.arc[_ileum.length - 1];

  /// The ileum laid open, its edge drawn in by [depth] millimetres: its rows
  /// from where it is cut open to where the cut stops short of the cecum,
  /// each so far in.
  static List<Offset> _stripEdge(double depth) {
    final double from = _ileumLength - IntestineAnatomy.openTo + depth;
    final double to = _ileumLength - IntestineAnatomy.openFrom - depth;
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    for (int i = 0; i < _ileum.length; i++) {
      final double s = _ileum.arc[i];
      if (s < from || s > to) {
        continue;
      }
      plus.add(_ileum.centres[i] + _ileum.across[i] * (_ileum.plus[i] - depth));
      minus.add(
        _ileum.centres[i] - _ileum.across[i] * (_ileum.minus[i] - depth),
      );
    }
    return <Offset>[...plus, ...minus.reversed];
  }

  static final List<List<Offset>> _stripMm = <List<Offset>>[
    _stripEdge(0),
    for (final double d in _depths(IntestineAnatomy.ileumWall)) _stripEdge(d),
  ];

  /// The rows where the ileum is cut open, and where it is not: from the
  /// pelvis up to the cut, and from the cut's end on under the cecum.
  static final int _openFirst = _rowAt(
    _ileum,
    _ileumLength - IntestineAnatomy.openTo,
  );
  static final int _openLast = _rowAt(
    _ileum,
    _ileumLength - IntestineAnatomy.openFrom,
  );

  /// The Peyer's patch: its middle, the way along the ileum there, and its
  /// outline, in millimetres.
  static final (Offset, Offset) _patchFrame = () {
    final int i = _rowAt(_ileum, _ileumLength - IntestineAnatomy.patchAt);
    final Offset way = _unit(
      _ileum.centres[math.min(_ileum.length - 1, i + 1)] -
          _ileum.centres[math.max(0, i - 1)],
    );
    return (_ileum.centres[i], way);
  }();

  /// The patch's middle, in millimetres: where the zoom goes in. For tests.
  static Offset get patchMiddleMm => _patchFrame.$1;

  static final List<Offset> _patchMm = () {
    final (Offset c, Offset way) = _patchFrame;
    final Offset across = Offset(-way.dy, way.dx);
    return <Offset>[
      for (int k = 0; k < 40; k++)
        c +
            way *
                (IntestineAnatomy.patchLength /
                    2 *
                    math.cos(2 * math.pi * k / 40)) +
            across *
                (IntestineAnatomy.patchWidth /
                    2 *
                    math.sin(2 * math.pi * k / 40)),
    ];
  }();

  /// The patch's lymphoid nodules, scattered over it, none nearer another
  /// than half the patch's width.
  static final List<Offset> _nodulesMm = () {
    final (Offset c, Offset way) = _patchFrame;
    final Offset across = Offset(-way.dy, way.dx);
    final math.Random random = math.Random(IntestineStyle.seed);
    final List<Offset> out = <Offset>[];
    const double apart = IntestineAnatomy.patchWidth * 0.3;
    for (
      int tries = 0;
      tries < 400 && out.length < IntestineAnatomy.patchNodules;
      tries++
    ) {
      final double u = random.nextDouble() * 2 - 1;
      final double v = random.nextDouble() * 2 - 1;
      if (u * u + v * v > 0.62) {
        continue;
      }
      final Offset p =
          c +
          way * (u * IntestineAnatomy.patchLength / 2) +
          across * (v * IntestineAnatomy.patchWidth / 2);
      if (out.every((Offset q) => (q - p).distance >= apart)) {
        out.add(p);
      }
    }
    return out;
  }();

  // The coils and the appendix, in millimetres.

  static final List<TubeCourse> _coilsMm = <TubeCourse>[
    for (final (List<Offset> line, bool jejunum) in IntestineAnatomy.coils)
      TubeCourse(
        AnatomyTube(
          line,
          <double>[
            for (final Offset _ in line)
              jejunum
                  ? IntestineAnatomy.jejunumHalf
                  : IntestineAnatomy.ileumHalf,
          ],
          fadeIn: IntestineAnatomy.coilFade,
          fadeOut: IntestineAnatomy.coilFade,
        ),
        (Offset p) => p,
        1,
        IntestineStyle.edgeStep,
        bend: 0.9,
      ),
  ];

  static final TubeCourse _appendixMm = TubeCourse(
    AnatomyTube(IntestineAnatomy.appendix, <double>[
      for (final Offset _ in IntestineAnatomy.appendix)
        IntestineAnatomy.appendixHalf,
    ]),
    (Offset p) => p,
    1,
    IntestineStyle.edgeStep / 2,
    bend: 0.9,
  );

  /// A tube's silhouette where at least half of it shows.
  static List<Offset> _silhouette(TubeCourse t) {
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    for (int i = 0; i < t.length; i++) {
      if (t.shown[i] < 0.5) {
        continue;
      }
      plus.add(t.at(i, 1));
      minus.add(t.at(i, -1));
    }
    return <Offset>[...plus, ...minus.reversed];
  }

  /// The intestines' outline, in millimetres: round the colon, the coils,
  /// the terminal ileum and the appendix together.
  static final List<Offset> _outlineMm = () {
    Path union = Path()..addPolygon(_colonOutlineMm, true);
    for (final List<Offset> shape in <List<Offset>>[
      for (final TubeCourse t in _coilsMm) _silhouette(t),
      _silhouette(_ileum),
      _silhouette(_appendixMm),
      _circle(_appendixMm.centres.last, IntestineAnatomy.appendixHalf),
    ]) {
      if (shape.length < 3) {
        continue;
      }
      union = Path.combine(
        PathOperation.union,
        union,
        Path()..addPolygon(shape, true),
      );
    }
    List<Offset> best = <Offset>[];
    double most = 0;
    for (final PathMetric metric in union.computeMetrics()) {
      final List<Offset> points = <Offset>[
        for (double d = 0; d < metric.length; d += IntestineStyle.outlineStep)
          metric.getTangentForOffset(d)!.position,
      ];
      final double a = _area(points).abs();
      if (a > most) {
        most = a;
        best = points;
      }
    }
    return best;
  }();

  /// The outline, in millimetres. For tests.
  static List<Offset> get outlineMm => _outlineMm;

  static List<Offset> _circle(Offset c, double r) => <Offset>[
    for (int k = 0; k < 16; k++)
      c +
          Offset(
                math.cos(2 * math.pi * k / 16),
                math.sin(2 * math.pi * k / 16),
              ) *
              r,
  ];

  // The folds, in millimetres.

  /// The semilunar folds seen in the window, one at each groove between the
  /// sacculi that lies inside it: from either side in turn, across most of
  /// the lumen, bowed along the colon.
  static final List<List<Offset>> _semilunarMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    int k = 0;
    for (final double s in _grooves) {
      if (s > IntestineAnatomy.windowTo - IntestineAnatomy.colonWall - 4) {
        break;
      }
      final int i = _rowAt(_colon, s);
      const double wall = IntestineAnatomy.colonWall;
      final Offset way = _unit(
        _colon.centres[math.min(_colon.length - 1, i + 1)] -
            _colon.centres[math.max(0, i - 1)],
      );
      final double side = k.isEven ? 1 : -1;
      final double plus = _colonPlusAt(i) - wall;
      final double minus = _colonMinusAt(i) - wall;
      final Offset root =
          _colon.centres[i] + _colon.across[i] * (side > 0 ? plus : -minus);
      final Offset tip =
          root -
          _colon.across[i] *
              (side * (plus + minus) * IntestineAnatomy.semilunarReach);
      final Offset middle =
          Offset.lerp(root, tip, 0.5)! - way * IntestineAnatomy.semilunarBow;
      out.add(
        _smoothLine(<Offset>[root, middle, tip], IntestineStyle.edgeStep / 3),
      );
      k++;
    }
    return out;
  }();

  /// The valve: its aperture, its two lips' attached borders, and its
  /// frenula running on round the wall from the aperture's two ends.
  static final List<Offset> _slitMm = _smoothLine(<Offset>[
    IntestineAnatomy.valveFrom,
    Offset.lerp(IntestineAnatomy.valveFrom, IntestineAnatomy.valveTo, 0.5)! +
        const Offset(0, 0.6),
    IntestineAnatomy.valveTo,
  ], 0.5);

  static List<Offset> _lip(double off) {
    const Offset a = IntestineAnatomy.valveFrom;
    const Offset b = IntestineAnatomy.valveTo;
    final Offset way = _unit(b - a);
    final Offset normal = Offset(way.dy, -way.dx);
    return _smoothLine(<Offset>[
      a - way * 1.5,
      Offset.lerp(a, b, 0.25)! + normal * (off * 0.8),
      Offset.lerp(a, b, 0.55)! + normal * off,
      b + way * 1.2,
    ], 0.5);
  }

  static final List<List<Offset>> _valveMm = () {
    const Offset a = IntestineAnatomy.valveFrom;
    const Offset b = IntestineAnatomy.valveTo;
    final Offset way = _unit(b - a);
    const double f = IntestineAnatomy.frenulum;
    return <List<Offset>>[
      _lip(IntestineAnatomy.upperLip),
      _lip(-IntestineAnatomy.lowerLip),
      _smoothLine(<Offset>[
        a - way * 1.5,
        a - way * (f * 0.5) + const Offset(0, -1),
        a - way * f + const Offset(0, -0.5),
      ], 0.5),
      _smoothLine(<Offset>[
        b + way * 1.2,
        b + way * (f * 0.5) + const Offset(0, 1),
        b + way * f + const Offset(0, 2.5),
      ], 0.5),
    ];
  }();

  /// The grooves between the sacculi on the colon's outside, each across
  /// it at its row, with which part of the colon it lies on: the sigmoid's
  /// behind the coils, the rest over them.
  static final List<(List<Offset>, bool)> _groovesMm = () {
    final List<(List<Offset>, bool)> out = <(List<Offset>, bool)>[];
    for (final double s in _grooves) {
      if (s < IntestineAnatomy.windowTo + 4) {
        continue;
      }
      final int i = _rowAt(_colon, s);
      const double reach = IntestineStyle.grooveReach;
      out.add((
        <Offset>[
          for (int k = 0; k <= 8; k++)
            _colon.centres[i] +
                _colon.across[i] *
                    (k <= 4
                        ? -_colonMinusAt(i) * reach * (1 - k / 4)
                        : _colonPlusAt(i) * reach * ((k - 4) / 4)),
        ],
        i >= _sigmoidRow,
      ));
    }
    return out;
  }();

  // The parts, laid in the scene.

  /// The colon's rows in the scene: the window's (cut away, drawn as its
  /// edges), the rest lit; and the row the window ends at, and the row the
  /// sigmoid colon starts at.
  late final IntestineRows colon = (
    centres: _placed(_colon.centres),
    across: _colon.across,
    plus: <double>[for (int i = 0; i < _colon.length; i++) mm(_colonPlusAt(i))],
    minus: <double>[
      for (int i = 0; i < _colon.length; i++) mm(_colonMinusAt(i)),
    ],
    tilt: _colonTilt,
    shown: <double>[
      for (int i = 0; i < _colon.length; i++)
        _smooth((_colonLength - _colon.arc[i]) / IntestineAnatomy.rectumFade),
    ],
  );
  int get windowRow => _windowRow;
  int get sigmoidRow => _sigmoidRow;

  /// The colon's free band: how far across the colon it reaches to either
  /// side of its middle at each row, a share of its half-width.
  late final List<double> band = <double>[
    for (int i = 0; i < _colon.length; i++)
      math.min(0.6, IntestineAnatomy.band / 2 / math.max(1, _colonHalf[i])),
  ];

  /// The window, as the edges of its cut wall's coats from the outside in
  /// (the serosa's outer face, the serosa's inner edge, the longitudinal
  /// muscle's, the circular muscle's, the submucosa's) and the lining, the
  /// wall's inner edge, last.
  late final List<List<Offset>> window = <List<Offset>>[
    for (final List<Offset> edge in _windowMm) _placed(edge),
  ];

  /// The terminal ileum laid open, as its cut wall's coats and its lining,
  /// as [window]'s are.
  late final List<List<Offset>> strip = <List<Offset>>[
    for (final List<Offset> edge in _stripMm) _placed(edge),
  ];

  /// The terminal ileum, lit where it is not cut open, and the rows it is
  /// cut open between.
  late final TubeCourse ileum = _tube(IntestineAnatomy.terminalIleum);
  int get openFirst => _openFirst;
  int get openLast => _openLast;

  /// The coils, back to front, and which are the jejunum's.
  late final List<TubeCourse> coils = <TubeCourse>[
    for (final (List<Offset> line, bool jejunum) in IntestineAnatomy.coils)
      _tube(
        AnatomyTube(
          line,
          <double>[
            for (final Offset _ in line)
              jejunum
                  ? IntestineAnatomy.jejunumHalf
                  : IntestineAnatomy.ileumHalf,
          ],
          fadeIn: IntestineAnatomy.coilFade,
          fadeOut: IntestineAnatomy.coilFade,
        ),
      ),
  ];
  static final List<bool> jejunal = <bool>[
    for (final (List<Offset>, bool) coil in IntestineAnatomy.coils) coil.$2,
  ];

  /// The appendix, and its rounded tip.
  late final TubeCourse appendix = TubeCourse(
    AnatomyTube(IntestineAnatomy.appendix, <double>[
      for (final Offset _ in IntestineAnatomy.appendix)
        IntestineAnatomy.appendixHalf,
    ]),
    place,
    scale,
    mm(IntestineStyle.edgeStep / 2),
    bend: 0.9,
  );

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(IntestineStyle.edgeStep), bend: 0.9);

  /// The appendices epiploicae, each its middle, the way it hangs, how long
  /// and how wide it is, and whether it hangs from the sigmoid colon.
  late final List<(Offset, Offset, double, double, bool)> appendices =
      <(Offset, Offset, double, double, bool)>[
        for (final (double s, double side, double long)
            in IntestineAnatomy.appendices)
          () {
            final int i = _rowAt(_colon, s);
            final Offset out = _colon.across[i] * side;
            final double reach = side > 0 ? _colonPlusAt(i) : _colonMinusAt(i);
            final Offset base = _colon.centres[i] + out * (reach * 0.86);
            return (
              place(base + out * (long * 0.42)),
              out,
              mm(long),
              mm(long * 0.62),
              i >= _sigmoidRow,
            );
          }(),
      ];

  /// The Peyer's patch's outline and its nodules.
  late final List<Offset> patch = _placed(_patchMm);
  late final List<Offset> nodules = _placed(_nodulesMm);

  /// The folds cut into the lining: the semilunar folds and the valve's
  /// lips and frenula, as the creases cut along them, tapering in from their
  /// ends; the valve's aperture, a slit; the appendix's orifice, its middle.
  late final Path folds = () {
    final Path path = Path();
    for (final List<Offset> line in <List<Offset>>[
      ..._semilunarMm,
      ..._valveMm,
    ]) {
      path.addPolygon(
        _placed(
          _tapered(line, IntestineStyle.fold / 2, IntestineStyle.foldTaper),
        ),
        true,
      );
    }
    return path;
  }();
  late final Path slit = Path()
    ..addPolygon(_placed(_tapered(_slitMm, IntestineStyle.slit / 2, 4)), true);
  late final Offset orifice = place(IntestineAnatomy.orifice);

  /// The grooves between the sacculi on the colon's outside, the sigmoid's
  /// and the rest's.
  late final Path sigmoidGrooves = _groovePath(true);
  late final Path grooves = _groovePath(false);

  Path _groovePath(bool sigmoid) {
    final Path path = Path();
    for (final (List<Offset> line, bool onSigmoid) in _groovesMm) {
      if (onSigmoid == sigmoid) {
        path.addPolygon(
          _placed(_tapered(line, IntestineStyle.fold / 2, 6)),
          true,
        );
      }
    }
    return path;
  }

  // Where the parts are named.

  /// Where the zoom's cell lives, named: the cecum's lining low in the
  /// window, the ileum's beside its patch, the valve between the two, or
  /// the free band above the window.
  late final Offset homeName = switch (home) {
    IntestineHome.colon => place(
      _colon.centres[_rowAt(_colon, IntestineAnatomy.cecumRound + 8)] +
          _colon.across[_rowAt(_colon, IntestineAnatomy.cecumRound + 8)] *
              (_colonPlusAt(_rowAt(_colon, IntestineAnatomy.cecumRound + 8)) *
                  0.35),
    ),
    IntestineHome.ileum => place(
      _ileum.centres[_rowAt(
        _ileum,
        _ileumLength - IntestineAnatomy.patchAt - 24,
      )],
    ),
    IntestineHome.both => place(
      Offset.lerp(IntestineAnatomy.valveFrom, IntestineAnatomy.valveTo, 0.5)!,
    ),
    IntestineHome.muscle => place(
      _colon.centres[_rowAt(_colon, IntestineAnatomy.windowTo + 30)],
    ),
  };

  /// The transverse and the descending colon, the jejunum, the ileum and
  /// the appendix, each at the nearest point of its middle line to where
  /// the anatomy names it.
  late final Offset transverseName = _nearestOn(
    _colon.centres.sublist(_windowRow, _sigmoidRow),
    IntestineAnatomy.transverseName,
  );
  late final Offset descendingName = _nearestOn(
    _colon.centres.sublist(_windowRow, _sigmoidRow),
    IntestineAnatomy.descendingName,
  );
  late final Offset jejunumName = _nearestOn(
    _coilsMm.first.centres,
    IntestineAnatomy.jejunumName,
  );
  late final Offset ileumName = _nearestOn(
    _coilsMm[5].centres,
    IntestineAnatomy.ileumName,
  );
  late final Offset appendixName = _nearestOn(
    _appendixMm.centres,
    IntestineAnatomy.appendixName,
  );

  Offset _nearestOn(List<Offset> line, Offset p) {
    Offset best = line.first;
    for (final Offset q in line) {
      if ((q - p).distanceSquared < (best - p).distanceSquared) {
        best = q;
      }
    }
    return place(best);
  }

  /// Where the step from the body meets the intestines' outline and the
  /// body's, besides their tops (the left colic flexure on the one and the
  /// highest of the body's coils on the other): the outermost point on the
  /// right, the lowest of the right half, the lowest (the appendix's tip on
  /// the one, the body's lowest coil, low on its right, on the other), and
  /// the outermost on the left, each picked out of either outline alike.
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.2, 0.8),
        _lowestRight,
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.2, 0.8),
      ];

  /// The lowest point of the outline's right half: the lowest coil in the
  /// pelvis on the intestines' own, the lowest of the body's coils there on
  /// the body's.
  static int _lowestRight(List<Offset> points) {
    double left = double.infinity;
    double right = double.negativeInfinity;
    for (final Offset p in points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
    }
    final double middle = (left + right) / 2;
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      if (points[i].dx > middle &&
          (best < 0 || points[i].dy > points[best].dy)) {
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
  /// other, for tests: the top, then the rest in the order of [_marks].
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topmost(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

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
      final double t = k / steps;
      final double t2 = t * t;
      final double t3 = t2 * t;
      out.add(
        (p1 * 2 +
                (p2 - p0) * t +
                (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
                (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
            0.5,
      );
    }
  }
  return out;
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
