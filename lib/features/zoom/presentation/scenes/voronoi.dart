import 'dart:ui';

/// The middle of [poly], by its area.
Offset polygonCentroid(List<Offset> poly) {
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

/// Each seed's Voronoi cell: the ground nearer to it than to any other,
/// no farther than [reach] from it. Clockwise on screen.
List<List<Offset>> voronoiCells(List<Offset> seeds, double reach) {
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
List<Offset> _nearer(List<Offset> poly, Offset a, Offset b) {
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
List<Offset> relaxedSeeds(
  List<Offset> seeds,
  double reach, {
  int times = 2,
  int fixed = 0,
}) {
  List<Offset> out = seeds;
  for (int t = 0; t < times; t++) {
    final List<List<Offset>> cells = voronoiCells(out, reach);
    out = <Offset>[
      for (int i = 0; i < out.length; i++)
        i < fixed || cells[i].length < 3 ? out[i] : polygonCentroid(cells[i]),
    ];
  }
  return out;
}
