import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../mutate/domain/apply_edit.dart';
import 'replication_plan.dart';
import 'seeded_draw.dart';

/// How much of the cell's error checking is switched on. Each level keeps the
/// one before it.
enum Fidelity {
  /// The polymerase's own choice of base, and nothing after it.
  polymerase,

  /// Plus proofreading: a wrong base stalls the polymerase, which steps back
  /// and cuts it out.
  proofreading,

  /// Plus mismatch repair, which finds what proofreading missed, behind the
  /// fork.
  repair;

  /// Errors per base copied, as the orders of magnitude usually given: about
  /// one in 10⁴ to 10⁵ for the polymerase alone, one in 10⁷ with
  /// proofreading, one in 10⁹ to 10¹⁰ with mismatch repair too.
  (double low, double high) get range => switch (this) {
    Fidelity.polymerase => (1e-5, 1e-4),
    Fidelity.proofreading => (1e-7, 1e-7),
    Fidelity.repair => (1e-10, 1e-9),
  };

  /// The rate errors are drawn at here: the middle of [range] on a log scale,
  /// since the range is orders of magnitude wide.
  double get rate => math.sqrt(range.$1 * range.$2);

  /// The share of the errors that got past the level before that this one
  /// lets through: its rate over the last one's. One for the polymerase.
  double get letThrough => switch (this) {
    Fidelity.polymerase => 1,
    Fidelity.proofreading =>
      Fidelity.proofreading.rate / Fidelity.polymerase.rate,
    Fidelity.repair => Fidelity.repair.rate / Fidelity.proofreading.rate,
  };
}

/// One base a polymerase got wrong while the record was copied, and what it
/// leaves in the record once the next round copies it.
@immutable
final class CopyingError {
  const CopyingError({
    required this.copy,
    required this.index,
    required this.newBase,
    required this.strand,
    required this.proofreadDraw,
    required this.repairDraw,
  });

  /// Which copy it was made in, counted from 1.
  final int copy;

  /// Where, as an index into the record's sequence.
  final int index;

  /// The record's letter at [index] once the error is copied in turn: the
  /// wrong base itself where it went into the sense strand, and its
  /// complement where it went into the antisense.
  final String newBase;

  /// Which new strand it went into.
  final NewStrand strand;

  /// Two draws, each above 0 and below 1. The error gets past proofreading
  /// when the first falls below the share proofreading lets through, and
  /// past mismatch repair when the second does too. So what survives one
  /// level always survived the one before it.
  final double proofreadDraw;
  final double repairDraw;

  bool survives(Fidelity fidelity) => switch (fidelity) {
    Fidelity.polymerase => true,
    Fidelity.proofreading => proofreadDraw < Fidelity.proofreading.letThrough,
    Fidelity.repair =>
      proofreadDraw < Fidelity.proofreading.letThrough &&
          repairDraw < Fidelity.repair.letThrough,
  };

  /// The error as an edit to the record, which the mutate screen reads the
  /// way it reads one a reader makes by hand.
  Substitution editOf(ReplicationPlan plan) =>
      Substitution(plan.positionOf(index), newBase);
}

/// The errors copying the record [copies] times makes, at the polymerase's
/// own rate, each with its chance of getting past the checks after it.
///
/// Each copy makes two new strands, so it copies twice the record's length.
/// The errors fall at random through all of those bases, at
/// [Fidelity.polymerase]'s rate: the gap to the next is drawn from the
/// geometric distribution that rate gives, so thousands of copies cost only
/// the errors themselves. Which of the three other letters a base becomes is
/// drawn at random too: real polymerases favour some slips over others, and
/// this does not model which. The draws are seeded with the record's letters,
/// so one record always gives the same errors, and a level's survivors are
/// always among the level before's.
final class ErrorTally {
  ErrorTally._(this.plan, this.copies, this.made);

  factory ErrorTally.of(ReplicationPlan plan, {int copies = defaultCopies}) {
    final SeededDraw draw = SeededDraw(seedOf(plan.sequence) ^ 0x5bd1e995);
    final int perCopy = 2 * plan.length;
    final int total = copies * perCopy;
    final double miss = math.log(1 - Fidelity.polymerase.rate);
    final List<CopyingError> made = <CopyingError>[];
    int at = -1;
    while (true) {
      at += 1 + (math.log(draw.unit()) / miss).floor();
      if (at >= total) {
        break;
      }
      final int within = at % perCopy;
      final int index = within % plan.length;
      final String was = plan.baseAt(index);
      final List<String> others = <String>[
        for (final String b in const <String>['A', 'C', 'G', 'T'])
          if (b != was) b,
      ];
      made.add(
        CopyingError(
          copy: at ~/ perCopy + 1,
          index: index,
          newBase: others[draw.between(0, 2)],
          strand: within < plan.length ? NewStrand.sense : NewStrand.antisense,
          proofreadDraw: draw.unit(),
          repairDraw: draw.unit(),
        ),
      );
    }
    return ErrorTally._(plan, copies, List<CopyingError>.unmodifiable(made));
  }

  /// How many times the tally copies the record.
  static const int defaultCopies = 1000;

  final ReplicationPlan plan;
  final int copies;

  /// Every error the polymerase made, in the order it made them.
  final List<CopyingError> made;

  /// The new bases the copies made between them.
  int get basesCopied => copies * 2 * plan.length;

  /// The errors [fidelity] lets through.
  List<CopyingError> survivors(Fidelity fidelity) => <CopyingError>[
    for (final CopyingError e in made)
      if (e.survives(fidelity)) e,
  ];

  /// How many would get through [fidelity] on average, at its middle rate.
  double expected(Fidelity fidelity) => basesCopied * fidelity.rate;
}
