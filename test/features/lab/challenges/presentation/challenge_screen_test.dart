import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/lab/challenges/domain/challenge_materials.dart';
import 'package:helixpeek/features/lab/challenges/domain/daily_puzzle.dart';
import 'package:helixpeek/features/lab/challenges/domain/puzzle_generator.dart';
import 'package:helixpeek/features/lab/challenges/presentation/challenge_card.dart';
import 'package:helixpeek/features/lab/challenges/presentation/challenge_ledger.dart';
import 'package:helixpeek/features/lab/challenges/presentation/challenge_screen.dart';
import 'package:helixpeek/features/lab/challenges/presentation/challenge_shelf.dart';
import 'package:helixpeek/shared/clinvar/evidence_row.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../../../support/catalog_api.dart';
import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';

const Size _phone = Size(390, 844);
final DateTime _today = DateTime(2026, 9, 28, 10);
final String _day = PuzzleGenerator.dayOf(_today);

/// Holds what a test says it holds, and remembers what it was asked about.
final class _Shelf implements ChallengeShelf {
  _Shelf([this.held = const <String, ProteinMaterials>{}]);

  final Map<String, ProteinMaterials> held;
  final List<String> asked = <String>[];

  @override
  Future<ProteinMaterials> materialsOf(ProteinTarget target) async {
    asked.add(target.slug);
    return held[target.slug] ?? ProteinMaterials.none;
  }
}

final class _Ledger implements ChallengeLedger {
  final Map<String, DayResult> days = <String, DayResult>{};

  @override
  Future<Map<String, DayResult>> read() async =>
      Map<String, DayResult>.of(days);

  @override
  Future<void> write(DayResult result) async => days[result.day] = result;
}

/// A ledger whose write waits until a test lets it finish.
final class _SlowLedger extends _Ledger {
  final Completer<void> release = Completer<void>();
  final List<DayResult> writes = <DayResult>[];

  @override
  Future<void> write(DayResult result) async {
    writes.add(result);
    await release.future;
    await super.write(result);
  }
}

/// A track source that must not be read: the puzzle is made offline.
final class _NoNetwork implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) =>
      throw StateError('read $kind of $slug: the puzzle must not ask');
}

/// What was shared.
final class _Shared {
  Uint8List? png;
  String? text;
  String? fileName;

  Future<void> sheet({
    required Uint8List png,
    required String fileName,
    required String text,
    Rect? origin,
  }) async {
    this.png = png;
    this.fileName = fileName;
    this.text = text;
  }
}

Future<ProteinCatalogRepository> _catalog(WidgetTester tester) async {
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(
    CatalogApi(),
    null,
  );
  addTearDown(catalog.dispose);
  await tester.runAsync(catalog.refresh);
  return catalog;
}

Future<void> _host(
  WidgetTester tester, {
  required ChallengeShelf shelf,
  required ChallengeLedger ledger,
  _Shared? shared,
  TrackSource? tracks,
  bool accessible = false,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final ProteinCatalogRepository catalog = await _catalog(tester);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<TrackSource>.value(value: tracks ?? _NoNetwork()),
      ],
      child: MaterialApp(
        theme: AppTheme.analysis,
        home: MediaQuery(
          data: MediaQueryData(
            size: _phone,
            disableAnimations: true,
            accessibleNavigation: accessible,
          ),
          child: ChallengeRoute(
            shelf: shelf,
            ledger: ledger,
            now: () => _today,
            shareSheet: (shared ?? _Shared()).sheet,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

/// Today's puzzle as the screen makes it, from what [held] holds.
DailyPuzzle _puzzle([
  Map<String, ProteinMaterials> held = const <String, ProteinMaterials>{},
]) => PuzzleGenerator.generate(day: _day, catalog: TestCatalog.all, held: held);

Future<void> _tapKey(WidgetTester tester, String key) async {
  final Finder found = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(found);
  await tester.pump();
  await tester.tap(found);
  await tester.pump();
}

/// Answers the round on screen rightly.
Future<void> _answerRightly(WidgetTester tester, ChallengeRound round) async {
  switch (round) {
    case FoldRound():
      await _tapKey(tester, 'challenge-option-${round.answer}');
    case IdentifyRound():
      await _tapKey(tester, 'challenge-option-${round.answer}');
    case MutationRound():
      await _tapKey(tester, 'challenge-residue-${round.at}');
    case WalkOrderRound():
      for (int page = 0; page < round.pages.length; page++) {
        await _tapKey(tester, 'challenge-page-$page');
      }
    case CodonRound():
      await _tapKey(tester, 'challenge-codons-start');
      for (final CodonQuestion question in round.questions) {
        await _tapKey(tester, 'challenge-codon-option-${question.answer}');
      }
  }
}

Map<String, ProteinMaterials>
_holdingEverything() => <String, ProteinMaterials>{
  for (final ProteinTarget t in TestCatalog.all)
    t.slug: ProteinMaterials(
      fold: true,
      sequence: recordOf(t).protein!.translation,
      reported: <ReportedChange>[
        // One reported change at the fifth residue, to whatever is not there.
        ReportedChange(
          residue: 5,
          from: recordOf(t).protein!.translation[4],
          to: recordOf(t).protein!.translation[4] == 'A' ? 'G' : 'A',
          classification: 'Likely benign',
        ),
      ],
    ),
};

void main() {
  testWidgets('holding nothing: four rounds played, then how the day went', (
    WidgetTester tester,
  ) async {
    final _Shelf shelf = _Shelf();
    final _Ledger ledger = _Ledger();
    await _host(tester, shelf: shelf, ledger: ledger);
    final DailyPuzzle puzzle = _puzzle();

    for (int i = 0; i < puzzle.rounds.length; i++) {
      expect(find.text(puzzle.rounds[i].prompt), findsOneWidget, reason: '$i');
      await _answerRightly(tester, puzzle.rounds[i]);
      expect(find.text('Right.'), findsOneWidget, reason: '$i');
      await _tapKey(tester, 'challenge-next');
      await tester.pump();
    }

    expect(
      find.byKey(const ValueKey<String>('challenge-summary')),
      findsOneWidget,
    );
    expect(find.text('$_day: 4 of 4'), findsOneWidget);
    expect(find.text('A streak of one day.'), findsOneWidget);
    expect(ledger.days[_day]!.rounds, <bool>[true, true, true, true]);
    expect(ledger.days[_day]!.codons, List<bool>.filled(8, true));
  });

  testWidgets('it asks the shelf only about the proteins the day needs, and '
      'reads no track', (WidgetTester tester) async {
    final _Shelf shelf = _Shelf();
    await _host(tester, shelf: shelf, ledger: _Ledger());
    final DailyPuzzle puzzle = _puzzle();
    expect(shelf.asked, <String>[
      (puzzle.rounds[0] as IdentifyRound).subject.slug,
      (puzzle.rounds[1] as IdentifyRound).subject.slug,
    ]);
    // _NoNetwork throws on any read, and no exception surfaced.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a held fold is drawn by the walk’s own StructureView', (
    WidgetTester tester,
  ) async {
    final String subject = (_puzzle().rounds[0] as IdentifyRound).subject.slug;
    await _host(
      tester,
      shelf: _Shelf(<String, ProteinMaterials>{
        subject: const ProteinMaterials(fold: true),
      }),
      ledger: _Ledger(),
      tracks: _Folds(),
    );
    expect(find.text('Whose fold is this?'), findsOneWidget);
    expect(find.byType(StructureView), findsOneWidget);
    expect(
      tester.widget<StructureView>(find.byType(StructureView)).target.slug,
      subject,
    );
  });

  testWidgets('a residue is spotted in the walk’s colours, and a reported '
      'change is quoted in ClinVar’s words', (WidgetTester tester) async {
    final Map<String, ProteinMaterials> held = _holdingEverything();
    await _host(tester, shelf: _Shelf(held), ledger: _Ledger());
    final DailyPuzzle puzzle = _puzzle(held);
    await _answerRightly(tester, puzzle.rounds[0]);
    await _tapKey(tester, 'challenge-next');
    final MutationRound round = puzzle.rounds[1] as MutationRound;
    expect(find.text(round.prompt), findsOneWidget);

    final BuildContext context = tester.element(
      find.byKey(const ValueKey<String>('challenge-residue-0')),
    );
    final Container tile = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('challenge-residue-0')),
        matching: find.byType(Container),
      ),
    );
    expect(
      (tile.decoration! as BoxDecoration).color,
      context.anatomyColors.forResidue(round.changed[0]),
    );

    await _tapKey(tester, 'challenge-residue-${round.at}');
    expect(find.text('Right.'), findsOneWidget);
    expect(find.text(round.reveal), findsOneWidget);
    final Finder reported = find.byKey(
      const ValueKey<String>('challenge-reported'),
    );
    expect(tester.widget<Text>(reported).data, 'Likely benign');
    expect(
      find.ancestor(of: reported, matching: find.byType(ClinVarSourced)),
      findsOneWidget,
    );
  });

  testWidgets('the clock runs out on the codons not answered', (
    WidgetTester tester,
  ) async {
    final _Ledger ledger = _Ledger();
    await _host(tester, shelf: _Shelf(), ledger: ledger);
    final DailyPuzzle puzzle = _puzzle();
    for (int i = 0; i < 3; i++) {
      await _answerRightly(tester, puzzle.rounds[i]);
      await _tapKey(tester, 'challenge-next');
    }
    await _tapKey(tester, 'challenge-codons-start');
    final CodonRound codons = puzzle.rounds[3] as CodonRound;
    await _tapKey(
      tester,
      'challenge-codon-option-${codons.questions.first.answer}',
    );
    await tester.pump(const Duration(seconds: 46));
    expect(find.text('1 of 8 codons.'), findsOneWidget);
    expect(find.text('Not this time.'), findsOneWidget);
  });

  testWidgets('with a screen reader on, the clock gives twice the time', (
    WidgetTester tester,
  ) async {
    await _host(tester, shelf: _Shelf(), ledger: _Ledger(), accessible: true);
    final DailyPuzzle puzzle = _puzzle();
    for (int i = 0; i < 3; i++) {
      await _answerRightly(tester, puzzle.rounds[i]);
      await _tapKey(tester, 'challenge-next');
    }
    await _tapKey(tester, 'challenge-codons-start');
    expect(find.text('90 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 50));
    expect(
      find.byKey(const ValueKey<String>('challenge-codon')),
      findsOneWidget,
    );
    expect(find.text('40 s'), findsOneWidget);
    // Finish the round, so no clock outlives the test.
    for (final CodonQuestion question
        in (puzzle.rounds[3] as CodonRound).questions) {
      await _tapKey(tester, 'challenge-codon-option-${question.answer}');
    }
  });

  testWidgets('a second tap on the last round counts no fifth', (
    WidgetTester tester,
  ) async {
    final _SlowLedger ledger = _SlowLedger();
    await _host(tester, shelf: _Shelf(), ledger: ledger);
    final DailyPuzzle puzzle = _puzzle();
    for (int i = 0; i < puzzle.rounds.length; i++) {
      await _answerRightly(tester, puzzle.rounds[i]);
      if (i + 1 < puzzle.rounds.length) {
        await _tapKey(tester, 'challenge-next');
      }
    }
    final Finder next = find.byKey(const ValueKey<String>('challenge-next'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump();
    await tester.tap(next, warnIfMissed: false);
    await tester.pump();
    ledger.release.complete();
    await tester.pump();
    await tester.pump();
    expect(ledger.writes, hasLength(1));
    expect(ledger.writes.single.rounds, hasLength(4));
  });

  testWidgets('a day is played once: it opens on its result', (
    WidgetTester tester,
  ) async {
    final _Ledger ledger = _Ledger()
      ..days[_day] = DayResult(
        day: _day,
        rounds: const <bool>[true, false, true, true],
        codons: List<bool>.filled(8, true),
      );
    await _host(tester, shelf: _Shelf(), ledger: ledger);
    expect(
      find.byKey(const ValueKey<String>('challenge-summary')),
      findsOneWidget,
    );
    expect(find.text('$_day: 3 of 4'), findsOneWidget);
    expect(find.text(_puzzle().rounds[0].prompt), findsNothing);
  });

  testWidgets('sharing hands over a card, a square a round and a square a '
      'codon, and the link', (WidgetTester tester) async {
    final _Shared shared = _Shared();
    final _Ledger ledger = _Ledger()
      ..days[_day] = DayResult(
        day: _day,
        rounds: const <bool>[true, false, true, true],
        codons: const <bool>[true, true, false, true, true, true, false, true],
      );
    await _host(tester, shelf: _Shelf(), ledger: ledger, shared: shared);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey<String>('challenge-share')));
      for (int i = 0; i < 100 && shared.text == null; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(
      shared.text,
      'Helix Peek daily $_day: 3/4\n'
      '🟩⬛🟩🟩\n'
      '🟩🟩⬛🟩🟩🟩⬛🟩\n'
      'helixpeek://open/lab/challenges',
    );
    expect(shared.fileName, 'helix-peek-$_day.png');
    expect(shared.png!.sublist(1, 4), 'PNG'.codeUnits);
  });

  testWidgets('every control is a labelled target a screen reader reaches', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _host(tester, shelf: _Shelf(), ledger: _Ledger());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    final DailyPuzzle puzzle = _puzzle();
    for (int i = 0; i < 2; i++) {
      await _answerRightly(tester, puzzle.rounds[i]);
      await _tapKey(tester, 'challenge-next');
    }
    // The walk's pages, then the codon round's answers.
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await _answerRightly(tester, puzzle.rounds[2]);
    await _tapKey(tester, 'challenge-next');
    await _tapKey(tester, 'challenge-codons-start');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    for (final CodonQuestion question
        in (puzzle.rounds[3] as CodonRound).questions) {
      await _tapKey(tester, 'challenge-codon-option-${question.answer}');
    }
    semantics.dispose();
  });

  group('the ledger', () {
    test('keeps days in the lab’s own folder, and reads them back', () async {
      final Directory root = Directory.systemTemp.createTempSync(
        'helixpeek-days',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final FileLedger ledger = FileLedger(directory: root);
      expect(await ledger.read(), isEmpty);
      await ledger.write(
        const DayResult(
          day: '2026-09-28',
          rounds: <bool>[true],
          codons: <bool>[false],
        ),
      );
      await ledger.write(
        const DayResult(
          day: '2026-09-29',
          rounds: <bool>[false],
          codons: <bool>[true],
        ),
      );
      expect(
        File('${root.path}/${FileLedger.folder}/days.json').existsSync(),
        isTrue,
      );
      expect(FileLedger.folder, startsWith('lab/'));
      final Map<String, DayResult> days = await FileLedger(directory: root)
          .read();
      expect(days.keys, <String>['2026-09-28', '2026-09-29']);
      expect(days['2026-09-29']!.rounds, <bool>[false]);
    });

    test('a streak is days in a row, and waits for today until it passes', () {
      Map<String, DayResult> played(List<String> days) => <String, DayResult>{
        for (final String day in days)
          day: DayResult(
            day: day,
            rounds: const <bool>[],
            codons: const <bool>[],
          ),
      };
      final DateTime today = DateTime(2026, 3, 1, 9);
      expect(streakOf(played(<String>[]), today), 0);
      expect(streakOf(played(<String>['2026-03-01']), today), 1);
      // Across a month's end.
      expect(
        streakOf(
          played(<String>['2026-02-27', '2026-02-28', '2026-03-01']),
          today,
        ),
        3,
      );
      // Today not played yet: yesterday's run still stands.
      expect(streakOf(played(<String>['2026-02-27', '2026-02-28']), today), 2);
      // A whole day missed ends it.
      expect(
        streakOf(
          played(<String>['2026-02-26', '2026-02-28', '2026-03-01']),
          today,
        ),
        2,
      );
      expect(streakOf(played(<String>['2026-02-26', '2026-02-27']), today), 0);
    });
  });

  group('the card', () {
    test('the link opens the day’s challenge on the app’s own scheme', () {
      expect(challengeLink().toString(), 'helixpeek://open/lab/challenges');
    });
  });
}

/// Serves the walk's own fixtures, for a fold the puzzle holds.
final class _Folds implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) =>
      File(TestCatalog.bySlug(slug)!.asset(kind)!).readAsBytes();
}
