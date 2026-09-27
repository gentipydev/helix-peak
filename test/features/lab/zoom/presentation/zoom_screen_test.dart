import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_captions.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_scale.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_screen.dart';

import '../../../../support/catalog_api.dart';
import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';
import '../zoom_fixtures.dart';

const Size _phone = Size(390, 844);

Widget _screen(ProteinTarget target, {bool reduced = true}) => MediaQuery(
  data: MediaQueryData(size: _phone, disableAnimations: reduced),
  // Keyed by its protein, as the route keys it.
  child: ZoomScreen(
    key: ValueKey<String>(target.slug),
    target: target,
    track: locusOf(target),
    bases: recordOf(target).sequence,
  ),
);

Future<void> _host(
  WidgetTester tester,
  ProteinTarget target, {
  bool reduced = true,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: _screen(target, reduced: reduced),
    ),
  );
  await tester.pump();
}

Future<void> _pick(WidgetTester tester, ZoomLevel level) async {
  final Finder chip = find.byKey(ValueKey<String>('zoom-level-${level.name}'));
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
  await tester.pump();
  await tester.pump();
}

String _caption(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey<String>('zoom-caption')))
    .data!;

bool _within(Rect inner, Rect outer) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

/// Two fingers on the canvas, [spread] times further apart when they lift,
/// moving apart in small even steps as fingers do. The recognizer counts
/// the spread from where it takes the gesture on, a step or two in.
Future<void> _pinch(WidgetTester tester, double spread) async {
  final Offset centre = tester.getCenter(
    find.byKey(const ValueKey<String>('zoom-canvas')),
  );
  const Offset half = Offset(40, 0);
  final TestGesture a = await tester.startGesture(centre - half, pointer: 7);
  final TestGesture b = await tester.startGesture(centre + half, pointer: 8);
  await tester.pump();
  const int steps = 30;
  for (int step = 1; step <= steps; step++) {
    final double s = math.pow(spread, step / steps).toDouble();
    await a.moveTo(centre - half * s);
    await b.moveTo(centre + half * s);
    await tester.pump();
  }
  await a.up();
  await b.up();
  // Past the double tap's wait for a second tap.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(File(path).readAsBytesSync().buffer),
      ),
    );
  }
  await loader.load();
}

void main() {
  // The captions' own face, so that a caption measures here as it does on a
  // phone: the test font's glyphs are each a full em wide.
  setUpAll(
    () => _loadFont(AppTypography.sansFamily, <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ]),
  );

  testWidgets('one screen serves all twenty: a caption for every level, each '
      'whole in its box on a phone', (WidgetTester tester) async {
    for (final ProteinTarget target in TestCatalog.all) {
      await _host(tester, target);
      final ZoomCaptions captions = ZoomCaptions(locusOf(target));
      expect(find.text(ZoomScreen.titleOf(target)), findsOneWidget);
      for (final ZoomLevel level in ZoomLevel.values) {
        await _pick(tester, level);
        expect(_caption(tester), captions.captionOf(level), reason: '$level');
        expect(
          _within(
            tester.getRect(find.byKey(const ValueKey<String>('zoom-caption'))),
            tester.getRect(
              find.byKey(const ValueKey<String>('zoom-caption-box')),
            ),
          ),
          isTrue,
          reason: '${target.slug} $level: the caption is cut short',
        );
      }
    }
  });

  testWidgets('hemoglobin lands in a marrow precursor, and the caption says '
      'so where it can be read', (WidgetTester tester) async {
    await _host(tester, TestCatalog.hemoglobin);
    await _pick(tester, ZoomLevel.cell);
    final String cell = _caption(tester);
    expect(cell, contains('mature red blood cells have no nucleus'));
    expect(cell, contains('erythroblasts of the bone marrow'));
    final Finder caption = find.byKey(const ValueKey<String>('zoom-caption'));
    expect(caption.hitTestable(), findsOneWidget);
    expect(_within(tester.getRect(caption), Offset.zero & _phone), isTrue);
  });

  testWidgets('the chromosome caption never has the gene seen', (
    WidgetTester tester,
  ) async {
    for (final ProteinTarget target in TestCatalog.all) {
      await _host(tester, target);
      await _pick(tester, ZoomLevel.chromosome);
      expect(
        _caption(tester),
        contains('too small to see at this scale'),
        reason: target.slug,
      );
    }
  });

  testWidgets('offers the walk at the gene alone, and opens it at the gene', (
    WidgetTester tester,
  ) async {
    final ProteinTarget target = TestCatalog.hemoglobin;
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => _screen(target)),
        GoRoute(
          path: '${RoutePaths.gene}/:slug',
          builder: (_, GoRouterState state) =>
              Text('the walk of ${state.pathParameters['slug']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.analysis, routerConfig: router),
    );
    await tester.pump();
    final Finder walk = find.byKey(const ValueKey<String>('zoom-walk'));
    for (final ZoomLevel level in ZoomLevel.values) {
      await _pick(tester, level);
      expect(
        walk,
        level == ZoomLevel.gene ? findsOneWidget : findsNothing,
        reason: '$level',
      );
    }
    await tester.tap(walk);
    await tester.pumpAndSettle();
    expect(find.text('the walk of ${target.slug}'), findsOneWidget);
    expect(RoutePaths.geneFor(target), '/gene/${target.slug}');
  });

  testWidgets('names its sources, the cytoBand table and the Atlas under its '
      'licence', (WidgetTester tester) async {
    await _host(tester, TestCatalog.insulin);
    final String sources = tester
        .widget<Text>(find.byKey(const ValueKey<String>('zoom-sources')))
        .data!;
    expect(sources, ZoomCaptions(locusOf(TestCatalog.insulin)).sources);
    expect(sources, contains('cytoBand'));
    expect(sources, contains('CC BY 4.0'));
  });

  testWidgets('a pinch runs through the levels and lets go at the nearest', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.hemoglobin);
    final LocusTrack track = locusOf(TestCatalog.hemoglobin);
    final ZoomCaptions captions = ZoomCaptions(track);
    expect(_caption(tester), captions.captionOf(ZoomLevel.body));
    // A body 2.2 m across, spread sixfold: 37 cm, nearest the organ.
    await _pinch(tester, 6);
    expect(_caption(tester), captions.captionOf(ZoomLevel.organ));
    // The organ's 30 cm, spread 250-fold: 1.2 mm, nearer the tissue's half
    // millimetre than anything else.
    await _pinch(tester, 250);
    expect(_caption(tester), captions.captionOf(ZoomLevel.tissue));
    // Pinched back in, fingers closing a hundredfold: back to the organ.
    await _pinch(tester, 0.01);
    expect(_caption(tester), captions.captionOf(ZoomLevel.organ));
  });

  testWidgets('a double tap goes a level deeper, and the chip row follows it '
      'to the gene', (WidgetTester tester) async {
    await _host(tester, TestCatalog.insulin);
    final ZoomCaptions captions = ZoomCaptions(locusOf(TestCatalog.insulin));
    final Finder canvas = find.byKey(const ValueKey<String>('zoom-canvas'));
    for (final ZoomLevel level in ZoomLevel.values.skip(1)) {
      await tester.tap(canvas);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(canvas);
      await tester.pumpAndSettle();
      expect(_caption(tester), captions.captionOf(level));
    }
    final ChoiceChip gene = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey<String>('zoom-level-gene')),
    );
    expect(gene.selected, isTrue);
    expect(
      _within(
        tester.getRect(find.byKey(const ValueKey<String>('zoom-level-gene'))),
        Offset.zero & _phone,
      ),
      isTrue,
      reason: 'the selected chip was left off screen',
    );
  });

  testWidgets('a chip animates the zoom there, or jumps under reduced motion', (
    WidgetTester tester,
  ) async {
    final ZoomCaptions captions = ZoomCaptions(locusOf(TestCatalog.insulin));
    await _host(tester, TestCatalog.insulin, reduced: false);
    await _pick(tester, ZoomLevel.gene);
    expect(_caption(tester), isNot(captions.captionOf(ZoomLevel.gene)));
    await tester.pumpAndSettle();
    expect(_caption(tester), captions.captionOf(ZoomLevel.gene));

    await _host(tester, TestCatalog.insulin);
    await _pick(tester, ZoomLevel.gene);
    expect(_caption(tester), captions.captionOf(ZoomLevel.gene));
  });

  group('the cubit', () {
    FetchGene fetch(TrackSource tracks) =>
        FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks)));

    test(
      'reads the locus track and the record where the row says ready',
      () async {
        final TrackSource tracks = ZoomTrackSource();
        final ZoomCubit cubit = ZoomCubit(
          withLocus(TestCatalog.hemoglobin, TrackState.ready),
          tracks,
          fetch(tracks),
        );
        addTearDown(cubit.close);
        await cubit.load();
        final ZoomState state = cubit.state;
        expect(state, isA<ZoomReady>());
        final ZoomReady ready = state as ZoomReady;
        expect(ready.track.locus, locusOf(TestCatalog.hemoglobin).locus);
        expect(
          ready.record.sequence,
          recordOf(TestCatalog.hemoglobin).sequence,
        );
      },
    );

    test(
      'draws the row’s state, not a failure, where it is not ready',
      () async {
        final TrackSource tracks = ZoomTrackSource();
        for (final TrackState state in <TrackState>[
          TrackState.absent,
          TrackState.pending,
          TrackState.refused,
        ]) {
          final ZoomCubit cubit = ZoomCubit(
            withLocus(TestCatalog.insulin, state, reason: 'no band'),
            tracks,
            fetch(tracks),
          );
          await cubit.load();
          expect(cubit.state, isA<ZoomUnavailable>());
          expect((cubit.state as ZoomUnavailable).state, state);
          await cubit.close();
        }
        expect(
          ZoomScreen.unavailable(TrackState.absent, null),
          'Where its gene lies is not published yet.',
        );
        expect(
          ZoomScreen.unavailable(TrackState.pending, null),
          'Where its gene lies is on its way.',
        );
        expect(
          ZoomScreen.unavailable(TrackState.refused, 'no band'),
          'Where its gene lies is not published: no band.',
        );
      },
    );
  });

  testWidgets('the route says so where the catalog has no locus for it yet', (
    WidgetTester tester,
  ) async {
    final TrackSource tracks = ZoomTrackSource();
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
          home: ZoomRoute(slug: TestCatalog.hemoglobin.slug),
        ),
      ),
    );
    final Finder unavailable = find.byKey(
      const ValueKey<String>('zoom-unavailable'),
    );
    await tester.runAsync(() async {
      for (int i = 0; i < 100 && unavailable.evaluate().isEmpty; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(
      tester.widget<Text>(unavailable).data,
      ZoomScreen.unavailable(TrackState.absent, null),
    );
  });
}
