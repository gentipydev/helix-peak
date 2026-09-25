import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';

/// One `/protein/{slug}/tracks` answer, in the shape the service serves.
Map<String, dynamic> _row({
  String state = 'ready',
  String? url = 'https://cdn.example/tracks/constraint/insulin.9527916f760d.json',
  String? sha256 = '9527916f760d',
  String? reason,
}) => <String, dynamic>{
  'state': state,
  'reason': reason,
  'url': url,
  'format': 'json',
  'bytes': null,
  'sha256': sha256,
  'content_encoding': null,
  'provenance': <String, dynamic>{},
};

Map<String, dynamic> _tracks(Map<String, Map<String, dynamic>> rows) =>
    <String, dynamic>{
      for (final TrackKind kind in TrackKind.values)
        kind.wire: rows[kind.wire] ?? _row(state: 'absent', url: null, sha256: null),
    };

/// Counts what it was asked for, and fails the way the service fails.
class _Api implements ApiClient {
  _Api(this.body, {this.error});

  final Map<String, dynamic> body;
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
    return body;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) => throw UnimplementedError();
}

/// Serves bytes for a URL, or the DioException the transport would raise.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.payloads, {this.failure});

  final Map<String, List<int>> payloads;
  final DioExceptionType? failure;
  final List<String> fetched = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetched.add(options.uri.toString());
    final DioExceptionType? raise = failure;
    if (raise != null) {
      throw DioException(requestOptions: options, type: raise);
    }
    final List<int>? bytes = payloads[options.uri.toString()];
    if (bytes == null) {
      return ResponseBody.fromBytes(const <int>[], 404);
    }
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, List<int>> files;
  final List<String> asked = <String>[];

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    final List<int>? bytes = files[key];
    if (bytes == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

const String _url =
    'https://cdn.example/tracks/constraint/insulin.9527916f760d.json';

List<int> _payload(String gene) => utf8.encode('{"gene":"$gene"}');

void main() {
  late Directory cache;

  setUp(() => cache = Directory.systemTemp.createTempSync('helixpeek-tracks'));
  tearDown(() {
    if (cache.existsSync()) {
      cache.deleteSync(recursive: true);
    }
  });

  TrackClient client(
    _Api api, {
    _Adapter? adapter,
    _Bundle? bundle,
    int budget = 200 * 1024 * 1024,
  }) {
    final Dio dio = Dio();
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }
    return TrackClient(
      api,
      dio: dio,
      bundle: bundle ?? _Bundle(<String, List<int>>{}),
      cache: cache,
      budget: budget,
    );
  }

  test('an asset:// track is read from the bundle and nothing is fetched', () async {
    final _Bundle bundle = _Bundle(<String, List<int>>{
      'assets/clinvar/insulin_clinvar.json': _payload('INS'),
    });
    final _Adapter adapter = _Adapter(const <String, List<int>>{});
    final TrackClient tracks = client(
      _Api(
        _tracks(<String, Map<String, dynamic>>{
          'clinvar': _row(
            url: 'asset://assets/clinvar/insulin_clinvar.json',
            sha256: null,
          ),
        }),
      ),
      adapter: adapter,
      bundle: bundle,
    );

    expect(
      utf8.decode(await tracks.read('insulin', TrackKind.clinvar)),
      '{"gene":"INS"}',
    );
    expect(bundle.asked, <String>['assets/clinvar/insulin_clinvar.json']);
    expect(adapter.fetched, isEmpty);
    // Nothing on disk: a bundle read is already the cheapest read there is.
    expect(cache.listSync(), isEmpty);
  });

  test('a ready track is fetched once and then read from the cache', () async {
    final _Adapter adapter = _Adapter(<String, List<int>>{
      _url: _payload('INS'),
    });
    final TrackClient tracks = client(
      _Api(_tracks(<String, Map<String, dynamic>>{'constraint': _row()})),
      adapter: adapter,
    );

    expect(
      utf8.decode(await tracks.read('insulin', TrackKind.constraint)),
      '{"gene":"INS"}',
    );
    expect(
      utf8.decode(await tracks.read('insulin', TrackKind.constraint)),
      '{"gene":"INS"}',
    );
    expect(adapter.fetched, <String>[_url]);
  });

  test('the cached file is named by the digest, so a re-bake is a new file', () async {
    final TrackClient tracks = client(
      _Api(_tracks(<String, Map<String, dynamic>>{'constraint': _row()})),
      adapter: _Adapter(<String, List<int>>{_url: _payload('INS')}),
    );
    await tracks.read('insulin', TrackKind.constraint);

    expect(
      cache.listSync().map((FileSystemEntity e) => e.uri.pathSegments.last),
      <String>['9527916f760d'],
    );
    // And no `.part` left behind: the write lands under a name nothing looks
    // for and is renamed onto the digest.
    expect(
      cache.listSync().where((FileSystemEntity e) => e.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('a track with no digest is fetched and not cached', () async {
    final _Adapter adapter = _Adapter(<String, List<int>>{_url: _payload('INS')});
    final TrackClient tracks = client(
      _Api(
        _tracks(<String, Map<String, dynamic>>{'constraint': _row(sha256: null)}),
      ),
      adapter: adapter,
    );

    await tracks.read('insulin', TrackKind.constraint);
    await tracks.read('insulin', TrackKind.constraint);
    expect(cache.listSync(), isEmpty);
    expect(adapter.fetched, <String>[_url, _url]);
  });

  test('the cache is trimmed to its budget, least recently read first', () async {
    final TrackClient tracks = client(
      _Api(_tracks(<String, Map<String, dynamic>>{'constraint': _row()})),
      adapter: _Adapter(<String, List<int>>{_url: List<int>.filled(400, 0x20)}),
      budget: 1000,
    );

    // Three files already there, read at known times.
    for (final (String name, int age) in <(String, int)>[
      ('older', 3),
      ('oldest', 9),
      ('newer', 1),
    ]) {
      final File held = File('${cache.path}/$name')
        ..writeAsBytesSync(List<int>.filled(400, 0x20));
      held.setLastModifiedSync(
        DateTime.now().subtract(Duration(hours: age)),
      );
    }
    expect(cache.listSync().length, 3);

    // 1,600 B against a 1,000 B budget, so the two oldest go and the digest
    // just written stays.
    await tracks.read('insulin', TrackKind.constraint);
    expect(
      cache
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .toSet(),
      <String>{'newer', '9527916f760d'},
    );
  });

  test('a protein is asked about once, however many families are read', () async {
    final _Api api = _Api(
      _tracks(<String, Map<String, dynamic>>{
        'constraint': _row(),
        'impact': _row(
          url: 'https://cdn.example/tracks/impact/insulin.9f06a9b1e45a.json',
          sha256: '9f06a9b1e45a',
        ),
      }),
    );
    final TrackClient tracks = client(
      api,
      adapter: _Adapter(<String, List<int>>{
        _url: _payload('INS'),
        'https://cdn.example/tracks/impact/insulin.9f06a9b1e45a.json':
            _payload('INS'),
      }),
    );

    await tracks.read('insulin', TrackKind.constraint);
    await tracks.read('insulin', TrackKind.impact);
    expect(api.asked, <String>['/protein/insulin/tracks']);
  });

  test('a track row that failed is not remembered', () async {
    final _Api api = _Api(
      _tracks(<String, Map<String, dynamic>>{'constraint': _row()}),
      error: const NetworkApiException(),
    );
    final TrackClient tracks = client(
      api,
      adapter: _Adapter(<String, List<int>>{_url: _payload('INS')}),
    );

    await expectLater(
      tracks.read('insulin', TrackKind.constraint),
      throwsA(isA<NetworkApiException>()),
    );
    // The service cold-starts; the second look has to be allowed to succeed.
    api.error = null;
    expect(
      utf8.decode(await tracks.read('insulin', TrackKind.constraint)),
      '{"gene":"INS"}',
    );
    expect(api.asked, <String>[
      '/protein/insulin/tracks',
      '/protein/insulin/tracks',
    ]);
  });

  test('a family the service does not call ready throws, and says why', () async {
    final _Adapter adapter = _Adapter(const <String, List<int>>{});
    final TrackClient tracks = client(
      _Api(
        _tracks(<String, Map<String, dynamic>>{
          'clinvar': _row(
            state: 'refused',
            url: null,
            sha256: null,
            reason: 'Titin exceeds the page budget.',
          ),
        }),
      ),
      adapter: adapter,
    );

    await expectLater(
      tracks.read('titin', TrackKind.clinvar),
      throwsA(
        isA<TrackApiException>()
            .having((TrackApiException e) => e.state, 'state', 'refused')
            .having((TrackApiException e) => e.kind, 'kind', 'clinvar')
            .having(
              (TrackApiException e) => e.userMessage,
              'userMessage',
              'Titin exceeds the page budget.',
            ),
      ),
    );
    // A track with nowhere to fetch from is not fetched from anywhere.
    expect(adapter.fetched, isEmpty);
  });

  test('a family with no row at all reads as absent rather than throwing oddly', () async {
    final TrackClient tracks = client(
      _Api(const <String, dynamic>{}),
      adapter: _Adapter(const <String, List<int>>{}),
    );

    await expectLater(
      tracks.read('insulin', TrackKind.structure),
      throwsA(
        isA<TrackApiException>()
            .having((TrackApiException e) => e.state, 'state', 'absent'),
      ),
    );
  });

  test('a download failure surfaces in the vocabulary the app reports', () async {
    final TrackClient tracks = client(
      _Api(_tracks(<String, Map<String, dynamic>>{'constraint': _row()})),
      adapter: _Adapter(
        const <String, List<int>>{},
        failure: DioExceptionType.receiveTimeout,
      ),
    );

    await expectLater(
      tracks.read('insulin', TrackKind.constraint),
      throwsA(isA<TimeoutApiException>()),
    );
    // A failed fetch leaves nothing behind to be served as if it were a track.
    expect(cache.listSync(), isEmpty);
  });

  test('a 404 on the blob is the server error it is', () async {
    final TrackClient tracks = client(
      _Api(
        _tracks(<String, Map<String, dynamic>>{
          'constraint': _row(url: 'https://cdn.example/gone.json'),
        }),
      ),
      adapter: _Adapter(const <String, List<int>>{}),
    );

    await expectLater(
      tracks.read('insulin', TrackKind.constraint),
      throwsA(
        isA<ServerApiException>()
            .having((ServerApiException e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });
}
