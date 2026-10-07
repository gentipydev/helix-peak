import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/lab_routes.dart';
import 'package:helixpeek/features/lab/presentation/lab_index_screen.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_screen.dart';
import 'package:helixpeek/features/zoom/zoom_routes.dart';

import '../../support/catalog_api.dart';
import '../../support/test_catalog.dart';
import 'zoom_fixtures.dart';

/// The catalog as the service serves it today: every row's locus ready, which
/// the walk's own fixture does not say.
Map<String, dynamic> _locatedCatalog() {
  final Map<String, dynamic> body = catalogFixture();
  for (final Object? row in body['proteins'] as List<dynamic>) {
    final Map<String, dynamic> tracks =
        (row! as Map<String, dynamic>)['tracks'] as Map<String, dynamic>;
    tracks[TrackKind.locus.wire] = TrackState.ready.wire;
  }
  return body;
}

/// [ZoomTrackSource]'s files, read at once: a widget test's clock does not
/// wait for the disk.
final class _HeldTracks implements TrackSource {
  int reads = 0;

  @override
  Future<Uint8List> read(String slug, TrackKind kind) {
    reads++;
    final ProteinTarget target = TestCatalog.bySlug(slug)!;
    return Future<Uint8List>.value(
      File(
        kind == TrackKind.locus ? locusAsset(target) : target.asset(kind)!,
      ).readAsBytesSync(),
    );
  }
}

/// The app's routes with the zoom's, and the lab's where [lab] says so, over
/// a catalog that has a locus for every protein.
Future<(GoRouter, _HeldTracks)> _host(
  WidgetTester tester,
  String path, {
  bool lab = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final CatalogApi api = CatalogApi(answer: (_, _) async => _locatedCatalog());
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(api, null);
  addTearDown(catalog.dispose);
  await catalog.refresh();
  final _HeldTracks tracks = _HeldTracks();
  final GoRouter router = buildAppRouter(
    extra: <RouteBase>[...zoomRoutes, if (lab) ...buildLabRoutes()],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ApiClient>.value(value: api),
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<TrackSource>.value(value: tracks),
        RepositoryProvider<FetchGene>.value(
          value: FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks))),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        // Reduced motion, so a page is settled the moment it is reached.
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  router.go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return (router, tracks);
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  tearDown(dotenv.clean);

  testWidgets('/zoom/<slug> opens the zoom in a build without the lab, in '
      'the walk’s theme and through the app’s tracks', (
    WidgetTester tester,
  ) async {
    dotenv.clean();
    expect(labRoutes, isEmpty);
    final (GoRouter _, _HeldTracks tracks) = await _host(
      tester,
      '/zoom/insulin',
    );
    expect(find.byType(ZoomScreen), findsOneWidget);
    expect(find.text(ZoomScreen.titleOf(TestCatalog.insulin)), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ZoomScreen))).colorScheme.surface,
      AppTheme.analysis.colorScheme.surface,
    );
    // The locus and the record, from the source the app provides: nothing
    // stands between the route and it, as the lab's shell did.
    expect(tracks.reads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a protein with no locus is told so, as it was in the lab', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The walk's fixture, which names no locus for any protein.
    final ProteinCatalogRepository catalog = ProteinCatalogRepository(
      CatalogApi(),
      null,
    );
    addTearDown(catalog.dispose);
    await catalog.refresh();
    final _HeldTracks tracks = _HeldTracks();
    final GoRouter router = buildAppRouter(extra: zoomRoutes);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
          RepositoryProvider<TrackSource>.value(value: tracks),
          RepositoryProvider<FetchGene>.value(
            value: FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks))),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/zoom/insulin');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ZoomScreen), findsNothing);
    expect(
      find.text(ZoomScreen.unavailable(TrackState.absent, null)),
      findsOneWidget,
    );
    expect(tracks.reads, 0);
  });

  for (final bool lab in <bool>[false, true]) {
    final String build = lab ? 'with the lab' : 'without the lab';

    testWidgets('a link from when it was a lab flow opens it where it is '
        'now, $build', (WidgetTester tester) async {
      final (GoRouter router, _HeldTracks _) = await _host(
        tester,
        '/lab/zoom/hemoglobin',
        lab: lab,
      );
      expect(_location(router), '/zoom/hemoglobin');
      expect(find.byType(ZoomScreen), findsOneWidget);
      expect(
        find.text(ZoomScreen.titleOf(TestCatalog.hemoglobin)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the lab’s old picker is the protein list, $build', (
      WidgetTester tester,
    ) async {
      final (GoRouter router, _HeldTracks _) = await _host(
        tester,
        '/lab/zoom',
        lab: lab,
      );
      expect(_location(router), RoutePaths.search);
      expect(find.byType(SearchScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('the lab no longer lists it', () {
    for (final LabFeature feature in labFeatures) {
      expect(feature.title, isNot('Zoom'));
      expect(feature.path, isNot(startsWith('${RoutePaths.lab}/zoom')));
    }
  });

  test('its path is its own, outside the lab', () {
    expect(RoutePaths.zoomFor(TestCatalog.insulin), '/zoom/insulin');
    expect(RoutePaths.zoom, isNot(startsWith(RoutePaths.lab)));
  });
}
