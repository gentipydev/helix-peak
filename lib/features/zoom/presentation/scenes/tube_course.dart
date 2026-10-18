import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'coloured_mesh.dart';
import 'specimen_light.dart';

/// A tube of an organ's anatomy: a duct, a vessel, a length of gut. Its
/// course runs through [points], [radii] wide at each, in the anatomy's own
/// units.
///
/// [fadeIn] and [fadeOut] are how far from each end it comes up out of
/// nothing, where it runs on beyond what the view needs; [cutStart] and
/// [cutEnd] mark an end that is cut, as an anatomy plate cuts what it has
/// taken away, and is drawn open.
final class AnatomyTube {
  const AnatomyTube(
    this.points,
    this.radii, {
    this.fadeIn = 0,
    this.fadeOut = 0,
    this.cutStart = false,
    this.cutEnd = false,
  });

  final List<Offset> points;
  final List<double> radii;
  final double fadeIn;
  final double fadeOut;
  final bool cutStart;
  final bool cutEnd;
}

/// A tube of the anatomy laid in the scene: rows along it, each its middle,
/// the way across it, how far it reaches to either side, and how much of
/// it shows.
final class TubeCourse {
  TubeCourse(
    AnatomyTube tube,
    Offset Function(Offset) place,
    double scale,
    double row, {
    required double bend,
  }) : cutStart = tube.cutStart,
       cutEnd = tube.cutEnd {
    final List<Offset> knots = <Offset>[
      for (final Offset p in tube.points) place(p),
    ];
    final int n = knots.length;
    Offset knot(int i) => i < 0
        ? knots[0] * 2 - knots[1]
        : i >= n
        ? knots[n - 1] * 2 - knots[n - 2]
        : knots[i];
    final List<Offset> points = <Offset>[];
    final List<double> radii = <double>[];
    final List<int> starts = <int>[];
    for (int i = 0; i < n - 1; i++) {
      final Offset p0 = knot(i - 1);
      final Offset p1 = knot(i);
      final Offset p2 = knot(i + 1);
      final Offset p3 = knot(i + 2);
      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      final int steps = math.max(
        2,
        ((p1 - c1).distance + (c1 - c2).distance + (c2 - p2).distance) ~/ row +
            1,
      );
      starts.add(points.length);
      final bool last = i == n - 2;
      for (int k = 0; k < (last ? steps + 1 : steps); k++) {
        final double t = k / steps;
        final double u = 1 - t;
        points.add(
          p1 * (u * u * u) +
              c1 * (3 * u * u * t) +
              c2 * (3 * u * t * t) +
              p2 * (t * t * t),
        );
        radii.add(
          (tube.radii[i] + (tube.radii[i + 1] - tube.radii[i]) * t) * scale,
        );
      }
    }
    starts.add(points.length - 1);
    knotRows = List<int>.unmodifiable(starts);
    centres = List<Offset>.unmodifiable(points);
    final int count = points.length;
    final List<Offset> across = <Offset>[];
    arc = Float64List(count);
    for (int i = 0; i < count; i++) {
      final Offset t =
          points[math.min(count - 1, i + 1)] - points[math.max(0, i - 1)];
      final double length = t.distance;
      across.add(
        length <= 0 ? const Offset(0, 1) : Offset(-t.dy, t.dx) / length,
      );
      if (i > 0) {
        arc[i] = arc[i - 1] + (points[i] - points[i - 1]).distance;
      }
    }
    this.across = List<Offset>.unmodifiable(across);
    radius = Float64List.fromList(radii);
    plus = Float64List.fromList(radii);
    minus = Float64List.fromList(radii);
    // Round a bend the inner side comes no nearer its middle than [bend] of
    // the bend's radius, so the tube never folds over itself.
    for (int i = 2; i < count - 2; i++) {
      final Offset a = points[i] - points[i - 2];
      final Offset b = points[i + 2] - points[i];
      final double la = a.distance;
      final double lb = b.distance;
      if (la <= 0 || lb <= 0) {
        continue;
      }
      final double turn = (a.dx * b.dy - a.dy * b.dx) / (la * lb);
      final double curvature = turn / ((la + lb) / 2);
      if (curvature.abs() < 1e-9) {
        continue;
      }
      final double limit = bend / curvature.abs();
      if (curvature > 0) {
        plus[i] = math.min(plus[i], limit);
      } else {
        minus[i] = math.min(minus[i], limit);
      }
    }
    // Coming up out of nothing at an end that runs on out of view.
    shown = Float64List(count);
    final double total = arc[count - 1];
    for (int i = 0; i < count; i++) {
      double alpha = 1;
      if (tube.fadeIn > 0) {
        alpha *= _smooth(arc[i] / (tube.fadeIn * scale));
      }
      if (tube.fadeOut > 0) {
        alpha *= _smooth((total - arc[i]) / (tube.fadeOut * scale));
      }
      shown[i] = alpha;
    }
  }

  late final List<Offset> centres;

  /// The way across each row, a unit: the left hand of the way along.
  late final List<Offset> across;

  /// Its radius at each row, and how far it reaches to either side of its
  /// middle, a bend's inner side drawn in.
  late final Float64List radius;
  late final Float64List plus;
  late final Float64List minus;

  /// How far along it each row lies, and how much of it shows there.
  late final Float64List arc;
  late final Float64List shown;

  /// The row each of the anatomy's points lies at.
  late final List<int> knotRows;

  final bool cutStart;
  final bool cutEnd;

  int get length => centres.length;

  /// The point [u] of the way across row [i], from -1 to 1.
  Offset at(int i, double u) =>
      centres[i] + across[i] * (u >= 0 ? plus[i] * u : minus[i] * u);

  /// Its middle line.
  Path get line {
    final Path path = Path()..moveTo(centres.first.dx, centres.first.dy);
    for (final Offset p in centres.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// Its rows [from] to [to] laid in [mesh] as a lit tube in [tone]: round
  /// it at [columns], each from -1 on one side through its middle to 1 on
  /// the other, lit by [light] at [brightness] of it and mixed by [palette].
  void lay(
    ColouredMesh mesh,
    SpecimenTone tone,
    SpecimenLight light,
    SpecimenPalette palette,
    List<double> columns, {
    int from = 0,
    int? to,
    double brightness = 1,
  }) {
    final int end = to ?? length - 1;
    final int around = columns.length;
    final int rows = end - from + 1;
    if (rows < 2) {
      return;
    }
    mesh.begin(rows * around);
    final int first = mesh.next;
    for (int i = from; i <= end; i++) {
      final Offset m = across[i];
      for (final double u in columns) {
        final Offset p = at(i, u);
        final double nz = math.sqrt(math.max(0, 1 - u * u));
        final double nx = m.dx * u;
        final double ny = m.dy * u;
        mesh.vertex(
          p.dx,
          p.dy,
          palette.colour(
            tone,
            light.light(nx, ny, nz, form: nz) * brightness,
            sheen: light.sheen(nx, ny, nz) * brightness,
            alpha: shown[i],
          ),
        );
      }
    }
    for (int i = 0; i + 1 < rows; i++) {
      for (int j = 0; j + 1 < around; j++) {
        final int a = first + i * around + j;
        final int c = a + around;
        mesh.triangle(a, a + 1, c);
        mesh.triangle(a + 1, c + 1, c);
      }
    }
  }
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
