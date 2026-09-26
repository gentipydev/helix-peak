import 'dart:typed_data';
import 'dart:ui';

import 'anatomy_layout.dart';
import 'anatomy_motion.dart';

/// A translation has two spatial steps: fold each triplet where it can still
/// be read, then move the resulting residues into the protein layout.
/// Membership comes from genomic positions, including codons split by exons.
final class AnatomyTranslation {
  AnatomyTranslation({
    required this.target,
    required this.fromLayout,
    required this.toLayout,
    required int residueCount,
    this.sourceScrollOffset = 0,
  }) : bases = List<List<int>>.generate(residueCount, (_) => <int>[]) {
    for (int cell = 0; cell < target.length; cell++) {
      if (target[cell] >= 0) {
        bases[target[cell]].add(cell);
      }
    }
  }

  final Int32List target;
  final AnatomyLayout fromLayout;
  final AnatomyLayout toLayout;
  final double sourceScrollOffset;
  final List<List<int>> bases;

  double _cachedOpen = -1;
  late List<Offset> _origins;
  late List<Offset> _centres;
  late final List<Offset> _destinations = List<Offset>.generate(
    bases.length,
    toLayout.centreOf,
  );
  late final double _liftDistance =
      fromLayout.side -
      fromLayout.centreOf(bases.first.first).dy +
      sourceScrollOffset;

  // The source groove is frozen for a translation. Resolve its layout and
  // triplet centres once, rather than allocating layouts for every base/frame.
  void _prepare(double open) {
    if (open == _cachedOpen) {
      return;
    }
    _cachedOpen = open;
    final AnatomyLayout layout = fromLayout.opened(open);
    _origins = List<Offset>.generate(
      target.length,
      (int cell) => layout.centreOf(cell) - Offset(0, sourceScrollOffset),
    );
    _centres = <Offset>[
      for (final List<int> members in bases)
        members.fold(
              Offset.zero,
              (Offset sum, int cell) => sum + _origins[cell],
            ) /
            members.length.toDouble(),
    ];
  }

  static double phase(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  // All phases use the same forward clock, including on a reversed swipe.
  // UTRs have completely left before the first triplet starts folding.
  static double removal(double t) => AnatomyMotion.ease(phase(t, 0, 0.20));
  static double lift(double t) => AnatomyMotion.ease(phase(t, 0.08, 0.34));
  static double reflow(double t) => AnatomyMotion.ease(phase(t, 0.78, 0.94));

  static double compact(double t) => AnatomyMotion.ease(phase(t, 0.72, 0.80));
  static double expand(double t) => AnatomyMotion.ease(phase(t, 0.92, 1));

  /// Lettered tiles briefly become small beads while changing row order.
  /// Only the compact shapes travel; full-sized letters never cross each other.
  double sideAt(double t) {
    final double small = fromLayout.side * 0.30;
    return lerpDouble(fromLayout.side, small, compact(t))! +
        (toLayout.side - small) * expand(t);
  }

  static double residueInk(double t) =>
      1 -
      AnatomyMotion.ease(phase(t, 0.72, 0.765)) +
      AnatomyMotion.ease(phase(t, 0.94, 1));

  double swap(int residue, double t) => AnatomyMotion.staggered(
    phase(t, 0.24, 0.72),
    bases.length > 1 ? residue / (bases.length - 1) : 0,
    lead: 0.55,
  );

  static double fold(double swap) => AnatomyMotion.ease(phase(swap, 0, 0.56));
  static double baseOpacity(double swap) => swap < 0.56 ? 1 : 0;
  static double baseInk(double swap) =>
      1 - AnatomyMotion.ease(phase(swap, 0.06, 0.30));
  static double reveal(double swap) => AnatomyMotion.ease(phase(swap, 0.56, 1));

  /// The coding sequence rises into the space vacated by the 5′ UTR. The
  /// original scroll offset is absorbed in this motion, with no first-frame
  /// jump when the user swipes from the bottom of the transcript.
  Offset _lift(double t) => Offset(0, _liftDistance * lift(t));

  Offset centreOf(int residue, double t, {double open = 1}) {
    _prepare(open);
    final Offset folded = _centres[residue] + _lift(t);
    return Offset.lerp(folded, _destinations[residue], reflow(t))!;
  }

  Offset positionOf(int cell, double t, {double open = 1}) {
    _prepare(open);
    final Offset origin = _origins[cell];
    final int residue = target[cell];
    if (residue < 0) {
      final bool leading = cell < bases.first.first;
      return origin + Offset(0, (leading ? -18 : 18) * removal(t));
    }
    final Offset centre = _centres[residue];
    final Offset within = (origin - centre) * (1 - fold(swap(residue, t)));
    return centreOf(residue, t, open: open) + within * (1 - reflow(t));
  }
}
