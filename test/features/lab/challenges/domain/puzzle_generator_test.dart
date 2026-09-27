import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/genetic_code.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/challenges/domain/challenge_materials.dart';
import 'package:helixpeek/features/lab/challenges/domain/daily_puzzle.dart';
import 'package:helixpeek/features/lab/challenges/domain/puzzle_generator.dart';

import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';

/// The missense records of [target]'s stored ClinVar snapshot.
List<ReportedChange> _reported(ProteinTarget target) {
  final Map<String, dynamic> snapshot = jsonDecode(
    File(target.clinvarAsset).readAsStringSync(),
  ) as Map<String, dynamic>;
  return <ReportedChange>[
    for (final dynamic raw in snapshot['variants'] as List<dynamic>)
      ?ReportedChange.of(
        residue: (raw as Map<String, dynamic>)['residue'] as int?,
        proteinChange: raw['protein_change'] as String?,
        classification: raw['classification'] as String,
      ),
  ];
}

/// Every protein's fold, sequence and records held, as on a phone that has
/// opened them all.
final Map<String, ProteinMaterials> _everything = <String, ProteinMaterials>{
  for (final ProteinTarget t in TestCatalog.all)
    t.slug: ProteinMaterials(
      fold: true,
      sequence: recordOf(t).protein!.translation,
      reported: _reported(t),
    ),
};

/// Sequences held, and no ClinVar snapshot.
final Map<String, ProteinMaterials> _sequences = <String, ProteinMaterials>{
  for (final ProteinTarget t in TestCatalog.all)
    t.slug: ProteinMaterials(sequence: recordOf(t).protein!.translation),
};

DailyPuzzle _puzzle(
  String day, [
  Map<String, ProteinMaterials> held = const <String, ProteinMaterials>{},
]) => PuzzleGenerator.generate(day: day, catalog: TestCatalog.all, held: held);

/// [count] days in a row from 2026-01-01.
List<String> _days(int count) => <String>[
  for (int i = 0; i < count; i++)
    PuzzleGenerator.dayOf(DateTime(2026).add(Duration(days: i))),
];

void main() {
  group('from the date alone', () {
    test(
      'the same date makes the same puzzle, however the catalog is held',
      () {
        for (final String day in _days(40)) {
          final DailyPuzzle once = _puzzle(day, _everything);
          expect(_puzzle(day, _everything).key, once.key);
          final DailyPuzzle reversed = PuzzleGenerator.generate(
            day: day,
            catalog: TestCatalog.all.reversed.toList(),
            held: _everything,
          );
          expect(reversed.key, once.key, reason: day);
        }
      },
    );

    test('consecutive days differ', () {
      final List<String> days = _days(400);
      for (int i = 1; i < days.length; i++) {
        expect(
          _puzzle(days[i]).key,
          isNot(_puzzle(days[i - 1]).key),
          reason: days[i],
        );
        expect(
          _puzzle(days[i], _everything).key,
          isNot(_puzzle(days[i - 1], _everything).key),
          reason: days[i],
        );
      }
    });

    test('a day is the reader’s own date', () {
      expect(
        PuzzleGenerator.dayOf(DateTime(2026, 9, 28, 23, 59)),
        '2026-09-28',
      );
      expect(PuzzleGenerator.dayOf(DateTime(2027, 1, 2)), '2027-01-02');
    });

    test('one day’s puzzle is pinned, so no SDK can move it', () {
      final DailyPuzzle day = _puzzle('2026-09-28', _everything);
      expect(day.rounds.map((ChallengeRound r) => r.format), <ChallengeFormat>[
        ChallengeFormat.fold,
        ChallengeFormat.mutation,
        ChallengeFormat.walkOrder,
        ChallengeFormat.codons,
      ]);
      expect(day.key, _pinned);
    });
  });

  group('never from a track the phone does not hold', () {
    test(
      'holding nothing, the two rounds that need tracks ask from the catalog',
      () {
        for (final String day in _days(30)) {
          final List<ChallengeRound> rounds = _puzzle(day).rounds;
          expect(rounds[0], isA<IdentifyRound>());
          expect((rounds[0] as IdentifyRound).standsIn, ChallengeFormat.fold);
          expect(rounds[1], isA<IdentifyRound>());
          expect(
            (rounds[1] as IdentifyRound).standsIn,
            ChallengeFormat.mutation,
          );
          expect(rounds[2], isA<WalkOrderRound>());
          expect(rounds[3], isA<CodonRound>());
        }
      },
    );

    test(
      'holding them, the rounds are the ones intended, about the same proteins',
      () {
        for (final String day in _days(30)) {
          final List<ChallengeRound> bare = _puzzle(day).rounds;
          final List<ChallengeRound> full = _puzzle(day, _everything).rounds;
          final FoldRound fold = full[0] as FoldRound;
          final IdentifyRound instead = bare[0] as IdentifyRound;
          expect(fold.subject, instead.subject);
          expect(fold.options, instead.options);
          expect(
            (full[1] as MutationRound).subject,
            (bare[1] as IdentifyRound).subject,
          );
          // Nothing held or not moves the rounds that need nothing.
          expect(full[2].key, bare[2].key);
          expect(full[3].key, bare[3].key);
        }
      },
    );

    test('only the one protein’s tracks decide its round', () {
      final DailyPuzzle bare = _puzzle('2026-09-28');
      final String subject = (bare.rounds[0] as IdentifyRound).subject.slug;
      final DailyPuzzle one = _puzzle('2026-09-28', <String, ProteinMaterials>{
        subject: const ProteinMaterials(fold: true),
      });
      expect(one.rounds[0], isA<FoldRound>());
      expect(one.rounds[1].key, bare.rounds[1].key);
    });
  });

  group('each round', () {
    test(
      'a fold or identify round offers four names, the answer among them',
      () {
        for (final String day in _days(60)) {
          for (final Map<String, ProteinMaterials> held
              in <Map<String, ProteinMaterials>>[
                <String, ProteinMaterials>{},
                _everything,
              ]) {
            final ChallengeRound round = _puzzle(day, held).rounds[0];
            final List<ProteinTarget> options = switch (round) {
              FoldRound(:final List<ProteinTarget> options) => options,
              IdentifyRound(:final List<ProteinTarget> options) => options,
              _ => throw StateError('round one is a fold or its fall-back'),
            };
            expect(options, hasLength(4));
            expect(options.toSet(), hasLength(4));
          }
        }
      },
    );

    test('its numbers name one protein among the four', () {
      for (final String day in _days(120)) {
        for (final ChallengeRound round in _puzzle(day).rounds) {
          if (round is IdentifyRound) {
            final Iterable<String> others = round.options
                .where((ProteinTarget t) => t != round.subject)
                .map(IdentifyRound.cluesOf);
            expect(others, isNot(contains(round.clue)), reason: day);
          }
        }
      }
    });

    test('a mutation round changes exactly one residue, and says where', () {
      for (final String day in _days(120)) {
        final MutationRound round =
            _puzzle(day, _everything).rounds[1] as MutationRound;
        final String sequence = recordOf(round.subject).protein!.translation;
        expect(round.reference.length, round.changed.length);
        expect(
          round.reference.length,
          lessThanOrEqualTo(PuzzleGenerator.stretch),
        );
        expect(
          sequence.substring(
            round.start - 1,
            round.start - 1 + round.reference.length,
          ),
          round.reference,
        );
        final List<int> differ = <int>[
          for (int i = 0; i < round.reference.length; i++)
            if (round.reference[i] != round.changed[i]) i,
        ];
        expect(differ, <int>[round.at], reason: day);
      }
    });

    test('a reported change is the record’s, in ClinVar’s own words', () {
      int reported = 0;
      for (final String day in _days(120)) {
        final MutationRound round =
            _puzzle(day, _everything).rounds[1] as MutationRound;
        final String? classification = round.reportedAs;
        if (classification == null) {
          continue;
        }
        reported++;
        final bool found = _reported(round.subject).any(
          (ReportedChange c) =>
              c.residue == round.residue &&
              c.from == round.reference[round.at] &&
              c.to == round.changed[round.at] &&
              c.classification == classification,
        );
        expect(found, isTrue, reason: '${round.subject.slug} ${round.change}');
        expect(round.reveal, contains('ClinVar has a record of'));
        expect(round.reveal, contains('reported there as'));
      }
      expect(reported, greaterThan(0));
    });

    test('a change made for the puzzle says so, and claims no record', () {
      for (final String day in _days(40)) {
        final MutationRound round =
            _puzzle(day, _sequences).rounds[1] as MutationRound;
        expect(round.reportedAs, isNull);
        expect(round.reveal, contains('was made for this puzzle'));
        expect(round.reveal, isNot(contains('ClinVar')));
      }
    });

    test('a walk is shown out of order, and its order is the walk’s', () {
      for (final String day in _days(60)) {
        final WalkOrderRound round = _puzzle(day).rounds[2] as WalkOrderRound;
        expect(round.pages.first, startsWith('Its gene'));
        expect(round.pages.last, 'Its fold');
        expect(round.shown.toSet(), <int>{
          for (int i = 0; i < round.pages.length; i++) i,
        });
        expect(
          round.shown,
          isNot(<int>[for (int i = 0; i < round.pages.length; i++) i]),
        );
      }
    });

    test('a codon round: eight codons, each answer the genetic code’s', () {
      for (final String day in _days(60)) {
        final CodonRound round = _puzzle(day).rounds[3] as CodonRound;
        expect(round.questions, hasLength(PuzzleGenerator.codons));
        expect(
          round.questions.map((CodonQuestion q) => q.codon).toSet(),
          hasLength(8),
        );
        expect(round.timeLimit, PuzzleGenerator.codonTime);
        for (final CodonQuestion q in round.questions) {
          expect(q.options.toSet(), hasLength(4));
          expect(q.options[q.answer], GeneticCode.translate(q.codon));
        }
      }
    });
  });

  group('the words', () {
    test('no question says a variant causes anything', () {
      final RegExp cause = RegExp(r'\bcause', caseSensitive: false);
      for (final String day in _days(365)) {
        for (final Map<String, ProteinMaterials> held
            in <Map<String, ProteinMaterials>>[
              <String, ProteinMaterials>{},
              _sequences,
              _everything,
            ]) {
          for (final String text in _puzzle(day, held).texts) {
            expect(text.contains('causes'), isFalse, reason: text);
            expect(cause.hasMatch(text), isFalse, reason: text);
          }
        }
      }
    });

    test('a reported record is quoted, never restated', () {
      final ReportedChange? change = ReportedChange.of(
        residue: 6,
        proteinChange: 'p.E6V',
        classification: 'Pathogenic',
      );
      expect(change!.from, 'E');
      expect(change.to, 'V');
      expect(
        ReportedChange.of(
          residue: 6,
          proteinChange: 'p.E7V',
          classification: 'x',
        ),
        isNull,
      );
      expect(
        ReportedChange.of(
          residue: 24,
          proteinChange: 'p.W24*',
          classification: 'x',
        ),
        isNull,
      );
      expect(
        ReportedChange.of(
          residue: null,
          proteinChange: null,
          classification: 'x',
        ),
        isNull,
      );
    });
  });
}

/// 2026-09-28's puzzle on a phone holding every track, as first made.
const String _pinned =
    '2026-09-28\n'
    'fold leptin leptin,lysozyme,somatotropin,app\n'
    'mutation glucagon 147 ADGSFSDEMNTI ADGSFSDEMNTV Benign\n'
    'walk oxytocin 3,2,1,0,4\n'
    'codons TAT:YSVR GCG:GLRA ATC:*IAG ACG:TQCR GCT:DQ*A AGT:*LST ACC:EGYT GCA:ACLW';
