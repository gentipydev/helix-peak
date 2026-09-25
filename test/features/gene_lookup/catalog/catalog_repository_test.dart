import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/di/dependencies.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/mock_api_client.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/catalog_local_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/search/presentation/widgets/protein_card.dart';

/// Captured from the deployed service, and kept in the shape it arrived in.
///
/// It matters that this is a real response rather than one written to suit the
/// client: the rows come back ordered by slug rather than in reading order, and
/// `record` is `absent` for all twenty because a GenBank record is fetched live
/// and is never a blob. Both are things the client has to get right rather than
/// things it would have thought to fake.
///
/// Re-captured after the four families were uploaded, so the blob tracks now say
/// `ready`. The rows `absent` is tested against below are made by editing a copy
/// of this one, which is the honest way round: a fixture frozen before an upload
/// would keep passing a test about a service that has moved on.
Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows() => <Map<String, dynamic>>[
  for (final Object? row in _fixture()['proteins'] as List<dynamic>)
    row! as Map<String, dynamic>,
];

/// The captured page with [kinds] knocked back to `absent` on every row: the
/// service before that family was uploaded, or after a bake was withdrawn.
Map<String, dynamic> _withoutTracks(String kind, [String? also]) {
  final Map<String, dynamic> page = _fixture();
  for (final Object? row in page['proteins'] as List<dynamic>) {
    final Map<String, dynamic> tracks =
        (row! as Map<String, dynamic>)['tracks'] as Map<String, dynamic>;
    tracks[kind] = 'absent';
    if (also != null) {
      tracks[also] = 'absent';
    }
  }
  return page;
}

/// Serves prepared pages, then fails the way the service fails.
class _Client implements ApiClient {
  _Client(this.pages, {this.error});

  final List<Map<String, dynamic>> pages;
  final ApiException? error;
  final List<Map<String, dynamic>?> asked = <Map<String, dynamic>?>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    expect(path, '/catalog');
    asked.add(query);
    final ApiException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return pages[asked.length - 1];
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) => throw UnimplementedError();
}

/// No cache: there is no documents directory under `flutter test`, and only
/// the one test below is about what happens when it is asked for anyway.
ProteinCatalogRepository _repository(_Client client) =>
    ProteinCatalogRepository(client, null);

void main() {
  test('the service serves the catalog in an order nobody reads it in', () {
    // Without this the ordering test below could pass by accident. The service
    // pages by slug and so must order by slug; the reading order travels as
    // `catalog_order` instead.
    final List<String> served = <String>[
      for (final Map<String, dynamic> row in _rows()) row['slug'] as String,
    ];
    expect(served.first, 'amylase');
    expect(served, isNot(<String>[
      for (final ProteinTarget target in ProteinCatalog.all) target.slug,
    ]));
  });

  test('a refreshed repository carries the twenty the bundle does', () async {
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[_fixture()]),
    );
    await catalog.refresh();

    // Slug and reading order, restored from `catalog_order`.
    expect(catalog.all, ProteinCatalog.all);

    // These rows came off the wire. Without this the assertion above passes
    // just as well when every row was rejected and the seed was kept — which
    // is exactly what happened the first time this test was written.
    expect(identical(catalog.all, ProteinCatalog.all), isFalse);
    expect(
      identical(catalog.bySlug('insulin'), ProteinCatalog.insulin),
      isFalse,
    );

    // Equality is slug-only, so the fields have to be checked by hand or the
    // line above would pass on twenty empty rows with the right names.
    for (final ProteinTarget want in ProteinCatalog.all) {
      final ProteinTarget got = catalog.bySlug(want.slug)!;
      final String where = want.slug;
      expect(got.display, want.display, reason: where);
      expect(got.gene, want.gene, reason: where);
      expect(got.uniprot, want.uniprot, reason: where);
      expect(got.accession, want.accession, reason: where);
      expect(got.summary, want.summary, reason: where);
      expect(got.chain, want.chain, reason: where);
      expect(got.facts.residues, want.facts.residues, reason: where);
      expect(got.facts.exons, want.facts.exons, reason: where);
      expect(got.facts.chains, want.facts.chains, reason: where);
      expect(got.facts.bridges, want.facts.bridges, reason: where);
    }
  });

  test('a family that has moved answers from the state the service reports',
      () async {
    // Phase 4a retired `scored` and `impactScored` into the track states, so
    // these two are now the service's word and not the bundle's.
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[_fixture()]),
    );
    await catalog.refresh();

    for (final ProteinTarget got in catalog.all) {
      expect(got.state(TrackKind.constraint), TrackState.ready, reason: got.slug);
      expect(got.scored, isTrue, reason: got.slug);
      expect(got.impactScored, isTrue, reason: got.slug);
    }

    final ProteinCatalogRepository silent = _repository(
      _Client(<Map<String, dynamic>>[_withoutTracks('constraint', 'impact')]),
    );
    await silent.refresh();
    final ProteinTarget insulin = silent.bySlug('insulin')!;
    expect(insulin.state(TrackKind.constraint), TrackState.absent);
    // The page then draws what it draws for a protein nobody has scored: no
    // toolbar, and a tap that follows the tracer. Not an error.
    expect(insulin.scored, isFalse);
    expect(insulin.impactScored, isFalse);
  });

  test('a family still bundled is drawn even where the service says absent',
      () async {
    // The other half of the retirement, and the half that has not happened.
    // Until ClinVar's blobs are what the walk reads, the bundled seed is the
    // only honest authority on whether this build has a snapshot — deriving
    // `clinvarAvailable` from an `absent` row would take the marks off all
    // twenty at once, which is the trap Phase 4b has to walk past deliberately.
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[
        _withoutTracks('clinvar', 'impact_explanations'),
      ]),
    );
    await catalog.refresh();

    for (final ProteinTarget want in ProteinCatalog.all) {
      final ProteinTarget got = catalog.bySlug(want.slug)!;
      expect(got.state(TrackKind.clinvar), TrackState.absent, reason: want.slug);
      expect(got.clinvarAvailable, want.clinvarAvailable, reason: want.slug);
      expect(
        got.impactExplanationsAvailable,
        want.impactExplanationsAvailable,
        reason: want.slug,
      );
    }
  });

  test('what the service does say about a track is carried', () async {
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[_fixture()]),
    );
    await catalog.refresh();

    // Three genes have their explanations uploaded; the rest do not.
    expect(
      catalog.bySlug('insulin')!.state(TrackKind.impactExplanations),
      TrackState.ready,
    );
    expect(
      catalog.bySlug('p53')!.state(TrackKind.impactExplanations),
      TrackState.absent,
    );
    expect(catalog.bySlug('insulin')!.reason(TrackKind.constraint), isNull);
  });

  test('search, bySlug and byPath answer as the const catalog did', () async {
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[_fixture()]),
    );
    await catalog.refresh();

    for (final String query in <String>[
      'p01308',
      'NG_012232',
      'TP53',
      'tp53',
      'hormone',
      'insulin',
      'hemo',
      'nothing here',
    ]) {
      expect(
        catalog.matching(query),
        ProteinCatalog.matching(query),
        reason: query,
      );
    }
    expect(catalog.bySlug('cftr'), ProteinCatalog.bySlug('cftr'));
    expect(catalog.bySlug('nonesuch'), isNull);
    expect(
      catalog.byPath('NG_007114', 'INS'),
      ProteinCatalog.byPath('NG_007114', 'INS'),
    );
    expect(catalog.byPath('NG_007114', 'TP53'), isNull);
    expect(catalog.fallback.slug, ProteinCatalog.fallback.slug);
  });

  test('an empty query is the list itself, not a copy of it', () async {
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[_fixture()]),
    );
    await catalog.refresh();
    expect(catalog.matching(''), same(catalog.all));
    expect(catalog.matching('   '), same(catalog.all));
  });

  test('it answers before anything has been fetched', () {
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[]),
    );
    // The router and the search screen read this on the first frame.
    expect(catalog.all, ProteinCatalog.all);
    expect(catalog.bySlug('insulin'), isNotNull);
    expect(catalog.fallback.slug, 'insulin');
  });

  test('a service that cannot answer leaves the rows alone', () async {
    for (final ApiException failure in <ApiException>[
      const ServerApiException(statusCode: 503, detail: 'No catalog database.'),
      const NetworkApiException(),
      const TimeoutApiException(),
    ]) {
      final ProteinCatalogRepository catalog = _repository(
        _Client(<Map<String, dynamic>>[], error: failure),
      );
      await catalog.refresh();
      // Never an empty screen, and never "no such protein".
      expect(catalog.all, ProteinCatalog.all, reason: '$failure');
      expect(catalog.bySlug('dystrophin'), isNotNull, reason: '$failure');
    }
  });

  test('an empty catalog is not adopted', () async {
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[
        <String, dynamic>{'proteins': <dynamic>[], 'next': null},
      ]),
    );
    await catalog.refresh();
    expect(catalog.all, ProteinCatalog.all);
  });

  test('a catalog page carries no fold prose, so the bundle keeps it', () async {
    // `/catalog` serves nine keys: no `structure`, no `chains`, no `chain`.
    // The fold page's copy is hand-written per protein and stays in the seed
    // until the detail route is asked for it.
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[_fixture()]),
    );
    await catalog.refresh();

    final ProteinTarget insulin = catalog.bySlug('insulin')!;
    expect(insulin.structure.pdb, '3I40');
    expect(insulin.structure.count, ProteinCatalog.insulin.structure.count);
    expect(insulin.structure.sentence, ProteinCatalog.insulin.structure.sentence);
    expect(
      <String>[for (final StructureChain c in insulin.chains) c.node],
      <String>['chainA', 'chainB', 'bonds'],
    );
    expect(insulin.chains.first.tint, ChainTint.mature3);
    // p53's modelled span is the thing the fold page says "of 393" about.
    expect(catalog.bySlug('p53')!.structure.modelled, (96, 289));
    expect(catalog.bySlug('hemoglobin')!.chain, 'hemoglobin beta chain');
  });

  test('a detail row is read in preference to the bundled one', () async {
    // What the resolver will serve, and the shape `/protein/{slug}` already
    // has today.
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[
        <String, dynamic>{
          'proteins': <Map<String, dynamic>>[
            for (final Map<String, dynamic> row in _rows())
              if (row['slug'] == 'insulin')
                <String, dynamic>{
                  ...row,
                  'chain': 'a chain the service named',
                  'chains': <Map<String, dynamic>>[
                    <String, dynamic>{'node': 'chainA', 'tint': 'mature2'},
                  ],
                  'structure': <String, dynamic>{
                    'pdb': '9XYZ',
                    'modelled': <int>[3, 7],
                    'label': 'the served label',
                    'count': 42,
                    'unit': 'residues',
                    'sentence': 'Served.',
                    'semantics': 'Served semantics.',
                  },
                }
              else
                row,
          ],
          'next': null,
        },
      ]),
    );
    await catalog.refresh();

    final ProteinTarget insulin = catalog.bySlug('insulin')!;
    expect(insulin.structure.pdb, '9XYZ');
    expect(insulin.structure.modelled, (3, 7));
    expect(insulin.chain, 'a chain the service named');
    expect(insulin.chains.single.tint, ChainTint.mature2);
  });

  test('a protein with no structure anywhere is left out', () async {
    // A row the bundle has never heard of and no entry passed the picker for.
    // The fold page has no drawing for its absence, so the catalog declines to
    // carry it rather than opening a walk that cannot finish.
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[
        <String, dynamic>{
          'proteins': <Map<String, dynamic>>[
            ..._rows(),
            <String, dynamic>{
              'slug': 'nonesuch',
              'display': 'Nonesuch',
              'gene': 'NONE',
              'uniprot': 'P00000',
              'accession': 'NG_000000',
              'summary': 'Resolved, but no entry covers its mature chain.',
              'facts': <String, dynamic>{
                'residues': 100,
                'exons': 2,
                'chains': 1,
                'bridges': 0,
              },
              'catalog_order': null,
              'tracks': <String, dynamic>{'structure': 'refused'},
            },
          ],
          'next': null,
        },
      ]),
    );
    await catalog.refresh();

    expect(catalog.bySlug('nonesuch'), isNull);
    expect(catalog.all, ProteinCatalog.all);
  });

  test('it follows the cursor until the service stops giving one', () async {
    final List<Map<String, dynamic>> rows = _rows();
    final _Client client = _Client(<Map<String, dynamic>>[
      <String, dynamic>{
        'proteins': rows.sublist(0, 12),
        'next': rows[11]['slug'],
      },
      <String, dynamic>{'proteins': rows.sublist(12), 'next': null},
    ]);
    final ProteinCatalogRepository catalog = _repository(client);
    await catalog.refresh();

    expect(client.asked, hasLength(2));
    expect(client.asked.first!['cursor'], isNull);
    expect(client.asked.last!['cursor'], rows[11]['slug']);
    expect(catalog.all, ProteinCatalog.all);
  });

  test('a cursor that stops advancing does not page forever', () async {
    final List<Map<String, dynamic>> rows = _rows();
    final _Client client = _Client(<Map<String, dynamic>>[
      for (int page = 0; page < 60; page++)
        <String, dynamic>{'proteins': rows, 'next': 'stuck'},
    ]);
    await _repository(client).refresh();
    expect(client.asked.length, lessThanOrEqualTo(50));
  });

  test('load works where there is no documents directory', () async {
    // There is none under `flutter test`: `path_provider` has no plugin to
    // answer it, so both cache calls fail. The rows still arrive — the cache is
    // a head start, never a dependency. The two lines it prints are the point.
    final ProteinCatalogRepository catalog = ProteinCatalogRepository(
      _Client(<Map<String, dynamic>>[_fixture()]),
      const CatalogLocalDataSource(),
    );
    await catalog.load();
    expect(catalog.all, ProteinCatalog.all);
  });

  test('a refresh that changes the rows notifies', () async {
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[_fixture()]),
    );
    int told = 0;
    catalog.rows.addListener(() => told++);
    await catalog.refresh();
    expect(told, 1);
  });

  test('the repository itself is not a Listenable', () {
    // A `RepositoryProvider` is a plain `Provider`, and `provider` asserts on
    // a Listenable put in one — it would never rebuild what read it. The rows
    // are the thing that changes, so the rows are what listens.
    final ProteinCatalogRepository catalog = _repository(
      _Client(<Map<String, dynamic>>[]),
    );
    expect(catalog, isNot(isA<Listenable>()));
    expect(catalog.rows, isA<Listenable>());
  });

  testWidgets('the app graph resolves and the search screen reads it', (
    WidgetTester tester,
  ) async {
    // Nothing else covers this: every other widget test pumps its screen
    // without providers. The first version of this wiring put the repository
    // in a `RepositoryProvider` while it was still a `ChangeNotifier`, which
    // `provider` asserts on — the app crashed on the first read, and only a
    // real graph showed it.
    await tester.binding.setSurfaceSize(const Size(400, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    ProteinCatalogRepository? seen;
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: buildAppProviders(),
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              seen = context.read<ProteinCatalogRepository>();
              return const SearchScreen();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(seen, isNotNull);
    expect(seen!.all, hasLength(ProteinCatalog.all.length));
    expect(find.byType(ProteinCard), findsNWidgets(ProteinCatalog.all.length));
    expect(find.text('Insulin'), findsOneWidget);
    expect(find.text('Dystrophin'), findsOneWidget);
  });

  test('the mock build fills its catalog from the fixture server', () async {
    // `USE_MOCK_DATA=true` swaps one line of the graph, and everything above
    // it stays production code. That only holds if the fixture server answers
    // the catalog routes too.
    final ProteinCatalogRepository catalog = ProteinCatalogRepository(
      MockApiClient(latency: Duration.zero),
      null,
    );
    await catalog.refresh();

    expect(identical(catalog.all, ProteinCatalog.all), isFalse);
    expect(catalog.all, ProteinCatalog.all);
    expect(catalog.bySlug('insulin')!.structure.pdb, '3I40');
    expect(catalog.bySlug('p53')!.structure.modelled, (96, 289));
    // The fixture server answers for the build it stands in for, where every
    // bundled family is there to be read.
    expect(
      catalog.bySlug('insulin')!.state(TrackKind.clinvar),
      TrackState.ready,
    );
    expect(
      catalog.bySlug('p53')!.state(TrackKind.impactExplanations),
      TrackState.absent,
    );
  });

  test('the fixture server answers the detail and track routes', () async {
    final MockApiClient server = MockApiClient(latency: Duration.zero);

    final Map<String, dynamic> detail = await server.getJson('/protein/cftr');
    expect(detail['display'], 'CFTR');
    expect(detail['chain'], isNotNull);
    expect((detail['structure']! as Map<String, dynamic>)['pdb'], isNotNull);

    final Map<String, dynamic> tracks = await server.getJson(
      '/protein/cftr/tracks',
    );
    expect(
      tracks.keys.toSet(),
      <String>{for (final TrackKind k in TrackKind.values) k.wire},
    );

    final Map<String, dynamic> found = await server.getJson(
      '/catalog/search',
      query: <String, dynamic>{'q': 'TP53'},
    );
    expect((found['proteins']! as List<dynamic>).single, isA<Map<String, dynamic>>());
    expect(found['candidates'], isEmpty);

    // Verbatim from the backend's router, so `userMessage` reads the same.
    await expectLater(
      server.getJson('/protein/nonesuch'),
      throwsA(
        isA<ServerApiException>().having(
          (ServerApiException e) => e.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
    await expectLater(
      server.getJson('/nowhere'),
      throwsA(isA<ServerApiException>()),
    );
  });
}
