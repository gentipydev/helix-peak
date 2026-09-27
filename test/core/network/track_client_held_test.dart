import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';

const String _url =
    'https://cdn.example/tracks/constraint/insulin.9527916f760d.json';

Map<String, dynamic> _tracks({String state = 'ready'}) => <String, dynamic>{
  for (final TrackKind kind in TrackKind.values)
    kind.wire: kind == TrackKind.constraint
        ? <String, dynamic>{
            'state': state,
            'url': state == 'ready' ? _url : null,
            'format': 'json',
            'sha256': state == 'ready' ? '9527916f760d' : null,
            'provenance': <String, dynamic>{},
          }
        : <String, dynamic>{
            'state': 'absent',
            'provenance': <String, dynamic>{},
          },
};

/// Answers the rows, and counts every call, so a test can say none was made.
class _Api implements ApiClient {
  _Api(this.body);

  final Map<String, dynamic> body;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    calls++;
    return body;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) => throw UnimplementedError();
}

/// Serves one payload, and counts every fetch.
class _Adapter implements HttpClientAdapter {
  int fetches = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetches++;
    return ResponseBody.fromBytes(utf8.encode('{"gene":"INS"}'), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory cache;

  setUp(() {
    final Directory root = Directory.systemTemp.createTempSync(
      'helixpeek-held',
    );
    cache = Directory('${root.path}/tracks')..createSync();
  });
  tearDown(() => cache.parent.deleteSync(recursive: true));

  TrackClient client(_Api api, _Adapter adapter) =>
      TrackClient(api, dio: Dio()..httpClientAdapter = adapter, cache: cache);

  test('holds nothing before anything is read, and asks nobody', () async {
    final _Api api = _Api(_tracks());
    final _Adapter adapter = _Adapter();
    expect(
      await client(api, adapter).held('insulin', TrackKind.constraint),
      isNull,
    );
    expect(api.calls, 0);
    expect(adapter.fetches, 0);
  });

  test(
    'holds what it has read, and gives it back without the network',
    () async {
      final _Adapter first = _Adapter();
      final Uint8List read = await client(
        _Api(_tracks()),
        first,
      ).read('insulin', TrackKind.constraint);

      // A new client over the same cache: the app, started again, offline.
      final _Api api = _Api(_tracks());
      final _Adapter adapter = _Adapter();
      final TrackClient again = client(api, adapter);
      expect(await again.held('insulin', TrackKind.constraint), read);
      expect(api.calls, 0);
      expect(adapter.fetches, 0);
    },
  );

  test('holds nothing for a kind its rows do not call ready', () async {
    final TrackClient reader = client(_Api(_tracks()), _Adapter());
    await reader.read('insulin', TrackKind.constraint);
    expect(await reader.held('insulin', TrackKind.clinvar), isNull);
    expect(await reader.held('glucagon', TrackKind.constraint), isNull);
  });

  test('holds nothing once the file its rows name is gone', () async {
    final TrackClient reader = client(_Api(_tracks()), _Adapter());
    await reader.read('insulin', TrackKind.constraint);
    File('${cache.path}/9527916f760d').deleteSync();
    expect(await reader.held('insulin', TrackKind.constraint), isNull);
  });
}
