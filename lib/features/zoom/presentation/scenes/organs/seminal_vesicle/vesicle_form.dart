import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import '../../voronoi.dart';
import '../prostate/prostate_anatomy.dart';
import 'vesicle_anatomy.dart';
import 'vesicle_style.dart';

/// The seminal vesicles as the zoom's organ scene draws them, seen from the
/// front with the bladder taken away, the one on the body's left laid
/// open: every part in the scene's units at its real size, the midline
/// level with the body's outline of the vesicle at the origin.
///
/// They are drawn from general anatomy ([SeminalVesicleAnatomy]) and laid
/// on the body's outline of the vesicle on its left so that the place it
/// is gone into in the anatomy ([SeminalVesicleAnatomy.site]) lies on the
/// place the body goes in ([site]). The step from the body draws the body's
/// outline in toward the opened vesicle's own ([pathAt]). Its mucosa is
/// where the zoom's cell lives, whatever the cell: no cell the Atlas names
/// has the seminal vesicle as its home. Everything here is geometry: what
/// it is drawn in is `SeminalVesicleArt`'s.
final class SeminalVesicleForm {
  SeminalVesicleForm({
    required this.diagramPoints,
    required this.site,
    required double width,
    required this.view,
  }) : scale = width / SeminalVesicleAnatomy.length {
    final List<Offset> diagramDense = Contour(diagramPoints).sampled(8).points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool reversed =
        _area(_openedOutlineMm).sign != _area(diagramDense).sign;
    final List<Offset> placed = _placed(_openedOutlineMm);
    outlinePoints = reversed ? placed.reversed.toList() : placed;
    outline = Path()..addPolygon(outlinePoints, true);
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagramPoints).toPath(),
      count: SeminalVesicleStyle.morphPoints,
      bed: mm(SeminalVesicleStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The vesicles where the body draws the one on its left as [part], in a
  /// view [view] metres across.
  factory SeminalVesicleForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return SeminalVesicleForm(
      diagramPoints: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      width: anatomy.metres / view,
      view: view,
    );
  }

  /// Where the body goes into the vesicle, in the scene: the opened
  /// vesicle's mucosa.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// The body's outline of the vesicle in the scene: the shape the step
  /// from the body hands over.
  final List<Offset> diagramPoints;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The opened vesicle's outline, its cut wall's outer edge, and the
  /// points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - SeminalVesicleAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => SeminalVesicleAnatomy.site + (p - site) / scale;

  /// How far the opened vesicle's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the opened vesicle's at 1, and [bed] of the way on toward
  /// the bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the opened vesicle's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every vesicle.

  static Offset _mirror(Offset p) => Offset(-p.dx, p.dy);

  /// The spine of the vesicle on the body's left, followed closely, and
  /// how far along it each of its points lies.
  static final List<Offset> _spineMm = _smoothLine(
    SeminalVesicleAnatomy.spine,
    SeminalVesicleStyle.spineStep,
  );
  static final List<double> _spineArc = _along(_spineMm);

  /// How far along the spine, as [_spineArc] measures it, each knot of the
  /// anatomy lies: the knots' own distances, scaled to the followed
  /// spine's length.
  static final List<double> _knotArcs = () {
    final List<double> knots = _along(SeminalVesicleAnatomy.spine);
    final double total = _spineArc.last / knots.last;
    return <double>[for (final double a in knots) a * total];
  }();

  /// The sac's half-width [a] along its spine, eased from knot to knot so
  /// its edges have no kinks.
  static double halfAt(double a) {
    final List<double> knots = _knotArcs;
    const List<double> halves = SeminalVesicleAnatomy.halfWidths;
    if (a <= knots.first) {
      return halves.first;
    }
    for (int j = 1; j < knots.length; j++) {
      if (a <= knots[j]) {
        final double t = _smooth(
          (a - knots[j - 1]) / (knots[j] - knots[j - 1]),
        );
        return halves[j - 1] + (halves[j] - halves[j - 1]) * t;
      }
    }
    return halves.last;
  }

  /// How much the coils swell the sac [a] along its spine, a factor of its
  /// half-width: none along the duct, the swellings coming up past it.
  static double coilAt(double a) =>
      1 +
      SeminalVesicleAnatomy.coilDepth *
          _smooth((a - SeminalVesicleAnatomy.sacFrom) / 3) *
          math.sin(2 * math.pi * a / SeminalVesicleAnatomy.coil);

  /// A vesicle as a tube of the anatomy, on the body's left or, mirrored,
  /// its right: its spine's points, each with its half-width there, the
  /// coils' swellings on it.
  static AnatomyTube _sacTube({required bool mirrored}) => AnatomyTube(
    <Offset>[for (final Offset p in _spineMm) mirrored ? _mirror(p) : p],
    <double>[for (final double a in _spineArc) halfAt(a) * coilAt(a)],
  );

  static TubeCourse _courseMm(AnatomyTube tube) => TubeCourse(
    tube,
    (Offset p) => p,
    1,
    SeminalVesicleStyle.tubeRow,
    bend: 0.9,
  );

  /// The two vesicles, as tubes in millimetres: the body's left, laid open,
  /// and its right, whole.
  static final TubeCourse _leftMm = _courseMm(_sacTube(mirrored: false));
  static final TubeCourse _rightMm = _courseMm(_sacTube(mirrored: true));

  /// The row of a vesicle's tube where its sac begins, past its duct.
  static final int _sacRow = _rowAt(_leftMm, SeminalVesicleAnatomy.sacFrom);

  static int _rowAt(TubeCourse t, double arc) {
    int i = 0;
    while (i + 1 < t.length && t.arc[i + 1] <= arc) {
      i++;
    }
    return i;
  }

  /// The outline of [t]'s rows [from] to [to], [inset] in from its sides:
  /// up one side, round its far end, and back down the other, the ends
  /// rounded where [capped] or cut straight across where not, and then
  /// drawn in by [inset] along the tube too, so that a lining lies inside
  /// its wall at the ends as well.
  static List<Offset> _outlineOf(
    TubeCourse t, {
    double inset = 0,
    int from = 0,
    int? to,
    bool capped = true,
  }) {
    int first = from;
    int last = to ?? t.length - 1;
    if (!capped && inset > 0) {
      while (first < last && t.arc[first] - t.arc[from] < inset) {
        first++;
      }
      while (last > first && t.arc[to ?? t.length - 1] - t.arc[last] < inset) {
        last--;
      }
    }
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    for (int i = first; i <= last; i++) {
      plus.add(t.centres[i] + t.across[i] * (t.plus[i] - inset));
      minus.add(t.centres[i] - t.across[i] * (t.minus[i] - inset));
    }
    List<Offset> cap(int i, double sign) {
      final Offset c = t.centres[i];
      final Offset across = t.across[i];
      final Offset forward =
          _unit(
            t.centres[math.min(t.length - 1, i + 1)] -
                t.centres[math.max(0, i - 1)],
          ) *
          sign;
      final double r = math.max(0, t.radius[i] - inset);
      return <Offset>[
        for (int k = 1; k < 12; k++)
          () {
            final double th = math.pi * k / 12;
            return c +
                (across * (sign * math.cos(th)) + forward * math.sin(th)) * r;
          }(),
      ];
    }

    return <Offset>[
      ...plus,
      if (capped) ...cap(last, 1),
      ...minus.reversed,
      if (capped) ...cap(first, -1),
    ];
  }

  /// The opened vesicle's outline, in millimetres: the whole of it, its
  /// duct included.
  static final List<Offset> _openedOutlineMm = _outlineOf(_leftMm);

  /// Its sac alone, past its duct, whose front wall is taken away: the cut
  /// wall's outer edge.
  static final List<Offset> _openedSacMm = _outlineOf(_leftMm, from: _sacRow);

  /// Its lumen, where its front wall is taken away: the sac inside its
  /// wall, from where the sac begins to its tip.
  static final List<Offset> _lumenMm = _outlineOf(
    _leftMm,
    inset: SeminalVesicleAnatomy.wall,
    from: _sacRow,
  );

  /// Whether [mm] lies in the opened vesicle's lumen, and how far in from
  /// its wall; below zero outside.
  static bool inLumen(Offset mm) => _inside(_lumenMm, mm);
  static double lumenDepth(Offset mm) {
    final double edge = _toLine(_lumenMm, mm, closed: true);
    return _inside(_lumenMm, mm) ? edge : -edge;
  }

  /// A fold across a lumen at row [i] of [t], whose wall is [wall] thick:
  /// from the wall on [side], [reach] of the way across, slanting [slant]
  /// along the tube toward its start, bowed a little the way it slants.
  static List<Offset> _foldAt(
    TubeCourse t,
    int i,
    double side,
    double wall,
    double reach,
    double slant,
  ) {
    final Offset c = t.centres[i];
    final Offset across = t.across[i];
    final Offset back = _unit(
      t.centres[math.max(0, i - 1)] - t.centres[math.min(t.length - 1, i + 1)],
    );
    final double plus = t.plus[i] - wall;
    final double minus = t.minus[i] - wall;
    final double width = plus + minus;
    final Offset root = c + across * (side > 0 ? plus : -minus) * 1.02;
    final Offset tip = root - across * (side * width * reach) + back * slant;
    final Offset middle = Offset.lerp(root, tip, 0.5)! + back * (slant * 0.25);
    return _smoothLine(<Offset>[
      root,
      middle,
      tip,
    ], SeminalVesicleStyle.edgeStep);
  }

  /// The septa between the opened vesicle's coils, from either side in
  /// turn, in millimetres.
  static final List<List<Offset>> _septaMm = <List<Offset>>[
    for (int k = 0; k < SeminalVesicleAnatomy.septa.length; k++)
      _foldAt(
        _leftMm,
        _rowAt(_leftMm, SeminalVesicleAnatomy.septa[k]),
        k.isEven ? 1 : -1,
        SeminalVesicleAnatomy.wall,
        SeminalVesicleAnatomy.septumReach,
        SeminalVesicleAnatomy.septumSlant,
      ),
  ];

  /// The diverticula's pits in the opened vesicle's lateral wall, each
  /// its middle and its radius, in millimetres.
  static final List<(Offset, double)> _pitsMm = <(Offset, double)>[
    for (final (double a, double share, double width)
        in SeminalVesicleAnatomy.pits)
      () {
        final int i = _rowAt(_leftMm, a);
        final double u = 2 * share - 1;
        final double half = u >= 0
            ? _leftMm.plus[i] - SeminalVesicleAnatomy.wall
            : _leftMm.minus[i] - SeminalVesicleAnatomy.wall;
        return (_leftMm.centres[i] + _leftMm.across[i] * (half * u), width / 2);
      }(),
  ];

  /// The mucosa's honeycomb, each fold a straight edge between two meshes,
  /// in millimetres: every edge of the meshes whose middles lie in the
  /// lumen or just outside it, where the cut clips them. Meshes are laid a
  /// little outside the lumen too, so that those along its edge are
  /// bounded by neighbours and not by how far a mesh may reach.
  static final List<(Offset, Offset)> _meshEdgesMm = () {
    const double pitch = SeminalVesicleAnatomy.mesh;
    final math.Random random = math.Random(SeminalVesicleStyle.seed);
    final Rect bounds = _bounds(_lumenMm).inflate(1.5 * pitch);
    final double rowHeight = pitch * math.sqrt(3) / 2;
    final List<Offset> seeds = <Offset>[];
    final List<bool> own = <bool>[];
    int row = 0;
    for (double y = bounds.top; y <= bounds.bottom; y += rowHeight, row++) {
      final double shift = row.isOdd ? pitch / 2 : 0;
      for (double x = bounds.left + shift; x <= bounds.right; x += pitch) {
        final Offset p =
            Offset(x, y) +
            Offset(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1) *
                (pitch * SeminalVesicleAnatomy.meshJitter);
        if (_inside(_lumenMm, p)) {
          seeds.add(p);
          own.add(true);
          continue;
        }
        final double out = _toLine(_lumenMm, p, closed: true);
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
      times: SeminalVesicleAnatomy.meshRelax,
    );
    // Evened out, a mesh at the field's edge may have drifted out from the
    // lumen: which meshes are the mucosa's own is read where they lie now.
    for (int i = 0; i < even.length; i++) {
      own[i] =
          _inside(_lumenMm, even[i]) ||
          _toLine(_lumenMm, even[i], closed: true) < 0.5 * pitch;
    }
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

  /// Where the whole vesicle's coils meet, along it, between its
  /// swellings, in millimetres along its spine.
  static final List<double> _coilsAtMm = () {
    final double total = _rightMm.arc[_rightMm.length - 1];
    return <double>[
      for (
        double a =
            SeminalVesicleAnatomy.sacFrom + SeminalVesicleAnatomy.coil * 0.75;
        a < total - 2;
        a += SeminalVesicleAnatomy.coil
      )
        a,
    ];
  }();

  /// The deferent duct on the body's left, followed closely, its ampulla
  /// swinging to either side along its tortuous stretch, fading in above
  /// (the right's is its mirror).
  static final AnatomyTube _deferensTube = () {
    const AnatomyTube d = SeminalVesicleAnatomy.deferens;
    final List<Offset> line = _smoothLine(d.points, 0.4);
    final List<double> along = _along(line);
    final List<double> knots = _along(d.points);
    final List<Offset> swung = <Offset>[];
    final List<double> radii = <double>[];
    for (int i = 0; i < line.length; i++) {
      final Offset t =
          line[math.min(line.length - 1, i + 1)] - line[math.max(0, i - 1)];
      final Offset across = Offset(-t.dy, t.dx) / t.distance;
      final double a = along[i];
      // Tortuous along the ampulla alone, easing in and out of it.
      final double tortuous =
          _smooth((a - SeminalVesicleAnatomy.ampullaFrom) / 4) *
          _smooth((SeminalVesicleAnatomy.ampullaTo - a) / 4);
      swung.add(
        line[i] +
            across *
                (SeminalVesicleAnatomy.ampullaSwing *
                    tortuous *
                    math.sin(
                      2 * math.pi * a / SeminalVesicleAnatomy.ampullaTurn,
                    )),
      );
      final double share = a / along.last * knots.last;
      int j = 1;
      while (j < knots.length - 1 && knots[j] < share) {
        j++;
      }
      final double s = _smooth(
        ((share - knots[j - 1]) / (knots[j] - knots[j - 1])).clamp(0.0, 1.0),
      );
      // Sacculated along the ampulla, a swelling a fold.
      final double swell =
          1 +
          SeminalVesicleAnatomy.ampullaSwell *
              tortuous *
              math.sin(2 * math.pi * a / SeminalVesicleAnatomy.ampullaFold);
      radii.add((d.radii[j - 1] + (d.radii[j] - d.radii[j - 1]) * s) * swell);
    }
    return AnatomyTube(swung, radii, fadeIn: d.fadeIn);
  }();

  static AnatomyTube _mirrored(AnatomyTube t) => AnatomyTube(
    <Offset>[for (final Offset p in t.points) _mirror(p)],
    t.radii,
    fadeIn: t.fadeIn,
    fadeOut: t.fadeOut,
    cutStart: t.cutStart,
    cutEnd: t.cutEnd,
  );

  /// The deferent duct on the body's left, in millimetres: the opened
  /// ampulla's rows are read off it.
  static final TubeCourse _leftDeferensMm = _courseMm(_deferensTube);

  /// The rows the ampulla on the body's left is laid open between.
  static final int _openedFromRow = _rowAt(
    _leftDeferensMm,
    SeminalVesicleAnatomy.openedFrom,
  );
  static final int _openedToRow = _rowAt(
    _leftDeferensMm,
    SeminalVesicleAnatomy.openedTo,
  );

  /// The opened ampulla: its cut wall's outer edge and its lining inside
  /// the wall, each cut straight across at its ends, in millimetres.
  static final List<Offset> _openedAmpullaMm = _outlineOf(
    _leftDeferensMm,
    from: _openedFromRow,
    to: _openedToRow,
    capped: false,
  );
  static final List<Offset> _ampullaLiningMm = _outlineOf(
    _leftDeferensMm,
    inset: SeminalVesicleAnatomy.ampullaWall,
    from: _openedFromRow,
    to: _openedToRow,
    capped: false,
  );

  /// The opened ampulla's cross folds, from either side in turn, in
  /// millimetres.
  static final List<List<Offset>> _ampullaFoldsMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    int k = 0;
    for (
      double a =
          SeminalVesicleAnatomy.openedFrom +
          SeminalVesicleAnatomy.ampullaFold / 2;
      a < SeminalVesicleAnatomy.openedTo - 1;
      a += SeminalVesicleAnatomy.ampullaFold, k++
    ) {
      out.add(
        _foldAt(
          _leftDeferensMm,
          _rowAt(_leftDeferensMm, a),
          k.isEven ? 1 : -1,
          SeminalVesicleAnatomy.ampullaWall,
          SeminalVesicleAnatomy.ampullaFoldReach,
          0.4,
        ),
      );
    }
    return out;
  }();

  /// The prostate's outline below the vesicles, the prostate specimen's,
  /// laid with the top of its base at the origin, followed closely, in
  /// millimetres.
  static final List<Offset> _prostateMm = _closedCurve(<Offset>[
    for (final Offset p in ProstateAnatomy.outline)
      p + const Offset(0, SeminalVesicleAnatomy.prostateDown),
  ], 0.3);

  /// How much of the prostate shows at [mm]: all of its base, none below
  /// where it fades out.
  static double prostateShownAt(Offset mm) =>
      1 -
      _smooth(
        (mm.dy - SeminalVesicleAnatomy.prostateWhole) /
            (SeminalVesicleAnatomy.prostateGone -
                SeminalVesicleAnatomy.prostateWhole),
      );

  /// Whether [mm] lies inside the prostate's outline.
  static bool inProstate(Offset mm) => _inside(_prostateMm, mm);

  // The parts, laid in the scene.

  TubeCourse _tube(AnatomyTube tube) => TubeCourse(
    tube,
    place,
    scale,
    mm(SeminalVesicleStyle.tubeRow),
    bend: 0.9,
  );

  /// The vesicles as tubes in the scene: the body's left, whose duct alone
  /// is drawn as a tube, the sac being laid open; and its right, whole.
  late final TubeCourse left = _tube(_sacTube(mirrored: false));
  late final TubeCourse right = _tube(_sacTube(mirrored: true));

  /// The row of a vesicle's tube where its sac begins, past its duct.
  int get sacRow => _sacRow;

  /// Where the whole vesicle's coils meet, along it, in the scene.
  late final List<double> coilsAt = <double>[
    for (final double a in _coilsAtMm) mm(a),
  ];

  /// The opened vesicle's sac, its cut wall's outer edge past its duct;
  /// its lumen, its septa, its pits and its honeycomb.
  late final List<Offset> openedSac = _placed(_openedSacMm);
  late final List<Offset> lumen = _placed(_lumenMm);
  late final List<List<Offset>> septa = <List<Offset>>[
    for (final List<Offset> s in _septaMm) _placed(s),
  ];
  late final List<(Offset, double)> pits = <(Offset, double)>[
    for (final (Offset p, double r) in _pitsMm) (place(p), mm(r)),
  ];
  late final List<(Offset, Offset)> meshEdges = <(Offset, Offset)>[
    for (final (Offset a, Offset b) in _meshEdgesMm) (place(a), place(b)),
  ];

  /// The deferent ducts, the body's left then its right; the left's
  /// ampulla laid open: its cut wall's outer edge, its lining, its folds.
  late final List<TubeCourse> deferens = <TubeCourse>[
    _tube(_deferensTube),
    _tube(_mirrored(_deferensTube)),
  ];
  late final List<Offset> openedAmpulla = _placed(_openedAmpullaMm);
  late final List<Offset> ampullaLining = _placed(_ampullaLiningMm);
  late final List<List<Offset>> ampullaFolds = <List<Offset>>[
    for (final List<Offset> f in _ampullaFoldsMm) _placed(f),
  ];

  /// The rows the ampulla on the body's left is laid open between.
  int get openedFromRow => _openedFromRow;
  int get openedToRow => _openedToRow;

  /// The ejaculatory ducts, the body's left then its right.
  late final List<TubeCourse> ejaculatory = <TubeCourse>[
    _tube(SeminalVesicleAnatomy.ejaculatory),
    _tube(_mirrored(SeminalVesicleAnatomy.ejaculatory)),
  ];

  /// The arteries to the vesicles, the body's left then its right.
  late final List<TubeCourse> arteries = <TubeCourse>[
    _tube(SeminalVesicleAnatomy.artery),
    _tube(_mirrored(SeminalVesicleAnatomy.artery)),
  ];

  /// The prostate's outline below, and how much of it shows at a point of
  /// the scene.
  late final List<Offset> prostate = _placed(_prostateMm);
  double prostateShown(Offset p) => prostateShownAt(toMm(p));

  /// What is drawn outside the opened vesicle, for its names to keep clear
  /// of.
  late final List<TubeCourse> beside = <TubeCourse>[
    right,
    ...deferens,
    ...ejaculatory,
    ...arteries,
  ];

  // Where the parts are named.

  /// The mucosa at the site; the whole vesicle, its ampulla and its
  /// deferent duct on the body's right; the ejaculatory duct on its left;
  /// the prostate below.
  Offset get homeName => site;
  late final Offset vesicleName = place(SeminalVesicleAnatomy.vesicleName);
  late final Offset ampullaName = place(SeminalVesicleAnatomy.ampullaName);
  late final Offset deferensName = place(SeminalVesicleAnatomy.deferensName);
  late final Offset ejaculatoryName = place(
    SeminalVesicleAnatomy.ejaculatoryName,
  );
  late final Offset prostateName = place(SeminalVesicleAnatomy.prostateName);

  /// Where the step from the body meets the opened vesicle's outline and
  /// the body's, besides the point nearest the middle of their tops:
  /// either side and the lowest point, each picked out of either outline
  /// alike.
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

  /// The point of [points] nearest the middle of their box's top, among
  /// those on its upper half: where the step meets the two outlines first.
  static int _topMiddle(List<Offset> points) {
    final Rect box = _bounds(points);
    final Offset at = Offset(box.center.dx, box.top);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      if (points[i].dy > box.center.dy) {
        continue;
      }
      if (best < 0 ||
          (points[i] - at).distanceSquared <
              (points[best] - at).distanceSquared) {
        best = i;
      }
    }
    return best;
  }

  /// The points of an outline where the step from the body meets the
  /// body's, for tests: the top's nearest point, then the rest in the
  /// order of [_marks].
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topMiddle(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];

  /// For tests: the anatomy in millimetres.
  static List<Offset> get spineMm => _spineMm;
  static List<Offset> get openedOutlineMm => _openedOutlineMm;
  static List<Offset> get openedSacMm => _openedSacMm;
  static List<Offset> get lumenMm => _lumenMm;
  static List<List<Offset>> get septaMm => _septaMm;
  static List<(Offset, double)> get pitsMm => _pitsMm;
  static List<(Offset, Offset)> get meshEdgesMm => _meshEdgesMm;
  static TubeCourse get leftMm => _leftMm;
  static TubeCourse get rightMm => _rightMm;
  static TubeCourse get leftDeferensMm => _leftDeferensMm;
  static List<Offset> get openedAmpullaMm => _openedAmpullaMm;
  static List<Offset> get prostateMm => _prostateMm;
}

// Geometry, in the anatomy's millimetres.

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
