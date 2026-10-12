// Search opens the walk of a protein outside the catalog with the names it
// already shows for it, so the walk's wait is headed while its row is read
// (RoutePaths.walkNames). A curated protein is opened by its row, as it was.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/search/presentation/widgets/build_ready_listener.dart';
import 'package:helixpeek/features/search/presentation/widgets/protein_card.dart';
import 'package:helixpeek/features/search/presentation/widgets/suggestion_tile.dart';

import '../../support/catalog_api.dart';
import 'support/resolver_api.dart';

const Duration _pause = Duration(milliseconds: 300);
const Duration _tick = Duration(seconds: 3);

Map<String, dynamic> _suggestion(
  String uniprot,
  String gene,
  String name,
  int length,
  String status, {
  String? slug,
  String? display,
}) => <String, dynamic>{
  'uniprot': uniprot, 'gene': gene, 'name': name, 'display': display,
  'length': length, 'slug': slug, 'status': status, 'reason': null,
  'building': false, 'stopped': false,
};

final Map<String, dynamic> _ttr = _suggestion(
  'P02766', 'TTR', 'Transthyretin', 147, 'ready', slug: 'ttr', display: 'Transthyretin');
final Map<String, dynamic> _b2m = _suggestion(
  'P61769', 'B2M', 'Beta-2-microglobulin', 119, 'ready', slug: 'b2m');
final Map<String, dynamic> _brca1 = _suggestion(
  'P38398', 'BRCA1', 'Breast cancer type 1 susceptibility protein', 1863, 'buildable',
  slug: 'brca1');

Map<String, dynamic> _built(String step, double elapsed) => <String, dynamic>{
  'slug': 'brca1', 'state': 'ready', 'reason': null,
  'build': <String, dynamic>{
    'step': step, 'ahead': null, 'scored': 1863, 'residues': 1863, 'left': null,
    'elapsed': elapsed, 'transcript': 'NM_007294.4', 'reason': null,
  },
};

/// What each walk was opened with: its slug, and the `extra` beside it.
final List<(String, Object?)> _opened = <(String, Object?)>[];

/// Search over a router whose walk only notes how it was opened, with the
/// app's builds and its build-ready listener above it, as the app has them.
Future<(GoRouter, ProteinBuilds)> _pump(WidgetTester tester, ResolverApi api) async {
  _opened.clear();
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(CatalogApi(), null);
  await catalog.refresh();
  addTearDown(catalog.dispose);
  final ProteinResolver resolver = ProteinResolver(api);
  final ProteinBuilds builds = ProteinBuilds(resolver);
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/elsewhere',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('elsewhere')),
      ),
      GoRoute(
        path: '/gene/:slug',
        builder: (BuildContext context, GoRouterState state) {
          _opened.add((state.pathParameters['slug']!, state.extra));
          return Scaffold(body: Text('walk ${state.pathParameters['slug']}'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(400, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<ProteinResolver>.value(value: resolver),
        RepositoryProvider<ProteinBuilds>(
          create: (BuildContext context) => builds,
          dispose: (ProteinBuilds builds) => builds.dispose(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) =>
            BuildReadyListener(router: router, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router, builds);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.pump(_pause);
  await tester.pump();
}

Finder _tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SuggestionTile));

Future<Map<String, dynamic>> Function(String) _finding(List<Map<String, dynamic>> found) =>
    (String q) async => <String, dynamic>{'q': q, 'release': null, 'suggestions': found};

void main() {
  testWidgets('a protein on the built tab is opened with its symbol and its name', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      ResolverApi(
        built: (int limit) async => <String, dynamic>{
          'proteins': <Map<String, dynamic>>[_ttr],
          'next': null,
        },
      ),
    );
    await tester.tap(find.text('Built on demand'));
    await tester.pump();
    await tester.pump();
    await tester.tap(_tile('Transthyretin'));
    await tester.pumpAndSettle();
    expect(find.text('walk ttr'), findsOneWidget);
    expect(_opened.single.$1, 'ttr');
    expect(
      _opened.single.$2,
      RoutePaths.walkNames(gene: 'TTR', display: 'Transthyretin'),
    );
  });

  testWidgets('a built protein a search finds is opened by the name its row shows', (
    WidgetTester tester,
  ) async {
    await _pump(tester, ResolverApi(suggest: _finding(<Map<String, dynamic>>[_b2m])));
    await _type(tester, 'b2m');
    await tester.tap(_tile('Beta-2-microglobulin'));
    await tester.pumpAndSettle();
    // No name of the app's own for it: UniProt's, as its row is titled.
    expect(_opened.single.$1, 'b2m');
    expect(
      _opened.single.$2,
      RoutePaths.walkNames(gene: 'B2M', display: 'Beta-2-microglobulin'),
    );
  });

  testWidgets('a build that has ended is opened named, from its card and from what says it elsewhere', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => _built('done', 600),
      status: (String gene) async => _built('done', 600),
    );
    final (GoRouter router, ProteinBuilds builds) = await _pump(tester, api);
    final Map<String, String> named = RoutePaths.walkNames(
      gene: 'BRCA1',
      display: 'Breast cancer type 1 susceptibility protein',
    );
    await _type(tester, 'brca1');
    await tester.tap(
      find.descendant(
        of: _tile('Breast cancer type 1 susceptibility protein'),
        matching: find.text('Build'),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('build-BRCA1')),
        matching: find.text('Open'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_opened.single.$1, 'brca1');
    expect(_opened.single.$2, named);

    // And one that ends while search is not the screen: said there, with Open.
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    _opened.clear();
    unawaited(builds.build(ProteinSuggestion.fromJson(_brca1)));
    await tester.pump();
    await tester.pump(_tick);
    await tester.pump();
    await tester.tap(find.widgetWithText(SnackBarAction, 'Open'));
    await tester.pumpAndSettle();
    expect(_opened.single.$1, 'brca1');
    expect(_opened.single.$2, named);
  });

  testWidgets('a curated protein is opened by its row, with nothing beside it', (
    WidgetTester tester,
  ) async {
    await _pump(tester, ResolverApi());
    await tester.tap(find.widgetWithText(ProteinCard, 'Insulin'));
    await tester.pumpAndSettle();
    expect(_opened.single.$1, 'insulin');
    expect(_opened.single.$2, isNull);
  });
}
