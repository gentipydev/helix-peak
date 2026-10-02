import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';

import '../../features/search/support/resolver_api.dart';

/// `/proteins/suggest` as the backend's `test_suggest.py` pins its rows.
Map<String, dynamic> _page() => <String, dynamic>{
  'q': 'ins',
  'release': 'UniProt 2026_03 · MANE v1.5',
  'suggestions': <Object?>[
    <String, dynamic>{
      'uniprot': 'P01308', 'gene': 'INS', 'name': 'Insulin', 'display': 'Insulin',
      'length': 110, 'slug': 'insulin', 'status': 'listed', 'reason': null,
    },
    <String, dynamic>{
      'uniprot': 'P06213', 'gene': 'INSR', 'name': 'Insulin receptor', 'display': null,
      'length': 1382, 'slug': 'insr', 'status': 'buildable', 'reason': null,
    },
    <String, dynamic>{
      'uniprot': 'Q13625', 'gene': 'TP53BP2',
      'name': 'Apoptosis-stimulating of p53 protein 2', 'display': null,
      'length': 1128, 'slug': null, 'status': 'unavailable',
      'reason': 'MANE Select encodes isoform Q13625-3, and UniProt numbers its '
          'features on the canonical sequence.',
    },
  ],
};

void main() {
  test('a page of suggestions reads every field the service sends', () {
    final SuggestionPage page = SuggestionPage.fromJson(_page());
    expect(page.query, 'ins');
    expect(page.release, 'UniProt 2026_03 · MANE v1.5');
    expect(
      <(String, String?, SuggestionStatus, String?)>[
        for (final ProteinSuggestion s in page.suggestions)
          (s.title, s.slug, s.status, s.gene),
      ],
      <(String, String?, SuggestionStatus, String?)>[
        ('Insulin', 'insulin', SuggestionStatus.listed, 'INS'),
        ('Insulin receptor', 'insr', SuggestionStatus.buildable, 'INSR'),
        ('Apoptosis-stimulating of p53 protein 2', null, SuggestionStatus.unavailable, 'TP53BP2'),
      ],
    );
    expect(page.suggestions[1].length, 1382);
    expect(page.suggestions[2].reason, startsWith('MANE Select encodes isoform'));
  });

  test('a status this build does not know is one it cannot offer', () {
    expect(SuggestionStatus.fromWire('teleported'), SuggestionStatus.unavailable);
    expect(SuggestionStatus.fromWire(null), SuggestionStatus.unavailable);
    expect(ResolveState.fromWire('teleported'), ResolveState.failed);
  });

  test('a resolve answer reads its state, slug and reason', () {
    final ResolveStatus pending = ResolveStatus.fromJson(
      <String, dynamic>{'slug': 'brca1', 'state': 'pending', 'reason': null},
    );
    expect((pending.state, pending.slug, pending.reason), (ResolveState.pending, 'brca1', null));
    final ResolveStatus refused = ResolveStatus.fromJson(
      <String, dynamic>{'slug': null, 'state': 'refused', 'reason': 'Too long.'},
    );
    expect((refused.state, refused.reason), (ResolveState.refused, 'Too long.'));
  });

  test('the resolver asks the service what the backend serves', () async {
    final ResolverApi api = ResolverApi(
      suggest: (String q) async => _page(),
      resolve: (String gene) async =>
          <String, dynamic>{'slug': 'brca1', 'state': 'pending', 'reason': null},
      status: (String gene) async =>
          <String, dynamic>{'slug': 'brca1', 'state': 'ready', 'reason': null},
      tracks: (String slug) async => <String, dynamic>{
        'record': <String, dynamic>{'state': 'ready'},
        'constraint': <String, dynamic>{'state': 'pending'},
      },
    );
    final ProteinResolver resolver = ProteinResolver(api);

    expect((await resolver.suggest('ins')).suggestions, hasLength(3));
    expect((await resolver.request('BRCA1')).state, ResolveState.pending);
    expect((await resolver.status('HLA-A')).state, ResolveState.ready);
    expect(await resolver.trackState('brca1', TrackKind.constraint), TrackState.pending);
    // A kind the service has no row for reads as absent, as the walk reads it.
    expect(await resolver.trackState('brca1', TrackKind.clinvar), TrackState.absent);
    expect(api.calls, <String>[
      'GET /proteins/suggest?q=ins',
      'POST /proteins/resolve BRCA1',
      'GET /proteins/resolve/HLA-A',
      'GET /protein/brca1/tracks',
      'GET /protein/brca1/tracks',
    ]);
  });
}
