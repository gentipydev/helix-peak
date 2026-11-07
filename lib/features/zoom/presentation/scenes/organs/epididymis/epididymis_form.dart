import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'epididymis_anatomy.dart';
import 'epididymis_style.dart';

/// Where in the epididymis the zoom's cell lives, which its drawing lights
/// in the mark, by the Atlas's name for the cell. By the kind of cell,
/// never by gene.
enum EpididymisHome {
  /// The epididymal duct, in the body and the tail: its principal, clear
  /// and basal cells, and every cell that has no part of the epididymis of
  /// its own to be drawn at its size.
  duct,

  /// The efferent ductules, coiled in the head's cones: their ciliated and
  /// absorptive cells.
  ductules;

  /// Where a cell the Atlas calls [cell] lives.
  static EpididymisHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('efferent duct')) {
      return ductules;
    }
    return duct;
  }

  /// What its name says.
  String get word => switch (this) {
    duct => 'epididymal duct',
    ductules => 'efferent ductules',
  };
}

/// One of the duct's profiles, where the cut crosses one of its coils: its
/// middle, how far it reaches along its length and across it, and the way
/// its length runs, in radians; in millimetres.
typedef DuctProfile = ({Offset at, double long, double short, double turn});

/// The epididymis as the zoom's organ scene draws it, cut down its length
/// on the back of its testis: every part in the scene's units at its real
/// size, the middle of the view at the origin.
///
/// The epididymis is drawn from general anatomy ([EpididymisAnatomy]) and
/// laid on the body's outline of it so that the place it is gone into in
/// the anatomy ([EpididymisAnatomy.site]) lies on the place the body goes
/// in ([site]). The step from the body draws the body's outline in toward
/// the epididymis's own ([pathAt]); the testis comes up beside it. Where
/// the zoom's cell lives is chosen by the Atlas's name for it ([home]).
/// Everything here is geometry: what it is drawn in is `EpididymisArt`'s.
final class EpididymisForm {
  EpididymisForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.home = EpididymisHome.duct,
  }) : scale = length / EpididymisAnatomy.length {
    outlinePoints = _placed(_outlineMm);
    outline = Path()..addPolygon(outlinePoints, true);
    box = _bounds(outlinePoints);
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(EpididymisStyle.outlineSpan)
        .points;
    _diagramBox = _bounds(diagramDense);
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template =
        _area(outlinePoints).sign != _area(diagramDense).sign
        ? outlinePoints.reversed.toList()
        : outlinePoints;
    _morph = OutlineMorph(
      template: template,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: EpididymisStyle.morphPoints,
      bed: mm(EpididymisStyle.bed),
      marks: _marks,
    );
  }

  /// The epididymis where the body draws it as [part], in a view [view]
  /// metres across, about a cell that lives in its [home].
  factory EpididymisForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    EpididymisHome home = EpididymisHome.duct,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return EpididymisForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the epididymis, in the scene: its duct, just
  /// below its head.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Where the zoom's cell lives.
  final EpididymisHome home;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The epididymis's outline where the cut crosses it, the points it is
  /// followed by, and its box.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - EpididymisAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => EpididymisAnatomy.site + (p - site) / scale;

  /// How far the epididymis lies from the body's outline it draws in from,
  /// in millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the epididymis's at 1, and [bed] of the way on toward the
  /// bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the epididymis's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every epididymis.

  /// The outline's own points, followed closely.
  static final List<Offset> _outlineMm = const Contour(
    EpididymisAnatomy.outline,
  ).sampled(EpididymisStyle.outlineSpan).points;

  /// The outline in millimetres. For tests.
  static List<Offset> get outlineMm => _outlineMm;

  /// The tunica's inner face, a line in from the outline all round.
  static final List<Offset> _tunicaMm = () {
    final int n = _outlineMm.length;
    final double inward = _area(_outlineMm) > 0 ? 1 : -1;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t = _unit(
            _outlineMm[(i + 1) % n] - _outlineMm[(i - 1 + n) % n],
          );
          return _outlineMm[i] +
              Offset(-t.dy, t.dx) * (inward * EpididymisAnatomy.tunica);
        }(),
    ];
  }();

  /// The tunica's inner face in millimetres. For tests.
  static List<Offset> get tunicaMm => _tunicaMm;

  /// Its front edge, over the testis, where the sinus lies.
  static final List<Offset> _frontMm = _outlineMm.sublist(
    EpididymisAnatomy.frontFrom * EpididymisStyle.outlineSpan,
    EpididymisAnatomy.frontTo * EpididymisStyle.outlineSpan + 1,
  );

  /// The way across the line where the head ends toward the head, a unit.
  static final Offset _towardHead = _unit(EpididymisAnatomy.towardHead);

  /// How far [mm] lies on the head's side of the line where it ends: less
  /// than nothing in the body and the tail.
  static double _headward(Offset mm) {
    final Offset d = mm - EpididymisAnatomy.headEnd;
    return d.dx * _towardHead.dx + d.dy * _towardHead.dy;
  }

  /// Whether [mm] lies in the head, and in the duct's part, the body and
  /// the tail.
  static bool inHead(Offset mm) => _inside(_outlineMm, mm) && _headward(mm) > 0;
  static bool inDuct(Offset mm) =>
      _inside(_outlineMm, mm) && _headward(mm) <= 0;

  /// The head and the duct's part, each cut out of the outline by the line
  /// where the head ends.
  static final List<Offset> _headMm = _clip(_outlineMm, _headward);
  static final List<Offset> _ductMm = _clip(
    _outlineMm,
    (Offset p) => -_headward(p),
  );

  /// The head and the duct's part in millimetres. For tests.
  static List<Offset> get headMm => _headMm;
  static List<Offset> get ductMm => _ductMm;

  // The cones.

  /// The head's underside, where it lies on the testis, and its top and
  /// back, each from where the head ends to its front end.
  static final (List<Offset>, List<Offset>) _headEdgesMm = () {
    final List<Offset> o = _outlineMm;
    final int n = o.length;
    const int tip = EpididymisAnatomy.frontEnd * EpididymisStyle.outlineSpan;
    List<Offset> walk(int step) {
      final List<Offset> out = <Offset>[o[tip]];
      int i = tip;
      while (true) {
        final int next = (i + step + n) % n;
        final double a = _headward(o[i]);
        final double b = _headward(o[next]);
        if (b <= 0) {
          out.add(o[i] + (o[next] - o[i]) * (a / (a - b)));
          break;
        }
        out.add(o[next]);
        i = next;
      }
      return out.reversed.toList();
    }

    return (walk(1), walk(-1));
  }();

  /// The line where the head ends, across the epididymis from its front
  /// edge to its back.
  static final (Offset, Offset) _headEndMm = (
    _headEdgesMm.$1.first,
    _headEdgesMm.$2.first,
  );

  /// The cones, each the head between two lines across it, from its
  /// underside to its top and back, the head shared out alike along both.
  static final List<List<Offset>> _conesMm = () {
    final (List<Offset> under, List<Offset> over) = _headEdgesMm;
    const int k = EpididymisAnatomy.cones;
    return <List<Offset>>[
      for (int i = 0; i < k; i++)
        <Offset>[
          ..._stretch(under, i / k, (i + 1) / k),
          ..._stretch(over, i / k, (i + 1) / k).reversed,
        ],
    ];
  }();

  /// Which cone [mm] lies in: -1 for none.
  static int coneOf(Offset mm) {
    for (int k = 0; k < _conesMm.length; k++) {
      if (_inside(_conesMm[k], mm)) {
        return k;
      }
    }
    return -1;
  }

  /// The septa between the cones, each from the underside to the top or
  /// the back, short of the tunica at either end.
  static final List<List<Offset>> _coneSeptaMm = () {
    final (List<Offset> under, List<Offset> over) = _headEdgesMm;
    const int k = EpididymisAnatomy.cones;
    return <List<Offset>>[
      for (int i = 1; i < k; i++)
        () {
          final Offset a = _pointAlong(under, i / k);
          final Offset b = _pointAlong(over, i / k);
          final Offset way = _unit(b - a);
          return <Offset>[
            a + way * EpididymisAnatomy.tunica,
            b - way * EpididymisAnatomy.tunica,
          ];
        }(),
    ];
  }();

  /// The ductule coiled in each cone: zigzagging across it along its middle
  /// from near the underside out to its base, swinging as wide as the cone
  /// allows there, pulled in wherever a swing would leave it.
  static final List<List<Offset>> _ductulesMm = () {
    final (List<Offset> under, List<Offset> over) = _headEdgesMm;
    const int k = EpididymisAnatomy.cones;
    return <List<Offset>>[
      for (int i = 0; i < k; i++)
        () {
          final Offset b0 = _pointAlong(under, i / k);
          final Offset b1 = _pointAlong(under, (i + 1) / k);
          final Offset o0 = _pointAlong(over, i / k);
          final Offset o1 = _pointAlong(over, (i + 1) / k);
          final Offset apex = (b0 + b1) / 2;
          final Offset base = (o0 + o1) / 2;
          final Offset way = _unit(base - apex);
          final Offset across = Offset(-way.dy, way.dx);
          final double length = (base - apex).distance;
          const double from = EpididymisAnatomy.hilum;
          final double to = length - EpididymisAnatomy.tunica;
          final List<Offset> out = <Offset>[];
          for (double s = from; s <= to; s += EpididymisStyle.edgeStep / 2) {
            final double t = s / length;
            final double half =
                ((b1 - b0).distance * (1 - t) + (o1 - o0).distance * t) / 2;
            final double swing =
                EpididymisAnatomy.coilSwing *
                half *
                _zigzag((s - from) / EpididymisAnatomy.coilWave);
            final Offset axis = apex + way * s;
            Offset p = axis + across * swing;
            for (int pull = 1; pull <= 4 && !_coneHolds(p, i); pull++) {
              p = axis + across * (swing * (1 - pull / 4));
            }
            if (_coneHolds(p, i)) {
              out.add(p);
            }
          }
          return out;
        }(),
    ];
  }();

  /// Whether [mm] lies in the [k]th cone, as far in from its sides, the
  /// tunica and the septa, as the tunica is thick.
  static bool _coneHolds(Offset mm, int k) =>
      _inside(_conesMm[k], mm) &&
      _toLine(_conesMm[k], mm) > EpididymisAnatomy.tunica;

  /// The cones, the septa between them and the ductules, in millimetres.
  /// For tests.
  static List<List<Offset>> get conesMm => _conesMm;
  static List<List<Offset>> get coneSeptaMm => _coneSeptaMm;
  static List<List<Offset>> get ductulesMm => _ductulesMm;

  // The duct.

  /// The septa across the duct, each wandering a little from its front
  /// edge to its back and on past both, to be drawn inside it.
  static final List<List<Offset>> _ductSeptaMm = () {
    final math.Random random = math.Random(EpididymisStyle.seed);
    return <List<Offset>>[
      for (final (Offset a, Offset b) in EpididymisAnatomy.septa)
        () {
          final Offset way = _unit(b - a);
          return _wandering(a - way * 0.8, b + way * 0.8, random, 0.15);
        }(),
    ];
  }();

  /// The septa across the duct in millimetres. For tests.
  static List<List<Offset>> get ductSeptaMm => _ductSeptaMm;

  /// The duct's profiles, laid by darts thrown over its part of the cut,
  /// each kept clear of the edges, of the septa, of where the head ends and
  /// of every other: each larger the further down the duct it lies.
  static final List<DuctProfile> _profilesMm = () {
    final math.Random random = math.Random(EpididymisStyle.seed + 1);
    final Rect area = _bounds(_ductMm);
    final double top = EpididymisAnatomy.headEnd.dy;
    final double bottom = area.bottom;
    const double cell = 1;
    final int columns = (area.width / cell).ceil() + 1;
    final int rows = (area.height / cell).ceil() + 1;
    final List<List<int>> grid = List<List<int>>.generate(
      columns * rows,
      (_) => <int>[],
    );
    final _Spans spans = _Spans(_ductMm, area, 0.05);
    final List<DuctProfile> out = <DuctProfile>[];
    final List<List<(Offset, double)>> discs = <List<(Offset, double)>>[];
    int cellOf(Offset p) =>
        ((p.dy - area.top) / cell).floor().clamp(0, rows - 1) * columns +
        ((p.dx - area.left) / cell).floor().clamp(0, columns - 1);
    for (int attempt = 0; attempt < 24000; attempt++) {
      final Offset p = Offset(
        area.left + random.nextDouble() * area.width,
        area.top + random.nextDouble() * area.height,
      );
      final double t = ((p.dy - top) / (bottom - top)).clamp(0.0, 1.0);
      final double r =
          EpididymisAnatomy.profileTop +
          (EpididymisAnatomy.profileTail - EpididymisAnatomy.profileTop) * t;
      final double stretch = random.nextDouble();
      final double long =
          r * (1 + (EpididymisAnatomy.profileLong - 1) * stretch * stretch);
      final double turn = random.nextDouble() * math.pi;
      const double clear = EpididymisAnatomy.profileClear;
      if (-_headward(p) < long + clear || !spans.holds(p)) {
        continue;
      }
      // As three discs along its length, to keep it clear of the others:
      // the cheaper test first, then the edges and the septa.
      final Offset along = Offset(math.cos(turn), math.sin(turn));
      final List<(Offset, double)> mine = <(Offset, double)>[
        (p, r),
        (p + along * (long - r), r),
        (p - along * (long - r), r),
      ];
      final int c = cellOf(p);
      final int ci = c % columns;
      final int cj = c ~/ columns;
      bool free = true;
      for (int dj = -2; dj <= 2 && free; dj++) {
        for (int di = -2; di <= 2 && free; di++) {
          final int i = ci + di;
          final int j = cj + dj;
          if (i < 0 || j < 0 || i >= columns || j >= rows) {
            continue;
          }
          for (final int other in grid[j * columns + i]) {
            // Far enough apart however each is turned.
            if ((out[other].at - p).distance >
                out[other].long + long + EpididymisAnatomy.profileGap) {
              continue;
            }
            for (final (Offset q, double rq) in discs[other]) {
              for (final (Offset m, double rm) in mine) {
                if ((q - m).distance < rq + rm + EpididymisAnatomy.profileGap) {
                  free = false;
                }
              }
            }
          }
        }
      }
      if (!free ||
          _toLine(_outlineMm, p) < long + EpididymisAnatomy.tunica + clear ||
          _ductSeptaMm.any(
            (List<Offset> septum) =>
                _toLine(septum, p, closed: false) < long + clear,
          )) {
        continue;
      }
      grid[c].add(out.length);
      discs.add(mine);
      out.add((at: p, long: long, short: r, turn: turn));
    }
    return out;
  }();

  /// The duct's profiles in millimetres. For tests.
  static List<DuctProfile> get profilesMm => _profilesMm;

  // The testis.

  /// The testis's outline: its ellipse, turned.
  static final List<Offset> _testisMm = () {
    const double tilt = EpididymisAnatomy.testisTilt * math.pi / 180;
    final double c = math.cos(tilt);
    final double s = math.sin(tilt);
    return <Offset>[
      for (int i = 0; i < 180; i++)
        () {
          final double a = i * 2 * math.pi / 180;
          final double x = EpididymisAnatomy.testisHalfDepth * math.cos(a);
          final double y = -EpididymisAnatomy.testisHalfLength * math.sin(a);
          return EpididymisAnatomy.testisCentre +
              Offset(x * c - y * s, x * s + y * c);
        }(),
    ];
  }();

  /// The testis's outline in millimetres. For tests.
  static List<Offset> get testisMm => _testisMm;

  // The parts, laid in the scene.

  /// The head and the duct's part of the cut, and the line where the head
  /// ends.
  late final List<Offset> head = _placed(_headMm);
  late final List<Offset> duct = _placed(_ductMm);
  late final (Offset, Offset) headEndLine = (
    place(_headEndMm.$1),
    place(_headEndMm.$2),
  );

  /// The tunica's inner face.
  late final List<Offset> tunica = _placed(_tunicaMm);

  /// The front edge, where the sinus lies along it.
  late final List<Offset> front = _placed(_frontMm);

  /// The septa between the cones, and the ductules coiled in them.
  late final List<List<Offset>> coneSepta = <List<Offset>>[
    for (final List<Offset> septum in _coneSeptaMm) _placed(septum),
  ];
  late final List<List<Offset>> ductules = <List<Offset>>[
    for (final List<Offset> ductule in _ductulesMm) _placed(ductule),
  ];

  /// The septa across the duct, and its profiles.
  late final List<List<Offset>> ductSepta = <List<Offset>>[
    for (final List<Offset> septum in _ductSeptaMm) _placed(septum),
  ];
  late final List<DuctProfile> profiles = <DuctProfile>[
    for (final DuctProfile p in _profilesMm)
      (at: place(p.at), long: mm(p.long), short: mm(p.short), turn: p.turn),
  ];

  /// The testis, whole, and the sac laid open round it all.
  late final List<Offset> testisPoints = _placed(_testisMm);
  late final Path testis = Path()..addPolygon(testisPoints, true);
  late final List<Offset> sacPoints = Contour(_placed(EpididymisAnatomy.sac))
      .sampled(EpididymisStyle.outlineSpan)
      .points;
  late final Path sac = Contour(_placed(EpididymisAnatomy.sac)).toPath();

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(EpididymisStyle.tubeRow), bend: 0.9);

  /// The vas deferens, the testicular artery and the veins of the
  /// pampiniform plexus.
  late final TubeCourse vas = _tube(EpididymisAnatomy.vas);
  late final TubeCourse artery = _tube(EpididymisAnatomy.artery);
  late final List<TubeCourse> veins = <TubeCourse>[
    for (final AnatomyTube vein in EpididymisAnatomy.veins) _tube(vein),
  ];

  /// What runs on beside it.
  late final List<TubeCourse> beside = <TubeCourse>[vas, artery, ...veins];

  // Where the parts are named.

  /// A point well inside the [k]th cone, along its middle.
  static Offset _inCone(int k) {
    final (List<Offset> under, List<Offset> over) = _headEdgesMm;
    const int n = EpididymisAnatomy.cones;
    final Offset apex =
        (_pointAlong(under, k / n) + _pointAlong(under, (k + 1) / n)) / 2;
    final Offset base =
        (_pointAlong(over, k / n) + _pointAlong(over, (k + 1) / n)) / 2;
    return Offset.lerp(apex, base, 0.55)!;
  }

  /// The cone nearest where the tissue is sampled, and the head's middle
  /// cone.
  static final Offset _nearCone = () {
    Offset best = _inCone(0);
    for (int k = 1; k < EpididymisAnatomy.cones; k++) {
      final Offset p = _inCone(k);
      if ((p - EpididymisAnatomy.site).distance <
          (best - EpididymisAnatomy.site).distance) {
        best = p;
      }
    }
    return best;
  }();
  static final Offset _middleCone = _inCone(EpididymisAnatomy.cones ~/ 2);

  /// Where the zoom's cell lives, named in the mark: the duct at the site,
  /// or the cone nearest it; and the other of the two, in the quiet ink.
  late final Offset homeName = switch (home) {
    EpididymisHome.duct => site,
    EpididymisHome.ductules => place(_nearCone),
  };
  late final Offset otherName = switch (home) {
    EpididymisHome.duct => place(_middleCone),
    EpididymisHome.ductules => place(EpididymisAnatomy.ductName),
  };

  /// The tail, the testis and the vas deferens.
  late final Offset tailName = place(EpididymisAnatomy.tailName);
  late final Offset testisName = place(EpididymisAnatomy.testisName);
  late final Offset vasName = place(EpididymisAnatomy.vasName);

  /// The outermost points of what is drawn at the height of [at], on
  /// either side: the epididymis, the testis and the tubes beside them,
  /// with room round the tubes; [at] alone where nothing is.
  (Offset, Offset) edgesAt(Offset at) {
    double left = double.infinity;
    double right = double.negativeInfinity;
    for (final List<Offset> shape in <List<Offset>>[
      outlinePoints,
      testisPoints,
    ]) {
      for (final double x in _crossings(shape, at.dy)) {
        left = math.min(left, x);
        right = math.max(right, x);
      }
    }
    final double clear = mm(EpididymisStyle.nameClear);
    for (final TubeCourse tube in beside) {
      for (int i = 0; i < tube.length; i++) {
        if (tube.shown[i] <= EpididymisStyle.nameShown) {
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

  static List<double> _crossings(List<Offset> points, double y) {
    final List<double> out = <double>[];
    final int n = points.length;
    for (int i = 0; i < n; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % n];
      if ((a.dy <= y) != (b.dy <= y)) {
        out.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
      }
    }
    return out;
  }

  // The step from the body.

  /// Where the step from the body meets the epididymis's outline and the
  /// body's, besides their tops: each side's outermost point down its
  /// middle, and the lowest, each picked out of either outline alike.
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.3, 0.7),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.3, 0.7),
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
  /// epididymis's and the body's, for tests: the top, then the rest in the
  /// order round it from there.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topmost(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

/// Where a polygon lies, row by row across its box: each row's stretches
/// inside it, for a quick test of whether a point does, to within a row.
final class _Spans {
  _Spans(List<Offset> polygon, Rect box, this.row)
    : _top = box.top,
      _rows = <List<double>>[
        for (double y = box.top + row / 2; y < box.bottom; y += row)
          () {
            final List<double> xs = <double>[];
            final int n = polygon.length;
            for (int i = 0; i < n; i++) {
              final Offset a = polygon[i];
              final Offset b = polygon[(i + 1) % n];
              if ((a.dy <= y) != (b.dy <= y)) {
                xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
              }
            }
            return xs..sort();
          }(),
      ];

  final double row;
  final double _top;
  final List<List<double>> _rows;

  bool holds(Offset p) {
    final int j = ((p.dy - _top) / row).floor();
    if (j < 0 || j >= _rows.length) {
      return false;
    }
    final List<double> xs = _rows[j];
    for (int k = 0; k + 1 < xs.length; k += 2) {
      if (p.dx >= xs[k] && p.dx <= xs[k + 1]) {
        return true;
      }
    }
    return false;
  }
}

/// [polygon] cut down to where [side] is above nothing, by the straight
/// line [side] is measured from.
List<Offset> _clip(List<Offset> polygon, double Function(Offset) side) {
  final List<Offset> out = <Offset>[];
  final int n = polygon.length;
  for (int i = 0; i < n; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % n];
    final double sa = side(a);
    final double sb = side(b);
    if (sa > 0) {
      out.add(a);
    }
    if ((sa > 0) != (sb > 0)) {
      out.add(a + (b - a) * (sa / (sa - sb)));
    }
  }
  return out;
}

/// The point [f] of the way along [line], by its length.
Offset _pointAlong(List<Offset> line, double f) {
  final List<double> along = _alongOf(line);
  final double at = along.last * f.clamp(0.0, 1.0);
  for (int i = 1; i < line.length; i++) {
    if (along[i] >= at) {
      final double span = along[i] - along[i - 1];
      return span <= 0
          ? line[i]
          : Offset.lerp(line[i - 1], line[i], (at - along[i - 1]) / span)!;
    }
  }
  return line.last;
}

/// [line] from [f0] to [f1] of the way along it, its ends where those
/// fall.
List<Offset> _stretch(List<Offset> line, double f0, double f1) {
  final List<double> along = _alongOf(line);
  final double a = along.last * f0;
  final double b = along.last * f1;
  return <Offset>[
    _pointAlong(line, f0),
    for (int i = 0; i < line.length; i++)
      if (along[i] > a && along[i] < b) line[i],
    _pointAlong(line, f1),
  ];
}

/// How far along [line] each of its points lies.
List<double> _alongOf(List<Offset> line) {
  final List<double> out = <double>[0];
  for (int i = 1; i < line.length; i++) {
    out.add(out.last + (line[i] - line[i - 1]).distance);
  }
  return out;
}

/// A zigzag of period one, from -1 to 1, rounded a little at its turns.
double _zigzag(double t) {
  final double u = t - t.floorToDouble();
  final double tri = u < 0.5 ? 4 * u - 1 : 3 - 4 * u;
  return math.sin(tri * math.pi / 2);
}

/// A line from [from] to [to] in points [EpididymisStyle.edgeStep] apart,
/// wandering to either side by up to [wander], laid by [random].
List<Offset> _wandering(
  Offset from,
  Offset to,
  math.Random random,
  double wander,
) {
  final Offset way = to - from;
  final double length = way.distance;
  if (length <= 0) {
    return <Offset>[from, to];
  }
  final Offset along = way / length;
  final Offset across = Offset(-along.dy, along.dx);
  final double phase = random.nextDouble() * 2 * math.pi;
  final double wave = 2 + 2 * random.nextDouble();
  final int steps = math.max(2, (length / EpididymisStyle.edgeStep).ceil());
  return <Offset>[
    for (int i = 0; i <= steps; i++)
      () {
        final double s = length * i / steps;
        return from +
            along * s +
            across * (wander * math.sin(s / wave * 2 * math.pi + phase));
      }(),
  ];
}

Offset _unit(Offset p) {
  final double length = p.distance;
  return length <= 0 ? Offset.zero : p / length;
}

/// How far [p] lies from the line through [points], [closed] or open.
double _toLine(List<Offset> points, Offset p, {bool closed = true}) {
  double least = double.infinity;
  final int n = points.length;
  for (int i = 0; i < (closed ? n : n - 1); i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final Offset ab = b - a;
    final double length = ab.distanceSquared;
    final double t = length <= 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    least = math.min(least, (p - (a + ab * t)).distanceSquared);
  }
  return math.sqrt(least);
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
