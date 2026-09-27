import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/features/lab/challenges/domain/challenge_materials.dart';
import 'package:helixpeek/features/lab/challenges/presentation/challenge_shelf.dart';

import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';

/// The rows naming insulin's record, fold and ClinVar snapshot, each at a
/// URL the adapter serves from the walk's fixtures.
Map<String, dynamic> _rows(ProteinTarget target) => <String, dynamic>{
  for (final TrackKind kind in TrackKind.values)
    kind.wire:
        <TrackKind>[
          TrackKind.record,
          TrackKind.structure,
          TrackKind.clinvar,
        ].contains(kind)
        ? <String, dynamic>{
            'state': 'ready',
            'url': 'https://cdn.example/${kind.wire}/${target.slug}',
            'format': 'json',
            'sha256': '${kind.wire}-${target.slug}',
            'provenance': <String, dynamic>{},
          }
        : <String, dynamic>{
            'state': 'absent',
            'provenance': <String, dynamic>{},
          },
};

class _Api implements ApiClient {
  _Api(this.target);

  final ProteinTarget target;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async => _rows(target);

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) => throw UnimplementedError();
}

/// Serves each fixture once; after that, the network is gone.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.target);

  final ProteinTarget target;
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final TrackKind kind = TrackKind.fromWire(options.uri.pathSegments.first)!;
    return ResponseBody.fromBytes(
      File(target.asset(kind)!).readAsBytesSync(),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory cache;

  setUp(() {
    cache = Directory(
      '${Directory.systemTemp.createTempSync('helixpeek-shelf').path}/tracks',
    )..createSync();
  });
  tearDown(() => cache.parent.deleteSync(recursive: true));

  test('holds nothing of a protein the lab has not opened', () async {
    final ProteinTarget insulin = TestCatalog.insulin;
    final _Adapter adapter = _Adapter(insulin)..offline = true;
    final TrackClient client = TrackClient(
      _Api(insulin),
      dio: Dio()..httpClientAdapter = adapter,
      cache: cache,
    );
    final ProteinMaterials held = await CachedShelf(client)
        .materialsOf(insulin);
    expect(held.fold, isFalse);
    expect(held.sequence, isNull);
    expect(held.reported, isEmpty);
  });

  test('reads what the lab has opened, offline: the fold, the sequence and '
      'the missense records', () async {
    final ProteinTarget insulin = TestCatalog.insulin;
    final _Adapter adapter = _Adapter(insulin);
    final TrackClient first = TrackClient(
      _Api(insulin),
      dio: Dio()..httpClientAdapter = adapter,
      cache: cache,
    );
    for (final TrackKind kind in <TrackKind>[
      TrackKind.record,
      TrackKind.structure,
      TrackKind.clinvar,
    ]) {
      await first.read(insulin.slug, kind);
    }

    // The app again, with the network gone.
    adapter.offline = true;
    final TrackClient again = TrackClient(
      _Api(insulin),
      dio: Dio()..httpClientAdapter = adapter,
      cache: cache,
    );
    final ProteinMaterials held = await CachedShelf(again).materialsOf(insulin);
    final String sequence = recordOf(insulin).protein!.translation;
    expect(held.fold, isTrue);
    expect(held.sequence, sequence);
    expect(held.reported, isNotEmpty);
    for (final ReportedChange change in held.reported) {
      expect(sequence[change.residue - 1], change.from);
      expect(change.to, isNot(change.from));
    }
  });
}
