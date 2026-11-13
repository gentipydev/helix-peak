import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';

/// The service's digest names a cached file only where it can be nothing but a
/// name (the security review of 2026-11-13): one that could name a path is
/// fetched and never written, inside the cache or out of it.

const String _url = 'https://cdn.example/tracks/constraint/insulin.json';

Map<String, dynamic> _tracks(String? sha256) => <String, dynamic>{
  for (final TrackKind kind in TrackKind.values)
    kind.wire: kind == TrackKind.constraint
        ? <String, dynamic>{
            'state': 'ready',
            'reason': null,
            'url': _url,
            'format': 'json',
            'bytes': null,
            'sha256': sha256,
            'content_encoding': null,
            'provenance': <String, dynamic>{},
          }
        : <String, dynamic>{'state': 'absent', 'url': null, 'sha256': null},
};

class _Api implements ApiClient {
  _Api(this.body);

  final Map<String, dynamic> body;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async => body;

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) => throw UnimplementedError();
}

class _Adapter implements HttpClientAdapter {
  final List<String> fetched = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetched.add(options.uri.toString());
    return ResponseBody.fromBytes(utf8.encode('{"gene":"INS"}'), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;
  late Directory cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('helixpeek-digest');
    cache = Directory('${root.path}/tracks')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  TrackClient client(String? sha256, _Adapter adapter) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    return TrackClient(_Api(_tracks(sha256)), dio: dio, cache: cache);
  }

  List<String> everyFile() => root
      .listSync(recursive: true)
      .whereType<File>()
      .map((File file) => file.path.substring(root.path.length))
      .toList();

  for (final String digest in <String>['../escaped', '../../escaped', 'a/b', '..', '.', 'x.json']) {
    test('a digest that could name a path ($digest) is fetched and never kept', () async {
      final _Adapter adapter = _Adapter();
      final TrackClient tracks = client(digest, adapter);

      expect(utf8.decode(await tracks.read('insulin', TrackKind.constraint)), '{"gene":"INS"}');
      expect(utf8.decode(await tracks.read('insulin', TrackKind.constraint)), '{"gene":"INS"}');

      expect(adapter.fetched, <String>[_url, _url]);
      expect(cache.listSync(), isEmpty);
      expect(everyFile().where((String path) => path.contains('escaped')), isEmpty);
      expect(File('${root.parent.path}/escaped').existsSync(), isFalse);
    });
  }

  test('a sha256 still names the cached file', () async {
    const String sha256 = '9527916f760d4d4c43a4ae1ab2f2b1c0a5b9d3c1e6f7a8b9c0d1e2f3a4b5cd78';
    final _Adapter adapter = _Adapter();
    final TrackClient tracks = client(sha256, adapter);

    await tracks.read('insulin', TrackKind.constraint);
    await tracks.read('insulin', TrackKind.constraint);

    expect(adapter.fetched, <String>[_url]);
    expect(
      cache.listSync().map((FileSystemEntity e) => e.uri.pathSegments.last),
      <String>[sha256],
    );
  });
}
