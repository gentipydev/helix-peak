import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How the step from a gene into its DNA spends itself.
///
/// Every other step narrows the view by the same factor for each equal step
/// of depth. This one crosses up to five decades, from a whole gene to 14
/// base pairs, and five things happen in it at their own scales: a long
/// gene's empty introns go by; its exons sink into its DNA; the DNA winds
/// onto its histones and the beads are read; and the bare start opens into
/// the helix. Narrowed evenly, the beads passed in a quarter of a second at
/// the step's fastest. So the step weighs each decade by what happens in it,
/// and spends its depth in proportion: a decade of empty gene weighs a
/// quarter of one where the exons sink, and a decade where the DNA winds and
/// its beads are read three and a half.
///
/// Widths are in base pairs, read as their common logarithm; [narrowedAt]
/// is the share of the step's decades narrowed at a share of its depth.
@immutable
final class DnaDive {
  DnaDive({required double geneWidth, required double dnaWidth})
    : _top = math.log(geneWidth) / math.ln10,
      _bottom = math.log(dnaWidth) / math.ln10 {
    _whole = _held(_bottom);
  }

  /// The view's width at the gene and at the DNA, as logarithms.
  final double _top;
  final double _bottom;

  /// The weight of the whole step.
  late final double _whole;

  /// What a decade weighs where nothing but the gene's introns goes by.
  static const double empty = 0.15;

  /// Where the weight changes, as the view narrows past each width (base
  /// pairs), over how many decades, and by how much: up to a decade's worth
  /// where the exons sink into the DNA, below about 20 kb; up again where
  /// the DNA winds and its beads are read, below about 2.8 kb; and down a
  /// little where the bare start opens into the helix, below about 160 bp.
  static const List<(double, double, double)> _changes =
      <(double, double, double)>[
        (40000, 0.4, 1.85),
        (2800, 0.3, 2.5),
        (160, 0.3, -3.6),
      ];

  /// What a decade weighs where the view is 10^[decade] base pairs wide.
  @visibleForTesting
  double weightAt(double decade) {
    double w = empty;
    for (final (double width, double over, double by) in _changes) {
      w += by * _rise(_across(decade, width, over));
    }
    return w;
  }

  /// How far through a change at [width] over [over] decades the view is at
  /// [decade]: 0 above it, 1 below.
  static double _across(double decade, double width, double over) =>
      (math.log(width) / math.ln10 - decade) / over + 0.5;

  static double _rise(double u) {
    final double x = u.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// The integral of [_rise] from 0 to [u].
  static double _risen(double u) {
    if (u <= 0) {
      return 0;
    }
    if (u >= 1) {
      return u - 0.5;
    }
    return u * u * u - u * u * u * u / 2;
  }

  /// The weight the step has spent by the time the view is 10^[decade] wide.
  double _held(double decade) {
    double held = empty * (_top - decade);
    for (final (double width, double over, double by) in _changes) {
      held +=
          by *
          over *
          (_risen(_across(decade, width, over)) -
              _risen(_across(_top, width, over)));
    }
    return held;
  }

  /// The share of the step's decades narrowed [s] of the way along it: 0 at
  /// the gene, 1 at the DNA, each decade crossed in depth as it weighs.
  double narrowedAt(double s) {
    if (s <= 0) {
      return 0;
    }
    if (s >= 1) {
      return 1;
    }
    final double target = s * _whole;
    // Newton's way down the decades, kept within a bracket that holds the
    // answer: the weight spent only grows as the view narrows.
    double high = _top;
    double low = _bottom;
    double at = _top - s * (_top - _bottom);
    for (int i = 0; i < 40; i++) {
      final double gap = _held(at) - target;
      if (gap.abs() < 1e-13) {
        break;
      }
      if (gap > 0) {
        low = at;
      } else {
        high = at;
      }
      final double next = at + gap / weightAt(at);
      at = next > low && next < high ? next : (low + high) / 2;
    }
    return (_top - at) / (_top - _bottom);
  }
}
