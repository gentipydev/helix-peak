import 'dart:math' as math;
import 'dart:ui';

import '../domain/genome_replication.dart';

/// An opened-out view of an established fork. Proteins are spread apart to
/// expose their active sites; nucleotide spacing is compressed. The two 100-nt
/// fragments share actual sequence coordinates with the timeline.
class ReplicationGeometry {
  ReplicationGeometry(this.frame, {this.top = 27, this.bottom = 550})
    : _leading = frame.pieces(leading: true),
      _lagging = frame.pieces(leading: false);

  final ReplicationFrame frame;
  static const Size designSize = Size(360, 600);
  static const double pitch = 1.8;
  final double top;
  final double bottom;
  final List<DaughterPiece> _leading;
  final List<DaughterPiece> _lagging;

  // Follow the fork, as the Ribosome follows its decoding centre.
  double yOf(double index) => forkY + (frame.fork - index) * pitch;
  double get forkY => 170;
  double get firstVisible => frame.fork - (bottom - forkY) / pitch;

  /// The first index drawn for the upper fork. Below the origin, the lower
  /// fork is this half turned about it.
  double get firstDrawn =>
      math.max(firstVisible, GenomeReplication.origin);

  /// How far [index] is from both forks, eased over [reach] nucleotides: 0
  /// at a fork, 1 well inside the bubble. The lower fork's factor is 1
  /// everywhere the tour looks, so a single fork is drawn as before.
  double _inside(double index, double reach) =>
      ease((frame.fork - index) / reach) *
      ease((index - frame.lowerFork) / reach);

  static double ease(double t) {
    final double v = t.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  Offset centre(double index, {required bool leading}) {
    final double opened = _inside(index, 58);
    return Offset(180 + (leading ? -1 : 1) * (12 + 91 * opened), yOf(index));
  }

  List<DaughterPiece> piecesOn({required bool leading}) =>
      leading ? _leading : _lagging;

  /// How far a piece's growing end is from its neighbour, as a weight: 1
  /// while it is free, 0 once it has closed on the next piece or the fork.
  double _free(List<DaughterPiece> list, int k) {
    final DaughterPiece piece = list[k];
    final double gap = piece.threePrimeAtFrom
        ? (k == 0 ? double.infinity : piece.from - list[k - 1].to)
        : (k + 1 < list.length ? list[k + 1].from : frame.fork) - piece.to;
    return ease(gap / 3);
  }

  /// How fully the template at [index] is wound into a duplex with its new
  /// strand: 1 inside a piece, easing to 0 over 12 nt behind a free 3′ end
  /// and over 8 nt past a 5′ end. Continuous in position and in time, so a
  /// strand never kinks where a fragment starts, ends or joins another.
  double paired(double index, {required bool leading}) {
    final List<DaughterPiece> list = piecesOn(leading: leading);
    double best = 0;
    for (int k = 0; k < list.length; k++) {
      final DaughterPiece piece = list[k];
      final double free = _free(list, k);
      final double value;
      if (index >= piece.from && index <= piece.to) {
        value = 1 - free * (1 - ease(piece.fromThreePrime(index) / 12));
      } else {
        final double past = piece.threePrimeAtFrom
            ? index - piece.to
            : piece.from - index;
        if (past <= 0) {
          continue;
        }
        final double atEnd = 1 - free * (1 - ease(piece.length / 12));
        value = atEnd * (1 - ease(past / 8));
      }
      if (value > best) {
        best = value;
      }
    }
    return best;
  }

  /// How much of the new base at [index] is there: it grows in as the
  /// growing end crosses that base, and is whole once the end is past it. A
  /// base Pol δ takes over from a displaced primer was never missing.
  double presence(double index, {required bool leading}) {
    double best = 0;
    for (final DaughterPiece piece in piecesOn(leading: leading)) {
      final double inside = piece.fromThreePrime(index);
      final double pastFivePrime = piece.threePrimeAtFrom
          ? index - piece.to
          : piece.from - index;
      if (pastFivePrime > 0) {
        continue;
      }
      final double width = frame.growIn;
      if (inside < -0.5 * width) {
        continue;
      }
      final double grown = inside >= 0 && inside < piece.replaced
          ? 1.0
          : ((inside - piece.replaced + 0.5 * width) / width).clamp(0.0, 1.0);
      best = math.max(best, grown);
    }
    return best;
  }

  /// How much the new base at [index] is RNA rather than DNA. A base is the
  /// material its place in the strand makes it from its first moment; only
  /// where Pol δ displaces a primer does RNA give way to DNA gradually, over
  /// a width that opens from nothing as the front moves off.
  double rna(double index, {required bool leading}) {
    final List<DaughterPiece> list = piecesOn(leading: leading);
    final double half = frame.growIn / 2;
    double best = 0;
    for (int k = 0; k < list.length; k++) {
      final DaughterPiece piece = list[k];
      if (!piece.hasRna) {
        continue;
      }
      final bool joinedBelow = k > 0 && piece.from - list[k - 1].to < 1e-3;
      final bool joinedAbove =
          k + 1 < list.length && list[k + 1].from - piece.to < 1e-3;
      final double softBelow = joinedBelow && piece.rnaFrom <= piece.from + 1e-6
          ? math.min(half, list[k - 1].replaced)
          : 0;
      final double softAbove = joinedAbove && piece.rnaTo >= piece.to - 1e-6
          ? math.min(half, list[k + 1].replaced)
          : 0;
      // This piece's bases, the one still growing in at its free 3′ end, and
      // the blend across a displacement front.
      final double low =
          piece.from -
          (piece.threePrimeAtFrom && !joinedBelow ? half : softBelow);
      final double high =
          piece.to +
          (!piece.threePrimeAtFrom && !joinedAbove ? half : softAbove);
      if (index < low || index > high) {
        continue;
      }
      best = math.max(
        best,
        math.min(
          _side(index - piece.rnaFrom, softBelow),
          _side(piece.rnaTo - index, softAbove),
        ),
      );
    }
    return best;
  }

  static double _side(double inside, double soft) => soft <= 1e-9
      ? (inside >= 0 ? 1.0 : 0.0)
      : ((inside + soft) / (soft * 2)).clamp(0.0, 1.0);

  // Ahead of the fork the parental duplex winds tighter as the helicase
  // overwinds it: up to 45 nt ahead in full, easing to none at 60, where
  // topoisomerase II waits.
  static double _wound(double ahead) {
    if (ahead <= 45) {
      return ahead;
    }
    if (ahead >= 60) {
      return 52.5;
    }
    final double v = (ahead - 45) / 15;
    return 45 + 15 * (v - v * v * v + v * v * v * v / 2);
  }

  /// The parental helix's phase at [index], 0 at the fork: each multiple of
  /// π is where its strands pass from front to back.
  double parentalPhase(double index) {
    final double ahead = index - frame.fork;
    return (ahead + frame.overwinding * _wound(ahead)) * math.pi * 2 / 38;
  }

  /// The index ahead of the fork where the parental phase reaches [phase].
  double parentalIndexAt(double phase) {
    double low = frame.fork;
    double high = frame.fork + 38 * phase / (math.pi * 2) + 1;
    for (int k = 0; k < 40; k++) {
      final double middle = (low + high) / 2;
      if (parentalPhase(middle) < phase) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return (low + high) / 2;
  }

  /// Where topo II cuts each parental strand: four nucleotides apart, as
  /// its two tyrosines do.
  double parentalCut({required bool leading}) =>
      frame.topoIndex + (leading ? 2 : -2);

  /// How far topo II's opened gate holds a strand's cut ends apart: each
  /// end moves away from the cut, and the duplex further off stays put.
  double _gateShift(double index, {required bool leading}) {
    final double open = frame.topoGate;
    if (open <= 0) {
      return 0;
    }
    final double from = index - parentalCut(leading: leading);
    return (from >= 0 ? -1 : 1) * 6 * open * (1 - ease(from.abs() / 10));
  }

  Offset template(double index, {required bool leading}) {
    if (index >= frame.fork) {
      final double angle = parentalPhase(index);
      return Offset(
        180 + (leading ? -1 : 1) * 12 * math.cos(angle),
        yOf(index) + _gateShift(index, leading: leading),
      );
    }
    final Offset axis = centre(index, leading: leading);
    final double wound = paired(index, leading: leading);
    final double twist = 1 + wound * (math.cos(index * math.pi * 2 / 38) - 1);
    final double spread = 12 * _inside(index, 18);
    return axis + Offset((leading ? -1 : 1) * spread * twist, 0);
  }

  Offset daughter(double index, {required bool leading}) {
    final Offset axis = centre(index, leading: leading);
    return axis * 2 - template(index, leading: leading);
  }

  Offset get leadingEnzyme => centre(frame.leadingTip, leading: true);
  Offset get laggingEnzyme => centre(frame.deltaTip, leading: false);
  Offset get primase =>
      centre(frame.tipOf(frame.activeFragment), leading: false);
  Offset get nick => daughter(89.5, leading: false);
}
