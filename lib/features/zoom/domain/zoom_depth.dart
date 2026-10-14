import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../shared/format.dart';
import 'anatomy_figure.dart';
import 'anatomy_tables.dart';
import 'cell_archetypes.dart';
import 'locus_track.dart';
import 'zoom_path.dart';

/// The stops of the zoom, from the widest to the finest.
enum ZoomStop { body, organ, tissue, cell, nucleus, chromosome, band, dna }

/// What a stop's width is measured in. From the body down to the whole
/// chromosome the view is a stretch of space; from the chromosome down it
/// is a stretch of the genome, and the zoom's scale reads in base pairs.
enum ZoomUnit { metres, basePairs }

/// How deep the zoom is, as one number: [depth] runs from 0 at the body to
/// [total] at the DNA, through every stop in order.
///
/// Between two stops the view's width changes by the same factor for every
/// equal step of depth, so a step of the pinch multiplies the width as much
/// anywhere within a segment. A segment's depth is the number of tenfold
/// steps across it, but never fewer than [minimumTravel]: the nucleus is
/// about as wide as a long chromosome condensed, and the step between them
/// still has a story to tell (the territory condensing into a chromosome),
/// so it is given room.
///
/// The widths are what things measure: a body 1.8 metres across, its organ
/// as big as the organ is, a slice of tissue half a millimetre, a cell tens
/// of micrometres, its nucleus about ten. The chromosome is drawn at the
/// length it condenses to when a cell divides, which follows its base pairs;
/// below it, the band and the double helix are as many base pairs as each
/// spans.
@immutable
final class ZoomDepth {
  ZoomDepth(this.track, {required this.path})
    : organMetres = _organOf(track, path),
      archetype = archetypeOf(path) {
    // A nucleus is framed with room for its chromosome condensed, which for
    // a long chromosome in a small nucleus is the longer; a cell, with room
    // for its nucleus.
    nucleusMetres = math.max(
      archetype.nucleusViewMetres,
      1.15 * 1.5 * condensedLength,
    );
    cellMetres = math.max(archetype.viewMetres, 1.3 * nucleusMetres);
    final List<double> travel = <double>[];
    for (int k = 0; k + 1 < ZoomStop.values.length; k++) {
      travel.add(math.max(math.log(1 / ratioOf(k)) / math.ln10, minimumTravel));
    }
    _travel = List<double>.unmodifiable(travel);
    final List<double> at = <double>[0];
    for (final double t in travel) {
      at.add(at.last + t);
    }
    _at = List<double>.unmodifiable(at);
  }

  final LocusTrack track;
  final ZoomPath path;

  /// The kind of cell the path lands in, as it is drawn.
  final CellArchetype archetype;

  /// How wide the view is at the cell, in metres.
  late final double cellMetres;

  /// How wide the view is at the nucleus, in metres.
  late final double nucleusMetres;

  /// How wide the view is at the organ, in metres: the organ whole, with a
  /// margin round it.
  final double organMetres;

  late final List<double> _travel;
  late final List<double> _at;

  /// The least depth a segment between two stops is given.
  static const double minimumTravel = 0.6;

  /// How thick a base pair is along the double helix, in metres.
  static const double basePairMetres = 0.34e-9;

  /// How many times shorter a chromosome condensed for division is than its
  /// DNA stretched out.
  static const double condensation = 1e4;

  /// How wide the view is at the chromosome, against the chromosome's own
  /// length: a little narrower, so the chromosome, standing upright on a
  /// phone, fills most of the canvas's height.
  static const double chromosomeView = 0.9;

  /// How wide the view is at the DNA, in base pairs: the home screen's
  /// helix at its own proportions on a phone, a turn and a third of it.
  static const double dnaBasePairs = 14;

  /// How many of the gene's first bases the helix at the DNA carries: more
  /// than the view holds, as the home screen's helix runs off its edge.
  static const int helixBases = 33;

  /// How wide the view is at the body, in metres: a figure 1.70 m tall
  /// stands whole in a view as tall as it is wide.
  static const double bodyMetres = 1.8;

  /// The organ is drawn with a margin of this much of itself round it.
  static const double organMargin = 1.6;

  /// How wide the round field of the microscope is at the tissue, in
  /// metres: half a millimetre, what a ×40 objective shows.
  static const double tissueField = 5e-4;

  /// How wide the view is at the tissue, in metres: the field, with the
  /// dark of the eyepiece round it.
  static const double tissueMetres = 6e-4;

  /// How much taller than wide a phone's canvas is, about: a tall organ is
  /// framed by the canvas's height, not its width.
  static const double phoneAspect = 1.45;

  static double _organOf(LocusTrack track, ZoomPath path) {
    final String? tissue = path.tissue;
    final TissueAnatomy? anatomy = tissue == null
        ? null
        : tissueAnatomy[tissue];
    if (anatomy == null) {
      return 0.3;
    }
    return anatomy.metres * organMargin / uprightOf(track, path, anatomy);
  }

  /// How much taller than wide the organ is drawn, up to a phone's own
  /// proportions ([phoneAspect]), or 1 for one that is not: its longest
  /// side, standing upright, then takes the share of the canvas's height
  /// that a wide one's takes of its width. Read from the anatomogram's own
  /// outline, the one the organ's scene draws; an organ drawn from general
  /// anatomy, or the brain, is framed by its width.
  static double uprightOf(
    LocusTrack track,
    ZoomPath path,
    TissueAnatomy anatomy,
  ) {
    if (anatomy.inBrain != null ||
        anatomy.organ == OrganKind.lymphNode ||
        anatomy.organ == OrganKind.vessel ||
        anatomy.organ == OrganKind.skin ||
        anatomy.organ == OrganKind.parathyroid ||
        anatomy.organ == OrganKind.eye) {
      return 1;
    }
    final AnatomyFigure body = AnatomyFigure.bodyFor(path.tissue, <String>[
      for (final (String name, double _) in track.tissue.specific)
        ZoomPath.tissueName(name),
    ]);
    final AnatomyPart? part = body.parts[anatomy.uberon];
    if (part == null) {
      return 1;
    }
    final Rect box = part.box;
    return box.width <= 0
        ? 1
        : (box.height / box.width).clamp(1.0, phoneAspect);
  }

  /// How wide the view is at [stop], in [unitOf] it.
  double widthOf(ZoomStop stop) => switch (stop) {
    ZoomStop.body => bodyMetres,
    ZoomStop.organ => organMetres,
    ZoomStop.tissue => tissueMetres,
    ZoomStop.cell => cellMetres,
    ZoomStop.nucleus => nucleusMetres,
    ZoomStop.chromosome => chromosomeView * condensedLength,
    ZoomStop.band => 1.5 * track.bandLengthBp,
    ZoomStop.dna => dnaBasePairs,
  };

  /// What [stop]'s width is measured in. The chromosome is both: its view
  /// is [chromosomeBasePairs] of the genome as well as [widthOf] metres.
  static ZoomUnit unitOf(ZoomStop stop) =>
      stop.index <= ZoomStop.chromosome.index
      ? ZoomUnit.metres
      : ZoomUnit.basePairs;

  /// How long the chromosome is condensed for division, in metres.
  double get condensedLength =>
      track.length * basePairMetres / condensation;

  /// How many base pairs the view at the chromosome spans.
  double get chromosomeBasePairs => chromosomeView * track.length;

  /// How long [basePairs] of DNA would be stretched out, in metres.
  static double stretchedLength(int basePairs) => basePairs * basePairMetres;

  /// The width of the stop after segment [k]'s start, over its own: the
  /// factor the view narrows by across the segment, measured in the
  /// segment's unit (base pairs from the chromosome on).
  double ratioOf(int k) {
    final ZoomStop from = ZoomStop.values[k];
    final ZoomStop to = ZoomStop.values[k + 1];
    if (from == ZoomStop.chromosome) {
      return widthOf(to) / chromosomeBasePairs;
    }
    return widthOf(to) / widthOf(from);
  }

  /// How much depth segment [k] takes.
  double travelOf(int k) => _travel[k];

  /// The depth of the DNA, the deepest stop.
  double get total => _at.last;

  /// Where [stop] sits on the depth.
  double depthOf(ZoomStop stop) => _at[stop.index];

  /// The segment [depth] lies in, by the index of the stop it starts at, and
  /// how far along it, from 0 to 1. A stop is the start of the segment that
  /// leaves it; the last stop is the end of the last segment.
  (int, double) segmentAt(double depth) {
    final double d = depth.clamp(0.0, total);
    for (int k = 0; k + 1 < _at.length; k++) {
      if (d < _at[k + 1] || k + 2 == _at.length) {
        return (k, ((d - _at[k]) / _travel[k]).clamp(0.0, 1.0));
      }
    }
    return (_at.length - 2, 1);
  }

  /// How wide the view is at [depth], in [unitAt] it.
  double widthAt(double depth) {
    final (int k, double s) = segmentAt(depth);
    final ZoomStop from = ZoomStop.values[k];
    if (from != ZoomStop.chromosome) {
      return widthOf(from) * math.pow(ratioOf(k), s).toDouble();
    }
    final double basePairs =
        chromosomeBasePairs * math.pow(ratioOf(k), s).toDouble();
    // The chromosome is still drawn as it is in a dividing cell until the
    // view has turned it into the genome's map, half way to the band.
    return unitAt(depth) == ZoomUnit.metres
        ? basePairs * basePairMetres / condensation
        : basePairs;
  }

  /// What the width at [depth] is measured in: metres down to the
  /// chromosome and half way past it, base pairs from there on.
  ZoomUnit unitAt(double depth) {
    final (int k, double s) = segmentAt(depth);
    final int chromosome = ZoomStop.chromosome.index;
    return k < chromosome || (k == chromosome && s < 0.5)
        ? ZoomUnit.metres
        : ZoomUnit.basePairs;
  }

  /// The stop nearest [depth]: where a released pinch settles.
  ZoomStop nearest(double depth) {
    ZoomStop best = ZoomStop.body;
    double gap = double.infinity;
    for (final ZoomStop stop in ZoomStop.values) {
      final double d = (depthOf(stop) - depth).abs();
      if (d < gap) {
        gap = d;
        best = stop;
      }
    }
    return best;
  }

  /// The view's width at [depth], as the scale reads it: `30 µm`, `3.2 Mb`.
  String widthLabel(double depth) => labelAt(depth, widthAt(depth));

  /// [value], a length in the unit the view at [depth] is measured in, as
  /// the scale reads it: to two significant figures.
  String labelAt(double depth, double value) =>
      unitAt(depth) == ZoomUnit.metres
      ? lengthLabel(_round2(value))
      : basePairLabel(_round2(value));

  /// [value] to two significant figures.
  static double _round2(double value) {
    if (value <= 0) {
      return value;
    }
    final double scale = math
        .pow(10, 1 - (math.log(value) / math.ln10).floor())
        .toDouble();
    return (value * scale).round() / scale;
  }
}

/// A scale bar for a view [width] wide drawn [pixels] wide: the round length
/// it shows, in the view's own unit, what that is in pixels, and its label.
(double, double, String) scaleBar(
  double width,
  double pixels, {
  ZoomUnit unit = ZoomUnit.metres,
}) {
  final double target = width * 0.22;
  final double power = math
      .pow(10, (math.log(target) / math.ln10).floor())
      .toDouble();
  double length = power;
  for (final double step in <double>[2, 5, 10]) {
    if (power * step <= target) {
      length = power * step;
    }
  }
  return (
    length,
    length / width * pixels,
    unit == ZoomUnit.metres ? lengthLabel(length) : basePairLabel(length),
  );
}

String _trim(double value) {
  final String fixed = value >= 10
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// A length, in the unit that reads best: 2 m, 50 cm, 1 mm, 10 µm, 20 nm.
String lengthLabel(double metres) {
  if (metres >= 1) {
    return '${_trim(metres)} m';
  }
  if (metres >= 1e-2) {
    return '${_trim(metres * 1e2)} cm';
  }
  if (metres >= 1e-3) {
    return '${_trim(metres * 1e3)} mm';
  }
  if (metres >= 1e-6) {
    return '${_trim(metres * 1e6)} µm';
  }
  return '${_trim(metres * 1e9)} nm';
}

/// A stretch of the genome, in the unit that reads best: 135 Mb, 3.2 Mb,
/// 120 kb, 2 kb, 33 bp.
String basePairLabel(double basePairs) {
  if (basePairs >= 1e6) {
    return '${_trim(basePairs / 1e6)} Mb';
  }
  if (basePairs >= 1e3) {
    return '${_trim(basePairs / 1e3)} kb';
  }
  return '${_trim(basePairs)} bp';
}

/// A ruler's number for [position] where ticks are [step] apart, precise
/// enough that no two ticks read the same: 5 Mb; 5.23 Mb; 5,226 kb.
String rulerLabel(double position, double step) {
  if (step >= 1e6) {
    return '${_trim(position / 1e6)} Mb';
  }
  if (step >= 1e5) {
    return '${(position / 1e6).toStringAsFixed(1)} Mb';
  }
  if (step >= 1e4) {
    return '${(position / 1e6).toStringAsFixed(2)} Mb';
  }
  if (step >= 1e3) {
    return '${grouped((position / 1e3).round())} kb';
  }
  return '${grouped(position.round())} bp';
}
