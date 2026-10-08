import 'dart:async';
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
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_facts.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_screen.dart';

import '../../../support/catalog_api.dart';
import '../../../support/test_catalog.dart';
import '../../lab/replication/replication_fixtures.dart';
import '../zoom_fixtures.dart';

const Size _phone = Size(390, 844);

Widget _screen(
  ProteinTarget target, {
  bool reduced = true,
  bool overWalk = false,
}) => MediaQuery(
  data: MediaQueryData(size: _phone, disableAnimations: reduced),
  // Keyed by its protein, as the route keys it.
  child: ZoomScreen(
    key: ValueKey<String>(target.slug),
    target: target,
    track: locusOf(target),
    record: recordOf(target),
    overWalk: overWalk,
  ),
);

/// A page standing in for the walk, and the zoom at its own route, over the
/// walk where its link says so.
GoRouter _walkAndZoom(
  ProteinTarget target,
  String initialLocation, {
  bool reduced = true,
}) => GoRouter(
  initialLocation: initialLocation,
  routes: <RouteBase>[
    GoRoute(
      path: '${RoutePaths.gene}/:slug',
      builder: (_, GoRouterState state) =>
          Scaffold(body: Text('the walk of ${state.pathParameters['slug']}')),
    ),
    GoRoute(
      path: '${RoutePaths.zoom}/:slug',
      builder: (_, GoRouterState state) => _screen(
        target,
        reduced: reduced,
        overWalk: RoutePaths.zoomIsOverWalk(state.uri),
      ),
    ),
  ],
);

/// Lets [time] pass a frame at a time. Not `pumpAndSettle`: near the cell
/// and the DNA the zoom's ambient clock never stops.
Future<void> _pass(WidgetTester tester, Duration time) async {
  const Duration frame = Duration(milliseconds: 50);
  for (Duration t = Duration.zero; t < time; t += frame) {
    await tester.pump(frame);
  }
}

/// Steps the zoom on screen down to the DNA, where the walk is offered.
Future<void> _toDna(WidgetTester tester) async {
  for (int step = 1; step < ZoomStop.values.length; step++) {
    await _tap(tester, 'zoom-next');
    // Longer than the longest flight between two stops.
    await _pass(tester, const Duration(seconds: 3));
  }
  expect(_stop(tester), 'DNA');
}

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

ZoomFacts _facts(ProteinTarget target) => ZoomFacts(
  track: locusOf(target),
  path: ZoomPath.of(locusOf(target)),
  record: recordOf(target),
);

ZoomDepth _depth(ProteinTarget target) =>
    ZoomDepth(locusOf(target), path: ZoomPath.of(locusOf(target)));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

/// The stop the card is at, by its overline.
String _stop(WidgetTester tester) => _text(tester, 'zoom-card-stop');

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey<String>(key)));
  await tester.pump();
}

bool _within(Rect inner, Rect outer) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

/// Two fingers on the canvas, [spread] times further apart when they lift,
/// moving apart in small even steps as fingers do.
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
  // The card's own face, so its words measure here as they do on a phone.
  setUpAll(
    () => _loadFont(AppTypography.sansFamily, <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ]),
  );

  testWidgets('one screen serves all twenty: every stop’s words, whole in '
      'the card', (WidgetTester tester) async {
    for (final ProteinTarget target in TestCatalog.all) {
      await _host(tester, target);
      expect(find.text(ZoomScreen.titleOf(target)), findsOneWidget);
      final ZoomFacts facts = _facts(target);
      for (final ZoomStop stop in ZoomStop.values) {
        if (stop != ZoomStop.body) {
          await _tap(tester, 'zoom-next');
        }
        expect(_stop(tester), ZoomScreen.nameOf(stop).toUpperCase());
        final ZoomFact fact = facts.of(stop);
        expect(_text(tester, 'zoom-card-title'), fact.title);
        expect(_text(tester, 'zoom-card-line'), fact.line);
        final Finder words = find.byKey(
          const ValueKey<String>('zoom-card-words'),
        );
        for (final String key in <String>[
          'zoom-card-title',
          'zoom-card-line',
        ]) {
          expect(
            _within(
              tester.getRect(find.byKey(ValueKey<String>(key))),
              tester.getRect(find.ancestor(of: words, matching: find.byType(SizedBox)).first),
            ),
            isTrue,
            reason: '${target.slug} at ${stop.name}: $key spills',
          );
        }
      }
    }
  });

  testWidgets('steps a stop either way, by its buttons and a double tap', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.insulin);
    expect(_stop(tester), 'BODY');
    // At the body there is nothing above it to step back to.
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('zoom-previous')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await _tap(tester, 'zoom-next');
    expect(_stop(tester), 'ORGAN');
    final Finder canvas = find.byKey(const ValueKey<String>('zoom-canvas'));
    await tester.tap(canvas);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(canvas);
    await tester.pumpAndSettle();
    expect(_stop(tester), 'TISSUE');
    await _tap(tester, 'zoom-previous');
    expect(_stop(tester), 'ORGAN');
  });

  testWidgets('the rail is a slider a screen reader steps by stop', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.hemoglobin);
    Semantics rail() => tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('zoom-rail')),
    );
    expect(rail().properties.slider, isTrue);
    expect(rail().properties.value, startsWith('Body, '));
    expect(rail().properties.increasedValue, 'Organ');
    expect(rail().properties.onDecrease, isNull);
    rail().properties.onIncrease!();
    await tester.pump();
    expect(_stop(tester), 'ORGAN');
    expect(rail().properties.decreasedValue, 'Body');
  });

  testWidgets('a pinch runs through the stops and lets go at the nearest', (
    WidgetTester tester,
  ) async {
    final ProteinTarget target = TestCatalog.hemoglobin;
    final ZoomDepth depth = _depth(target);
    await _host(tester, target);
    expect(_stop(tester), 'BODY');
    // The recognizer takes the gesture on only past its slop, so a test's
    // spread counts for less than its full factor: each is chosen to land
    // well inside the stop it names whatever the slop takes.
    expect(depth.depthOf(ZoomStop.organ), lessThan(1));
    expect(depth.depthOf(ZoomStop.tissue), greaterThan(3));
    // Spread fourfold: past the body, short of half way to the tissue.
    await _pinch(tester, 4);
    expect(_stop(tester), 'ORGAN');
    // Twentyfold more: most of the way to the tissue.
    await _pinch(tester, 20);
    expect(_stop(tester), 'TISSUE');
    // Fingers closing twentyfold: back to the organ.
    await _pinch(tester, 0.05);
    expect(_stop(tester), 'ORGAN');
  });

  testWidgets('with motion on a step flies there over its time; under '
      'reduced motion it cuts', (WidgetTester tester) async {
    await _host(tester, TestCatalog.insulin, reduced: false);
    await _tap(tester, 'zoom-next');
    await tester.pump(const Duration(milliseconds: 100));
    // Still on its way: the card has not reached the organ yet, or has
    // only just; the flight takes at least 450 ms.
    await tester.pumpAndSettle();
    expect(_stop(tester), 'ORGAN');

    // A fresh screen, not the one above kept by its key.
    await tester.pumpWidget(const SizedBox());
    await _host(tester, TestCatalog.insulin);
    await _tap(tester, 'zoom-next');
    expect(_stop(tester), 'ORGAN');
  });

  testWidgets('Play dives on its own, resting at each stop, and a touch '
      'pauses it', (WidgetTester tester) async {
    final ProteinTarget target = TestCatalog.hemoglobin;
    await _host(tester, target, reduced: false);
    await _tap(tester, 'zoom-play');
    // Resting at the body first.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(_stop(tester), 'BODY');
    // Then on to the organ, and its rest.
    await tester.pump(
      PlaySchedule.dwell + const Duration(milliseconds: 1500),
    );
    expect(_stop(tester), isNot('BODY'));
    // A touch on the canvas pauses the dive where it is.
    await tester.tap(find.byKey(const ValueKey<String>('zoom-canvas')));
    await tester.pump(const Duration(milliseconds: 400));
    final String paused = _stop(tester);
    await tester.pump(const Duration(seconds: 6));
    expect(_stop(tester), paused);
    expect(
      find.byTooltip('Play the dive'),
      findsOneWidget,
      reason: 'the button offers to play again',
    );
  });

  testWidgets('under reduced motion Play steps a stop every few seconds', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.insulin);
    await _tap(tester, 'zoom-play');
    expect(_stop(tester), 'BODY');
    await tester.pump(PlaySchedule.steppedHold + const Duration(milliseconds: 50));
    expect(_stop(tester), 'ORGAN');
    await tester.pump(PlaySchedule.steppedHold);
    expect(_stop(tester), 'TISSUE');
    await _tap(tester, 'zoom-play');
  });

  testWidgets('About names every source, under its licence', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.insulin);
    await _tap(tester, 'zoom-about');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('zoom-about-sheet')),
      findsOneWidget,
    );
    for (final ZoomSource source in _facts(TestCatalog.insulin).about) {
      expect(
        find.textContaining(source.name, findRichText: true),
        findsWidgets,
        reason: source.name,
      );
    }
    expect(find.textContaining('CC BY 4.0', findRichText: true), findsWidgets);
  });

  testWidgets('offers the walk at the DNA alone, and opens it at the gene', (
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
    for (final ZoomStop stop in ZoomStop.values) {
      if (stop != ZoomStop.body) {
        await _tap(tester, 'zoom-next');
      }
      expect(
        walk,
        stop == ZoomStop.dna ? findsOneWidget : findsNothing,
        reason: '$stop',
      );
    }
    await tester.tap(walk);
    await tester.pumpAndSettle();
    expect(find.text('the walk of ${target.slug}'), findsOneWidget);
  });

  for (final bool reduced in <bool>[true, false]) {
    testWidgets('opened over the walk, "Walk ›" goes back to that walk and '
        'opens no second one, ${reduced ? 'under reduced motion' : 'after '
              'the helix unzips'}', (WidgetTester tester) async {
      final ProteinTarget target = TestCatalog.hemoglobin;
      await tester.binding.setSurfaceSize(_phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final GoRouter router = _walkAndZoom(
        target,
        RoutePaths.geneFor(target),
        reduced: reduced,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.analysis, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('the walk of ${target.slug}'), findsOneWidget);

      // As the walk's gene page opens it.
      unawaited(router.push(RoutePaths.zoomFor(target, overWalk: true)));
      await _pass(tester, const Duration(seconds: 1));
      expect(find.byType(ZoomScreen), findsOneWidget);
      expect(router.canPop(), isTrue);
      await _toDna(tester);

      await tester.tap(find.byKey(const ValueKey<String>('zoom-walk')));
      // The helix unzips, where motion is allowed, and the page goes.
      await _pass(tester, const Duration(seconds: 2));
      expect(find.byType(ZoomScreen), findsNothing);
      expect(find.text('the walk of ${target.slug}'), findsOneWidget);
      // The walk it came from, with nothing left above or under it.
      expect(router.canPop(), isFalse);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        RoutePaths.geneFor(target),
      );
    });
  }

  testWidgets('a link that says it is over the walk, with no page under it, '
      'opens the walk like any other', (WidgetTester tester) async {
    final ProteinTarget target = TestCatalog.hemoglobin;
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = _walkAndZoom(
      target,
      RoutePaths.zoomFor(target, overWalk: true),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.analysis, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ZoomScreen), findsOneWidget);
    expect(router.canPop(), isFalse);
    await _toDna(tester);

    await tester.tap(find.byKey(const ValueKey<String>('zoom-walk')));
    await _pass(tester, const Duration(seconds: 2));
    expect(find.text('the walk of ${target.slug}'), findsOneWidget);
    // Above the zoom, which Back still returns to.
    expect(router.canPop(), isTrue);
  });

  test('only a zoom the walk opened says it is over the walk', () {
    final ProteinTarget target = TestCatalog.hemoglobin;
    expect(RoutePaths.zoomFor(target), '/zoom/hemoglobin');
    expect(
      RoutePaths.zoomIsOverWalk(Uri.parse(RoutePaths.zoomFor(target))),
      isFalse,
    );
    expect(
      RoutePaths.zoomIsOverWalk(
        Uri.parse(RoutePaths.zoomFor(target, overWalk: true)),
      ),
      isTrue,
    );
    expect(
      RoutePaths.zoomIsOverWalk(Uri.parse('/zoom/hemoglobin?over=search')),
      isFalse,
    );
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
