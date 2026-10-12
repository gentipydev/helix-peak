// A protein built on demand whose fold is published again while the app runs:
// each walk reads one generation of it, whole, and the next walk the new one.
import 'dart:async';
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

import '../../support/built_fold.dart';

/// The service, as answers queued a path at a time: the last one stays. With
/// [hold] set, a call waits for it before it is answered, as a service that
/// is asleep keeps a caller waiting.
class _Api implements ApiClient {
  final Map<String, List<Object>> answers = <String, List<Object>>{};
  final List<String> asked = <String>[];
  Completer<void>? hold;

  void answer(String path, Object body) => answers[path] = <Object>[body];
  void then(String path, Object body) => answers[path]!.add(body);

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    asked.add(path);
    final Completer<void>? waits = hold;
    if (waits != null) {
      await waits.future;
    }
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

/// A patience no answer here outlasts, and one every held answer does.
const Duration _long = Duration(minutes: 1);
const Duration _short = Duration(milliseconds: 20);

/// Waits until [met], for as long as two seconds.
Future<void> _until(Future<bool> Function() met) async {
  for (int turn = 0; turn < 400 && !await met(); turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(await met(), isTrue);
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
      ProteinTarget.fromJson(BuiltFold.row(generation));

  Map<TrackKind, TrackRef> rows(String generation, {String? framedIn}) =>
      tracksFromJson(BuiltFold.tracks(generation, framedIn: framedIn));

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
      final Map<String, dynamic> pending = BuiltFold.tracks('alphafold')
        ..['structure'] = <String, dynamic>{'state': 'pending'};
      expect(foldCoherence(target('alphafold'), tracksFromJson(pending)), FoldCoherence.whole);
    });
  });

  group('a walk of a protein built on demand', () {
    test('reads one generation of its fold, and the next walk the one published since', () async {
      api.answer('/protein/ttr', BuiltFold.row('alphafold'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('alphafold'));
      final (ProteinTarget first, TrackSource? firstSource) = await pinWalk(catalog, client, 'ttr');
      expect(first.structure!.pdb, 'AF-P02766-F1');
      final PinnedTrackSource before = firstSource! as PinnedTrackSource;

      // A backfill publishes the experimental fold.
      api.answer('/protein/ttr', BuiltFold.row('pdb'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      final (ProteinTarget second, TrackSource? secondSource) = await pinWalk(
        catalog, client, 'ttr', patience: _long);
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
      // The row answered before the backfill landed; the track rows after it.
      api.answer('/protein/ttr', BuiltFold.row('alphafold'));
      api.then('/protein/ttr', BuiltFold.row('pdb'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      final (ProteinTarget target, TrackSource? source) = await pinWalk(catalog, client, 'ttr');
      expect(target.structure!.pdb, '8C86');
      expect(foldCoherence(target, (source! as TrackRows).rowsOf('ttr')!), FoldCoherence.whole);
      expect(api.asked.where((String path) => path == '/protein/ttr'), hasLength(2));
      expect(api.asked.where((String path) => path == '/protein/ttr/tracks'), hasLength(2));
    });

    test('opens on the model, without its fold, where the fold was made with another model', () async {
      api.answer('/protein/ttr', BuiltFold.row('pdb'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb', framedIn: 'c' * 64));
      final (_, TrackSource? source) = await pinWalk(catalog, client, 'ttr');
      final PinnedTrackSource pinned = source! as PinnedTrackSource;
      expect(pinned.rowsOf('ttr')![TrackKind.folding]!.state, TrackState.absent);
      expect(pinned.rowsOf('ttr')![TrackKind.structure]!.state, TrackState.ready);
      await expectLater(pinned.read('ttr', TrackKind.folding), throwsA(isA<TrackApiException>()));
    });

    test('reads as it always has where no track rows can be read at all', () async {
      api.answer('/protein/ttr', BuiltFold.row('pdb'));
      api.answer('/protein/ttr/tracks', const ServerApiException(statusCode: 503));
      final (ProteinTarget target, TrackSource? source) = await pinWalk(catalog, client, 'ttr');
      expect((target.structure!.pdb, source), ('8C86', null));
    });

    test('never read, waits for the service however slow it is', () async {
      api.answer('/protein/ttr', BuiltFold.row('pdb'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      final Completer<void> asleep = api.hold = Completer<void>();
      bool opened = false;
      final Future<(ProteinTarget, TrackSource?)> open = pinWalk(
        catalog, client, 'ttr', patience: _short);
      unawaited(open.then(((ProteinTarget, TrackSource?) _) => opened = true));
      await Future<void>.delayed(_short * 6);
      expect(opened, isFalse);
      asleep.complete();
      expect((await open).$1.structure!.pdb, '8C86');
    });

    test('already read, opens on what is held where the service is slow, and keeps its answer', () async {
      api.answer('/protein/ttr', BuiltFold.row('alphafold'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('alphafold'));
      await pinWalk(catalog, client, 'ttr');

      // Its fold is published again, and the service is slow to say so.
      api.answer('/protein/ttr', BuiltFold.row('pdb'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      final Completer<void> asleep = api.hold = Completer<void>();
      final (ProteinTarget target, TrackSource? source) = await pinWalk(
        catalog, client, 'ttr', patience: _short);
      expect(target.structure!.pdb, 'AF-P02766-F1');
      expect((source! as TrackRows).rowsOf('ttr')![TrackKind.structure]!.sha256, '1' * 64);
      // Nothing else of the walk waits on that answer: the rows remembered
      // are still the ones any read is by (the record's is the client's own).
      expect(
        (await client.tracksOf('ttr').timeout(_short * 6))[TrackKind.structure]!.sha256,
        '1' * 64,
      );

      // It answers at last: kept, and the next open is by it.
      asleep.complete();
      api.hold = null;
      await _until(() async =>
          catalog.bySlug('ttr')!.structure!.pdb == '8C86' &&
          (await client.remembered('ttr')!)[TrackKind.structure]!.sha256 == '2' * 64);
      api.asked.clear();
      api.hold = Completer<void>();
      final (ProteinTarget next, TrackSource? nextSource) = await pinWalk(
        catalog, client, 'ttr', patience: _short);
      expect(next.structure!.pdb, '8C86');
      expect((nextSource! as TrackRows).rowsOf('ttr')![TrackKind.folding]!.sha256, '3' * 64);
      api.hold!.complete();
    });

    test('already read, waits all the same where what is held is not one fold', () async {
      // The row of one fold and the rows of another, however often it asks.
      api.answer('/protein/ttr', BuiltFold.row('alphafold'));
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      final (ProteinTarget parted, TrackSource? partedSource) = await pinWalk(catalog, client, 'ttr');
      expect(foldCoherence(parted, (partedSource! as TrackRows).rowsOf('ttr')!), FoldCoherence.none);

      api.answer('/protein/ttr', BuiltFold.row('pdb'));
      final Completer<void> asleep = api.hold = Completer<void>();
      bool opened = false;
      final Future<(ProteinTarget, TrackSource?)> open = pinWalk(
        catalog, client, 'ttr', patience: _short);
      unawaited(open.then(((ProteinTarget, TrackSource?) _) => opened = true));
      await Future<void>.delayed(_short * 6);
      expect(opened, isFalse);
      asleep.complete();
      final (ProteinTarget target, TrackSource? source) = await open;
      expect(foldCoherence(target, (source! as TrackRows).rowsOf('ttr')!), FoldCoherence.whole);
    });
  });

  group('track rows asked for again', () {
    setUp(() async {
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('alphafold'));
      await client.tracksOf('ttr');
    });

    test('are the service\'s, remembered in place of those held', () async {
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      expect((await client.refresh('ttr'))[TrackKind.structure]!.sha256, '2' * 64);
      expect((await client.tracksOf('ttr'))[TrackKind.structure]!.sha256, '2' * 64);
      expect(api.asked, hasLength(2));
    });

    test('are the ones held where the service cannot be reached, and those stay', () async {
      api.answer('/protein/ttr/tracks', const ServerApiException(statusCode: 503));
      expect((await client.refresh('ttr'))[TrackKind.structure]!.sha256, '1' * 64);
      expect((await client.remembered('ttr')!)[TrackKind.structure]!.sha256, '1' * 64);
    });

    test('are forgotten where the service refuses outright', () async {
      api.answer('/protein/ttr/tracks', const ServerApiException(statusCode: 404, detail: 'Gone'));
      await expectLater(client.refresh('ttr'), throwsA(isA<ServerApiException>()));
      expect(client.remembered('ttr'), isNull);
    });

    test('asked again before the service has answered, are the one ask', () async {
      final Completer<void> asleep = api.hold = Completer<void>();
      api.asked.clear();
      final Future<Map<TrackKind, TrackRef>> first = client.refresh('ttr');
      final Future<Map<TrackKind, TrackRef>> second = client.refresh('ttr');
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      asleep.complete();
      expect((await first)[TrackKind.structure]!.sha256, '2' * 64);
      expect((await second)[TrackKind.structure]!.sha256, '2' * 64);
      expect(api.asked, hasLength(1));

      // Answered, the next ask is a new one.
      api.hold = null;
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('alphafold'));
      expect((await client.refresh('ttr'))[TrackKind.structure]!.sha256, '1' * 64);
      expect(api.asked, hasLength(2));
    });

    test('are there to be had at once, as last read', () async {
      expect(client.known('prl'), isNull);
      expect(client.known('ttr')![TrackKind.structure]!.sha256, '1' * 64);
      api.answer('/protein/ttr/tracks', BuiltFold.tracks('pdb'));
      final Completer<void> asleep = api.hold = Completer<void>();
      final Future<Map<TrackKind, TrackRef>> asked = client.refresh('ttr');
      // Still the ones it had, while it is asked.
      expect(client.known('ttr')![TrackKind.structure]!.sha256, '1' * 64);
      asleep.complete();
      await asked;
      expect(client.known('ttr')![TrackKind.structure]!.sha256, '2' * 64);
      // And the ones it had where the service cannot be reached.
      api.hold = null;
      api.answer('/protein/ttr/tracks', const ServerApiException(statusCode: 503));
      await client.refresh('ttr');
      expect(client.known('ttr')![TrackKind.structure]!.sha256, '2' * 64);
    });

    test('of a protein never read are read as any are, the cache behind them', () async {
      api.answer('/protein/prl/tracks', BuiltFold.tracks('pdb'));
      expect(client.remembered('prl'), isNull);
      expect((await client.refresh('prl'))[TrackKind.structure]!.sha256, '2' * 64);
      expect(client.remembered('prl'), isNotNull);
    });
  });

  group('a row read afresh', () {
    test('is the one kept where the service cannot be reached, and not where it refuses', () async {
      api.answer('/protein/ttr', BuiltFold.row('alphafold'));
      expect((await catalog.protein('ttr')).structure!.pdb, 'AF-P02766-F1');
      api.answer('/protein/ttr', const ServerApiException(statusCode: 503));
      expect((await catalog.protein('ttr', fresh: true)).structure!.pdb, 'AF-P02766-F1');
      api.answer('/protein/ttr', const ServerApiException(statusCode: 404, detail: 'Gone'));
      await expectLater(catalog.protein('ttr', fresh: true), throwsA(isA<ServerApiException>()));
    });

    test('is the list\'s own for one of the catalog, which is never asked for again', () async {
      api.answer('/catalog', <String, dynamic>{
        'proteins': <Map<String, dynamic>>[<String, dynamic>{
          ...BuiltFold.row('pdb'), 'slug': 'insulin', 'catalog_order': 0}],
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
