// A build's fold on its card: a "Structure" row after its gene record, marked
// from the fold's own state (the user's decision of 2026-10-12), and a build
// held at its fold until the fold is made.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/search/presentation/widgets/suggestion_tile.dart';

import '../../support/catalog_api.dart';
import 'support/resolver_api.dart';

const Duration _pause = Duration(milliseconds: 300);
const Duration _tick = Duration(seconds: 3);

final Map<String, dynamic> _brca1 = <String, dynamic>{
  'uniprot': 'P38398', 'gene': 'BRCA1', 'name': 'Breast cancer type 1 susceptibility protein',
  'display': null, 'length': 1863, 'slug': 'brca1', 'status': 'buildable', 'reason': null,
  'building': false, 'stopped': false,
};

Map<String, dynamic> _said(String state, Map<String, dynamic> build) =>
    <String, dynamic>{'slug': 'brca1', 'state': state, 'reason': null, 'build': build};

/// A `BuildReport` as the backend's `app/resolves.py` writes one, its fold
/// beside it.
Map<String, dynamic> _report(String step, double elapsed, {String? fold, int? scored}) =>
    <String, dynamic>{
      'step': step, 'ahead': step == 'scoring' ? 0 : null, 'scored': scored,
      'residues': scored, 'left': null, 'elapsed': elapsed, 'transcript': 'NM_007294.4',
      'reason': null, 'stopped': false, 'ran': null, 'fold': fold,
    };

Future<Map<String, dynamic>> Function(String) _inTurn(List<Map<String, dynamic>> answers) =>
    (String key) async => answers.length > 1 ? answers.removeAt(0) : answers.single;

Finder _inCard(Finder finder) =>
    find.descendant(of: find.byKey(const ValueKey<String>('build-BRCA1')), matching: finder);

/// The mark beside a step of the card, by the step's name: within the row
/// the step is padded in, the nearest padding round its name.
Finder _markOf(String step, IconData icon) => find.descendant(
  of: find.ancestor(of: _inCard(find.text(step)), matching: find.byType(Padding)).first,
  matching: find.byIcon(icon),
);

/// The search screen with a build of BRCA1 asked for, answered in turn by
/// [answers].
Future<void> _build(WidgetTester tester, List<Map<String, dynamic>> answers) async {
  final ResolverApi api = ResolverApi(
    suggest: (String q) async => <String, dynamic>{
      'q': q, 'release': 'UniProt 2026_03 · MANE v1.5',
      'suggestions': <Map<String, dynamic>>[_brca1],
    },
    resolve: (String gene) async => _said('pending', _report('queued', 0.2)),
    status: _inTurn(answers),
  );
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(CatalogApi(), null);
  await catalog.refresh();
  addTearDown(catalog.dispose);
  final ProteinResolver resolver = ProteinResolver(api);
  final GoRouter router = GoRouter(routes: <RouteBase>[
    GoRoute(path: '/', builder: (BuildContext context, GoRouterState state) => const SearchScreen()),
    GoRoute(
      path: '/gene/:slug',
      builder: (BuildContext context, GoRouterState state) =>
          Scaffold(body: Text('walk ${state.pathParameters['slug']}')),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(400, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<ProteinResolver>.value(value: resolver),
        RepositoryProvider<ProteinBuilds>(
          create: (BuildContext context) => ProteinBuilds(resolver),
          dispose: (ProteinBuilds builds) => builds.dispose(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'brca1');
  await tester.pump();
  await tester.pump(_pause);
  await tester.pump();
  await tester.tap(find.descendant(
    of: find.ancestor(
      of: find.text('Breast cancer type 1 susceptibility protein'),
      matching: find.byType(SuggestionTile),
    ),
    matching: find.text('Build'),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  test('the service\'s structure step reads as every step behind it, held for its fold', () {
    final BuildReport held = ResolveStatus.fromJson(
      _said('ready', _report('structure', 905.0, fold: 'pending')),
    ).build!;
    expect((held.step, held.holding, held.fold, held.reason),
           (BuildStep.done, true, TrackState.pending, null));
    final BuildReport done = ResolveStatus.fromJson(
      _said('ready', _report('done', 905.0, fold: 'ready')),
    ).build!;
    expect((done.step, done.holding, done.fold), (BuildStep.done, false, TrackState.ready));
    // From a service older than the fold, no fold, and no row for one.
    final BuildReport older = ResolveStatus.fromJson(
      _said('ready', <String, dynamic>{'step': 'scoring', 'elapsed': 3.0}),
    ).build!;
    expect((older.fold, older.holding), (null, false));
  });

  testWidgets('a build\'s fold is a Structure row after its gene record, marked by its state', (
    WidgetTester tester,
  ) async {
    await _build(tester, <Map<String, dynamic>>[
      _said('ready', _report('evidence', 53.0, fold: 'pending')),
      _said('ready', _report('scoring', 172.0, fold: 'ready')),
    ]);
    await tester.pump(_tick);
    final Finder structure = _inCard(find.text('Structure'));
    expect(structure, findsOneWidget);
    final double record = tester.getTopLeft(_inCard(find.text('Gene record'))).dy;
    final double evidence = tester.getTopLeft(_inCard(find.text('AlphaGenome and ClinVar'))).dy;
    expect(tester.getTopLeft(structure).dy, inExclusiveRange(record, evidence));
    // Being made: not done.
    expect(_markOf('Structure', Icons.check_rounded), findsNothing);

    await tester.pump(_tick);
    expect(_markOf('Structure', Icons.check_rounded), findsOneWidget);
  });

  testWidgets('a build held for its first fold is not done until the fold is made', (
    WidgetTester tester,
  ) async {
    await _build(tester, <Map<String, dynamic>>[
      _said('ready', _report('structure', 905.0, fold: 'pending', scored: 1863)),
      _said('ready', _report('done', 911.0, fold: 'ready', scored: 1863)),
    ]);
    await tester.pump(_tick);
    // Every step behind it, the fold under way, and nothing to open yet.
    for (final String step in <String>['Queued', 'Gene record', 'AlphaGenome and ClinVar',
                                       'ESM-2 650M', 'Alignment check']) {
      expect(_markOf(step, Icons.check_rounded), findsOneWidget, reason: step);
    }
    expect(_markOf('Structure', Icons.check_rounded), findsNothing);
    expect(find.text('Open'), findsNothing);

    // Made: done, and it opens.
    await tester.pump(_tick);
    expect(_inCard(find.text('Open')), findsOneWidget);
  });

  testWidgets('a fold with no model is marked so, and a build with no fold has no row', (
    WidgetTester tester,
  ) async {
    await _build(tester, <Map<String, dynamic>>[
      _said('ready', _report('scoring', 172.0, fold: 'refused')),
    ]);
    await tester.pump(_tick);
    expect(_markOf('Structure', Icons.close_rounded), findsOneWidget);
  });

  testWidgets('a build made without models shows its five steps alone', (
    WidgetTester tester,
  ) async {
    await _build(tester, <Map<String, dynamic>>[
      _said('ready', _report('scoring', 172.0)),
    ]);
    await tester.pump(_tick);
    expect(_inCard(find.text('Gene record')), findsOneWidget);
    expect(_inCard(find.text('Structure')), findsNothing);
  });
}
