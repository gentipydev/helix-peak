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
/// above the router, as `core/di` provides them. With [asker], this phone
/// names itself when it asks, and may stop what it asked for. [size] is tall
/// by default, so the lazy list builds everything it has.
Future<GoRouter> _pump(
  WidgetTester tester,
  ResolverApi api, {
  String? asker,
  Size size = const Size(400, 4000),
}) async {
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
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<ProteinResolver>.value(value: resolver),
        RepositoryProvider<ProteinBuilds>(
          create: (BuildContext context) => ProteinBuilds(
            resolver,
            asker: asker == null ? null : () async => asker,
          ),
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

/// Whether the search field has the cursor.
bool _focused(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

/// What the search field reads.
String _typed(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

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
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester, api);
    await _type(tester, 'brca1');
    expect(find.text('Nothing here for "brca1"'), findsNothing);

    await tester.tap(_inTile('Breast cancer type 1 susceptibility protein', find.text('Build')));
    await tester.pump();
    await tester.pump();
    // Pinned above everything, and the search that found it is over: the
    // field emptied and put away, the other matches gone with it, and the
    // list back to how it opens.
    expect(find.text('BUILDING'), findsOneWidget);
    expect(_tile('Breast cancer type 1 susceptibility protein'), findsNothing);
    expect(_tile('Insulin receptor'), findsNothing);
    expect(_typed(tester), isEmpty);
    expect(_focused(tester), isFalse);
    expect(find.text('CURATED'), findsOneWidget);
    expect(_inCard('BRCA1', find.text('P38398 · 1,863 aa')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Queued')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('1 protein ahead')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('00:00 elapsed')), findsOneWidget);
    // The clock runs on between two answers.
    await tester.pump(const Duration(seconds: 2));
    expect(_inCard('BRCA1', find.text('00:02 elapsed')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(_inCard('BRCA1', find.text('1 protein ahead')), findsNothing);
    expect(_inCard('BRCA1', find.text('00:31 elapsed')), findsOneWidget);
    // Its row is there: the record is done, and the walk is not opened yet.
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('NM_007294.4')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Next')), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('Loading the model')), findsOneWidget);
    await tester.pump(_tick);
    expect(_inCard('BRCA1', find.text('450 / 1,863')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('04:05 left')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('05:31 elapsed')), findsOneWidget);
    expect(find.bySemanticsLabel('ESM-2, 450 of 1863 residues scored'), findsOneWidget);
    // Both run, the time left down: the count stays the scorer's own.
    await tester.pump(const Duration(seconds: 2));
    expect(_inCard('BRCA1', find.text('04:03 left')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('05:33 elapsed')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('450 / 1,863')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel(RegExp('residues scored')), findsNothing);
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
    semantics.dispose();
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
    // Asking for it ended the search; looked for again, it opens from its row.
    await _type(tester, 'brca1');
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

    // Away from search, the build goes on being asked about. (The card's
    // clock never settles, so the pages are given their time.)
    unawaited(router.push('/elsewhere'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(_tick);
    await tester.pump(_tick);
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_inCard('BRCA1', find.text('400 / 1,863')), findsOneWidget);
  });

  testWidgets('a build asked from far down the list shows its card at the top', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> kinases = <Map<String, dynamic>>[
      for (int i = 1; i <= 12; i++)
        _suggestion('Q9K${i.toString().padLeft(3, '0')}', 'KIN$i', 'Kinase $i', 300 + i,
            'buildable', slug: 'kin$i'),
    ];
    final ResolverApi api = ResolverApi(
      suggest: _finding(kinases),
      resolve: (String gene) async => _said('pending', build: _report('queued', 0.0, ahead: 0)),
      status: (String gene) async => _said('pending', build: _report('queued', 3.0, ahead: 0)),
    );
    await _pump(tester, api, size: const Size(400, 800));
    await _type(tester, 'kinase');
    final Finder last = _inTile('Kinase 12', find.text('Build'));
    await tester.dragUntilVisible(last, find.byType(ListView), const Offset(0, -200));
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();

    await tester.tap(last);
    await tester.pump();
    await tester.pump();
    expect(_card('KIN12').hitTestable(), findsOneWidget);
  });

  testWidgets("the card's own Try again keeps what is typed", (WidgetTester tester) async {
    final ResolverApi api = ResolverApi(
      suggest: (String q) async =>
          _finding(<Map<String, dynamic>>[if (q == 'brca1') _brca1 else _insr])(q),
      resolve: (String gene) async => throw const NetworkApiException(),
    );
    await _pump(tester, api);
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    expect(_inCard('BRCA1', find.text('Try again')), findsOneWidget);

    // A search under way is the reader's: the card asking again leaves it be.
    await _type(tester, 'insr');
    await tester.tap(_inCard('BRCA1', find.text('Try again')));
    await tester.pump();
    await tester.pump();
    expect(_typed(tester), 'insr');
    expect(_tile('Insulin receptor'), findsOneWidget);
  });

  testWidgets('a Build without a touch, as a screen reader asks, puts the field away too', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('queued', 0.0, ahead: 0)),
      status: (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('queued', 3.0, ahead: 0)),
    );
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester, api);
    await _type(tester, 'brca1');
    expect(_focused(tester), isTrue);

    // No pointer comes down outside the field: Build itself puts it away.
    tester.semantics.tap(find.semantics.byLabel('Build'));
    await tester.pump();
    await tester.pump();
    expect(_card('BRCA1'), findsOneWidget);
    expect(_typed(tester), isEmpty);
    expect(_focused(tester), isFalse);
    semantics.dispose();
  });

  testWidgets('the Search key opens the one match, built or curated, and never builds', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: (String q) async => _finding(<Map<String, dynamic>>[
        if (q == 'b2m') _b2m,
        if (q == 'brca1') _brca1,
      ])(q),
    );
    final GoRouter router = await _pump(tester, api);
    // Nothing curated, and one other protein, built on demand: it opens.
    await _type(tester, 'b2m');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('walk b2m'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    // One curated match opens, as it always has.
    await _type(tester, 'lysozyme');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('walk lysozyme'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    // One not built yet is built by its own Build alone.
    await _type(tester, 'brca1');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsNothing);
    expect(find.text('BUILDING'), findsNothing);
    expect(api.calls.where((String call) => call.startsWith('POST')), isEmpty);
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
    expect(_inCard('B2M', find.text('00:06 left')), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    // Another phone asked for it: this one may not stop it.
    expect(find.text('Stop'), findsNothing);
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

  testWidgets('the phone that asked stops a queued build, after saying so', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('queued', 0.0, ahead: 1)),
      status: (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('queued', 3.0, ahead: 1)),
      stop: (String gene) async => <String, dynamic>{
        ..._said('stopped', build: _report('queued', 12.0,
            reason: 'Stopped before it was built.')),
        'build': <String, dynamic>{
          ..._report('queued', 12.0, reason: 'Stopped before it was built.'),
          'stopped': true,
        },
      },
    );
    await _pump(tester, api, asker: 'install-a');
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    expect(api.posted.single, <String, dynamic>{'gene': 'BRCA1', 'asker': 'install-a'});

    // Kept building, on second thoughts.
    await tester.tap(_inCard('BRCA1', find.text('Stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stop BRCA1?'), findsOneWidget);
    expect(find.text('Nothing has been built yet.'), findsOneWidget);
    await tester.tap(find.text('Keep building'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stop BRCA1?'), findsNothing);
    expect(api.calls.where((String c) => c.endsWith('/stop')), isEmpty);

    await tester.tap(_inCard('BRCA1', find.text('Stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, 'Stop').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.calls.last, 'POST /proteins/resolve/BRCA1/stop');
    expect(api.posted.last, <String, dynamic>{'asker': 'install-a'});
    expect(_inCard('BRCA1', find.text('Stopped before it was built.')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Stopped after 12 s')), findsOneWidget);
    // Nothing was built, so nothing opens; Build asks again.
    expect(_inCard('BRCA1', find.text('Open')), findsNothing);
    final int asked = api.calls.length;
    await tester.pump(_tick * 3);
    expect(api.calls.length, asked);

    await tester.tap(_inCard('BRCA1', find.text('Build')));
    await tester.pump();
    await tester.pump();
    expect(api.calls[asked], 'POST /proteins/resolve BRCA1');
    expect(_inCard('BRCA1', find.text('Stop')), findsOneWidget);
  });

  testWidgets('stopped while scoring, it opens unscored, and Build scores it again', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic> scoring(double elapsed) => _said('ready', slug: 'brca1',
        build: <String, dynamic>{
          ..._report('scoring', elapsed, scored: 450, residues: 1863, left: 1100.0,
              transcript: 'NM_007294.4'),
          'ran': 330.0,
        });
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => scoring(400.0),
      status: (String gene) async => scoring(403.0),
      stop: (String gene) async => _said('stopped', slug: 'brca1', build: <String, dynamic>{
        ..._report('scoring', 410.0, scored: 450, residues: 1863,
            transcript: 'NM_007294.4', reason: 'Stopped at 450 of 1,863 residues.'),
        'stopped': true,
      }),
    );
    await _pump(tester, api, asker: 'install-a');
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();

    await tester.tap(_inCard('BRCA1', find.text('Stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('6 min of ESM-2 scoring is lost.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Stop').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_inCard('BRCA1', find.text('Stopped at 450 of 1,863 residues.')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Stopped after 7 min')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('NM_007294.4')), findsOneWidget);

    // Build again: its scoring is queued afresh, and watched.
    api.resolve = (String gene) async =>
        _said('ready', slug: 'brca1', build: _report('scoring', 0.1, ahead: 0));
    await tester.tap(_inCard('BRCA1', find.text('Build')));
    await tester.pump();
    await tester.pump();
    expect(_inCard('BRCA1', find.text('Next')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Stop')), findsOneWidget);
  });

  testWidgets('stopped while scoring, Open walks it as it is', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => _said('ready', slug: 'brca1',
          build: _report('scoring', 50.0, scored: 25, residues: 1863, left: 2000.0)),
      stop: (String gene) async => _said('stopped', slug: 'brca1', build: <String, dynamic>{
        ..._report('scoring', 60.0, scored: 25, residues: 1863,
            reason: 'Stopped at 25 of 1,863 residues.'),
        'stopped': true,
      }),
    );
    await _pump(tester, api, asker: 'install-a');
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    await tester.tap(_inCard('BRCA1', find.text('Stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, 'Stop').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(_inCard('BRCA1', find.text('Open')));
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsOneWidget);
  });

  testWidgets('a stop the service turns down is said, and the build goes on', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('queued', 0.0, ahead: 0)),
      status: (String gene) async =>
          _said('pending', slug: 'brca1', build: _report('queued', 3.0, ahead: 0)),
      stop: (String gene) async => throw const ServerApiException(
        statusCode: 409,
        detail: 'Its gene record is being written. Stop it in a moment.',
      ),
    );
    await _pump(tester, api, asker: 'install-a');
    await _type(tester, 'brca1');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    await tester.tap(_inCard('BRCA1', find.text('Stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, 'Stop').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Stop it in a moment'), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Queued')), findsOneWidget);
    expect(_inCard('BRCA1', find.text('Stop')), findsOneWidget);
  });

  testWidgets('a protein whose scoring was stopped earlier opens, and offers Build', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> stopped = <String, dynamic>{
      ..._suggestion('P38398', 'BRCA1', 'Breast cancer type 1 susceptibility protein', 1863,
          'ready', slug: 'brca1'),
      'stopped': true,
    };
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[stopped]),
      resolve: (String gene) async =>
          _said('ready', slug: 'brca1', build: _report('scoring', 0.1, ahead: 0)),
    );
    await _pump(tester, api, asker: 'install-a');
    await _type(tester, 'brca1');
    const String title = 'Breast cancer type 1 susceptibility protein';
    expect(_inTile(title, find.text('Stopped before ESM-2 finished')), findsOneWidget);
    await tester.tap(_inTile(title, find.text('Build')));
    await tester.pump();
    await tester.pump();
    expect(_inCard('BRCA1', find.text('Next')), findsOneWidget);
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
