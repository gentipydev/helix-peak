import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import '../bladder/bladder_anatomy.dart';
import '../bladder/bladder_form.dart';
import 'detrusor_anatomy.dart';
import 'detrusor_style.dart';

/// Smooth muscle as the zoom's organ scene draws it: the bladder's wall,
/// the detrusor, whole from the front, every part in the scene's units at
/// its real size, the middle of the body's outline of it at the origin.
///
/// It is drawn in the bladder specimen's frame ([BladderAnatomy],
/// [DetrusorAnatomy]) and laid on the body's outline of it, the
/// anatomogram's smooth muscle, so that the place it is gone into in the
/// anatomy ([BladderAnatomy.site]) lies on the place the body goes in
/// ([site]). The step from the body draws the body's outline in toward the
/// bladder's own ([pathAt]). The whole muscle is where the zoom's cell
/// lives, whatever the cell: the smooth muscle cell is the one cell the
/// Atlas names with smooth muscle as its home. Everything here is
/// geometry: what it is drawn in is `DetrusorArt`'s.
final class DetrusorForm {
  DetrusorForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
  }) : scale = length / BladderAnatomy.length {
    final List<Offset> knots = <Offset>[
      for (final Offset p in BladderForm.knotsMm) place(p),
    ];
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(DetrusorStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(DetrusorStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: DetrusorStyle.morphPoints,
      bed: mm(DetrusorStyle.bed),
      marks: BladderForm.marks,
      start: BladderForm.topMiddle,
    );
  }

  /// The muscle where the body draws it as [part], in a view [view] metres
  /// across.
  factory DetrusorForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return DetrusorForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
    );
  }

  /// Where the body goes into the muscle, in the scene: the front wall.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The bladder's outline and the points it is followed by.
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
  /// millimetres, laid so that the site lies where the body's is.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  List<List<Offset>> _placedAll(List<List<Offset>> lines) => <List<Offset>>[
    for (final List<Offset> l in lines) _placed(l),
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

  /// The outline followed closely, in millimetres: the bladder specimen's.
  static final List<Offset> _outlineMm = Contour(BladderForm.knotsMm)
      .sampled(DetrusorStyle.outlineSpan)
      .points;
  static final Rect _boxMm = _bounds(_outlineMm);

  /// How far the outline reaches to the body's left at height [y]: the
  /// half-width of the bladder there, the outline being the same either
  /// side of the middle; none above its dome or below its neck.
  static double halfAt(double y) {
    double right = 0;
    final int n = _outlineMm.length;
    for (int i = 0; i < n; i++) {
      final Offset a = _outlineMm[i];
      final Offset b = _outlineMm[(i + 1) % n];
      if ((a.dy <= y) == (b.dy <= y)) {
        continue;
      }
      final double x = a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
      right = math.max(right, x);
    }
    return right;
  }

  /// A number from 0 to 1 that stays with a place: a bundle's own.
  static double _hash(double v) {
    final double h = math.sin(v * 12.9898 + 78.233) * 43758.5453;
    return h - h.floorToDouble();
  }

  /// The share of the half-width the [k]th of the outer layer's bundles
  /// lies at: the meridians of a rounded form seen from the front, even in
  /// angle, so bunching toward the sides.
  static double bundleShare(int k) =>
      DetrusorAnatomy.bundleEdge *
      math.sin(-math.pi / 2 + math.pi * (k + 0.5) / DetrusorAnatomy.bundles);

  /// Whether the point at share [u] of the half-width and height [y] lies
  /// in the patch cut from the outer layer.
  static bool inPatchAt(double u, double y) =>
      u >= DetrusorAnatomy.patchFrom &&
      u <= DetrusorAnatomy.patchTo &&
      y >= DetrusorAnatomy.patchTop &&
      y <= DetrusorAnatomy.patchBottom;

  /// The outer layer's bundles, in millimetres: each a meridian, from the
  /// apex down to the neck, wandering a little, drawn only where it and its
  /// neighbour lie far enough apart, and not through the patch; in runs.
  static final List<List<Offset>> _bundlesMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    for (int k = 0; k < DetrusorAnatomy.bundles; k++) {
      final double u = bundleShare(k);
      final double apart = math.min(
        (bundleShare(math.max(0, k - 1)) - u).abs(),
        (bundleShare(math.min(DetrusorAnatomy.bundles - 1, k + 1)) - u).abs(),
      );
      final double phase = _hash(k.toDouble()) * 2 * math.pi;
      List<Offset> run = <Offset>[];
      for (
        double y = _boxMm.top + 0.3;
        y <= _boxMm.bottom - 0.3;
        y += DetrusorStyle.edgeStep
      ) {
        final double half = halfAt(y);
        final double wander =
            DetrusorAnatomy.wander *
            math.sin(2 * math.pi * y / DetrusorAnatomy.wave + phase);
        final double x = u * half + wander;
        final bool drawn =
            half * apart >= DetrusorAnatomy.bundleLeast &&
            x.abs() < half - 0.6 &&
            !inPatchAt(u, y);
        if (drawn) {
          run.add(Offset(x, y));
        } else if (run.length > 1) {
          out.add(run);
          run = <Offset>[];
        } else {
          run = <Offset>[];
        }
      }
      if (run.length > 1) {
        out.add(run);
      }
    }
    return out;
  }();

  /// The oblique bundles at the sides, in millimetres: from the silhouette
  /// in and down, and in and up, either side, not through the patch.
  static final List<List<Offset>> _obliquesMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    for (final double side in <double>[-1, 1]) {
      for (final double y0 in DetrusorAnatomy.obliqueAt) {
        for (final double drop in <double>[
          DetrusorAnatomy.obliqueDrop,
          -DetrusorAnatomy.obliqueDrop,
        ]) {
          final Offset from = Offset(side * (halfAt(y0) - 1), y0);
          final Offset to =
              from + Offset(-side * DetrusorAnatomy.obliqueRun, drop);
          final List<Offset> run = <Offset>[];
          final int steps = ((to - from).distance / DetrusorStyle.edgeStep)
              .ceil();
          for (int i = 0; i <= steps; i++) {
            final Offset p = Offset.lerp(from, to, i / steps)!;
            final double half = halfAt(p.dy);
            if (half <= 0 ||
                p.dx.abs() > half - 0.6 ||
                inPatchAt(p.dx / half, p.dy)) {
              continue;
            }
            run.add(p);
          }
          if (run.length > 1) {
            out.add(run);
          }
        }
      }
    }
    return out;
  }();

  /// The sphincter's rings round the neck, in millimetres: across the
  /// bladder, each sagging a little at its middle.
  static final List<List<Offset>> _ringsMm = <List<Offset>>[
    for (final double y in DetrusorAnatomy.rings)
      () {
        final double half = halfAt(y) - DetrusorAnatomy.ringIn;
        return <Offset>[
          for (int i = 0; i <= 24; i++)
            () {
              final double t = -1 + 2 * i / 24;
              return Offset(
                half * t,
                y + DetrusorAnatomy.ringSag * (1 - t * t),
              );
            }(),
        ];
      }(),
  ];

  /// The patch cut from the outer layer, in millimetres: along the bundle
  /// on its lateral side, across its foot, up the bundle on its medial
  /// side and back across its top.
  static final List<Offset> _patchMm = () {
    List<Offset> meridian(double u, double from, double to) {
      final int steps = ((to - from).abs() / DetrusorStyle.edgeStep).ceil();
      return <Offset>[
        for (int i = 0; i <= steps; i++)
          () {
            final double y = from + (to - from) * i / steps;
            return Offset(u * halfAt(y), y);
          }(),
      ];
    }

    return <Offset>[
      ...meridian(
        DetrusorAnatomy.patchFrom,
        DetrusorAnatomy.patchTop,
        DetrusorAnatomy.patchBottom,
      ),
      ...meridian(
        DetrusorAnatomy.patchTo,
        DetrusorAnatomy.patchBottom,
        DetrusorAnatomy.patchTop,
      ),
    ];
  }();

  /// The circular layer's bundles in the patch, in millimetres: across it
  /// at each height, a little oblique, kept in from its edges.
  static final List<List<Offset>> _circularMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    const double middle =
        (DetrusorAnatomy.patchFrom + DetrusorAnatomy.patchTo) / 2;
    for (final double y0 in DetrusorAnatomy.circular) {
      final List<Offset> run = <Offset>[];
      for (
        double u = DetrusorAnatomy.patchFrom;
        u <= DetrusorAnatomy.patchTo;
        u += 0.01
      ) {
        final double x = u * halfAt(y0);
        // Rising toward the body's side, whichever side the patch is on.
        final double y =
            y0 -
            (u.abs() - middle.abs()) *
                halfAt(y0) *
                DetrusorAnatomy.circularSlant;
        final Offset p = Offset(x, y);
        if (!_inside(_patchMm, p) ||
            _toLine(_patchMm, p, closed: true) < DetrusorAnatomy.circularIn) {
          if (run.length > 1) {
            out.add(List<Offset>.of(run));
          }
          run.clear();
          continue;
        }
        run.add(p);
      }
      if (run.length > 1) {
        out.add(List<Offset>.of(run));
      }
    }
    return out;
  }();

  /// The arteries' small branches, each running on over the wall and
  /// fading into it.
  static final List<AnatomyTube> _branchesMm = <AnatomyTube>[
    for (final AnatomyTube t in BladderForm.branchesInto(
      _outlineMm,
      under: DetrusorAnatomy.branchOver,
    ))
      AnatomyTube(t.points, t.radii, fadeOut: DetrusorAnatomy.branchFade),
  ];

  /// Whether [mm] lies in the patch, and how far in from its edge; below
  /// zero outside. For tests.
  static bool inPatch(Offset mm) => _inside(_patchMm, mm);
  static double patchDepth(Offset mm) {
    final double edge = _toLine(_patchMm, mm, closed: true);
    return _inside(_patchMm, mm) ? edge : -edge;
  }

  /// How far [mm] lies from the nearest bundle of the outer layer, in
  /// millimetres. For tests.
  static double clearOfBundles(Offset mm) {
    double best = double.infinity;
    for (final List<Offset> b in _bundlesMm) {
      best = math.min(best, _toLine(b, mm, closed: false));
    }
    return best;
  }

  // The parts, laid in the scene.

  /// The outer layer's bundles, the oblique bundles, the sphincter's rings,
  /// the patch and the circular layer's bundles in it.
  late final List<List<Offset>> bundles = _placedAll(_bundlesMm);
  late final List<List<Offset>> obliques = _placedAll(_obliquesMm);
  late final List<List<Offset>> rings = _placedAll(_ringsMm);
  late final List<Offset> patch = _placed(_patchMm);
  late final List<List<Offset>> circular = _placedAll(_circularMm);

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(DetrusorStyle.edgeStep), bend: 0.9);

  static AnatomyTube _mirrored(AnatomyTube tube) => AnatomyTube(
    <Offset>[for (final Offset p in tube.points) Offset(-p.dx, p.dy)],
    tube.radii,
    fadeIn: tube.fadeIn,
    fadeOut: tube.fadeOut,
    cutStart: tube.cutStart,
    cutEnd: tube.cutEnd,
  );

  /// The ureters, left and right, and the urethra, each cut short; the
  /// vesical arteries, cut short at their origins, and their branches over
  /// the wall; the urachus, fading out above.
  late final List<TubeCourse> ureters = <TubeCourse>[
    _tube(_mirrored(BladderAnatomy.rightUreter)),
    _tube(BladderAnatomy.rightUreter),
  ];
  late final TubeCourse urethra = _tube(DetrusorAnatomy.urethra);
  late final List<TubeCourse> arteries = <TubeCourse>[
    for (final AnatomyTube t in BladderForm.arteriesMm) _tube(t),
  ];
  late final List<TubeCourse> branches = <TubeCourse>[
    for (final AnatomyTube t in _branchesMm) _tube(t),
  ];
  late final TubeCourse urachus = _tube(DetrusorAnatomy.urachus);

  /// What runs on beside the bladder.
  late final List<TubeCourse> beside = <TubeCourse>[
    ...ureters,
    urethra,
    ...arteries,
    urachus,
  ];

  // Where the parts are named.

  /// The detrusor at the site; the circular layer at the patch's middle;
  /// the urachus above the apex; the ureter on the body's right where it
  /// runs beside the wall; the sphincter on its middle ring, on the body's
  /// left. The urethra and the figure's uterus or prostate below are drawn
  /// and not named: level with the row of names below the bladder, a
  /// third name there had no room on the squattest phones, its line
  /// running through the others' plates.
  Offset get homeName => site;
  late final Offset circularName = place(
    Offset(
      DetrusorAnatomy.circularNameAt * halfAt(DetrusorAnatomy.circularNameY),
      DetrusorAnatomy.circularNameY,
    ),
  );
  late final Offset urachusName = _nearest(<List<Offset>>[
    urachus.centres,
  ], place(DetrusorAnatomy.urachusName));
  late final Offset ureterName = _nearest(<List<Offset>>[
    ureters.first.centres,
  ], place(BladderAnatomy.ureterName));
  late final Offset sphincterName = _nearest(
    rings,
    place(DetrusorAnatomy.sphincterName),
  );

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

  /// The points of the bladder's own outline where the step from the body
  /// meets the body's, for tests: the dome's middle, then the rest in the
  /// order round it from there.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[BladderForm.topMiddle(points)],
    for (final int Function(List<Offset>) mark in BladderForm.marks)
      points[mark(points)],
  ];

  /// For tests: the anatomy in millimetres.
  static List<Offset> get outlineMm => _outlineMm;
  static List<List<Offset>> get bundlesMm => _bundlesMm;
  static List<List<Offset>> get obliquesMm => _obliquesMm;
  static List<List<Offset>> get ringsMm => _ringsMm;
  static List<Offset> get patchMm => _patchMm;
  static List<List<Offset>> get circularMm => _circularMm;
}

// Geometry, in the anatomy's millimetres.

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
