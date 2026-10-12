// The walk's route for a protein built on demand: read afresh at every open,
// and handed a source that reads it by the rows it opened with. One of the
// catalog's own opens as it always has.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/gene_query.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/screens/gene_screen.dart';

import '../../support/built_fold.dart';
import '../../support/catalog_api.dart';

class _Records implements GeneRepository {
  @override
  Future<GeneRecord> fetchGene(GeneQuery query) => Completer<GeneRecord>().future;
}

/// Where the track client asks the platform for somewhere to cache.
const MethodChannel _paths = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CatalogApi api;
  late ProteinCatalogRepository catalog;
  late TrackClient client;

  /// The service's fold of transthyretin, as it stands.
  String generation = 'alphafold';

  /// Set, the service keeps every caller waiting on it, as one asleep does.
  Completer<void>? asleep;

  setUp(() async {
    generation = 'alphafold';
    asleep = null;
    api = CatalogApi();
    catalog = ProteinCatalogRepository(api, null);
    await catalog.refresh();
    api.answer = (String path, Map<String, dynamic>? query) async {
      await asleep?.future;
      return path.endsWith('/tracks')
          ? BuiltFold.tracks(generation)
          : path == '/protein/ttr'
          ? BuiltFold.row(generation)
          : catalogFixture();
    };
    // A platform with nowhere to cache, said at once: the client's own files
    // are real I/O, which a widget test's clock never waits for.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_paths, (MethodCall call) async => null);
    client = TrackClient(api);
    appRouter.go('/');
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_paths, null);
    catalog.dispose();
  });

  Future<void> host(WidgetTester tester) => tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<TrackSource>.value(value: client),
        RepositoryProvider<FetchGene>.value(value: FetchGene(_Records())),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ),
  );

  Future<void> open(WidgetTester tester, String path) async {
    appRouter.go(path);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  }

  /// The source the walk on screen reads its tracks by.
  TrackSource? sourceOf(WidgetTester tester) =>
      tester.element(find.byType(GeneScreen)).read<TrackSource?>();

  testWidgets('its walk reads by the rows it opened with, and the next open by the new ones', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await open(tester, '/gene/ttr');
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
           'AF-P02766-F1');
    final TrackSource? first = sourceOf(tester);
    expect(first, isA<PinnedTrackSource>());
    expect((first! as PinnedTrackSource).rowsOf('ttr')![TrackKind.structure]!.sha256, '1' * 64);

    // Its fold is published again while the walk is open: the walk keeps its own.
    generation = 'pdb';
    await tester.pump(const Duration(seconds: 5));
    expect(sourceOf(tester), same(first));
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
           'AF-P02766-F1');

    // Left and opened again, with no restart: the new fold, whole.
    await open(tester, '/');
    await open(tester, '/gene/ttr');
    final GeneScreen walk = tester.widget<GeneScreen>(find.byType(GeneScreen));
    expect(walk.target.structure!.pdb, '8C86');
    expect(walk.target.state(TrackKind.folding), TrackState.ready);
    final PinnedTrackSource second = sourceOf(tester)! as PinnedTrackSource;
    expect(second.rowsOf('ttr')![TrackKind.structure]!.sha256, '2' * 64);
    expect(second.rowsOf('ttr')![TrackKind.folding]!.sha256, '3' * 64);
    await finish(tester);
  });

  testWidgets('already read, it opens on what is held when the service is slow to answer', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await open(tester, '/gene/ttr');
    await open(tester, '/');

    generation = 'pdb';
    asleep = Completer<void>();
    appRouter.go('/gene/ttr');
    await tester.pump();
    await tester.pump(walkPatience - const Duration(milliseconds: 100));
    expect(find.text('LOADING TTR'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
           'AF-P02766-F1');
    expect((sourceOf(tester)! as PinnedTrackSource).rowsOf('ttr')![TrackKind.structure]!.sha256,
           '1' * 64);

    // The service wakes: the walk stays as it opened, and the next open is the new fold.
    asleep!.complete();
    asleep = null;
    await tester.pump();
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
           'AF-P02766-F1');
    await open(tester, '/');
    await open(tester, '/gene/ttr');
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb, '8C86');
    await finish(tester);
  });

  testWidgets('one of the catalog\'s own opens at once, by the app\'s own source, and asks nothing', (
    WidgetTester tester,
  ) async {
    await host(tester);
    api.asked.clear();
    appRouter.go('/gene/insulin');
    await tester.pump();
    await tester.pump();
    expect(find.text('LOADING INSULIN'), findsNothing);
    expect(find.byType(GeneScreen), findsOneWidget);
    expect(sourceOf(tester), same(client));
    expect(api.asked, isEmpty);
    await finish(tester);
  });
}
