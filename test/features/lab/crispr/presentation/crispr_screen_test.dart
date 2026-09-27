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
import 'package:helixpeek/features/lab/crispr/presentation/crispr_screen.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_cubit.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_screen.dart';
import 'package:helixpeek/features/lab/presentation/lab_anatomy_view.dart';
import 'package:helixpeek/shared/anatomy/anatomy_scene.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../../support/fixture_track_source.dart';
import '../../../../support/test_catalog.dart';

const ValueKey<String> _canvas = ValueKey<String>('crispr-canvas');
const ValueKey<String> _lead = ValueKey<String>('crispr-lead');

/// Tall enough that a region's bases all fit, so a cell can be tapped where
/// the layout puts it.
const Size _surface = Size(390, 1800);

/// The sense guide TACCTAGTGTGCGGGGAACG, PAM AGG, cutting before 5358.
const int _cut = 5358;

Future<ProteinTarget> _host(WidgetTester tester, String slug) async {
  final ProteinTarget target = TestCatalog.bySlug(slug)!;
  final TrackSource tracks = FixtureTrackSource();
  final FetchGene fetchGene = FetchGene(
    GeneRepositoryImpl(TrackGeneDataSource(tracks)),
  );
  // The record is read from disk: real async.
  final GeneRecord record = (await tester.runAsync(
    () => fetchGene(target.query),
  ))!;
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
        home: CrisprScreen(target: target, record: record),
      ),
    ),
  );
  await tester.pump();
  return target;
}

AnatomyScene _scene(WidgetTester tester) =>
    tester.widget<LabAnatomyView>(find.byKey(_canvas)).scene;

List<int> _breaks(WidgetTester tester) =>
    tester.widget<LabAnatomyView>(find.byKey(_canvas)).breaks;

String _leadText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_lead)).data!;

Future<void> _tapPosition(WidgetTester tester, int position) async {
  final AnatomyScene scene = _scene(tester);
  final AnatomyStage stage = scene.isTransition ? scene.to : scene.from;
  final int cell = stage.cellAt(position);
  expect(cell, greaterThanOrEqualTo(0), reason: 'base $position is drawn');
  final Offset centre = (scene.isTransition ? scene.toLayout : scene.fromLayout)
      .centreOf(cell);
  await tester.tapAt(tester.getTopLeft(find.byKey(_canvas)) + centre);
  await tester.pump();
}

/// Opens the region holding [position], then the cut before that base.
Future<void> _openCut(WidgetTester tester, int position) async {
  await _tapPosition(tester, position);
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
  expect(_scene(tester).from.kind, StageKind.dna);
  await _tapPosition(tester, position);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Brings a widget inside the sheet on screen: its content is longer than
/// the sheet is tall.
Future<void> _bringUp(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey<String>('crispr-sheet-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

void main() {
  testWidgets('the gene opens on its regions, with nothing cut yet', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin');
    expect(_scene(tester).from.kind, StageKind.gene);
    expect(
      _leadText(tester),
      'Tap a region of the gene to open its bases and see where a nuclease '
      'can cut it.',
    );
    expect(
      _breaks(tester),
      isEmpty,
      reason: 'the whole gene is two points a cell; a cut is drawn in a region',
    );
  });

  testWidgets('the screen says off-targets are not searched, from the start', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin');
    expect(
      find.byKey(const ValueKey<String>('crispr-off-target')),
      findsOneWidget,
    );
    expect(find.textContaining('Off-targets are not searched'), findsWidgets);
  });

  testWidgets('a region shows every cut in it, between the bases it falls '
      'between', (WidgetTester tester) async {
    await _host(tester, 'insulin');
    await _tapPosition(tester, _cut);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    final AnatomyStage region = _scene(tester).from;
    expect(region.kind, StageKind.dna);
    final List<int> breaks = _breaks(tester);
    expect(breaks, isNotEmpty);
    expect(breaks, contains(region.cellAt(_cut)));
    expect(breaks.toSet(), hasLength(breaks.length), reason: 'no duplicates');
    expect(_leadText(tester), matches(RegExp(r'^\w+ guides cut inside ')));
    expect(_leadText(tester), endsWith('Tap a cut to see it.'));
  });

  testWidgets('a cut opens the guide that makes it, and what its bases '
      'measure', (WidgetTester tester) async {
    await _host(tester, 'insulin');
    await _openCut(tester, _cut);

    expect(find.byKey(const ValueKey<String>('crispr-cut')), findsOneWidget);
    expect(find.text('A cut before base 5,358'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('crispr-guide-sense-5341')),
      findsOneWidget,
    );
    expect(find.textContaining('TACCTAGTGTGCGGGGAACG'), findsOneWidget);
    expect(find.textContaining('GC 60%'), findsOneWidget);
    expect(find.textContaining('no run of four T'), findsOneWidget);
    // Never a word about how well it will work, or whether it is safe.
    expect(find.textContaining(RegExp('safe|specific|efficien')), findsNothing);
  });

  testWidgets('one guide at a cut is chosen already, and offers the three '
      'paths', (WidgetTester tester) async {
    await _host(tester, 'insulin');
    await _openCut(tester, _cut);

    expect(find.text('End joining'), findsOneWidget);
    expect(find.text('Homology-directed repair'), findsOneWidget);
    expect(find.text('Base editing'), findsOneWidget);
    expect(
      find.textContaining('a spread over many outcomes, not one'),
      findsOneWidget,
    );
    expect(
      find.textContaining('A to T is not one of them on either strand'),
      findsOneWidget,
    );
  });

  testWidgets('end joining offers several outcomes at the cut', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin');
    await _openCut(tester, _cut);
    expect(
      find.byKey(const ValueKey<String>('crispr-nhej-gain-1')),
      findsOneWidget,
    );
    expect(find.text('A gained at the cut'), findsOneWidget);
    expect(find.text('one base lost at the cut'), findsOneWidget);
    expect(find.text('three bases lost'), findsOneWidget);
  });

  testWidgets('a base editor offers only what sits in its window', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin');
    await _openCut(tester, _cut);
    // Bases four to eight of TACCTAGTGTGCGGGGAACG read C, T, A, G, T: one A
    // for the adenine editor, at base 5,346, and one C for the other two.
    expect(
      find.byKey(const ValueKey<String>('crispr-base-ABE-6')),
      findsOneWidget,
    );
    expect(find.text('Base 5,346: A to G'), findsOneWidget);
    expect(find.text('Base 5,344: C to T'), findsOneWidget);
    expect(find.text('Base 5,344: C to G'), findsOneWidget);
    expect(find.text('adenine base editor (ABE) · A to G'), findsOneWidget);
  });

  testWidgets('homology-directed repair writes the base the reader picks', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin');
    await _openCut(tester, _cut);
    final Finder chip = find.byKey(
      const ValueKey<String>('crispr-hdr-at-$_cut'),
    );
    expect(chip, findsOneWidget);
    // Ten bases either side of the cut, and no further.
    expect(
      find.byKey(const ValueKey<String>('crispr-hdr-at-${_cut + 10}')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('crispr-hdr-at-${_cut + 11}')),
      findsNothing,
    );

    await _bringUp(tester, chip);
    await tester.tap(chip);
    await tester.pump();
    expect(find.text('Base 5,358 reads A. Write'), findsOneWidget);
    // The base it already is, is not on offer.
    expect(find.byKey(const ValueKey<String>('crispr-hdr-A')), findsNothing);
    expect(find.byKey(const ValueKey<String>('crispr-hdr-G')), findsOneWidget);
  });

  testWidgets('a base with nothing cutting before it says so', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin');
    // 5,357 is inside the same guide's twenty bases, but no guide cuts there.
    await _openCut(tester, 5357);
    expect(
      find.byKey(const ValueKey<String>('crispr-no-guide')),
      findsOneWidget,
    );
    expect(find.text('End joining'), findsNothing);
  });

  testWidgets('the repair chosen is rendered through the mutate screen', (
    WidgetTester tester,
  ) async {
    final ProteinTarget target = await _host(tester, 'insulin');
    await _openCut(tester, _cut);
    // The pushed screen reads the record from disk again, through the lab's
    // own cache: real async, so the whole handoff runs unfaked.
    late final MutateCubit cubit;
    await tester.runAsync(() async {
      await tester.tap(
        find.byKey(const ValueKey<String>('crispr-nhej-lose-1-at-$_cut')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MutateScreen), findsOneWidget);
      expect(find.text('Mutate · ${target.display}'), findsOneWidget);
      cubit = BlocProvider.of<MutateCubit>(
        tester.element(find.byType(MutateScreen)),
      );
      for (int i = 0; i < 200; i++) {
        if (cubit.state case final MutateReady ready
            when ready.clinvar != ClinVarLoad.loading) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    final MutateReady ready = cubit.state as MutateReady;
    expect(ready.applied, isNotNull, reason: 'the repair arrived applied');
    expect(ready.applied!.edit.position, _cut);
    // And the screen opens on what it did, not on the gene it did it to.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('mutate-lead')))
          .data,
      contains('reading frame shifts'),
    );
    await tester.pump(const Duration(seconds: 3));
  });
}
