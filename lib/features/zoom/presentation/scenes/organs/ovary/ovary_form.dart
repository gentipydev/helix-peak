import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import '../fallopian_tube/fallopian_anatomy.dart';
import 'ovary_anatomy.dart';
import 'ovary_style.dart';

/// Where in the ovary the zoom's cell lives, by the Atlas's name for it.
enum OvaryHome {
  /// The follicles: the oocytes and the granulosa cells round them, from
  /// the earliest follicles under the surface to the one near ripeness.
  follicles,

  /// The stroma of the cortex and the medulla: the ovarian stromal cells,
  /// and any cell the Atlas finds in the ovary that lives in no follicle,
  /// as the tissue's own cells where the Atlas names none.
  stroma;

  static OvaryHome of(String? cell) {
    if (cell == null) {
      return stroma;
    }
    final String name = cell.toLowerCase();
    if (name.contains('oocyte') || name.contains('granulosa')) {
      return follicles;
    }
    return stroma;
  }

  /// The word the zoom names it by.
  String get word => switch (this) {
    OvaryHome.follicles => 'follicles',
    OvaryHome.stroma => 'stroma',
  };
}

/// A follicle with an antrum, laid in the scene: its middle and its
/// radius to the outside of its granulosa, how thick its granulosa is, its
/// cumulus's middle and radius, and its oocyte's middle and radius.
typedef OvaryFollicle = ({
  Offset centre,
  double radius,
  double granulosa,
  Offset cumulus,
  double cumulusRadius,
  Offset oocyte,
  double oocyteRadius,
});

/// A helicine vessel cut across in the medulla, laid in the scene: its
/// middle, its outer half-lengths along and across its cut, which way its
/// length lies, and the share of it its wall is; whether it is an artery.
typedef OvaryProfile = ({
  Offset centre,
  double along,
  double across,
  double angle,
  double wall,
  bool artery,
});

/// The ovary as the zoom's organ scene draws it, cut through its thickness
/// from the front: every part in the scene's units at its real size, the
/// middle of the body's outline of it at the origin.
///
/// The ovary is drawn from general anatomy ([OvaryAnatomy]) and laid on the
/// body's outline of it, turned [OvaryAnatomy.tilt] from level, so that the
/// place it is gone into in the anatomy ([OvaryAnatomy.site]) lies on the
/// place the body goes in ([site]). The anatomogram draws each ovary as a
/// pie closed through its middle, a slit of no width from its rim to its
/// middle: the outline the step from the body draws in from is the disc's
/// rim ([rimOf]), and so is the other ovary's ([others]). Where the zoom's
/// cell lives is [home]. Everything here is geometry: what it is drawn in
/// is `OvaryArt`'s.
final class OvaryForm {
  OvaryForm({
    required List<Offset> diagram,
    required this.others,
    required this.site,
    required double length,
    required this.view,
    this.home = OvaryHome.follicles,
  }) : scale = length / OvaryAnatomy.length,
       diagramPoints = rimOf(diagram) {
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
      count: OvaryStyle.morphPoints,
      bed: mm(OvaryStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The left ovary where the body draws the ovary as [part], in a view
  /// [view] metres across, the cell living in it at [home].
  factory OvaryForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    OvaryHome home = OvaryHome.follicles,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return OvaryForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      others: <List<Offset>>[
        for (final List<Offset> other in part.others)
          rimOf(<Offset>[for (final Offset p in other) placed(p)]),
      ],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the ovary, in the scene: its free border's
  /// cortex.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Where in the ovary the zoom's cell lives.
  final OvaryHome home;

  /// The body's other outlines of the ovary, its right ovary, in the scene,
  /// each the disc's rim.
  final List<List<Offset>> others;

  /// The body's outline of the ovary in the scene, the disc's rim: the
  /// shape the step from the body hands over.
  final List<Offset> diagramPoints;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The ovary's outline, the cut's edge, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres along the ovary, in the scene:
  /// turned as the ovary lies in the body.
  Offset place(Offset mm) => site + _turned(mm - OvaryAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres along the ovary.
  Offset toMm(Offset p) => OvaryAnatomy.site + _unturned((p - site) / scale);

  /// How far the ovary's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the ovary's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the ovary's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  /// [points], the anatomogram's outline of an ovary, without what it
  /// draws its slit by: a point lying deep inside the outline of the
  /// others, the pie's middle, and a point all but repeating the one before
  /// it. What is left is the disc's rim.
  static List<Offset> rimOf(List<Offset> points) {
    List<Offset> out = <Offset>[...points];
    final Rect box = _bounds(out);
    final double deep = 0.2 * math.min(box.width, box.height);
    bool dropped = true;
    while (dropped && out.length > 3) {
      dropped = false;
      for (int i = 0; i < out.length; i++) {
        final List<Offset> rest = <Offset>[...out]..removeAt(i);
        if (_inside(rest, out[i]) &&
            _toLine(rest, out[i], closed: true) > deep) {
          out = rest;
          dropped = true;
          break;
        }
      }
    }
    final double near = 0.01 * (box.width + box.height);
    final List<Offset> kept = <Offset>[];
    for (final Offset p in out) {
      if (kept.isEmpty || (p - kept.last).distance > near) {
        kept.add(p);
      }
    }
    if (kept.length > 3 && (kept.first - kept.last).distance <= near) {
      kept.removeLast();
    }
    return kept;
  }

  // The anatomy in millimetres, built once for every ovary.

  static final double _cos = math.cos(OvaryAnatomy.tilt);
  static final double _sin = math.sin(OvaryAnatomy.tilt);

  /// [p], along the ovary, as it lies in the body: its tubal pole higher.
  static Offset _turned(Offset p) =>
      Offset(p.dx * _cos + p.dy * _sin, -p.dx * _sin + p.dy * _cos);

  static Offset _unturned(Offset p) =>
      Offset(p.dx * _cos - p.dy * _sin, p.dx * _sin + p.dy * _cos);

  /// The ovary's outline, followed closely, in millimetres.
  static final List<Offset> _outlineMm = _closedCurve(
    OvaryAnatomy.outline,
    OvaryStyle.outlineStep,
  );

  /// The way into the ovary at each point of its outline, a unit.
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

  /// The ovary's outline in millimetres. For tests.
  static List<Offset> get outlineMm => _outlineMm;

  /// How far [mm] lies from the ovary's surface, in millimetres; below
  /// zero outside it.
  static double depth(Offset mm) {
    final double edge = _toLine(_outlineMm, mm, closed: true);
    return _inside(_outlineMm, mm) ? edge : -edge;
  }

  /// Whether [mm] lies in the medulla's oval.
  static bool inMedulla(Offset mm) {
    final Offset d = mm - OvaryAnatomy.medulla;
    final double a = d.dx / OvaryAnatomy.medullaAlong;
    final double b = d.dy / OvaryAnatomy.medullaAcross;
    return a * a + b * b <= _medullaReach(math.atan2(b, a));
  }

  /// How far out the medulla's oval reaches at [angle], squared, a little
  /// uneven, as a central stroma's edge is.
  static double _medullaReach(double angle) {
    final double r =
        1 + 0.05 * math.sin(3 * angle + 1) + 0.03 * math.sin(5 * angle);
    return r * r;
  }

  /// The medulla's oval in millimetres, closed: it runs out past the
  /// mesovarian border, where the cut's outline bounds it.
  static final List<Offset> _medullaMm = <Offset>[
    for (int k = 0; k < 160; k++)
      () {
        final double t = 2 * math.pi * k / 160;
        final double r = math.sqrt(_medullaReach(t));
        return OvaryAnatomy.medulla +
            Offset(
              math.cos(t) * OvaryAnatomy.medullaAlong * r,
              math.sin(t) * OvaryAnatomy.medullaAcross * r,
            );
      }(),
  ];

  /// The outline's points where the medulla reaches the surface: the
  /// hilum, from its first to its last, by the outline's points.
  static final (int, int) _hilum = () {
    final int n = _outlineMm.length;
    int? first;
    int? last;
    // Round from the uterine pole: the hilum is one stretch of the
    // mesovarian border, with the outline's start outside it.
    for (int i = 0; i < n; i++) {
      if (inMedulla(_outlineMm[i])) {
        first ??= i;
        last = i;
      }
    }
    return (first!, last!);
  }();

  /// The outline from the hilum's one end round the free border to its
  /// other: where the cortex lies under the surface; with the way in at
  /// each of its points, and how much of its depth the cortex keeps there,
  /// none at the hilum.
  static final List<int> _runIndices = () {
    final int n = _outlineMm.length;
    final (int first, int last) = _hilum;
    return <int>[for (int i = last; i != first; i = (i + 1) % n) i];
  }();
  static final List<Offset> _runMm = <Offset>[
    for (final int i in _runIndices) _outlineMm[i],
  ];
  static final List<double> _taperMm = () {
    final List<double> along = _along(_runMm);
    final double total = along.last;
    return <double>[
      for (final double a in along)
        _smooth(math.min(a, total - a) / OvaryStyle.taper),
    ];
  }();

  /// The cut face's rim under the surface, in millimetres: its outer edge,
  /// the run, and its inner, the run [OvaryStyle.rim] in, tapering out at
  /// the hilum.
  static final List<Offset> _rimInnerMm = <Offset>[
    for (int k = 0; k < _runIndices.length; k++)
      _outlineMm[_runIndices[k]] +
          _inMm[_runIndices[k]] * (OvaryStyle.rim * _taperMm[k]),
  ];

  /// Every follicle, corpus and their margins, what the dust and the
  /// vessels keep out of: middles and radii, in millimetres.
  static final List<(Offset, double)> _bodiesMm = <(Offset, double)>[
    (OvaryAnatomy.ripe.centre, OvaryAnatomy.ripe.radius),
    for (final OvaryBody b in OvaryAnatomy.antral) (b.centre, b.radius),
    (OvaryAnatomy.luteum.centre, OvaryAnatomy.luteum.radius),
    for (final OvaryBody b in OvaryAnatomy.albicantia)
      (b.centre, b.radius * (1 + OvaryStyle.convolution * 1.45)),
  ];

  static bool _clear(Offset mm, double margin) {
    for (final (Offset c, double r) in _bodiesMm) {
      if ((mm - c).distance < r + margin) {
        return false;
      }
    }
    return true;
  }

  /// The dust of the earliest follicles under the surface, in millimetres:
  /// the primordial ones near it and the growing ones deeper, scattered
  /// along the cortex, none in another follicle or a corpus.
  static final List<Offset> _primordialMm = _dust(
    OvaryStyle.primordialApart,
    OvaryAnatomy.primordialFrom,
    OvaryAnatomy.primordialTo,
    OvaryStyle.seed,
  );
  static final List<Offset> _growingMm = _dust(
    OvaryStyle.growingApart,
    OvaryAnatomy.growingFrom,
    OvaryAnatomy.growingTo,
    OvaryStyle.seed + 1,
  );

  static List<Offset> _dust(double apart, double from, double to, int seed) {
    final math.Random random = math.Random(seed);
    final List<double> along = _along(_runMm);
    final List<Offset> out = <Offset>[];
    int j = 1;
    for (double a = apart / 2; a < along.last; a += apart) {
      final double at = a + (random.nextDouble() - 0.5) * apart * 0.6;
      // Scattered a little either way, so the search may step back.
      while (j > 1 && along[j - 1] >= at) {
        j--;
      }
      while (j < along.length - 1 && along[j] < at) {
        j++;
      }
      final int k = j;
      final double deep =
          (from + (to - from) * random.nextDouble()) * _taperMm[k];
      final Offset p = _runMm[k] + _inMm[_runIndices[k]] * deep;
      if (_taperMm[k] > 0.3 &&
          _inside(_outlineMm, p) &&
          !inMedulla(p) &&
          _clear(p, 0.15)) {
        out.add(p);
      }
    }
    return out;
  }

  /// The helicine vessels' profiles in the medulla, in millimetres: along
  /// each course, swinging from side to side as a coil cut across does,
  /// artery and vein in turn, none outside the medulla or in a follicle or
  /// a corpus.
  static final List<(Offset, Offset, bool)> _profilesMm = () {
    final List<(Offset, Offset, bool)> out = <(Offset, Offset, bool)>[];
    for (final List<Offset> course in OvaryAnatomy.helicine) {
      final List<Offset> line = _smoothLine(course, OvaryStyle.edgeStep);
      final List<double> along = _along(line);
      int k = 0;
      int j = 1;
      for (
        double a = OvaryAnatomy.coilPitch / 2;
        a < along.last;
        a += OvaryAnatomy.coilPitch
      ) {
        while (j < along.length - 1 && along[j] < a) {
          j++;
        }
        final Offset way = _unit(line[j] - line[j - 1]);
        final Offset across = Offset(-way.dy, way.dx);
        final double swing = k.isEven
            ? OvaryAnatomy.coilSwing
            : -OvaryAnatomy.coilSwing;
        final Offset p = line[j] + across * swing;
        final bool artery = k % 3 != 2;
        final double r = artery
            ? OvaryAnatomy.arteryProfile
            : OvaryAnatomy.veinProfile;
        if (inMedulla(p) && _inside(_outlineMm, p) && _clear(p, r + 0.1)) {
          out.add((p, way, artery));
        }
        k++;
      }
    }
    return out;
  }();

  // The ovary laid in the scene.

  /// The medulla's oval, in the scene; drawn inside the outline.
  late final List<Offset> medulla = _placed(_medullaMm);

  /// The run of the outline the cortex lies under, and the rim's inner
  /// edge, in the scene: the cut face turning away under the surface.
  late final List<Offset> run = _placed(_runMm);
  late final List<Offset> rimInner = _placed(_rimInnerMm);

  /// The follicle near ripeness, then the small antral ones.
  late final List<OvaryFollicle> follicles = <OvaryFollicle>[
    _follicle(OvaryAnatomy.ripe, ripe: true),
    for (final OvaryBody b in OvaryAnatomy.antral) _follicle(b, ripe: false),
  ];

  OvaryFollicle _follicle(OvaryBody body, {required bool ripe}) {
    // Its cumulus on the side of it toward the ovary's middle, away from
    // the surface.
    final Offset inward = _unit(OvaryAnatomy.medulla - body.centre);
    final double granulosa = ripe
        ? OvaryAnatomy.granulosaRipe
        : OvaryAnatomy.granulosa;
    final double cumulus = ripe
        ? OvaryAnatomy.cumulusRipe
        : OvaryAnatomy.cumulus;
    final double wall = body.radius - granulosa;
    return (
      centre: place(body.centre),
      radius: mm(body.radius),
      granulosa: mm(granulosa),
      cumulus: place(body.centre + inward * (wall - cumulus * 0.35)),
      cumulusRadius: mm(cumulus * 0.75),
      oocyte: place(body.centre + inward * (wall - cumulus * 0.6)),
      oocyteRadius: mm(OvaryAnatomy.oocyte / 2),
    );
  }

  /// The corpus luteum: its outer edge, a little swollen at each fold, and
  /// its core's, thrown into festoons by the folds of its lining; the
  /// creases between the folds, each from the core out into the band.
  late final List<Offset> luteum = _placed(_luteumOuterMm);
  late final List<Offset> luteumCore = _placed(_luteumCoreMm);
  late final List<(Offset, Offset)> luteumCreases = <(Offset, Offset)>[
    for (final (Offset a, Offset b) in _luteumCreasesMm) (place(a), place(b)),
  ];

  static final List<Offset> _luteumOuterMm = _ring(
    OvaryAnatomy.luteum.centre,
    (double t) =>
        OvaryAnatomy.luteum.radius +
        OvaryStyle.swell *
            OvaryAnatomy.luteumBand *
            math.sin(OvaryAnatomy.luteumFolds * t),
  );
  static double _coreAt(double t) =>
      OvaryAnatomy.luteum.radius -
      OvaryAnatomy.luteumBand *
          (1 +
              OvaryStyle.festoon *
                  (0.5 + 0.5 * math.sin(OvaryAnatomy.luteumFolds * t)));
  static final List<Offset> _luteumCoreMm = _ring(
    OvaryAnatomy.luteum.centre,
    _coreAt,
  );
  static final List<(Offset, Offset)> _luteumCreasesMm = () {
    const int folds = OvaryAnatomy.luteumFolds;
    final List<(Offset, Offset)> out = <(Offset, Offset)>[];
    for (int k = 0; k < folds; k++) {
      // Between two folds: where the core reaches out furthest.
      final double t = (2 * math.pi * k + 1.5 * math.pi) / folds;
      final Offset way = Offset(math.cos(t), math.sin(t));
      final double from = _coreAt(t);
      out.add((
        OvaryAnatomy.luteum.centre + way * from,
        OvaryAnatomy.luteum.centre +
            way *
                (from +
                    OvaryStyle.creaseReach *
                        (OvaryAnatomy.luteum.radius - from)),
      ));
    }
    return out;
  }();

  /// The corpora albicantia, each convoluted; and the creases in each.
  late final List<List<Offset>> albicantia = <List<Offset>>[
    for (final List<Offset> a in _albicantiaMm) _placed(a),
  ];
  late final List<List<Offset>> albicantiaCreases = <List<Offset>>[
    for (final List<Offset> c in _albicantiaCreasesMm) _placed(c),
  ];

  static final List<List<Offset>> _albicantiaMm = <List<Offset>>[
    for (int k = 0; k < OvaryAnatomy.albicantia.length; k++)
      _ring(
        OvaryAnatomy.albicantia[k].centre,
        (double t) =>
            OvaryAnatomy.albicantia[k].radius *
            (1 +
                OvaryStyle.convolution * math.sin(5 * t + 1.3 * k) +
                0.45 * OvaryStyle.convolution * math.sin(9 * t + 0.7 + k)),
      ),
  ];
  static final List<List<Offset>> _albicantiaCreasesMm = <List<Offset>>[
    for (int k = 0; k < OvaryAnatomy.albicantia.length; k++)
      for (final double at in <double>[-0.32, 0.28])
        () {
          final OvaryBody b = OvaryAnatomy.albicantia[k];
          final double r = b.radius;
          return <Offset>[
            for (int i = 0; i <= 12; i++)
              b.centre +
                  Offset(
                    (-0.55 + 1.1 * i / 12) * r,
                    at * r + 0.12 * r * math.sin(i * 1.4 + k + 4 * at),
                  ),
          ];
        }(),
  ];

  /// The dust of the earliest follicles, in the scene: the primordial and
  /// the growing, each a point.
  late final List<Offset> primordial = _placed(_primordialMm);
  late final List<Offset> growing = _placed(_growingMm);

  /// The helicine vessels cut across, in the scene.
  late final List<OvaryProfile> profiles = <OvaryProfile>[
    for (final (Offset p, Offset way, bool artery) in _profilesMm)
      () {
        final Offset w = _turned(way);
        final double r = artery
            ? OvaryAnatomy.arteryProfile
            : OvaryAnatomy.veinProfile;
        return (
          centre: place(p),
          along: mm(r * 1.45),
          across: mm(r),
          angle: math.atan2(w.dy, w.dx),
          wall: artery ? OvaryAnatomy.arteryWall : OvaryAnatomy.veinWall,
          artery: artery,
        );
      }(),
  ];

  // What runs outside the ovary.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(OvaryStyle.tubeRow), bend: 0.9);

  /// The tube, from its ostium by the tubal pole back over the ovary to
  /// where it is cut short toward the uterus, its calibre the fallopian
  /// tube's own at each length from its ostium.
  late final TubeCourse tube = _tube(
    AnatomyTube(OvaryAnatomy.tube.reversed.toList(), <double>[
      for (final double a in _along(OvaryAnatomy.tube.reversed.toList()))
        _tubeHalfAt(a),
    ], cutEnd: true),
  );

  /// The fallopian tube's outer half-width [fromOstium] millimetres from
  /// its ostium, by the tube the fallopian tube's own scene draws.
  static double _tubeHalfAt(double fromOstium) {
    final List<double> along = _along(FallopianAnatomy.course);
    final double at = (along.last - fromOstium).clamp(0.0, along.last);
    int j = 1;
    while (j < along.length - 1 && along[j] < at) {
      j++;
    }
    final double span = along[j] - along[j - 1];
    final double t = span <= 0 ? 0 : (at - along[j - 1]) / span;
    return FallopianAnatomy.half[j - 1] +
        (FallopianAnatomy.half[j] - FallopianAnatomy.half[j - 1]) * t;
  }

  /// The fimbriae round the ostium, the fallopian tube's own, spread down
  /// past the tubal pole: drawn for the body's left, where the fallopian
  /// tube's scene draws the right, so they lie round the ostium the other
  /// way.
  late final List<TubeCourse> fimbriae = () {
    const List<Offset> c = OvaryAnatomy.tube;
    final int n = c.length;
    final Offset end = c[n - 1];
    final Offset way = _unit(OvaryAnatomy.fimbriaeWay);
    final Offset across = Offset(-way.dy, way.dx);
    final double rim = FallopianAnatomy.half.last * 0.9;
    return <TubeCourse>[
      for (final (double share, double turn, double length)
          in FallopianAnatomy.fimbriae)
        () {
          final Offset root = end + across * (rim * (1 - 2 * share));
          final Offset dir = _rotate(way, turn);
          final Offset curl = _rotate(dir, turn * 0.35);
          return _tube(
            AnatomyTube(
              <Offset>[
                root - dir * 0.8,
                root + dir * (length * 0.5),
                root + dir * (length * 0.55) + curl * (length * 0.45),
              ],
              <double>[
                FallopianAnatomy.fimbriaRoot,
                (FallopianAnatomy.fimbriaRoot + FallopianAnatomy.fimbriaTip) /
                    2,
                FallopianAnatomy.fimbriaTip,
              ],
            ),
          );
        }(),
    ];
  }();

  /// The ligament of the ovary, from its uterine pole, cut short.
  late final TubeCourse ligament = _tube(
    AnatomyTube(OvaryAnatomy.ligament, <double>[
      for (final Offset _ in OvaryAnatomy.ligament) OvaryAnatomy.ligamentRadius,
    ], cutEnd: true),
  );

  /// The ovarian vein and artery, coming up out of the hilum and running
  /// up the suspensory ligament, cut short.
  late final TubeCourse vein = _tube(
    AnatomyTube(
      OvaryAnatomy.vein,
      <double>[
        for (final Offset _ in OvaryAnatomy.vein) OvaryAnatomy.veinRadius,
      ],
      fadeIn: OvaryAnatomy.vesselsRise,
      cutEnd: true,
    ),
  );
  late final TubeCourse artery = _tube(
    AnatomyTube(
      OvaryAnatomy.artery,
      <double>[
        for (final Offset _ in OvaryAnatomy.artery) OvaryAnatomy.arteryRadius,
      ],
      fadeIn: OvaryAnatomy.vesselsRise,
      cutEnd: true,
    ),
  );

  /// What is drawn outside the ovary, for its names to keep clear of.
  late final List<TubeCourse> beside = <TubeCourse>[
    tube,
    ...fimbriae,
    ligament,
    vein,
    artery,
  ];

  // Where the parts are named.

  /// Where the cell lives: at the site, the cortex's follicles or its
  /// stroma about it.
  late final Offset homeName = site;
  late final Offset luteumName = place(OvaryAnatomy.luteumName);
  late final Offset albicansName = place(OvaryAnatomy.albicansName);
  late final Offset medullaName = place(OvaryAnatomy.medullaName);
  late final Offset ligamentName = place(OvaryAnatomy.ligamentName);

  /// The tube named over the ovary's middle, the suspensory ligament where
  /// its vessels are cut.
  late final Offset tubeName = place(OvaryAnatomy.tubeName);
  late final Offset suspensoryName =
      (vein.centres.last + artery.centres.last) / 2;

  /// Where the step from the body meets the ovary's outline and the
  /// body's, besides the middle of their tops: the tubal pole, the free
  /// border's lowest point and the uterine pole, each picked out of either
  /// outline alike.
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

  /// The hilum's ends in millimetres, and the follicles, corpora and
  /// profiles in millimetres, for tests.
  static (Offset, Offset) get hilumMm =>
      (_outlineMm[_hilum.$1], _outlineMm[_hilum.$2]);
  static List<Offset> get primordialMm => _primordialMm;
  static List<Offset> get growingMm => _growingMm;
  static List<Offset> get profilesMm => <Offset>[
    for (final (Offset p, Offset _, bool _) in _profilesMm) p,
  ];
}

// Geometry, in the anatomy's millimetres.

/// [way] turned by [angle] radians, clockwise on screen.
Offset _rotate(Offset way, double angle) {
  final double c = math.cos(angle);
  final double s = math.sin(angle);
  return Offset(way.dx * c - way.dy * s, way.dx * s + way.dy * c);
}

/// A closed ring round [centre], [radius] from it at each angle, in points
/// [OvaryStyle.edgeStep] apart at most.
List<Offset> _ring(Offset centre, double Function(double) radius) {
  final double reach = radius(0).abs() + 1;
  final int n = math.max(
    48,
    (2 * math.pi * reach / OvaryStyle.edgeStep).ceil(),
  );
  return <Offset>[
    for (int k = 0; k < n; k++)
      () {
        final double t = 2 * math.pi * k / n;
        return centre + Offset(math.cos(t), math.sin(t)) * radius(t);
      }(),
  ];
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
