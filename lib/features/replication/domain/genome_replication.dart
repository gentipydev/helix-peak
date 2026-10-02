import 'package:flutter/foundation.dart';

import 'monotone_curve.dart';

/// A human origin firing, and one of its two forks followed through two
/// 100-nt Okazaki fragments. Coordinates increase in the direction the upper
/// fork travels. A leading daughter grows towards larger indices; a lagging
/// daughter grows towards smaller ones. Base i spans i − 0.5 to i + 0.5, and
/// every end below is exact: a strand grows, and a primer is replaced,
/// continuously, never a whole base at once.
///
/// The lower fork is the upper one turned 180° about the origin, as the
/// MCM double hexamer that starts them is two-fold symmetric: each fork's
/// leading strand begins at the origin, and each lagging strand ends there.
/// In cells the two forks move independently; here they mirror each other.
///
/// This illustrative sequence is not a gene or a reference-genome locus.
abstract final class GenomeReplication {
  static const int windowBases = 200;
  static const int fragmentBases = 100;
  static const int rnaBases = 10;
  static const int alphaBases = 20;
  static const int leadingTrail = 36;

  /// Where the bubble opens. A multiple of 19, half the drawn helix's turn,
  /// so the helix is point-symmetric about it.
  static const double origin = -95;

  // The leading template, read 3′ → 5′ as indices increase towards the fork.
  // A fixed teaching sequence; repeats outside the window provide context.
  static const String sequence =
      'ACGTTGCAAGTCGATCGTACGATTCGACCTAGGCTAACGTCAGTCGATGC'
      'TACCGATGCTAGTCGATCGAGCTTACGGTACAGCTAGCATGACCTGATCGA'
      'GCTAGTCAGATCGGATCATGCTAGCATCGATGGCATACGTAGCTTACGATCG'
      'ATGCATCGACTAGGCTACGATTCAGCTAGCATGGTACCTAGCATCGA';

  /// The origin's 61 bases, from 30 before it to 30 after: an A/T-rich
  /// unwinding element of 25 bases between G/C-rich flanks. Illustrative:
  /// human origins share no consensus sequence.
  static const String originRegion =
      'GCCGCGGCTGCCGGCGCC'
      'ATTTATAATTAATATTTAAATATTT'
      'GGCGCCGGCTGCCGCGGC';

  static const int unwindingHalf = 12;

  static String templateAt(int index) {
    final int fromStart = index - origin.toInt() + 30;
    if (fromStart >= 0 && fromStart < originRegion.length) {
      return originRegion[fromStart];
    }
    return sequence[index % sequence.length];
  }

  /// Hydrogen bonds holding the pair at [index]: two for A·T, three for G·C.
  static int hydrogenBonds(int index) =>
      switch (templateAt(index)) { 'A' || 'T' => 2, _ => 3 };

  static String complement(String base, {bool rna = false}) => switch (base) {
    'A' => rna ? 'U' : 'T',
    'T' || 'U' => 'A',
    'C' => 'G',
    'G' => 'C',
    _ => throw ArgumentError.value(base, 'base'),
  };
}

enum ReplicationStage {
  origin('Origin', -60),
  licensing('Licensing', -52),
  firing('Firing', -40),
  bubble('Two forks', -30),
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
/// and [to] on the leading one. [rnaFrom] to [rnaTo] is where its RNA lies
/// once made, so a base is RNA or DNA from the moment it starts to grow.
@immutable
class DaughterPiece {
  const DaughterPiece({
    required this.from,
    required this.to,
    required this.threePrimeAtFrom,
    this.rnaFrom = 0,
    this.rnaTo = 0,
    this.replaced = 0,
    this.sealBelow = 0,
    this.sealAbove = 0,
  });

  final double from;
  final double to;
  final bool threePrimeAtFrom;
  final double rnaFrom;
  final double rnaTo;

  /// How much of the piece, from its 3′ end, took over bases that another
  /// piece had already paired: those were never missing.
  final double replaced;

  /// How far the nick at each end, where it meets the next piece, is sealed.
  final double sealBelow;
  final double sealAbove;

  double get length => to - from;
  double get threePrime => threePrimeAtFrom ? from : to;
  bool get hasRna => rnaTo > rnaFrom;

  /// How far [index] lies inside the piece from its growing end.
  double fromThreePrime(double index) =>
      threePrimeAtFrom ? index - from : to - index;

  /// This piece as the other fork has it: turned about the origin, onto the
  /// other template.
  DaughterPiece get mirrored {
    const double twice = GenomeReplication.origin * 2;
    return DaughterPiece(
      from: twice - to,
      to: twice - from,
      threePrimeAtFrom: !threePrimeAtFrom,
      rnaFrom: hasRna ? twice - rnaTo : 0,
      rnaTo: hasRna ? twice - rnaFrom : 0,
      replaced: replaced,
      sealBelow: sealAbove,
      sealAbove: sealBelow,
    );
  }
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

/// A later piece's Pol δ taking over an earlier piece's RNA primer: it
/// displaces the RNA into a flap in three strokes, pausing while FEN1 cuts
/// each flap away, and ligase then seals the nick left behind.
@immutable
class PrimerReplacement {
  const PrimerReplacement({
    required this.start,
    required this.stroke,
    required this.sealFrom,
    required this.sealTo,
  });

  final double start;
  final double stroke;
  final double sealFrom;
  final double sealTo;

  static const double flapCut = GenomeReplication.rnaBases / 3;

  double get end => start + 3 * stroke;

  /// Nucleotides of the primer displaced so far.
  double replaced(double seconds) {
    if (seconds <= start) {
      return 0;
    }
    final double strokes = (seconds - start) / stroke;
    if (strokes >= 3) {
      return GenomeReplication.rnaBases.toDouble();
    }
    final int k = strokes.floor();
    final double v = strokes - k;
    return flapCut * (k + v * v * (3 - 2 * v));
  }

  /// Stroke [k]'s flap, in nt, and how far FEN1 has taken it up once cut:
  /// null before the stroke starts and after the cut flap has gone.
  ({double length, double taken})? flap(double seconds, int k) {
    final double from = start + stroke * k;
    final double cut = from + stroke;
    if (seconds <= from || seconds >= cut + 0.8) {
      return null;
    }
    if (seconds < cut) {
      return (
        length: flapCut * ReplicationFrame.eased(seconds, from, cut),
        taken: 0,
      );
    }
    return (
      length: flapCut,
      taken: ReplicationFrame.eased(seconds, cut, cut + 0.8),
    );
  }

  double sealed(double seconds) =>
      ReplicationFrame.eased(seconds, sealFrom, sealTo);
}

@immutable
class ReplicationFrame {
  const ReplicationFrame(this.seconds);
  final double seconds;

  ReplicationStage get stage => ReplicationStage.values.lastWhere(
    (ReplicationStage stage) => seconds >= stage.second,
    orElse: () => ReplicationStage.origin,
  );

  static double progress(double time, double start, double end) =>
      ((time - start) / (end - start)).clamp(0.0, 1.0);

  /// [progress] that starts and finishes at rest.
  static double eased(double time, double start, double end) {
    final double v = progress(time, start, end);
    return v * v * (3 - 2 * v);
  }

  static const double _origin = GenomeReplication.origin;

  // --- The bubble ---

  // The origin melts inside the double hexamer (15 nt either side), then the
  // two forks run apart, easing into the fork's own pace as the tour joins
  // the upper one.
  static final MonotoneCurve _opening = MonotoneCurve(
    const <(double, double)>[(-36, 0), (-30, 15), (0, 205)],
    startSlope: 0,
    endSlope: 2,
  );

  // Two nucleotides a second until both fragments are primed, then slower,
  // turning the corner smoothly.
  static final MonotoneCurve _fork = MonotoneCurve(
    const <(double, double)>[(0, 110), (40, 190), (50, 210), (120, 240)],
    startSlope: 2,
  );

  /// The upper fork. Before the origin fires, it is the origin itself.
  double get fork =>
      seconds < 0 ? _origin + _opening.at(seconds) : _fork.at(seconds);

  /// The lower fork, the upper one turned about the origin.
  double get lowerFork => _origin * 2 - fork;

  // --- The leading strand, begun at the origin ---

  static final MonotoneCurve _primer = MonotoneCurve(
    const <(double, double)>[(-29, 0), (-26.5, 10), (-23, 30)],
    startSlope: 0,
    endSlope: 0,
  );

  /// The leading strand's 3′ end: primase and Pol α start it at the origin,
  /// and Pol ε then follows the helicase, 36 nt behind the fork.
  double get leadingTip {
    final double begun = _origin - 0.5 + _primer.at(seconds);
    final double following = fork - GenomeReplication.leadingTrail;
    // The later of the two, turning from one to the other without a jolt.
    const double soft = 12;
    final double lead = begun - following;
    if (lead <= -soft) {
      return following;
    }
    if (lead >= soft) {
      return begun;
    }
    return following + (lead + soft) * (lead + soft) / (4 * soft);
  }

  // --- Okazaki fragments on the upper fork's lagging strand ---

  static final MonotoneCurve _firstFragment = MonotoneCurve(
    const <(double, double)>[(0, 0), (1.5, 10), (3.5, 30), (11, 94)],
    startSlope: 0,
    endSlope: 0,
  );

  // RNA (10 nt) and Pol alpha DNA (20 nt); a rest while RFC takes the primer
  // end and loads PCNA; then Pol delta (70 nt), starting from rest and
  // slowing to a stop at the earlier fragment.
  static final MonotoneCurve _synthesis = MonotoneCurve(
    const <(double, double)>[(0, 0), (4, 10), (10, 30), (14, 30), (38, 100)],
    startSlope: 0,
    endSlope: 0,
  );

  /// When [fragment]'s primer starts: fragment −1 is the first the upper
  /// fork makes, from base −1 down to the origin; 0 and 1 are the tour's.
  static double primedAt(int fragment) => switch (fragment) {
    -1 => -16,
    0 => 8,
    _ => 50,
  };

  /// When Pol α has made [fragment]'s RNA–DNA primer and lets it go: RFC
  /// takes the primer end from it and loads PCNA there. The bubble's first
  /// fragment is primed too fast to show RFC: Pol δ takes it over at once.
  static double primerDoneAt(int fragment) =>
      primedAt(fragment) + (fragment < 0 ? 3.5 : 10);

  /// When Pol δ, on the clamp RFC has closed, takes over [fragment]'s primer
  /// end.
  static double handoffAt(int fragment) =>
      primedAt(fragment) + (fragment < 0 ? 3.5 : 14);

  /// Nucleotides laid down on [fragment]: RNA, then Pol alpha, then Pol delta.
  double lengthOf(int fragment) => fragment < 0
      ? _firstFragment.at(seconds - primedAt(fragment))
      : _synthesis.at(seconds - primedAt(fragment));

  /// [fragment]'s 5′ end, where its primer starts.
  static double fivePrimeOf(int fragment) =>
      (fragment + 1) * GenomeReplication.fragmentBases - 0.5;

  /// The growing 3′ end of [fragment].
  double tipOf(int fragment) => fivePrimeOf(fragment) - lengthOf(fragment);

  // --- Primer replacement ---

  /// Each lagging fragment reaches the primer ahead of it and replaces it:
  /// fragment −1 the other fork's leading primer at the origin, fragment 0
  /// fragment −1's, and fragment 1 fragment 0's, which the tour watches.
  static const PrimerReplacement atOrigin = PrimerReplacement(
    start: -5,
    stroke: 1,
    sealFrom: -2,
    sealTo: 0,
  );
  static const PrimerReplacement earlier = PrimerReplacement(
    start: 50,
    stroke: 4 / 3,
    sealFrom: 54.5,
    sealTo: 56,
  );
  static const PrimerReplacement later = PrimerReplacement(
    start: 88,
    stroke: 4,
    sealFrom: 102,
    sealTo: 110,
  );

  static const double flapCut = PrimerReplacement.flapCut;
  static const double replaceStart = 88;
  static const double strokeSeconds = 4;

  double get replacedBases => later.replaced(seconds);

  /// Stroke [k] of fragment 0's primer replacement.
  ({double length, double taken})? flapOf(int k) => later.flap(seconds, k);

  double get sealing => later.sealed(seconds);
  bool get sealed => sealing >= 1;

  /// Over how many nucleotides a new base grows in as a strand's end passes
  /// it. The bubble grows several times faster than the tour's fork, so its
  /// bases grow in over more, taking about as long to appear; by the time
  /// the tour joins the fork, one nucleotide.
  double get growIn => 1 + 5 * (1 - eased(seconds, -3, 0));

  // --- Initiation ---

  /// How clearly the origin shows as an origin: its A/T-rich stretch and
  /// the hydrogen bonds of each base pair, until it melts.
  double get originShown =>
      eased(seconds, -60, -58.5) * (1 - eased(seconds, -36, -33));

  /// ORC, and Cdc6 with it, on the origin through licensing.
  double get orc =>
      eased(seconds, -51.5, -50) * (1 - eased(seconds, -42, -40.5));
  double get cdc6 =>
      eased(seconds, -50, -49) * (1 - eased(seconds, -42, -40.5));

  /// Each MCM2–7 hexamer arrives open with Cdt1, closes round the duplex
  /// and slides to meet the other head to head.
  double get mcmArrive => eased(seconds, -49.5, -47.5);
  double get mcmClosed => eased(seconds, -47.5, -46.5);
  double get mcmDocked => eased(seconds, -46.5, -45);
  double get cdt1 => mcmArrive * (1 - eased(seconds, -46, -44.5));

  /// Cdc45 and GINS join each MCM ring, making a CMG helicase.
  double get cmgPartners => eased(seconds, -39.5, -37);

  /// How far the CMGs have left dsDNA for single strands as the origin
  /// melts, passing each other on the way to their forks.
  double get cmgOnStrand => eased(seconds, -36, -32);

  // --- Topoisomerase II ahead of the fork ---
  //
  // Unwinding overwinds the DNA ahead; topo II captures a crossing duplex
  // (the T-segment), cuts the duplex it is bound to (the G-segment) with its
  // active-site tyrosines, passes the T-segment through the break and
  // reseals it, and the helix relaxes.

  /// Nucleotides between the fork and topoisomerase II while it waits.
  static const double topoAhead = 60;

  /// Topo II arrives ahead of each fork once the bubble opens.
  double get topoShown => eased(seconds, -20, -16);

  /// How much tighter than relaxed the DNA ahead of the fork is wound.
  double get overwinding =>
      0.7 * eased(seconds, -24, 5.2) * (1 - eased(seconds, 7, 7.9));

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
  double get topoCut =>
      eased(seconds, 6, 6.3) * (1 - eased(seconds, 7.05, 7.3));

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

  // --- The strands ---

  /// The upper fork's pieces: its leading strand on the left template, its
  /// lagging fragments on the right.
  List<DaughterPiece> _upper({required bool leading}) {
    final double atOriginDone = atOrigin.replaced(seconds);
    final double sealedAtOrigin = atOrigin.sealed(seconds);
    if (leading) {
      if (seconds < -29) {
        return const <DaughterPiece>[];
      }
      // Its primer begins at the origin, and the other fork's first
      // fragment displaces it from below.
      final double from = _origin - 0.5 + atOriginDone;
      final double tip = leadingTip;
      return <DaughterPiece>[
        if (tip > from)
          DaughterPiece(
            from: from,
            to: tip,
            threePrimeAtFrom: false,
            rnaFrom: from,
            rnaTo: _origin + 9.5,
            sealBelow: sealedAtOrigin,
          ),
      ];
    }
    final double earlierDone = earlier.replaced(seconds);
    final double laterDone = later.replaced(seconds);
    final List<DaughterPiece> pieces = <DaughterPiece>[];
    // Fragment −1 runs down to the origin, then displaces the other fork's
    // leading primer; fragment 0 later displaces its own primer.
    if (lengthOf(-1) > 0) {
      final double from = tipOf(-1) - atOriginDone;
      final double to = -0.5 - earlierDone;
      pieces.add(
        DaughterPiece(
          from: from,
          to: to,
          threePrimeAtFrom: true,
          rnaFrom: -10.5,
          rnaTo: to,
          replaced: atOriginDone,
          sealBelow: sealedAtOrigin,
          sealAbove: earlier.sealed(seconds),
        ),
      );
    }
    if (lengthOf(0) > 0) {
      final double from = tipOf(0) - earlierDone;
      final double to = 99.5 - laterDone;
      pieces.add(
        DaughterPiece(
          from: from,
          to: to,
          threePrimeAtFrom: true,
          rnaFrom: 89.5,
          rnaTo: to,
          replaced: earlierDone,
          sealBelow: earlier.sealed(seconds),
          sealAbove: later.sealed(seconds),
        ),
      );
    }
    final double tip1 = tipOf(1);
    if (tip1 < 199.5) {
      pieces.add(
        DaughterPiece(
          // Once it reaches fragment 0, its end is the displacement front.
          from: tip1 > 99.5 ? tip1 : 99.5 - laterDone,
          to: 199.5,
          threePrimeAtFrom: true,
          rnaFrom: 189.5,
          rnaTo: 199.5,
          replaced: laterDone,
          sealBelow: later.sealed(seconds),
        ),
      );
    }
    return pieces;
  }

  /// The daughter pieces on one template, in index order, from both forks:
  /// below the origin, a template carries the other fork's pieces from the
  /// other template, turned about the origin.
  List<DaughterPiece> pieces({required bool leading}) {
    final List<DaughterPiece> pieces = <DaughterPiece>[
      for (final DaughterPiece piece in _upper(leading: !leading))
        piece.mirrored,
      ..._upper(leading: leading),
    ]..sort((DaughterPiece a, DaughterPiece b) => a.from.compareTo(b.from));
    return pieces;
  }

  /// Where neighbouring pieces on one template meet or face each other.
  List<PieceJunction> junctions({required bool leading}) {
    final List<DaughterPiece> list = pieces(leading: leading);
    return <PieceJunction>[
      for (int k = 1; k < list.length; k++)
        PieceJunction(list[k - 1].to, list[k].from, list[k].sealBelow),
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
