import 'package:flutter/foundation.dart';

import 'monotone_curve.dart';

/// One established human fork, with two 100-nt Okazaki fragments in view.
/// Coordinates increase in the direction of fork travel. A leading daughter
/// grows towards larger indices; a lagging daughter grows towards smaller ones.
/// Base i spans i − 0.5 to i + 0.5, and every end below is exact: a strand
/// grows, and a primer is replaced, continuously, never a whole base at once.
/// This illustrative sequence is not a gene or a reference-genome locus.
abstract final class GenomeReplication {
  static const int windowBases = 200;
  static const int fragmentBases = 100;
  static const int rnaBases = 10;
  static const int alphaBases = 20;
  static const int leadingTrail = 36;

  // The leading template, read 3′ → 5′ as indices increase towards the fork.
  // A fixed teaching sequence; repeats outside the window provide context.
  static const String sequence =
      'ACGTTGCAAGTCGATCGTACGATTCGACCTAGGCTAACGTCAGTCGATGC'
      'TACCGATGCTAGTCGATCGAGCTTACGGTACAGCTAGCATGACCTGATCGA'
      'GCTAGTCAGATCGGATCATGCTAGCATCGATGGCATACGTAGCTTACGATCG'
      'ATGCATCGACTAGGCTACGATTCAGCTAGCATGGTACCTAGCATCGA';

  static String templateAt(int index) => sequence[index % sequence.length];

  static String complement(String base, {bool rna = false}) => switch (base) {
    'A' => rna ? 'U' : 'T',
    'T' || 'U' => 'A',
    'C' => 'G',
    'G' => 'C',
    _ => throw ArgumentError.value(base, 'base'),
  };
}

enum ReplicationStage {
  unwind('Unwinding', 0),
  prime('Priming', 8),
  extend('Elongation', 20),
  primeAgain('Next primer', 50),
  extendAgain('Next fragment', 62),
  replace('Primer removal', 88),
  seal('Ligation', 102),
  continueFork('Fork continues', 112);

  const ReplicationStage(this.title, this.second);
  final String title;
  final double second;
}

enum DaughterBase { absent, rna, dna }

/// One piece of new strand paired with a template, between exact ends
/// ([from] below [to]). Its growing 3′ end is [from] on the lagging template
/// and [to] on the leading one; [rnaFrom] to [rnaTo] is its RNA, if any.
@immutable
class DaughterPiece {
  const DaughterPiece({
    required this.from,
    required this.to,
    required this.threePrimeAtFrom,
    this.rnaFrom = 0,
    this.rnaTo = 0,
    this.replaced = 0,
  });

  final double from;
  final double to;
  final bool threePrimeAtFrom;
  final double rnaFrom;
  final double rnaTo;

  /// How much of the piece, from its 3′ end, took over bases that another
  /// piece had already paired: those were never missing.
  final double replaced;

  double get length => to - from;
  double get threePrime => threePrimeAtFrom ? from : to;
  bool get hasRna => rnaTo > rnaFrom;

  /// How far [index] lies inside the piece from its growing end.
  double fromThreePrime(double index) =>
      threePrimeAtFrom ? index - from : to - index;
}

/// Two neighbouring pieces on one template: the upper end of the one below,
/// the lower end of the one above, and how far the break is sealed.
@immutable
class PieceJunction {
  const PieceJunction(this.lower, this.upper, this.sealed);
  final double lower;
  final double upper;
  final double sealed;

  double get gap => upper - lower;
}

@immutable
class ReplicationFrame {
  const ReplicationFrame(this.seconds);
  final double seconds;

  ReplicationStage get stage => ReplicationStage.values.lastWhere(
    (ReplicationStage stage) => seconds >= stage.second,
  );

  static double progress(double time, double start, double end) =>
      ((time - start) / (end - start)).clamp(0.0, 1.0);

  /// [progress] that starts and finishes at rest.
  static double eased(double time, double start, double end) {
    final double v = progress(time, start, end);
    return v * v * (3 - 2 * v);
  }

  // Two nucleotides a second until both fragments are primed, then slower,
  // turning the corner smoothly.
  static final MonotoneCurve _fork = MonotoneCurve(
    const <(double, double)>[(0, 110), (40, 190), (50, 210), (120, 240)],
    startSlope: 2,
  );

  // RNA (10 nt), Pol alpha DNA (20 nt), then Pol delta (70 nt), starting
  // from rest and slowing to a stop at the earlier fragment.
  static final MonotoneCurve _synthesis = MonotoneCurve(
    const <(double, double)>[(0, 0), (4, 10), (12, 30), (38, 100)],
    startSlope: 0,
    endSlope: 0,
  );

  /// The camera begins at an already active fork; origin firing occurs outside
  /// this window. Travel continues while each lagging fragment is synthesized.
  double get fork => _fork.at(seconds);

  double get leadingTip => fork - GenomeReplication.leadingTrail;

  static double primedAt(int fragment) => fragment == 0 ? 8 : 50;

  /// Nucleotides laid down on [fragment]: RNA, then Pol alpha, then Pol delta.
  double lengthOf(int fragment) =>
      _synthesis.at(seconds - primedAt(fragment));

  /// The growing 3′ end of [fragment]; its 5′ end is fixed at
  /// `(fragment + 1) * 100 - 0.5`.
  double tipOf(int fragment) =>
      (fragment + 1) * GenomeReplication.fragmentBases - 0.5 -
      lengthOf(fragment);

  /// Replacing the earlier fragment's primer takes three strokes: Pol delta
  /// displaces a third of it into a flap and pauses while FEN1 cuts it off.
  static const double flapCut = GenomeReplication.rnaBases / 3;
  static const double replaceStart = 88;
  static const double strokeSeconds = 4;

  double get replacedBases {
    if (seconds <= replaceStart) {
      return 0;
    }
    final double strokes = (seconds - replaceStart) / strokeSeconds;
    if (strokes >= 3) {
      return GenomeReplication.rnaBases.toDouble();
    }
    final int k = strokes.floor();
    final double v = strokes - k;
    return flapCut * (k + v * v * (3 - 2 * v));
  }

  /// Stroke [k] (0 to 2) of primer replacement: the RNA it has displaced
  /// into a flap, in nt, and once FEN1 has cut it, how far it has been taken
  /// up. Null before the stroke starts and after the cut flap has gone.
  ({double length, double taken})? flapOf(int k) {
    final double start = replaceStart + strokeSeconds * k;
    final double cut = start + strokeSeconds;
    if (seconds <= start || seconds >= cut + 0.8) {
      return null;
    }
    if (seconds < cut) {
      return (length: flapCut * eased(seconds, start, cut), taken: 0);
    }
    return (length: flapCut, taken: eased(seconds, cut, cut + 0.8));
  }

  // Topoisomerase II ahead of the fork. Unwinding overwinds the DNA ahead;
  // topo II captures a crossing duplex (the T-segment), cuts the duplex it
  // is bound to (the G-segment) with its active-site tyrosines, passes the
  // T-segment through the break and reseals it, and the helix relaxes.

  /// Nucleotides between the fork and topoisomerase II while it waits.
  static const double topoAhead = 60;

  /// How much tighter than relaxed the DNA ahead of the fork is wound.
  double get overwinding =>
      0.7 * eased(seconds, 0.5, 5.2) * (1 - eased(seconds, 7, 7.9));

  /// How firmly topo II holds the DNA it cuts: while it does, it moves with
  /// that DNA rather than staying a fixed distance ahead of the fork.
  double get topoEngaged =>
      eased(seconds, 5.4, 5.8) * (1 - eased(seconds, 7.8, 8.2));

  /// Where on the DNA topo II sits.
  double get topoIndex {
    final double waiting = fork + topoAhead;
    final double bound = _fork.at(5.8) + topoAhead;
    return waiting + (bound - waiting) * topoEngaged;
  }

  /// The G-segment's strands, cut (1) or whole (0).
  double get topoCut => eased(seconds, 6, 6.3) * (1 - eased(seconds, 7.05, 7.3));

  /// How far the DNA gate has opened the cut G-segment.
  double get topoGate =>
      eased(seconds, 6.1, 6.4) * (1 - eased(seconds, 7, 7.25));

  /// The active-site tyrosines at work, holding the cut ends.
  double get topoSites =>
      eased(seconds, 5.95, 6.2) * (1 - eased(seconds, 7.2, 7.5));

  /// The T-segment's way through: 0 arriving, 1 captured in the N-gate,
  /// 2 through the break into the C-gate, 3 released.
  double get transport =>
      eased(seconds, 5.2, 5.9) +
      eased(seconds, 6.35, 6.95) +
      eased(seconds, 7.3, 7.8);

  double get transportShown =>
      eased(seconds, 5.2, 5.7) * (1 - eased(seconds, 7.35, 7.8));

  double get sealing => eased(seconds, 102, 110);
  bool get sealed => sealing >= 1;

  /// Fragment 0 meets the offscreen fragment below it; that nick closes once
  /// the camera has moved on.
  double get earlierJoin => eased(seconds, 48, 51);

  /// The daughter pieces on one template, in index order.
  List<DaughterPiece> pieces({required bool leading}) {
    if (leading) {
      return <DaughterPiece>[
        DaughterPiece(from: -1e6, to: leadingTip, threePrimeAtFrom: false),
      ];
    }
    final double front = 99.5 - replacedBases;
    final List<DaughterPiece> pieces = <DaughterPiece>[
      const DaughterPiece(from: -1e6, to: -0.5, threePrimeAtFrom: true),
    ];
    final double tip0 = tipOf(0);
    if (tip0 < 99.5) {
      pieces.add(
        DaughterPiece(
          from: tip0,
          to: front,
          threePrimeAtFrom: true,
          rnaFrom: tip0 > 89.5 ? tip0 : 89.5,
          rnaTo: front,
        ),
      );
    }
    final double tip1 = tipOf(1);
    if (tip1 < 199.5) {
      pieces.add(
        DaughterPiece(
          // Once it reaches fragment 0, its end is the displacement front.
          from: tip1 > 99.5 ? tip1 : front,
          to: 199.5,
          threePrimeAtFrom: true,
          rnaFrom: tip1 > 189.5 ? tip1 : 189.5,
          rnaTo: 199.5,
          replaced: replacedBases,
        ),
      );
    }
    return pieces;
  }

  /// Where neighbouring lagging pieces meet or face each other.
  List<PieceJunction> junctions({required bool leading}) {
    if (leading) {
      return const <PieceJunction>[];
    }
    final List<DaughterPiece> list = pieces(leading: false);
    return <PieceJunction>[
      for (int k = 1; k < list.length; k++)
        PieceJunction(
          list[k - 1].to,
          list[k].from,
          k == 1 ? earlierJoin : sealing,
        ),
    ];
  }

  DaughterBase _baseOn(int index, List<DaughterPiece> list) {
    final double low = index - 0.5;
    final double high = index + 0.5;
    for (final DaughterPiece piece in list) {
      if (low >= piece.from - 1e-9 && high <= piece.to + 1e-9) {
        return piece.hasRna &&
                low >= piece.rnaFrom - 1e-9 &&
                high <= piece.rnaTo + 1e-9
            ? DaughterBase.rna
            : DaughterBase.dna;
      }
    }
    return DaughterBase.absent;
  }

  /// What the whole base at [index] is on the lagging daughter, if it is
  /// there yet.
  DaughterBase laggingAt(int index) {
    if (index >= GenomeReplication.windowBases) {
      return DaughterBase.absent;
    }
    return _baseOn(index, pieces(leading: false));
  }

  DaughterBase leadingAt(int index) =>
      _baseOn(index, pieces(leading: true));

  /// The nick is between bases 89 and 90 after the first RNA primer is gone.
  bool get hasNick => replacedBases >= 10 && !sealed;

  bool get priming =>
      stage == ReplicationStage.prime || stage == ReplicationStage.primeAgain;
  int get activeFragment => seconds < 50 ? 0 : 1;
  bool get deltaActive =>
      (seconds >= 20 && seconds < 46) || (seconds >= 62 && seconds < 100);
  double get deltaTip =>
      seconds >= replaceStart ? 99.5 - replacedBases : tipOf(activeFragment);

  @override
  bool operator ==(Object other) =>
      other is ReplicationFrame && other.seconds == seconds;
  @override
  int get hashCode => seconds.hashCode;
}
