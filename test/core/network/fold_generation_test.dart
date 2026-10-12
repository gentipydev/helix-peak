// A protein built on demand whose fold is published again while the app runs:
// each walk reads one generation of it, whole, and the next walk the new one.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/core/network/track_rows.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';

/// Transthyretin as it was built (AlphaFold DB's model, drawn still) and as
/// a backfill publishes it (PDB 8C86, with its fold): each its row and its
/// track rows.
abstract final class _Fold {
  static Map<String, dynamic> row(String generation) => <String, dynamic>{
    'slug': 'ttr',
    'display': 'Transthyretin',
    'gene': 'TTR',
    'uniprot': 'P02766',
    'accession': 'NG_009490.1',
    'summary': 'Built on demand.',
    'facts': <String, int>{'residues': 147, 'exons': 4, 'chains': 1, 'bridges': 0},
    'catalog_order': null,
    'chain': null,
    'chains': generation == 'pdb'
        ? <Map<String, String>>[<String, String>{'node': 'chainA', 'tint': 'mature1'}]
        : <Map<String, String>>[
            <String, String>{'node': 'plddtVeryHigh', 'tint': 'plddtVeryHigh'},
            <String, String>{'node': 'plddtLow', 'tint': 'plddtLow'},
          ],
    'structure': <String, dynamic>{
      'pdb': generation == 'pdb' ? '8C86' : 'AF-P02766-F1',
      'modelled': null,
      'label': generation == 'pdb' ? 'the subunit' : 'the predicted fold',
      'count': 127,
      'unit': 'residues',
      'sentence': 'A sentence.',
      'semantics': 'Its semantics.',
    },
    'regions': <Map<String, dynamic>>[
      <String, dynamic>{'label': 'Signal peptide', 'short': 'S', 'start': 1, 'end': 20,
                        'origin': 1, 'kept': false},
      <String, dynamic>{'label': 'Transthyretin', 'short': 'T', 'start': 21, 'end': 147,
                        'origin': 21, 'kept': true},
    ],
    'tracks': <String, String>{
      'record': 'ready',
      'structure': 'ready',
      'folding': generation == 'pdb' ? 'ready' : 'absent',
    },
  };

  static Map<String, dynamic> tracks(String generation, {String? framedIn}) {
    final bool pdb = generation == 'pdb';
    final String glb = pdb ? 'b' * 64 : 'a' * 64;
    final String scene = pdb ? '2' * 64 : '1' * 64;
    return <String, dynamic>{
      'record': _ref('record/ttr.0123456789ab.json', '0' * 64),
      'structure': <String, dynamic>{
        ..._ref('structure/ttr.${scene.substring(0, 12)}.fsceneb', scene),
        'format': 'fsceneb',
        'provenance': <String, dynamic>{
          'pdb': pdb ? '8C86' : 'AF-P02766-F1',
          'nodes': pdb ? <String>['chainA'] : <String>['plddtVeryHigh', 'plddtLow'],
          'glb': <String, dynamic>{'path': 'structure/ttr.glb', 'sha256': glb},
        },
      },
      'folding': pdb
          ? <String, dynamic>{
              ..._ref('folding/ttr.${'3' * 12}.json', '3' * 64),
              'provenance': <String, dynamic>{
                'frame': <String, dynamic>{'glb_sha256': framedIn ?? glb},
              },
            }
          : <String, dynamic>{'state': 'absent', 'provenance': <String, dynamic>{}},
    };
  }

  static Map<String, dynamic> _ref(String path, String sha256) => <String, dynamic>{
    'state': 'ready',
    'reason': null,
    'url': 'https://cdn.example/$path',
    'format': 'json',
    'bytes': 4,
    'sha256': sha256,
    'content_encoding': null,
    'provenance': <String, dynamic>{},
  };
}

/// The service, as answers queued a path at a time: the last one stays.
class _Api implements ApiClient {
  final Map<String, List<Object>> answers = <String, List<Object>>{};
  final List<String> asked = <String>[];

  void answer(String path, Object body) => answers[path] = <Object>[body];
  void then(String path, Object body) => answers[path]!.add(body);

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    asked.add(path);
    final List<Object>? queued = answers[path];
    if (queued == null) {
      throw const ServerApiException(statusCode: 404, detail: 'No such path');
    }
    final Object answer = queued.length > 1 ? queued.removeAt(0) : queued.first;
    if (answer is ApiException) {
      throw answer;
    }
    return answer as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {required Map<String, dynamic> body}) =>
      throw UnimplementedError();
}

/// Storage: every object's bytes are its own path, so a read says which
/// generation it was.
class _Storage implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(utf8.encode(options.uri.path), 200);

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory cache;
  late _Api api;
  late TrackClient client;
  late ProteinCatalogRepository catalog;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('helixpeek-generations');
    api = _Api();
    client = TrackClient(api, dio: Dio()..httpClientAdapter = _Storage(),
                         cache: Directory('${cache.path}/tracks'));
    catalog = ProteinCatalogRepository(api, null);
  });
  tearDown(() {
    catalog.dispose();
    cache.deleteSync(recursive: true);
  });

  ProteinTarget target(String generation) =>
      ProteinTarget.fromJson(_Fold.row(generation));

  Map<TrackKind, TrackRef> rows(String generation, {String? framedIn}) =>
      tracksFromJson(_Fold.tracks(generation, framedIn: framedIn));

  group('a row and its track rows', () {
    test('are one fold where the model and its fold agree with the row', () {
      expect(foldCoherence(target('alphafold'), rows('alphafold')), FoldCoherence.whole);
      expect(foldCoherence(target('pdb'), rows('pdb')), FoldCoherence.whole);
    });

    test('name another model where the row was read before the fold was published', () {
      expect(foldCoherence(target('alphafold'), rows('pdb')), FoldCoherence.none);
      expect(foldCoherence(target('pdb'), rows('alphafold')), FoldCoherence.none);
    });

    test('keep the model and not the fold where the fold was made in another frame', () {
      expect(foldCoherence(target('pdb'), rows('pdb', framedIn: 'c' * 64)),
             FoldCoherence.modelOnly);
    });

    test('have nothing to disagree about where there is no model yet', () {
      final Map<String, dynamic> pending = _Fold.tracks('alphafold')
        ..['structure'] = <String, dynamic>{'state': 'pending'};
      expect(foldCoherence(target('alphafold'), tracksFromJson(pending)), FoldCoherence.whole);
    });
  });

  group('a walk of a protein built on demand', () {
    test('reads one generation of its fold, and the next walk the one published since', () async {
      api.answer('/protein/ttr', _Fold.row('alphafold'));
      api.answer('/protein/ttr/tracks', _Fold.tracks('alphafold'));
      final (ProteinTarget first, TrackSource? firstSource) = await pinWalk(
        catalog, client, await catalog.protein('ttr', fresh: true));
      expect(first.structure!.pdb, 'AF-P02766-F1');
      final PinnedTrackSource before = firstSource! as PinnedTrackSource;

      // A backfill publishes the experimental fold.
      api.answer('/protein/ttr', _Fold.row('pdb'));
      api.answer('/protein/ttr/tracks', _Fold.tracks('pdb'));
      final (ProteinTarget second, TrackSource? secondSource) = await pinWalk(
        catalog, client, await catalog.protein('ttr', fresh: true));
      expect(second.structure!.pdb, '8C86');
      expect(catalog.bySlug('ttr')!.structure!.pdb, '8C86');
      final PinnedTrackSource after = secondSource! as PinnedTrackSource;

      // Each reads its own: the walk opened first stays on AlphaFold's model.
      expect(utf8.decode(await before.read('ttr', TrackKind.structure)),
             '/structure/ttr.111111111111.fsceneb');
      expect(utf8.decode(await after.read('ttr', TrackKind.structure)),
             '/structure/ttr.222222222222.fsceneb');
      await expectLater(before.read('ttr', TrackKind.folding),
                        throwsA(isA<TrackApiException>()));
      expect(utf8.decode(await after.read('ttr', TrackKind.folding)),
             '/folding/ttr.333333333333.json');
      expect(before.rowsOf('ttr')![TrackKind.structure]!.sha256, '1' * 64);
      expect(after.rowsOf('ttr')![TrackKind.structure]!.sha256, '2' * 64);
      // Another protein is read as the client reads it.
      expect(before.rowsOf('insulin'), isNull);
    });

    test('reads its row and its rows once more where a publication parted them', () async {
      // The row read before the backfill landed; the track rows after it.
      api.answer('/protein/ttr', _Fold.row('alphafold'));
      api.then('/protein/ttr', _Fold.row('pdb'));
      api.answer('/protein/ttr/tracks', _Fold.tracks('pdb'));
      final ProteinTarget stale = await catalog.protein('ttr', fresh: true);
      expect(stale.structure!.pdb, 'AF-P02766-F1');
      final (ProteinTarget target, TrackSource? source) = await pinWalk(catalog, client, stale);
      expect(target.structure!.pdb, '8C86');
      expect(foldCoherence(target, (source! as TrackRows).rowsOf('ttr')!), FoldCoherence.whole);
      expect(api.asked.where((String path) => path == '/protein/ttr'), hasLength(2));
    });

    test('opens on the model, without its fold, where the fold was made with another model', () async {
      api.answer('/protein/ttr', _Fold.row('pdb'));
      api.answer('/protein/ttr/tracks', _Fold.tracks('pdb', framedIn: 'c' * 64));
      final (_, TrackSource? source) = await pinWalk(
        catalog, client, await catalog.protein('ttr', fresh: true));
      final PinnedTrackSource pinned = source! as PinnedTrackSource;
      expect(pinned.rowsOf('ttr')![TrackKind.folding]!.state, TrackState.absent);
      expect(pinned.rowsOf('ttr')![TrackKind.structure]!.state, TrackState.ready);
      await expectLater(pinned.read('ttr', TrackKind.folding), throwsA(isA<TrackApiException>()));
    });

    test('reads as it always has where no track rows can be read at all', () async {
      api.answer('/protein/ttr', _Fold.row('pdb'));
      api.answer('/protein/ttr/tracks', const ServerApiException(statusCode: 503));
      final ProteinTarget held = await catalog.protein('ttr', fresh: true);
      final (ProteinTarget target, TrackSource? source) = await pinWalk(catalog, client, held);
      expect((target, source), (held, null));
    });
  });

  group('a row read afresh', () {
    test('is the one kept where the service cannot be reached, and not where it refuses', () async {
      api.answer('/protein/ttr', _Fold.row('alphafold'));
      expect((await catalog.protein('ttr')).structure!.pdb, 'AF-P02766-F1');
      api.answer('/protein/ttr', const ServerApiException(statusCode: 503));
      expect((await catalog.protein('ttr', fresh: true)).structure!.pdb, 'AF-P02766-F1');
      api.answer('/protein/ttr', const ServerApiException(statusCode: 404, detail: 'Gone'));
      await expectLater(catalog.protein('ttr', fresh: true), throwsA(isA<ServerApiException>()));
    });

    test('is the list\'s own for one of the catalog, which is never asked for again', () async {
      api.answer('/catalog', <String, dynamic>{
        'proteins': <Map<String, dynamic>>[<String, dynamic>{
          ..._Fold.row('pdb'), 'slug': 'insulin', 'catalog_order': 0}],
        'next': null,
      });
      await catalog.refresh();
      expect(catalog.listed('insulin'), isTrue);
      expect(catalog.listed('ttr'), isFalse);
      api.asked.clear();
      expect((await catalog.protein('insulin', fresh: true)).slug, 'insulin');
      expect(api.asked, isEmpty);
    });
  });
}
