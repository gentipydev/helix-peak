import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import '../../voronoi.dart';
import 'gallbladder_anatomy.dart';
import 'gallbladder_style.dart';

/// The figure's liver, named above the gallbladder where it lies in its
/// fossa.
const String _liver = 'UBERON_0002107';

/// The gallbladder as the zoom's organ scene draws it, laid open from the
/// front with its ducts: every part in the scene's units at its real size,
/// the middle of the body's outline of it at the origin.
///
/// The gallbladder is drawn from general anatomy ([GallbladderAnatomy]) and
/// laid on the body's outline of it so that the place it is gone into in
/// the anatomy ([GallbladderAnatomy.site]) lies on the place the body goes
/// in ([site]). The step from the body draws the body's outline in toward
/// the gallbladder's own ([pathAt]). Its mucosa is where the zoom's cell
/// lives, whatever the cell: the cholangiocyte is the one cell the Atlas
/// names with the gallbladder among its homes. Everything here is geometry:
/// what it is drawn in is `GallbladderArt`'s.
final class GallbladderForm {
  GallbladderForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.liverOutline,
  }) : scale = length / GallbladderAnatomy.length {
    final List<Offset> diagramDense = Contour(diagram).sampled(8).points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool reversed = _area(_outlineMm).sign != _area(diagramDense).sign;
    List<Offset> turned(List<Offset> mm) {
      final List<Offset> placed = _placed(mm);
      return reversed ? placed.reversed.toList() : placed;
    }

    outlinePoints = turned(_outlineMm);
    outline = Contour(outlinePoints).toPath();
    coats = <List<Offset>>[
      for (final List<Offset> edge in _coatsMm) turned(edge),
    ];
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: GallbladderStyle.morphPoints,
      bed: mm(GallbladderStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The gallbladder where the body draws it as [part] of [figure], in a
  /// view [view] metres across; the figure's liver round it.
  factory GallbladderForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    AnatomyFigure? figure,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    final AnatomyPart? liver = figure?.parts[_liver];
    List<Offset>? liverOutline;
    if (liver != null) {
      double most = 0;
      for (final List<Offset> c in liver.contours) {
        final double a = _area(c).abs();
        if (a > most) {
          most = a;
          liverOutline = <Offset>[for (final Offset p in c) placed(p)];
        }
      }
    }
    return GallbladderForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      liverOutline: liverOutline,
    );
  }

  /// Where the body goes into the gallbladder, in the scene: its back wall,
  /// in the body toward the fundus.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// The body's outline of the liver, in the scene; none where no figure is
  /// given.
  final List<Offset>? liverOutline;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The gallbladder's outline, the serosa where the cut crosses the wall,
  /// and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// The edges of the wall's coats, each a closed outline inside the one
  /// before: the serosa's inner edge, the perimuscular tissue's, the
  /// fibromuscular coat's, and the mucosa's surface, the wall's inner edge.
  late final List<List<Offset>> coats;

  /// The mucosa's surface, the wall's inner edge.
  List<Offset> get inner => coats[3];

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - GallbladderAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => GallbladderAnatomy.site + (p - site) / scale;

  /// How far the gallbladder's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the gallbladder's at 1, and [bed] of the way on toward the
  /// bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the gallbladder's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every gallbladder.

  /// The sac's middle line followed closely: its rows, the way across
  /// each, and how wide it is to either side.
  static final TubeCourse _spine = TubeCourse(
    const AnatomyTube(GallbladderAnatomy.spine, GallbladderAnatomy.half),
    (Offset p) => p,
    1,
    GallbladderStyle.outlineStep,
    bend: 0.9,
  );

  /// How thick the wall is at each of the spine's rows, from the anatomy's
  /// points between.
  static final List<double> _wallRows = () {
    final List<int> knots = _spine.knotRows;
    final List<double> out = <double>[];
    for (int i = 0; i < _spine.length; i++) {
      int k = 0;
      while (k + 1 < knots.length - 1 && knots[k + 1] <= i) {
        k++;
      }
      final int a = knots[k];
      final int b = knots[k + 1];
      final double t = b > a ? ((i - a) / (b - a)).clamp(0.0, 1.0) : 0;
      out.add(
        GallbladderAnatomy.wall[k] +
            (GallbladderAnatomy.wall[k + 1] - GallbladderAnatomy.wall[k]) * t,
      );
    }
    return out;
  }();

  /// How wide the sac is to either side at each of the spine's rows: the
  /// anatomy's widths at its points, eased between them (a cubic through
  /// them, level at the fundus), so its sides bend where they widen or
  /// narrow and never break; a bend's inner side drawn in as the spine's.
  static final List<double> _halfRows = () {
    final List<int> knots = _spine.knotRows;
    const List<double> h = GallbladderAnatomy.half;
    final int n = h.length;
    final List<double> a = <double>[for (final int k in knots) _spine.arc[k]];
    final List<double> slope = <double>[
      for (int k = 0; k < n; k++)
        k == 0
            ? 0
            : k == n - 1
            ? (h[k] - h[k - 1]) / (a[k] - a[k - 1])
            : (h[k + 1] - h[k - 1]) / (a[k + 1] - a[k - 1]),
    ];
    final List<double> out = <double>[];
    for (int i = 0; i < _spine.length; i++) {
      int k = 0;
      while (k + 1 < n - 1 && knots[k + 1] <= i) {
        k++;
      }
      final double span = a[k + 1] - a[k];
      final double t = span > 0
          ? ((_spine.arc[i] - a[k]) / span).clamp(0.0, 1.0)
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

  static double _plusAt(int i) => _spine.plus[i] < _spine.radius[i]
      ? math.min(_halfRows[i], _spine.plus[i])
      : _halfRows[i];
  static double _minusAt(int i) => _spine.minus[i] < _spine.radius[i]
      ? math.min(_halfRows[i], _spine.minus[i])
      : _halfRows[i];

  /// Which side of the spine's rows (1 its `plus` side, -1 its `minus`)
  /// is the under side, where Hartmann's pouch hangs: the one lower on the
  /// screen where the pouch is.
  static final double _under = () {
    final int i = _rowAt(GallbladderAnatomy.pouchAt);
    return _spine.across[i].dy > 0 ? 1.0 : -1.0;
  }();

  /// The row [arc] millimetres along the spine.
  static int _rowAt(double arc) {
    int best = 0;
    for (int i = 1; i < _spine.length; i++) {
      if ((_spine.arc[i] - arc).abs() < (_spine.arc[best] - arc).abs()) {
        best = i;
      }
    }
    return best;
  }

  /// How far the pouch pushes the under side out at row [i].
  static double _pouch(int i) {
    final double d =
        (_spine.arc[i] - GallbladderAnatomy.pouchAt) /
        GallbladderAnatomy.pouchLength;
    if (d.abs() >= 1) {
      return 0;
    }
    final double c = math.cos(d * math.pi / 2);
    return GallbladderAnatomy.pouchDepth * c * c;
  }

  /// The sac's outline drawn in by [inset] at each row of the spine (the
  /// rounded ends by theirs): its plus side from the fundus to the neck's
  /// end, round the neck's end, back down its minus side, and round the
  /// fundus.
  static List<Offset> _sac(double Function(int) inset) {
    final int n = _spine.length;
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    for (int i = 0; i < n; i++) {
      final double pouch = _pouch(i);
      final double inPlus = _plusAt(i) + (_under > 0 ? pouch : 0);
      final double inMinus = _minusAt(i) + (_under < 0 ? pouch : 0);
      plus.add(_spine.at(i, 0) + _spine.across[i] * (inPlus - inset(i)));
      minus.add(_spine.at(i, 0) - _spine.across[i] * (inMinus - inset(i)));
    }
    List<Offset> round(int row, Offset out) {
      final Offset across = _spine.across[row];
      final double r = _halfRows[row] - inset(row);
      // From the plus side round to the minus side, through [out].
      return <Offset>[
        for (int k = 1; k < 12; k++)
          _spine.centres[row] +
              (across * math.cos(math.pi * k / 12) +
                      out * math.sin(math.pi * k / 12)) *
                  r,
      ];
    }

    final Offset endWay = _unit(_spine.centres[n - 1] - _spine.centres[n - 2]);
    final Offset startWay = _unit(_spine.centres[0] - _spine.centres[1]);
    // Round the neck's end from plus to minus, round the fundus from minus
    // to plus: the second goes the other way about its across.
    final List<Offset> fundus = round(0, startWay).reversed.toList();
    return <Offset>[
      ...plus,
      ...round(n - 1, endWay),
      ...minus.reversed,
      ...fundus,
    ];
  }

  /// The outline, the serosa, in millimetres.
  static final List<Offset> _outlineMm = _sac((int i) => 0);

  /// How deep each coat's inner edge lies under the outline at row [i]:
  /// the serosa's, the perimuscular tissue's, the fibromuscular coat's, and
  /// the mucosa's surface.
  static double _depth(int coat, int i) {
    final double w = _wallRows[i];
    final double serosa = math.min(
      w * GallbladderAnatomy.serosaShare,
      GallbladderAnatomy.serosaMost,
    );
    final double perimuscular = math.min(
      w * GallbladderAnatomy.perimuscularShare,
      GallbladderAnatomy.perimuscularMost,
    );
    final double mucosa = math.min(
      w * GallbladderAnatomy.mucosaShare,
      GallbladderAnatomy.mucosaMost,
    );
    return switch (coat) {
      0 => serosa,
      1 => serosa + perimuscular,
      2 => w - mucosa,
      _ => w,
    };
  }

  /// The coats' inner edges, in millimetres.
  static final List<List<Offset>> _coatsMm = <List<Offset>>[
    for (int coat = 0; coat < 4; coat++) _sac((int i) => _depth(coat, i)),
  ];

  /// The mucosa's surface, the wall's inner edge, in millimetres.
  static List<Offset> get _innerMm => _coatsMm[3];

  /// Where the neck starts, and the way along the spine there: the plane
  /// the honeycomb runs up to.
  static final int _neckRow = _spine.knotRows[GallbladderAnatomy.neckFrom];
  static Offset get _neckAt => _spine.centres[_neckRow];
  static Offset get _neckWay => _unit(
    _spine.centres[math.min(_spine.length - 1, _neckRow + 1)] -
        _spine.centres[math.max(0, _neckRow - 1)],
  );

  /// How far past the neck's start [mm] lies, along the spine's way there:
  /// below zero in the fundus and the body.
  static double pastNeck(Offset mm) {
    final Offset d = mm - _neckAt;
    return d.dx * _neckWay.dx + d.dy * _neckWay.dy;
  }

  // The honeycomb.

  /// The honeycomb's folds, each a straight edge between two meshes, in
  /// millimetres: every edge of the meshes whose middles lie in the mucosa,
  /// or just outside it, where the cut clips them, up to the neck, where
  /// they give way, unevenly, to the oblique folds. Meshes are laid a
  /// little outside the mucosa too, so that those along its edge are
  /// bounded by neighbours and not by how far a mesh may reach.
  static final List<(Offset, Offset)> _meshEdgesMm = () {
    const double pitch = GallbladderAnatomy.mesh;
    final math.Random random = math.Random(GallbladderStyle.seed);
    final Rect bounds = _bounds(_innerMm).inflate(1.5 * pitch);
    final double rowHeight = pitch * math.sqrt(3) / 2;
    final List<Offset> seeds = <Offset>[];
    final List<bool> own = <bool>[];
    // The mucosa's edge followed more coarsely, which choosing the seeds
    // needs no closer: off it by under a tenth of a millimetre.
    final List<Offset> edge = <Offset>[
      for (int i = 0; i < _innerMm.length; i += 3) _innerMm[i],
    ];
    int row = 0;
    for (double y = bounds.top; y <= bounds.bottom; y += rowHeight, row++) {
      final double shift = row.isOdd ? pitch / 2 : 0;
      for (double x = bounds.left + shift; x <= bounds.right; x += pitch) {
        final Offset p =
            Offset(x, y) +
            Offset(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1) *
                (pitch * GallbladderAnatomy.meshJitter);
        if (_inside(edge, p)) {
          seeds.add(p);
          own.add(true);
          continue;
        }
        final double out = _toLine(edge, p, closed: true);
        if (out < 1.5 * pitch) {
          seeds.add(p);
          own.add(out < 0.5 * pitch);
        }
      }
    }
    const double reach = 1.3 * pitch;
    final List<Offset> even = relaxedSeeds(
      seeds,
      reach,
      times: GallbladderAnatomy.meshRelax,
    );
    final Map<(int, int, int, int), (Offset, Offset)> edges =
        <(int, int, int, int), (Offset, Offset)>{};
    int key(double v) => (v * 1000).round();
    final List<List<Offset>> cells = voronoiCells(even, reach);
    for (int c = 0; c < cells.length; c++) {
      if (!own[c]) {
        continue;
      }
      final List<Offset> cell = cells[c];
      for (int i = 0; i < cell.length; i++) {
        final Offset a = cell[i];
        final Offset b = cell[(i + 1) % cell.length];
        if ((b - a).distance < 0.05) {
          continue;
        }
        // Up to the neck, giving way over about a mesh, edge by edge.
        final Offset middle = Offset.lerp(a, b, 0.5)!;
        if (pastNeck(middle) > -_hash(middle) * 1.5 * pitch) {
          continue;
        }
        final (int, int) ka = (key(a.dx), key(a.dy));
        final (int, int) kb = (key(b.dx), key(b.dy));
        final (int, int, int, int) k =
            ka.$1 < kb.$1 || (ka.$1 == kb.$1 && ka.$2 <= kb.$2)
            ? (ka.$1, ka.$2, kb.$1, kb.$2)
            : (kb.$1, kb.$2, ka.$1, ka.$2);
        edges.putIfAbsent(k, () => (a, b));
      }
    }
    return edges.values.toList();
  }();

  /// A number from 0 to 1 that stays with a place: an edge's own, so that
  /// the honeycomb gives way to the neck unevenly and the same every time.
  static double _hash(Offset p) {
    final double h = math.sin(p.dx * 12.9898 + p.dy * 78.233) * 43758.5453;
    return h - h.floorToDouble();
  }

  /// The honeycomb's folds, in millimetres. For tests.
  static List<(Offset, Offset)> get meshEdgesMm => _meshEdgesMm;

  // The neck's and the cystic duct's oblique folds.

  /// The neck's oblique folds, each from the wall on one side, across most
  /// of the lumen, slanting along the way toward the duct; from either side
  /// in turn.
  static final List<List<Offset>> _neckFoldsMm = () {
    final int from = _neckRow;
    final int to = _spine.length - 1;
    final double a = _spine.arc[from];
    final double b = _spine.arc[to];
    return <List<Offset>>[
      for (int k = 0; k < GallbladderAnatomy.neckFolds.length; k++)
        () {
          final int i = _rowAt(a + (b - a) * GallbladderAnatomy.neckFolds[k]);
          final double side = k.isEven ? 1 : -1;
          final double lumenPlus = _plusAt(i) - _wallRows[i];
          final double lumenMinus = _minusAt(i) - _wallRows[i];
          final Offset way = _unit(
            _spine.centres[math.min(to, i + 1)] -
                _spine.centres[math.max(0, i - 1)],
          );
          return _fold(
            _spine.centres[i],
            _spine.across[i],
            way,
            side,
            lumenPlus,
            lumenMinus,
            GallbladderAnatomy.neckFoldReach,
            GallbladderAnatomy.neckFoldSlant,
          );
        }(),
    ];
  }();

  /// A fold across a lumen at [centre], [plus] and [minus] wide to either
  /// side along [across]: from the wall on [side], [reach] of the way
  /// across, slanting [slant] along [way] from its root to its tip, bowed a
  /// little toward the way it slants.
  static List<Offset> _fold(
    Offset centre,
    Offset across,
    Offset way,
    double side,
    double plus,
    double minus,
    double reach,
    double slant,
  ) {
    final double width = plus + minus;
    final Offset root = centre + across * (side > 0 ? plus : -minus) * 1.02;
    final Offset tip = root - across * (side * width * reach) + way * slant;
    final Offset middle = Offset.lerp(root, tip, 0.5)! + way * (slant * 0.25);
    return _smoothLine(<Offset>[root, middle, tip], GallbladderStyle.edgeStep);
  }

  /// The cystic duct's middle line followed closely, in millimetres: its
  /// rows, the way across each, and how wide it is to either side, its
  /// wall included.
  static final TubeCourse _ductMm = TubeCourse(
    AnatomyTube(GallbladderAnatomy.cysticDuct, <double>[
      for (final Offset _ in GallbladderAnatomy.cysticDuct)
        GallbladderAnatomy.cysticLumen + GallbladderAnatomy.cysticWall,
    ]),
    (Offset p) => p,
    1,
    GallbladderStyle.edgeStep,
    bend: 0.9,
  );

  /// The share of the cystic duct's half-width its lumen is.
  static const double _lumenShare =
      GallbladderAnatomy.cysticLumen /
      (GallbladderAnatomy.cysticLumen + GallbladderAnatomy.cysticWall);

  /// The cystic duct's crescentic folds, from either side in turn, evenly
  /// down it from its first stretch outside the neck.
  static final List<List<Offset>> _cysticFoldsMm = () {
    final TubeCourse d = _ductMm;
    final double total = d.arc[d.length - 1];
    const int count = GallbladderAnatomy.cysticFolds;
    return <List<Offset>>[
      for (int k = 0; k < count; k++)
        () {
          final double s = total * (0.16 + 0.76 * k / (count - 1));
          int i = 0;
          while (i + 1 < d.length && d.arc[i + 1] <= s) {
            i++;
          }
          final Offset way = _unit(
            d.centres[math.min(d.length - 1, i + 1)] -
                d.centres[math.max(0, i - 1)],
          );
          return _fold(
            d.centres[i],
            d.across[i],
            way,
            k.isEven ? 1 : -1,
            d.plus[i] * _lumenShare,
            d.minus[i] * _lumenShare,
            GallbladderAnatomy.cysticFoldReach,
            GallbladderAnatomy.cysticFoldSlant,
          );
        }(),
    ];
  }();

  /// The neck's and the cystic duct's folds, in millimetres. For tests.
  static List<List<Offset>> get neckFoldsMm => _neckFoldsMm;
  static List<List<Offset>> get cysticFoldsMm => _cysticFoldsMm;

  /// How far [mm] lies inside the mucosa's surface, from the wall's inner
  /// edge, in millimetres: below zero in the wall or outside it. For tests.
  static double clearOfWall(Offset mm) {
    final double d = _toLine(_innerMm, mm, closed: true);
    return _inside(_innerMm, mm) ? d : -d;
  }

  /// How thick the wall is at the spine's row nearest [mm], in
  /// millimetres. For tests.
  static double wallAt(Offset mm) {
    int best = 0;
    for (int i = 1; i < _spine.length; i++) {
      if ((_spine.centres[i] - mm).distanceSquared <
          (_spine.centres[best] - mm).distanceSquared) {
        best = i;
      }
    }
    return _wallRows[best];
  }

  /// The cystic duct's lumen, in millimetres, its two sides from its start
  /// to its end. For tests.
  static List<Offset> get cysticLumenMm => _stripOf(_ductMm, _lumenShare);

  /// The strip a laid-open tube makes, [share] of its half-width to either
  /// side: one side from its start, the other back.
  static List<Offset> _stripOf(TubeCourse tube, double share) => <Offset>[
    for (int i = 0; i < tube.length; i++) tube.at(i, share),
    for (int i = tube.length - 1; i >= 0; i--) tube.at(i, -share),
  ];

  // The parts, laid in the scene.

  /// The honeycomb's folds as one path of lines, the neck's and the cystic
  /// duct's folds as the creases cut along them, tapering in from their
  /// ends, and as their middle lines.
  late final Path meshes = () {
    final Path path = Path();
    for (final (Offset a, Offset b) in _meshEdgesMm) {
      final Offset p = place(a);
      final Offset q = place(b);
      path
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
    return path;
  }();
  late final Path neckCreases = _creases(_neckFoldsMm);
  late final Path cysticCreases = _creases(_cysticFoldsMm);
  late final List<List<Offset>> neckFolds = <List<Offset>>[
    for (final List<Offset> fold in _neckFoldsMm) _placed(fold),
  ];
  late final List<List<Offset>> cysticFolds = <List<Offset>>[
    for (final List<Offset> fold in _cysticFoldsMm) _placed(fold),
  ];

  Path _creases(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      path.addPolygon(
        _placed(
          _tapered(line, GallbladderStyle.fold / 2, GallbladderStyle.foldTaper),
        ),
        true,
      );
    }
    return path;
  }

  /// The cystic duct, laid open: its course in the scene, the strip of its
  /// cut wall, and the strip of its lumen inside it.
  late final TubeCourse cysticDuct = TubeCourse(
    AnatomyTube(GallbladderAnatomy.cysticDuct, <double>[
      for (final Offset _ in GallbladderAnatomy.cysticDuct)
        GallbladderAnatomy.cysticLumen + GallbladderAnatomy.cysticWall,
    ]),
    place,
    scale,
    mm(GallbladderStyle.edgeStep),
    bend: 0.9,
  );
  late final List<Offset> cysticWall = _stripOf(cysticDuct, 1);
  late final List<Offset> cysticLumen = _stripOf(cysticDuct, _lumenShare);

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(GallbladderStyle.edgeStep), bend: 0.9);

  /// The hepatic duct and the common bile duct, cut short below; and the
  /// cystic artery, cut short at the right hepatic artery.
  late final TubeCourse bileDuct = _tube(GallbladderAnatomy.bileDuct);
  late final TubeCourse cysticArtery = _tube(GallbladderAnatomy.cysticArtery);

  /// What runs on beside the gallbladder.
  late final List<TubeCourse> beside = <TubeCourse>[bileDuct, cysticArtery];

  // Where the parts are named.

  /// Its fundus and its neck; the cystic duct, the common bile duct and the
  /// cystic artery at the nearest point of their middle lines; and the
  /// figure's liver above it, where the figure draws one.
  late final Offset fundusName = place(GallbladderAnatomy.fundusName);
  late final Offset neckName = place(GallbladderAnatomy.neckName);
  late final Offset cysticName = _nearest(
    cysticDuct.centres,
    place(GallbladderAnatomy.cysticName),
  );
  late final Offset bileDuctName = _nearest(
    bileDuct.centres,
    place(GallbladderAnatomy.bileDuctName),
  );
  late final Offset arteryName = _nearest(
    cysticArtery.centres,
    place(GallbladderAnatomy.arteryName),
  );
  late final Offset? liverName = () {
    final List<Offset>? liver = liverOutline;
    final Offset at = place(GallbladderAnatomy.liverName);
    return liver != null && _inside(liver, at) ? at : null;
  }();

  static Offset _nearest(List<Offset> line, Offset p) {
    Offset best = line.first;
    for (final Offset q in line) {
      if ((q - p).distanceSquared < (best - p).distanceSquared) {
        best = q;
      }
    }
    return best;
  }

  /// Where the step from the body meets the gallbladder's outline and the
  /// body's: the middle of its top, which is nearly level on the body's
  /// outline, in place of the topmost point, which a hair's difference
  /// could move from one side of it to the other; the neck's end, the
  /// outermost point on the right; the lowest point; and the fundus's
  /// outermost point on the left: each picked out of either outline alike.
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
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.2, 0.8),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.2, 0.8),
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

  /// The points of the gallbladder's own outline where the step from the
  /// body meets the body's, for tests: the top's middle, then the rest in
  /// the order of [_marks].
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topMiddle(points)],
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
