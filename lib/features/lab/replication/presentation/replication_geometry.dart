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

  static double ease(double t) {
    final double v = t.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  Offset centre(double index, {required bool leading}) {
    final double opened = ease((frame.fork - index) / 58);
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
      if (inside < -0.5 || pastFivePrime > 0) {
        continue;
      }
      final double grown = inside >= 0 && inside < piece.replaced
          ? 1.0
          : (inside - piece.replaced + 0.5).clamp(0.0, 1.0);
      best = math.max(best, grown);
    }
    return best;
  }

  /// How much the new base at [index] is RNA rather than DNA, blended over
  /// half a nucleotide either side of an RNA run's ends, so a base changes
  /// colour smoothly as a displacement front passes it.
  double rna(double index, {required bool leading}) {
    double best = 0;
    for (final DaughterPiece piece in piecesOn(leading: leading)) {
      if (piece.hasRna) {
        final double inside = math.min(
          index - piece.rnaFrom,
          piece.rnaTo - index,
        );
        best = math.max(best, (inside + 0.5).clamp(0.0, 1.0));
      }
    }
    return best;
  }

  Offset template(double index, {required bool leading}) {
    if (index >= frame.fork) {
      final double angle = (index - frame.fork) * math.pi * 2 / 38;
      return Offset(
        180 + (leading ? -1 : 1) * 12 * math.cos(angle),
        yOf(index),
      );
    }
    final Offset axis = centre(index, leading: leading);
    final double gap = frame.fork - index;
    final double wound = paired(index, leading: leading);
    final double twist = 1 + wound * (math.cos(index * math.pi * 2 / 38) - 1);
    final double spread = 12 * ease(gap / 18);
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
