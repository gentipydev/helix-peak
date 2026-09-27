import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import 'seeded_draw.dart';

/// Which new strand a piece is part of, named by the letters it carries.
enum NewStrand {
  /// The record's own letters, 5' to 3' as the sequence runs, made with the
  /// complementary parental strand as template.
  sense,

  /// Their complement, made with the record's own strand as template. Read
  /// 5' to 3' it runs down the sequence.
  antisense,
}

/// Which way from the origin a fork runs: towards the record's first base,
/// or its last.
enum Fork { left, right }

/// How much of one new base is there.
enum Made {
  /// Not made yet: the template base opposite is single-stranded.
  none,

  /// Primer: RNA, laid down by primase for a polymerase to extend.
  rna,

  /// DNA.
  dna,
}

/// One stretch of new strand, started from one primer: a whole leading
/// strand, or one Okazaki fragment.
///
/// Its bases are indices into the record's sequence, inclusive. A piece that
/// runs past the end of the record, as the forks do, keeps its whole length
/// here; only what lies inside the record is ever drawn.
@immutable
final class NewPiece {
  const NewPiece({
    required this.strand,
    required this.fork,
    required this.leading,
    required this.from,
    required this.to,
    required this.primedAt,
    required this.doneAt,
    this.ordinal = 0,
  });

  final NewStrand strand;
  final Fork fork;

  /// A leading strand: one piece, made towards its fork. Otherwise an Okazaki
  /// fragment, made away from it.
  final bool leading;

  final int from;
  final int to;

  /// A fragment's place in its fork's order, from 1 for the first primed; 0
  /// for a leading strand.
  final int ordinal;

  /// How far the forks have travelled, in bases, when this piece's primer
  /// goes down.
  final double primedAt;

  /// How far, when it is finished: made to its 3' end, through the primer
  /// it runs into, and sealed to what is beyond. A leading strand never runs
  /// into one, and is finished once it has left the record.
  final double doneAt;

  /// The sense strand is made up the sequence, 5' at [from]; the antisense
  /// down it, 5' at [to]. Polymerases build 5' to 3' only.
  bool get growsUp => strand == NewStrand.sense;

  /// Where the primer is.
  int get fivePrime => growsUp ? from : to;

  int get threePrime => growsUp ? to : from;

  int get length => to - from + 1;

  /// The primer's bases, the first [ReplicationPlan.primerLength] from the 5'
  /// end, inclusive.
  (int, int) get primer => growsUp
      ? (from, from + ReplicationPlan.primerLength - 1)
      : (to - ReplicationPlan.primerLength + 1, to);

  bool covers(int index) => index >= from && index <= to;

  @override
  String toString() =>
      'NewPiece(${strand.name}, ${fork.name}, '
      '${leading ? 'leading' : 'fragment $ordinal'}, $from-$to)';
}

/// How one record is copied: where the bubble opens, and every piece of new
/// strand each fork makes, when it is primed, extended and sealed, all
/// decided from the record before any frame is drawn.
///
/// The record's sequence is one strand, read 5' to 3' up its indices; its
/// complement is the other. A bubble opens at [origin] and two forks run out
/// of it at one pace, the right fork up the sequence and the left down it.
/// Everything happens at a fork's **travel**: how many bases it has unwound.
///
/// At each fork one new strand can grow the way the fork runs and is made in
/// one piece from a single primer: the leading strand. The other runs the
/// wrong way for a polymerase, which only builds 5' to 3', so it is made
/// backwards in Okazaki fragments, each from a primer of [primerLength] bases
/// laid down at the fork, [shortestFragment] to [longestFragment] bases
/// long, extended until it meets the piece before it. It then replaces that
/// piece's primer with DNA, and the nick left is sealed: stitched. The next
/// primer goes down as it finishes, so each fragment is finished exactly when
/// the next is primed, and one loop of template is in hand at a time.
///
/// The fragment lengths are drawn in their range from a generator seeded with
/// the record's own letters: the same record always gives the same fragments,
/// and nothing here names a gene.
final class ReplicationPlan {
  ReplicationPlan._({
    required this.record,
    required this.sequence,
    required this.origin,
    required this.pieces,
    required this.setPieceSite,
  }) : _sense = _sorted(pieces, NewStrand.sense),
       _antisense = _sorted(pieces, NewStrand.antisense);

  /// [record]'s replication. Refuses one [refusal] names a reason for.
  factory ReplicationPlan.of(GeneRecord record) {
    final String? refused = refusal(record);
    if (refused != null) {
      throw ArgumentError.value(record.gene, 'record', refused);
    }
    final String sequence = record.sequence.toUpperCase();
    final int n = sequence.length;
    final int origin = n ~/ 2;
    final SeededDraw draw = SeededDraw(seedOf(sequence));

    // The fragments, as the 5' end of each and the one before it, out to the
    // first whose primer lies wholly past the end of the record: every primer
    // inside it then has a fragment beyond to replace it.
    final List<int> right = <int>[origin - 1];
    while (right.last - primerLength + 1 < n) {
      right.add(right.last + draw.between(shortestFragment, longestFragment));
    }
    final List<int> left = <int>[origin];
    while (left.last + primerLength - 1 >= 0) {
      left.add(left.last - draw.between(shortestFragment, longestFragment));
    }

    // A fork has unwound past a base when it has travelled this far.
    double rightPast(int index) => (index + 1 - origin).toDouble();
    double leftPast(int index) => (origin - index).toDouble();

    final List<NewPiece> pieces = <NewPiece>[
      NewPiece(
        strand: NewStrand.sense,
        fork: Fork.right,
        leading: true,
        from: origin,
        to: n - 1,
        primedAt: bubble.toDouble(),
        doneAt: rightPast(n - 1) + trail,
      ),
      NewPiece(
        strand: NewStrand.antisense,
        fork: Fork.left,
        leading: true,
        from: 0,
        to: origin - 1,
        primedAt: bubble.toDouble(),
        doneAt: leftPast(0) + trail,
      ),
      for (int k = 1; k < right.length; k++)
        NewPiece(
          strand: NewStrand.antisense,
          fork: Fork.right,
          leading: false,
          ordinal: k,
          from: right[k - 1] + 1,
          to: right[k],
          primedAt: rightPast(right[k]),
          doneAt: k + 1 < right.length
              ? rightPast(right[k + 1])
              : rightPast(right[k]) + (right[k] - right[k - 1]) + sealSpan,
        ),
      for (int k = 1; k < left.length; k++)
        NewPiece(
          strand: NewStrand.sense,
          fork: Fork.left,
          leading: false,
          ordinal: k,
          from: left[k],
          to: left[k - 1] - 1,
          primedAt: leftPast(left[k]),
          doneAt: k + 1 < left.length
              ? leftPast(left[k + 1])
              : leftPast(left[k]) + (left[k - 1] - left[k]) + sealSpan,
        ),
    ];

    return ReplicationPlan._(
      record: record,
      sequence: sequence,
      origin: origin,
      pieces: pieces,
      // Just past the second primer on the right, where the first fragment
      // has been stitched and let go, and the fork is quiet.
      setPieceSite:
          right[2 < right.length ? 2 : right.length - 1] + setPieceLead,
    );
  }

  /// Why [record] cannot be copied here, in one sentence, or null where it
  /// can.
  static String? refusal(GeneRecord record) {
    if (record.isIntronCompressed) {
      return 'Its introns arrive shortened, so the bases drawn are not one '
          'stretch of DNA a fork could copy.';
    }
    if (!RegExp(r'^[ACGTacgt]*$').hasMatch(record.sequence)) {
      return 'Its record holds a letter that is not A, C, G or T.';
    }
    // Room on the right for two fragments and the proofreading after them.
    final int half = record.sequence.length - record.sequence.length ~/ 2;
    if (half < 2 * longestFragment + setPieceLead + trail + 1) {
      return 'It is too short to show the fork making more than one '
          'fragment.';
    }
    return null;
  }

  static const int primerLength = 10;
  static const int shortestFragment = 100;
  static const int longestFragment = 200;

  /// How many bases each fork unwinds before the primers go down.
  static const int bubble = 12;

  /// How far a polymerase's 3' end trails the helicase ahead of it.
  static const int trail = 2;

  /// How much travel it takes to seal a nick once the gap is filled.
  static const double sealSpan = 4;

  /// How far past the second lagging primer the leading polymerase puts in
  /// the wrong base.
  static const int setPieceLead = 12;

  final GeneRecord record;

  /// The record's sequence, upper case: one strand, 5' to 3'.
  final String sequence;

  /// The first base the right fork copies. The left fork copies the base
  /// before it first.
  final int origin;

  /// Every piece of new strand, both strands, both forks.
  final List<NewPiece> pieces;

  /// Where, on the right fork's leading strand, the wrong base goes in.
  final int setPieceSite;

  /// The base put in there by mistake: the other purine for a purine, the
  /// other pyrimidine for a pyrimidine, which pairs with the template base
  /// as a wobble rather than not at all. The commonest slip a polymerase
  /// makes is of this kind.
  String get setPieceWrong => transitionOf(baseAt(setPieceSite));

  final List<NewPiece> _sense;
  final List<NewPiece> _antisense;

  int get length => sequence.length;

  NewPiece get rightLeading =>
      _sense.firstWhere((NewPiece p) => p.leading && p.fork == Fork.right);

  NewPiece get leftLeading =>
      _antisense.firstWhere((NewPiece p) => p.leading && p.fork == Fork.left);

  /// A fork's fragments, in the order it primes them.
  List<NewPiece> fragmentsOf(Fork fork) => <NewPiece>[
    for (final NewPiece p in pieces)
      if (!p.leading && p.fork == fork) p,
  ];

  /// How far the forks travel before every piece inside the record is
  /// finished.
  double get travelEnd => pieces
      .map((NewPiece p) => p.doneAt)
      .reduce((double a, double b) => a > b ? a : b);

  /// How far they travel before the right fork's leading polymerase reaches
  /// [setPieceSite]: its 3' end on the base before.
  double get setPieceTravel =>
      (setPieceSite - 1 + trail + 1 - origin).toDouble();

  /// Where the right fork is, as the index of the last base it has unwound.
  double rightFork(double travel) => origin - 1 + travel;

  /// Where the left fork is, likewise, counting down.
  double leftFork(double travel) => origin - travel;

  /// The record's letter at [index], and its complement.
  String baseAt(int index) => sequence[index];

  String partnerAt(int index) => complementOf(sequence[index]);

  /// The letter on [strand] at [index] once made.
  String newBaseAt(NewStrand strand, int index) =>
      strand == NewStrand.sense ? baseAt(index) : partnerAt(index);

  /// The record position [index] is: what the record's own coordinates, and
  /// the mutate screen, call it.
  int positionOf(int index) =>
      record.strand == -1 ? record.end - index : record.start + index;

  /// The other purine for a purine, the other pyrimidine for a pyrimidine.
  static String transitionOf(String base) => switch (base) {
    'A' => 'G',
    'G' => 'A',
    'C' => 'T',
    'T' => 'C',
    _ => throw ArgumentError.value(base, 'base', 'not A, C, G or T'),
  };

  static String complementOf(String base) => switch (base) {
    'A' => 'T',
    'T' => 'A',
    'G' => 'C',
    'C' => 'G',
    _ => throw ArgumentError.value(base, 'base', 'not A, C, G or T'),
  };

  // ---------------------------------------------------------------- reading

  /// The piece of [strand] whose bases include [index], or null.
  NewPiece? pieceAt(NewStrand strand, int index) {
    final List<NewPiece> sorted = strand == NewStrand.sense
        ? _sense
        : _antisense;
    int low = 0;
    int high = sorted.length - 1;
    while (low <= high) {
      final int middle = (low + high) >> 1;
      final NewPiece p = sorted[middle];
      if (index < p.from) {
        high = middle - 1;
      } else if (index > p.to) {
        low = middle + 1;
      } else {
        return p;
      }
    }
    return null;
  }

  /// The piece that runs into [piece]'s primer and replaces it: the one
  /// whose 3' end lies next to its 5' end. Null where none does inside the
  /// plan.
  NewPiece? replacerOf(NewPiece piece) {
    final int next = piece.growsUp ? piece.from - 1 : piece.to + 1;
    final NewPiece? found = pieceAt(piece.strand, next);
    return found != null && !found.leading && found.threePrime == next
        ? found
        : null;
  }

  /// How many bases past its primer [piece] has made at [travel]: for a
  /// fragment, its own and then the primer it replaces; for a leading strand,
  /// as far as its polymerase has followed the fork.
  int extensionAt(NewPiece piece, double travel) {
    if (travel < piece.primedAt) {
      return -1;
    }
    if (piece.leading) {
      final double fork = piece.fork == Fork.right
          ? rightFork(travel) - piece.fivePrime
          : piece.fivePrime - leftFork(travel);
      return (fork.floor() - trail - primerLength + 1).clamp(0, piece.length);
    }
    final double span = piece.doneAt - sealSpan - piece.primedAt;
    final double f = span <= 0
        ? 1
        : ((travel - piece.primedAt) / span).clamp(0.0, 1.0);
    return (f * piece.length).floor();
  }

  /// Whether the nick [piece]'s replacer leaves at the end of its primer has
  /// been sealed at [travel].
  bool sealedAt(NewPiece piece, double travel) {
    final NewPiece? replacer = replacerOf(piece);
    return replacer != null && travel >= replacer.doneAt;
  }

  /// What is made of [strand] at [index] when the forks have travelled
  /// [travel].
  Made madeAt(NewStrand strand, int index, double travel) {
    final NewPiece? piece = pieceAt(strand, index);
    if (piece == null || travel < piece.primedAt) {
      return Made.none;
    }
    // Counted from the 5' end: the primer first, then what follows it.
    final int along = piece.growsUp ? index - piece.from : piece.to - index;
    if (along < primerLength) {
      final NewPiece? replacer = replacerOf(piece);
      if (replacer != null) {
        // The replacer comes in at this piece's 5' end, next to its own 3'
        // end, and turns the primer to DNA base by base towards the piece's
        // own DNA.
        final int into =
            extensionAt(replacer, travel) - (replacer.length - primerLength);
        if (along < into) {
          return Made.dna;
        }
      }
      return Made.rna;
    }
    return along - primerLength < extensionAt(piece, travel)
        ? Made.dna
        : Made.none;
  }

  /// Whether a break no ligase has sealed yet lies between [index] and the
  /// base above it on [strand].
  bool nickAbove(NewStrand strand, int index, double travel) {
    final NewPiece? piece = pieceAt(strand, index);
    if (piece == null) {
      return false;
    }
    // The only one a piece has sits between the last base of its primer,
    // which its replacer turned to DNA, and the first of its own DNA.
    final int boundary = piece.growsUp
        ? piece.from + primerLength - 1
        : piece.to - primerLength;
    return boundary == index &&
        replacerOf(piece) != null &&
        madeAt(strand, index, travel) == Made.dna &&
        madeAt(strand, index + 1, travel) == Made.dna &&
        !sealedAt(piece, travel);
  }

  static List<NewPiece> _sorted(List<NewPiece> pieces, NewStrand strand) =>
      <NewPiece>[
        for (final NewPiece p in pieces)
          if (p.strand == strand) p,
      ]..sort((NewPiece a, NewPiece b) => a.from.compareTo(b.from));
}
