import 'dart:math' as math;

import '../../../../core/biology/genetic_code.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../shared/format.dart';
import '../../replication/domain/seeded_draw.dart';
import 'challenge_materials.dart';
import 'daily_puzzle.dart';

/// Makes a day's puzzle on the phone: the same for every reader of that day,
/// from the date and the catalog, and never a call to the backend.
///
/// **The same from the date alone.** Each round draws from its own stream,
/// seeded with the day and the round's name ([SeededDraw], the same on every
/// platform), and the catalog is read sorted by slug, so every phone that
/// holds the same catalog draws the same proteins, stretches and codons.
///
/// **Never from a track the phone does not hold.** A round picks its protein
/// from the whole catalog first, by the date, and only then asks what the
/// phone holds of it ([ProteinMaterials]). Where the phone holds the fold, or
/// the sequence, the round is the one intended; where it does not, the same
/// protein is asked about from its catalog row alone ([IdentifyRound]). So a
/// reader with that protein's tracks gets the same round as every other such
/// reader, and one without gets the same fall-back as every other such
/// reader, and nothing one round falls back to moves another round's draws.
///
/// **ClinVar's words stay ClinVar's.** A changed residue is, where the phone
/// holds a snapshot with a missense record in the protein, that record's
/// change, and it is said to be reported there, in the record's own
/// classification. No sentence here says what a change does.
abstract final class PuzzleGenerator {
  /// The twenty amino acids by one-letter code, in the order draws index.
  static const String aminoAcids = 'ACDEFGHIKLMNPQRSTVWY';

  /// A codon round's length, and its time.
  static const int codons = 8;
  static const Duration codonTime = Duration(seconds: 45);

  /// How many residues a mutation round shows.
  static const int stretch = 12;

  /// The day [when] falls on, where the reader is, as ISO 8601 writes a
  /// date: `2026-09-28`.
  static String dayOf(DateTime when) =>
      '${when.year.toString().padLeft(4, '0')}-'
      '${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';

  static DailyPuzzle generate({
    required String day,
    required List<ProteinTarget> catalog,
    Map<String, ProteinMaterials> held = const <String, ProteinMaterials>{},
  }) {
    final List<ProteinTarget> proteins = <ProteinTarget>[...catalog]
      ..sort((ProteinTarget a, ProteinTarget b) => a.slug.compareTo(b.slug));
    if (proteins.length < 4) {
      throw ArgumentError('A puzzle needs a catalog of four proteins at least');
    }
    SeededDraw drawFor(String round) =>
        SeededDraw(seedOf('helix-peek challenge $day $round'));
    ProteinMaterials of(ProteinTarget target) =>
        held[target.slug] ?? ProteinMaterials.none;

    // Whose fold is this?
    final SeededDraw one = drawFor('fold');
    final ProteinTarget first = _pick(proteins, one);
    final List<ProteinTarget> firstOptions = _options(first, proteins, one);
    final ChallengeRound fold = of(first).fold
        ? FoldRound(subject: first, options: firstOptions)
        : IdentifyRound(
            subject: first,
            options: firstOptions,
            standsIn: ChallengeFormat.fold,
          );

    // Which residue differs? Another protein than the fold's.
    final SeededDraw two = drawFor('mutation');
    final ProteinTarget second = _pick(
      proteins.where((ProteinTarget t) => t != first).toList(),
      two,
    );
    final String? sequence = of(second).sequence;
    final ChallengeRound mutation = sequence != null && sequence.length > 1
        ? _mutation(second, sequence, of(second).reported, two)
        : IdentifyRound(
            subject: second,
            options: _options(second, proteins, two),
            standsIn: ChallengeFormat.mutation,
          );

    // Put a walk in order.
    final SeededDraw three = drawFor('walk');
    final ProteinTarget third = _pick(proteins, three);
    final List<String> pages = walkPagesOf(third);
    final WalkOrderRound walk = WalkOrderRound(
      subject: third,
      pages: pages,
      shown: _shuffled(pages.length, three),
    );

    // Codons against the clock.
    final CodonRound round = _codons(drawFor('codons'));

    return DailyPuzzle(
      day: day,
      rounds: List<ChallengeRound>.unmodifiable(<ChallengeRound>[
        fold,
        mutation,
        walk,
        round,
      ]),
    );
  }

  /// A protein's walk, page by page, from its catalog row: its gene, its mRNA
  /// where it has introns to splice out, its protein, its chains where it is
  /// cut into more than one, and its fold.
  static List<String> walkPagesOf(ProteinTarget target) {
    final ProteinFacts facts = target.facts;
    return <String>[
      'Its gene, ${spelled(facts.exons)} exon${facts.exons == 1 ? '' : 's'}',
      if (facts.exons > 1) 'Its mRNA, the exons spliced together',
      'Its protein, ${grouped(facts.residues)} residues',
      if (facts.chains > 1)
        'Its ${spelled(facts.chains)} chains, cut from the protein',
      'Its fold',
    ];
  }

  static ProteinTarget _pick(List<ProteinTarget> from, SeededDraw draw) =>
      from[draw.between(0, from.length - 1)];

  /// Four names: [subject]'s, and three whose numbers differ from its own, so
  /// a round asked from the numbers alone has one answer. The subject's place
  /// among them is drawn too.
  static List<ProteinTarget> _options(
    ProteinTarget subject,
    List<ProteinTarget> proteins,
    SeededDraw draw,
  ) {
    final String clue = IdentifyRound.cluesOf(subject);
    final List<ProteinTarget> eligible = proteins
        .where(
          (ProteinTarget t) => t != subject && IdentifyRound.cluesOf(t) != clue,
        )
        .toList();
    final List<ProteinTarget> chosen = <ProteinTarget>[];
    while (chosen.length < 3 && chosen.length < eligible.length) {
      final ProteinTarget next = _pick(eligible, draw);
      if (!chosen.contains(next)) {
        chosen.add(next);
      }
    }
    return List<ProteinTarget>.unmodifiable(
      chosen..insert(draw.between(0, chosen.length), subject),
    );
  }

  static MutationRound _mutation(
    ProteinTarget subject,
    String sequence,
    List<ReportedChange> reported,
    SeededDraw draw,
  ) {
    // A reported change, where the snapshot has one that fits this sequence.
    final List<ReportedChange> usable =
        <ReportedChange>[
          for (final ReportedChange change in reported)
            if (change.residue >= 1 &&
                change.residue <= sequence.length &&
                sequence[change.residue - 1] == change.from &&
                change.to != change.from &&
                aminoAcids.contains(change.to))
              change,
        ]..sort(
          (ReportedChange a, ReportedChange b) => a.residue != b.residue
              ? a.residue.compareTo(b.residue)
              : a.to.compareTo(b.to),
        );
    final int residue;
    final String to;
    String? reportedAs;
    if (usable.isNotEmpty) {
      final ReportedChange change = usable[draw.between(0, usable.length - 1)];
      residue = change.residue;
      to = change.to;
      reportedAs = change.classification;
    } else {
      residue = draw.between(1, sequence.length);
      final String others = aminoAcids.replaceAll(sequence[residue - 1], '');
      to = others[draw.between(0, others.length - 1)];
    }
    final int width = math.min(stretch, sequence.length);
    final int offset = draw.between(0, width - 1);
    final int start = (residue - 1 - offset).clamp(0, sequence.length - width);
    final String reference = sequence.substring(start, start + width);
    final int at = residue - 1 - start;
    return MutationRound(
      subject: subject,
      start: start + 1,
      reference: reference,
      changed: reference.replaceRange(at, at + 1, to),
      at: at,
      reportedAs: reportedAs,
    );
  }

  /// A draw of 0 to [n] - 1, never in order: Fisher and Yates, and a turn
  /// by one where the shuffle happens to land where it started.
  static List<int> _shuffled(int n, SeededDraw draw) {
    final List<int> order = List<int>.generate(n, (int i) => i);
    for (int i = n - 1; i > 0; i--) {
      final int j = draw.between(0, i);
      final int held = order[i];
      order[i] = order[j];
      order[j] = held;
    }
    bool inOrder = true;
    for (int i = 0; i < n; i++) {
      inOrder = inOrder && order[i] == i;
    }
    if (inOrder && n > 1) {
      order.add(order.removeAt(0));
    }
    return List<int>.unmodifiable(order);
  }

  static CodonRound _codons(SeededDraw draw) {
    const String bases = 'TCAG';
    final List<CodonQuestion> questions = <CodonQuestion>[];
    final Set<String> asked = <String>{};
    while (questions.length < codons) {
      final String codon =
          '${bases[draw.between(0, 3)]}${bases[draw.between(0, 3)]}'
          '${bases[draw.between(0, 3)]}';
      if (!asked.add(codon)) {
        continue;
      }
      final String answer = GeneticCode.translate(codon)!;
      final String pool = '$aminoAcids*'.replaceAll(answer, '');
      final List<String> options = <String>[];
      while (options.length < 3) {
        final String option = pool[draw.between(0, pool.length - 1)];
        if (!options.contains(option)) {
          options.add(option);
        }
      }
      final int at = draw.between(0, 3);
      options.insert(at, answer);
      questions.add(
        CodonQuestion(
          codon: codon,
          options: List<String>.unmodifiable(options),
          answer: at,
        ),
      );
    }
    return CodonRound(
      questions: List<CodonQuestion>.unmodifiable(questions),
      timeLimit: codonTime,
    );
  }
}
