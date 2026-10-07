import 'dart:math' as math;
import 'dart:ui';

/// A closed outline as a list of points, for the zoom's morphs: two outlines
/// resampled to the same number of points, each starting from its top, can
/// be blended point for point without the shape turning inside out.
final class Contour {
  const Contour(this.points);

  /// [count] points round an ellipse of radii [rx] and [ry] at [centre],
  /// starting at its top and running clockwise on screen, each pushed in or
  /// out by [wobble] of its radius: a soft, irregular blob when wobble is
  /// set, deterministic for a given [seed].
  factory Contour.blob(
    Offset centre,
    double rx,
    double ry, {
    int count = 96,
    double wobble = 0,
    int seed = 0,
  }) {
    final math.Random random = math.Random(seed);
    final List<double> phases = <double>[
      for (int k = 0; k < 3; k++) random.nextDouble() * 2 * math.pi,
    ];
    return Contour(<Offset>[
      for (int i = 0; i < count; i++)
        () {
          final double a = -math.pi / 2 + 2 * math.pi * i / count;
          final double push =
              1 +
              wobble *
                  (0.55 * math.sin(3 * a + phases[0]) +
                      0.3 * math.sin(5 * a + phases[1]) +
                      0.15 * math.sin(8 * a + phases[2]));
          return centre +
              Offset(math.cos(a) * rx * push, math.sin(a) * ry * push);
        }(),
    ]);
  }

  final List<Offset> points;

  /// The outline resampled to [count] points evenly spaced along it,
  /// starting from its topmost point and running the same way round.
  Contour resampled(int count) {
    final int n = points.length;
    if (n < 2) {
      return Contour(List<Offset>.filled(count, n == 0 ? Offset.zero : points.first));
    }
    int top = 0;
    for (int i = 1; i < n; i++) {
      if (points[i].dy < points[top].dy) {
        top = i;
      }
    }
    final List<Offset> loop = <Offset>[
      for (int i = 0; i <= n; i++) points[(top + i) % n],
    ];
    final List<double> along = <double>[0];
    for (int i = 1; i < loop.length; i++) {
      along.add(along.last + (loop[i] - loop[i - 1]).distance);
    }
    final double total = along.last;
    final List<Offset> out = <Offset>[];
    int j = 1;
    for (int k = 0; k < count; k++) {
      final double at = total * k / count;
      while (j < loop.length - 1 && along[j] < at) {
        j++;
      }
      final double span = along[j] - along[j - 1];
      final double t = span <= 0 ? 0 : (at - along[j - 1]) / span;
      out.add(Offset.lerp(loop[j - 1], loop[j], t)!);
    }
    return Contour(out);
  }

  /// This outline blended toward [other], which has as many points.
  Contour lerp(Contour other, double t) => Contour(<Offset>[
    for (int i = 0; i < points.length; i++)
      Offset.lerp(points[i], other.points[i % other.points.length], t)!,
  ]);

  /// A smooth closed path through the points: each corner rounded by a
  /// Catmull-Rom spline, so a polygon of a hundred points reads as a curve.
  Path toPath() {
    final Path path = Path();
    final int n = points.length;
    if (n < 3) {
      return path;
    }
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < n; i++) {
      final Offset p0 = points[(i - 1 + n) % n];
      final Offset p1 = points[i];
      final Offset p2 = points[(i + 1) % n];
      final Offset p3 = points[(i + 2) % n];
      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }
}
