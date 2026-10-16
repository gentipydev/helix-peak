import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A point of the DNA as it lies: along the fibre's axis and across it, in
/// base pairs' lengths (0.34 nm), and how near the reader it is.
@immutable
final class FibrePoint {
  const FibrePoint(this.along, this.across, this.depth);

  /// Along the fibre's axis: from the gene's 5′ end, or for a point of a
  /// nucleosome's DNA ([ChromatinLayout.coilAt]) from its core's middle.
  final double along;

  /// Across it, down the screen.
  final double across;

  /// Toward the reader, from the fibre's axis: a point of a nucleosome's DNA
  /// with a positive depth passes in front of its histone core.
  final double depth;
}

/// A gene's DNA as chromatin packs it: wound round histone octamers, 147
/// base pairs to a nucleosome in 1.65 left-handed turns (Luger et al. 1997),
/// one every 200 base pairs, with the stretch round the gene's start bare
/// (Schones et al. 2008): the textbook's packing, not this gene's.
///
/// Every nucleosome's DNA is wound round its core, from the gene's stop on
/// ([coilAt]; the user's choice of 2026-10-16: the gene's stop shows its
/// nucleosomes as DNA wound round histones). Along the fibre the DNA lies as
/// the zoom's genome first, every base pair a base pair's length along the
/// view, as the gene's stop lays it out; and as the view closes in, it
/// packs: [packed] from 0 to 1, the line between the cores drawn in until
/// each nucleosome takes the length along the fibre its core does. The bare
/// stretch at the start never moves, so the gene's 5′ end stays where it is.
@immutable
final class ChromatinLayout {
  const ChromatinLayout();

  /// Where the first nucleosome's DNA starts, in base pairs from the gene's
  /// 5′ end, and how far apart nucleosomes are; how much DNA each winds.
  static const double first = 40;
  static const double period = 200;
  static const double wrapped = 147;

  /// Where the bare stretch round the start ends upstream: the promoter's
  /// nucleosome lies before it, the rest one every [period] before that.
  static const double bareUpstream = -220;

  /// How many turns a nucleosome's DNA makes round its core.
  static const double turns = 1.65;

  /// The radius of the DNA's superhelix round the core, and how far apart
  /// along the core's axis its two turns lie, in base pairs' lengths: 4.2 nm
  /// and 2.4 nm (Luger et al. 1997).
  static const double radius = 4.2 / 0.34;
  static const double pitch = 2.4 / 0.34;

  /// How far the core's face is tilted toward the reader: seen three
  /// quarters on, its DNA's turns both show.
  static const double tilt = 1.25;

  /// How much length along the fibre a packed nucleosome takes: its DNA's
  /// superhelix, edge to edge.
  static const double across = 2 * radius;

  /// How far either side of a core's middle, along the fibre's axis, its DNA
  /// leaves the axis to wind round the core and comes back to it, in base
  /// pairs' lengths: a little past the superhelix's edge.
  static const double reach = 16;

  /// The stretches each nucleosome winds, from and to, in base pairs from
  /// the gene's 5′ end, that reach into [from] to [to].
  List<(double, double)> nucleosomesWithin(double from, double to) {
    final List<(double, double)> out = <(double, double)>[];
    // Upstream: the promoter's nucleosome first, then one a period apart.
    final int far = ((bareUpstream - from) / period).floor();
    for (int k = math.max(0, far + 1); k >= 0; k--) {
      final double end = bareUpstream - k * period;
      final double start = end - wrapped;
      if (end > from && start < to) {
        out.add((start, end));
      }
    }
    final int last = ((to - first) / period).ceil();
    for (
      int k = math.max(0, ((from - first - wrapped) / period).floor());
      k <= last;
      k++
    ) {
      final double start = first + k * period;
      if (start + wrapped > from && start < to) {
        out.add((start, start + wrapped));
      }
    }
    return out;
  }

  /// How much shorter than its base pairs a packed nucleosome lies.
  static const double _gain = wrapped - across;

  /// Where along the fibre's axis the point [offset] base pairs from the
  /// gene's 5′ end lies, [packed] of the way packed, where it is not in a
  /// nucleosome's stretch: each nucleosome between it and the start draws
  /// it in by the length its winding saves.
  double axisAt(double offset, double packed) {
    if (offset >= first) {
      return first + _drawnIn(offset - first, packed);
    }
    if (offset <= bareUpstream) {
      return bareUpstream - _drawnIn(bareUpstream - offset, packed);
    }
    return offset;
  }

  /// The point whose place along the fibre's axis is [along], [packed] of
  /// the way packed, in base pairs from the gene's 5′ end: where [axisAt]
  /// lays it, which only ever draws the DNA in.
  double offsetAt(double along, double packed) {
    if (along >= first) {
      return first + _drawnOut(along - first, packed);
    }
    if (along <= bareUpstream) {
      return bareUpstream - _drawnOut(bareUpstream - along, packed);
    }
    return along;
  }

  /// How far along the fibre lies the point [d] base pairs past where the
  /// nucleosomes start, going away from the bare start: each period winds a
  /// stretch first, which packs, and then a linker, which does not.
  static double _drawnIn(double d, double packed) {
    final double passed = (d / period).floor().toDouble();
    final double into = d - passed * period;
    final double whole = passed + math.min(into / wrapped, 1);
    return d - packed * _gain * whole;
  }

  /// The inverse of [_drawnIn].
  static double _drawnOut(double along, double packed) {
    final double perPeriod = period - packed * _gain;
    final double passed = (along / perPeriod).floor().toDouble();
    final double rest = along - passed * perPeriod;
    final double stretch = wrapped - packed * _gain;
    final double into = rest < stretch
        ? rest * wrapped / stretch
        : rest + packed * _gain;
    return passed * period + into;
  }

  /// Where the middle of the core lies along the fibre's axis, [packed] of
  /// the way packed, for the nucleosome that winds [start] to [start] +
  /// [wrapped].
  double coreAt(double start, double packed) =>
      axisAt(start, packed) + across / 2;

  /// Where its turns start, round the core: at its front, toward its left.
  static const double _phase = 5 * math.pi / 6;

  /// A point of the superhelix [v] of the way along its turns, about the
  /// core's middle: seen from above and in front as a coin on a table is,
  /// its face tilted [tilt] toward the reader. Left-handed: going round, it
  /// steps up the core's axis, the turns crossing the core's front left to
  /// right.
  static FibrePoint _turnAt(double v) {
    final double phi = _phase - v * turns * 2 * math.pi;
    final double x = radius * math.cos(phi);
    final double round = radius * math.sin(phi);
    final double up = (v - 0.5) * turns * pitch;
    return FibrePoint(
      x,
      round * math.cos(tilt) - up * math.sin(tilt),
      round * math.sin(tilt) + up * math.cos(tilt),
    );
  }

  /// [_turnAt]'s way at [v], as a unit step.
  static FibrePoint _turnWay(double v) {
    const double h = 1e-4;
    final FibrePoint a = _turnAt(v - h);
    final FibrePoint b = _turnAt(v + h);
    final double dx = b.along - a.along;
    final double dy = b.across - a.across;
    final double dz = b.depth - a.depth;
    final double n = math.sqrt(dx * dx + dy * dy + dz * dz);
    return FibrePoint(dx / n, dy / n, dz / n);
  }

  static double _distance(FibrePoint a, FibrePoint b) => math.sqrt(
    math.pow(b.along - a.along, 2) +
        math.pow(b.across - a.across, 2) +
        math.pow(b.depth - a.depth, 2),
  );

  /// Where the DNA leaves the fibre's axis before the core and comes back
  /// to it after.
  static const FibrePoint _leaves = FibrePoint(-reach, 0, 0);
  static const FibrePoint _returns = FibrePoint(reach, 0, 0);

  /// How long the way in, the turns and the way out are, in base pairs'
  /// lengths: the share of a nucleosome's DNA each takes.
  static final (double, double, double) _lengths = () {
    final double turnsLong = math.sqrt(
      math.pow(turns * 2 * math.pi * radius, 2) + math.pow(turns * pitch, 2),
    );
    return (
      _distance(_leaves, _turnAt(0)),
      turnsLong,
      _distance(_turnAt(1), _returns),
    );
  }();

  /// The share of a nucleosome's DNA on its way in to the turns, and on
  /// its way out of them.
  @visibleForTesting
  static final double wayIn =
      _lengths.$1 / (_lengths.$1 + _lengths.$2 + _lengths.$3);
  @visibleForTesting
  static final double wayOut =
      _lengths.$3 / (_lengths.$1 + _lengths.$2 + _lengths.$3);

  /// The turns' way where they start.
  static final FibrePoint _inWay = _turnWay(0);

  /// The point [u] of the way along a nucleosome's DNA, about its core's
  /// middle, from where it leaves the fibre's axis before the core ([reach]
  /// to its left, u = 0) to where it comes back to it after ([reach] to its
  /// right, u = 1): in round the core's front from its left, 1.65 turns
  /// round it ([turns]), and out from behind it to the right.
  static FibrePoint coilAt(double u) {
    final double t = u.clamp(0.0, 1.0);
    final double a = wayIn;
    final double c = wayOut;
    if (t < a) {
      // In off the axis along it, meeting the turns along their way.
      return _hermite(
        _leaves,
        const FibrePoint(1, 0, 0),
        _turnAt(0),
        _inWay,
        _lengths.$1,
        t / a,
      );
    }
    if (t > 1 - c) {
      // Out from behind the core onto the axis, along it: it turns back
      // where the core hides it.
      final FibrePoint from = _turnAt(1);
      final double long = _lengths.$3;
      return _hermite(
        from,
        FibrePoint(
          (_returns.along - from.along) / long,
          (_returns.across - from.across) / long,
          (_returns.depth - from.depth) / long,
        ),
        _returns,
        const FibrePoint(1, 0, 0),
        long,
        (t - (1 - c)) / c,
      );
    }
    return _turnAt((t - a) / (1 - a - c));
  }

  /// The cubic from [p0] going [w0] to [p1] going [w1] (unit ways, scaled
  /// by [long]), [s] of the way along.
  static FibrePoint _hermite(
    FibrePoint p0,
    FibrePoint w0,
    FibrePoint p1,
    FibrePoint w1,
    double long,
    double s,
  ) {
    final double s2 = s * s;
    final double s3 = s2 * s;
    final double h00 = 2 * s3 - 3 * s2 + 1;
    final double h10 = (s3 - 2 * s2 + s) * long;
    final double h01 = -2 * s3 + 3 * s2;
    final double h11 = (s3 - s2) * long;
    return FibrePoint(
      h00 * p0.along + h10 * w0.along + h01 * p1.along + h11 * w1.along,
      h00 * p0.across + h10 * w0.across + h01 * p1.across + h11 * w1.across,
      h00 * p0.depth + h10 * w0.depth + h01 * p1.depth + h11 * w1.depth,
    );
  }
}
