import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/presentation/lab_anatomy_view.dart';
import 'package:helixpeek/features/lab/sickle/domain/sickle_story.dart';
import 'package:helixpeek/features/lab/sickle/presentation/sickle_screen.dart';
import 'package:helixpeek/shared/clinvar/evidence_row.dart';

import '../../../../support/fixture_track_source.dart';
import '../../../../support/test_catalog.dart';

const Size _surface = Size(390, 1400);

/// The two ClinVar variation IDs at the codon, from the stored snapshot.
const String _sickleRecord = '15333';
const String _makassarRecord = '15175';

late GeneRecord _record;
late ProteinTarget _target;

Future<void> _host(WidgetTester tester) async {
  _target = TestCatalog.all.firstWhere(
    (ProteinTarget t) => t.gene == sickleGene,
  );
  final TrackSource tracks = FixtureTrackSource();
  final FetchGene fetchGene = FetchGene(
    GeneRepositoryImpl(TrackGeneDataSource(tracks)),
  );
  _record = (await tester.runAsync(() => fetchGene(_target.query)))!;
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<TrackSource>.value(value: tracks),
        RepositoryProvider<FetchGene>.value(value: fetchGene),
      ],
      child: MaterialApp(
        theme: AppTheme.analysis,
        home: SickleScreen(target: _target, record: _record),
      ),
    ),
  );
  await tester.pump();
  // ClinVar is read from disk and parsed on another isolate: real async.
  await tester.runAsync(() async {
    for (int i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
      if (find.byType(EvidenceRow).evaluate().isNotEmpty ||
          find.textContaining('ClinVar has no record').evaluate().isNotEmpty) {
        break;
      }
      if (i > 5 && find.text('Reading ClinVar…').evaluate().isEmpty) {
        break;
      }
    }
  });
  await tester.pump();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('sickle-next')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  // Chapter one shows nothing of ClinVar, so [_host] cannot see whether the
  // snapshot has arrived and may stop waiting before it does. The chapters
  // after it say "Reading ClinVar…" until it has: wait that out, in real time.
  await tester.runAsync(() async {
    for (int i = 0; i < 200; i++) {
      if (find.text('Reading ClinVar…').evaluate().isEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });
  await tester.pump();
}

/// The chapter's own scroll view: the first in the tree, above whatever the
/// chapter's own widgets scroll.
Finder get _chapterScroll => find.byType(Scrollable).first;

/// Brings a widget the chapter has not built yet into the tree.
Future<bool> _scrolled(WidgetTester tester, double by) async {
  final ScrollableState list = tester.state<ScrollableState>(_chapterScroll);
  final double from = list.position.pixels;
  list.position.jumpTo((from + by).clamp(0, list.position.maxScrollExtent));
  await tester.pump();
  return list.position.pixels != from;
}

Future<void> _bringUp(WidgetTester tester, Finder target) async {
  while (target.evaluate().isEmpty) {
    if (!await _scrolled(tester, 240)) {
      break;
    }
  }
  final Finder chapter = find.byKey(const ValueKey<String>('sickle-chapter'));
  expect(
    target,
    findsWidgets,
    reason: 'scrolled looking for it, in ${tester.widget<Text>(chapter).data}',
  );
  await tester.pump();
}

/// Every word the screen writes in its own voice, chapter by chapter.
List<String> _ownWords(WidgetTester tester) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.byWidgetPredicate(
      (Widget w) => w is Text && w.data != null,
      skipOffstage: false,
    ),
  ))
    text.data!,
];

/// Every line of the chapter, read by scrolling the whole of it past.
Future<Set<String>> _wholeChapter(WidgetTester tester) async {
  final Set<String> lines = <String>{..._ownWords(tester)};
  while (await _scrolled(tester, 240)) {
    lines.addAll(_ownWords(tester));
  }
  return lines;
}

void main() {
  testWidgets('chapter one is about a gene this page does not draw', (
    WidgetTester tester,
  ) async {
    await _host(tester);
    expect(find.text('Chapter one of three'), findsOneWidget);
    expect(
      find.text('The approved therapy does not edit this gene'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('sickle-not-this-gene')),
      findsOneWidget,
    );
    expect(
      find.byType(LabAnatomyView),
      findsNothing,
      reason: 'the gene is not drawn in a chapter that is not about it',
    );
    expect(find.textContaining('BCL11A'), findsWidgets);
    expect(find.textContaining('GATA1 binding site'), findsWidgets);
    expect(
      find.textContaining('Nothing on this page is drawn on BCL11A'),
      findsOneWidget,
    );
    // Back is where the story starts, so there is nowhere back to.
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey<String>('sickle-back')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('every chapter carries the sources its claims rest on', (
    WidgetTester tester,
  ) async {
    await _host(tester);
    expect(find.byKey(const ValueKey<String>('sickle-sources-0')), findsOne);
    expect(
      find.byKey(const ValueKey<String>('source-link-Canver et al., 2015')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('source-link-Frangoul et al., 2021')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('source-link-FDA, December 2023')),
      findsOneWidget,
    );

    await _next(tester);
    await _bringUp(
      tester,
      find.byKey(const ValueKey<String>('sickle-sources-1')),
    );
    expect(find.byKey(const ValueKey<String>('sickle-sources-1')), findsOne);
    expect(
      find.byKey(const ValueKey<String>('source-link-Gaudelli et al., 2017')),
      findsOneWidget,
    );

    await _next(tester);
    await _bringUp(
      tester,
      find.byKey(const ValueKey<String>('sickle-sources-2')),
    );
    expect(find.byKey(const ValueKey<String>('sickle-sources-2')), findsOne);
    expect(
      find.byKey(const ValueKey<String>('source-link-Newby et al., 2021')),
      findsOneWidget,
    );
  });

  testWidgets('chapter two reads the change off the record, and says no '
      'editor writes it back', (WidgetTester tester) async {
    await _host(tester);
    await _next(tester);

    expect(find.text('Why no editor puts the change back'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sickle-codon')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('sickle-outcome')))
          .data,
      'Codon 7 now reads valine where it read glutamate: one residue of '
      '${_record.protein!.translation.length} changes.',
    );
    // The six changes the editors do write, and not the one this needs.
    await _bringUp(
      tester,
      find.byKey(const ValueKey<String>('sickle-editor-changes')),
    );
    expect(find.text('A to G'), findsOneWidget);
    expect(find.text('T to C'), findsOneWidget);
    expect(find.text('T to A'), findsNothing);
    expect(find.text('A to T'), findsNothing);
    expect(
      find.textContaining('write six of the twelve changes'),
      findsOneWidget,
    );
    // And the chain itself, on the walk's own page.
    expect(find.byKey(const ValueKey<String>('sickle-ripple')), findsOneWidget);
  });

  testWidgets('chapter three writes the Makassar codon, and says what cannot '
      'carry the editor there', (WidgetTester tester) async {
    await _host(tester);
    await _next(tester);
    await _next(tester);

    expect(find.text('The Makassar workaround'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('makassar-outcome')))
          .data,
      'Codon 7 now reads alanine where it read valine: one residue of '
      '${_record.protein!.translation.length} changes.',
    );
    await _bringUp(
      tester,
      find.byKey(const ValueKey<String>('makassar-editor')),
    );
    final String editor = tester
        .widget<Text>(find.byKey(const ValueKey<String>('makassar-editor')))
        .data!;
    expect(editor, contains('other strand'));
    expect(editor, contains('adenine base editor'));

    await _bringUp(
      tester,
      find.byKey(const ValueKey<String>('makassar-reach')),
    );
    final String reach = tester
        .widget<Text>(find.byKey(const ValueKey<String>('makassar-reach')))
        .data!;
    expect(reach, contains('No guide this screen searches for'));
    expect(reach, contains('2 and 19'));
    expect(reach, contains('4 to 8'));
    expect(reach, contains('a PAM other than NGG'));

    // Nowhere further to go.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('sickle-next')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('the clinical words are ClinVar’s, quoted in its own rows', (
    WidgetTester tester,
  ) async {
    await _host(tester);
    await _next(tester);
    expect(
      find.byKey(
        const ValueKey<String>('sickle-clinvar-change-$_sickleRecord'),
      ),
      findsOneWidget,
      reason: 'the snapshot holds c.20A>T',
    );
    await _next(tester);
    await _bringUp(
      tester,
      find.byKey(
        const ValueKey<String>('makassar-clinvar-change-$_makassarRecord'),
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>('makassar-clinvar-change-$_makassarRecord'),
      ),
      findsOneWidget,
      reason: 'the snapshot holds c.20A>C, which is the Makassar change',
    );
  });

  testWidgets('no chapter says a change causes anything', (
    WidgetTester tester,
  ) async {
    await _host(tester);
    for (int chapter = 0; chapter < 3; chapter++) {
      if (chapter > 0) {
        await _next(tester);
      }
      for (final String line in await _wholeChapter(tester)) {
        expect(
          line.toLowerCase(),
          isNot(contains('cause')),
          reason: 'chapter ${chapter + 1}',
        );
        expect(
          line.toLowerCase(),
          isNot(contains('you ')),
          reason: 'chapter ${chapter + 1}: nothing here is about a person',
        );
      }
    }
  });

  testWidgets('a record without the codon is not made to tell the story', (
    WidgetTester tester,
  ) async {
    await _host(tester);
    final GeneRecord insulin = (await tester.runAsync(
      () => FetchGene(
        GeneRepositoryImpl(TrackGeneDataSource(FixtureTrackSource())),
      )(TestCatalog.insulin.query),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: SickleScreen(target: TestCatalog.insulin, record: insulin),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('sickle-untellable')),
      findsOneWidget,
    );
  });
}
