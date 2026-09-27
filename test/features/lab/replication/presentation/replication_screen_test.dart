import 'dart:ui' show ClipOp;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_cubit.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_screen.dart';
import 'package:helixpeek/features/lab/replication/domain/fidelity.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_captions.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_plan.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_timeline.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_painters.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_screen.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

import '../../../../support/catalog_api.dart';
import '../../../../support/fixture_track_source.dart';
import '../../../../support/test_catalog.dart';
import '../replication_fixtures.dart';

Future<void> _host(WidgetTester tester, ProteinTarget target) async {
  final TrackSource tracks = FixtureTrackSource();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<TrackSource>.value(value: tracks),
        RepositoryProvider<FetchGene>.value(
          value: FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks))),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.analysis,
        home: ReplicationScreen(target: target, plan: planOf(target)),
      ),
    ),
  );
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

TimelineController _controller(WidgetTester tester) =>
    tester.widget<TransportBar>(find.byType(TransportBar)).controller;

void main() {
  testWidgets('one screen serves every record that can be copied, a caption '
      'for every chapter', (WidgetTester tester) async {
    for (final ProteinTarget target in copyable) {
      await _host(tester, target);
      final ReplicationPlan plan = planOf(target);
      final ReplicationTimeline timeline = ReplicationTimeline(plan);
      final ReplicationCaptions captions = ReplicationCaptions(plan);
      expect(find.text(ReplicationScreen.titleOf(target)), findsOneWidget);
      for (final String key in <String>[
        'replication-bases',
        'replication-loop',
        'replication-record',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      }
      for (final PhaseMark mark in timeline.phases) {
        if (mark.t > 0) {
          await tester.tap(find.byTooltip('Step forward'));
          await tester.pump();
        }
        expect(
          _text(tester, 'replication-caption'),
          captions.captionOf(timeline.stateAt(mark.t), Fidelity.repair),
          reason: '${target.slug}, ${mark.name}',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('the proofreading chapter plays what the reader chose', (
    WidgetTester tester,
  ) async {
    final ProteinTarget insulin = TestCatalog.insulin;
    await _host(tester, insulin);
    final ReplicationPlan plan = planOf(insulin);
    final ReplicationCaptions captions = ReplicationCaptions(plan);
    _controller(tester).seek(
      ReplicationTimeline(plan).phases
          .firstWhere((PhaseMark m) => m.captionKey == 'proofreading')
          .t,
    );
    await tester.pump();
    expect(
      _text(tester, 'replication-caption'),
      captions.proofreading(Fidelity.repair),
    );
    await tester.tap(
      find.text(ReplicationCaptions.nameOf(Fidelity.polymerase)),
    );
    await tester.pump();
    expect(
      _text(tester, 'replication-caption'),
      captions.proofreading(Fidelity.polymerase),
    );
    expect(_text(tester, 'replication-caption'), contains('stays'));
    // The site's base follows the choice too.
    final ReplicationFrame after = ReplicationTimeline(plan).stateAt(0.7);
    expect(siteBaseAt(plan, after, Fidelity.polymerase), plan.setPieceWrong);
    expect(
      siteBaseAt(plan, after, Fidelity.proofreading),
      plan.baseAt(plan.setPieceSite),
    );
  });

  testWidgets('says how many errors got through, at each level', (
    WidgetTester tester,
  ) async {
    final ProteinTarget insulin = TestCatalog.insulin;
    await _host(tester, insulin);
    final ReplicationPlan plan = planOf(insulin);
    final ReplicationCaptions captions = ReplicationCaptions(plan);
    final ErrorTally tally = ErrorTally.of(plan);
    for (final Fidelity f in Fidelity.values) {
      await tester.tap(find.text(ReplicationCaptions.nameOf(f)));
      await tester.pump();
      expect(
        _text(tester, 'replication-tally'),
        allOf(
          contains(ReplicationCaptions.rateOf(f)),
          contains(captions.tallyOf(tally, f)),
        ),
      );
      final TextButton open = tester.widget<TextButton>(
        find.byKey(const ValueKey<String>('replication-errors')),
      );
      // With the polymerase alone the copy drawn keeps its wrong base too.
      final bool any =
          f == Fidelity.polymerase || tally.survivors(f).isNotEmpty;
      expect(open.onPressed != null, any, reason: f.name);
    }
  });

  testWidgets('an error that got through opens on the mutate screen, made', (
    WidgetTester tester,
  ) async {
    final ProteinTarget insulin = TestCatalog.insulin;
    await _host(tester, insulin);
    final ReplicationPlan plan = planOf(insulin);
    await tester.tap(
      find.text(ReplicationCaptions.nameOf(Fidelity.polymerase)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('replication-errors')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('replication-error-list')),
      findsOneWidget,
    );
    // The first is the copy drawn above, with the set piece's wrong base.
    expect(find.textContaining('The copy drawn above'), findsOneWidget);

    // The mutate screen reads the record from disk again, through the lab's
    // own cache: real async, as the CRISPR hand-off is tested.
    late final MutateCubit cubit;
    await tester.runAsync(() async {
      await tester.tap(
        find.byKey(const ValueKey<String>('replication-error-0')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MutateScreen), findsOneWidget);
      expect(find.text('Mutate · ${insulin.display}'), findsOneWidget);
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
    expect(ready.applied, isNotNull, reason: 'the error arrived as an edit');
    final Substitution edit = ready.applied!.edit as Substitution;
    expect(edit.position, plan.positionOf(plan.setPieceSite));
    expect(edit.newBase, plan.setPieceWrong);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'a record whose introns arrive shortened is refused, saying why',
    (WidgetTester tester) async {
      final TrackSource tracks = FixtureTrackSource();
      final ProteinCatalogRepository catalog = ProteinCatalogRepository(
        CatalogApi(),
        null,
      );
      addTearDown(catalog.dispose);
      await tester.runAsync(catalog.refresh);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: <RepositoryProvider<Object>>[
            RepositoryProvider<TrackSource>.value(value: tracks),
            RepositoryProvider<FetchGene>.value(
              value: FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks))),
            ),
            RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.analysis,
            home: ReplicationRoute(slug: TestCatalog.dystrophin.slug),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (int i = 0; i < 100; i++) {
          await tester.pump();
          if (find
              .byKey(const ValueKey<String>('replication-refused'))
              .evaluate()
              .isNotEmpty) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(
        _text(tester, 'replication-refused'),
        ReplicationPlan.refusal(recordOf(TestCatalog.dystrophin)),
      );
    },
  );

  group('the lagging strand is drawn with its loop, never flat', () {
    test(
      'at the scale of bases: up from the fork, down into the polymerase',
      () {
        final ReplicationPlan plan = planOf(TestCatalog.insulin);
        final ReplicationTimeline timeline = ReplicationTimeline(plan);
        final ReplicationFrame frame = timeline.stateAt(0.36);
        expect(frame.phase, ReplicationPhase.lagging);
        final (NewPiece, double)? lagging = laggingAt(plan, frame.travel);
        expect(lagging, isNotNull, reason: 'a fragment is in hand');
        final double fork = plan.rightFork(frame.travel);
        final double q = lagging!.$2;
        expect(fork - q, greaterThan(20), reason: 'the loop holds bases');
        const double pitch = 10;
        const double row = 100;
        final LaggingLoop loop = LaggingLoop(
          fork: fork,
          polymerase: q,
          rightX: 300,
          pitch: pitch,
          rowY: row,
        );
        // The polymerase is at the fork, not where its base would lie flat.
        expect(loop.polymeraseAt.dx, 300 - 3 * pitch);
        // Every base between it and the fork is lifted off the row: the loop.
        for (double b = q + 1; b < fork - 1; b += 1) {
          expect(
            loop.placeOf(b, across: 0).dy,
            lessThan(row - pitch / 2),
            reason: 'base $b lies flat',
          );
        }
        // Beyond the polymerase the template lies flat, running away from it.
        expect(loop.placeOf(q - 5, across: 0).dy, row);
        expect(
          loop.placeOf(q - 5, across: 0).dx,
          lessThan(loop.placeOf(q - 1, across: 0).dx),
        );
        // The fragment pairs on the loop's inside, a row in from its template.
        for (final double b in <double>[q, q + 3, fork - 3]) {
          final (Offset tile, _) = loop.pairedWith(b);
          expect(
            (tile - loop.placeOf(b, across: 0)).distance,
            closeTo(pitch, 1e-6),
          );
        }
      },
    );

    testWidgets('at the scale of fragments: a loop taller than the rows', (
      WidgetTester tester,
    ) async {
      final ReplicationPlan plan = planOf(TestCatalog.insulin);
      final ReplicationTimeline timeline = ReplicationTimeline(plan);
      late final ReplicationInks inks;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          home: Builder(
            builder: (BuildContext context) {
              inks = ReplicationInks.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final _PathsCanvas canvas = _PathsCanvas();
      const Size size = Size(390, 150);
      ForkLoopPainter(
        plan: plan,
        timeline: timeline,
        at: () => 0.36,
        fidelity: Fidelity.repair,
        inks: inks,
        labels: const TextStyle(fontSize: 11),
      ).paint(canvas, size);
      final double rowA = size.height * 0.8 - 10;
      expect(
        canvas.paths.where(
          (Rect r) => r.height > 40 && (r.bottom - rowA).abs() < 8,
        ),
        isNotEmpty,
        reason: 'no loop stands on the lagging row',
      );
    });
  });
}

/// Records where paths are drawn; anything else is let through.
final class _PathsCanvas implements Canvas {
  final List<Rect> paths = <Rect>[];

  @override
  void drawPath(Path path, Paint paint) => paths.add(path.getBounds());

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
