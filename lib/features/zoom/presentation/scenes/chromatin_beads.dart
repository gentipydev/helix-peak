import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/chromatin_layout.dart';
import '../zoom_inks.dart';
import 'nucleosome_art.dart';

/// A gene's nucleosomes as beads on its DNA, from the gene's stop down into
/// its DNA (the user's choice of 2026-10-16: the gene as a stretch of
/// chromatin, still, and the step into the DNA going into the same beads).
///
/// Each bead is a real nucleosome at its own place in the textbook's packing
/// ([ChromatinLayout]), drawn as the step into the DNA draws its cores
/// ([NucleosomeArt]), where the DNA lies before it winds. Where they lie
/// closer than the eye can tell apart, only some are drawn: every other
/// one, every fourth, and so on. As the view closes in, the ones between
/// come up where they are, and none moves. The first past the gene's start,
/// which the DNA names further in, is always drawn.
abstract final class ChromatinBeads {
  /// The least room between two beads drawn whole, in pixels.
  static const double apart = 10;

  /// Over how many halvings of that room a bead comes up.
  static const double fade = 3;

  /// The least radius a bead is drawn at, in pixels: a nucleosome is
  /// smaller than that at every width wider than about a kilobase.
  static const double least = 3.6;

  static const ChromatinLayout _layout = ChromatinLayout();

  /// How many halvings short of room for every nucleosome the view is,
  /// where a base pair is [perBase] pixels: 0 where every one has room.
  static double levelAt(double perBase) => math.max(
    0,
    math.log(apart / (ChromatinLayout.period * perBase)) / math.ln2,
  );

  /// Which nucleosome winds the stretch from [start]: 0 the first past the
  /// gene's start and counting on downstream, -1 the promoter's and counting
  /// back upstream.
  static int indexOf(double start) {
    if (start >= ChromatinLayout.first) {
      return ((start - ChromatinLayout.first) / ChromatinLayout.period).round();
    }
    final double end = start + ChromatinLayout.wrapped;
    return -((ChromatinLayout.bareUpstream - end) / ChromatinLayout.period)
            .round() -
        1;
  }

  /// How much of nucleosome [index] shows [level] halvings short of room:
  /// whole where it is one of those every 2^[level] apart, coming up over
  /// [fade] halvings; the first past the start always.
  static double shownAt(int index, double level) {
    int n = index.abs();
    if (n == 0) {
      return 1;
    }
    int depth = 0;
    while (n.isEven) {
      n >>= 1;
      depth++;
    }
    final double t = ((depth + fade - level) / fade).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// The beads that reach into [from] to [to], in base pairs from the
  /// gene's 5′ end the genome's way, [level] halvings short of room for
  /// every one ([levelAt]): where each core's middle lies before its DNA
  /// winds, which nucleosome it is, and how much of it shows.
  static List<(double, int, double)> within(
    double from,
    double to,
    double level,
  ) {
    // Only every so many can show at all: the rest are not looked at.
    final int every = 1 << math.min(30, math.max(0, (level - fade).floor()));
    final List<(double, int, double)> out = <(double, int, double)>[];
    for (final (double start, double _) in _layout.nucleosomesWithin(
      from,
      to,
    )) {
      final int index = indexOf(start);
      if (index % every != 0) {
        continue;
      }
      final double shown = shownAt(index, level);
      if (shown > 0) {
        out.add((start + ChromatinLayout.across / 2, index, shown));
      }
    }
    return out;
  }

  /// Draws the beads from [from] to [to] (base pairs from the gene's 5′ end,
  /// the genome's way) on the line at [mid], [x] the screen x of such a
  /// place, a base pair [perBase] pixels, [level] halvings short of room for
  /// every one; [alphaAt] how much of a bead at a place shows besides.
  static void paint(
    Canvas canvas,
    ZoomInks inks, {
    required double Function(double offset) x,
    required double mid,
    required double from,
    required double to,
    required double perBase,
    required double level,
    double Function(double offset)? alphaAt,
  }) {
    for (final (double at, int _, double shown) in within(from, to, level)) {
      final double alpha = shown * (alphaAt?.call(at) ?? 1);
      if (alpha > 0.002) {
        NucleosomeArt.paint(
          canvas,
          Offset(x(at), mid),
          perBase,
          inks,
          alpha: alpha,
          least: least,
        );
      }
    }
  }
}
