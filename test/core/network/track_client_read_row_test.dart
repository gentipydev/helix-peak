import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_client.dart';

const String _path = '/peptide-lm/runs/curated';
const String _url =
    'https://cdn.example/tracks/peptide-lm/curated.6f3031599652.json';

/// The row the service names a run by, and the ways asking can fail.
class _Api implements ApiClient {
  _Api({this.error});

  ApiException? error;
  final List<String> asked = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    asked.add(path);
    final ApiException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return <String, dynamic>{
      'name': 'curated',
      'url': _url,
      'bytes': 13,
      'sha256': '6f3031599652',
      'format': 'json',
      'provenance': <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) => throw UnimplementedError();
}

/// Serves the run's bytes, counting each fetch.
class _Adapter implements HttpClientAdapter {
  final List<String> fetched = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetched.add(options.uri.toString());
    return ResponseBody.fromBytes(utf8.encode('{"name":"curated"}'), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory cache;

  setUp(() {
    final Directory root = Directory.systemTemp.createTempSync('helixpeek-rows');
    cache = Directory('${root.path}/peptide_lm')..createSync();
  });
  tearDown(() {
    if (cache.existsSync()) {
      cache.parent.deleteSync(recursive: true);
    }
  });

  TrackClient client(_Api api, _Adapter adapter) => TrackClient(
    api,
    dio: Dio()..httpClientAdapter = adapter,
    cache: cache,
    folder: 'peptide_lm',
  );

  test('a row the service names is read, then its bytes, through the cache', () async {
    final _Api api = _Api();
    final _Adapter adapter = _Adapter();
    final Uint8List bytes = await client(api, adapter).readRow(_path);
    expect(utf8.decode(bytes), '{"name":"curated"}');
    expect(api.asked, <String>[_path]);
    expect(adapter.fetched, <String>[_url]);
    // Named by its digest, as a track's bytes are.
    expect(File('${cache.path}/6f3031599652').existsSync(), isTrue);

    // Read again in another run: the service is asked, the bytes are not.
    final _Adapter again = _Adapter();
    await client(_Api(), again).readRow(_path);
    expect(again.fetched, isEmpty);
  });

  test('a service that is down opens the row kept, and the bytes held', () async {
    await client(_Api(), _Adapter()).readRow(_path);
    final _Adapter adapter = _Adapter();
    final _Api down = _Api(error: const ServerApiException(statusCode: 503));
    final Uint8List bytes = await client(down, adapter).readRow(_path);
    expect(utf8.decode(bytes), '{"name":"curated"}');
    expect(adapter.fetched, isEmpty);

    final _Api asleep = _Api(error: const TimeoutApiException());
    expect(await client(asleep, _Adapter()).readRow(_path), bytes);
  });

  test('a refusal is never hidden behind the row kept', () async {
    await client(_Api(), _Adapter()).readRow(_path);
    final _Api gone = _Api(error: const ServerApiException(statusCode: 404));
    await expectLater(
      client(gone, _Adapter()).readRow(_path),
      throwsA(isA<ServerApiException>()),
    );
  });

  test('with nothing kept, a failure is the failure', () async {
    final _Api down = _Api(error: const NetworkApiException());
    await expectLater(
      client(down, _Adapter()).readRow(_path),
      throwsA(isA<NetworkApiException>()),
    );
  });
}
