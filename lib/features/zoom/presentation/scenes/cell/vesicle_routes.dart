import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// One way a vesicle goes through a cell's cytoplasm: points along it, each
/// with how far it lies from the nearest membrane, and how long it is.
@immutable
final class VesicleRoute {
  const VesicleRoute(this.points, this.clearances, this.length);

  final List<Offset> points;
  final List<double> clearances;
  final double length;

  Offset get start => points.first;
  Offset get end => points.last;

  /// The point [t] of the way along it, by length; the way it runs there,
  /// as a unit vector; and how far from it the nearest membrane is at the
  /// least: no nearer than either point either side of it, less how far
  /// it is from that point.
  (Offset, Offset, double) at(double t) {
    final double want = t.clamp(0.0, 1.0) * length;
    double run = 0;
    for (int i = 1; i < points.length; i++) {
      final Offset step = points[i] - points[i - 1];
      final double d = step.distance;
      if (run + d >= want || i == points.length - 1) {
        final double f = d == 0 ? 0 : ((want - run) / d).clamp(0.0, 1.0);
        return (
          points[i - 1] + step * f,
          d == 0 ? const Offset(1, 0) : step / d,
          math.max(clearances[i - 1] - f * d, clearances[i] - (1 - f) * d),
        );
      }
      run += d;
    }
    return (points.last, const Offset(1, 0), clearances.last);
  }
}

/// The ways vesicles go through a cell's cytoplasm, from where they bud to
/// where they end, laid once for the cell in its units: through the
/// cytoplasm only, never into the nucleus or a lipid droplet nor out
/// through the membrane, and keeping to the middle of the cytoplasm, wide
/// of the nuclear envelope, as the room allows.
///
/// A grid over the cell holds, at each square, how far it lies from the
/// nearest membrane: the cell's own, its nucleus's, any droplet's. The
/// cheapest way from each start to each end through squares at least
/// [least] from every membrane is found (Dijkstra's), each step dearer the
/// nearer it runs to one than [room]; it is then smoothed into a curve, as
/// much as keeps it [least] clear. A cell whose cytoplasm is too thin for
/// the grid to find any way, as a fat cell's rim is, is gridded finer.
final class VesicleRoutes {
  VesicleRoutes._(this.routes);

  /// The routes laid inside [body], outside [holes], from each of [starts]
  /// to each of [ends], within [view] (the rest of the cell is never seen):
  /// a start or an end not in the cytoplasm is moved to the nearest square
  /// that is, and an end no way reaches is left out.
  factory VesicleRoutes.lay({
    required List<Offset> body,
    required List<List<Offset>> holes,
    required List<Offset> starts,
    required List<Offset> ends,
    required double least,
    required double room,
    required Rect view,
    int across = 48,
  }) {
    final Rect box = _boxOf(body).intersect(view);
    if (box.isEmpty || starts.isEmpty || ends.isEmpty) {
      return VesicleRoutes._(const <VesicleRoute>[]);
    }
    for (final int grid in <int>[across, across * 2]) {
      final List<VesicleRoute> routes = _lay(
        body,
        holes,
        starts,
        ends,
        least,
        room,
        box,
        grid,
      );
      if (routes.isNotEmpty) {
        return VesicleRoutes._(List<VesicleRoute>.unmodifiable(routes));
      }
    }
    return VesicleRoutes._(const <VesicleRoute>[]);
  }

  final List<VesicleRoute> routes;

  static List<VesicleRoute> _lay(
    List<Offset> body,
    List<List<Offset>> holes,
    List<Offset> starts,
    List<Offset> ends,
    double least,
    double room,
    Rect box,
    int across,
  ) {
    final List<List<Offset>> edges = <List<Offset>>[body, ...holes];
    double clearance(Offset p) {
      if (!_within(body, p) || holes.any((List<Offset> h) => _within(h, p))) {
        return 0;
      }
      double best = double.infinity;
      for (final List<Offset> loop in edges) {
        best = math.min(best, _distanceTo(loop, p));
      }
      return best;
    }

    final double h = math.max(box.width, box.height) / across;
    final int cols = math.max(1, (box.width / h).ceil());
    final int rows = math.max(1, (box.height / h).ceil());
    Offset centre(int k) => Offset(
      box.left + (k % cols + 0.5) * h,
      box.top + (k ~/ cols + 0.5) * h,
    );
    final Float64List room0 = Float64List(cols * rows);
    for (int k = 0; k < room0.length; k++) {
      room0[k] = clearance(centre(k));
    }
    bool free(int k) => room0[k] >= least;
    // How clear [p] is, at the least: the square it lies in, less how far
    // it is from that square's middle, where that is clear enough; worked
    // out exactly only near a membrane.
    double clearOf(Offset p) {
      final int x = ((p.dx - box.left) / h).floor();
      final int y = ((p.dy - box.top) / h).floor();
      if (x >= 0 && y >= 0 && x < cols && y < rows) {
        final int k = y * cols + x;
        final double bound = room0[k] - (p - centre(k)).distance;
        if (bound >= least) {
          return bound;
        }
      }
      return clearance(p);
    }

    int nearest(Offset p) {
      int best = -1;
      double gap = double.infinity;
      for (int k = 0; k < room0.length; k++) {
        if (free(k)) {
          final double d = (centre(k) - p).distanceSquared;
          if (d < gap) {
            gap = d;
            best = k;
          }
        }
      }
      return best;
    }

    final List<VesicleRoute> routes = <VesicleRoute>[];
    for (final Offset from in starts) {
      final int source = nearest(from);
      if (source < 0) {
        continue;
      }
      final List<int> parent = _dijkstra(
        source,
        cols,
        rows,
        h,
        room0,
        least,
        room,
      );
      for (final Offset to in ends) {
        final int sink = nearest(to);
        if (sink < 0 || (parent[sink] < 0 && sink != source)) {
          continue;
        }
        final List<Offset> raw = <Offset>[];
        for (int k = sink; k >= 0; k = k == source ? -1 : parent[k]) {
          raw.add(centre(k));
        }
        final List<Offset> path = raw.reversed.toList();
        // The very start and end where they are themselves clear.
        if (clearance(from) >= least) {
          path.insert(0, from);
        }
        if (clearance(to) >= least) {
          path.add(to);
        }
        final List<Offset> even = _even(path, h / 2);
        for (final int passes in <int>[80, 40, 20, 0]) {
          final VesicleRoute? route = _route(
            _smooth(even, passes),
            clearOf,
            least,
          );
          if (route != null) {
            routes.add(route);
            break;
          }
        }
      }
    }
    return routes;
  }

  /// The cheapest way out from [source] to every square, as each square's
  /// parent, -1 where none reaches it.
  static List<int> _dijkstra(
    int source,
    int cols,
    int rows,
    double h,
    Float64List clear,
    double least,
    double room,
  ) {
    final int n = cols * rows;
    final Float64List cost = Float64List(n)..fillRange(0, n, double.infinity);
    final List<int> parent = List<int>.filled(n, -1);
    final List<bool> done = List<bool>.filled(n, false);
    cost[source] = 0;
    // A binary heap of (cost, square).
    final List<(double, int)> heap = <(double, int)>[(0, source)];
    void push((double, int) e) {
      heap.add(e);
      int i = heap.length - 1;
      while (i > 0) {
        final int up = (i - 1) ~/ 2;
        if (heap[up].$1 <= heap[i].$1) {
          break;
        }
        final (double, int) t = heap[up];
        heap[up] = heap[i];
        heap[i] = t;
        i = up;
      }
    }

    (double, int) pop() {
      final (double, int) top = heap.first;
      final (double, int) last = heap.removeLast();
      if (heap.isNotEmpty) {
        heap[0] = last;
        int i = 0;
        while (true) {
          final int l = 2 * i + 1;
          final int r = l + 1;
          int m = i;
          if (l < heap.length && heap[l].$1 < heap[m].$1) {
            m = l;
          }
          if (r < heap.length && heap[r].$1 < heap[m].$1) {
            m = r;
          }
          if (m == i) {
            break;
          }
          final (double, int) t = heap[m];
          heap[m] = heap[i];
          heap[i] = t;
          i = m;
        }
      }
      return top;
    }

    while (heap.isNotEmpty) {
      final (double c, int k) = pop();
      if (done[k]) {
        continue;
      }
      done[k] = true;
      final int x = k % cols;
      final int y = k ~/ cols;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) {
            continue;
          }
          final int nx = x + dx;
          final int ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
            continue;
          }
          final int j = ny * cols + nx;
          if (done[j] || clear[j] < least) {
            continue;
          }
          // Dearer the nearer a membrane, within [room] of one.
          final double near = room / math.max(clear[j], least);
          final double step =
              h * (dx != 0 && dy != 0 ? math.sqrt2 : 1) * (1 + near * near);
          if (c + step < cost[j]) {
            cost[j] = c + step;
            parent[j] = k;
            push((cost[j], j));
          }
        }
      }
    }
    return parent;
  }

  /// [path] laid at points [step] apart along it, its ends kept.
  static List<Offset> _even(List<Offset> path, double step) {
    final List<Offset> points = <Offset>[path.first];
    for (int i = 1; i < path.length; i++) {
      final Offset a = path[i - 1];
      final Offset b = path[i];
      final int steps = math.max(1, ((b - a).distance / step).ceil());
      for (int s = 1; s <= steps; s++) {
        points.add(Offset.lerp(a, b, s / steps)!);
      }
    }
    return points;
  }

  /// [points] drawn into a curve: each moved half way toward the middle of
  /// its two neighbours, [passes] times over, its ends kept. The grid's
  /// steps, square and diagonal, round off into the way a vesicle drifts.
  static List<Offset> _smooth(List<Offset> points, int passes) {
    List<Offset> out = points;
    for (int pass = 0; pass < passes && out.length > 2; pass++) {
      out = <Offset>[
        out.first,
        for (int i = 1; i + 1 < out.length; i++)
          out[i] * 0.5 + (out[i - 1] + out[i + 1]) * 0.25,
        out.last,
      ];
    }
    return out;
  }

  /// [points] as a route, each with its room, at the least, by
  /// [clearance]; null where any is less than [least] clear.
  static VesicleRoute? _route(
    List<Offset> points,
    double Function(Offset) clearance,
    double least,
  ) {
    final List<double> clearances = <double>[];
    double length = 0;
    for (int i = 0; i < points.length; i++) {
      final double c = clearance(points[i]);
      if (c < least) {
        return null;
      }
      clearances.add(c);
      if (i > 0) {
        length += (points[i] - points[i - 1]).distance;
      }
    }
    return VesicleRoute(
      List<Offset>.unmodifiable(points),
      List<double>.unmodifiable(clearances),
      length,
    );
  }

  static Rect _boxOf(List<Offset> points) {
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;
    for (final Offset p in points) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Whether [p] is inside the polygon [points], by the even-odd rule.
  static bool _within(List<Offset> points, Offset p) {
    bool inside = false;
    for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
      final Offset a = points[i];
      final Offset b = points[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// How far [p] lies from the nearest edge of the polygon [points].
  static double _distanceTo(List<Offset> points, Offset p) {
    double best = double.infinity;
    for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
      final Offset a = points[j];
      final Offset ab = points[i] - a;
      final double length = ab.distanceSquared;
      final double t = length == 0
          ? 0
          : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(
              0.0,
              1.0,
            );
      best = math.min(best, (a + ab * t - p).distanceSquared);
    }
    return math.sqrt(best);
  }
}
