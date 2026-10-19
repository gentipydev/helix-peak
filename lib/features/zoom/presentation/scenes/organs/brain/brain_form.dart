import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../contour.dart';
import '../../relief.dart';
import '../../tube_course.dart';
import 'brain_anatomy.dart';
import 'brain_style.dart';

/// The parts of the brain's core: what the cut lays open between the medial
/// face and the eye, each its own tone.
enum BrainPart {
  vermis,
  brainstem,
  fourthVentricle,
  septum,
  hypothalamus,
  thalamus,
  pituitaryAnterior,
  pituitaryPosterior,
  infundibulum,
  pineal,
  fornix,
  callosum,
  chiasm,
}

/// A surface laid on a grid: where each of its points is, in the scene's
/// units, which way it faces there (x across the screen, y down it, z out of
/// it), and how far the form it is part of faces the eye.
final class BrainSurface {
  BrainSurface(this.columns, this.rows)
    : positions = Float32List(2 * columns * rows),
      normals = Float32List(3 * columns * rows),
      form = Float32List(columns * rows),
      inside = Uint8List(columns * rows);

  final int columns;
  final int rows;
  final Float32List positions;
  final Float32List normals;
  final Float32List form;

  /// Whether each point lies inside what the surface draws: 1 if it does.
  final Uint8List inside;

  int get length => columns * rows;
}

/// The brain as the zoom's organ scene draws it: every shape in the scene's
/// units at the brain's real size, its middle at the origin. The anatomy is
/// `BrainAnatomy`'s, in millimetres, scaled to the length the brain really
/// is. Everything here is geometry: what it is drawn in is `BrainArt`'s.
final class BrainForm {
  BrainForm({required double length, required this.view}) {
    final List<Offset> hemisphere = _dense(BrainAnatomy.hemisphere);
    final Rect hemi = _bounds(hemisphere);
    scale = length / hemi.width;
    Rect all = hemi;
    for (final List<Offset> part in <List<Offset>>[
      BrainAnatomy.brainstem,
      BrainAnatomy.vermis,
      BrainAnatomy.pituitaryAnterior,
      BrainAnatomy.pituitaryPosterior,
      BrainAnatomy.chiasm,
    ]) {
      all = all.expandToInclude(_bounds(_dense(part)));
    }
    _centre = all.center;
    _hemisphereMm = hemisphere;
  }

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's millimetres, in the scene's units.
  late final double scale;

  late final Offset _centre;
  late final List<Offset> _hemisphereMm;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => (mm - _centre) * scale;

  /// A point of the scene, in the anatomy's millimetres.
  Offset toMm(Offset p) => p / scale + _centre;

  /// [millimetres] of the real brain, in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  // The outlines.

  /// An outline of the anatomy, followed closely, in millimetres.
  static List<Offset> _dense(List<Offset> points) =>
      Contour(points).sampled(BrainStyle.outlineSpan).points;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  Path _path(List<Offset> anatomy) => Contour(_placed(anatomy)).toPath();

  /// The medial face's edge.
  late final Path hemisphere = _path(BrainAnatomy.hemisphere);

  late final Path callosum = _path(BrainAnatomy.callosum);
  late final Path septum = _path(BrainAnatomy.septum);
  late final Path thalamus = _path(BrainAnatomy.thalamus);
  late final Path hypothalamus = _path(BrainAnatomy.hypothalamus);
  late final Path chiasm = _path(BrainAnatomy.chiasm);
  late final Path pituitaryAnterior = _path(BrainAnatomy.pituitaryAnterior);
  late final Path pituitaryPosterior = _path(BrainAnatomy.pituitaryPosterior);
  late final Path pineal = _path(BrainAnatomy.pineal);
  late final Path brainstem = _path(BrainAnatomy.brainstem);
  late final Path fourthVentricle = _path(BrainAnatomy.fourthVentricle);

  /// The vermis's edge, scalloped by its folia ([arbor]).
  Path get vermis => arbor.outline;

  /// The fornix and the infundibulum, laid along their middle lines.
  late final List<Offset> _fornixMm = _band(
    BrainAnatomy.fornix,
    BrainAnatomy.fornixHalf,
    BrainAnatomy.fornixHalf,
  );
  late final List<Offset> _infundibulumMm = _band(
    BrainAnatomy.infundibulum,
    BrainAnatomy.infundibulumTop,
    BrainAnatomy.infundibulumFoot,
  );
  late final Path fornix = Contour(_placed(_fornixMm)).toPath();
  late final Path infundibulum = Contour(_placed(_infundibulumMm)).toPath();

  /// The aqueduct's middle line, to be stroked as wide as it is.
  late final Path aqueduct = _open(BrainAnatomy.aqueduct);

  /// The small round parts: the commissures, the adhesion, the mammillary
  /// body.
  Rect _rect(Rect mm) =>
      Rect.fromPoints(place(mm.topLeft), place(mm.bottomRight));

  late final Rect anteriorCommissure = _rect(BrainAnatomy.anteriorCommissure);
  late final Rect posteriorCommissure = _rect(BrainAnatomy.posteriorCommissure);
  late final Rect adhesion = _rect(BrainAnatomy.adhesion);
  late final Rect mammillary = _rect(BrainAnatomy.mammillary);

  /// Where the midbrain gives way to the pons, and the pons to the medulla.
  late final Path ponsTop = _open(BrainAnatomy.ponsTop);
  late final Path ponsFoot = _open(BrainAnatomy.ponsFoot);

  /// Everything the brain draws, as one outline, and the points it is
  /// followed by: what its scene's light passes over, and what its names
  /// are set round.
  late final Path outline = () {
    Path union = Path()..addPath(hemisphere, Offset.zero);
    for (final Path part in <Path>[
      brainstem,
      vermis,
      pituitaryAnterior,
      pituitaryPosterior,
      chiasm,
      infundibulum,
    ]) {
      union = Path.combine(PathOperation.union, union, part);
    }
    return union;
  }();

  late final List<Offset> outlinePoints = () {
    final List<Offset> out = <Offset>[];
    final double step = mm(1.5);
    for (final PathMetric metric in outline.computeMetrics()) {
      for (double d = 0; d < metric.length; d += step) {
        final Tangent? tangent = metric.getTangentForOffset(d);
        if (tangent != null) {
          out.add(tangent.position);
        }
      }
    }
    return out;
  }();

  /// [points] as an open curve through them, in the scene.
  Path _open(List<Offset> points) {
    final List<Offset> curve = _curve(points);
    final Path path = Path()
      ..moveTo(place(curve.first).dx, place(curve.first).dy);
    for (final Offset p in curve.skip(1)) {
      final Offset q = place(p);
      path.lineTo(q.dx, q.dy);
    }
    return path;
  }

  /// [points], an open line, followed by a curve through them.
  static List<Offset> _curve(List<Offset> points, {int span = 6}) {
    final int n = points.length;
    if (n < 3) {
      return points;
    }
    Offset at(int i) => i < 0
        ? points[0] * 2 - points[1]
        : i >= n
        ? points[n - 1] * 2 - points[n - 2]
        : points[i];
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < n - 1; i++) {
      final Offset p0 = at(i - 1);
      final Offset p1 = at(i);
      final Offset p2 = at(i + 1);
      final Offset p3 = at(i + 2);
      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      for (int k = 0; k < span; k++) {
        final double t = k / span;
        final double u = 1 - t;
        out.add(
          p1 * (u * u * u) +
              c1 * (3 * u * u * t) +
              c2 * (3 * u * t * t) +
              p2 * (t * t * t),
        );
      }
    }
    out.add(points.last);
    return out;
  }

  /// A band along the line through [points], [from] wide to either side at
  /// its start and [to] at its end: its outline, in millimetres.
  static List<Offset> _band(List<Offset> points, double from, double to) {
    final List<Offset> line = _curve(points);
    final int n = line.length;
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i < n; i++) {
      final Offset t = line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)];
      final Offset across = Offset(-t.dy, t.dx) / t.distance;
      final double half = from + (to - from) * i / (n - 1);
      left.add(line[i] + across * half);
      right.add(line[i] - across * half);
    }
    return <Offset>[...left, ...right.reversed];
  }

  // The medial face.

  /// Each sulcus's course: a curve through its points, wandering a little to
  /// either side as a sulcus does, the same every time.
  late final List<List<Offset>> _sulcusLines = <List<Offset>>[
    for (int k = 0; k < BrainAnatomy.sulci.length; k++)
      _wander(_curve(BrainAnatomy.sulci[k].points), math.Random(97 + k)),
  ];

  /// [line] wandering to either side of itself, its ends where they were:
  /// followed every few tenths of a millimetre, so the wander is a curve.
  static List<Offset> _wander(List<Offset> line, math.Random random) {
    final double phase = random.nextDouble() * 2 * math.pi;
    final double second = random.nextDouble() * 2 * math.pi;
    final List<Offset> even = _even(line, 0.3);
    final int n = even.length;
    final double total = 0.3 * (n - 1);
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < n; i++) {
      final double along = 0.3 * i;
      final Offset t = even[math.min(n - 1, i + 1)] - even[math.max(0, i - 1)];
      final Offset across = Offset(-t.dy, t.dx) / t.distance;
      final double wave =
          math.sin(2 * math.pi * along / BrainStyle.sulcusWave + phase) +
          0.35 *
              math.sin(
                2 * math.pi * along / (0.47 * BrainStyle.sulcusWave) + second,
              );
      final double ends = _smooth(along / 3) * _smooth((total - along) / 3);
      out.add(even[i] + across * (BrainStyle.sulcusWander * wave * ends));
    }
    return out;
  }

  /// Points every [step] along the open line through [points].
  static List<Offset> _even(List<Offset> points, double step) {
    final List<Offset> out = <Offset>[points.first];
    double carried = 0;
    for (int i = 1; i < points.length; i++) {
      final Offset a = points[i - 1];
      final Offset b = points[i];
      final double length = (b - a).distance;
      double at = step - carried;
      while (at <= length) {
        out.add(Offset.lerp(a, b, at / length)!);
        at += step;
      }
      carried = length - (at - step);
    }
    if ((out.last - points.last).distance > step * 0.3) {
      out.add(points.last);
    }
    return out;
  }

  /// How far [p], in millimetres, lies inside the hemisphere's edge;
  /// nothing outside it.
  double _edgeDistance(Offset p) {
    if (!_inside(_hemisphereMm, p)) {
      return 0;
    }
    double best = double.infinity;
    final int n = _hemisphereMm.length;
    for (int s = 0; s < n; s++) {
      final Offset a = _hemisphereMm[s];
      final Offset b = _hemisphereMm[(s + 1) % n];
      final Offset ab = b - a;
      final double l2 = ab.distanceSquared;
      final double t = l2 <= 0
          ? 0
          : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
      best = math.min(best, (p - (a + ab * t)).distance);
    }
    return best;
  }

  /// The clefts down the sulci's middles, as bands to fill: the major
  /// sulci's and the minor's, each narrowing to nothing at an end that lies
  /// inside the face.
  late final (Path, Path) creases = () {
    final Path major = Path();
    final Path minor = Path();
    for (int index = 0; index < BrainAnatomy.sulci.length; index++) {
      final BrainSulcus sulcus = BrainAnatomy.sulci[index];
      final List<Offset> line = _sulcusLines[index];
      final List<double> along = <double>[0];
      for (int s = 1; s < line.length; s++) {
        along.add(along.last + (line[s] - line[s - 1]).distance);
      }
      final double total = along.last;
      final bool startOpen = _edgeDistance(line.first) > BrainStyle.sulcusTaper;
      final bool endOpen = _edgeDistance(line.last) > BrainStyle.sulcusTaper;
      final double half =
          (sulcus.major ? BrainStyle.crease : BrainStyle.minorCrease) / 2;
      final List<Offset> left = <Offset>[];
      final List<Offset> right = <Offset>[];
      final int n = line.length;
      for (int i = 0; i < n; i++) {
        final Offset t =
            line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)];
        final Offset across = Offset(-t.dy, t.dx) / t.distance;
        double w = half;
        if (startOpen) {
          w *= _smooth(along[i] / BrainStyle.sulcusTaper);
        }
        if (endOpen) {
          w *= _smooth((total - along[i]) / BrainStyle.sulcusTaper);
        }
        left.add(place(line[i] + across * w));
        right.add(place(line[i] - across * w));
      }
      (sulcus.major ? major : minor).addPolygon(<Offset>[
        ...left,
        ...right.reversed,
      ], true);
    }
    return (major, minor);
  }();

  // The core.

  /// The parts drawn as lit meshes, each in its own outline: the cut faces
  /// cushioned a little, the third ventricle's walls and the pituitary as
  /// domes. The septum and the fourth ventricle are drawn flat.
  static const List<BrainPart> meshed = <BrainPart>[
    BrainPart.thalamus,
    BrainPart.hypothalamus,
    BrainPart.infundibulum,
    BrainPart.pituitaryAnterior,
    BrainPart.pituitaryPosterior,
    BrainPart.chiasm,
    BrainPart.brainstem,
    BrainPart.vermis,
    BrainPart.pineal,
    BrainPart.fornix,
    BrainPart.callosum,
  ];

  static const Set<BrainPart> _walls = <BrainPart>{
    BrainPart.thalamus,
    BrainPart.hypothalamus,
    BrainPart.pituitaryAnterior,
    BrainPart.pituitaryPosterior,
    BrainPart.pineal,
  };

  /// Whether [part] is a surface the cut lays open, rather than cut.
  static bool isWall(BrainPart part) => _walls.contains(part);

  List<Offset> _outlineOf(BrainPart part) => switch (part) {
    BrainPart.vermis => _dense(BrainAnatomy.vermis),
    BrainPart.brainstem => _dense(BrainAnatomy.brainstem),
    BrainPart.fourthVentricle => _dense(BrainAnatomy.fourthVentricle),
    BrainPart.septum => _dense(BrainAnatomy.septum),
    BrainPart.hypothalamus => _dense(BrainAnatomy.hypothalamus),
    BrainPart.thalamus => _dense(BrainAnatomy.thalamus),
    BrainPart.pituitaryAnterior => _dense(BrainAnatomy.pituitaryAnterior),
    BrainPart.pituitaryPosterior => _dense(BrainAnatomy.pituitaryPosterior),
    BrainPart.infundibulum => _infundibulumMm,
    BrainPart.pineal => _dense(BrainAnatomy.pineal),
    BrainPart.fornix => _fornixMm,
    BrainPart.callosum => _dense(BrainAnatomy.callosum),
    BrainPart.chiasm => _dense(BrainAnatomy.chiasm),
  };

  /// [part]'s outline, in the scene.
  Path pathOf(BrainPart part) => switch (part) {
    BrainPart.vermis => vermis,
    BrainPart.brainstem => brainstem,
    BrainPart.fourthVentricle => fourthVentricle,
    BrainPart.septum => septum,
    BrainPart.hypothalamus => hypothalamus,
    BrainPart.thalamus => thalamus,
    BrainPart.pituitaryAnterior => pituitaryAnterior,
    BrainPart.pituitaryPosterior => pituitaryPosterior,
    BrainPart.infundibulum => infundibulum,
    BrainPart.pineal => pineal,
    BrainPart.fornix => fornix,
    BrainPart.callosum => callosum,
    BrainPart.chiasm => chiasm,
  };

  final Map<BrainPart, BrainSurface> _parts = <BrainPart, BrainSurface>{};

  /// [part]'s surface: on a grid over its outline, which way it faces at
  /// each point, its own cushion's.
  BrainSurface surfaceOf(BrainPart part) =>
      _parts.putIfAbsent(part, () => _layPart(part));

  BrainSurface _layPart(BrainPart part) {
    const double cell = BrainStyle.coreCell;
    final List<Offset> outline = _outlineOf(part);
    final Rect box = _bounds(outline).inflate(3 * cell);
    final int columns = (box.width / cell).ceil() + 1;
    final int rows = (box.height / cell).ceil() + 1;
    final BrainSurface surface = BrainSurface(columns, rows);
    final Uint8List inside = _raster(outline, box, cell, columns, rows);
    final Relief relief = Relief(
      outline,
      cell: cell,
      inflation: _walls.contains(part)
          ? BrainStyle.wallInflation
          : BrainStyle.cutInflation,
      sweeps: BrainStyle.reliefSweeps,
    );
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final int k = j * columns + i;
        final Offset at = Offset(box.left + i * cell, box.top + j * cell);
        final Offset p = place(at);
        surface.positions[2 * k] = p.dx;
        surface.positions[2 * k + 1] = p.dy;
        final (double nx, double ny, double nz) = relief.normalAt(at);
        surface.normals[3 * k] = nx;
        surface.normals[3 * k + 1] = ny;
        surface.normals[3 * k + 2] = nz;
        surface.form[k] = nz;
        surface.inside[k] = inside[k];
      }
    }
    return surface;
  }

  /// What lies deep behind the core, between its parts.
  late final Path deep = _path(BrainAnatomy.deep);

  // The arbor vitae.

  /// The vermis's white matter: its core, and a lamina out to each lobule,
  /// branching into its folia, one filled path; the fissures between the
  /// lobules and the grooves between the folia, as lines to stroke.
  late final ({Path white, Path fissures, Path folia, Path outline}) arbor =
      _layArbor();

  ({Path white, Path fissures, Path folia, Path outline}) _layArbor() {
    final List<Offset> outline = _dense(BrainAnatomy.vermis);
    final math.Random random = math.Random(29);
    const Offset core = BrainAnatomy.arborCore;
    final Path white = Path()
      ..addOval(
        Rect.fromCenter(
          center: place(core),
          width: mm(2 * BrainStyle.coreRadiusX),
          height: mm(2 * BrainStyle.coreRadiusY),
        ),
      );
    final List<Offset> tips = <Offset>[];
    void lamina(Offset from, Offset to, double w0, double w1) {
      final Offset d = to - from;
      final double l = d.distance;
      if (l <= 0) {
        return;
      }
      final Offset n = Offset(-d.dy, d.dx) / l;
      final Offset a = place(from + n * (w0 / 2));
      final Offset b = place(to + n * (w1 / 2));
      final Offset c = place(to - n * (w1 / 2));
      final Offset e = place(from - n * (w0 / 2));
      // Wound the way an oval is, so where the two overlap they add.
      white
        ..moveTo(a.dx, a.dy)
        ..lineTo(e.dx, e.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(b.dx, b.dy)
        ..close()
        ..addOval(Rect.fromCircle(center: place(to), radius: mm(w1 / 2)));
    }

    // How far from [from] heading [way] the vermis's surface lies.
    double reach(Offset from, Offset way) {
      double best = double.infinity;
      final int n = outline.length;
      for (int s = 0; s < n; s++) {
        final Offset a = outline[s];
        final Offset b = outline[(s + 1) % n];
        final Offset e = b - a;
        final double denominator = way.dx * e.dy - way.dy * e.dx;
        if (denominator.abs() < 1e-9) {
          continue;
        }
        final Offset q = a - from;
        final double t = (q.dx * e.dy - q.dy * e.dx) / denominator;
        final double u = (q.dx * way.dy - q.dy * way.dx) / denominator;
        if (t > 0 && u >= 0 && u <= 1) {
          best = math.min(best, t);
        }
      }
      return best;
    }

    Offset turned(Offset v, double angle) => Offset(
      v.dx * math.cos(angle) - v.dy * math.sin(angle),
      v.dx * math.sin(angle) + v.dy * math.cos(angle),
    );

    // A lamina out to each lobule, and its branches to the folia either
    // side, turned no further than keeps them in their lobule.
    for (final Offset tip in BrainAnatomy.lobules) {
      final Offset way = (tip - core) / (tip - core).distance;
      final double length = reach(core, way) - BrainStyle.laminaShort;
      if (!length.isFinite || length < 1) {
        continue;
      }
      final Offset end = core + way * length;
      lamina(core, end, BrainStyle.laminaRoot, BrainStyle.laminaTip);
      tips.add(end);
      final int branches = length > 14
          ? 4
          : (length > 9 ? 3 : (length > 5 ? 2 : 0));
      int side = random.nextBool() ? 1 : -1;
      for (int b = 0; b < branches; b++) {
        final double at = 0.38 + 0.5 * (b + 0.5) / branches;
        final Offset root = core + way * (length * at);
        final Offset branch = turned(
          way,
          side *
              (BrainStyle.branchTurn +
                  BrainStyle.branchSpread * random.nextDouble()),
        );
        final double reached = reach(root, branch) - BrainStyle.laminaShort;
        if (reached.isFinite && reached > 1) {
          final Offset to = root + branch * reached;
          lamina(root, to, BrainStyle.branchRoot, BrainStyle.branchTip);
          tips.add(to);
        }
        side = -side;
      }
    }
    // The fissures between the lobules, from the surface in.
    final Path fissures = Path();
    for (final List<Offset> fissure in BrainAnatomy.fissures) {
      fissures.addPath(_open(fissure), Offset.zero);
    }
    // The grooves between the folia: half way between two tips where they
    // meet the surface, pointing in toward the core.
    final List<double> along = <double>[0];
    for (int s = 1; s <= outline.length; s++) {
      along.add(
        along.last + (outline[s % outline.length] - outline[s - 1]).distance,
      );
    }
    double arcOf(Offset p) {
      int best = 0;
      double least = double.infinity;
      for (int s = 0; s < outline.length; s++) {
        final double d = (outline[s] - p).distanceSquared;
        if (d < least) {
          least = d;
          best = s;
        }
      }
      return along[best];
    }

    Offset pointAt(double arc) {
      final double total = along.last;
      final double a = ((arc % total) + total) % total;
      int s = 1;
      while (s < along.length - 1 && along[s] < a) {
        s++;
      }
      final double t = (a - along[s - 1]) / (along[s] - along[s - 1]);
      return Offset.lerp(outline[s - 1], outline[s % outline.length], t)!;
    }

    final List<double> arcs = <double>[
      for (final Offset tip in tips) arcOf(tip),
    ]..sort();
    final Path folia = Path();
    final double total = along.last;
    // Where the edge is notched, and how deep: between two folia, and
    // deeper where a fissure comes up to the surface.
    final List<(double, double)> notches = <(double, double)>[
      for (final List<Offset> fissure in BrainAnatomy.fissures)
        (arcOf(fissure.first), BrainStyle.fissureNotch),
    ];
    for (int k = 0; k < arcs.length; k++) {
      final double a = arcs[k];
      final double b = k + 1 < arcs.length ? arcs[k + 1] : arcs[0] + total;
      final double gap = b - a;
      if (gap < 1.4 || gap > 9) {
        continue;
      }
      final Offset at = pointAt((a + b) / 2);
      // The roof of the fourth ventricle has no folia.
      if ((at - BrainAnatomy.arborCore).distance < 9) {
        continue;
      }
      notches.add((((a + b) / 2) % total, BrainStyle.foliumNotch));
      final Offset inward = (core - at) / (core - at).distance;
      final double depth = math.min(
        BrainStyle.foliumDepth * (0.7 + 0.3 * gap / BrainStyle.foliumStep),
        (core - at).distance * 0.45,
      );
      final Offset from = place(at);
      final Offset to = place(at + inward * depth);
      folia
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
    }
    // The edge, every quarter millimetre, drawn in at each notch.
    final List<Offset> edge = <Offset>[];
    const double step = 0.25;
    for (double a = 0; a < total; a += step) {
      final Offset p = pointAt(a);
      final Offset t = pointAt(a + step) - pointAt(a - step);
      Offset inward = Offset(-t.dy, t.dx) / t.distance;
      if ((core - p).dx * inward.dx + (core - p).dy * inward.dy < 0) {
        inward = -inward;
      }
      double drawn = 0;
      for (final (double at, double depth) in notches) {
        double gap = (a - at).abs();
        gap = math.min(gap, total - gap);
        if (gap < 4 * BrainStyle.notchWidth) {
          final double u = gap / BrainStyle.notchWidth;
          drawn = math.max(drawn, depth * math.exp(-u * u));
        }
      }
      edge.add(place(p + inward * drawn));
    }
    final Path scalloped = Path()..addPolygon(edge, true);
    return (white: white, fissures: fissures, folia: folia, outline: scalloped);
  }

  // The arteries.

  TubeCourse _tube(AnatomyTube tube) => TubeCourse(
    tube,
    place,
    scale,
    mm(BrainStyle.tubeRow),
    bend: BrainStyle.bend,
  );

  late final List<TubeCourse> faceArteries = <TubeCourse>[
    for (final AnatomyTube tube in BrainAnatomy.faceArteries) _tube(tube),
  ];
  late final List<TubeCourse> fossaArteries = <TubeCourse>[
    for (final AnatomyTube tube in BrainAnatomy.fossaArteries) _tube(tube),
  ];

  // The choroid plexus.

  /// The window onto the lateral ventricle: the septum, cut away.
  Path get window => septum;

  /// The window's edge, every half millimetre: each place on it and the way
  /// out of the window there.
  late final List<(Offset, Offset)> windowEdge = () {
    final List<(Offset, Offset)> out = <(Offset, Offset)>[];
    final double step = mm(0.5);
    final double probe = mm(0.3);
    for (final PathMetric metric in window.computeMetrics()) {
      for (double d = 0; d < metric.length; d += step) {
        final Tangent? tangent = metric.getTangentForOffset(d);
        if (tangent == null) {
          continue;
        }
        final Offset v = tangent.vector;
        Offset outward = Offset(-v.dy, v.dx) / v.distance;
        if (window.contains(tangent.position + outward * probe)) {
          outward = -outward;
        }
        out.add((tangent.position, outward));
      }
    }
    return out;
  }();

  /// The plexus's beads along [course]: each its place and radius, in the
  /// scene's units, from [from] at the course's start to [to] at its end.
  List<(Offset, double)> _beads(
    List<Offset> course,
    double from,
    double to,
    int seed,
  ) {
    final List<Offset> line = _curve(course);
    final List<double> along = <double>[0];
    for (int s = 1; s < line.length; s++) {
      along.add(along.last + (line[s] - line[s - 1]).distance);
    }
    final double total = along.last;
    final math.Random random = math.Random(seed);
    final List<(Offset, double)> out = <(Offset, double)>[];
    int s = 1;
    for (double a = 0; a <= total; a += BrainStyle.beadStep) {
      while (s < line.length - 1 && along[s] < a) {
        s++;
      }
      final double t = (a - along[s - 1]) / (along[s] - along[s - 1]);
      final Offset p = Offset.lerp(line[s - 1], line[s], t)!;
      final Offset tangent = line[s] - line[s - 1];
      final Offset across = Offset(-tangent.dy, tangent.dx) / tangent.distance;
      final double r = from + (to - from) * (a / total);
      final Offset jitter = across * ((random.nextDouble() - 0.5) * r);
      out.add((place(p + jitter), mm(r * (0.8 + 0.4 * random.nextDouble()))));
    }
    return out;
  }

  late final List<(Offset, double)> lateralPlexus = _beads(
    BrainAnatomy.lateralPlexus,
    BrainStyle.lateralFront,
    BrainStyle.lateralBack,
    31,
  );
  late final List<(Offset, double)> thirdPlexus = _beads(
    BrainAnatomy.thirdPlexus,
    BrainStyle.thirdBead,
    BrainStyle.thirdBead,
    37,
  );
  late final List<(Offset, double)> fourthPlexus = _beads(
    BrainAnatomy.fourthPlexus,
    BrainStyle.fourthBead,
    BrainStyle.fourthBead,
    41,
  );

  // Helpers.

  /// Which points of a grid lie inside [shape]: by its crossings along each
  /// row.
  static Uint8List _raster(
    List<Offset> shape,
    Rect box,
    double cell,
    int columns,
    int rows,
  ) {
    final Uint8List inside = Uint8List(columns * rows);
    final int n = shape.length;
    for (int j = 0; j < rows; j++) {
      final double y = box.top + j * cell;
      final List<double> crossings = <double>[];
      for (int i = 0; i < n; i++) {
        final Offset a = shape[i];
        final Offset b = shape[(i + 1) % n];
        if ((a.dy <= y) != (b.dy <= y)) {
          crossings.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
        }
      }
      crossings.sort();
      for (int k = 0; k + 1 < crossings.length; k += 2) {
        final int from = ((crossings[k] - box.left) / cell).ceil();
        final int to = ((crossings[k + 1] - box.left) / cell).floor();
        for (int i = math.max(0, from); i <= math.min(columns - 1, to); i++) {
          inside[j * columns + i] = 1;
        }
      }
    }
    return inside;
  }

  static bool _inside(List<Offset> points, Offset p) {
    bool inside = false;
    final int n = points.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final Offset a = points[i];
      final Offset b = points[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static Rect _bounds(List<Offset> points) {
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

  static double _smooth(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}
