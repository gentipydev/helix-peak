import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/lab_routes.dart';
import 'package:helixpeek/features/lab/lab_scope.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_screen.dart';
import 'package:helixpeek/features/lab/presentation/lab_index_screen.dart';
import 'package:helixpeek/features/lab/presentation/lab_protein_picker.dart';

import '../../support/catalog_api.dart';

void main() {
  tearDown(dotenv.clean);

  test('a build without the flag has no lab routes', () {
    dotenv.clean();
    expect(labRoutes, isEmpty);
  });

  test('a build with the flag off says so, and has none either', () {
    dotenv.loadFromString(envString: 'LAB_ENABLED=false');
    expect(labRoutes, isEmpty);
  });

  test('a build with the flag on has them', () {
    dotenv.loadFromString(envString: 'LAB_ENABLED=true');
    expect(labRoutes, isNotEmpty);
  });

  testWidgets('the lab reads through its own client, not the walk’s', (
    WidgetTester tester,
  ) async {
    final ApiClient api = CatalogApi();
    final TrackClient walk = TrackClient(api);
    late BuildContext inside;
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ApiClient>.value(value: api),
          RepositoryProvider<TrackSource>.value(value: walk),
        ],
        child: MaterialApp(
          home: LabScope(
            child: Builder(
              builder: (BuildContext context) {
                inside = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    final TrackSource source = inside.read<TrackSource>();
    expect(source, isNot(same(walk)));
    expect(source, same(inside.read<TrackClient>()));
    final TrackClient lab = inside.read<TrackClient>();
    expect(lab.folder, LabScope.folder);
    expect(lab.folder, isNot(walk.folder));
    expect(lab.budget, LabScope.budget);
    expect(inside.read<FetchGene>(), isA<FetchGene>());
  });

  testWidgets('the index says so while it holds nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LabIndexScreen(features: <LabFeature>[])),
    );
    expect(find.text('Lab'), findsOneWidget);
    expect(find.text('Nothing in the lab yet.'), findsOneWidget);
  });

  testWidgets('the index lists each feature with its summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LabIndexScreen(
          features: <LabFeature>[
            LabFeature(title: 'One', summary: 'The first.', path: '/lab/one'),
            LabFeature(title: 'Two', summary: 'The second.', path: '/lab/two'),
          ],
        ),
      ),
    );
    expect(find.text('One'), findsOneWidget);
    expect(find.text('The second.'), findsOneWidget);
    expect(find.text('Nothing in the lab yet.'), findsNothing);
  });

  testWidgets('each feature on the index is a route that picks a protein', (
    WidgetTester tester,
  ) async {
    for (final LabFeature feature in labFeatures) {
      await hostLab(tester, feature.path);
      expect(find.byType(LabProteinPicker), findsOneWidget, reason: feature.path);
      expect(find.text('Insulin'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('/lab/mutate/<slug> opens the mutate screen for that protein', (
    WidgetTester tester,
  ) async {
    await hostLab(tester, '/lab/mutate/insulin');
    expect(find.byType(MutateScreen), findsOneWidget);
    expect(find.text('Mutate · Insulin'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// The lab's routes under a real router, over the app's catalog.
Future<GoRouter> hostLab(WidgetTester tester, String path) async {
  final CatalogApi api = CatalogApi();
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(api, null);
  addTearDown(catalog.dispose);
  await catalog.refresh();
  final GoRouter router = buildAppRouter(extra: buildLabRoutes());
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ApiClient>.value(value: api),
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}
