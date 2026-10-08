import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/search/presentation/widgets/protein_card.dart';
import 'package:helixpeek/features/search/presentation/widgets/suggestion_tile.dart';

import '../../support/catalog_api.dart';
import 'support/resolver_api.dart';

/// Search beyond the curated list: the second half of the screen, which asks
/// the service about every reviewed human protein and builds one on demand.
///
/// The curated list is the catalog's own fixtures; the service is
/// [ResolverApi], answering as the backend's `/proteins/suggest` and
/// `/proteins/resolve` do. Time is the widget binding's fake time: the pause
/// before a search is asked for and every poll of a build is a `pump`.

const Duration _pause = Duration(milliseconds: 300);
const Duration _tick = Duration(seconds: 3);
const String _release = 'UniProt 2026_03 · MANE v1.5';

Map<String, dynamic> _suggestion(
  String uniprot,
  String gene,
  String name,
  int length,
  String status, {
  String? slug,
  String? display,
  String? reason,
  bool building = false,
}) => <String, dynamic>{
  'uniprot': uniprot, 'gene': gene, 'name': name, 'display': display,
  'length': length, 'slug': slug, 'status': status, 'reason': reason,
  'building': building,
};

final Map<String, dynamic> _insulin = _suggestion(
  'P01308', 'INS', 'Insulin', 110, 'listed', slug: 'insulin', display: 'Insulin');
final Map<String, dynamic> _insr = _suggestion(
  'P06213', 'INSR', 'Insulin receptor', 1382, 'buildable', slug: 'insr');
final Map<String, dynamic> _brca1 = _suggestion(
  'P38398', 'BRCA1', 'Breast cancer type 1 susceptibility protein', 1863, 'buildable',
  slug: 'brca1');
final Map<String, dynamic> _b2m = _suggestion(
  'P61769', 'B2M', 'Beta-2-microglobulin', 119, 'ready', slug: 'b2m');
const String _isoform =
    'MANE Select encodes isoform Q13625-3, and UniProt numbers its features on the '
    'canonical sequence.';
final Map<String, dynamic> _tp53bp2 = _suggestion(
  'Q13625', 'TP53BP2', 'Apoptosis-stimulating of p53 protein 2', 1128, 'unavailable',
  reason: _isoform);

Future<Map<String, dynamic>> Function(String) _finding(
  List<Map<String, dynamic>> suggestions,
) =>
    (String q) async => <String, dynamic>{
      'q': q, 'release': _release, 'suggestions': suggestions,
    };

Map<String, dynamic> _said(
  String state, {
  String? slug,
  String? reason,
  Map<String, dynamic>? build,
}) => <String, dynamic>{'slug': slug, 'state': state, 'reason': reason, 'build': build};

/// A `BuildReport` as the backend's `app/resolves.py` writes one.
Map<String, dynamic> _report(
  String step,
  double elapsed, {
  int? ahead,
  int? scored,
  int? residues,
  double? left,
  String? transcript,
  String? reason,
}) => <String, dynamic>{
  'step': step, 'ahead': ahead, 'scored': scored, 'residues': residues,
  'left': left, 'elapsed': elapsed, 'transcript': transcript, 'reason': reason,
};

Map<String, dynamic> _constraint(String state) => <String, dynamic>{
  'constraint': <String, dynamic>{'state': state},
};

/// The search screen on a router whose walk is a line naming the slug it
/// opened, so a test can see where a tap went, with the builds the app's,
/// above the router, as `core/di` provides them.
Future<GoRouter> _pump(WidgetTester tester, ResolverApi api) async {
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(CatalogApi(), null);
  await catalog.refresh();
  addTearDown(catalog.dispose);
  final ProteinResolver resolver = ProteinResolver(api);
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/gene/:slug',
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: Text('walk ${state.pathParameters['slug']}')),
      ),
      GoRoute(
        path: '/elsewhere',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('elsewhere')),
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
          create: (BuildContext context) => ProteinBuilds(resolver),
          dispose: (ProteinBuilds builds) => builds.dispose(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Type, wait out the pause, and let the answer land.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.pump(_pause);
  await tester.pump();
}

Finder _tile(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byType(SuggestionTile),
);

Finder _inTile(String title, Finder finder) =>
    find.descendant(of: _tile(title), matching: finder);

Finder _card(String gene) => find.byKey(ValueKey<String>('build-$gene'));

Finder _inCard(String gene, Finder finder) =>
    find.descendant(of: _card(gene), matching: finder);

/// Answers in turn, the last one for as long as it is asked.
Future<Map<String, dynamic>> Function(String) _inTurn(
  List<Map<String, dynamic>> answers,
) =>
    (String key) async => answers.length > 1 ? answers.removeAt(0) : answers.single;

void main() {
  testWidgets('the curated list and every other protein are told apart', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(suggest: _finding(<Map<String, dynamic>>[_insulin, _insr]));
    await _pump(tester, api);
    // Before anything is typed: the twenty, under their own name.
    expect(find.text('CURATED'), findsOneWidget);
    expect(find.text('EVERY REVIEWED HUMAN PROTEIN'), findsNothing);

    await _type(tester, 'ins');
    expect(find.text('CURATED'), findsOneWidget);
    expect(find.text('EVERY REVIEWED HUMAN PROTEIN'), findsOneWidget);
    expect(find.textContaining(_release), findsOneWidget);
    // Insulin is on the curated list already, so it is not offered twice.
    expect(find.widgetWithText(ProteinCard, 'Insulin'), findsOneWidget);
    expect(_tile('Insulin'), findsNothing);
    expect(_tile('Insulin receptor'), findsOneWidget);
    expect(_inTile('Insulin receptor', find.text('P06213 · 1,382 aa')), findsOneWidget);
    expect(_inTile('Insulin receptor', find.text('Not built yet')), findsOneWidget);
    expect(api.calls, <String>['GET /proteins/suggest?q=ins']);
  });

  testWidgets('a build is pinned, told step by step, and opened when scored', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_insr, _brca1]),
      resolve: (String gene) async => _said(
        'pending', slug: 'brca1', build: _report('queued', 0.2, ahead: 1)),
      status: _inTurn(<Map<String, dynamic>>[
        _said('pending', slug: 'brca1', build: _report('record', 31.0)),
        _said('ready', slug: 'brca1',
            build: _report('scoring', 35.0, ahead: 0, transcript: 'NM_007294.4')),
        _said('ready', slug: 'brca1',
            build: _report('scoring', 50.0, transcript: 'NM_007294.4')),
        _said('ready', slug: 'brca1', build: _report('scoring', 331.0,
            scored: 450, residues: 1863, left: 245.0, transcript: 'NM_007294.4')),
        _said('ready', slug: 'brca1', build: _report('check', 900.0,
            scored: 1863, residues: 1863, left: 0.0, transcript: 'NM_007294.4')),
        _said('ready', slug: 'brca1', build: _report('done', 905.0,
            scored: 1863, residues: 1863, transcript: 'NM_007294.4')),
      ]),
    );
    await _pump(tester, api);
    await _type(tester, 'brca1');
    expect(find.text('Nothing here for "brca1"'), findsNothing);

    await tester.tap(_inTile('Breast cancer type 1 susceptibility protein', find.text('Build')));
    await tester.pump();
    await tester.pump();
    // Pinned above everything, and no longer in the list below.
    expect(find.text('BUILDING'), findsOneWidget);
    expect(_tile('Breast cancer type 1 susceptibility protein'), findsNothing);
    expect(_tile('Insulin receptor'), findsOneWidget);
    expect(_inCard('BRCA1', find.text('P38398 · 1,863 aa')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Queued')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('1 protein ahead')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Asked 0 s ago')), findsOneWidget);

    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('1 protein ahead')), findsNothing);
    expect(_inCard('BRCA1', find.text('Asked 31 s ago')), findsOneWidget);
    // Its row is there: the record is done, and the walk is not opened yet.
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('NM_007294.4')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Next')), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('Loading the model')), findsOneWidget);
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('450 / 1,863')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('4 min left')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Asked 5 min ago')), findsOneWidget);
    final LinearProgressIndicator bar = tester.widget(
      _inCard('BRCA1', find.byType(LinearProgressIndicator)),
    );
    expect(bar.semanticsLabel, 'ESM-2, 450 of 1863 residues scored');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      tester.widget<LinearProgressIndicator>(
        _inCard('BRCA1', find.byType(LinearProgressIndicator)),
      ).value,
      closeTo(450 / 1863, 1e-9),
    );
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.byType(LinearProgressIndicator)), findsNothing);
    expect(_inCard('BRCA1', find.text('Alignment check')), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('Built in 15 min')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Queued')), findsNothing);
    await tester.tap(_inCard('BRCA1', find.text('Open')));
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsOneWidget);
    expect(api.calls, <String>[
      'GET /proteins/suggest?q=brca1',
      'POST /proteins/resolve BRCA1',
      for (int i = 0; i < 6; i++) 'GET /proteins/resolve/BRCA1',
    ]);
  });

  testWidgets('opened, it leaves the top and opens from its row', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => _said('ready', slug: 'brca1',
          build: _report('done', 600.0, scored: 1863, residues: 1863)),
    );
    final GoRouter router = await _pump(tester, api);
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    await tester.tap(_inCard('BRCA1', find.text('Open')));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('BUILDING'), findsNothing);
    expect(_inTile('Breast cancer type 1 susceptibility protein', find.text('Built on demand')),
        findsOneWidget);
    await tester.tap(_tile('Breast cancer type 1 susceptibility protein'));
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsOneWidget);
  });

  testWidgets('a build stays pinned whatever is typed, and outlives search', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: (String q) async =>
          _finding(<Map<String, dynamic>>[if (q == 'brca1') _brca1 else _insr])(q),
      resolve: (String gene) async => _said('pending', slug: 'brca1',
          build: _report('queued', 0.0, ahead: 0)),
      status: _inTurn(<Map<String, dynamic>>[
        _said('ready', slug: 'brca1', build: _report('scoring', 120.0,
            scored: 100, residues: 1863, left: 2000.0)),
        _said('ready', slug: 'brca1', build: _report('scoring', 300.0,
            scored: 400, residues: 1863, left: 1100.0)),
      ]),
    );
    final GoRouter router = await _pump(tester, api);
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();

    await _type(tester, 'insr');
    expect(_card('BRCA1'), findsOneWidget);
    expect(_tile('Insulin receptor'), findsOneWidget);

    // Away from search, the build goes on being asked about.
    unawaited(router.push('/elsewhere'));
    await tester.pumpAndSettle();
    await tester.pump(_tick);
    await tester.pump(_tick);
    router.pop();
    await tester.pumpAndSettle();
    expect(_inCard('BRCA1', find.text('400 / 1,863')), findsOneWidget);
  });

  testWidgets('a build search finds under way is watched, not opened', (
    WidgetTester tester,
  ) async {
    // B2M's row is written, so it reads as ready; its ESM-2 track is not.
    final Map<String, dynamic> b2m = _suggestion(
      'P61769', 'B2M', 'Beta-2-microglobulin', 119, 'ready', slug: 'b2m', building: true);
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[b2m]),
      status: (String gene) async => _said('ready', slug: 'b2m',
          build: _report('scoring', 20.0, scored: 50, residues: 119, left: 6.0)),
    );
    await _pump(tester, api);
    await _type(tester, 'b2m');
    await tester.pump();
    expect(_tile('Beta-2-microglobulin'), findsNothing);
    expect(_inCard('B2M', find.text('50 / 119')), findsOneWidget);
    expect(_inCard('B2M', find.text('< 1 min left')), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    expect(api.calls, <String>['GET /proteins/suggest?q=b2m', 'GET /proteins/resolve/B2M']);
  });

  testWidgets('ESM-2 scores declined open unscored, and the check says why', (
    WidgetTester tester,
  ) async {
    const String gate =
        'ESM-2 prefers the residue that is there to the one before it 37.9% of the time, '
        'and to the one after it 37.9%. The scores are not drawn.';
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => _said('ready', slug: 'brca1', build: _report(
          'check', 40.0, scored: 1863, residues: 1863, transcript: 'NM_007294.4',
          reason: gate)),
    );
    await _pump(tester, api);
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    expect(_inCard('BRCA1', find.text(gate)), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Built in 40 s')), findsOneWidget);
    await tester.tap(_inCard('BRCA1', find.text('Open')));
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsOneWidget);
  });

  testWidgets('a request the resolver declined says why at its record', (
    WidgetTester tester,
  ) async {
    const String why = "The record's protein is 111 residues long; UniProt A2JGV3 is 58.";
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => _said('pending', slug: 'brca1',
          build: _report('queued', 0.0, ahead: 0)),
      status: (String gene) async => _said('refused', reason: why,
          build: _report('record', 4.0)),
    );
    await _pump(tester, api);
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text(why)), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a service without the report builds as before: one line, then Open', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => _said('pending', slug: 'brca1'),
      status: _inTurn(<Map<String, dynamic>>[
        _said('pending', slug: 'brca1'),
        _said('ready', slug: 'brca1'),
      ]),
      tracks: _inTurn(<Map<String, dynamic>>[_constraint('pending'), _constraint('ready')]),
    );
    await _pump(tester, api);
    await _type(tester, 'brca1');

    await tester.tap(_inTile('Breast cancer type 1 susceptibility protein', find.text('Build')));
    await tester.pump();
    expect(_inCard('BRCA1', find.text('Building')), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('Building')), findsOneWidget);
    await tester.pump(_tick);
    // The row is there; the walk is not opened until ESM-2 has scored it.
    expect(_inCard('BRCA1', find.text('Building')), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('Built, ready to walk')), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsOneWidget);
    // Its state each time, and once it has a row, its track as well.
    expect(api.calls, <String>[
      'GET /proteins/suggest?q=brca1',
      'POST /proteins/resolve BRCA1',
      'GET /proteins/resolve/BRCA1',
      'GET /proteins/resolve/BRCA1',
      'GET /protein/brca1/tracks',
      'GET /proteins/resolve/BRCA1',
      'GET /protein/brca1/tracks',
    ]);
  });

  testWidgets('a protein built earlier, or curated under another name, opens at once', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> hemoglobin = _suggestion(
      'P68871', 'HBB', 'Hemoglobin subunit beta', 147, 'listed',
      slug: 'hemoglobin', display: 'Hemoglobin (beta chain)');
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_b2m, hemoglobin]),
    );
    await _pump(tester, api);
    // Matches no curated name, so the curated protein is found only below.
    await _type(tester, 'beta-glob');
    expect(find.byType(ProteinCard), findsNothing);
    expect(_inTile('Hemoglobin (beta chain)', find.text('Curated walk')), findsOneWidget);
    expect(_inTile('Beta-2-microglobulin', find.text('Built on demand')), findsOneWidget);

    await tester.tap(_tile('Hemoglobin (beta chain)'));
    await tester.pumpAndSettle();
    expect(find.text('walk hemoglobin'), findsOneWidget);
  });

  testWidgets('a protein that cannot be built says why and offers no build', (
    WidgetTester tester,
  ) async {
    await _pump(tester, ResolverApi(suggest: _finding(<Map<String, dynamic>>[_tp53bp2])));
    await _type(tester, 'tp53bp');
    expect(_inTile('Apoptosis-stimulating of p53 protein 2', find.text(_isoform)), findsOneWidget);
    expect(find.text('Build'), findsNothing);
  });

  testWidgets("a day's builds taken is said on its card", (WidgetTester tester) async {
    await _pump(
      tester,
      ResolverApi(
        suggest: _finding(<Map<String, dynamic>>[_brca1]),
        resolve: (String gene) async => throw const ServerApiException(
          statusCode: 429,
          detail: "The service builds 50 proteins a day, and today's are taken. "
              'Ask again tomorrow.',
        ),
      ),
    );
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    expect(_inCard('BRCA1', find.textContaining("today's are taken")), findsOneWidget);
    expect(find.text('Build'), findsNothing);
  });

  testWidgets('a service that does not answer leaves the curated list, and a retry', (
    WidgetTester tester,
  ) async {
    int asked = 0;
    await _pump(
      tester,
      ResolverApi(
        suggest: (String q) async {
          asked++;
          if (asked == 1) {
            throw const NetworkApiException();
          }
          return _finding(<Map<String, dynamic>>[_insr])(q);
        },
      ),
    );
    await _type(tester, 'ins');
    expect(find.widgetWithText(ProteinCard, 'Insulin'), findsOneWidget);
    expect(find.text(const NetworkApiException().userMessage), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(_tile('Insulin receptor'), findsOneWidget);
    expect(find.text(const NetworkApiException().userMessage), findsNothing);
  });

  testWidgets('one letter asks the service nothing, and says to type more', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi();
    await _pump(tester, api);
    // A character no curated name or summary holds: any letter is somewhere
    // in one of the summaries, which the curated search reads too.
    await _type(tester, '#');
    expect(api.calls, isEmpty);
    expect(find.text('Nothing here for "#"'), findsOneWidget);
    expect(find.textContaining('Type more to look through every reviewed human protein'),
        findsOneWidget);
  });
}
