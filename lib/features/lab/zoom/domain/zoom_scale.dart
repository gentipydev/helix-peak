import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'locus_track.dart';

/// The levels the zoom snaps to, from the widest to the finest.
enum ZoomLevel { body, organ, tissue, cell, nucleus, chromosome, gene }

/// How wide the view is at each level, and the one value the zoom runs on.
///
/// The zoom is one number, from 0 at the body to 1 at the gene, and the
/// logarithm of the view's width is linear in it: every step of a pinch
/// multiplies the width by the same factor, so a body two metres across and
/// a double helix two nanometres across are one continuous movement apart.
/// Each level snaps at the width it is drawn at.
///
/// The widths are what things measure, not per protein: a body is about 1.7
/// metres tall, a slice of tissue under a microscope half a millimetre
/// across, a cell tens of micrometres and its nucleus about ten. The one
/// level that differs by protein is the chromosome, drawn at the length it
/// condenses to when a cell divides, which follows its base pairs.
@immutable
final class ZoomScale {
  ZoomScale(this.track)
    : _logs = <double>[
        for (final ZoomLevel level in ZoomLevel.values)
          math.log(widthOf(level, track)) / math.ln10,
      ];

  final LocusTrack track;
  final List<double> _logs;

  /// How thick a base pair is along the double helix, in metres.
  static const double basePairMetres = 0.34e-9;

  /// How many times shorter a chromosome condensed for division is than its
  /// DNA stretched out.
  static const double condensation = 1e4;

  /// How wide the view is at the gene: 12 nm, a few turns of the helix.
  static const double geneWidth = 1.2e-8;

  /// How many of the gene's base pairs the view at its level holds, with a
  /// base pair's width kept clear at each end.
  static final int helixBases = (geneWidth / basePairMetres).floor() - 2;

  /// How wide the view is at [level], in metres.
  static double widthOf(ZoomLevel level, LocusTrack track) => switch (level) {
    ZoomLevel.body => 2.2,
    ZoomLevel.organ => 0.3,
    ZoomLevel.tissue => 5e-4,
    ZoomLevel.cell => 4e-5,
    ZoomLevel.nucleus => 1.5e-5,
    ZoomLevel.chromosome => 1.5 * condensedLength(track),
    ZoomLevel.gene => geneWidth,
  };

  /// How long [track]'s chromosome is condensed for division, in metres.
  static double condensedLength(LocusTrack track) =>
      track.length * basePairMetres / condensation;

  /// How long its DNA would be stretched out, in metres.
  static double stretchedLength(int basePairs) => basePairs * basePairMetres;

  /// Where [level] sits on the zoom, from 0 to 1.
  double zoomOf(ZoomLevel level) =>
      (_logs.first - _logs[level.index]) / (_logs.first - _logs.last);

  /// How wide the view is at [zoom], in metres.
  double widthAt(double zoom) {
    final double z = zoom.clamp(0.0, 1.0);
    return math
        .pow(10, _logs.first + (_logs.last - _logs.first) * z)
        .toDouble();
  }

  /// The zoom a view [width] metres wide sits at.
  double zoomAt(double width) =>
      ((_logs.first - math.log(width) / math.ln10) / (_logs.first - _logs.last))
          .clamp(0.0, 1.0);

  /// The level nearest [zoom]: where a released pinch settles.
  ZoomLevel nearest(double zoom) {
    ZoomLevel best = ZoomLevel.body;
    double gap = double.infinity;
    for (final ZoomLevel level in ZoomLevel.values) {
      final double d = (zoomOf(level) - zoom).abs();
      if (d < gap) {
        gap = d;
        best = level;
      }
    }
    return best;
  }

  /// The two levels [zoom] lies between, and how far from the first to the
  /// second, from 0 to 1.
  (ZoomLevel, ZoomLevel, double) between(double zoom) {
    final double z = zoom.clamp(0.0, 1.0);
    for (int i = 0; i + 1 < ZoomLevel.values.length; i++) {
      final double from = zoomOf(ZoomLevel.values[i]);
      final double to = zoomOf(ZoomLevel.values[i + 1]);
      if (z <= to || i + 2 == ZoomLevel.values.length) {
        return (
          ZoomLevel.values[i],
          ZoomLevel.values[i + 1],
          to <= from ? 1 : ((z - from) / (to - from)).clamp(0.0, 1.0),
        );
      }
    }
    return (ZoomLevel.chromosome, ZoomLevel.gene, 1);
  }

  /// How much of [level]'s layer shows at [zoom], from 0 to 1: all of it at
  /// its own snap point, crossfading into the next as the view closes in on
  /// it, and out of the one before as it pulls back.
  double presence(ZoomLevel level, double zoom) {
    final (ZoomLevel from, ZoomLevel to, double p) = between(zoom);
    final double into = _fade(p);
    if (level == from) {
      return 1 - into;
    }
    if (level == to) {
      return into;
    }
    return 0;
  }

  /// The crossfade: the layer being left holds until a third of the way
  /// and is gone by four fifths, so each is seen whole at its own level.
  static double _fade(double p) {
    final double t = ((p - 0.35) / 0.45).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

/// A scale bar for a view [width] metres across drawn [pixels] wide: the
/// round length it shows, in metres, what that is in pixels, and its label.
(double, double, String) scaleBar(double width, double pixels) {
  final double target = width * 0.22;
  final double power = math
      .pow(10, (math.log(target) / math.ln10).floor())
      .toDouble();
  double metres = power;
  for (final double step in <double>[2, 5, 10]) {
    if (power * step <= target) {
      metres = power * step;
    }
  }
  return (metres, metres / width * pixels, lengthLabel(metres));
}

/// A length, in the unit that reads best: 2 m, 50 cm, 1 mm, 10 µm, 20 nm.
String lengthLabel(double metres) {
  String trim(double value) {
    final String fixed = value >= 10
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  if (metres >= 1) {
    return '${trim(metres)} m';
  }
  if (metres >= 1e-2) {
    return '${trim(metres * 1e2)} cm';
  }
  if (metres >= 1e-3) {
    return '${trim(metres * 1e3)} mm';
  }
  if (metres >= 1e-6) {
    return '${trim(metres * 1e6)} µm';
  }
  return '${trim(metres * 1e9)} nm';
}
