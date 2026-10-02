import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
}) => <String, dynamic>{
  'uniprot': uniprot, 'gene': gene, 'name': name, 'display': display,
  'length': length, 'slug': slug, 'status': status, 'reason': reason,
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

Map<String, dynamic> _said(String state, {String? slug, String? reason}) =>
    <String, dynamic>{'slug': slug, 'state': state, 'reason': reason};

Map<String, dynamic> _constraint(String state) => <String, dynamic>{
  'constraint': <String, dynamic>{'state': state},
};

/// The search screen on a router whose walk is a line naming the slug it
/// opened, so a test can see where a tap went.
Future<void> _pump(WidgetTester tester, ResolverApi api) async {
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(CatalogApi(), null);
  await catalog.refresh();
  addTearDown(catalog.dispose);
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
    ],
  );
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(400, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<ProteinResolver>.value(value: ProteinResolver(api)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
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

  testWidgets('a protein is built from its row in the list, then opened', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> resolving = <Map<String, dynamic>>[
      _said('pending', slug: 'brca1'),
      _said('ready', slug: 'brca1'),
    ];
    final List<Map<String, dynamic>> scoring = <Map<String, dynamic>>[
      _constraint('pending'),
      _constraint('ready'),
    ];
    final ResolverApi api = ResolverApi(
      suggest: _finding(<Map<String, dynamic>>[_brca1]),
      resolve: (String gene) async => _said('pending', slug: 'brca1'),
      status: (String gene) async => resolving.removeAt(0),
      tracks: (String slug) async => scoring.removeAt(0),
    );
    await _pump(tester, api);
    await _type(tester, 'brca1');
    expect(find.text('Nothing here for "brca1"'), findsNothing);

    await tester.tap(_inTile('Breast cancer type 1 susceptibility protein', find.text('Build')));
    await tester.pump();
    expect(find.text('Building its gene record'), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    await tester.pump(_tick);
    expect(find.text('Building its gene record'), findsOneWidget);
    await tester.pump(_tick);
    // The row is there; the walk is not opened until ESM-2 has scored it.
    expect(find.text('Scoring every residue with ESM-2'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    await tester.pump(_tick);
    expect(find.text('Built, ready to walk'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsOneWidget);
    expect(api.calls, <String>[
      'GET /proteins/suggest?q=brca1',
      'POST /proteins/resolve BRCA1',
      'GET /proteins/resolve/BRCA1',
      'GET /proteins/resolve/BRCA1',
      'GET /protein/brca1/tracks',
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

  testWidgets("a day's builds taken is said on the row", (WidgetTester tester) async {
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
    expect(find.textContaining("today's are taken"), findsOneWidget);
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
