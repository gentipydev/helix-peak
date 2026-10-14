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
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_screen.dart';

import '../../../support/catalog_api.dart';
import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
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

/// The stop the card is at, by the key its words carry, in capitals: the
/// words of a stop being left may still be on their way out.
String _stop(WidgetTester tester) {
  const String prefix = 'zoom-card-at-';
  final Element words = find
      .byWidgetPredicate(
        (Widget w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(prefix),
      )
      .evaluate()
      .last;
  final String name = (words.widget.key! as ValueKey<String>).value.substring(
    prefix.length,
  );
  return ZoomScreen.nameOf(ZoomStop.values.byName(name)).toUpperCase();
}

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
        final Finder line = find.byKey(const ValueKey<String>('zoom-card-line'));
        if (fact.line.isEmpty) {
          expect(line, findsNothing, reason: '${target.slug} at ${stop.name}');
        } else {
          expect(_text(tester, 'zoom-card-line'), fact.line);
        }
        final Finder words = find.byKey(
          const ValueKey<String>('zoom-card-words'),
        );
        for (final String key in <String>[
          'zoom-card-title',
          if (fact.line.isNotEmpty) 'zoom-card-line',
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

  testWidgets('the card holds its words and a step either way, and nothing '
      'else', (WidgetTester tester) async {
    for (final ProteinTarget target in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.hemoglobin,
      TestCatalog.dystrophin,
    ]) {
      await _host(tester, target);
      for (final ZoomStop stop in ZoomStop.values) {
        if (stop != ZoomStop.body) {
          await _tap(tester, 'zoom-next');
        }
        for (final String gone in <String>[
          'zoom-play',
          'zoom-about',
          'zoom-rail',
          'zoom-card-stop',
          'zoom-card-source',
        ]) {
          expect(
            find.byKey(ValueKey<String>(gone)),
            findsNothing,
            reason: '${target.slug} at ${stop.name}: $gone',
          );
        }
        expect(find.byType(IconButton), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('zoom-previous')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey<String>(stop == ZoomStop.dna ? 'zoom-walk' : 'zoom-next'),
          ),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('every stop’s words fit the card on a small phone with type '
      'turned up', (WidgetTester tester) async {
    const Size small = Size(320, 568);
    await tester.binding.setSurfaceSize(small);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final ProteinTarget target in TestCatalog.all) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          home: MediaQuery(
            data: const MediaQueryData(
              size: small,
              textScaler: TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: ZoomScreen(
              key: ValueKey<String>(target.slug),
              target: target,
              track: locusOf(target),
              record: recordOf(target),
            ),
          ),
        ),
      );
      for (final ZoomStop stop in ZoomStop.values) {
        if (stop != ZoomStop.body) {
          await _tap(tester, 'zoom-next');
        }
        expect(tester.takeException(), isNull, reason: target.slug);
        final Rect words = tester.getRect(
          find
              .ancestor(
                of: find.byKey(const ValueKey<String>('zoom-card-words')),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(
          _within(
            tester.getRect(find.byKey(const ValueKey<String>('zoom-card-title'))),
            words,
          ),
          isTrue,
          reason: '${target.slug} at ${stop.name}',
        );
      }
    }
  });

  testWidgets('a step asked for mid-flight carries straight on, with no '
      'stall', (WidgetTester tester) async {
    final ProteinTarget target = TestCatalog.insulin;
    final ZoomDepth depth = _depth(target);
    await _host(tester, target, reduced: false);
    double at() => (tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('zoom-canvas')),
                )
                .painter!
            as ZoomPainter)
        .at();
    await _tap(tester, 'zoom-next');
    const Duration frame = Duration(microseconds: 16667);
    final List<double> seen = <double>[];
    for (int i = 0; i < 24; i++) {
      await tester.pump(frame);
      seen.add(at());
    }
    // A second step, while the first is still on its way to the organ.
    expect(seen.last, lessThan(depth.depthOf(ZoomStop.organ)));
    await _tap(tester, 'zoom-next');
    for (int i = 0; i < 6; i++) {
      await tester.pump(frame);
      seen.add(at());
    }
    // Its speed carries over: no frame's step is far from the one before.
    for (int i = 2; i < seen.length; i++) {
      final double before = seen[i - 1] - seen[i - 2];
      final double now = seen[i] - seen[i - 1];
      expect(now, greaterThan(0), reason: 'frame $i');
      expect((now - before).abs(), lessThan(0.02), reason: 'frame $i');
    }
    await tester.pumpAndSettle();
    // And it lands two stops on.
    expect(_stop(tester), 'TISSUE');
    expect(at(), closeTo(depth.depthOf(ZoomStop.tissue), 1e-9));
  });

  testWidgets('the body carries its credit, clear of the scale bar, and no '
      'other stop does', (WidgetTester tester) async {
    for (final ProteinTarget target in TestCatalog.all) {
      final ZoomFacts facts = _facts(target);
      final ZoomDepth depth = _depth(target);
      expect(
        facts.credit,
        'Anatomogram EMBL-EBI · HPA ${locusOf(target).atlasVersion} · '
        'CC BY 4.0',
      );
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(target), record: recordOf(target)),
      );
      expect(stage.creditAt(depth.depthOf(ZoomStop.body)), 1);
      for (final ZoomStop stop in ZoomStop.values.skip(1)) {
        expect(stage.creditAt(depth.depthOf(stop)), 0, reason: stop.name);
      }
    }
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    final TextStyle caption = AppTheme.analysis.caption!;
    final ZoomDepth depth = _depth(TestCatalog.insulin);
    final String credit = _facts(TestCatalog.insulin).credit;
    for (final Size size in <Size>[
      const Size(390, 560),
      const Size(320, 420),
    ]) {
      final (double pixels, String label) = scaleBarAt(depth, 0, size);
      final TextPainter text = TextPainter(
        text: TextSpan(text: label, style: labels),
        textDirection: TextDirection.ltr,
      )..layout();
      final Rect bar = scaleBarBox(pixels, text.size, size);
      text.dispose();
      final Rect box = creditBox(credit, caption, size, bar);
      expect(box.overlaps(bar), isFalse, reason: '$size');
      expect(box.right, lessThanOrEqualTo(size.width), reason: '$size');
      expect(box.left, greaterThan(bar.right), reason: '$size');
    }
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
