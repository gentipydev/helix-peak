import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/gene_lookup/domain/entities/protein_catalog.dart';
import '../../features/gene_lookup/domain/entities/protein_ranking.dart';
import '../../features/gene_lookup/domain/entities/protein_target.dart';
import '../../features/gene_lookup/domain/entities/protein_track.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// An [ApiClient] that answers from bundled fixtures instead of the network.
///
/// It sits at the transport seam rather than higher up on purpose. Everything
/// above it — `GeneRemoteDataSourceImpl`, `GeneRecordDto.fromJson`, the
/// DTO→entity mappers, `GeneRepositoryImpl`, `FetchGene`, `GeneLookupCubit` and
/// the [ApiException] → user-message translation — stays the real production
/// code, running exactly as it does against the live service. Only the socket
/// is gone. A fake one layer up would skip the JSON parsing, which is most of
/// what a mock build exists to check.
///
/// It behaves like the FastAPI service, not like a stub: it round-trips before
/// answering, matches the gene exactly the way `extract_gene` does, and fails
/// with the wording the backend fails with.
final class MockApiClient implements ApiClient {
  MockApiClient({
    AssetBundle? bundle,
    this.latency = const Duration(milliseconds: 700),
  }) : _bundle = bundle ?? rootBundle;

  static final RegExp _genePath = RegExp(
    r'^/gene/([^/]+)/([^/]+)(/impact-explanations)?$',
  );

  static final RegExp _proteinPath = RegExp(r'^/protein/([^/]+)(/tracks)?$');

  final AssetBundle _bundle;

  /// How long a call takes before it answers.
  ///
  /// Not decoration: the live request goes on to NCBI and takes seconds, so
  /// `LoadingView(label: 'FETCHING NG_007114')` is part of the flow being
  /// checked. Answering instantly would make the mock build behave differently
  /// from the app it stands in for.
  final Duration latency;

  /// Read once per record, then decoded again per call.
  ///
  /// Caching the decoded map instead would hand every caller the same mutable
  /// object, where a real response is fresh bytes each time — and the callers
  /// do edit it: `anatomy_fixture.dart` builds its contrasting genes by
  /// deleting keys from a decoded payload. Dystrophin's fifty kilobytes is the
  /// largest of them, and still not worth a shared-mutable-state bug.
  final Map<String, Future<String>> _payloads = <String, Future<String>>{};

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    await Future<void>.delayed(latency);

    if (path == '/catalog') {
      return _catalog(ProteinCatalog.all);
    }
    if (path == '/catalog/search') {
      return _search(query?['q'] as String? ?? '');
    }

    final RegExpMatch? protein = _proteinPath.firstMatch(path);
    if (protein != null) {
      return _protein(protein.group(1)!, tracksOnly: protein.group(2) != null);
    }

    final RegExpMatch? match = _genePath.firstMatch(path);
    if (match == null) {
      // What FastAPI answers for a route it does not have.
      throw const ServerApiException(statusCode: 404, detail: 'Not Found');
    }

    final String id = match.group(1)!;
    final String name = match.group(2)!;
    // A fake server knows what it was given. Ten records are bundled, and a
    // gene that is not one of them correctly 404s rather than serving some
    // other protein under the wrong name.
    final ProteinTarget? target = ProteinCatalog.byPath(id, name);
    if (target == null) {
      // Verbatim from the backend's router, so `userMessage` reads the same.
      throw ServerApiException(
        statusCode: 404,
        detail: "No gene '$name' in record '$id'.",
      );
    }

    if (match.group(3) != null) {
      if (!target.impactExplanationsAvailable) {
        throw const ServerApiException(
          statusCode: 404,
          detail: 'AVI explanations are not included for this gene.',
        );
      }
      final String raw = await (_payloads[target.impactExplanationsAsset] ??=
          _bundle.loadString(target.impactExplanationsAsset));
      return compute(_decode, raw);
    }
    return _record(target);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    await Future<void>.delayed(latency);
    // The service exposes no POST route, so this is the honest answer rather
    // than an UnimplementedError the app has no way to interpret.
    throw const ServerApiException(
      statusCode: 405,
      detail: 'Method Not Allowed',
    );
  }

  /// `GET /catalog`. One page, because twenty fits in one and the cursor the
  /// real service pages by is keyed on slug, which this never needs to split.
  Map<String, dynamic> _catalog(List<ProteinTarget> targets) =>
      <String, dynamic>{
        'proteins': <Map<String, dynamic>>[
          for (final ProteinTarget target in targets) _summary(target),
        ],
        'next': null,
      };

  /// `GET /catalog/search`. `candidates` is empty here for the same reason it
  /// is empty on the real service: discovery arrives with the resolver.
  Map<String, dynamic> _search(String query) => <String, dynamic>{
    'proteins': <Map<String, dynamic>>[
      for (final ProteinTarget target in rank(ProteinCatalog.all, query))
        _summary(target),
    ],
    'candidates': <Map<String, dynamic>>[],
  };

  /// `GET /protein/{slug}` and `GET /protein/{slug}/tracks`.
  Map<String, dynamic> _protein(String slug, {required bool tracksOnly}) {
    final ProteinTarget? target = ProteinCatalog.bySlug(slug);
    if (target == null) {
      // Verbatim from the backend's router.
      throw ServerApiException(
        statusCode: 404,
        detail: "No protein '$slug' in the catalog.",
      );
    }
    if (tracksOnly) {
      return <String, dynamic>{
        for (final TrackKind kind in TrackKind.values)
          kind.wire: <String, dynamic>{
            'state': _stateOf(target, kind).wire,
            'reason': null,
            // Null while the assets are still bundled: nothing asks this
            // server for a blob, because every track still resolves through
            // `rootBundle` off the paths on the target itself.
            'url': null,
            'format': kind == TrackKind.structure ? 'glb' : 'json',
            'bytes': null,
            'sha256': null,
            'content_encoding': null,
            'provenance': <String, dynamic>{},
          },
      };
    }
    return <String, dynamic>{
      ..._summary(target),
      'chain': target.chain,
      'mature_peptides': true,
      'chains': <Map<String, dynamic>>[
        for (final StructureChain chain in target.chains)
          <String, dynamic>{'node': chain.node, 'tint': chain.tint.name},
      ],
      'structure': <String, dynamic>{
        'pdb': target.structure.pdb,
        'modelled': target.structure.modelled == null
            ? null
            : <int>[
                target.structure.modelled!.$1,
                target.structure.modelled!.$2,
              ],
        'label': target.structure.label,
        'count': target.structure.count,
        'unit': target.structure.unit,
        'sentence': target.structure.sentence,
        'semantics': target.structure.semantics,
      },
    };
  }

  /// The fields a search card needs. Deliberately not every field the real
  /// `ProteinDetail` carries: `regions`, `disulfides` and `provenance` are
  /// derived from the record rather than held on a target, so this server has
  /// nothing truthful to say about them and says nothing instead.
  Map<String, dynamic> _summary(ProteinTarget target) => <String, dynamic>{
    'slug': target.slug,
    'display': target.display,
    'gene': target.gene,
    'uniprot': target.uniprot,
    'accession': target.accession,
    'summary': target.summary,
    'facts': <String, dynamic>{
      'residues': target.facts.residues,
      'exons': target.facts.exons,
      'chains': target.facts.chains,
      'bridges': target.facts.bridges,
    },
    'catalog_order': ProteinCatalog.all.indexOf(target),
    'tracks': <String, dynamic>{
      for (final TrackKind kind in TrackKind.values)
        kind.wire: _stateOf(target, kind).wire,
    },
  };

  /// What this build actually bundles. A fixture server that claimed a track
  /// was absent while the asset sat in the bundle would be answering for a
  /// different build than the one it is standing in for.
  TrackState _stateOf(ProteinTarget target, TrackKind kind) => switch (kind) {
    TrackKind.record => TrackState.ready,
    TrackKind.constraint => _readyIf(target.scored),
    TrackKind.impact => _readyIf(target.impactScored),
    TrackKind.clinvar => _readyIf(target.clinvarAvailable),
    TrackKind.structure => TrackState.ready,
    TrackKind.impactExplanations => _readyIf(
      target.impactExplanationsAvailable,
    ),
  };

  static TrackState _readyIf(bool bundled) =>
      bundled ? TrackState.ready : TrackState.absent;

  Future<Map<String, dynamic>> _record(ProteinTarget target) async {
    final String raw = await (_payloads[target.slug] ??= _bundle.loadString(
      target.mockAsset,
    ));
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Map<String, dynamic> _decode(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;
}
