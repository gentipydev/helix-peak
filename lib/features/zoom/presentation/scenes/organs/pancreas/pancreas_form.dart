import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../relief.dart';
import '../../tube_course.dart';
import 'pancreas_anatomy.dart';
import 'pancreas_style.dart';

/// The pancreas as the zoom's organ scene draws it, and what lies round it:
/// every shape in the scene's units at the gland's real size, its middle at
/// the origin.
///
/// The gland is drawn from general anatomy ([PancreasAnatomy]), as wide as
/// the anatomogram's own outline grows to, about the same middle; the place
/// its tissue is sampled stays the anatomogram's ([site]), which lies in
/// its head. The step from the body draws the anatomogram's outline in
/// toward this one ([outlineAt]). Everything here is geometry: what it is
/// drawn in is `PancreasArt`'s.
final class PancreasForm {
  PancreasForm({
    required List<Offset> diagram,
    required this.site,
    required double width,
    required this.view,
  }) {
    // The template's own box, on the curve it is drawn by.
    final List<Offset> dense = const Contour(PancreasAnatomy.outline)
        .sampled(PancreasStyle.outlineSpan)
        .points;
    final Rect cm = _bounds(dense);
    _centre = cm.center;
    scale = width / cm.width;
    final List<Offset> placed = <Offset>[
      for (final Offset p in PancreasAnatomy.outline) place(p),
    ];
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(PancreasStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool flip = _area(dense).sign != _area(diagramDense).sign;
    final List<Offset> template = flip ? placed.reversed.toList() : placed;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(PancreasStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _inward = _area(outlinePoints) > 0 ? 1.0 : -1.0;
    // The two outlines met at two places they both have: the top of the
    // tail and the outer edge of the head.
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: PancreasStyle.morphPoints,
      bed: mm(PancreasStyle.bed * PancreasStyle.lobule),
    );
  }

  /// The form for [anatomy]'s pancreas, where the body draws it as [part],
  /// in a view [view] metres across.
  factory PancreasForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return PancreasForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      width: anatomy.metres / view,
      view: view,
    );
  }

  /// Where the tissue is sampled: the anatomogram's own place for it.
  final Offset site;

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's centimetres, in the scene's units.
  late final double scale;

  late final Offset _centre;

  /// The gland's outline, smooth, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// Which way into the gland the outline's left hand points: 1 or -1.
  late final double _inward;

  /// The body's outline of the gland drawn in toward the gland's.
  late final OutlineMorph _morph;

  /// A point of the anatomy, in centimetres, in the scene.
  Offset place(Offset cm) => (cm - _centre) * scale;

  /// A point of the scene, in the anatomy's centimetres.
  Offset toCm(Offset p) => p / scale + _centre;

  /// [millimetres] of the real gland, in the scene's units.
  double mm(double millimetres) => millimetres / 1000 / view;

  /// The outline the step from the body draws: the body's own at [settle]
  /// 0, the gland's at 1, drawn in by [bed] toward the bed its lobules lie
  /// on.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// The path [outlineAt] draws: at [settle] 0 the very curve the body's
  /// outline is drawn by.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// Whether [p] lies inside the gland's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  /// How the gland stands up off the page.
  late final Relief relief = Relief(
    outlinePoints,
    cell: mm(PancreasStyle.reliefCell),
    inflation: PancreasStyle.inflation,
    sweeps: PancreasStyle.reliefSweeps,
  );

  // The lobules.

  double get _spacing => mm(PancreasStyle.lobule);

  /// The gland's lobules: a row of them round its edge, a little in from
  /// it, and the rest on a loose lattice inside.
  late final List<Lobule> lobules = _layLobules();

  List<Lobule> _layLobules() {
    final double s = _spacing;
    final math.Random random = math.Random(47);
    final List<Offset> seeds = <Offset>[];
    // Round the edge.
    final double step = PancreasStyle.edgeStep * s;
    final int n = outlinePoints.length;
    double carried = 0;
    for (int i = 0; i < n; i++) {
      final Offset a = outlinePoints[i];
      final Offset b = outlinePoints[(i + 1) % n];
      final double length = (b - a).distance;
      if (length <= 0) {
        continue;
      }
      final Offset t = (b - a) / length;
      final Offset inward = Offset(-t.dy, t.dx) * _inward;
      double at = step - carried;
      while (at <= length) {
        final Offset p = a + t * at + inward * (PancreasStyle.edgeInset * s);
        if (_inside(outlinePoints, p) &&
            seeds.every((Offset q) => (q - p).distance >= 0.75 * s)) {
          seeds.add(p);
        }
        at += step;
      }
      carried = length - (at - step);
    }
    final int edge = seeds.length;
    // Inside, on a loose lattice.
    int row = 0;
    for (double y = box.top; y <= box.bottom; y += s * 0.866) {
      for (
        double x = box.left - (row.isOdd ? s / 2 : 0);
        x <= box.right;
        x += s
      ) {
        final Offset p =
            Offset(x, y) +
            Offset(random.nextDouble() - 0.5, random.nextDouble() - 0.5) *
                (2 * PancreasStyle.jitter * s);
        if (!_inside(outlinePoints, p)) {
          continue;
        }
        bool clear = true;
        for (int k = 0; k < edge; k++) {
          if ((seeds[k] - p).distance < PancreasStyle.clearOfEdge * s) {
            clear = false;
            break;
          }
        }
        if (clear) {
          seeds.add(p);
        }
      }
      row++;
    }
    // The lobules gather into lobes, a centimetre or so across, parted by
    // deeper clefts than part the lobules in each.
    final double apart = mm(PancreasStyle.lobe);
    final List<Offset> lobes = <Offset>[];
    int lobeRow = 0;
    for (double y = box.top; y <= box.bottom + apart; y += apart * 0.866) {
      for (
        double x = box.left - (lobeRow.isOdd ? apart / 2 : 0);
        x <= box.right + apart;
        x += apart
      ) {
        lobes.add(
          Offset(x, y) +
              Offset(random.nextDouble() - 0.5, random.nextDouble() - 0.5) *
                  (0.5 * apart),
        );
      }
      lobeRow++;
    }
    int lobeOf(Offset p) {
      int best = 0;
      for (int k = 1; k < lobes.length; k++) {
        if ((lobes[k] - p).distanceSquared <
            (lobes[best] - p).distanceSquared) {
          best = k;
        }
      }
      return best;
    }

    final List<int> lobe = <int>[for (final Offset p in seeds) lobeOf(p)];
    // Each lobule reaches toward its neighbours as far as the line half
    // way to each, and no further than its cap.
    final _Buckets near = _Buckets(seeds, 2.2 * s);
    final double cap = PancreasStyle.cap * s;
    final double fine = mm(PancreasStyle.crevice) / 2;
    final double deep = mm(PancreasStyle.cleft) / 2;
    const int rays = PancreasStyle.rays;
    return <Lobule>[
      for (int i = 0; i < seeds.length; i++)
        () {
          final Offset c = seeds[i];
          final List<int> close = List<int>.of(near.around(c));
          final Float64List raw = Float64List(rays);
          final Float64List cleft = Float64List(rays);
          for (int k = 0; k < rays; k++) {
            final Offset u = Lobule.direction(k);
            double reach = cap;
            int by = -1;
            for (final int j in close) {
              if (j == i) {
                continue;
              }
              final Offset d = seeds[j] - c;
              final double toward = d.dx * u.dx + d.dy * u.dy;
              if (toward > 1e-12) {
                final double half = d.distanceSquared / (2 * toward);
                if (half < reach) {
                  reach = half;
                  by = j;
                }
              }
            }
            raw[k] = reach;
            // A cleft where the lobule meets another lobe, or the gland's
            // edge.
            cleft[k] = by < 0 || lobe[by] != lobe[i] ? 1 : 0;
          }
          // Its corners rounded, its sides kept to the half-way lines, and
          // its clefts eased round it.
          Float64List smooth = raw;
          for (int pass = 0; pass < 2; pass++) {
            smooth = _eased(smooth);
          }
          final Float64List depth = _eased(cleft);
          final Float64List reach = Float64List(rays);
          for (int k = 0; k < rays; k++) {
            reach[k] = math.max(
              0.25 * s,
              math.min(smooth[k], raw[k]) - (fine + (deep - fine) * depth[k]),
            );
          }
          return Lobule(
            c,
            reach,
            uncinate: PancreasAnatomy.inUncinate(toCm(c)),
            depth: depth,
            lobe: lobes[lobe[i]],
            lobeIndex: lobe[i],
          );
        }(),
    ];
  }

  /// [values] round a lobule, each eased toward its neighbours.
  static Float64List _eased(Float64List values) {
    final int n = values.length;
    final Float64List out = Float64List(n);
    for (int k = 0; k < n; k++) {
      out[k] =
          (values[(k - 1 + n) % n] + 2 * values[k] + values[(k + 1) % n]) / 4;
    }
    return out;
  }

  late final _Buckets _lobuleBuckets = _Buckets(<Offset>[
    for (final Lobule lobule in lobules) lobule.centre,
  ], 1.5 * _spacing);

  /// The lobule whose middle lies nearest [p].
  Lobule nearestLobule(Offset p) {
    int best = 0;
    double least = double.infinity;
    for (final int i in _lobuleBuckets.around(p)) {
      final double d = (lobules[i].centre - p).distanceSquared;
      if (d < least) {
        least = d;
        best = i;
      }
    }
    if (least == double.infinity) {
      for (int i = 0; i < lobules.length; i++) {
        final double d = (lobules[i].centre - p).distanceSquared;
        if (d < least) {
          least = d;
          best = i;
        }
      }
    }
    return lobules[best];
  }

  // The islets, for an endocrine cell.

  /// The islets: a million in a gland, a few hundred drawn, each its true
  /// size, inside a lobule, more of them toward the tail, where they are
  /// denser, and where the gland is thicker.
  late final List<Islet> islets = _layIslets();

  /// The islet at the place the tissue is sampled.
  late final Islet siteIslet = Islet(
    site,
    mm(PancreasStyle.siteIslet / 1000),
    uncinate: PancreasAnatomy.inUncinate(toCm(site)),
  );

  List<Islet> _layIslets() {
    final math.Random random = math.Random(53);
    final double highest = relief.highest;
    final List<Islet> out = <Islet>[];
    int tries = 0;
    while (out.length < PancreasStyle.islets &&
        tries < PancreasStyle.islets * 400) {
      tries++;
      final Offset p = Offset(
        box.left + random.nextDouble() * box.width,
        box.top + random.nextDouble() * box.height,
      );
      final double pick = random.nextDouble();
      final double size = random.nextDouble();
      if (!_inside(outlinePoints, p)) {
        continue;
      }
      final double along = (p.dx - box.left) / box.width;
      final double thick = highest <= 0
          ? 1
          : math.sqrt(math.max(0, relief.heightAt(p)) / highest);
      final double chance =
          (PancreasStyle.isletHead + (1 - PancreasStyle.isletHead) * along) *
          (1 - PancreasStyle.isletThick + PancreasStyle.isletThick * thick);
      if (pick > chance) {
        continue;
      }
      double radius = PancreasStyle.isletRadii.last;
      double sum = 0;
      for (int k = 0; k < PancreasStyle.isletRadii.length; k++) {
        sum += PancreasStyle.isletShares[k];
        if (size <= sum) {
          radius = PancreasStyle.isletRadii[k];
          break;
        }
      }
      final double r = mm(radius / 1000);
      final Lobule lobule = nearestLobule(p);
      if (!lobule.holds(p, margin: 1.5 * r)) {
        continue;
      }
      out.add(Islet(p, r, uncinate: lobule.uncinate));
    }
    return out;
  }

  // The tubes.

  /// A tube of the anatomy laid in the scene, its rows at most [row]
  /// millimetres apart.
  TubeCourse tube(AnatomyTube tube, {double row = PancreasStyle.tubeRow}) =>
      TubeCourse(tube, place, scale, mm(row), bend: PancreasStyle.bend);

  late final TubeCourse duodenum = tube(PancreasAnatomy.duodenum);
  late final TubeCourse coeliacTrunk = tube(PancreasAnatomy.coeliacTrunk);
  late final TubeCourse splenicArtery = tube(PancreasAnatomy.splenicArtery);
  late final List<TubeCourse> hilarBranches = <TubeCourse>[
    for (final AnatomyTube branch in PancreasAnatomy.hilarBranches)
      tube(branch),
  ];
  late final TubeCourse hepaticArtery = tube(PancreasAnatomy.hepaticArtery);
  late final TubeCourse mesentericVein = tube(PancreasAnatomy.mesentericVein);
  late final TubeCourse mesentericArtery = tube(
    PancreasAnatomy.mesentericArtery,
  );
  late final TubeCourse bileDuct = tube(PancreasAnatomy.bileDuct);
  late final TubeCourse mainDuct = tube(
    PancreasAnatomy.mainDuct,
    row: PancreasStyle.ductRow,
  );
  late final TubeCourse accessoryDuct = tube(
    PancreasAnatomy.accessoryDuct,
    row: PancreasStyle.ductRow,
  );

  /// The row at which the duodenum passes behind the head: the rows before
  /// it, its first part, lie in front.
  int get duodenumFront => duodenum.knotRows[PancreasAnatomy.duodenumFront - 1];

  // The spleen.

  late final List<Offset> spleenPoints = Contour(<Offset>[
    for (final Offset p in PancreasAnatomy.spleen) place(p),
  ]).sampled(PancreasStyle.outlineSpan).points;

  late final Path spleen = Path()..addPolygon(spleenPoints, true);

  late final Relief spleenRelief = Relief(
    spleenPoints,
    cell: mm(PancreasStyle.reliefCell),
    inflation: PancreasStyle.inflation,
    sweeps: PancreasStyle.reliefSweeps,
  );

  // The window, for a duct cell.

  /// The strip of the gland's front cut away along its main duct: wider in
  /// the head, where the accessory duct and the end of the bile duct lie
  /// above the main one.
  late final Path window = Path.combine(
    PathOperation.intersect,
    _strip(),
    outline,
  );

  Path _strip() {
    final TubeCourse duct = mainDuct;
    double above(double x) => _ease(
      x,
      PancreasStyle.windowTail,
      PancreasStyle.windowBody,
      PancreasStyle.windowHeadAbove,
    );
    double below(double x) => _ease(
      x,
      PancreasStyle.windowTail,
      PancreasStyle.windowBody,
      PancreasStyle.windowHeadBelow,
    );
    final List<Offset> up = <Offset>[];
    final List<Offset> down = <Offset>[];
    for (int i = 0; i < duct.length; i++) {
      final double x = toCm(duct.centres[i]).dx;
      up.add(duct.centres[i] + duct.across[i] * (above(x) * scale));
      down.add(duct.centres[i] - duct.across[i] * (below(x) * scale));
    }
    // The tail's end rounded; at the head's the strip runs on past the
    // ampulla, square, for the gland's own edge to end it.
    List<Offset> cap(int i, double sign) {
      final Offset c = duct.centres[i];
      final Offset m = duct.across[i];
      final Offset t = Offset(m.dy, -m.dx) * sign;
      final double x = toCm(c).dx;
      final double r = (above(x) + below(x)) / 2 * scale;
      return <Offset>[
        for (int k = 1; k < 12; k++)
          () {
            final double a = math.pi * k / 12;
            return c + m * (math.cos(a) * r * sign) + t * (math.sin(a) * r);
          }(),
      ];
    }

    List<Offset> past(int i) {
      final Offset c = duct.centres[i];
      final Offset m = duct.across[i];
      final Offset t = Offset(m.dy, -m.dx);
      final double x = toCm(c).dx;
      final double r = math.max(above(x), below(x)) * scale;
      return <Offset>[
        c + m * (above(x) * scale) + t * r,
        c - m * (below(x) * scale) + t * r,
      ];
    }

    return Path()..addPolygon(<Offset>[
      ...up,
      ...past(duct.length - 1),
      ...down.reversed,
      ...cap(0, -1),
    ], true);
  }

  /// [tail], [body] or [head] by where along the gland [x] lies, in
  /// centimetres, eased from one to the next.
  static double _ease(double x, double tail, double body, double head) {
    final double toTail = _smooth(
      (x - PancreasStyle.tailFrom) / PancreasStyle.windowEase,
    );
    final double toHead = _smooth(
      (PancreasStyle.headFrom - x) / PancreasStyle.windowEase,
    );
    return body + (tail - body) * toTail + (head - body) * toHead;
  }

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
        Offset out1 = Offset(-v.dy, v.dx) / v.distance;
        if (window.contains(tangent.position + out1 * probe)) {
          out1 = -out1;
        }
        out.add((tangent.position, out1));
      }
    }
    return out;
  }();

  /// The main duct's side branches: one every so far along it, to either
  /// side in turn, each forking once.
  late final Path branches = () {
    final math.Random random = math.Random(61);
    final TubeCourse duct = mainDuct;
    final Path path = Path();
    final double step = PancreasStyle.branchStep * scale;
    final double end = duct.arc.last - 0.5 * scale;
    int side = 1;
    int i = 0;
    for (
      double at = 0.5 * scale;
      at < end;
      at += step * (0.7 + 0.6 * random.nextDouble())
    ) {
      while (i < duct.length - 1 && duct.arc[i] < at) {
        i++;
      }
      final Offset c = duct.centres[i];
      final Offset m = duct.across[i] * side.toDouble();
      final Offset t = Offset(duct.across[i].dy, -duct.across[i].dx);
      final double angle =
          (PancreasStyle.branchAngle +
              PancreasStyle.branchSpread * (2 * random.nextDouble() - 1)) *
          math.pi /
          180;
      // Turned from along the duct toward this side.
      final Offset d = t * math.cos(angle) + m * math.sin(angle);
      final double head = toCm(c).dx < PancreasStyle.headFrom - 1.2
          ? PancreasStyle.branchHead
          : 1;
      final double length =
          (PancreasStyle.branchLength +
              PancreasStyle.branchLonger * random.nextDouble()) *
          head *
          scale;
      final Offset bend =
          Offset(-d.dy, d.dx) * (length * 0.3 * (random.nextDouble() - 0.5));
      final Offset tip = c + d * length;
      path
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(
          c.dx + d.dx * length / 2 + bend.dx,
          c.dy + d.dy * length / 2 + bend.dy,
          tip.dx,
          tip.dy,
        );
      // Most fork once at their end, some part way along.
      final Offset fork = random.nextDouble() < 0.35
          ? c + d * (length * (0.45 + 0.2 * random.nextDouble()))
          : tip;
      for (final double way in <double>[-1, 1]) {
        if (random.nextDouble() < 0.2) {
          continue;
        }
        final double turn = way * (0.35 + 0.45 * random.nextDouble());
        final Offset f = Offset(
          d.dx * math.cos(turn) - d.dy * math.sin(turn),
          d.dx * math.sin(turn) + d.dy * math.cos(turn),
        );
        final Offset to =
            fork + f * (length * (0.25 + 0.3 * random.nextDouble()));
        path
          ..moveTo(fork.dx, fork.dy)
          ..lineTo(to.dx, to.dy);
      }
      side = -side;
    }
    return path;
  }();

  /// A branch from the main duct to the place the tissue is sampled, where
  /// that lies further from it than [PancreasStyle.siteReach]; else none.
  late final Path? siteBranch = () {
    final TubeCourse duct = mainDuct;
    int best = 0;
    double least = double.infinity;
    for (int i = 0; i < duct.length; i++) {
      final double d = (duct.centres[i] - site).distance;
      if (d < least) {
        least = d;
        best = i;
      }
    }
    if (least <= mm(PancreasStyle.siteReach)) {
      return null;
    }
    final Offset from = duct.centres[best];
    final Offset mid = Offset.lerp(from, site, 0.5)!;
    final Offset bend = Offset(-(site - from).dy, (site - from).dx) * 0.12;
    return Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx + bend.dx, mid.dy + bend.dy, site.dx, site.dy);
  }();

  // Helpers.

  static double _area(List<Offset> points) {
    double sum = 0;
    for (int i = 0; i < points.length; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % points.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum / 2;
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
}

/// Whether [p] lies inside the closed outline [points].
bool _inside(List<Offset> points, Offset p) {
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

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Points sorted into square buckets [size] across, to find the ones near
/// a place without looking at all of them.
final class _Buckets {
  _Buckets(this.points, this.size) {
    for (int i = 0; i < points.length; i++) {
      _cells.putIfAbsent(_key(points[i]), () => <int>[]).add(i);
    }
  }

  final List<Offset> points;
  final double size;
  final Map<int, List<int>> _cells = <int, List<int>>{};

  static int _pack(int x, int y) => (x + 4096) * 8192 + (y + 4096);

  int _key(Offset p) => _pack((p.dx / size).floor(), (p.dy / size).floor());

  final List<int> _found = <int>[];

  /// The points in [p]'s bucket and the eight round it. The list is reused
  /// by the next call.
  List<int> around(Offset p) {
    _found.clear();
    final int x = (p.dx / size).floor();
    final int y = (p.dy / size).floor();
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final List<int>? cell = _cells[_pack(x + dx, y + dy)];
        if (cell != null) {
          _found.addAll(cell);
        }
      }
    }
    return _found;
  }
}

/// One of the gland's lobules: its middle, and how far it reaches from it
/// toward each of [PancreasStyle.rays] ways round, the first to the right.
final class Lobule {
  Lobule(
    this.centre,
    this.reach, {
    required this.uncinate,
    Float64List? depth,
    Offset? lobe,
    this.lobeIndex = 0,
  }) : depth = depth ?? Float64List(reach.length),
       lobe = lobe ?? centre;

  final Offset centre;
  final Float64List reach;

  /// Whether it lies in the uncinate process, behind the mesenteric
  /// vessels.
  final bool uncinate;

  /// How deep the crevice is on each way round, from 0, between two
  /// lobules of one lobe, to 1, a cleft between two lobes or the gland's
  /// edge.
  final Float64List depth;

  /// The middle of the lobe it is part of, and which lobe that is.
  final Offset lobe;
  final int lobeIndex;

  static final List<Offset> _directions = <Offset>[
    for (int k = 0; k < PancreasStyle.rays; k++)
      Offset(
        math.cos(2 * math.pi * k / PancreasStyle.rays),
        math.sin(2 * math.pi * k / PancreasStyle.rays),
      ),
  ];

  /// The [k]th way round.
  static Offset direction(int k) => _directions[k];

  /// The point [share] of the way out toward its edge the [k]th way round.
  Offset at(int k, double share) =>
      centre + _directions[k] * (reach[k] * share);

  /// Its mean radius.
  double get radius {
    double sum = 0;
    for (final double r in reach) {
      sum += r;
    }
    return sum / reach.length;
  }

  /// Its outline, [share] of the way out, as one closed path.
  void addTo(Path path, {double share = 1, double grow = 0}) {
    path.moveTo(
      centre.dx + _directions[0].dx * (reach[0] * share + grow),
      centre.dy + _directions[0].dy * (reach[0] * share + grow),
    );
    for (int k = 1; k < reach.length; k++) {
      path.lineTo(
        centre.dx + _directions[k].dx * (reach[k] * share + grow),
        centre.dy + _directions[k].dy * (reach[k] * share + grow),
      );
    }
    path.close();
  }

  /// Whether [p] lies inside it, at least [margin] in from its edge.
  bool holds(Offset p, {double margin = 0}) {
    final Offset d = p - centre;
    final double distance = d.distance;
    if (distance == 0) {
      return true;
    }
    double angle = math.atan2(d.dy, d.dx);
    if (angle < 0) {
      angle += 2 * math.pi;
    }
    final double f = angle / (2 * math.pi) * reach.length;
    final int k = f.floor() % reach.length;
    final double t = f - f.floor();
    final double edge =
        reach[k] + (reach[(k + 1) % reach.length] - reach[k]) * t;
    return distance <= edge - margin;
  }
}

/// An islet: where it lies, its true radius, and whether it lies in the
/// uncinate process.
final class Islet {
  const Islet(this.at, this.radius, {required this.uncinate});

  final Offset at;
  final double radius;
  final bool uncinate;
}
