import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A point of the DNA as it lies: along the fibre's axis and across it, in
/// base pairs' lengths (0.34 nm), and how near the reader it is.
@immutable
final class FibrePoint {
  const FibrePoint(this.along, this.across, this.depth);

  /// Along the fibre's axis, from the gene's 5′ end.
  final double along;

  /// Across it, down the screen.
  final double across;

  /// Toward the reader, from the fibre's axis: a point of a wound stretch
  /// with a positive depth passes in front of its histone core.
  final double depth;
}

/// A gene's DNA as chromatin packs it: wound round histone octamers, 147
/// base pairs to a nucleosome in 1.65 left-handed turns (Luger et al. 1997),
/// one every 200 base pairs, with the stretch round the gene's start bare
/// (Schones et al. 2008): the textbook's packing, not this gene's.
///
/// It lies along the zoom's genome first, every base pair a base pair's
/// length along the view, as the gene's stop lays it out; and as the view
/// closes in, it winds: [wound] from 0 to 1, each nucleosome's stretch
/// coiling round its core, the linkers between drawing the cores together,
/// until each nucleosome takes the length along the fibre its core does.
/// The bare stretch at the start never moves, so the gene's 5′ end stays
/// where it is.
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
  static const double tilt = 0.95;

  /// How much length along the fibre a wound nucleosome takes: its DNA's
  /// superhelix, edge to edge.
  static const double across = 2 * radius;

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

  /// How much shorter than its base pairs a wound nucleosome lies.
  static const double _gain = wrapped - across;

  /// Where along the fibre's axis the point [offset] base pairs from the
  /// gene's 5′ end lies, [wound] of the way wound, where it is not in a
  /// nucleosome's stretch: each nucleosome between it and the start draws
  /// it in by the length its winding saves.
  double axisAt(double offset, double wound) {
    if (offset >= first) {
      final double passed = ((offset - first) / period).floor() + 0.0;
      final double into = offset - first - passed * period;
      final double whole = passed + math.min(into / wrapped, 1);
      return offset - wound * _gain * whole;
    }
    if (offset <= bareUpstream) {
      final double passed = ((bareUpstream - offset) / period).floor() + 0.0;
      final double into = bareUpstream - offset - passed * period;
      final double whole = passed + math.min(into / wrapped, 1);
      return offset + wound * _gain * whole;
    }
    return offset;
  }

  /// The point [offset] base pairs from the 5′ end in the nucleosome that
  /// winds [start] to [start] + [wrapped], [wound] of the way wound: on the
  /// line the gene's stop lays it on, eased onto its turns round the core.
  FibrePoint woundAt(double start, double offset, double wound) {
    final double u = ((offset - start) / wrapped).clamp(0.0, 1.0);
    final double entry = axisAt(start, wound);
    final double straight =
        entry + (offset - start) * (1 - wound) + u * across * wound;
    if (wound <= 0) {
      return FibrePoint(offset, 0, 0);
    }
    // Round a core whose centre lies half its length along from where the
    // DNA comes in, seen from above and in front as a coin on a table is:
    // its face tilted [tilt] toward the reader. Left-handed: the DNA steps
    // down the core's axis as it goes round it, from the core's left.
    final double phi = math.pi + u * turns * 2 * math.pi;
    final double centre = entry + across / 2;
    final double x = centre + radius * math.cos(phi);
    final double round = radius * math.sin(phi);
    final double up = -(u - 0.5) * turns * pitch;
    final double down = round * math.cos(tilt) - up * math.sin(tilt);
    final double near = round * math.sin(tilt) + up * math.cos(tilt);
    return FibrePoint(
      straight + (x - straight) * wound,
      down * wound,
      near * wound,
    );
  }
}
