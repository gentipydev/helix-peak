import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'prostate_anatomy.dart';
import 'prostate_style.dart';

/// Where in the prostate the zoom's cell lives, by the Atlas's name for it.
enum ProstateHome {
  /// The glands of its peripheral and central zones: their secretory and
  /// basal cells, and any cell the Atlas finds in the prostate that is not
  /// one of the others, as the tissue's own cells where it names none.
  glands,

  /// Its fibromuscular stroma: its smooth muscle cells and fibroblasts.
  stroma,

  /// The lining of its urethra: the urothelial, hillock and club cells
  /// that line it and the ducts' mouths in it.
  urethra;

  static ProstateHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('smooth muscle') ||
        name.contains('fibroblast') ||
        name.contains('stromal')) {
      return stroma;
    }
    if (name.contains('hillock') ||
        name.contains('club') ||
        name.contains('urothelial')) {
      return urethra;
    }
    return glands;
  }

  /// The word the zoom names it by.
  String get word => switch (this) {
    ProstateHome.glands => 'glands',
    ProstateHome.stroma => 'stroma',
    ProstateHome.urethra => 'urethra',
  };
}

/// The prostate as the zoom's organ scene draws it, cut from front to back
/// through its ejaculatory ducts: every part in the scene's units at its
/// real size, the middle of the body's outline of it at the origin.
///
/// The prostate is drawn from general anatomy ([ProstateAnatomy]) and laid
/// on the body's outline of it so that the place it is gone into in the
/// anatomy ([ProstateAnatomy.site]) lies on the place the body goes in
/// ([site]). Where the zoom's cell lives is [home]. Everything here is
/// geometry: what it is drawn in is `ProstateArt`'s.
final class ProstateForm {
  ProstateForm({
    required this.diagramPoints,
    required this.site,
    required double width,
    required this.view,
    this.home = ProstateHome.glands,
  }) : scale = width / ProstateAnatomy.width {
    final List<Offset> diagramDense = Contour(diagramPoints).sampled(8).points;
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
      diagramPath: Contour(diagramPoints).toPath(),
      count: ProstateStyle.morphPoints,
      bed: mm(ProstateStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The prostate where the body draws it as [part], in a view [view]
  /// metres across, the cell living in it at [home].
  factory ProstateForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    ProstateHome home = ProstateHome.glands,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return ProstateForm(
      diagramPoints: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      width: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the prostate, in the scene: its peripheral
  /// zone.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Where in the prostate the zoom's cell lives.
  final ProstateHome home;

  /// The body's outline of the prostate in the scene: the shape the step
  /// from the body hands over.
  final List<Offset> diagramPoints;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The prostate's outline, the cut's edge, and the points it is followed
  /// by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - ProstateAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => ProstateAnatomy.site + (p - site) / scale;

  /// How far the prostate's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the prostate's at 1, and [bed] of the way on toward the
  /// bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the prostate's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every prostate.

  static Offset _mirror(Offset p) => Offset(-p.dx, p.dy);

  /// The outline, followed closely.
  static final List<Offset> _outlineMm = _closedCurve(
    ProstateAnatomy.outline,
    ProstateStyle.outlineStep,
  );

  /// The prostate's outline in millimetres. For tests.
  static List<Offset> get outlineMm => _outlineMm;

  /// The way into the prostate at each point of its outline, a unit.
  static final List<Offset> _inMm = () {
    final int n = _outlineMm.length;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t =
              _outlineMm[(i + 1) % n] - _outlineMm[(i - 1 + n) % n];
          final Offset left = Offset(-t.dy, t.dx) / t.distance;
          return _inside(_outlineMm, _outlineMm[i] + left * 0.05)
              ? left
              : -left;
        }(),
    ];
  }();

  /// The cut face's edge under the capsule, turning away, and the band
  /// under it the capsule is drawn in where the stroma is the home.
  static final List<Offset> _rimInnerMm = <Offset>[
    for (int i = 0; i < _outlineMm.length; i++)
      _outlineMm[i] + _inMm[i] * ProstateStyle.rim,
  ];

  /// How far [mm] lies from the prostate's surface; below zero outside.
  static double depth(Offset mm) {
    final double edge = _toLine(_outlineMm, mm, closed: true);
    return _inside(_outlineMm, mm) ? edge : -edge;
  }

  /// The central zone, closed above the base, outside the outline that
  /// bounds it.
  static final List<Offset> _centralMm = () {
    final List<Offset> right = _smoothLine(
      ProstateAnatomy.centralBorder,
      ProstateStyle.edgeStep,
    );
    return <Offset>[
      ...right,
      for (final Offset p in right.reversed.skip(1)) _mirror(p),
    ];
  }();

  /// Its border with the peripheral zone, either side, inside the outline.
  static final List<List<Offset>> _centralBorderMm = () {
    final List<Offset> right = <Offset>[
      for (final Offset p in _smoothLine(
        ProstateAnatomy.centralBorder,
        ProstateStyle.edgeStep,
      ))
        if (_inside(_outlineMm, p)) p,
    ];
    return <List<Offset>>[
      right,
      <Offset>[for (final Offset p in right) _mirror(p)],
    ];
  }();

  /// Whether [mm] lies in the central zone.
  static bool inCentral(Offset mm) =>
      _inside(_outlineMm, mm) && _inside(_centralMm, mm);

  /// The urethra's opened lumen: down its right side and up its left.
  static final List<Offset> _urethraMm = () {
    const List<(double, double)> u = ProstateAnatomy.urethra;
    final List<Offset> right = _smoothLine(<Offset>[
      for (final (double y, double half) in u) Offset(half, y),
    ], ProstateStyle.edgeStep);
    return <Offset>[
      ...right,
      for (final Offset p in right.reversed.skip(1)) _mirror(p),
    ];
  }();

  /// The urethra's half-width at depth [y], its lumen's.
  static double urethraHalf(double y) {
    const List<(double, double)> u = ProstateAnatomy.urethra;
    if (y <= u.first.$1 || y >= u.last.$1) {
      return y <= u.first.$1 ? 0 : u.last.$2;
    }
    for (int i = 0; i + 1 < u.length; i++) {
      final (double y0, double h0) = u[i];
      final (double y1, double h1) = u[i + 1];
      if (y <= y1) {
        return h0 + (h1 - h0) * (y - y0) / (y1 - y0);
      }
    }
    return u.last.$2;
  }

  /// The smooth muscle round the urethra: its outer edge, round the lumen,
  /// thickening toward the apex.
  static final List<Offset> _sleeveMm = () {
    const List<(double, double)> u = ProstateAnatomy.urethra;
    final double top = u.first.$1;
    final double bottom = u.last.$1 + 2;
    final List<Offset> right = <Offset>[];
    for (double y = top - ProstateAnatomy.sleeve; y <= bottom; y += 0.25) {
      final double t = ((y - top) / (u.last.$1 - top)).clamp(0.0, 1.0);
      final double thick =
          ProstateAnatomy.sleeve +
          (ProstateAnatomy.sleeveApex - ProstateAnatomy.sleeve) * t * t;
      final double half = urethraHalf(y.clamp(top, u.last.$1 - 1e-9));
      final double cap = y < top
          ? math.sqrt(
              math.max(
                0,
                1 -
                    ((top - y) / ProstateAnatomy.sleeve) *
                        ((top - y) / ProstateAnatomy.sleeve),
              ),
            )
          : 1;
      right.add(Offset((half + thick) * cap, y));
    }
    return <Offset>[
      ...right,
      for (final Offset p in right.reversed.skip(1)) _mirror(p),
    ];
  }();

  /// Whether [mm] lies in the urethra or the muscle round it.
  static bool inSleeve(Offset mm) => _inside(_sleeveMm, mm);

  /// The colliculus on the urethra's floor.
  static final List<Offset> _colliculusMm = <Offset>[
    for (int k = 0; k < 64; k++)
      () {
        final double t = 2 * math.pi * k / 64;
        // A little narrower above, where the crest rises to it.
        final double across =
            ProstateAnatomy.colliculusAcross * (1 - 0.12 * math.sin(t));
        return ProstateAnatomy.colliculus +
            Offset(
              math.cos(t) * across,
              math.sin(t) * ProstateAnatomy.colliculusDown,
            );
      }(),
  ];

  /// The crest down the urethra's floor below the colliculus.
  static final (Offset, Offset) _crestMm = (
    ProstateAnatomy.colliculus +
        const Offset(0, ProstateAnatomy.colliculusDown * 0.6),
    const Offset(0, ProstateAnatomy.crestTo),
  );

  /// The prostatic ducts' orifices in the sinuses either side of the
  /// crest.
  static final List<Offset> _orificesMm = <Offset>[
    for (
      double y = ProstateAnatomy.sinusFrom;
      y <= ProstateAnatomy.sinusTo;
      y += ProstateAnatomy.sinusApart
    ) ...<Offset>[
      Offset(-ProstateAnatomy.sinusOut, y),
      Offset(ProstateAnatomy.sinusOut, y),
    ],
  ];

  /// The utricle: a blind sac up from its orifice between the ducts.
  static final List<Offset> _utricleMm = () {
    const double w = ProstateAnatomy.utricleWidth / 2;
    const double top = ProstateAnatomy.utricleTop;
    const Offset bottom = ProstateAnatomy.utricleMouth;
    return <Offset>[
      for (int k = 0; k <= 16; k++)
        Offset(
          w * math.cos(math.pi * k / 16),
          top + w - w * math.sin(math.pi * k / 16),
        ),
      Offset(-w * 0.7, bottom.dy),
      Offset(w * 0.7, bottom.dy),
    ];
  }();

  /// The ejaculatory ducts, each its middle line, its wall's half-width
  /// along it, diminishing toward its end.
  static final List<List<Offset>> _ductLinesMm = () {
    final List<Offset> left = _smoothLine(
      ProstateAnatomy.duct,
      ProstateStyle.edgeStep,
    );
    return <List<Offset>>[
      left,
      <Offset>[for (final Offset p in left) _mirror(p)],
    ];
  }();

  /// A duct's outline: its middle line [line] widened by its half-width,
  /// [from] at its start to [to] at its end.
  static List<Offset> _widened(List<Offset> line, double from, double to) {
    final List<double> along = _along(line);
    final List<Offset> a = <Offset>[];
    final List<Offset> b = <Offset>[];
    for (int i = 0; i < line.length; i++) {
      final Offset t =
          line[math.min(line.length - 1, i + 1)] - line[math.max(0, i - 1)];
      final Offset across = Offset(-t.dy, t.dx) / t.distance;
      final double w = from + (to - from) * along[i] / along.last;
      a.add(line[i] + across * w);
      b.add(line[i] - across * w);
    }
    return <Offset>[...a, ...b.reversed];
  }

  static final List<List<Offset>> _ductWallsMm = <List<Offset>>[
    for (final List<Offset> l in _ductLinesMm)
      _widened(l, ProstateAnatomy.ductBase, ProstateAnatomy.ductEnd),
  ];

  /// Whether [mm] lies within [margin] of an ejaculatory duct or the
  /// utricle.
  static bool nearDucts(Offset mm, double margin) {
    for (final List<Offset> l in _ductLinesMm) {
      if (_toLine(l, mm, closed: false) < ProstateAnatomy.ductBase + margin) {
        return true;
      }
    }
    return _inside(_utricleMm, mm) ||
        _toLine(_utricleMm, mm, closed: true) < margin;
  }

  /// The ducts of the peripheral zone, out from the urethra's sides, each
  /// curving up toward the base or down toward the apex as the zone runs,
  /// with a branch; and those of the central zone, up along the
  /// ejaculatory ducts and out near the base. Each clipped to the cut
  /// face, short of its rim.
  static final List<List<Offset>> _glandDuctsMm = () {
    final List<List<Offset>> left = <List<Offset>>[];
    for (final (
          double y,
          double angle,
          double reach,
          double branchAt,
          double turn,
        )
        in ProstateAnatomy.peripheralDucts) {
      final Offset start = Offset(urethraHalf(y) + 0.9, y);
      final Offset way = Offset(math.cos(angle), math.sin(angle));
      // Curving on, a little further from straight across, as it goes.
      final Offset bend = Offset(
        math.cos(angle * 1.25),
        math.sin(angle * 1.25),
      );
      final List<Offset> course = _smoothLine(<Offset>[
        start,
        start + way * (reach * 0.5),
        start + way * (reach * 0.5) + bend * (reach * 0.5),
      ], ProstateStyle.edgeStep);
      left.add(course);
      final int at = (course.length * branchAt).round().clamp(
        1,
        course.length - 2,
      );
      final Offset from = course[at];
      final Offset dir = course[at + 1] - course[at - 1];
      final Offset unit = dir / dir.distance;
      final Offset turned = Offset(
        unit.dx * math.cos(turn) - unit.dy * math.sin(turn),
        unit.dx * math.sin(turn) + unit.dy * math.cos(turn),
      );
      left.add(
        _smoothLine(<Offset>[
          from,
          from + turned * (reach * (1 - branchAt) * 0.55),
          from + (turned + unit) * (reach * (1 - branchAt) * 0.45),
        ], ProstateStyle.edgeStep),
      );
    }
    for (final List<Offset> knots in ProstateAnatomy.centralDucts) {
      left.add(_smoothLine(knots, ProstateStyle.edgeStep));
    }
    final List<List<Offset>> all = <List<Offset>>[
      ...left,
      for (final List<Offset> l in left)
        <Offset>[for (final Offset p in l) _mirror(p)],
    ];
    // Kept to the cut face, short of its rim, and out of the urethra and
    // the ejaculatory ducts.
    return <List<Offset>>[
      for (final List<Offset> l in all)
        for (final List<Offset> run in _runs(
          l,
          (Offset p) =>
              depth(p) > ProstateStyle.rim + 0.4 &&
              !inSleeve(p) &&
              !nearDucts(p, 0.25),
        ))
          if (run.length > 2) run,
    ];
  }();

  /// The pores, the lumens of the glands: scattered through both zones,
  /// denser toward the apex, clear of the rim, the urethra, the ejaculatory
  /// ducts and the place the body goes in.
  static final List<(Offset, double)> _poresMm = () {
    final math.Random random = math.Random(ProstateStyle.seed);
    final Rect box = _bounds(_outlineMm);
    final List<(Offset, double)> out = <(Offset, double)>[];
    int tries = 0;
    while (out.length < ProstateAnatomy.pores && tries < 40000) {
      tries++;
      final Offset p = Offset(
        box.left + random.nextDouble() * box.width,
        box.top + random.nextDouble() * box.height,
      );
      final double down = (p.dy - box.top) / box.height;
      final double keep =
          (1 + (ProstateAnatomy.poreApex - 1) * down) /
          ProstateAnatomy.poreApex;
      final double r =
          (ProstateAnatomy.poreLeast +
              (ProstateAnatomy.poreMost - ProstateAnatomy.poreLeast) *
                  random.nextDouble()) /
          2;
      if (random.nextDouble() > keep ||
          depth(p) < ProstateStyle.rim + 0.6 + r ||
          _inside(_sleeveMm, p) ||
          _toLine(_sleeveMm, p, closed: true) < 0.5 + r ||
          nearDucts(p, 0.5 + r) ||
          (p - ProstateAnatomy.site).distance < 1.6 + r ||
          _centralBorderMm.any(
            (List<Offset> l) => _toLine(l, p, closed: false) < 0.3 + r,
          ) ||
          out.any(
            ((Offset, double) q) => (q.$1 - p).distance < q.$2 + r + 0.6,
          )) {
        continue;
      }
      out.add((p, r));
    }
    return out;
  }();

  /// The seminal vesicle on the body's left, its course followed closely
  /// with its coils' swellings, fading out above.
  static final AnatomyTube _vesicleTube = () {
    final List<Offset> line = _smoothLine(ProstateAnatomy.vesicle, 0.5);
    final List<double> along = _along(line);
    final List<double> knots = _along(ProstateAnatomy.vesicle);
    double base(double a) {
      int j = 1;
      while (j < knots.length - 1 && knots[j] < a) {
        j++;
      }
      final double t = ((a - knots[j - 1]) / (knots[j] - knots[j - 1])).clamp(
        0.0,
        1.0,
      );
      return ProstateAnatomy.vesicleRadii[j - 1] +
          (ProstateAnatomy.vesicleRadii[j] -
                  ProstateAnatomy.vesicleRadii[j - 1]) *
              t;
    }

    final double total = along.last;
    return AnatomyTube(line, <double>[
      for (int i = 0; i < line.length; i++)
        base(along[i] / total * knots.last) *
            (1 +
                ProstateAnatomy.coilDepth *
                    math.sin(2 * math.pi * along[i] / ProstateAnatomy.coil)),
    ], fadeOut: ProstateAnatomy.vesicleFade);
  }();

  /// Where the vesicle's coils meet, along it, between its swellings.
  static final List<double> _coilsAt = () {
    final double total = _along(_vesicleTube.points).last;
    return <double>[
      for (
        double a = ProstateAnatomy.coil * 0.75;
        a < total - 1;
        a += ProstateAnatomy.coil
      )
        a,
    ];
  }();

  /// The ampulla on the body's left, tortuous along its course, fading out
  /// above.
  static final AnatomyTube _ampullaTube = () {
    final List<Offset> line = _smoothLine(ProstateAnatomy.ampulla, 0.4);
    final List<double> along = _along(line);
    final List<double> knots = _along(ProstateAnatomy.ampulla);
    final List<Offset> swung = <Offset>[];
    final List<double> radii = <double>[];
    for (int i = 0; i < line.length; i++) {
      final Offset t =
          line[math.min(line.length - 1, i + 1)] - line[math.max(0, i - 1)];
      final Offset across = Offset(-t.dy, t.dx) / t.distance;
      // No swing where it goes in at the base.
      final double settle = _smooth(along[i] / 3);
      swung.add(
        line[i] +
            across *
                (ProstateAnatomy.ampullaSwing *
                    settle *
                    math.sin(
                      2 * math.pi * along[i] / ProstateAnatomy.ampullaTurn,
                    )),
      );
      final double a = along[i] / along.last * knots.last;
      int j = 1;
      while (j < knots.length - 1 && knots[j] < a) {
        j++;
      }
      final double s = ((a - knots[j - 1]) / (knots[j] - knots[j - 1])).clamp(
        0.0,
        1.0,
      );
      radii.add(
        ProstateAnatomy.ampullaRadii[j - 1] +
            (ProstateAnatomy.ampullaRadii[j] -
                    ProstateAnatomy.ampullaRadii[j - 1]) *
                s,
      );
    }
    return AnatomyTube(swung, radii, fadeOut: ProstateAnatomy.ampullaFade);
  }();

  static AnatomyTube _mirrored(AnatomyTube t) => AnatomyTube(
    <Offset>[for (final Offset p in t.points) _mirror(p)],
    t.radii,
    fadeIn: t.fadeIn,
    fadeOut: t.fadeOut,
    cutStart: t.cutStart,
    cutEnd: t.cutEnd,
  );

  // The parts, laid in the scene.

  /// The cut face's edge under the capsule and the line it turns away to,
  /// point for point.
  late final List<Offset> rimOuter = _placed(_outlineMm);
  late final List<Offset> rimInner = _placed(_rimInnerMm);

  late final List<Offset> central = _placed(_centralMm);
  late final List<List<Offset>> centralBorders = <List<Offset>>[
    for (final List<Offset> l in _centralBorderMm) _placed(l),
  ];
  late final List<Offset> urethra = _placed(_urethraMm);
  late final List<Offset> sleeve = _placed(_sleeveMm);
  late final List<Offset> colliculus = _placed(_colliculusMm);
  late final (Offset, Offset) crest = (place(_crestMm.$1), place(_crestMm.$2));
  late final List<Offset> orifices = _placed(_orificesMm);
  late final List<Offset> utricle = _placed(_utricleMm);
  late final Offset utricleMouth = place(ProstateAnatomy.utricleMouth);
  late final List<Offset> ductMouths = <Offset>[
    place(ProstateAnatomy.ductMouth),
    place(_mirror(ProstateAnatomy.ductMouth)),
  ];
  late final List<List<Offset>> ductLines = <List<Offset>>[
    for (final List<Offset> l in _ductLinesMm) _placed(l),
  ];
  late final List<List<Offset>> ductWalls = <List<Offset>>[
    for (final List<Offset> w in _ductWallsMm) _placed(w),
  ];
  late final List<List<Offset>> glandDucts = <List<Offset>>[
    for (final List<Offset> l in _glandDuctsMm) _placed(l),
  ];
  late final List<(Offset, double)> pores = <(Offset, double)>[
    for (final (Offset p, double r) in _poresMm) (place(p), mm(r)),
  ];

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(ProstateStyle.tubeRow), bend: 0.9);

  /// The seminal vesicles, the body's left then its right, and where their
  /// coils meet, along each.
  late final List<TubeCourse> vesicles = <TubeCourse>[
    _tube(_vesicleTube),
    _tube(_mirrored(_vesicleTube)),
  ];
  late final List<double> coilsAt = <double>[
    for (final double a in _coilsAt) mm(a),
  ];

  /// The ampullae of the deferent ducts, the body's left then its right.
  late final List<TubeCourse> ampullae = <TubeCourse>[
    _tube(_ampullaTube),
    _tube(_mirrored(_ampullaTube)),
  ];

  /// The prostatic arteries, the body's left then its right.
  late final List<TubeCourse> arteries = <TubeCourse>[
    _tube(ProstateAnatomy.artery),
    _tube(_mirrored(ProstateAnatomy.artery)),
  ];

  /// The membranous urethra in its sphincter, cut short below the apex.
  late final TubeCourse sphincter = _tube(ProstateAnatomy.sphincter);

  /// What is drawn outside the prostate, for its names to keep clear of.
  late final List<TubeCourse> beside = <TubeCourse>[
    ...vesicles,
    ...ampullae,
    ...arteries,
    sphincter,
  ];

  // Where the parts are named.

  /// Where the cell lives: the glands at the site, the stroma there too,
  /// the urethra down its lumen.
  Offset get homeName => switch (home) {
    ProstateHome.glands || ProstateHome.stroma => site,
    ProstateHome.urethra => urethraName,
  };
  late final Offset centralName = place(ProstateAnatomy.centralName);
  late final Offset urethraName = place(ProstateAnatomy.urethraName);
  late final Offset verumontanumName = place(ProstateAnatomy.verumontanumName);

  /// The ejaculatory duct on the body's right, a third of the way down;
  /// the vesicle on the body's left and the ampulla on its right, part way
  /// up where each shows whole.
  late final Offset ductName = () {
    final List<Offset> l = ductLines.last;
    return l[l.length ~/ 3];
  }();
  late final Offset vesicleName = _wholeMiddle(vesicles.first);
  late final Offset ampullaName = _wholeMiddle(ampullae.last);

  static Offset _wholeMiddle(TubeCourse t) {
    final int last = t.shown.lastIndexWhere((double s) => s > 0.98);
    return t.centres[math.max(0, last * 3 ~/ 5)];
  }

  /// Where the step from the body meets the prostate's outline and the
  /// body's, besides the middle of their tops: either side and the apex,
  /// each picked out of either outline alike.
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
  /// body's, for tests: the top's middle, then the rest in the order of
  /// [_marks].
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topMiddle(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];

  /// The pores and the ducts of the glands in millimetres, for tests.
  static List<(Offset, double)> get poresMm => _poresMm;
  static List<List<Offset>> get glandDuctsMm => _glandDuctsMm;
}

// Geometry, in the anatomy's millimetres.

/// The runs of [line] whose points [keep] holds for.
List<List<Offset>> _runs(List<Offset> line, bool Function(Offset) keep) {
  final List<List<Offset>> out = <List<Offset>>[];
  List<Offset> run = <Offset>[];
  for (final Offset p in line) {
    if (keep(p)) {
      run.add(p);
    } else if (run.isNotEmpty) {
      out.add(run);
      run = <Offset>[];
    }
  }
  if (run.isNotEmpty) {
    out.add(run);
  }
  return out;
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

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
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
