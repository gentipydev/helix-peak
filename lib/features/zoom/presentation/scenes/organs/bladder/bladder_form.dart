import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'bladder_anatomy.dart';
import 'bladder_style.dart';

/// The figure's parts named beside the bladder where the figure draws
/// them: its uterus, as the anatomogram's endometrium is named so by the
/// fallopian tube's scene, on the female figure, and its prostate on the
/// male.
const String _uterus = 'UBERON_0001295';
const String _prostate = 'UBERON_0002367';

/// The bladder as the zoom's organ scene draws it, opened from the front:
/// every part in the scene's units at its real size, the middle of the
/// body's outline of it at the origin.
///
/// The bladder is drawn from general anatomy ([BladderAnatomy]) and laid
/// on the body's outline of it so that the place it is gone into in the
/// anatomy ([BladderAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline in toward the
/// bladder's own ([pathAt]). Its urothelium is where the zoom's cell lives,
/// whatever the cell: no other cell the Atlas names has the bladder as its
/// home. Everything here is geometry: what it is drawn in is
/// `BladderArt`'s.
final class BladderForm {
  BladderForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.uterusOutline,
    this.prostateOutline,
  }) : scale = length / BladderAnatomy.length {
    final List<Offset> knots = <Offset>[
      for (final Offset p in _knotsMm) place(p),
    ];
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(BladderStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(BladderStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: BladderStyle.morphPoints,
      bed: mm(BladderStyle.bed),
      marks: marks,
      start: topMiddle,
    );
  }

  /// The bladder where the body draws it as [part] of [figure], in a view
  /// [view] metres across; the figure's uterus or prostate below it.
  factory BladderForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    AnatomyFigure? figure,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    List<Offset>? nearest(String uberon) {
      final AnatomyPart? other = figure?.parts[uberon];
      if (other == null) {
        return null;
      }
      List<Offset>? best;
      double least = double.infinity;
      for (final List<Offset> c in other.contours) {
        final double d = (_bounds(c).center - part.site).distance;
        if (d < least) {
          least = d;
          best = c;
        }
      }
      return best == null
          ? null
          : <Offset>[for (final Offset p in best) placed(p)];
    }

    return BladderForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      uterusOutline: nearest(_uterus),
      prostateOutline: nearest(_prostate),
    );
  }

  /// Where the body goes into the bladder, in the scene: its back wall,
  /// above the trigone.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// The body's outlines of the uterus (on the female figure) and of the
  /// prostate (on the male) below the bladder, in the scene; none where no
  /// figure is given or it draws no such part.
  final List<Offset>? uterusOutline;
  final List<Offset>? prostateOutline;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The bladder's outline, the serosa, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - BladderAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => BladderAnatomy.site + (p - site) / scale;

  /// How far the bladder's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the bladder's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the bladder's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every bladder.

  /// The outline's own points, its right half and then its left, mirrored,
  /// from the middle of the dome round by the neck; and how thick the wall
  /// is at each.
  static List<Offset> get knotsMm => _knotsMm;
  static final List<Offset> _knotsMm = <Offset>[
    ...BladderAnatomy.half,
    for (int i = BladderAnatomy.half.length - 2; i >= 1; i--)
      Offset(-BladderAnatomy.half[i].dx, BladderAnatomy.half[i].dy),
  ];
  static final List<double> _knotWalls = <double>[
    ...BladderAnatomy.wall,
    for (int i = BladderAnatomy.wall.length - 2; i >= 1; i--)
      BladderAnatomy.wall[i],
  ];

  /// The outline followed closely, in millimetres, and how thick the wall
  /// is at each of its points.
  static final List<Offset> _outlineMm = Contour(_knotsMm)
      .sampled(BladderStyle.outlineSpan)
      .points;
  static final List<double> _wallMm = () {
    const int span = BladderStyle.outlineSpan;
    final int n = _knotWalls.length;
    return <double>[
      for (int i = 0; i < n; i++)
        for (int k = 0; k < span; k++)
          _knotWalls[i] + (_knotWalls[(i + 1) % n] - _knotWalls[i]) * k / span,
    ];
  }();

  /// The way into the bladder at each of the outline's points, a unit.
  static final List<Offset> _inwardMm = () {
    final List<Offset> normals = _normals(_outlineMm, closed: true);
    final double inward = _inside(_outlineMm, _outlineMm[0] + normals[0] * 0.5)
        ? 1
        : -1;
    return <Offset>[for (final Offset n in normals) n * inward];
  }();

  /// The edges of the wall's coats, point for point with the outline, in
  /// millimetres: the serosa's inner edge, the detrusor's, the lamina
  /// propria's and the urothelium's, its surface.
  static final List<List<Offset>> _coatsMm = () {
    final List<List<Offset>> out = <List<Offset>>[
      for (int k = 0; k < 4; k++) <Offset>[],
    ];
    for (int i = 0; i < _outlineMm.length; i++) {
      final double w = _wallMm[i];
      final double serosa = math.min(
        w * BladderAnatomy.serosaShare,
        BladderAnatomy.serosaMost,
      );
      final double lamina = math.min(
        w * BladderAnatomy.laminaShare,
        BladderAnatomy.laminaMost,
      );
      final double urothelium = math.min(
        w * BladderAnatomy.urotheliumShare,
        BladderAnatomy.urotheliumMost,
      );
      final double detrusor = math.max(0, w - serosa - lamina - urothelium);
      final Offset p = _outlineMm[i];
      final Offset n = _inwardMm[i];
      double depth = 0;
      for (final (int k, double coat) in <(int, double)>[
        (0, serosa),
        (1, detrusor),
        (2, lamina),
        (3, urothelium),
      ]) {
        depth += coat;
        out[k].add(p + n * depth);
      }
    }
    return out;
  }();

  /// The urothelium's surface, the wall's inner edge, in millimetres.
  static List<Offset> get _innerMm => _coatsMm[3];

  // The trigone.

  /// The ureters' orifices, left and right, and the urethra's.
  static final Offset _leftOrifice = Offset(
    -BladderAnatomy.rightOrifice.dx,
    BladderAnatomy.rightOrifice.dy,
  );
  static const Offset _rightOrifice = BladderAnatomy.rightOrifice;
  static const Offset _urethral = BladderAnatomy.urethralOrifice;

  /// The torus uretericus, from the left orifice to the right, bowed up
  /// away from the neck.
  static final List<Offset> _torusMm = () {
    const int steps = 24;
    final Offset middle = Offset.lerp(_leftOrifice, _rightOrifice, 0.5)!;
    final Offset control =
        middle + const Offset(0, -2 * BladderAnatomy.torusBow);
    return <Offset>[
      for (int i = 0; i <= steps; i++)
        () {
          final double t = i / steps;
          final double u = 1 - t;
          return _leftOrifice * (u * u) +
              control * (2 * u * t) +
              _rightOrifice * (t * t);
        }(),
    ];
  }();

  /// The way each plica runs, up and out from its orifice: the left's, and
  /// the right's.
  static Offset _plicaWay(double side) => Offset(
    side * math.cos(BladderAnatomy.plicaRise),
    -math.sin(BladderAnatomy.plicaRise),
  );

  /// The plicae uretericae, each from its orifice up and out.
  static final List<List<Offset>> _plicaeMm = <List<Offset>>[
    for (final (Offset orifice, double side) in <(Offset, double)>[
      (_leftOrifice, -1),
      (_rightOrifice, 1),
    ])
      _line(
        orifice,
        orifice + _plicaWay(side) * BladderAnatomy.plica,
        BladderStyle.edgeStep,
      ),
  ];

  /// The trigone, between the torus and the urethral orifice, and its two
  /// sides down from each ureter's orifice.
  static final List<Offset> _trigoneMm = <Offset>[..._torusMm, _urethral];
  static final List<List<Offset>> _trigoneSidesMm = <List<Offset>>[
    _line(_leftOrifice, _urethral, BladderStyle.edgeStep),
    _line(_rightOrifice, _urethral, BladderStyle.edgeStep),
  ];

  /// Each ureter's slit, a lens laid along its plica, and the urethra's
  /// crescent, its hollow up toward the trigone.
  static final List<List<Offset>> _slitsMm = <List<Offset>>[
    for (final (Offset orifice, double side) in <(Offset, double)>[
      (_leftOrifice, -1),
      (_rightOrifice, 1),
    ])
      _lens(
        orifice,
        _plicaWay(side),
        BladderAnatomy.slit,
        BladderAnatomy.slitWidth,
      ),
  ];
  static final List<Offset> _crescentMm = () {
    const int steps = 16;
    const double half = BladderAnatomy.crescent / 2;
    const double depth = BladderAnatomy.crescentDepth;
    // The outer edge sags below the orifice's middle, the inner edge less,
    // so the crescent is thickest at its middle and tapers to its horns.
    final List<Offset> outer = <Offset>[
      for (int i = 0; i <= steps; i++)
        () {
          final double x = -half + 2 * half * i / steps;
          final double s = 1 - (x / half) * (x / half);
          return _urethral + Offset(x, depth * 0.5 * s);
        }(),
    ];
    final List<Offset> inner = <Offset>[
      for (int i = steps; i >= 0; i--)
        () {
          final double x = -half + 2 * half * i / steps;
          final double s = 1 - (x / half) * (x / half);
          return _urethral + Offset(x, -depth * 0.5 * s * 0.2);
        }(),
    ];
    return <Offset>[...outer, ...inner];
  }();

  // The folds.

  /// The low folds' middle lines, in millimetres: each wandering, and a
  /// long one broken off once along its length.
  static final List<List<Offset>> _foldsMm = <List<Offset>>[
    for (final (Offset from, Offset to, int seed) in BladderAnatomy.folds)
      ..._fold(from, to, math.Random(seed)),
  ];

  static List<List<Offset>> _fold(Offset from, Offset to, math.Random random) {
    final Offset way = to - from;
    final double length = way.distance;
    final Offset along = way / length;
    final Offset across = Offset(-along.dy, along.dx);
    final double wavePhase = random.nextDouble() * 2 * math.pi;
    final double ripplePhase = random.nextDouble() * 2 * math.pi;
    final (double, double)? gap = length >= BladderAnatomy.breakFrom
        ? () {
            final double at = length * (0.3 + 0.4 * random.nextDouble());
            return (
              at - BladderAnatomy.breakLength / 2,
              at + BladderAnatomy.breakLength / 2,
            );
          }()
        : null;
    final int steps = math.max(2, (length / BladderStyle.edgeStep).ceil());
    final List<List<Offset>> out = <List<Offset>>[];
    List<Offset> run = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final double s = length * i / steps;
      if (gap != null && s > gap.$1 && s < gap.$2) {
        if (run.length > 1) {
          out.add(run);
        }
        run = <Offset>[];
        continue;
      }
      final double wander =
          BladderAnatomy.wander *
          (0.65 * math.sin(s / BladderAnatomy.wave * 2 * math.pi + wavePhase) +
              0.35 *
                  math.sin(
                    s / BladderAnatomy.ripple * 2 * math.pi + ripplePhase,
                  ));
      run.add(from + along * s + across * wander);
    }
    if (run.length > 1) {
      out.add(run);
    }
    return out;
  }

  /// How far [mm] lies from the nearest fold's middle line, in
  /// millimetres. For tests.
  static double clearOfFolds(Offset mm) {
    double best = double.infinity;
    for (final List<Offset> fold in _foldsMm) {
      best = math.min(best, _toLine(fold, mm, closed: false));
    }
    return best;
  }

  /// How far [mm] lies inside the urothelium's surface, from the wall's
  /// inner edge, in millimetres: below zero in the wall or outside it. For
  /// tests.
  static double clearOfWall(Offset mm) {
    final double d = _toLine(_innerMm, mm, closed: true);
    return _inside(_innerMm, mm) ? d : -d;
  }

  /// How far [mm] lies outside the trigone, in millimetres: below zero
  /// inside it. For tests.
  static double clearOfTrigone(Offset mm) {
    final double d = _toLine(_trigoneMm, mm, closed: true);
    return _inside(_trigoneMm, mm) ? -d : d;
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

  /// The folds' middle lines, in millimetres. For tests.
  static List<List<Offset>> get foldsMm => _foldsMm;

  // The parts, laid in the scene.

  /// The wall's coats' edges, point for point with the outline: the
  /// serosa's inner edge, the detrusor's, the lamina propria's and the
  /// urothelium's surface.
  late final List<List<Offset>> coats = <List<Offset>>[
    for (final List<Offset> edge in _coatsMm) _placed(edge),
  ];

  /// The outline as the coats are laid round it, point for point with
  /// them.
  late final List<Offset> serosa = _placed(_outlineMm);

  /// The urothelium's surface, the wall's inner edge.
  List<Offset> get inner => coats[3];

  /// The detrusor's middle, in runs along the wall where it shows: where
  /// its name is set.
  late final List<List<Offset>> muscleMiddle = () {
    final List<List<Offset>> runs = <List<Offset>>[];
    List<Offset> run = <Offset>[];
    final int n = _outlineMm.length;
    // From the place with no wall, the neck's lowest point, so that no run
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

  /// The trigone, its sides, the torus, the plicae, the ureters' slits and
  /// the urethra's crescent.
  late final List<Offset> trigone = _placed(_trigoneMm);
  late final List<List<Offset>> trigoneSides = <List<Offset>>[
    for (final List<Offset> side in _trigoneSidesMm) _placed(side),
  ];
  late final List<Offset> torus = _placed(_torusMm);
  late final List<List<Offset>> plicae = <List<Offset>>[
    for (final List<Offset> plica in _plicaeMm) _placed(plica),
  ];
  late final List<List<Offset>> slits = <List<Offset>>[
    for (final List<Offset> slit in _slitsMm) _placed(slit),
  ];
  late final List<Offset> crescent = _placed(_crescentMm);

  /// The ureters' orifices and the urethra's, in the scene.
  late final Offset leftOrifice = place(_leftOrifice);
  late final Offset rightOrifice = place(_rightOrifice);
  late final Offset urethralOrifice = place(_urethral);

  /// The folds' middle lines, and each as the crease cut along it,
  /// tapering in from its ends.
  late final List<List<Offset>> folds = <List<Offset>>[
    for (final List<Offset> fold in _foldsMm) _placed(fold),
  ];
  late final Path creases = _creases(
    _foldsMm,
    BladderStyle.crease,
    BladderStyle.creaseTaper,
  );

  /// The torus's and the plicae's creases, the plicae fading as they run
  /// out; and the trigone's sides, fine.
  late final Path torusCrease = _creases(
    <List<Offset>>[_torusMm],
    BladderStyle.torusCrease,
    BladderAnatomy.slit / 2,
  );
  late final Path plicaCreases = _creases(
    _plicaeMm,
    BladderStyle.torusCrease,
    BladderAnatomy.plica * BladderStyle.plicaFade,
  );
  late final Path trigoneEdges = _creases(
    _trigoneSidesMm,
    BladderStyle.trigoneEdge,
    BladderAnatomy.slit,
  );

  Path _creases(List<List<Offset>> lines, double width, double taper) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      path.addPolygon(_placed(_tapered(line, width / 2, taper)), true);
    }
    return path;
  }

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(BladderStyle.edgeStep), bend: 0.9);

  /// [tube] as it runs on the body's right, mirrored.
  static AnatomyTube _mirrored(AnatomyTube tube) => AnatomyTube(
    <Offset>[for (final Offset p in tube.points) Offset(-p.dx, p.dy)],
    tube.radii,
    fadeIn: tube.fadeIn,
    fadeOut: tube.fadeOut,
    cutStart: tube.cutStart,
    cutEnd: tube.cutEnd,
  );

  /// The superior and inferior vesical arteries, left and right, in
  /// millimetres.
  static final List<AnatomyTube> arteriesMm = <AnatomyTube>[
    _mirrored(BladderAnatomy.rightSuperior),
    BladderAnatomy.rightSuperior,
    _mirrored(BladderAnatomy.rightInferior),
    BladderAnatomy.rightInferior,
  ];

  /// The ureters, left and right, and the urethra, each cut short; the
  /// superior and inferior vesical arteries, cut short at their origins.
  late final List<TubeCourse> ureters = <TubeCourse>[
    _tube(_mirrored(BladderAnatomy.rightUreter)),
    _tube(BladderAnatomy.rightUreter),
  ];
  late final TubeCourse urethra = _tube(BladderAnatomy.urethra);
  late final List<TubeCourse> arteries = <TubeCourse>[
    for (final AnatomyTube t in arteriesMm) _tube(t),
  ];

  /// The arteries' small branches into the wall, each running in under it.
  late final List<TubeCourse> branches = <TubeCourse>[
    for (final AnatomyTube t in _branchesMm) _tube(t),
  ];

  static final List<AnatomyTube> _branchesMm = branchesInto(_outlineMm);

  /// The arteries' small branches into a wall whose outline is [outline],
  /// each running [under] it, in millimetres.
  static List<AnatomyTube> branchesInto(
    List<Offset> outline, {
    double under = BladderAnatomy.branchUnder,
  }) {
    final List<AnatomyTube> out = <AnatomyTube>[];
    final math.Random random = math.Random(BladderStyle.seed);
    for (final AnatomyTube artery in arteriesMm) {
      final TubeCourse course = TubeCourse(
        artery,
        (Offset p) => p,
        1,
        BladderStyle.edgeStep,
        bend: 0.9,
      );
      double next = BladderAnatomy.branchApart / 3;
      for (int i = 0; i < course.length; i++) {
        if (course.arc[i] < next) {
          continue;
        }
        final Offset c = course.centres[i];
        // Leaning a little ahead along the artery, or behind.
        final Offset way = Offset(course.across[i].dy, -course.across[i].dx);
        final Offset aim =
            c +
            way * (BladderAnatomy.branchLean * (2 * random.nextDouble() - 1));
        Offset edge = outline.first;
        for (final Offset q in outline) {
          if ((q - aim).distanceSquared < (edge - aim).distanceSquared) {
            edge = q;
          }
        }
        final Offset to = edge - c;
        final double reach = to.distance;
        if (reach > BladderAnatomy.branchReach || reach <= 0) {
          continue;
        }
        next =
            course.arc[i] +
            BladderAnatomy.branchApart +
            BladderAnatomy.branchJitter * (2 * random.nextDouble() - 1);
        out.add(
          AnatomyTube(
            <Offset>[c, edge + to / reach * under],
            const <double>[BladderAnatomy.branch, BladderAnatomy.branch],
          ),
        );
      }
    }
    return out;
  }

  /// What runs on beside the bladder.
  late final List<TubeCourse> beside = <TubeCourse>[
    ...ureters,
    urethra,
    ...arteries,
  ];

  // Where the parts are named.

  /// Its trigone, in its half on the body's right; the ureter's orifice on
  /// the body's right,
  /// and that ureter where it runs beside the wall; the urethra; and the
  /// detrusor in the cut wall of the body's left side.
  late final Offset trigoneName = place(BladderAnatomy.trigoneName);
  late final Offset orificeName = leftOrifice;
  late final Offset ureterName = _nearest(<List<Offset>>[
    ureters.first.centres,
  ], place(BladderAnatomy.ureterName));
  late final Offset urethraName = _nearest(<List<Offset>>[
    urethra.centres,
  ], place(BladderAnatomy.urethraName));
  late final Offset detrusorName = _nearest(
    muscleMiddle,
    place(BladderAnatomy.detrusorName),
  );

  /// The figure's uterus or prostate named where it shows below the
  /// bladder, on the side of the urethra away from the ureter named: the
  /// point of it furthest out from the bladder's outline and off the
  /// urethra that lies well inside it (the anatomogram draws the uterus as
  /// a thin band, its outline, so well inside it is little); none where the
  /// figure draws neither.
  late final String? neighbourWord = uterusOutline != null
      ? 'uterus'
      : prostateOutline != null
      ? 'prostate'
      : null;
  late final Offset? neighbourName = () {
    final List<Offset>? shape = uterusOutline ?? prostateOutline;
    if (shape == null) {
      return null;
    }
    return neighbourNameIn(
      shape,
      outline: outlinePoints,
      urethra: urethra,
      step: mm(BladderStyle.neighbourStep),
    );
  }();

  /// Where a neighbour of the bladder's whose outline is [shape] is named,
  /// below a bladder whose outline is [outline] and whose [urethra] leaves
  /// it: the point of the shape furthest out from the bladder's outline
  /// and off the urethra that lies well inside the shape, on the side of
  /// the urethra away from the ureter named, looked for every [step].
  static Offset? neighbourNameIn(
    List<Offset> shape, {
    required List<Offset> outline,
    required TubeCourse urethra,
    required double step,
  }) {
    final Rect bounds = _bounds(shape);
    final Offset top = urethra.centres.first;
    final Offset bottom = urethra.centres.last;
    final double urethraRadius = urethra.radius.first;
    Offset? best;
    double most = 0;
    for (double y = bounds.top; y <= bounds.bottom; y += step) {
      for (double x = bounds.left; x <= bounds.right; x += step) {
        final Offset p = Offset(x, y);
        if (p.dx < top.dx || !_inside(shape, p) || _inside(outline, p)) {
          continue;
        }
        final double room = <double>[
          _toLine(shape, p, closed: true) * BladderStyle.neighbourInside,
          _toLine(outline, p, closed: true),
          _toSegment(p, top, bottom) - urethraRadius,
        ].reduce(math.min);
        if (room > most) {
          most = room;
          best = p;
        }
      }
    }
    return best;
  }

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

  /// Where the step from the body meets the bladder's outline and the
  /// body's: the middle of the dome, which is nearly level, in place of the
  /// topmost point, which a hair's difference could move from one side of
  /// it to the other; each side's outermost point, and the neck's lowest,
  /// each picked out of either outline alike.
  static int topMiddle(List<Offset> points) {
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

  static final List<int Function(List<Offset>)> marks =
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

  /// The points of the bladder's own outline where the step from the body
  /// meets the body's, for tests: the dome's middle, then the rest in the
  /// order round it from there.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[topMiddle(points)],
    for (final int Function(List<Offset>) mark in marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

/// [from] to [to] in points [step] apart at most.
List<Offset> _line(Offset from, Offset to, double step) {
  final int steps = math.max(2, ((to - from).distance / step).ceil());
  return <Offset>[
    for (int i = 0; i <= steps; i++) Offset.lerp(from, to, i / steps)!,
  ];
}

/// A lens [length] long and [width] wide at [at], laid along [way].
List<Offset> _lens(Offset at, Offset way, double length, double width) {
  const int steps = 12;
  final Offset across = Offset(-way.dy, way.dx);
  return <Offset>[
    for (int i = 0; i < 2 * steps; i++)
      () {
        final double a = math.pi * i / steps;
        return at +
            way * (math.cos(a) * length / 2) +
            across * (math.sin(a) * width / 2);
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
