import 'package:flutter/foundation.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../shared/format.dart';

/// What a round asks.
enum ChallengeFormat {
  /// Whose fold is this? The fold drawn, four names.
  fold,

  /// Which residue differs? Two stretches of one protein, one residue changed.
  mutation,

  /// Put a protein's walk in order, from its gene to its fold.
  walkOrder,

  /// What does each codon code for? Against the clock.
  codons,

  /// Which protein has these numbers? The one format that needs nothing but
  /// the catalog row, asked in place of a round whose protein this phone
  /// holds no tracks for.
  identify,
}

/// One round of a day's puzzle.
@immutable
sealed class ChallengeRound {
  const ChallengeRound();

  ChallengeFormat get format;

  /// The question, as the screen asks it.
  String get prompt;

  /// Everything the round will say: its prompt, its choices and what it says
  /// once answered. What the house rules are checked against.
  List<String> get texts;

  /// The round as one canonical line: two rounds are the same round exactly
  /// when their keys are equal.
  String get key;
}

/// Whose fold is this?
final class FoldRound extends ChallengeRound {
  const FoldRound({required this.subject, required this.options});

  /// The protein whose fold is drawn.
  final ProteinTarget subject;

  /// Four names, the subject's among them.
  final List<ProteinTarget> options;

  int get answer => options.indexOf(subject);

  @override
  ChallengeFormat get format => ChallengeFormat.fold;

  @override
  String get prompt => 'Whose fold is this?';

  @override
  List<String> get texts => <String>[
    prompt,
    for (final ProteinTarget option in options) option.display,
  ];

  @override
  String get key =>
      'fold ${subject.slug} '
      '${options.map((ProteinTarget t) => t.slug).join(',')}';
}

/// Which protein has these numbers? Asked from the catalog row alone.
final class IdentifyRound extends ChallengeRound {
  const IdentifyRound({
    required this.subject,
    required this.options,
    required this.standsIn,
  });

  final ProteinTarget subject;
  final List<ProteinTarget> options;

  /// The round this one is asked in place of: its protein's tracks are not on
  /// this phone, and the puzzle is made offline.
  final ChallengeFormat standsIn;

  int get answer => options.indexOf(subject);

  /// The subject's numbers, as its catalog row gives them.
  String get clue => cluesOf(subject);

  /// A protein's numbers: residues, exons, chains and bridges, in the words
  /// the walk's own badges use.
  static String cluesOf(ProteinTarget target) {
    final ProteinFacts facts = target.facts;
    String count(int n, String one) => '${grouped(n)} $one${n == 1 ? '' : 's'}';
    return <String>[
      count(facts.residues, 'residue'),
      count(facts.exons, 'exon'),
      count(facts.chains, 'chain'),
      count(facts.bridges, 'disulfide bridge'),
    ].join(' · ');
  }

  @override
  ChallengeFormat get format => ChallengeFormat.identify;

  @override
  String get prompt => 'Which protein has these numbers?';

  @override
  List<String> get texts => <String>[
    prompt,
    clue,
    for (final ProteinTarget option in options) option.display,
  ];

  @override
  String get key =>
      'identify for ${standsIn.name} ${subject.slug} '
      '${options.map((ProteinTarget t) => t.slug).join(',')}';
}

/// Which residue differs? The same stretch of one protein twice, one residue
/// changed in the second.
final class MutationRound extends ChallengeRound {
  const MutationRound({
    required this.subject,
    required this.start,
    required this.reference,
    required this.changed,
    required this.at,
    this.reportedAs,
  });

  final ProteinTarget subject;

  /// The stretch's first residue, numbered from 1 in the precursor.
  final int start;

  /// The stretch as the protein has it, and as changed.
  final String reference;
  final String changed;

  /// Where in the stretch the change is, from 0.
  final int at;

  /// Where the change is one ClinVar has a record of: the classification the
  /// record gives, quoted as ClinVar gives it and never restated. Null for a
  /// change made for the puzzle.
  final String? reportedAs;

  /// The residue changed, numbered in the precursor.
  int get residue => start + at;

  /// The change as the walk cites one: `Glu7Val`.
  String get change =>
      '${AminoAcids.abbreviationOf(reference[at])}$residue'
      '${AminoAcids.abbreviationOf(changed[at])}';

  /// What the round says once answered. A reported change keeps the words it
  /// is reported in: ClinVar reports it, and what the record says is ClinVar's
  /// to say ([reportedAs], shown as ClinVar's own words).
  String get reveal => reportedAs == null
      ? '$change was made for this puzzle: it is not a reported variant.'
      : '$change is a change ClinVar has a record of. It is reported there as:';

  @override
  ChallengeFormat get format => ChallengeFormat.mutation;

  @override
  String get prompt =>
      'Which residue of ${subject.display} differs, residues $start to '
      '${start + reference.length - 1}?';

  @override
  List<String> get texts => <String>[prompt, reveal, ?reportedAs];

  @override
  String get key =>
      'mutation ${subject.slug} $start $reference $changed '
      '${reportedAs ?? '-'}';
}

/// Put a protein's walk in order.
final class WalkOrderRound extends ChallengeRound {
  const WalkOrderRound({
    required this.subject,
    required this.pages,
    required this.shown,
  });

  final ProteinTarget subject;

  /// The walk's pages, in the order the walk turns them.
  final List<String> pages;

  /// The order they are shown in: [shown] lists indices into [pages].
  final List<int> shown;

  @override
  ChallengeFormat get format => ChallengeFormat.walkOrder;

  @override
  String get prompt =>
      'Put ${subject.display}’s walk in order, its gene first.';

  @override
  List<String> get texts => <String>[prompt, ...pages];

  @override
  String get key => 'walk ${subject.slug} ${shown.join(',')}';
}

/// One codon of a codon round, and the four answers offered for it.
@immutable
final class CodonQuestion {
  const CodonQuestion({
    required this.codon,
    required this.options,
    required this.answer,
  });

  /// The codon, 5' to 3', as DNA writes it.
  final String codon;

  /// Four one-letter codes, `*` for a stop.
  final List<String> options;

  /// Which of [options] the codon codes for.
  final int answer;

  /// What an option reads as: `Leucine`, or `Stop`.
  static String nameOf(String code) =>
      code == '*' ? 'Stop' : AminoAcids.nameOf(code);
}

/// What does each codon code for? Against the clock.
final class CodonRound extends ChallengeRound {
  const CodonRound({required this.questions, required this.timeLimit});

  final List<CodonQuestion> questions;
  final Duration timeLimit;

  @override
  ChallengeFormat get format => ChallengeFormat.codons;

  @override
  String get prompt =>
      'What does each codon code for? ${spelledLeading(questions.length)} '
      'codons, ${timeLimit.inSeconds} seconds.';

  @override
  List<String> get texts => <String>[
    prompt,
    for (final CodonQuestion q in questions) ...<String>[
      q.codon,
      ...q.options.map(CodonQuestion.nameOf),
    ],
  ];

  @override
  String get key =>
      'codons ${questions.map((CodonQuestion q) => '${q.codon}:${q.options.join()}').join(' ')}';
}

/// One day's puzzle: the same four rounds for every reader of that day, made
/// on the phone from the date and the catalog, with no call to the backend.
@immutable
final class DailyPuzzle {
  const DailyPuzzle({required this.day, required this.rounds});

  /// The day it is for, as ISO 8601 writes a date: `2026-09-28`.
  final String day;

  final List<ChallengeRound> rounds;

  /// The whole puzzle as canonical lines: equal exactly when the puzzles are.
  String get key => <String>[
    day,
    for (final ChallengeRound round in rounds) round.key,
  ].join('\n');

  /// Every word the puzzle says.
  Iterable<String> get texts =>
      rounds.expand((ChallengeRound round) => round.texts);
}
