// The fold page reading a protein by rows fixed when its walk opened: its
// caches are named by that generation of the fold, and a fold made with
// another model than those rows name is not played.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

/// Relaxin's stored fold, the twenty's own bake, which names the `.glb` it was
/// made in the frame of.
final Uint8List _folding = File(
  'test/shared/folding/fixtures/relaxin_folding.json',
).readAsBytesSync();
final String _framedIn =
    ((jsonDecode(utf8.decode(_folding)) as Map<String, dynamic>)['frame']
            as Map<String, dynamic>)['glb_sha256']
        as String;

/// Relaxin's row, its fold said to be ready.
ProteinTarget _relaxin() {
  final Map<String, dynamic> catalog =
      jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
          as Map<String, dynamic>;
  final Map<String, dynamic> row =
      (catalog['proteins'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere(
        (Map<String, dynamic> row) => row['slug'] == 'relaxin',
      );
  return ProteinTarget.fromJson(<String, dynamic>{
    ...row,
    'tracks': <String, dynamic>{
      ...(row['tracks'] as Map<String, dynamic>),
      'folding': 'ready',
    },
  });
}

/// Its track rows: the model's `.glb` named by [glb], and its fold stored
/// under [folding]'s digest.
Map<TrackKind, TrackRef> _rows({required String glb, String folding = 'f'}) =>
    <TrackKind, TrackRef>{
      TrackKind.structure: TrackRef(
        state: TrackState.ready,
        url: 'https://cdn.example/structure/relaxin.$glb.fsceneb',
        sha256: 's$glb',
        provenance: <String, dynamic>{
          'pdb': '6RLX',
          'nodes': <String>['chainA', 'chainB', 'bonds'],
          'glb': <String, dynamic>{'sha256': glb},
        },
      ),
      TrackKind.folding: TrackRef(
        state: TrackState.ready,
        url: 'https://cdn.example/folding/relaxin.$folding.json',
        sha256: folding,
      ),
    };

class _NoService implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) =>
      throw UnimplementedError(path);

  @override
  Future<Map<String, dynamic>> postJson(String path, {required Map<String, dynamic> body}) =>
      throw UnimplementedError(path);
}

/// Storage serving relaxin's fold wherever it is asked for.
class _Storage implements HttpClientAdapter {
  int fetched = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetched++;
    return ResponseBody.fromBytes(_folding, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// The walk's tests' kind of source: the fold, and no rows.
class _Plain implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) async => _folding;
}

void main() {
  late TrackClient client;
  late _Storage storage;

  setUp(() {
    storage = _Storage();
    client = TrackClient(_NoService(), dio: Dio()..httpClientAdapter = storage);
  });

  test('a source with no rows names the fold by its protein, as it always has', () {
    expect(StructureView.generationOf(_relaxin(), _Plain()), 'relaxin');
    expect(StructureView.generationOf(_relaxin(), null), 'relaxin');
  });

  test('rows fixed for a walk name it by their generation, and two generations apart', () {
    final ProteinTarget relaxin = _relaxin();
    final String first = StructureView.generationOf(
      relaxin,
      client.pinned('relaxin', _rows(glb: _framedIn)),
    );
    final String second = StructureView.generationOf(
      relaxin,
      client.pinned('relaxin', _rows(glb: 'b' * 64, folding: 'g')),
    );
    expect(first, 'relaxin@s$_framedIn+f');
    expect(second, 'relaxin@s${'b' * 64}+g');
    // Another protein's rows say nothing of relaxin's.
    expect(
      StructureView.generationOf(relaxin, client.pinned('ttr', _rows(glb: 'c' * 64))),
      'relaxin',
    );
  });

  test('a fold made in the frame of the model its rows name is played', () async {
    final FoldGeometry? fold = await StructureView.foldOf(
      _relaxin(),
      client.pinned('relaxin', _rows(glb: _framedIn, folding: 'h')),
    );
    expect(fold, isNotNull);
    expect(fold!.track.glbSha256, _framedIn);
  });

  test('a fold made with another model is not played, and is not kept for the next', () async {
    final ProteinTarget relaxin = _relaxin();
    expect(
      await StructureView.foldOf(
        relaxin,
        client.pinned('relaxin', _rows(glb: 'd' * 64, folding: 'i')),
      ),
      isNull,
    );
    // The same fold, under rows that name its own model: a new generation,
    // read afresh, and played.
    expect(
      await StructureView.foldOf(
        relaxin,
        client.pinned('relaxin', _rows(glb: _framedIn, folding: 'i')),
      ),
      isNotNull,
    );
  });

  test('a source with no rows plays the fold as it always has', () async {
    final FoldGeometry? fold = await StructureView.foldOf(_relaxin(), _Plain());
    expect(fold, isNotNull);
  });
}
