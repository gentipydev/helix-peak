import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Every number a gland's lobules are laid and lit by. Lengths are in
/// millimetres of the real gland unless they say otherwise.
final class LobuleStyle {
  const LobuleStyle({
    required this.spacing,
    required this.edgeStep,
    required this.edgeInset,
    required this.jitter,
    required this.clearOfEdge,
    required this.cap,
    required this.crevice,
    required this.cleft,
    required this.lobe,
    required this.rings,
    required this.tilts,
    required this.tilt,
    required this.cleftTilt,
    required this.lobeTilt,
    required this.nudge,
    required this.feather,
    required this.rimShade,
    required this.lobeTone,
    required this.lobuleTone,
  });

  /// How far apart the lobules lie, centre to centre.
  final double spacing;

  /// The seeds round the edge: how far apart along it, and how far in.
  /// Shares of [spacing].
  final double edgeStep;
  final double edgeInset;

  /// The seeds inside: how far each strays from its lattice, and how far
  /// it keeps from those round the edge. Shares of [spacing].
  final double jitter;
  final double clearOfEdge;

  /// How far a lobule reaches at most, a share of [spacing]: past the edge
  /// it bulges out by this less [edgeInset], which makes the edge knobbly.
  final double cap;

  /// The crevice between two lobules of one lobe, and the deeper cleft
  /// between two lobes; and how far apart the lobes lie.
  final double crevice;
  final double cleft;
  final double lobe;

  /// A lobule's rings, out from its middle, and how far each tilts its
  /// normal outward.
  final List<double> rings;
  final List<double> tilts;

  /// How far a lobule's edge turns away, inside its lobe and at a cleft;
  /// how far each lobe rounds off toward its own edge; its middle's nudge
  /// toward the light, a share of its radius; its feathered edge, a share
  /// of [spacing].
  final double tilt;
  final double cleftTilt;
  final double lobeTilt;
  final double nudge;
  final double feather;

  /// How dark a lobule's rim is drawn at a cleft, in its shade; how much
  /// lighter or darker one lobe is than the next, and one lobule than the
  /// next, at most.
  final double rimShade;
  final double lobeTone;
  final double lobuleTone;
}

/// A gland's lobules, laid inside its outline: a row of them round its
/// edge, a little in from it, and the rest on a loose lattice inside,
/// gathered into lobes parted by deeper clefts than part the lobules in
/// each. Each reaches toward its neighbours as far as the line half way to
/// each.
final class Lobules {
  /// Lays them inside [outline], the gland's edge followed closely, whose
  /// box is [box] and whose left hand points into it where [inward] is 1;
  /// [mm] is a millimetre of the real gland in the outline's units, and
  /// [seed] the seed they are strewn by. [behind] says which lie behind
  /// what passes over the gland, and are drawn under it.
  Lobules.lay(
    List<Offset> outline, {
    required Rect box,
    required double inward,
    required LobuleStyle style,
    required double Function(double millimetres) mm,
    required int seed,
    bool Function(Offset centre)? behind,
  }) : _spacing = mm(style.spacing) {
    all = _lay(outline, box, inward, style, mm, seed, behind);
  }

  final double _spacing;

  /// Every lobule, in the order laid.
  late final List<Lobule> all;

  List<Lobule> _lay(
    List<Offset> outline,
    Rect box,
    double inward,
    LobuleStyle style,
    double Function(double millimetres) mm,
    int seed,
    bool Function(Offset centre)? behind,
  ) {
    final double s = _spacing;
    final math.Random random = math.Random(seed);
    final List<Offset> seeds = <Offset>[];
    // Round the edge.
    final double step = style.edgeStep * s;
    final int n = outline.length;
    double carried = 0;
    for (int i = 0; i < n; i++) {
      final Offset a = outline[i];
      final Offset b = outline[(i + 1) % n];
      final double length = (b - a).distance;
      if (length <= 0) {
        continue;
      }
      final Offset t = (b - a) / length;
      final Offset inwardOf = Offset(-t.dy, t.dx) * inward;
      double at = step - carried;
      while (at <= length) {
        final Offset p = a + t * at + inwardOf * (style.edgeInset * s);
        if (_inside(outline, p) &&
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
                (2 * style.jitter * s);
        if (!_inside(outline, p)) {
          continue;
        }
        bool clear = true;
        for (int k = 0; k < edge; k++) {
          if ((seeds[k] - p).distance < style.clearOfEdge * s) {
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
    // The lobules gather into lobes, parted by deeper clefts than part the
    // lobules in each.
    final double apart = mm(style.lobe);
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
    final double cap = style.cap * s;
    final double fine = mm(style.crevice) / 2;
    final double deep = mm(style.cleft) / 2;
    const int rays = Lobule.rays;
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
            behind: behind != null && behind(c),
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

  late final _Buckets _buckets = _Buckets(<Offset>[
    for (final Lobule lobule in all) lobule.centre,
  ], 1.5 * _spacing);

  /// The lobule whose middle lies nearest [p].
  Lobule nearest(Offset p) {
    int best = 0;
    double least = double.infinity;
    for (final int i in _buckets.around(p)) {
      final double d = (all[i].centre - p).distanceSquared;
      if (d < least) {
        least = d;
        best = i;
      }
    }
    if (least == double.infinity) {
      for (int i = 0; i < all.length; i++) {
        final double d = (all[i].centre - p).distanceSquared;
        if (d < least) {
          least = d;
          best = i;
        }
      }
    }
    return all[best];
  }

  /// The crevices between [lobules], filled: each lobule grown by [grow],
  /// so the grown shapes meet.
  static Path bed(Iterable<Lobule> lobules, double grow) {
    final Path path = Path();
    for (final Lobule lobule in lobules) {
      lobule.addTo(path, grow: grow);
    }
    return path;
  }
}

/// One of a gland's lobules: its middle, and how far it reaches from it
/// toward each of [rays] ways round, the first to the right.
final class Lobule {
  Lobule(
    this.centre,
    this.reach, {
    required this.behind,
    Float64List? depth,
    Offset? lobe,
    this.lobeIndex = 0,
  }) : depth = depth ?? Float64List(reach.length),
       lobe = lobe ?? centre;

  /// How far round a lobule its outline is followed.
  static const int rays = 24;

  final Offset centre;
  final Float64List reach;

  /// Whether it lies behind what passes over the gland, and is drawn under
  /// it: the pancreas's uncinate process, behind the mesenteric vessels.
  final bool behind;

  /// How deep the crevice is on each way round, from 0, between two
  /// lobules of one lobe, to 1, a cleft between two lobes or the gland's
  /// edge.
  final Float64List depth;

  /// The middle of the lobe it is part of, and which lobe that is.
  final Offset lobe;
  final int lobeIndex;

  static final List<Offset> _directions = <Offset>[
    for (int k = 0; k < rays; k++)
      Offset(
        math.cos(2 * math.pi * k / rays),
        math.sin(2 * math.pi * k / rays),
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
