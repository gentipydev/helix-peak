import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/cell_archetypes.dart';
import '../contour.dart';
import 'tissue_slide.dart';

/// A line with its length measured along it, so cells can be set along it
/// at even steps: an epithelium's surface.
final class Trail {
  Trail(List<Offset> points, {this.closed = false})
    : points = closed ? <Offset>[...points, points.first] : points {
    double sum = 0;
    _lengths.add(0);
    for (int i = 1; i < this.points.length; i++) {
      sum += (this.points[i] - this.points[i - 1]).distance;
      _lengths.add(sum);
    }
  }

  final List<Offset> points;

  /// Whether the line comes back to where it began.
  final bool closed;
  final List<double> _lengths = <double>[];

  double get length => _lengths.last;

  /// How far along the line its point [index] is.
  double lengthTo(int index) => _lengths[index];

  /// The point [s] along the line: round again past its end where it is
  /// closed, its end otherwise.
  Offset at(double s) {
    final double d = closed ? s % length : s.clamp(0.0, length);
    int low = 0;
    int high = _lengths.length - 1;
    while (high - low > 1) {
      final int middle = (low + high) >> 1;
      if (_lengths[middle] <= d) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final double span = _lengths[high] - _lengths[low];
    return span <= 0
        ? points[low]
        : Offset.lerp(points[low], points[high], (d - _lengths[low]) / span)!;
  }

  /// Which way the line runs at [s], as a unit vector, taken over [window]
  /// either side so a kink does not turn it.
  Offset wayAt(double s, {double window = 2}) {
    final double from = closed ? s - window : math.max(0, s - window);
    final double to = closed ? s + window : math.min(length, s + window);
    final Offset run = at(to) - at(from);
    final double far = run.distance;
    return far <= 0 ? const Offset(1, 0) : run / far;
  }
}

/// What an epithelium laid along a line leaves behind: the line its cells'
/// bases make, the edge of whatever lies under them, and each cell's apex
/// and the way in from it.
typedef Lining = ({List<Offset> inner, List<(Offset, Offset)> cells});

/// The engine every tissue's recipe is written in: seeds and the Voronoi
/// cells round them, cells and nuclei laid in a slide's inks, vessels,
/// fibres, and an epithelium set along a line. All of it in micrometres from
/// the middle of the field, and all of it from one seeded generator, so a
/// tissue is the same slide every time.
final class SlideBuilder {
  SlideBuilder(
    this.slide, {
    required this.field,
    required this.shape,
    required this.target,
    required this.targetNucleus,
    required int seed,
  }) : random = math.Random(seed),
       _salt = seed * 7919 + 17,
       targetPath = target.toPath() {
    targetBounds = targetPath.getBounds();
  }

  final TissueSlide slide;

  /// The field's radius.
  final double field;

  /// The kind of cell the zoom's own is.
  final CellShape shape;

  /// The zoom's own cell and its nucleus, at the origin.
  final Contour target;
  final Contour targetNucleus;
  final Path targetPath;
  late final Rect targetBounds;

  final math.Random random;
  final int _salt;
  final List<(Offset, double, int)> _kept = <(Offset, double, int)>[];

  // -- chance ---------------------------------------------------------------

  double get roll => random.nextDouble();

  double between(double a, double b) => a + (b - a) * random.nextDouble();

  bool chance(double share) => random.nextDouble() < share;

  /// A point anywhere in a round field of [radius].
  Offset anywhere([double? radius]) {
    final double r = (radius ?? field) * math.sqrt(random.nextDouble());
    return unit(between(0, 2 * math.pi)) * r;
  }

  /// A value that varies smoothly from place to place, from 0 to 1, over
  /// about [cell] micrometres: what clusters one kind of cell together.
  double noise(Offset p, double cell) {
    final double x = p.dx / cell;
    final double y = p.dy / cell;
    final int ix = x.floor();
    final int iy = y.floor();
    final double fx = x - ix;
    final double fy = y - iy;
    final double sx = fx * fx * (3 - 2 * fx);
    final double sy = fy * fy * (3 - 2 * fy);
    double mix(double a, double b, double t) => a + (b - a) * t;
    return mix(
      mix(_hash(ix, iy), _hash(ix + 1, iy), sx),
      mix(_hash(ix, iy + 1), _hash(ix + 1, iy + 1), sx),
      sy,
    );
  }

  double _hash(int x, int y) {
    int h = (x * 374761393 + y * 668265263 + _salt * 144665) & 0x7fffffff;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
    h = h ^ (h >> 16);
    return (h & 0xffffff) / 0x1000000;
  }

  // -- where things may go --------------------------------------------------

  /// Whether [p] is in the field, or within [margin] of it.
  bool near(Offset p, [double margin = 0]) => p.distance <= field + margin;

  /// Whether [p] is on the zoom's own cell, or within [margin] of it.
  bool onTarget(Offset p, [double margin = 0]) {
    if (!targetBounds.inflate(margin).contains(p)) {
      return false;
    }
    if (targetPath.contains(p)) {
      return true;
    }
    if (margin <= 0) {
      return false;
    }
    for (int k = 0; k < 8; k++) {
      if (targetPath.contains(p + unit(k * math.pi / 4) * margin)) {
        return true;
      }
    }
    return false;
  }

  /// Keeps a round place of [radius] at [centre] for something laid
  /// separately: no cell of layer [upTo] or below is laid there.
  void keep(Offset centre, double radius, {int upTo = TissueSlide.own}) =>
      _kept.add((centre, radius, upTo));

  /// Whether [p] is in a place kept from layer [layer], or within [margin]
  /// of one.
  bool kept(Offset p, [double margin = 0, int layer = TissueSlide.tissue]) {
    for (final (Offset c, double r, int upTo) in _kept) {
      if (upTo >= layer && (p - c).distance < r + margin) {
        return true;
      }
    }
    return false;
  }

  /// Whether something small may be laid at [p]: in the field, off the
  /// zoom's cell and out of every kept place, by [margin].
  bool free(Offset p, [double margin = 0, int layer = TissueSlide.tissue]) =>
      near(p, 12) && !onTarget(p, margin) && !kept(p, margin, layer);

  // -- inks -----------------------------------------------------------------

  /// The path [of] is drawn from in [layer], to add to.
  Path ink(SlideInk of, [int layer = TissueSlide.tissue]) =>
      slide.layers[layer].of(of);

  // -- geometry -------------------------------------------------------------

  /// The unit vector at [angle].
  Offset unit(double angle) => Offset(math.cos(angle), math.sin(angle));

  /// [v] turned a quarter turn: for a line running clockwise on screen, the
  /// way into what it encloses.
  Offset turned(Offset v) => Offset(-v.dy, v.dx);

  /// The middle of [poly], by its area.
  Offset centroid(List<Offset> poly) {
    double area = 0;
    double cx = 0;
    double cy = 0;
    for (int i = 0; i < poly.length; i++) {
      final Offset p = poly[i];
      final Offset q = poly[(i + 1) % poly.length];
      final double cross = p.dx * q.dy - q.dx * p.dy;
      area += cross;
      cx += (p.dx + q.dx) * cross;
      cy += (p.dy + q.dy) * cross;
    }
    if (area.abs() < 1e-9) {
      Offset sum = Offset.zero;
      for (final Offset p in poly) {
        sum += p;
      }
      return poly.isEmpty ? Offset.zero : sum / poly.length.toDouble();
    }
    return Offset(cx / (3 * area), cy / (3 * area));
  }

  /// [poly] as a closed path with straight sides.
  Path polygon(List<Offset> poly) {
    final Path path = Path();
    if (poly.isEmpty) {
      return path;
    }
    path.moveTo(poly.first.dx, poly.first.dy);
    for (int i = 1; i < poly.length; i++) {
      path.lineTo(poly[i].dx, poly[i].dy);
    }
    return path..close();
  }

  /// [points] as an open path.
  Path polyline(List<Offset> points) {
    final Path path = Path();
    if (points.isEmpty) {
      return path;
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  /// [poly] drawn in toward [about] (its own middle by default) by [shrink]
  /// and its corners rounded, each over [corner] of the shorter side at it:
  /// the outline of a cell among its neighbours. With [steps], each corner
  /// is that many points.
  List<Offset> roundedPoints(
    List<Offset> poly, {
    double shrink = 1,
    double corner = 0.3,
    Offset? about,
    int steps = 4,
  }) {
    final Offset c = about ?? centroid(poly);
    final List<Offset> p = <Offset>[];
    for (final Offset q in poly) {
      final Offset moved = c + (q - c) * shrink;
      if (p.isEmpty || (moved - p.last).distance > 1e-6) {
        p.add(moved);
      }
    }
    if (p.length > 1 && (p.first - p.last).distance <= 1e-6) {
      p.removeLast();
    }
    final int n = p.length;
    if (n < 3) {
      return p;
    }
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < n; i++) {
      final Offset before = p[(i - 1 + n) % n];
      final Offset at = p[i];
      final Offset after = p[(i + 1) % n];
      final double cut =
          math.min((before - at).distance, (after - at).distance) *
          corner.clamp(0.0, 0.5);
      final Offset from = at + (before - at) / (before - at).distance * cut;
      final Offset to = at + (after - at) / (after - at).distance * cut;
      for (int k = 0; k <= steps; k++) {
        final double t = k / steps;
        final double a = (1 - t) * (1 - t);
        final double b = 2 * t * (1 - t);
        out.add(from * a + at * b + to * (t * t));
      }
    }
    return out;
  }

  /// [roundedPoints] as a path, each corner one curve.
  Path rounded(
    List<Offset> poly, {
    double shrink = 1,
    double corner = 0.3,
    Offset? about,
  }) {
    final Offset c = about ?? centroid(poly);
    final List<Offset> p = <Offset>[];
    for (final Offset q in poly) {
      final Offset moved = c + (q - c) * shrink;
      if (p.isEmpty || (moved - p.last).distance > 1e-6) {
        p.add(moved);
      }
    }
    if (p.length > 1 && (p.first - p.last).distance <= 1e-6) {
      p.removeLast();
    }
    final Path path = Path();
    final int n = p.length;
    if (n < 3) {
      return path;
    }
    for (int i = 0; i < n; i++) {
      final Offset before = p[(i - 1 + n) % n];
      final Offset at = p[i];
      final Offset after = p[(i + 1) % n];
      final double cut =
          math.min((before - at).distance, (after - at).distance) *
          corner.clamp(0.0, 0.5);
      final Offset from = at + (before - at) / (before - at).distance * cut;
      final Offset to = at + (after - at) / (after - at).distance * cut;
      if (i == 0) {
        path.moveTo(from.dx, from.dy);
      } else {
        path.lineTo(from.dx, from.dy);
      }
      path.quadraticBezierTo(at.dx, at.dy, to.dx, to.dy);
    }
    return path..close();
  }

  /// Adds an ellipse at [c] to [into], [along] and [across] its half-axes,
  /// its long axis turned to [turn].
  void ellipse(
    Path into,
    Offset c,
    double along,
    double across, [
    double turn = 0,
  ]) {
    if (turn == 0) {
      into.addOval(
        Rect.fromCenter(center: c, width: along * 2, height: across * 2),
      );
      return;
    }
    final double ca = math.cos(turn);
    final double sa = math.sin(turn);
    Offset at(double x, double y) =>
        c + Offset(x * ca - y * sa, x * sa + y * ca);
    const double k = 0.5522847498;
    void arc(double x1, double y1, double x2, double y2, double x3, double y3) {
      final Offset a = at(x1, y1);
      final Offset b = at(x2, y2);
      final Offset e = at(x3, y3);
      into.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
    }

    final Offset start = at(along, 0);
    into.moveTo(start.dx, start.dy);
    arc(along, across * k, along * k, across, 0, across);
    arc(-along * k, across, -along, across * k, -along, 0);
    arc(-along, -across * k, -along * k, -across, 0, -across);
    arc(along * k, -across, along, -across * k, along, 0);
    into.close();
  }

  /// A smooth line through [through], [steps] points to each stretch.
  List<Offset> smooth(
    List<Offset> through, {
    int steps = 10,
    bool closed = false,
  }) {
    final int n = through.length;
    if (n < 3) {
      return through;
    }
    Offset point(int i) =>
        closed ? through[(i % n + n) % n] : through[i.clamp(0, n - 1)];
    final List<Offset> out = <Offset>[];
    final int stretches = closed ? n : n - 1;
    for (int i = 0; i < stretches; i++) {
      final Offset p0 = point(i - 1);
      final Offset p1 = point(i);
      final Offset p2 = point(i + 1);
      final Offset p3 = point(i + 2);
      for (int k = 0; k < steps; k++) {
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
    if (!closed) {
      out.add(through.last);
    }
    return out;
  }

  /// The outline of a band along [spine], [half] wide either side at each
  /// share of the way along it.
  List<Offset> ribbon(List<Offset> spine, double Function(double share) half) {
    final int n = spine.length;
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i < n; i++) {
      final Offset run =
          spine[math.min(i + 1, n - 1)] - spine[math.max(i - 1, 0)];
      final double far = run.distance;
      final Offset side = far <= 0 ? const Offset(0, 1) : turned(run / far);
      final double w = half(n == 1 ? 0 : i / (n - 1));
      left.add(spine[i] + side * w);
      right.add(spine[i] - side * w);
    }
    return <Offset>[...left, ...right.reversed];
  }

  // -- seeds and their cells ------------------------------------------------

  /// Seeds on a hexagonal lattice of [step], each moved by up to [jitter]
  /// of a step, out to [beyond] steps past the field so that every cell in
  /// the field has neighbours all round. One lattice point lies at [pin];
  /// where [pinned], it is not moved and comes first. [where] keeps only the
  /// seeds it passes.
  List<Offset> lattice(
    double step, {
    double jitter = 0.35,
    Offset pin = Offset.zero,
    bool pinned = false,
    double beyond = 3,
    bool Function(Offset p)? where,
  }) {
    final List<Offset> seeds = <Offset>[if (pinned) pin];
    final double rise = step * 0.8660254;
    final double reach = field + beyond * step;
    final int n = ((reach + pin.distance) / rise).ceil() + 1;
    for (int row = -n; row <= n; row++) {
      for (int col = -n; col <= n; col++) {
        final bool first = row == 0 && col == 0;
        if (first && pinned) {
          continue;
        }
        final Offset p =
            pin +
            Offset(
              (col + (row.isOdd ? 0.5 : 0) + (roll - 0.5) * jitter) * step,
              (row + (roll - 0.5) * jitter) * rise,
            );
        if (p.distance < reach && (where == null || where(p))) {
          seeds.add(p);
        }
      }
    }
    return seeds;
  }

  /// Each seed's Voronoi cell: the ground nearer to it than to any other,
  /// no farther than [reach] from it. Clockwise on screen.
  List<List<Offset>> voronoi(List<Offset> seeds, double reach) {
    final Map<int, List<int>> grid = <int, List<int>>{};
    int key(int gx, int gy) => (gx + 4096) * 8192 + (gy + 4096);
    for (int i = 0; i < seeds.length; i++) {
      grid
          .putIfAbsent(
            key((seeds[i].dx / reach).floor(), (seeds[i].dy / reach).floor()),
            () => <int>[],
          )
          .add(i);
    }
    final List<List<Offset>> cells = <List<Offset>>[];
    for (int i = 0; i < seeds.length; i++) {
      final Offset s = seeds[i];
      List<Offset> poly = <Offset>[
        s + Offset(-reach, -reach),
        s + Offset(reach, -reach),
        s + Offset(reach, reach),
        s + Offset(-reach, reach),
      ];
      final int gx = (s.dx / reach).floor();
      final int gy = (s.dy / reach).floor();
      for (int dx = -1; dx <= 1 && poly.isNotEmpty; dx++) {
        for (int dy = -1; dy <= 1 && poly.isNotEmpty; dy++) {
          for (final int j in grid[key(gx + dx, gy + dy)] ?? const <int>[]) {
            if (j == i) {
              continue;
            }
            poly = _nearer(poly, s, seeds[j]);
            if (poly.isEmpty) {
              break;
            }
          }
        }
      }
      cells.add(poly);
    }
    return cells;
  }

  /// The part of [poly] nearer to [a] than to [b].
  static List<Offset> _nearer(List<Offset> poly, Offset a, Offset b) {
    final Offset normal = b - a;
    final double limit = (b.distanceSquared - a.distanceSquared) / 2;
    double side(Offset p) => p.dx * normal.dx + p.dy * normal.dy - limit;
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < poly.length; i++) {
      final Offset p = poly[i];
      final Offset q = poly[(i + 1) % poly.length];
      final double sp = side(p);
      final double sq = side(q);
      if (sp <= 0) {
        out.add(p);
      }
      if ((sp <= 0) != (sq <= 0)) {
        out.add(Offset.lerp(p, q, sp / (sp - sq))!);
      }
    }
    return out;
  }

  /// [seeds] each moved to the middle of its own cell, [times] over, so the
  /// cells even out as packed cells do. The first [fixed] stay where they
  /// are.
  List<Offset> relaxed(
    List<Offset> seeds,
    double reach, {
    int times = 2,
    int fixed = 0,
  }) {
    List<Offset> out = seeds;
    for (int t = 0; t < times; t++) {
      final List<List<Offset>> cells = voronoi(out, reach);
      out = <Offset>[
        for (int i = 0; i < out.length; i++)
          i < fixed || cells[i].length < 3 ? out[i] : centroid(cells[i]),
      ];
    }
    return out;
  }

  // -- what a slide is made of ----------------------------------------------

  /// Lays one cell: [poly] drawn in a little and its corners rounded, in
  /// [fill], with its border and a nucleus of radius [nucleus] (none at 0)
  /// at [nucleusAt], its middle by default. Returns false, laying nothing,
  /// where the cell's middle is more than [reach] outside the field, on the
  /// zoom's own cell, or in a kept place.
  bool cell(
    List<Offset> poly,
    SlideInk fill, {
    int layer = TissueSlide.tissue,
    double shrink = 0.94,
    double corner = 0.3,
    double nucleus = 3,
    double? nucleusAcross,
    double nucleusTurn = 0,
    Offset? nucleusAt,
    SlideInk nucleusInk = SlideInk.nucleus1,
    bool nucleolus = false,
    bool border = true,
    double reach = 24,
  }) {
    if (poly.length < 3) {
      return false;
    }
    final Offset c = centroid(poly);
    if (!near(c, reach) || onTarget(c) || kept(c, 0, layer)) {
      return false;
    }
    final Path path = rounded(poly, shrink: shrink, corner: corner);
    ink(fill, layer).addPath(path, Offset.zero);
    if (border) {
      ink(SlideInk.border, layer).addPath(path, Offset.zero);
    }
    if (nucleus > 0) {
      this.nucleus(
        nucleusAt ?? c,
        nucleus,
        across: nucleusAcross,
        turn: nucleusTurn,
        ink: nucleusInk,
        layer: layer,
        nucleolus: nucleolus,
      );
    }
    return true;
  }

  /// A nucleus at [at], [along] its half-length and [across] its
  /// half-width, its long axis at [turn]; with [nucleolus], a dark dot in
  /// it. Not laid on the zoom's own cell.
  void nucleus(
    Offset at,
    double along, {
    double? across,
    double turn = 0,
    SlideInk ink = SlideInk.nucleus1,
    int layer = TissueSlide.tissue,
    bool nucleolus = false,
  }) {
    final double short = across ?? along * 0.9;
    if (layer != TissueSlide.own && onTarget(at, math.min(along, short))) {
      return;
    }
    ellipse(this.ink(ink, layer), at, along, short, turn);
    if (nucleolus) {
      ellipse(
        this.ink(SlideInk.nucleus2, layer),
        at + unit(turn + 0.9) * short * 0.3,
        short * 0.26,
        short * 0.26,
      );
    }
  }

  /// A red cell at [at].
  void red(Offset at, {double r = 3.5, int layer = TissueSlide.tissue}) {
    if (layer != TissueSlide.own && onTarget(at, r)) {
      return;
    }
    ellipse(ink(SlideInk.blood, layer), at, r, r * 0.9, between(0, math.pi));
  }

  /// A fibre along [through].
  void fibre(List<Offset> through, {int layer = TissueSlide.tissue}) {
    ink(SlideInk.fibre, layer).addPath(polyline(through), Offset.zero);
  }

  /// A wavy fibre from [from], [length] long, heading [angle].
  void strand(
    Offset from,
    double angle,
    double length, {
    double wave = 1.6,
    int layer = TissueSlide.tissue,
  }) {
    final Offset way = unit(angle);
    final Offset side = turned(way);
    final double phase = between(0, 2 * math.pi);
    final int n = math.max(2, (length / 6).round());
    fibre(<Offset>[
      for (int i = 0; i <= n; i++)
        from +
            way * (length * i / n) +
            side * (math.sin(phase + i * 0.9) * wave),
    ], layer: layer);
  }

  /// A small vessel cut across at [at], [r] inside: flat nuclei in its
  /// wall, red cells in it, and a muscular wall [wall] thick where set.
  void vessel(
    Offset at,
    double r, {
    double wall = 0,
    double filled = 0.5,
    int layer = TissueSlide.tissue,
  }) {
    final double squash = between(0.8, 0.96);
    final double turn = between(0, math.pi);
    if (wall > 0) {
      ellipse(
        ink(SlideInk.eosin2, layer),
        at,
        r + wall,
        (r + wall) * squash,
        turn,
      );
    }
    ellipse(ink(SlideInk.clear, layer), at, r, r * squash, turn);
    final int lining = math.max(2, (2 * math.pi * r / 17).round());
    final double first = between(0, 2 * math.pi);
    final double ca = math.cos(turn);
    final double sa = math.sin(turn);
    Offset placed(Offset p) =>
        at + Offset(p.dx * ca - p.dy * sa, p.dx * sa + p.dy * ca);
    for (int k = 0; k < lining; k++) {
      final double a = first + 2 * math.pi * k / lining + between(-0.3, 0.3);
      nucleus(
        placed(
          Offset(math.cos(a) * (r + 0.7), math.sin(a) * (r * squash + 0.7)),
        ),
        3.3,
        across: 1.1,
        turn: turn + math.atan2(math.cos(a) * squash, -math.sin(a)),
        ink: SlideInk.nucleus2,
        layer: layer,
      );
    }
    final int reds = (filled * r * r / 13).round().clamp(0, 16);
    for (int k = 0; k < reds; k++) {
      final Offset p = unit(between(0, 2 * math.pi)) * math.sqrt(roll);
      red(
        placed(
          Offset(
            p.dx * math.max(0, r - 3.2),
            p.dy * math.max(0, r * squash - 3.2),
          ),
        ),
        r: math.min(3.4, r * 0.55),
        layer: layer,
      );
    }
    keep(at, r + wall + 2);
  }

  /// A capillary along [spine], [width] across: a clear channel with flat
  /// nuclei at its edge and red cells in it.
  void capillary(
    List<Offset> spine,
    double width, {
    int layer = TissueSlide.tissue,
    double reds = 0.5,
  }) {
    ink(SlideInk.clear, layer).addPath(
      Contour(ribbon(spine, (double _) => width / 2)).toPath(),
      Offset.zero,
    );
    final Trail trail = Trail(spine);
    for (double s = between(3, 14); s < trail.length; s += between(13, 26)) {
      final Offset at = trail.at(s);
      final Offset way = trail.wayAt(s);
      if (chance(reds)) {
        red(at, r: math.min(3.2, width * 0.42), layer: layer);
      } else {
        nucleus(
          at + turned(way) * (chance(0.5) ? 1 : -1) * (width / 2 + 0.4),
          3.4,
          across: 1.05,
          turn: way.direction,
          ink: SlideInk.nucleus2,
          layer: layer,
        );
      }
    }
    // A channel wider than one red cell is full of them.
    for (double s = 2; width > 9 && s < trail.length; s += 3.4) {
      if (chance(reds)) {
        red(
          trail.at(s) +
              turned(trail.wayAt(s)) * between(-width / 2 + 3, width / 2 - 3),
          r: 3.2,
          layer: layer,
        );
      }
    }
    for (double s = 0; s <= trail.length; s += width * 0.7) {
      keep(trail.at(s), width / 2 + 1.5);
    }
  }

  /// A fat cell filling [poly]: clear, with a thin rim, and where the
  /// section passes through it, its nucleus pressed flat against the rim.
  void lard(List<Offset> poly, {int layer = TissueSlide.tissue}) {
    if (poly.length < 3) {
      return;
    }
    final Offset c = centroid(poly);
    if (!near(c, 70) || onTarget(c) || kept(c, 0, layer)) {
      return;
    }
    ink(
      SlideInk.eosin1,
      layer,
    ).addPath(rounded(poly, shrink: 0.985, corner: 0.42), Offset.zero);
    ink(
      SlideInk.clear,
      layer,
    ).addPath(rounded(poly, shrink: 0.935, corner: 0.45), Offset.zero);
    if (chance(0.4)) {
      final int side = random.nextInt(poly.length);
      final Offset a = poly[side];
      final Offset b = poly[(side + 1) % poly.length];
      final Offset middle = Offset.lerp(a, b, between(0.35, 0.65))!;
      nucleus(
        Offset.lerp(c, middle, 0.955)!,
        4.6,
        across: 1.25,
        turn: (b - a).direction,
        ink: SlideInk.nucleus2,
        layer: layer,
      );
    }
  }

  /// A gland or duct cut across at [c]: [count] cells in a ring from its
  /// lumen (of radius [lumen]) out to [outer], the first of them toward
  /// [turn]. [look] gives each cell's ink and where its nucleus lies from
  /// the lumen (0) to the outside (1); a null ink leaves the cell out.
  void ring(
    Offset c, {
    required double lumen,
    required double outer,
    required int count,
    required double turn,
    required (SlideInk?, double, SlideInk) Function(int k) look,
    int layer = TissueSlide.tissue,
    double nucleus = 3,
    bool open = true,
  }) {
    for (int k = 0; k < count; k++) {
      final double a0 = turn + 2 * math.pi * (k - 0.5) / count;
      final double a1 = turn + 2 * math.pi * (k + 0.5) / count;
      final double am = turn + 2 * math.pi * k / count;
      final (SlideInk? fill, double seat, SlideInk dye) = look(k);
      if (fill == null) {
        continue;
      }
      cell(
        <Offset>[
          c + unit(a0) * lumen,
          c + unit(a1) * lumen,
          c + unit(a1) * outer,
          c + unit(a0) * outer,
        ],
        fill,
        layer: layer,
        shrink: 0.96,
        corner: 0.18,
        nucleus: nucleus,
        nucleusAt: c + unit(am) * (lumen + (outer - lumen) * seat),
        nucleusInk: dye,
      );
    }
    if (open) {
      ellipse(ink(SlideInk.clear, layer), c, lumen * 0.97, lumen * 0.97);
    }
  }

  /// Lays an epithelium one cell deep along [trail], which runs clockwise
  /// on screen round what the cells enclose (or left to right over what
  /// lies under them): each cell [width] along it and [height] in from it.
  ///
  /// With [anchor], a cell [anchorWidth] wide is centred that far along the
  /// trail and left out: the zoom's own cell stands there. [fill] gives each
  /// cell's ink by its place in line.
  Lining epithelium(
    Trail trail, {
    required double width,
    required double height,
    required SlideInk Function(int index) fill,
    int layer = TissueSlide.tissue,
    double nucleus = 2.8,
    double nucleusLong = 1,
    double nucleusAt = 0.58,
    SlideInk nucleusInk = SlideInk.nucleus1,
    double cilia = 0,
    double? anchor,
    double anchorWidth = 0,
    double corner = 0.15,
    double shrink = 0.96,
  }) {
    // Where each cell begins and ends along the trail; the anchored one
    // last.
    final List<(double, double)> spans = <(double, double)>[];
    final double length = trail.length;
    if (trail.closed) {
      final double start = anchor == null ? 0 : anchor + anchorWidth / 2;
      final double run = length - (anchor == null ? 0 : anchorWidth);
      final int n = math.max(3, (run / width).round());
      for (int k = 0; k < n; k++) {
        spans.add((start + run * k / n, start + run * (k + 1) / n));
      }
    } else {
      final double from = anchor == null ? 0 : anchor + anchorWidth / 2;
      for (double s = from; s + width * 0.5 < length; s += width) {
        spans.add((s, s + width));
      }
      if (anchor != null) {
        for (
          double s = anchor - anchorWidth / 2;
          s - width * 0.5 > 0;
          s -= width
        ) {
          spans.add((s - width, s));
        }
      }
      spans.sort(
        ((double, double) a, (double, double) b) => a.$1.compareTo(b.$1),
      );
    }
    if (anchor != null) {
      spans.add((anchor - anchorWidth / 2, anchor + anchorWidth / 2));
    }
    final List<(double, Offset)> inner = <(double, Offset)>[];
    final List<(Offset, Offset)> cells = <(Offset, Offset)>[];
    (double, Offset)? last;
    for (int i = 0; i < spans.length; i++) {
      final (double s0, double s1) = spans[i];
      final bool own = anchor != null && i == spans.length - 1;
      final Offset p0 = trail.at(s0);
      final Offset p1 = trail.at(s1);
      final Offset in0 = turned(trail.wayAt(s0));
      final Offset in1 = turned(trail.wayAt(s1));
      final Offset q0 = p0 + in0 * height;
      final Offset q1 = p1 + in1 * height;
      inner.add((s0, q0));
      if (!trail.closed && (last == null || s1 > last.$1)) {
        last = (s1, q1);
      }
      final Offset middle = (p0 + p1) / 2;
      final Offset sum = in0 + in1;
      final Offset inward = sum.distance <= 0 ? in0 : sum / sum.distance;
      if (own || !near(middle, height + width)) {
        continue;
      }
      final bool laid = cell(
        <Offset>[p0, p1, q1, q0],
        fill(i),
        layer: layer,
        shrink: shrink,
        corner: corner,
        nucleus: nucleus * nucleusLong,
        nucleusAcross: math.min(nucleus, width * 0.42),
        nucleusTurn: inward.direction,
        nucleusAt: middle + inward * (height * nucleusAt),
        nucleusInk: nucleusInk,
      );
      if (!laid) {
        continue;
      }
      cells.add((middle, inward));
      if (cilia > 0) {
        for (final double t in <double>[0.2, 0.5, 0.8]) {
          final Offset from = Offset.lerp(p0, p1, t)!;
          fibre(<Offset>[from, from - inward * cilia], layer: layer);
        }
      }
    }
    if (last != null) {
      inner.add(last);
    }
    inner.sort(
      ((double, Offset) a, (double, Offset) b) => a.$1.compareTo(b.$1),
    );
    return (
      inner: <Offset>[for (final (double _, Offset p) in inner) p],
      cells: cells,
    );
  }

  /// Fills [region] with a loose connective tissue's small things: [nuclei]
  /// spindle nuclei, [fibres] wavy fibres running about [flow], and
  /// [vessels] small vessels.
  void stroma(
    Path region, {
    int nuclei = 60,
    int fibres = 40,
    int vessels = 0,
    double flow = 0,
    double sway = 0.5,
    int layer = TissueSlide.ground,
  }) {
    final Rect box = region.getBounds().intersect(
      Rect.fromCircle(center: Offset.zero, radius: field + 10),
    );
    Offset somewhere() =>
        Offset(between(box.left, box.right), between(box.top, box.bottom));
    for (int k = 0, laid = 0; k < vessels * 30 && laid < vessels; k++) {
      final Offset p = somewhere();
      final double r = between(4.5, 9);
      if (region.contains(p) &&
          region.contains(p + Offset(r + 4, 0)) &&
          region.contains(p - Offset(r + 4, 0)) &&
          region.contains(p + Offset(0, r + 4)) &&
          region.contains(p - Offset(0, r + 4)) &&
          free(p, r + 4)) {
        vessel(p, r, layer: layer);
        laid++;
      }
    }
    for (int k = 0, laid = 0; k < fibres * 8 && laid < fibres; k++) {
      final Offset p = somewhere();
      final double heading = flow + between(-sway, sway);
      final double length = between(22, 55);
      // A fibre lies wholly in the tissue it is of.
      if (region.contains(p) &&
          region.contains(p + unit(heading) * (length / 2)) &&
          region.contains(p + unit(heading) * length) &&
          near(p)) {
        strand(p, heading, length, layer: layer);
        laid++;
      }
    }
    for (int k = 0, laid = 0; k < nuclei * 6 && laid < nuclei; k++) {
      final Offset p = somewhere();
      if (region.contains(p) && free(p, 3)) {
        nucleus(
          p,
          between(4, 5.6),
          across: between(1.1, 1.6),
          turn: flow + between(-sway, sway),
          ink: chance(0.6) ? SlideInk.nucleus2 : SlideInk.nucleus1,
          layer: layer,
        );
        laid++;
      }
    }
  }

  /// The zoom's own cell at the origin, over everything: its outline in
  /// [fill] and its nucleus in [nucleus]. With [apex], the top [apexShare]
  /// of it is in that ink instead; with [hollow], all but its rim is clear,
  /// as a fat cell is.
  void own(
    SlideInk fill, {
    SlideInk nucleus = SlideInk.nucleus1,
    SlideInk? apex,
    double apexShare = 0.45,
    double hollow = 0,
    bool nucleolus = false,
    bool border = true,
  }) {
    final SlideLayer layer = slide.layers[TissueSlide.own];
    final Rect box = targetBounds;
    if (apex == null) {
      layer.of(fill).addPath(targetPath, Offset.zero);
    } else {
      final Path top = Path()
        ..addRect(
          Rect.fromLTRB(
            box.left - 1,
            box.top - 1,
            box.right + 1,
            box.top + box.height * apexShare,
          ),
        );
      layer
          .of(fill)
          .addPath(
            Path.combine(PathOperation.difference, targetPath, top),
            Offset.zero,
          );
      layer
          .of(apex)
          .addPath(
            Path.combine(PathOperation.intersect, targetPath, top),
            Offset.zero,
          );
    }
    if (hollow > 0) {
      final Offset c = box.center;
      layer
          .of(SlideInk.clear)
          .addPath(
            Contour(<Offset>[
              for (final Offset p in target.points) c + (p - c) * hollow,
            ]).toPath(),
            Offset.zero,
          );
    }
    if (border) {
      layer.of(SlideInk.border).addPath(targetPath, Offset.zero);
    }
    final Path core = targetNucleus.toPath();
    layer.of(nucleus).addPath(core, Offset.zero);
    if (nucleolus) {
      final Rect inside = core.getBounds();
      ellipse(
        layer.of(SlideInk.nucleus2),
        inside.center + Offset(-inside.width * 0.14, -inside.height * 0.1),
        inside.shortestSide * 0.13,
        inside.shortestSide * 0.13,
      );
    }
  }
}
