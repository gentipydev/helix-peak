import 'package:flutter/foundation.dart';

/// A curve through knots that never turns back: a cubic Hermite with
/// Fritsch–Butland tangents, as Matlab's `pchip` draws it. It meets every
/// knot exactly, overshoots none, and its speed changes without a jump, so a
/// replication clock or a synthesis front built on it never lurches.
@immutable
final class MonotoneCurve {
  MonotoneCurve(
    List<(double, double)> knots, {
    double? startSlope,
    double? endSlope,
  }) : assert(knots.length >= 2, 'a curve needs two knots'),
       _x = <double>[for (final (double x, double _) in knots) x],
       _y = <double>[for (final (double _, double y) in knots) y],
       _m = _slopes(knots, startSlope, endSlope);

  final List<double> _x;
  final List<double> _y;
  final List<double> _m;

  static List<double> _slopes(
    List<(double, double)> knots,
    double? start,
    double? end,
  ) {
    final int n = knots.length;
    final List<double> h = <double>[
      for (int k = 0; k + 1 < n; k++) knots[k + 1].$1 - knots[k].$1,
    ];
    final List<double> d = <double>[
      for (int k = 0; k + 1 < n; k++) (knots[k + 1].$2 - knots[k].$2) / h[k],
    ];
    final List<double> m = List<double>.filled(n, 0);
    m[0] = start ?? d.first;
    m[n - 1] = end ?? d.last;
    for (int k = 1; k + 1 < n; k++) {
      m[k] = d[k - 1] * d[k] <= 0
          ? 0
          : 3 *
                (h[k - 1] + h[k]) /
                ((2 * h[k] + h[k - 1]) / d[k - 1] +
                    (h[k] + 2 * h[k - 1]) / d[k]);
    }
    return m;
  }

  /// The curve at [x], level beyond its first and last knots.
  double at(double x) {
    if (x <= _x.first) {
      return _y.first;
    }
    if (x >= _x.last) {
      return _y.last;
    }
    int k = 0;
    while (x > _x[k + 1]) {
      k++;
    }
    final double h = _x[k + 1] - _x[k];
    final double t = (x - _x[k]) / h;
    final double t2 = t * t;
    final double t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * _y[k] +
        (t3 - 2 * t2 + t) * h * _m[k] +
        (-2 * t3 + 3 * t2) * _y[k + 1] +
        (t3 - t2) * h * _m[k + 1];
  }
}
