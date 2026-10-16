import 'dart:math' as math;

import '../../domain/chromatin_layout.dart';
import '../../domain/dna_dive.dart';

/// Which of a gene's nucleosomes are drawn, and how much of each, from the
/// gene's stop down into its DNA (the user's choice of 2026-10-16: the gene
/// as a stretch of chromatin, its nucleosomes wound and big enough to see).
///
/// Each is a real nucleosome at its own place in the textbook's packing
/// ([ChromatinLayout]). Where they lie closer than [apart], only some are
/// drawn, every one of them whole: every other one, every fourth, and so
/// on. As the view closes in, the ones between come up where they are once
/// they stand [apart] too, and none moves. The first past the gene's start,
/// which the DNA names further in, is always drawn.
abstract final class ChromatinBeads {
  /// The least room between two beads drawn, in pixels: a wound one,
  /// larger than life, is some 20 px across.
  static const double apart = 32;

  /// The least radius a bead's core is drawn at, in pixels: a nucleosome is
  /// smaller than that wherever the view is wider than about 600 bp.
  static const double least = 6;

  /// Over how much of the step into the DNA a bead comes up, in its depth:
  /// over four seconds at 60 fps, no faster than 0.08 a frame.
  static const double rise = 0.12;

  /// How many times nucleosome [index]'s number halves evenly: it is one of
  /// those every 2^depth apart. The first past the start is one of all.
  static int depthOf(int index) {
    int n = index.abs();
    if (n == 0) {
      return 62;
    }
    int depth = 0;
    while (n.isEven) {
      n >>= 1;
      depth++;
    }
    return depth;
  }

  /// Where the stretch nucleosome [index] winds starts, in base pairs from
  /// the gene's 5′ end: 0 the first past the gene's start and counting on
  /// downstream, -1 the promoter's and counting back upstream.
  static double startOf(int index) => index >= 0
      ? ChromatinLayout.first + index * ChromatinLayout.period
      : ChromatinLayout.bareUpstream -
            (-index - 1) * ChromatinLayout.period -
            ChromatinLayout.wrapped;

  /// Where nucleosome [index]'s core lies before the DNA packs, in base
  /// pairs from the gene's 5′ end.
  static double placeOf(int index) =>
      startOf(index) + ChromatinLayout.across / 2;

  /// How wide the view is, in base pairs, on a canvas [width] pixels wide,
  /// where the nucleosomes every 2^[depth] apart stand [apart].
  static double spanAt(int depth, double width) =>
      width * math.pow(2, depth) * ChromatinLayout.period / apart;

  /// The least depth whose nucleosomes stand [apart] where the view is
  /// [span] base pairs wide on a canvas [width] pixels wide: the beads drawn
  /// whole there.
  static int depthAt(double span, double width) {
    int depth = 0;
    while (depth < 62 && spanAt(depth, width) < span) {
      depth++;
    }
    return depth;
  }

  /// How much of nucleosome [index] shows [progress] of the way from the
  /// gene's stop to the DNA's, the gene's view [gene] base pairs across a
  /// canvas [width] pixels wide and the step spent as [dive] spends it:
  /// whole where its depth's beads stand [apart] at the gene's stop, and
  /// otherwise coming up over [rise] of the step from where they do. Keyed
  /// to the depth, it is the same either way.
  static double shownAt(
    int index,
    double progress, {
    required double gene,
    required double width,
    required DnaDive dive,
  }) {
    final double span = spanAt(depthOf(index), width);
    if (span >= gene) {
      return 1;
    }
    final double t = ((progress - dive.spentAt(span)) / rise).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// The least depth any bead shows at [progress] of the way to the DNA:
  /// the ones below it are not looked at.
  static int depthShownAt(
    double progress, {
    required double gene,
    required double width,
    required DnaDive dive,
  }) {
    int depth = 0;
    while (depth < depthAt(gene, width) &&
        shownAt(1 << depth, progress, gene: gene, width: width, dive: dive) <=
            0) {
      depth++;
    }
    return depth;
  }

  /// The nucleosomes every 2^[depth] apart whose stretches reach into
  /// [from] to [to], in base pairs from the gene's 5′ end, by index, in
  /// order along the gene: the first past the start among them, if it is
  /// there.
  static List<int> within(double from, double to, int depth) {
    final int step = 1 << math.min(depth, 30);
    const double period = ChromatinLayout.period;
    const double wrapped = ChromatinLayout.wrapped;
    final List<int> out = <int>[];
    // Upstream, nucleosome −(j + 1) is the j-th before the bare start: its
    // stretch ends at bareUpstream − j periods.
    final int jLow = math.max(
      0,
      ((ChromatinLayout.bareUpstream - wrapped - to) / period).floor() + 1,
    );
    final int jHigh =
        ((ChromatinLayout.bareUpstream - from) / period).ceil() - 1;
    if (jHigh >= jLow) {
      for (int q = (jHigh + 1) ~/ step; q * step >= jLow + 1; q--) {
        if (q > 0) {
          out.add(-q * step);
        }
      }
    }
    final int kLow = math.max(
      0,
      ((from - ChromatinLayout.first - wrapped) / period).floor() + 1,
    );
    final int kHigh = ((to - ChromatinLayout.first) / period).ceil() - 1;
    for (int k = (kLow + step - 1) ~/ step * step; k <= kHigh; k += step) {
      out.add(k);
    }
    return out;
  }
}
