import '../../../../shared/format.dart';
import 'fidelity.dart';
import 'replication_plan.dart';
import 'replication_timeline.dart';

/// The words under a replication: one caption per chapter, and the lines
/// about fidelity beside them. Every number is counted off the plan and the
/// record; no caption names a gene or a protein.
final class ReplicationCaptions {
  ReplicationCaptions(this.plan)
    : _right = _inside(plan, Fork.right),
      _left = _inside(plan, Fork.left);

  final ReplicationPlan plan;

  /// Each fork's fragments with any base inside the record.
  final List<NewPiece> _right;
  final List<NewPiece> _left;

  String captionOf(
    ReplicationFrame frame,
    Fidelity fidelity,
  ) => switch (frame.phase) {
    ReplicationPhase.origin =>
      'A bubble opens in the middle of the record’s '
          '${grouped(plan.length)} base pairs, and a helicase loads at '
          'each side of it to unwind the two strands. The place is chosen '
          'for the picture: human origins are not set by one sequence.',
    ReplicationPhase.leading =>
      'A polymerase builds only 5′ to 3′. On one strand at each fork that '
          'is the way the fork runs, so the new copy is made in one piece '
          'from a single primer of ${spelled(ReplicationPlan.primerLength)} '
          'bases: the leading strand. Ahead of the fork, a topoisomerase '
          'cuts and rejoins the DNA so the twist the helicase winds on can '
          'spin out.',
    ReplicationPhase.lagging => _lagging(),
    ReplicationPhase.proofreading => proofreading(fidelity),
    ReplicationPhase.whole => _whole(),
    ReplicationPhase.done =>
      'Two copies of ${grouped(plan.length)} base pairs, each one old '
          'strand and one new: a leading strand made in one piece, and a '
          'lagging strand stitched from '
          '${_count(_right.length + _left.length, 'fragment')}.',
  };

  String _lagging() {
    final NewPiece first = plan.fragmentsOf(Fork.right).first;
    return 'The other strand runs the wrong way, so it is copied backwards, '
        'in pieces. Primase lays a primer of about '
        '${spelled(ReplicationPlan.primerLength)} bases at the fork, and a '
        'polymerase extends it ${grouped(first.length)} bases back to the '
        'piece before, replaces that piece’s primer with DNA, and ligase seals '
        'the nick. The template loops out, so this polymerase travels with '
        'the fork, the same way as the leading one.';
  }

  /// The set piece, as [fidelity] plays it.
  String proofreading(Fidelity fidelity) {
    final int site = plan.setPieceSite;
    final String wrong = plan.setPieceWrong;
    final String right = plan.baseAt(site);
    final String template = plan.partnerAt(site);
    final String where = grouped(plan.positionOf(site));
    return fidelity == Fidelity.polymerase
        ? 'At base $where the polymerase puts in $wrong opposite $template, '
              'and the mismatch stalls it. With no proofreading it builds on '
              'past it: the $wrong stays, and once this strand is copied in '
              'turn the record reads $wrong there, not $right.'
        : 'At base $where the polymerase puts in $wrong opposite $template, '
              'and the mismatch stalls it. It steps back one base, moving the '
              'new strand’s end into its proofreading site, cuts the $wrong out '
              'and puts in $right.';
  }

  String _whole() {
    final List<int> lengths = <int>[
      for (final NewPiece p in <NewPiece>[..._right, ..._left]) p.length,
    ];
    final int shortest = lengths.reduce((int a, int b) => a < b ? a : b);
    final int longest = lengths.reduce((int a, int b) => a > b ? a : b);
    return 'The forks run on past both ends of the record: '
        '${_count(_right.length, 'fragment')} on one lagging strand and '
        '${spelled(_left.length)} on the other, ${grouped(shortest)} to '
        '${grouped(longest)} bases each. Human cells make them '
        '${grouped(ReplicationPlan.shortestFragment)} to '
        '${grouped(ReplicationPlan.longestFragment)} bases long, because the '
        'fork has to copy through nucleosomes, spaced about every 200 bases.';
  }

  // -------------------------------------------------------------- fidelity

  /// What each level of checking is called on its button: short enough for
  /// three to share a phone's width. Each keeps the one before it.
  static String nameOf(Fidelity fidelity) => switch (fidelity) {
    Fidelity.polymerase => 'Polymerase',
    Fidelity.proofreading => '+ Proofread',
    Fidelity.repair => '+ Repair',
  };

  /// Its error rate, in the orders of magnitude given for it.
  static String rateOf(Fidelity fidelity) => switch (fidelity) {
    Fidelity.polymerase =>
      'The polymerase alone gets about 1 base in 10⁴ to 10⁵ wrong.',
    Fidelity.proofreading => 'With proofreading, about 1 in 10⁷ gets through.',
    Fidelity.repair => 'With mismatch repair as well, about 1 in 10⁹ to 10¹⁰.',
  };

  /// How often a copy of this record keeps an error at [fidelity].
  String perCopy(Fidelity fidelity) {
    final double each = 2 * plan.length * fidelity.rate;
    return 'Copying these ${grouped(plan.length)} base pairs makes '
        '${grouped(2 * plan.length)} new bases, so about one copy in '
        '${roughly(1 / each)} keeps an error.';
  }

  /// What the tally found at [fidelity].
  String tallyOf(ErrorTally tally, Fidelity fidelity) {
    final int found = tally.survivors(fidelity).length;
    return 'In ${grouped(tally.copies)} copies here, '
        '${found == 0 ? 'no error' : _count(found, 'error')} got through.';
  }

  /// [value], to two significant figures and grouped: 3,500, 1,100,000.
  static String roughly(double value) {
    if (value < 1) {
      return '1';
    }
    final int digits = value.floor().toString().length;
    final int step = digits <= 2 ? 1 : _power(10, digits - 2);
    return grouped((value / step).round() * step);
  }

  static int _power(int base, int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  static String _count(int count, String noun) =>
      '${spelled(count)} ${count == 1 ? noun : '${noun}s'}';

  static List<NewPiece> _inside(ReplicationPlan plan, Fork fork) => <NewPiece>[
    for (final NewPiece p in plan.fragmentsOf(fork))
      if (p.to >= 0 && p.from < plan.length) p,
  ];
}
