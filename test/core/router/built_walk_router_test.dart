// The walk's route for a protein built on demand: read afresh at every open,
// and handed a source that reads it by the rows it opened with, under the
// walk's own wait from the page's first frame. One of the catalog's own opens
// as it always has.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/gene_query.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/screens/gene_screen.dart';
import 'package:helixpeek/shared/widgets/loading_view.dart';

import '../../support/built_fold.dart';
import '../../support/catalog_api.dart';

/// The record's source: it notes what it was asked for, and never answers,
/// so a walk stays on its wait.
class _Records implements GeneRepository {
  final List<GeneQuery> asked = <GeneQuery>[];

  @override
  Future<GeneRecord> fetchGene(GeneQuery query) {
    asked.add(query);
    return Completer<GeneRecord>().future;
  }
}

/// Where the track client asks the platform for somewhere to cache.
const MethodChannel _paths = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CatalogApi api;
  late ProteinCatalogRepository catalog;
  late TrackClient client;
  late _Records records;

  /// Set, the service answers with it in place of a protein's row and rows.
  ApiException? down;

  /// The service's fold of transthyretin, as it stands.
  String generation = 'alphafold';

  /// Set, the service keeps every caller waiting on it, as one asleep does.
  Completer<void>? asleep;

  setUp(() async {
    generation = 'alphafold';
    asleep = null;
    down = null;
    records = _Records();
    api = CatalogApi();
    catalog = ProteinCatalogRepository(api, null);
    await catalog.refresh();
    api.answer = (String path, Map<String, dynamic>? query) async {
      await asleep?.future;
      if (down case final ApiException failure when path != '/catalog') {
        throw failure;
      }
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
        RepositoryProvider<FetchGene>.value(value: FetchGene(records)),
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

  /// Open transthyretin's walk as a list that names it does.
  Future<void> openNamed(WidgetTester tester) async {
    unawaited(
      appRouter.push(
        '/gene/ttr',
        extra: RoutePaths.walkNames(gene: 'TTR', display: 'Transthyretin'),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// The ground the wait on screen is drawn on.
  Color groundOf(WidgetTester tester) => Theme.of(
    tester.element(find.byType(LoadingView)),
  ).scaffoldBackgroundColor;

  group('the page that opens', () {
    testWidgets('from a list that names it is the walk\'s own wait from its first frame', (
      WidgetTester tester,
    ) async {
      await host(tester);
      asleep = Completer<void>();
      await openNamed(tester);

      // Before a word of its row is in: the walk's screen, headed, on the
      // walk's ground, and no other page before it.
      expect(find.byType(GeneScreen), findsOneWidget);
      expect(find.text('TTR'), findsOneWidget);
      expect(find.text('  \u00b7  Transthyretin'), findsOneWidget);
      expect(find.text('STARTING'), findsOneWidget);
      expect(find.textContaining('LOADING'), findsNothing);
      expect(groundOf(tester), AppTheme.analysis.scaffoldBackgroundColor);
      expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 44);
      // The record is not asked for by a row the app does not have.
      expect(records.asked, isEmpty);
      final State<LoadingView> wait = tester.state(find.byType(LoadingView));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.state(find.byType(LoadingView)), same(wait));

      // Its row and rows land: the same screen and the same wait, now asking
      // for the record by that row, its walk reading by those rows.
      asleep!.complete();
      asleep = null;
      await tester.pump();
      await tester.pump();
      expect(tester.state(find.byType(LoadingView)), same(wait));
      expect(find.text('STARTING'), findsNothing);
      expect(find.text('FETCHING NG_009490.1'), findsOneWidget);
      expect(find.text('  \u00b7  Transthyretin'), findsOneWidget);
      final GeneScreen walk = tester.widget<GeneScreen>(find.byType(GeneScreen));
      expect(walk.target.structure!.pdb, 'AF-P02766-F1');
      expect(records.asked.single, walk.target.query);
      final PinnedTrackSource source = sourceOf(tester)! as PinnedTrackSource;
      expect(source.rowsOf('ttr')![TrackKind.structure]!.sha256, '1' * 64);
      await finish(tester);
    });

    testWidgets('again opens at once on what the app holds, as a curated one does', (
      WidgetTester tester,
    ) async {
      await host(tester);
      await open(tester, '/gene/ttr');
      await open(tester, '/');
      // The page left has slid away.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GeneScreen), findsNothing);
      records.asked.clear();
      api.asked.clear();

      // The service is slow to say anything: nothing waits on it.
      asleep = Completer<void>();
      unawaited(appRouter.push('/gene/ttr'));
      await tester.pump();
      await tester.pump();
      final GeneScreen walk = tester.widget<GeneScreen>(find.byType(GeneScreen));
      expect(walk.target.structure!.pdb, 'AF-P02766-F1');
      expect(records.asked.single, walk.target.query);
      expect(find.text('FETCHING NG_009490.1'), findsOneWidget);
      expect(find.text('STARTING'), findsNothing);
      expect(find.textContaining('LOADING'), findsNothing);
      final TrackSource? source = sourceOf(tester);
      expect((source! as PinnedTrackSource).rowsOf('ttr')![TrackKind.structure]!.sha256, '1' * 64);
      // It is asked all the same, behind the walk.
      expect(api.asked, unorderedEquals(<String>['/protein/ttr', '/protein/ttr/tracks']));

      // It says what the app held: the walk is left as it is.
      final State<LoadingView> wait = tester.state(find.byType(LoadingView));
      asleep!.complete();
      asleep = null;
      await tester.pump();
      await tester.pump();
      expect(tester.state(find.byType(LoadingView)), same(wait));
      expect(sourceOf(tester), same(source));
      expect(records.asked, hasLength(1));
      await finish(tester);
    });

    testWidgets('again, its fold published since, is opened on the new one a moment later', (
      WidgetTester tester,
    ) async {
      await host(tester);
      await open(tester, '/gene/ttr');
      await open(tester, '/');
      await tester.pump(const Duration(milliseconds: 500));
      records.asked.clear();

      generation = 'pdb';
      asleep = Completer<void>();
      unawaited(appRouter.push('/gene/ttr'));
      await tester.pump();
      await tester.pump();
      // At once, on what it held.
      expect(
        tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
        'AF-P02766-F1',
      );
      final State<LoadingView> first = tester.state(find.byType(LoadingView));

      // The service answers in time, with other rows: a walk of those, whole.
      await tester.pump(const Duration(milliseconds: 300));
      asleep!.complete();
      asleep = null;
      await tester.pump();
      await tester.pump();
      final GeneScreen walk = tester.widget<GeneScreen>(find.byType(GeneScreen));
      expect(walk.target.structure!.pdb, '8C86');
      expect(walk.target.state(TrackKind.folding), TrackState.ready);
      final PinnedTrackSource source = sourceOf(tester)! as PinnedTrackSource;
      expect(source.rowsOf('ttr')![TrackKind.structure]!.sha256, '2' * 64);
      expect(source.rowsOf('ttr')![TrackKind.folding]!.sha256, '3' * 64);
      // A new walk, with a lookup of its own asking for the record.
      expect(tester.state(find.byType(LoadingView)), isNot(same(first)));
      expect(records.asked, hasLength(2));
      expect(find.byType(GeneScreen), findsOneWidget);
      await finish(tester);
    });

    testWidgets('from a link that names nothing waits on the walk\'s ground, under its header\'s height', (
      WidgetTester tester,
    ) async {
      await host(tester);
      asleep = Completer<void>();
      unawaited(appRouter.push('/gene/ttr'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(GeneScreen), findsNothing);
      expect(find.text('LOADING TTR'), findsOneWidget);
      expect(groundOf(tester), AppTheme.analysis.scaffoldBackgroundColor);
      expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 44);
      // Under the header, and clear of the status bar.
      expect(
        tester.getTopLeft(find.byType(LoadingView)).dy,
        tester.getBottomLeft(find.byType(AppBar)).dy,
      );

      asleep!.complete();
      asleep = null;
      await tester.pump();
      await tester.pump();
      expect(find.byType(GeneScreen), findsOneWidget);
      expect(find.text('FETCHING NG_009490.1'), findsOneWidget);
      expect(groundOf(tester), AppTheme.analysis.scaffoldBackgroundColor);
      await finish(tester);
    });

    testWidgets('gives way to the failure where its row cannot be read, and Retry to the wait', (
      WidgetTester tester,
    ) async {
      await host(tester);
      down = const NetworkApiException();
      await openNamed(tester);
      await tester.pump();
      expect(find.text('Fetch failed'), findsOneWidget);
      expect(find.byType(GeneScreen), findsNothing);
      expect(records.asked, isEmpty);
      // On the walk's ground still, under a header of its height with the way back.
      expect(
        Theme.of(tester.element(find.text('Fetch failed'))).scaffoldBackgroundColor,
        AppTheme.analysis.scaffoldBackgroundColor,
      );
      expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 44);
      expect(find.byType(BackButton), findsOneWidget);

      down = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('FETCHING NG_009490.1'), findsOneWidget);
      expect(
        tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
        'AF-P02766-F1',
      );
      await finish(tester);
    });
  });

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

  testWidgets('already read and already touched, the walk is not opened again under the reader', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await open(tester, '/gene/ttr');
    await open(tester, '/');
    await tester.pump(const Duration(milliseconds: 500));

    generation = 'pdb';
    asleep = Completer<void>();
    records.asked.clear();
    unawaited(appRouter.push('/gene/ttr'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final TrackSource? source = sourceOf(tester);
    // A finger on it, before the service has said its fold was published again.
    await tester.tapAt(tester.getCenter(find.byType(LoadingView)));
    await tester.pump();
    asleep!.complete();
    asleep = null;
    await tester.pump();
    await tester.pump();
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
           'AF-P02766-F1');
    expect(sourceOf(tester), same(source));
    expect(records.asked, hasLength(1));

    // Left and opened again: the new fold.
    await open(tester, '/');
    await tester.pump(const Duration(milliseconds: 500));
    await open(tester, '/gene/ttr');
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb, '8C86');
    await finish(tester);
  });

  testWidgets('already read, a service too slow to say so leaves the walk as it opened', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await open(tester, '/gene/ttr');
    await open(tester, '/');
    await tester.pump(const Duration(milliseconds: 500));

    generation = 'pdb';
    asleep = Completer<void>();
    records.asked.clear();
    appRouter.go('/gene/ttr');
    await tester.pump();
    await tester.pump();
    // The walk is up at once, and the record asked for.
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
           'AF-P02766-F1');
    expect(records.asked, hasLength(1));
    final TrackSource? source = sourceOf(tester);
    await tester.pump(walkPatience + const Duration(milliseconds: 100));

    // The service wakes too late for this walk: it stays whole as it opened,
    // and the next open is on the new fold, at once.
    asleep!.complete();
    asleep = null;
    await tester.pump();
    await tester.pump();
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb,
           'AF-P02766-F1');
    expect(sourceOf(tester), same(source));
    expect(records.asked, hasLength(1));
    await open(tester, '/');
    await tester.pump(const Duration(milliseconds: 500));
    asleep = Completer<void>();
    unawaited(appRouter.push('/gene/ttr'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure!.pdb, '8C86');
    asleep!.complete();
    asleep = null;
    await tester.pump();
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
