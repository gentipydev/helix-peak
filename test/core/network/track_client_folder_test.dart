import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';

/// `getApplicationCacheDirectory`, answered with a temp directory: the only
/// way to see where a client with no `cache` given puts its files.
const MethodChannel _paths = MethodChannel('plugins.flutter.io/path_provider');

class _Api implements ApiClient {
  _Api(this.rows);

  final Map<String, Map<String, dynamic>> rows;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async => <String, dynamic>{
    for (final TrackKind kind in TrackKind.values)
      kind.wire: rows[kind.wire] ??
          <String, dynamic>{'state': 'absent', 'provenance': <String, dynamic>{}},
  };

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) => throw UnimplementedError();
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.payloads);

  final Map<String, List<int>> payloads;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final List<int>? bytes = payloads[options.uri.toString()];
    return bytes == null
        ? ResponseBody.fromBytes(const <int>[], 404)
        : ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ready(String url, String sha) => <String, dynamic>{
  'state': 'ready',
  'url': url,
  'format': 'json',
  'sha256': sha,
  'provenance': <String, dynamic>{},
};

const String _constraintUrl = 'https://cdn.example/constraint/insulin.aaaa.json';
const String _clinvarUrl = 'https://cdn.example/clinvar/insulin.bbbb.json';

final Map<String, List<int>> _payloads = <String, List<int>>{
  _constraintUrl: utf8.encode('{"gene":"INS","kind":"constraint"}'),
  _clinvarUrl: utf8.encode('{"gene":"INS","kind":"clinvar"}'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('helixpeek-folders');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _paths,
          (MethodCall call) async =>
              call.method == 'getApplicationCacheDirectory' ? root.path : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_paths, null);
    root.deleteSync(recursive: true);
  });

  TrackClient client({String? folder, int? budget}) {
    final Dio dio = Dio()..httpClientAdapter = _Adapter(_payloads);
    final _Api api = _Api(<String, Map<String, dynamic>>{
      'constraint': _ready(_constraintUrl, 'aaaa'),
      'clinvar': _ready(_clinvarUrl, 'bbbb'),
    });
    return folder == null
        ? TrackClient(api, dio: dio)
        : TrackClient(
            api,
            dio: dio,
            folder: folder,
            budget: budget ?? 200 * 1024 * 1024,
          );
  }

  List<String> namesIn(String path) {
    final Directory directory = Directory(path);
    if (!directory.existsSync()) {
      return const <String>[];
    }
    return <String>[
      for (final FileSystemEntity entity in directory.listSync())
        entity.uri.pathSegments.lastWhere((String s) => s.isNotEmpty),
    ]..sort();
  }

  test('the walk’s call keeps the folder it always had', () async {
    final TrackClient walk = client();
    expect(walk.folder, 'tracks');
    expect(walk.budget, 200 * 1024 * 1024);

    await walk.read('insulin', TrackKind.constraint);
    expect(namesIn('${root.path}/tracks'), <String>['aaaa']);
    expect(namesIn('${root.path}/track_rows'), <String>['insulin.json']);
  });

  test('a second client under its own folder keeps its own files and rows', () async {
    final TrackClient walk = client();
    final TrackClient lab = client(folder: 'lab/tracks');

    await walk.read('insulin', TrackKind.constraint);
    await lab.read('insulin', TrackKind.clinvar);

    expect(namesIn('${root.path}/tracks'), <String>['aaaa']);
    expect(namesIn('${root.path}/track_rows'), <String>['insulin.json']);
    expect(namesIn('${root.path}/lab/tracks'), <String>['bbbb']);
    expect(namesIn('${root.path}/lab/track_rows'), <String>['insulin.json']);
  });

  test('a second client over its budget evicts only its own files', () async {
    final TrackClient walk = client();
    // One byte: every write leaves the lab's cache over budget, so each one
    // empties it.
    final TrackClient lab = client(folder: 'lab/tracks', budget: 1);

    await walk.read('insulin', TrackKind.constraint);
    await walk.read('insulin', TrackKind.clinvar);
    await lab.read('insulin', TrackKind.constraint);
    await lab.read('insulin', TrackKind.clinvar);

    expect(namesIn('${root.path}/tracks'), <String>['aaaa', 'bbbb']);
    expect(namesIn('${root.path}/lab/tracks'), isEmpty);
  });
}
